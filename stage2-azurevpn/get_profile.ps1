# リソース情報
$resourceGroup = "rg-test-hubnw-prd-jpe-001"
$gatewayName = "vpngw-test-hubnw-prd-jpe-001"
$outputDir = "$(Build.ArtifactStagingDirectory)/vpn"

# 出力先作成
New-Item -ItemType Directory -Force -Path $outputDir | Out-Null

# ZIP生成（.azurevpn含む）
az network vpn-client generate \
  --resource-group $resourceGroup `
  --name $gatewayName `
  --processor-architecture Amd64 `
  --authentication-method EAPTLS `
  --output json > "$outputDir/profile_metadata.json"

# ZIP URLの取得
$zipUrl = (Get-Content "$outputDir/profile_metadata.json" | ConvertFrom-Json).profileUrl

# ZIPダウンロード
Invoke-WebRequest -Uri $zipUrl -OutFile "$outputDir/vpnprofile.zip"

