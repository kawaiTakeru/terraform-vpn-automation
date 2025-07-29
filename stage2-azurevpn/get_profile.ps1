# リソース情報
$resourceGroup = "rg-test-hubnw-prd-jpe-001"
$gatewayName = "vpngw-test-hubnw-prd-jpe-001"
$outputDir = "$env:BUILD_ARTIFACTSTAGINGDIRECTORY/vpn"
$profileMetadata = "$outputDir/profile_metadata.json"
$profileZip = "$outputDir/vpnprofile.zip"

# 出力先作成
New-Item -ItemType Directory -Force -Path $outputDir | Out-Null

# 拡張機能の追加（初回のみ）
& az extension add --name vpn-gateway

# VPNクライアント構成ファイルの生成
& az network vpn-gateway vpn-client generate `
    --resource-group $resourceGroup `
    --name $gatewayName `
    --processor-architecture Amd64 `
    --authentication-method EAPTLS `
    --output json `
    > $profileMetadata

# ZIP URLの取得
if (Test-Path $profileMetadata) {
    $zipUrl = (Get-Content $profileMetadata | ConvertFrom-Json).profileUrl

    if (![string]::IsNullOrWhiteSpace($zipUrl)) {
        # ZIPダウンロード
        Invoke-WebRequest -Uri $zipUrl -OutFile $profileZip
    } else {
        Write-Error "profileUrl is empty. VPN Gateway から URL を取得できませんでした。"
    }
} else {
    Write-Error "metadata JSON ファイルが作成されていません。"
}
