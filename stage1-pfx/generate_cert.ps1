# variables
$opensslPath = "openssl"  # PATHが通っていればコマンド名のみでOK
# 正しい環境変数の取得
$certDir = "$env:BUILD_ARTIFACTSTAGINGDIRECTORY/certs"
$jsonFile = "$env:BUILD_SOURCESDIRECTORY/stage1-pfx/vars.json"

# 出力ディレクトリ作成
New-Item -ItemType Directory -Force -Path $certDir | Out-Null

# JSONロードして証明書生成（以下略）


# create output dir
New-Item -ItemType Directory -Force -Path $certDir | Out-Null

# load users from vars.json
$json = Get-Content $jsonFile | ConvertFrom-Json

foreach ($user in $json.users) {
    $userName = $user.name
    $password = $user.password
    $keyFile = "$certDir/$userName.key"
    $csrFile = "$certDir/$userName.csr"
    $crtFile = "$certDir/$userName.crt"
    $pfxFile = "$certDir/$userName.pfx"

    # Create private key
    & $opensslPath genrsa -out $keyFile 2048

    # Create CSR
    & $opensslPath req -new -key $keyFile -out $csrFile -subj "/CN=$userName"

    # Self-sign certificate
    & $opensslPath x509 -req -in $csrFile -signkey $keyFile -out $crtFile -days 365

    # Create .pfx (with password)
    & $opensslPath pkcs12 -export -out $pfxFile -inkey $keyFile -in $crtFile -password pass:$password
}

