@echo off
setlocal EnableExtensions
title Telegram Drive Portable Startup
set "ROOT=%~dp0"
set "LAUNCHER=%ROOT%LAUNCH-TELEGRAMDRIVE-PORTABLE.cmd"
if not exist "%LAUNCHER%" (
  echo Missing launcher. Keep this script in the portable program folder.
  pause
  exit /b 1
)
set "VBS=%ROOT%Data\Start-TelegramDrive-Hidden.vbs"
if not exist "%ROOT%Data" mkdir "%ROOT%Data" >nul 2>&1
>"%VBS%" echo Set sh = CreateObject("WScript.Shell")
>>"%VBS%" echo sh.Run Chr(34) ^& "%LAUNCHER%" ^& Chr(34), 0, False
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ErrorActionPreference='Stop'; $dir=[Environment]::GetFolderPath('Startup'); $link=Join-Path $dir 'TelegramDrive-Portable.lnk'; $shell=New-Object -ComObject WScript.Shell; $s=$shell.CreateShortcut($link); $s.TargetPath=$env:WINDIR+'\System32\wscript.exe'; $s.Arguments='"%VBS%"'; $s.WorkingDirectory='%ROOT%'; $s.Description='Telegram Drive filesystem-portable Phase 1'; $s.Save(); Write-Host ('Startup shortcut created: '+$link)"
if errorlevel 1 (
  echo Startup creation FAILED.
) else (
  echo Startup registration complete. This is a user-level shortcut, not an application data store.
)
pause
