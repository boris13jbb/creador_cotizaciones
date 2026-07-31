@echo off
REM Parchea path_provider_android para evitar EvalIssueException
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0patch_path_provider_android.ps1"
