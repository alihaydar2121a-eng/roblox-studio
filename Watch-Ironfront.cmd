@echo off
rem Double-click to check GitHub every 60 s and pull safe updates. Ctrl+C to stop.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Watch-Ironfront.ps1" %*
if errorlevel 1 pause
