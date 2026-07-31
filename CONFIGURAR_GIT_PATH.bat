@echo off
REM Ejecutar como Administrador: clic derecho -^> Ejecutar como administrador
REM Agrega Git al PATH del sistema para compilacion Flutter Windows

echo Agregando Git al PATH del sistema...
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$p=[Environment]::GetEnvironmentVariable('Path','Machine'); ^
   if ($p -notlike '*Git\cmd*') { ^
     [Environment]::SetEnvironmentVariable('Path','C:\Program Files\Git\cmd;C:\Program Files\Git\bin;'+$p,'Machine'); ^
     Write-Host 'Listo. Cierra Cursor y vuelve a abrirlo.' -ForegroundColor Green ^
   } else { Write-Host 'Git ya esta en PATH.' -ForegroundColor Yellow }"
if errorlevel 1 echo ERROR: Ejecuta como Administrador.
pause
