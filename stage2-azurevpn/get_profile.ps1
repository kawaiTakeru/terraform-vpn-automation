$resourceGroup = "rg-test-hubnw-prd-jpe-001"
$gatewayName = "vnet-gateway"
$outputDir = "$env:BUILD_ARTIFACTSTAGINGDIRECTORY/vpn"
$profileMetadata = "$outputDir/profile_metadata.json"
$profileZip = "$outputDir/vpnprofile.zip"
$rawOutput = "$outputDir/raw_output.json"

Write-Host "🔧 Step 1: 作業ディレクトリ作成: $outputDir"
New-Item -ItemType Directory -Force -Path $outputDir | Out-Null

Write-Host "📡 Step 2: VPN Gateway から JSON 出力を取得中..."
try {
    $rawJson = az network vnet-gateway vpn-client generate `
      --resource-group $resourceGroup `
      --name $gatewayName `
      --processor-architecture Amd64 `
      --authentication-method EAPTLS `
      --output json

    if ([string]::IsNullOrWhiteSpace($rawJson)) {
        throw "❌ Step 2 failed: azコマンドの出力が空です。VPN Gatewayに失敗した可能性があります。"
    }

    Write-Host "✅ Step 2 success: 出力取得完了。JSON保存中..."

    $rawJson | Out-File -Encoding utf8 $rawOutput
    $rawJson | Out-File -Encoding utf8 $profileMetadata
    Write-Host "📝 Step 3: JSON保存完了 → raw: $rawOutput / metadata: $profileMetadata"
}
catch {
    Write-Error "❌ Step 2 error: az実行時のエラー: $_"
    exit 1
}

Write-Host "🔍 Step 4: JSON読み込みと profileUrl 抽出"
try {
    if (-Not (Test-Path $profileMetadata)) {
        throw "❌ Step 4 failed: profile_metadata.json が存在しません"
    }

    $json = Get-Content $profileMetadata | ConvertFrom-Json
    $zipUrl = $json.profileUrl

    Write-Host "🧾 profileUrl 抽出結果: $zipUrl"

    if ([string]::IsNullOrWhiteSpace($zipUrl)) {
        throw "❌ Step 4 failed: profileUrl が空です。VPN Gateway がZIP URLを返していません。"
    }
}
catch {
    Write-Error "❌ Step 4 error: JSON読み込み/パースに失敗しました: $_"
    exit 1
}

Write-Host "📥 Step 5: ZIPファイルのダウンロード開始..."
try {
    Invoke-WebRequest -Uri $zipUrl -OutFile $profileZip
    Write-Host "✅ Step 5 success: VPN ZIP ダウンロード完了: $profileZip"
}
catch {
    Write-Error "❌ Step 5 error: ZIPダウンロード失敗: $_"
    exit 1
}
