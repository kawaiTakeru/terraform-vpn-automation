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

# === [STEP] Create output directory ===
Write-Host "=== [STEP] Creating output directory..."
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

# === [CHECK] VPN ZIP file exists ===
Write-Host "=== [CHECK] Checking if VPN ZIP exists..."
if (-not (Test-Path $vpnZip)) {
    Write-Error "[ERROR] VPN ZIP file not found: $vpnZip"
    exit 1
}
Write-Host "[OK] VPN ZIP file found: $vpnZip"
Write-Host ""

# === [STEP] Extract VPN ZIP ===
Write-Host "=== [STEP] Extracting VPN ZIP..."
Expand-Archive -Path $vpnZip -DestinationPath $unzipDir -Force
Write-Host "[OK] Extracted to: $unzipDir"
Write-Host ""

# === [DEBUG] List extracted files ===
Write-Host "=== [DEBUG] Listing extracted files..."
Get-ChildItem $unzipDir -Recurse | ForEach-Object {
    Write-Host " - $($_.FullName)"
}
Write-Host ""

# === [STEP] Searching for .pfx files ===
Write-Host "=== [STEP] Searching for .pfx files..."
$pfxList = Get-ChildItem "$certs/*.pfx"
if (-not $pfxList) {
    Write-Error "[ERROR] No .pfx files found in: $certs"
    exit 1
}
Write-Host "[OK] Found $($pfxList.Count) .pfx file(s)"
Write-Host ""

# === [STEP] Process each .pfx file ===
foreach ($pfx in $pfxList) {
    $userName = $pfx.BaseName
    Write-Host "=== [PROCESS] User: $userName ==="
    Write-Host "PFX file path        : $($pfx.FullName)"

    $azurevpn = Get-Item "$unzipDir/AzureVPN/azurevpnconfig.xml" -ErrorAction SilentlyContinue
    if (-not $azurevpn) {
        Write-Error "[ERROR] azurevpnconfig.xml not found in: $unzipDir\AzureVPN"
        continue
    }
    Write-Host "VPN config file path : $($azurevpn.FullName)"

    try {
        $null = Get-Content $pfx.FullName -ErrorAction Stop
        $null = Get-Content $azurevpn.FullName -ErrorAction Stop
        Write-Host "[OK] Verified both files are readable."
    } catch {
        Write-Error "[ERROR] Failed to read files: $($_.Exception.Message)"
        continue
    }

    $zipPath = "$outDir/${userName}_vpn_package.zip"
    Write-Host "Creating ZIP package : $zipPath"
    Compress-Archive -Path @($pfx.FullName, $azurevpn.FullName) -DestinationPath $zipPath -Force
    Write-Host "[OK] Package created : $zipPath"
    Write-Host ""

    # === [STEP] Upload ZIP to Slack ===
    Write-Host "=== [STEP] Uploading ZIP to Slack DM..."

    $token = $env:SLACK_BOT_TOKEN
    $email = "t-kawai@bfts.co.jp"

    # ① Get Slack user ID
    $userResp = Invoke-RestMethod -Uri "https://slack.com/api/users.lookupByEmail" `
        -Headers @{ Authorization = "Bearer $token" } `
        -Method Get `
        -Body @{ email = $email }

    if (-not $userResp.ok) {
        Write-Error "[ERROR] Slack user lookup failed: $($userResp.error)"
        continue
    }
    $userId = $userResp.user.id
    Write-Host "[OK] Slack user ID: $userId"

    # ② Open DM channel
    $dmResp = Invoke-RestMethod -Uri "https://slack.com/api/conversations.open" `
        -Headers @{ Authorization = "Bearer $token" } `
        -Method Post `
        -ContentType "application/json" `
        -Body (@{ users = $userId } | ConvertTo-Json -Depth 10)

    if (-not $dmResp.ok) {
        Write-Error "[ERROR] Failed to open DM: $($dmResp.error)"
        continue
    }
    $channelId = $dmResp.channel.id
    Write-Host "[OK] DM channel: $channelId"

    # ③ Upload ZIP file using multipart/form-data
    Write-Host "Uploading $zipPath to Slack via multipart/form-data..."

    $httpClient = New-Object System.Net.Http.HttpClient
    $multipart = New-Object System.Net.Http.MultipartFormDataContent

    $fileStream = [System.IO.File]::OpenRead($zipPath)
    $fileContent = New-Object System.Net.Http.StreamContent($fileStream)
    $fileContent.Headers.ContentType = [System.Net.Http.Headers.MediaTypeHeaderValue]::Parse("application/zip")
    $multipart.Add($fileContent, "file", [System.IO.Path]::GetFileName($zipPath))
    $multipart.Add((New-Object System.Net.Http.StringContent($channelId)), "channels")

    $httpClient.DefaultRequestHeaders.Authorization = [System.Net.Http.Headers.AuthenticationHeaderValue]::new("Bearer", $token)

    $response = $httpClient.PostAsync("https://slack.com/api/files.upload", $multipart).Result
    $content = $response.Content.ReadAsStringAsync().Result | ConvertFrom-Json

    if ($content.ok) {
        Write-Host "[✅] Slack file uploaded to DM: $email"
    } else {
        Write-Error "[ERROR] Slack file upload failed: $($content.error)"
    }

    Write-Host ""
}
