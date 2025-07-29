$resourceGroup = "rg-test-hubnw-prd-jpe-001"
$gatewayName = "vnet-gateway"
$outputDir = "$env:BUILD_ARTIFACTSTAGINGDIRECTORY/vpn"
$profileUrlFile = "$outputDir/profile_url.txt"
$profileZip = "$outputDir/vpnprofile.zip"
$rawOutput = "$outputDir/raw_output.json"

Write-Host "🛠 Step 1: Creating output directory: $outputDir"
New-Item -ItemType Directory -Force -Path $outputDir | Out-Null

Write-Host "🚀 Step 2: Executing az network vnet-gateway vpn-client generate"
$rawUrl = az network vnet-gateway vpn-client generate `
  --resource-group $resourceGroup `
  --name $gatewayName `
  --processor-architecture Amd64 `
  --authentication-method EAPTLS `
  --output json

Write-Host "🧪 Step 2.5: Raw output from az command"
Write-Host $rawUrl

Write-Host "📄 Step 3: Saving URL to files"
$rawUrl | Out-File -Encoding utf8 $rawOutput
$rawUrl | Out-File -Encoding utf8 $profileUrlFile

Write-Host "🔍 Step 4: Validating and downloading VPN ZIP"
try {
    if ([string]::IsNullOrWhiteSpace($rawUrl)) {
        throw "❌ Error: VPN profile URL is empty."
    }

    $cleanUrl = $rawUrl -replace '"', ''  # 余計なダブルクォート削除
    Write-Host "🧾 Cleaned profileUrl: $cleanUrl"
    
    Write-Host "📦 Step 5: Downloading VPN ZIP..."
    Invoke-WebRequest -Uri $cleanUrl -OutFile $profileZip
    Write-Host "✅ Success: VPN profile ZIP downloaded to $profileZip"
}
catch {
    Write-Error "❌ Exception occurred: $_"
    exit 1
}
