@echo off
setlocal EnableExtensions
title Telegram Drive Portable - Phase 1
set "ROOT=%~dp0"
set "EXE=%ROOT%TelegramDrive-Portable.exe"
set "TEMP=%ROOT%Data\Temp"
set "TMP=%TEMP%"
set "LOGDIR=%ROOT%Data\LauncherLogs"
if not exist "%TEMP%" mkdir "%TEMP%" >nul 2>&1
if not exist "%LOGDIR%" mkdir "%LOGDIR%" >nul 2>&1
>>"%LOGDIR%\launcher.log" echo [%date% %time%] Start requested for %EXE%
if not exist "%EXE%" (
  echo ERROR: Cannot find TelegramDrive-Portable.exe beside this launcher.
  pause
  exit /b 1
)
start "" "%EXE%"
exit /b 0
