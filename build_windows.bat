@echo off
REM Compila para Windows (si falla Git, ejecuta CONFIGURAR_GIT_PATH.bat como Admin)
set "PATH=C:\Program Files\Git\cmd;C:\Program Files\Git\bin;%PATH%"
cd /d "%~dp0"
flutter build windows
if errorlevel 1 pause
