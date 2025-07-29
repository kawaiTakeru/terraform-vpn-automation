$certs = "$(Build.ArtifactStagingDirectory)/certs"
$vpnZip = "$(Build.ArtifactStagingDirectory)/vpn/vpnprofile.zip"
$outDir = "$(Build.ArtifactStagingDirectory)/output"
$slackWebhook = $env:SLACK_WEBHOOK_URL  # ← Pipeline側でSecretとして登録

# 準備
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

# 展開して .azurevpn を取り出す
Expand-Archive -Path $vpnZip -DestinationPath "$outDir/unzipped"

# ZIPファイルを作成（pfx + .azurevpn）
Get-ChildItem "$certs/*.pfx" | ForEach-Object {
    $userName = $_.BaseName
    $azurevpn = Get-ChildItem "$outDir/unzipped" -Recurse -Filter "*.azurevpn" | Select-Object -First 1
    $zipPath = "$outDir/${userName}_vpn_package.zip"
    
    Compress-Archive -Path @($_.FullName, $azurevpn.FullName) -DestinationPath $zipPath

    # Slack通知
    $payload = @{ text = "📦 `$userName` 用のVPNパッケージを作成しました！: $userName" } | ConvertTo-Json -Compress
    Invoke-RestMethod -Uri $slackWebhook -Method POST -ContentType 'application/json' -Body $payload
}

