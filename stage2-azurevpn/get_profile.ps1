$resourceGroup = "rg-test-hubnw-prd-jpe-001"
$gatewayName = "vpngw-test-hubnw-prd-jpe-001"
$outputDir = "$env:BUILD_ARTIFACTSTAGINGDIRECTORY/vpn"
$profileMetadata = "$outputDir/profile_metadata.json"
$profileZip = "$outputDir/vpnprofile.zip"

# Create output directory
New-Item -ItemType Directory -Force -Path $outputDir | Out-Null

# Generate VPN client profile metadata JSON
az network vnet-gateway vpn-client generate `
  --resource-group $resourceGroup `
  --name $gatewayName `
  --processor-architecture Amd64 `
  --authentication-method EAPTLS `
  --output json `
  > $profileMetadata

# If metadata JSON exists, proceed
if (Test-Path $profileMetadata) {
    $zipUrl = (Get-Content $profileMetadata | ConvertFrom-Json).profileUrl

    if (![string]::IsNullOrWhiteSpace($zipUrl)) {
        Invoke-WebRequest -Uri $zipUrl -OutFile $profileZip
    } else {
        throw "profileUrl is empty. Failed to obtain ZIP URL from VPN Gateway."
    }
} else {
    throw "profile_metadata.json not found. VPN Gateway profile metadata was not generated."
}
