@echo off
REM Sirve la app web compilada en http://localhost:8080

cd /d "%~dp0"

if not exist "build\web\index.html" (
    echo Compilando primero...
    call flutter build web
)

cd build\web
echo.
echo App disponible en: http://localhost:8080
echo Presiona Ctrl+C para detener.
echo.
python -m http.server 8080
