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

# === [STEP] Locate .pfx files ===
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

    Write-Host "[INFO] Slack Webhook disabled. Notification skipped."
    Write-Host ""
}
