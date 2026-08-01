#Requires -Version 5.1
<#
.SYNOPSIS
  Validación go-live CotiApp. Opcionalmente despliega Firebase.
.PARAMETER Deploy
  Tras validar, despliega hosting + rules + indexes + storage + functions.
.PARAMETER SkipTests
  Omite flutter test (más rápido).
#>
param(
  [switch]$Deploy,
  [switch]$SkipTests,
  [string]$ProjectId = "cotiapp-saas-jb"
)

$ErrorActionPreference = "Stop"
$root = Split-Path $PSScriptRoot -Parent
Set-Location $root

function Step($msg) { Write-Host "`n==> $msg" -ForegroundColor Cyan }

Step "flutter pub get"
flutter pub get
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Step "flutter analyze"
flutter analyze
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

if (-not $SkipTests) {
  Step "flutter test"
  flutter test
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

Step "flutter build web --release"
flutter build web --release --no-wasm-dry-run
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Step "functions npm run build"
Push-Location functions
npm run build
if ($LASTEXITCODE -ne 0) { Pop-Location; exit $LASTEXITCODE }
Pop-Location

Write-Host "`nValidación local OK. Artefacto web en build/web" -ForegroundColor Green
Write-Host "Checklist: docs/PRODUCTION_CHECKLIST.md"

if (-not $Deploy) {
  Write-Host "Para desplegar: .\tool\golive.ps1 -Deploy"
  exit 0
}

Write-Host "`nVas a desplegar en proyecto $ProjectId (hosting, rules, indexes, storage, functions)." -ForegroundColor Yellow
$confirm = Read-Host "Escribe DEPLOY para continuar"
if ($confirm -ne "DEPLOY") {
  Write-Host "Deploy cancelado."
  exit 1
}

Step "firebase deploy"
firebase deploy --only hosting,firestore:rules,firestore:indexes,storage,functions --project $ProjectId
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "`nDeploy completado. Verifica https://$ProjectId.web.app" -ForegroundColor Green
Write-Host "Rollback: docs/BACKUP_ROLLBACK.md"
