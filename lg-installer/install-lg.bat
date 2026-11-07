@echo off
title MyMoviz Plus - LG TV installer
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install-lg.ps1" %*
echo.
pause
