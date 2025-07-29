# リソース情報
$resourceGroup = "rg-test-hubnw-prd-jpe-001"
$gatewayName = "vpngw-test-hubnw-prd-jpe-001"
$outputDir = "$env:BUILD_ARTIFACTSTAGINGDIRECTORY/vpn"
$profileMetadata = "$outputDir/profile_metadata.json"
$profileZip = "$outputDir/vpnprofile.zip"

# 出力先作成
New-Item -ItemType Directory -Force -Path $outputDir | Out-Null

# VPNクライアント構成ファイルの生成
& az network vpn-client generate `
    --resource-group $resourceGroup `
    --name $gatewayName `
    --processor-architecture Amd64 `
    --authentication-method EAPTLS `
    --output json `
    > $profileMetadata

# ZIP URLの取得とダウンロード
$zipUrl = (Get-Content $profileMetadata | ConvertFrom-Json).profileUrl
Invoke-WebRequest -Uri $zipUrl -OutFile $profileZip
