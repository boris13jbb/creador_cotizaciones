@echo off
REM Compila APK para Android
REM Ejecuta el parche de path_provider_android antes de compilar
cd /d "%~dp0"

echo Aplicando parche para path_provider_android...
call tool\patch_path_provider_android.bat

echo Limpiando cache de compilacion...
call flutter clean
call flutter pub get

echo Compilando APK...
call flutter build apk

if errorlevel 1 pause
