# === [CONFIG] OpenSSL binary path ===
$opensslPath = "C:\Program Files\OpenSSL-Win64\bin\openssl.exe"

# === [CONFIG] Paths ===
$certDir = "$env:BUILD_ARTIFACTSTAGINGDIRECTORY/certs"
$jsonFile = "$env:BUILD_SOURCESDIRECTORY/stage1-pfx/vars.json"

Write-Host "=== [INFO] Certificate output directory: $certDir"
Write-Host "=== [INFO] Input JSON file: $jsonFile"

# === [STEP] Create output directory ===
New-Item -ItemType Directory -Force -Path $certDir | Out-Null

# === [STEP] Read JSON and generate certificates ===
$json = Get-Content $jsonFile | ConvertFrom-Json

foreach ($user in $json.users) {
    $userName = $user.name
    $password = $user.password

    $keyFile = "$certDir/$userName.key"
    $csrFile = "$certDir/$userName.csr"
    $crtFile = "$certDir/$userName.crt"
    $pfxFile = "$certDir/$userName.pfx"

    Write-Host ">>> Generating certificate for: $userName"

    # --- Generate private key ---
    & $opensslPath genrsa -out $keyFile 2048

    # --- Generate CSR ---
    & $opensslPath req -new -key $keyFile -out $csrFile -subj "/CN=$userName"

    # --- Generate self-signed certificate ---
    & $opensslPath x509 -req -in $csrFile -signkey $keyFile -out $crtFile -days 365

    # --- Generate .pfx with password ---
    & $opensslPath pkcs12 -export -out $pfxFile -inkey $keyFile -in $crtFile -password pass:$password

    Write-Host "[OK] $userName.pfx created → $pfxFile"
}

Write-Host "=== [SUCCESS] All certificates generated successfully ==="
