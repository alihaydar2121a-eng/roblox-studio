@echo off
rem Double-click to update from GitHub and start Rojo. Close the window (or Ctrl+C) to stop.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Sync-Ironfront.ps1" %*
if errorlevel 1 pause
