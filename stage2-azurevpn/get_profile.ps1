$resourceGroup = "rg-test-hubnw-prd-jpe-001"
$gatewayName = "vpngw-test-hubnw-prd-jpe-001"
$outputDir = "$env:BUILD_ARTIFACTSTAGINGDIRECTORY/vpn"
$profileMetadata = "$outputDir/profile_metadata.json"
$profileZip = "$outputDir/vpnprofile.zip"

# 出力先フォルダ作成
New-Item -ItemType Directory -Force -Path $outputDir | Out-Null

# VPN クライアント構成メタデータ取得
=======
# VPN クライアント構成メタデータ取得（profileUrl が含まれる JSON）
az network vnet-gateway vpn-client generate `
  --resource-group $resourceGroup `
  --name $gatewayName `
  --processor-architecture Amd64 `
  --authentication-method EAPTLS `
  --output json `
  > $profileMetadata

# JSON が存在していれば処理続行
if (Test-Path $profileMetadata) {
    $zipUrl = (Get-Content $profileMetadata | ConvertFrom-Json).profileUrl

    if (![string]::IsNullOrWhiteSpace($zipUrl)) {
        Invoke-WebRequest -Uri $zipUrl -OutFile $profileZip
    } else {
        Write-Error "profileUrl is empty. VPN Gateway から ZIP URL を取得できませんでした。"
    }
} else {
    Write-Error "profile_metadata.json が生成されていません。"
}
