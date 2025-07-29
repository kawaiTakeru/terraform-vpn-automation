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

try {
    if (-Not (Test-Path $profileMetadata)) {
        throw "profile_metadata.json が生成されていません。"
    }

    $json = Get-Content $profileMetadata | ConvertFrom-Json
    $zipUrl = $json.profileUrl

    if ([string]::IsNullOrWhiteSpace($zipUrl)) {
        throw "profileUrl is empty. VPN Gateway から ZIP URL を取得できませんでした。"
    }

    Invoke-WebRequest -Uri $zipUrl -OutFile $profileZip
}
catch {
    Write-Error $_
    exit 1
}
