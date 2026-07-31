# Parchea path_provider_android para evitar EvalIssueException con AGP 8.7+
# Ejecutar antes de: flutter build apk

$paths = @(
    "$env:LOCALAPPDATA\Pub\Cache\hosted\pub.dev\path_provider_android-2.2.19\android\build.gradle",
    "$env:USERPROFILE\.pub-cache\hosted\pub.dev\path_provider_android-2.2.19\android\build.gradle"
)
$pluginPath = $paths | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $pluginPath) {
    Write-Host "path_provider_android no encontrado en cache."
    exit 1
}

$content = Get-Content $pluginPath -Raw
if ($content -match "compileSdk = 34") {
    Write-Host "Parche ya aplicado."
    exit 0
}

$content = $content -replace "compileSdk = flutter\.compileSdkVersion", "compileSdk = 34"
Set-Content $pluginPath $content -NoNewline
Write-Host "Parche aplicado a path_provider_android."
