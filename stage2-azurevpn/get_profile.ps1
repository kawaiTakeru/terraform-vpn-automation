$resourceGroup = "rg-test-hubnw-prd-jpe-001"
$gatewayName = "vpngw-test-hubnw-prd-jpe-001"
$outputDir = "$env:BUILD_ARTIFACTSTAGINGDIRECTORY/vpn"
$profileMetadata = "$outputDir/profile_metadata.json"
$profileZip = "$outputDir/vpnprofile.zip"

# 出力先フォルダ作成
New-Item -ItemType Directory -Force -Path $outputDir | Out-Null

# 拡張機能追加（既にある場合はスキップされる）
az extension add --name vpn-gateway --only-show-errors

# VPN クライアント構成メタデータ取得（JSON に profileUrl 含まれる）
az network vpn-gateway vpn-client generate `
--resource-group $resourceGroup `
--name $gatewayName `
--processor-architecture Amd64 `
--authentication-method EAPTLS `
--output json `
> $profileMetadata

# JSON が存在していれば
if (Test-Path $profileMetadata) {
    $zipUrl = (Get-Content $profileMetadata | ConvertFrom-Json).profileUrl

    if (![string]::IsNullOrWhiteSpace($zipUrl)) {
        # ZIPをダウンロード
        Invoke-WebRequest -Uri $zipUrl -OutFile $profileZip
    } else {
        Write-Error "profileUrl is empty. VPN Gateway から ZIP URL を取得できませんでした。"
    }
} else {
    Write-Error "profile_metadata.json が生成されていません。"
}
