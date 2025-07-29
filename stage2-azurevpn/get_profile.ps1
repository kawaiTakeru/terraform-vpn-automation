$resourceGroup = "rg-test-hubnw-prd-jpe-001"
$gatewayName = "vnet-gateway"
$outputDir = "$env:BUILD_ARTIFACTSTAGINGDIRECTORY/vpn"
$profileMetadata = "$outputDir/profile_metadata.json"
$profileZip = "$outputDir/vpnprofile.zip"
$rawOutput = "$outputDir/raw_output.json"

Write-Host "🛠 Step 1: Creating output directory: $outputDir"
New-Item -ItemType Directory -Force -Path $outputDir | Out-Null

Write-Host "🚀 Step 2: Executing az network vnet-gateway vpn-client generate"
$rawJson = az network vnet-gateway vpn-client generate `
  --resource-group $resourceGroup `
  --name $gatewayName `
  --processor-architecture Amd64 `
  --authentication-method EAPTLS `
  --output json

Write-Host "📄 Step 3: Saving JSON output to files"
$rawJson | Out-File -Encoding utf8 $rawOutput
$rawJson | Out-File -Encoding utf8 $profileMetadata

Write-Host "🔍 Step 4: Reading profileUrl from metadata"
try {
    if (-Not (Test-Path $profileMetadata)) {
        throw "❌ Error: profile_metadata.json was not generated."
    }

    $json = Get-Content $profileMetadata | ConvertFrom-Json
    $zipUrl = $json.profileUrl

    if ([string]::IsNullOrWhiteSpace($zipUrl)) {
        throw "❌ Error: profileUrl is empty. Could not retrieve VPN ZIP URL."
    }

    Write-Host "🧾 profileUrl: $zipUrl"
    Write-Host "📦 Step 5: Downloading VPN ZIP file..."
    Invoke-WebRequest -Uri $zipUrl -OutFile $profileZip
    Write-Host "✅ Success: VPN profile ZIP downloaded to $profileZip"
}
catch {
    Write-Error "❌ Exception occurred: $_"
    exit 1
}
