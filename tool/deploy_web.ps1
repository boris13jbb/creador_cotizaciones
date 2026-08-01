#Requires -Version 5.1
# Build + (opcional) deploy Hosting. No ejecuta deploy sin -Deploy.
param(
  [switch]$Deploy,
  [string]$ProjectId = "cotiapp-saas-jb"
)

$ErrorActionPreference = "Stop"
Set-Location (Split-Path $PSScriptRoot -Parent)

Write-Host "==> flutter pub get"
flutter pub get
Write-Host "==> flutter build web --release"
flutter build web --release --no-wasm-dry-run

if ($Deploy) {
  Write-Host "==> firebase deploy --only hosting --project $ProjectId"
  firebase deploy --only hosting --project $ProjectId
} else {
  Write-Host "Build listo en build/web. Para publicar: .\tool\deploy_web.ps1 -Deploy"
}
