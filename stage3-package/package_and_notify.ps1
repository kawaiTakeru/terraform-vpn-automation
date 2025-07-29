# ✅ 各パスに BUILD_ARTIFACTSTAGINGDIRECTORY を使用
$certs   = "$env:BUILD_ARTIFACTSTAGINGDIRECTORY/certs"
$vpnZip  = "$env:BUILD_ARTIFACTSTAGINGDIRECTORY/vpn/vpnprofile.zip"
$outDir  = "$env:BUILD_ARTIFACTSTAGINGDIRECTORY/output"
$slackWebhook = $env:SLACK_WEBHOOK_URL  # ← Secret として事前に登録

# 🔧 準備
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

# ✅ ZIP存在チェック
if (-not (Test-Path $vpnZip)) {
    Write-Error "❌ VPN ZIPが見つかりません: $vpnZip"
    exit 1
}

# 📂 展開して .azurevpn を取り出す
Expand-Archive -Path $vpnZip -DestinationPath "$outDir/unzipped"

# 📦 ZIPファイル作成（pfx + .azurevpn）
Get-ChildItem "$certs/*.pfx" | ForEach-Object {
    $userName = $_.BaseName
    $azurevpn = Get-ChildItem "$outDir/unzipped" -Recurse -Filter "*.azurevpn" | Select-Object -First 1
    if (-not $azurevpn) {
        Write-Error "❌ .azurevpn ファイルが見つかりませんでした"
        exit 1
    }

    $zipPath = "$outDir/${userName}_vpn_package.zip"
    Compress-Archive -Path @($_.FullName, $azurevpn.FullName) -DestinationPath $zipPath

    # 📣 Slack 通知
    $payload = @{ text = "📦 `$userName` 用のVPNパッケージを作成しました！: $userName" } | ConvertTo-Json -Compress
    Invoke-RestMethod -Uri $slackWebhook -Method POST -ContentType 'application/json' -Body $payload
}
