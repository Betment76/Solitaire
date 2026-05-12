@echo off
chcp 65001 >nul
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0pepk_rustore.ps1"
set RC=%ERRORLEVEL%
if %RC% neq 0 pause
exit /b %RC%
