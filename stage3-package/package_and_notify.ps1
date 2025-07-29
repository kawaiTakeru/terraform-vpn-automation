# === [CONFIG] Paths ===
$certs        = "$env:BUILD_ARTIFACTSTAGINGDIRECTORY/certs/certs"
$vpnZip       = "$env:BUILD_ARTIFACTSTAGINGDIRECTORY/vpn/vpn/vpnprofile.zip"
$outDir       = "$env:BUILD_ARTIFACTSTAGINGDIRECTORY/output"
$unzipDir     = "$outDir/unzipped"
$slackWebhook = $env:SLACK_WEBHOOK_URL

# === [TEST] Slack通知テスト（Webhook動作確認） ===
if ($slackWebhook) {
    $testPayload = @{ text = "📣 Slack通知テスト：Pipelineからの送信テスト成功（WebHook確認）" } | ConvertTo-Json -Compress
    try {
        Invoke-RestMethod -Uri $slackWebhook -Method POST -ContentType 'application/json' -Body $testPayload
        Write-Host "[TEST] Slack Webhook test message sent successfully."
    } catch {
        Write-Warning "[WARN] Slack Webhook test failed: $($_.Exception.Message)"
    }
} else {
    Write-Warning "[WARN] SLACK_WEBHOOK_URL is not set. Skipping Slack test message."
}
Write-Host ""

Write-Host "=== [INFO] Directory paths ==="
Write-Host "Certificate directory : $certs"
Write-Host "VPN ZIP file          : $vpnZip"
Write-Host "Output directory      : $outDir"
Write-Host ""

# ...（後続の処理はそのまま）

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

# === [DEBUG] Listing VPN directory contents ===
$vpnDir = Split-Path $vpnZip
if (Test-Path $vpnDir) {
    Write-Host "=== [DEBUG] Listing contents of VPN directory: $vpnDir"
    Get-ChildItem -Recurse $vpnDir | ForEach-Object {
        Write-Host " - $($_.FullName)"
    }
    Write-Host ""
}

# === [DEBUG] List extracted files ===
Write-Host "=== [DEBUG] Listing extracted files..."
Get-ChildItem $unzipDir -Recurse | ForEach-Object {
    Write-Host " - $($_.FullName)"
}
Write-Host ""

# === [STEP] Locate .pfx files ===
Write-Host "=== [STEP] Finding .pfx files..."
$pfxList = Get-ChildItem "$certs/*.pfx"
if (-not $pfxList) {
    Write-Error "[ERROR] No .pfx files found in: $certs"
    exit 1
}
Write-Host "[OK] Found $($pfxList.Count) .pfx file(s)"
Write-Host ""

# === [STEP] Process each PFX file ===
foreach ($pfx in $pfxList) {
    $userName = $pfx.BaseName
    Write-Host "=== [PROCESS] User: $userName ==="
    Write-Host "PFX file path      : $($pfx.FullName)"

    # === Find VPN config file (.xml) ===
    $azurevpn = Get-Item "$unzipDir/AzureVPN/azurevpnconfig.xml" -ErrorAction SilentlyContinue
    if (-not $azurevpn) {
        Write-Error "[ERROR] azurevpnconfig.xml not found in: $unzipDir\AzureVPN"
        continue
    }
    Write-Host "VPN config file path: $($azurevpn.FullName)"

    # === Confirm both files are readable ===
    try {
        $null = Get-Content $pfx.FullName -ErrorAction Stop
        $null = Get-Content $azurevpn.FullName -ErrorAction Stop
        Write-Host "[OK] Verified both files are readable."
    } catch {
        Write-Error "[ERROR] File read failed: $($_.Exception.Message)"
        continue
    }

    # === Create ZIP package ===
    $zipPath = "$outDir/${userName}_vpn_package.zip"
    Write-Host "Creating ZIP package: $zipPath"
    Compress-Archive -Path @($pfx.FullName, $azurevpn.FullName) -DestinationPath $zipPath -Force
    Write-Host "[OK] Package created: $zipPath"

    # === Slack notification ===
    if ($slackWebhook) {
        $payload = @{ text = "[OK] VPN package for $userName has been created." } | ConvertTo-Json -Compress
        Invoke-RestMethod -Uri $slackWebhook -Method POST -ContentType 'application/json' -Body $payload
        Write-Host "[OK] Slack notification sent."
    } else {
        Write-Warning "[WARN] Slack webhook URL not set. Skipping notification."
    }

    Write-Host ""
}
