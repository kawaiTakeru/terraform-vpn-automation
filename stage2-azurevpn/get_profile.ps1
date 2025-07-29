$resourceGroup = "rg-test-hubnw-prd-jpe-001"
$gatewayName = "vpngw-test-hubnw-prd-jpe-001"
$outputDir = "$env:BUILD_ARTIFACTSTAGINGDIRECTORY/vpn"
$profileMetadata = "$outputDir/profile_metadata.json"
$profileZip = "$outputDir/vpnprofile.zip"

New-Item -ItemType Directory -Force -Path $outputDir | Out-Null

az network vnet-gateway vpn-client generate `
  --resource-group $resourceGroup `
  --name $gatewayName `
  --processor-architecture Amd64 `
  --authentication-method EAPTLS `
  --output json `
  > $profileMetadata

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
