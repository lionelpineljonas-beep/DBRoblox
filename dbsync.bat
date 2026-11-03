@echo off
rem Double-click to start DBSync: it feeds the scripts in this folder to the DBSync
rem plugin in Roblox Studio, which updates them by itself every second.
rem Leave this window open while you work (closing it stops the sync).
cd /d "%~dp0"
title DBSync server
python dbsync.py
pause
