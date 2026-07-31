# Activa Firestore + reglas SaaS en ambos proyectos.
# Requisito: billing (Blaze) habilitado en cotiapp-saas-jb y cvmaker-saas-jb.
$ErrorActionPreference = "Stop"

function Deploy-SaasProject {
  param(
    [Parameter(Mandatory = $true)][string]$ProjectId,
    [Parameter(Mandatory = $true)][string]$ProjectDir
  )

  Write-Host ""
  Write-Host "=== $ProjectId ===" -ForegroundColor Cyan
  Set-Location $ProjectDir

  Write-Host "Desplegando firestore.rules..."
  firebase deploy --only firestore:rules --project $ProjectId --non-interactive
  if ($LASTEXITCODE -ne 0) {
    throw "Fallo deploy de reglas en $ProjectId. ¿Billing activo y Firestore creado?"
  }
  Write-Host "OK $ProjectId" -ForegroundColor Green
}

Write-Host "Abriendo facturación (completa el vínculo de billing si aún no lo hiciste)..."
Start-Process "https://console.firebase.google.com/project/cotiapp-saas-jb/usage/details"
Start-Process "https://console.firebase.google.com/project/cvmaker-saas-jb/usage/details"
Start-Process "https://console.firebase.google.com/project/cotiapp-saas-jb/firestore"
Start-Process "https://console.firebase.google.com/project/cvmaker-saas-jb/firestore"

Write-Host ""
Write-Host "Si Firestore no existe: en la consola pulsa 'Create database' (modo production, ubicación nam5)."
Write-Host "Luego vuelve a este script o dime 'listo billing' en el chat."
Write-Host ""

Deploy-SaasProject -ProjectId "cotiapp-saas-jb" -ProjectDir "D:\creador_cotizaciones"
Deploy-SaasProject -ProjectId "cvmaker-saas-jb" -ProjectDir "D:\creador_cv"

Write-Host ""
Write-Host "Listo. Prueba:" -ForegroundColor Green
Write-Host "  cd D:\creador_cotizaciones; flutter run -d windows"
Write-Host "  cd D:\creador_cv; flutter run -d windows"
