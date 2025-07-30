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
if (-not (Test-Path $vpnZip)) {
    Write-Error "VPN ZIP missing: $vpnZip"
    exit 1
}
Expand-Archive -Path $vpnZip -DestinationPath $unzipDir -Force

# === Find PFX ===
$pfxList = Get-ChildItem "$certs/*.pfx"
if (-not $pfxList) {
    Write-Error "No PFX found in: $certs"
    exit 1
}

# === Slack Setup ===
$token = $env:SLACK_BOT_TOKEN
$json  = Get-Content "$env:BUILD_SOURCESDIRECTORY/stage1-pfx/vars.json" | ConvertFrom-Json

foreach ($user in $json.users) {
    $userName = $user.name
    $email    = $user.email
    $pfx      = "$certs/$userName.pfx"
    $vpnXml   = "$unzipDir/AzureVPN/azurevpnconfig.xml"

    if (-not (Test-Path $pfx) -or -not (Test-Path $vpnXml)) {
        Write-Warning "Skipping $userName (missing files)"
        continue
    }

    $zipPath = "$outDir/${userName}_vpn_package.zip"
    Compress-Archive -Path @($pfx, $vpnXml) -DestinationPath $zipPath -Force
    Write-Host "[OK] Created: $zipPath"

    # === Step 1: getUploadURLExternal ===
    $uploadReq = [PSCustomObject]@{
        filename = "${userName}_vpn_package.zip"
        length   = (Get-Item $zipPath).Length  # ✅ 修正箇所
    }
    $uploadJson = $uploadReq | ConvertTo-Json -Depth 10 -Compress
    Write-Host "→ [DEBUG] Upload request payload: $uploadJson"

    $uploadResp = Invoke-RestMethod -Uri "https://slack.com/api/files.getUploadURLExternal" `
        -Headers @{ Authorization = "Bearer $token" } `
        -Method POST `
        -ContentType "application/json" `
        -Body $uploadJson

    if (-not $uploadResp.ok) {
        Write-Error "[ERROR] Upload URL request failed: $($uploadResp.error)"
        continue
    }

    $uploadUrl = $uploadResp.upload_url
    $fileId    = $uploadResp.file_id

    # === Step 2: Upload file binary ===
    $bin = [System.IO.File]::ReadAllBytes($zipPath)
    Invoke-RestMethod -Uri $uploadUrl -Method PUT -Body $bin -ContentType "application/zip"

    # === Step 3: completeUploadExternal ===
    $completeReq = @{
        files = @(@{
            id    = $fileId
            title = "$userName VPN Package"
        })
    } | ConvertTo-Json -Depth 10

    $completeResp = Invoke-RestMethod -Uri "https://slack.com/api/files.completeUploadExternal" `
        -Headers @{ Authorization = "Bearer $token" } `
        -Method POST `
        -ContentType "application/json" `
        -Body $completeReq

    if (-not $completeResp.ok) {
        Write-Error "[ERROR] Complete upload failed: $($completeResp.error)"
        continue
    }

    # === Lookup user and open DM ===
    $userResp = Invoke-RestMethod -Uri "https://slack.com/api/users.lookupByEmail?email=$email" `
        -Headers @{ Authorization = "Bearer $token" } `
        -Method GET

    if (-not $userResp.ok) {
        Write-Error "[ERROR] User lookup failed: $($userResp.error)"
        continue
    }

    $userId = $userResp.user.id

    $dmResp = Invoke-RestMethod -Uri "https://slack.com/api/conversations.open" `
        -Headers @{ Authorization = "Bearer $token" } `
        -Method POST `
        -ContentType "application/json" `
        -Body (@{ users = $userId } | ConvertTo-Json -Depth 10)

    if (-not $dmResp.ok) {
        Write-Error "[ERROR] DM open failed: $($dmResp.error)"
        continue
    }

    $channelId = $dmResp.channel.id

    # === Step 4: Send message with link ===
    $msg = @{
        channel     = $channelId
        text        = ":package: VPN package for *$userName* is ready!"
        attachments = @(@{
            title      = "$userName VPN Package"
            title_link = $completeResp.files[0].permalink
        })
    } | ConvertTo-Json -Depth 10

    Invoke-RestMethod -Uri "https://slack.com/api/chat.postMessage" `
        -Headers @{ Authorization = "Bearer $token" } `
        -Method POST `
        -ContentType "application/json" `
        -Body $msg

    Write-Host "[✅] DM sent to $email"
}
