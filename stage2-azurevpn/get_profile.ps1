$resourceGroup = "rg-test-hubnw-prd-jpe-001"
$gatewayName = "vnet-gateway"
$outputDir = "$env:BUILD_ARTIFACTSTAGINGDIRECTORY/vpn"
$profileMetadata = "$outputDir/profile_metadata.json"
$profileZip = "$outputDir/vpnprofile.zip"
$rawOutput = "$outputDir/raw_output.json"

# 作業ディレクトリの作成
New-Item -ItemType Directory -Force -Path $outputDir | Out-Null

# VPNクライアント構成の生成とログ出力（Teeで2か所に出力）
az network vnet-gateway vpn-client generate `
  --resource-group $resourceGroup `
  --name $gatewayName `
  --processor-architecture Amd64 `
  --authentication-method EAPTLS `
  --output json `
  | Tee-Object -FilePath $rawOutput `
  > $profileMetadata

# ZIP URLのバリデーションとダウンロード処理
try {
    if (-Not (Test-Path $profileMetadata)) {
        throw "❌ profile_metadata.json was not生成できませんでした。"
    }

    $json = Get-Content $profileMetadata | ConvertFrom-Json
    $zipUrl = $json.profileUrl

    if ([string]::IsNullOrWhiteSpace($zipUrl)) {
        throw "❌ profileUrl is空です。VPN Gateway から ZIP URL を取得できませんでした。"
    }

    Invoke-WebRequest -Uri $zipUrl -OutFile $profileZip
    Write-Host "✅ VPNクライアント構成 ZIP をダウンロードしました: $profileZip"
}
catch {
    Write-Error $_
    exit 1
}
