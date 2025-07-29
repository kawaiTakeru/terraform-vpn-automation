# OpenSSL 実行パス（フルパス指定）
$opensslPath = "C:\Program Files\OpenSSL-Win64\bin\openssl.exe"

# 正しい環境変数の取得
$certDir = "$env:BUILD_ARTIFACTSTAGINGDIRECTORY/certs"
$jsonFile = "$env:BUILD_SOURCESDIRECTORY/stage1-pfx/vars.json"

# 出力ディレクトリ作成
New-Item -ItemType Directory -Force -Path $certDir | Out-Null

# JSONファイルからユーザー情報を読み込み
$json = Get-Content $jsonFile | ConvertFrom-Json

foreach ($user in $json.users) {
    $userName = $user.name
    $password = $user.password
    $keyFile = "$certDir/$userName.key"
    $csrFile = "$certDir/$userName.csr"
    $crtFile = "$certDir/$userName.crt"
    $pfxFile = "$certDir/$userName.pfx"

    Write-Host "🔐 Generating certificate for $userName..."

    # 秘密鍵生成
    & $opensslPath genrsa -out $keyFile 2048

    # CSR生成
    & $opensslPath req -new -key $keyFile -out $csrFile -subj "/CN=$userName"

    # 自己署名証明書生成
    & $opensslPath x509 -req -in $csrFile -signkey $keyFile -out $crtFile -days 365

    # .pfx生成（パスワード付き）
    & $opensslPath pkcs12 -export -out $pfxFile -inkey $keyFile -in $crtFile -password pass:$password

    Write-Host "✅ $userName.pfx created at $pfxFile"
}

Write-Host "🎉 All certificates generated successfully."
