@echo off
rem Double-click to start syncing the scripts into Roblox Studio.
rem Then in Studio: Plugins tab > Rojo > Connect. After that, every saved change
rem shows up in Studio by itself - just Stop and Play again to test it.
rem Leave this window open while you work (closing it stops the sync).
cd /d "%~dp0"
rojo.exe serve default.project.json --port 34872
pause
