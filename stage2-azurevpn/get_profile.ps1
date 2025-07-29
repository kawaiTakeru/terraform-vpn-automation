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

# Check result and download ZIP
try {
    if (-Not (Test-Path $profileMetadata)) {
        throw "profile_metadata.json was not generated."
    }

    $json = Get-Content $profileMetadata | ConvertFrom-Json
    $zipUrl = $json.profileUrl

    if ([string]::IsNullOrWhiteSpace($zipUrl)) {
        throw "profileUrl is empty. Failed to obtain ZIP URL from VPN Gateway."
    }

    Invoke-WebRequest -Uri $zipUrl -OutFile $profileZip
}
catch {
    Write-Error $_
    exit 1
}
