# === Path settings ===
$certs        = "$env:BUILD_ARTIFACTSTAGINGDIRECTORY/certs"
$vpnZip       = "$env:BUILD_ARTIFACTSTAGINGDIRECTORY/vpn/vpnprofile.zip"
$outDir       = "$env:BUILD_ARTIFACTSTAGINGDIRECTORY/output"
$unzipDir     = "$outDir/unzipped"
$slackWebhook = $env:SLACK_WEBHOOK_URL

Write-Host "Certificate directory: $certs"
Write-Host "VPN ZIP file: $vpnZip"
Write-Host "Output directory: $outDir"

# === Create output directory ===
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

# === Validate VPN ZIP exists ===
if (-not (Test-Path $vpnZip)) {
    Write-Error "VPN ZIP file not found: $vpnZip"
    exit 1
}

# === Unzip the VPN ZIP ===
Write-Host "Extracting VPN ZIP: $vpnZip"
Expand-Archive -Path $vpnZip -DestinationPath $unzipDir -Force

# === List extracted files ===
Write-Host "Extracted files:"
Get-ChildItem $unzipDir -Recurse | ForEach-Object {
    Write-Host " - $_"
}

# === Process each PFX file ===
$pfxList = Get-ChildItem "$certs/*.pfx"
if (-not $pfxList) {
    Write-Error "No .pfx files found in: $certs"
    exit 1
}

foreach ($pfx in $pfxList) {
    $userName = $pfx.BaseName
    Write-Host "User: $userName"
    Write-Host "PFX file: $($pfx.FullName)"

    # === Get the .azurevpn file ===
    $azurevpn = Get-ChildItem $unzipDir -Recurse -Filter "*.azurevpn" | Select-Object -First 1
    if (-not $azurevpn) {
        Write-Error ".azurevpn file not found in: $unzipDir"
        continue
    }

    Write-Host ".azurevpn file: $($azurevpn.FullName)"

    # === Confirm both files are readable ===
    if (-not (Test-Path $pfx.FullName)) {
        Write-Error "PFX file does not exist: $($pfx.FullName)"
        continue
    }
    if (-not (Test-Path $azurevpn.FullName)) {
        Write-Error ".azurevpn file does not exist: $($azurevpn.FullName)"
        continue
    }

    try {
        $null = Get-Content $pfx.FullName -ErrorAction Stop
        $null = Get-Content $azurevpn.FullName -ErrorAction Stop
        Write-Host "Confirmed: Both files are readable."
    } catch {
        Write-Error "Cannot read files: $($_.Exception.Message)"
        continue
    }

    # === Create user-specific ZIP package ===
    $zipPath = "$outDir/${userName}_vpn_package.zip"
    Write-Host "Creating ZIP package: $zipPath"
    Compress-Archive -Path @($pfx.FullName, $azurevpn.FullName) -DestinationPath $zipPath -Force

    # === Send Slack notification ===
    $payload = @{ text = "[OK] VPN package for $userName has been created." } | ConvertTo-Json -Compress
    Invoke-RestMethod -Uri $slackWebhook -Method POST -ContentType 'application/json' -Body $payload

    Write-Host "Slack notification sent."
}
