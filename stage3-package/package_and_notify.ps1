# ✅ パス設定（BUILD_ARTIFACTSTAGINGDIRECTORY に統一）
$certs        = "$env:BUILD_ARTIFACTSTAGINGDIRECTORY/certs"
$vpnZip       = "$env:BUILD_ARTIFACTSTAGINGDIRECTORY/vpn/vpnprofile.zip"
$outDir       = "$env:BUILD_ARTIFACTSTAGINGDIRECTORY/output"
$unzipDir     = "$outDir/unzipped"
$slackWebhook = $env:SLACK_WEBHOOK_URL

Write-Host "📂 証明書ディレクトリ: $certs"
Write-Host "📦 VPN ZIP ファイル: $vpnZip"
Write-Host "📁 出力先ディレクトリ: $outDir"

# 🔧 出力ディレクトリ作成
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

# 🔍 VPN ZIPファイルが存在するか確認
if (-not (Test-Path $vpnZip)) {
    Write-Error "❌ VPN ZIP が見つかりません: $vpnZip"
    exit 1
}

Write-Host "🧩 VPN ZIP を展開します: $vpnZip"
Expand-Archive -Path $vpnZip -DestinationPath $unzipDir -Force

# 🔍 展開後ファイル確認
$vpnFiles = Get-ChildItem "$unzipDir" -Recurse
Write-Host "📑 展開されたファイル:"
$vpnFiles | ForEach-Object { Write-Host " - $_" }

# 🧪 各ユーザーの pfx を処理
$pfxList = Get-ChildItem "$certs/*.pfx"
if (-not $pfxList) {
    Write-Error "❌ .pfx ファイルが見つかりません: $certs/*.pfx"
    exit 1
}

foreach ($pfx in $pfxList) {
    $userName = $pfx.BaseName
    Write-Host "👤 対象ユーザー: $userName"
    Write-Host "🔑 PFXファイル: $($pfx.FullName)"

    $azurevpn = Get-ChildItem "$unzipDir" -Recurse -Filter "*.azurevpn" | Select-Object -First 1
    if (-not $azurevpn) {
        Write-Error "❌ .azurevpn ファイルが見つかりませんでした in $unzipDir"
        continue
    }

    Write-Host "🌐 .azurevpn ファイル: $($azurevpn.FullName)"

    $zipPath = "$outDir/${userName}_vpn_package.zip"
    Write-Host "📦 ZIP作成: $zipPath"

    Compress-Archive -Path @($pfx.FullName, $azurevpn.FullName) -DestinationPath $zipPath -Force

    # 📣 Slack 通知
    $payload = @{ text = "✅ `$userName` 用 VPNパッケージを作成しました: $userName" } | ConvertTo-Json -Compress
    Invoke-RestMethod -Uri $slackWebhook -Method POST -ContentType 'application/json' -Body $payload
    Write-Host "📤 Slack 通知を送信しました。"
}
