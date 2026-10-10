@echo off
setlocal
title Remove Telegram Drive Portable Startup
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
  "$link=Join-Path ([Environment]::GetFolderPath('Startup')) 'TelegramDrive-Portable.lnk'; if(Test-Path -LiteralPath $link){Remove-Item -LiteralPath $link -Force;Write-Host ('Removed: '+$link)}else{Write-Host 'Portable startup is already absent.'}"
pause
