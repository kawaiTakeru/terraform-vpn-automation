# === [CONFIG] Paths ===
$certs    = "$env:BUILD_ARTIFACTSTAGINGDIRECTORY/certs/certs"
$vpnZip   = "$env:BUILD_ARTIFACTSTAGINGDIRECTORY/vpn/vpn/vpnprofile.zip"
$outDir   = "$env:BUILD_ARTIFACTSTAGINGDIRECTORY/output"
$unzipDir = "$outDir/unzipped"

Write-Host "=== [INFO] Directory paths ==="
Write-Host "Certificate directory : $certs"
Write-Host "VPN ZIP file          : $vpnZip"
Write-Host "Output directory      : $outDir"
Write-Host ""

New-Item -ItemType Directory -Force -Path $outDir | Out-Null

# === Extract ZIP ===
if (-not (Test-Path $vpnZip)) { Write-Error "VPN ZIP missing: $vpnZip"; exit 1 }
Expand-Archive -Path $vpnZip -DestinationPath $unzipDir -Force

# === Find PFX ===
$pfxList = Get-ChildItem "$certs/*.pfx"
if (-not $pfxList) { Write-Error "No PFX found in: $certs"; exit 1 }

# === Slack Setup ===
$token = $env:SLACK_BOT_TOKEN
$json  = Get-Content "$env:BUILD_SOURCESDIRECTORY/stage1-pfx/vars.json" | ConvertFrom-Json

foreach ($user in $json.users) {
    $userName = $user.name
    $email = $user.email
    $password = $user.password
    $pfx = "$certs/$userName.pfx"
    $vpnXml = "$unzipDir/AzureVPN/azurevpnconfig.xml"
    if (-not (Test-Path $pfx) -or -not (Test-Path $vpnXml)) { continue }

    $zipPath = "$outDir/${userName}_vpn_package.zip"
    Compress-Archive -Path @($pfx, $vpnXml) -DestinationPath $zipPath -Force
    Write-Host "[OK] Created: $zipPath"

    # === Step 1: getUploadURLExternal ===
    $uploadReq = @{
        filename = "$userName.zip"
        length = (Get-Item $zipPath).Length
        alt_text = "VPN Package for $userName"
    } | ConvertTo-Json -Depth 10

    $uploadResp = Invoke-RestMethod -Uri "https://slack.com/api/files.getUploadURLExternal" `
        -Headers @{ Authorization = "Bearer $token" } -Method POST `
        -ContentType "application/json" -Body $uploadReq

    if (-not $uploadResp.ok) { Write-Error "Upload URL request failed: $($uploadResp.error)"; continue }
    $uploadUrl = $uploadResp.upload_url
    $fileId = $uploadResp.file_id

    # === Step 2: Upload binary ===
    $bin = [System.IO.File]::ReadAllBytes($zipPath)
    $uploadResult = Invoke-RestMethod -Uri $uploadUrl -Method PUT -Body $bin -ContentType "application/zip"

    # === Step 3: completeUploadExternal ===
    $completeReq = @{
        files = @(@{
            id = $fileId
            title = "$userName VPN"
        })
    } | ConvertTo-Json -Depth 10

    $completeResp = Invoke-RestMethod -Uri "https://slack.com/api/files.completeUploadExternal" `
        -Headers @{ Authorization = "Bearer $token" } -Method POST `
        -ContentType "application/json" -Body $completeReq

    if (-not $completeResp.ok) { Write-Error "Complete upload failed: $($completeResp.error)"; continue }

    # === Lookup user & open DM ===
    $userResp = Invoke-RestMethod -Uri "https://slack.com/api/users.lookupByEmail" `
        -Headers @{ Authorization = "Bearer $token" } -Method GET `
        -Body @{ email = $email }

    $userId = $userResp.user.id
    $dmResp = Invoke-RestMethod -Uri "https://slack.com/api/conversations.open" `
        -Headers @{ Authorization = "Bearer $token" } -Method POST `
        -ContentType "application/json" -Body (@{ users = $userId } | ConvertTo-Json -Depth 10)
    $channelId = $dmResp.channel.id

    # === Final: postMessage with file link ===
    $msg = @{
        channel = $channelId
        text = ":package: VPN package for *$userName* is ready."
        attachments = @(@{
            title = "$userName VPN Package"
            title_link = $completeResp.files[0].permalink
        })
    } | ConvertTo-Json -Depth 10

    Invoke-RestMethod -Uri "https://slack.com/api/chat.postMessage" `
        -Headers @{ Authorization = "Bearer $token" } -Method POST `
        -ContentType "application/json" -Body $msg

    Write-Host "[✅] DM sent to $email"
}
