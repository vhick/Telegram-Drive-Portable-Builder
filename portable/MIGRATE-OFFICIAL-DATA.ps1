$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$target = Join-Path $root 'Data\AppState'
$backups = Join-Path $root 'MigrationBackups'
Write-Host 'Telegram Drive Phase 1 - copy installed application data' -ForegroundColor Cyan
Write-Host 'First close ALL Telegram Drive processes. Never migrate an open SQLite database.' -ForegroundColor Yellow
Write-Host 'This does not export Windows Credential Manager secrets.'
Write-Host ''
$answer = Read-Host 'Type CLOSED when Telegram Drive is fully closed'
if ($answer -cne 'CLOSED') { Write-Host 'Cancelled.'; exit 1 }
$known = @(
  (Join-Path $env:APPDATA 'com.cameronamer.telegramdrive'),
  (Join-Path $env:LOCALAPPDATA 'com.cameronamer.telegramdrive'),
  (Join-Path $env:APPDATA 'Telegram Drive'),
  (Join-Path $env:LOCALAPPDATA 'Telegram Drive')
)
$matches = @($known | Where-Object { Test-Path -LiteralPath $_ -PathType Container })
Write-Host 'Likely existing application-data folders:'
$matches | ForEach-Object { Write-Host ('  '+$_) }
Write-Host ''
$source = Read-Host 'Paste the FULL path to the original app-data folder to COPY (blank = cancel)'
if ([string]::IsNullOrWhiteSpace($source)) { Write-Host 'Cancelled.'; exit 0 }
$source = [IO.Path]::GetFullPath([Environment]::ExpandEnvironmentVariables($source.Trim('"')))
if (-not (Test-Path -LiteralPath $source -PathType Container)) { throw "Folder not found: $source" }
if ($source -ieq [IO.Path]::GetFullPath($target)) { throw 'Source is the portable target. Nothing to migrate.' }
$existing = @(Get-ChildItem -LiteralPath $target -Force -ErrorAction SilentlyContinue)
if ($existing.Count -gt 0) { throw 'Portable AppState already contains data. Migration stopped to prevent overwriting it.' }
New-Item -ItemType Directory -Path $backups,$target -Force | Out-Null
$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$backup = Join-Path $backups "BeforeMigration-$timestamp"
Write-Host "Backing up original data under: $backup"
& robocopy.exe "$source" "$backup" /E /COPY:DAT /DCOPY:DAT /XJ /R:1 /W:1 /NP /NFL /NDL /NJH /NJS | Out-Null
if ($LASTEXITCODE -ge 8) { throw "Backup failed (robocopy code $LASTEXITCODE)" }
Write-Host "Copying original AppData into: $target"
& robocopy.exe "$source" "$target" /E /COPY:DAT /DCOPY:DAT /XJ /R:1 /W:1 /NP /NFL /NDL /NJH /NJS | Out-Null
if ($LASTEXITCODE -ge 8) { throw "Copy failed (robocopy code $LASTEXITCODE)" }
Write-Host 'Copy completed. ORIGINAL SOURCE WAS NOT DELETED.' -ForegroundColor Green
Write-Host 'IMPORTANT: The backup and AppState may contain live Telegram sessions and confidential data.'
Write-Host 'If your old cache was separate, migrate it only after verifying its origin. Do NOT blindly merge two folders.'
Read-Host 'Press Enter to close' | Out-Null
