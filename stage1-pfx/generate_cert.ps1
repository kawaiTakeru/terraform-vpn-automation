# === Path settings ===
$certs        = "$env:BUILD_ARTIFACTSTAGINGDIRECTORY/certs/certs"
$vpnZip       = "$env:BUILD_ARTIFACTSTAGINGDIRECTORY/vpn/vpn/vpnprofile.zip"
$outDir       = "$env:BUILD_ARTIFACTSTAGINGDIRECTORY/output"
$unzipDir     = "$outDir/unzipped"
$slackWebhook = $env:SLACK_WEBHOOK_URL

Write-Host "=== [INFO] Directory paths ==="
Write-Host "Certificate directory : $certs"
Write-Host "VPN ZIP file          : $vpnZip"
Write-Host "Output directory      : $outDir"
Write-Host ""

# === Create output directory ===
Write-Host "=== [STEP] Creating output directory..."
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

# === Debug: List VPN ZIP directory contents before checking existence ===
$vpnDir = Split-Path $vpnZip
Write-Host "=== [DEBUG] Listing contents of VPN directory: $vpnDir"
Get-ChildItem -Recurse $vpnDir | ForEach-Object {
    Write-Host " - $($_.FullName)"
}
Write-Host ""

# === Validate VPN ZIP exists ===
Write-Host "=== [CHECK] Checking if VPN ZIP exists..."
if (-not (Test-Path $vpnZip)) {
    Write-Error "[ERROR] VPN ZIP file not found: $vpnZip"
    exit 1
}
Write-Host "[OK] VPN ZIP file found: $vpnZip"
Write-Host ""

# === Unzip the VPN ZIP ===
Write-Host "=== [STEP] Extracting VPN ZIP..."
Expand-Archive -Path $vpnZip -DestinationPath $unzipDir -Force
Write-Host "[OK] Extracted to: $unzipDir"
Write-Host ""

# === List extracted files ===
Write-Host "=== [DEBUG] Listing extracted files..."
Get-ChildItem $unzipDir -Recurse | ForEach-Object {
    Write-Host " - $($_.FullName)"
}
Write-Host ""

# === Find all PFX files ===
Write-Host "=== [STEP] Finding .pfx files..."
$pfxList = Get-ChildItem "$certs/*.pfx"
if (-not $pfxList) {
    Write-Error "[ERROR] No .pfx files found in: $certs"
    exit 1
}
Write-Host "[OK] Found $($pfxList.Count) .pfx file(s)"
Write-Host ""

# === Process each PFX file ===
foreach ($pfx in $pfxList) {
    $userName = $pfx.BaseName
    Write-Host "=== [PROCESS] User: $userName ==="
    Write-Host "PFX file path      : $($pfx.FullName)"

    # === Use azurevpnconfig.xml instead of .azurevpn ===
    $azurevpn = Get-Item "$unzipDir/AzureVPN/azurevpnconfig.xml" -ErrorAction SilentlyContinue
    if (-not $azurevpn) {
        Write-Error "[ERROR] azurevpnconfig.xml not found in: $unzipDir\AzureVPN"
        continue
    }
    Write-Host "VPN config file path: $($azurevpn.FullName)"

    # === Confirm both files exist and are readable ===
    if (-not (Test-Path $pfx.FullName)) {
        Write-Error "[ERROR] PFX file missing: $($pfx.FullName)"
        continue
    }
    if (-not (Test-Path $azurevpn.FullName)) {
        Write-Error "[ERROR] VPN config file missing: $($azurevpn.FullName)"
        continue
    }

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

    # === Send Slack notification ===
    if ($slackWebhook) {
        $payload = @{ text = "[OK] VPN package for $userName has been created." } | ConvertTo-Json -Compress
        Invoke-RestMethod -Uri $slackWebhook -Method POST -ContentType 'application/json' -Body $payload
        Write-Host "[OK] Slack notification sent."
    } else {
        Write-Warning "[WARN] Slack webhook URL not set. Skipping notification."
    }

    Write-Host ""
}
