param(
  [Parameter(Mandatory=$true)][string]$SourceRoot,
  [Parameter(Mandatory=$true)][string]$KitRoot,
  [Parameter(Mandatory=$true)][string]$OutputRoot
)
$ErrorActionPreference = 'Stop'
$releaseDir = Join-Path $SourceRoot 'app\src-tauri\target\release'
if (-not (Test-Path -LiteralPath $releaseDir -PathType Container)) { throw "Release directory missing: $releaseDir" }
$exe = Join-Path $releaseDir 'app.exe'
if (-not (Test-Path -LiteralPath $exe -PathType Leaf)) {
  $candidates = @(Get-ChildItem -LiteralPath $releaseDir -Filter '*.exe' -File |
    Where-Object { $_.Name -match '(?i)telegram|drive' } | Sort-Object LastWriteTime -Descending)
  if ($candidates.Count -eq 1) { $exe = $candidates[0].FullName }
  else { throw "Cannot identify the single Telegram Drive EXE in $releaseDir. Refusing to bundle the wrong program." }
}
$patch = Join-Path $SourceRoot '.telegramdrive-phase1-patch.json'
if (-not (Test-Path -LiteralPath $patch -PathType Leaf)) { throw 'Phase 1 source marker missing.' }
if (Test-Path -LiteralPath $OutputRoot) { Remove-Item -LiteralPath $OutputRoot -Recurse -Force }
New-Item -ItemType Directory -Path $OutputRoot -Force | Out-Null
foreach ($name in @('AppState','Temp','LauncherLogs')) {
  New-Item -ItemType Directory -Path (Join-Path $OutputRoot "Data\$name") -Force | Out-Null
}
Copy-Item -LiteralPath $exe -Destination (Join-Path $OutputRoot 'TelegramDrive-Portable.exe') -Force
foreach ($name in @(
  'LAUNCH-TELEGRAMDRIVE-PORTABLE.cmd',
  'INSTALL-PORTABLE-STARTUP.cmd',
  'REMOVE-PORTABLE-STARTUP.cmd',
  'MIGRATE-OFFICIAL-DATA.ps1',
  'VERIFY-PORTABLE.ps1'
)) {
  $src = Join-Path $KitRoot "portable\$name"
  if (-not (Test-Path -LiteralPath $src)) { throw "Helper missing: $src" }
  Copy-Item -LiteralPath $src -Destination (Join-Path $OutputRoot $name) -Force
}
Copy-Item -LiteralPath $patch -Destination (Join-Path $OutputRoot 'PHASE1-PORTABILITY.json') -Force
$sha = (git -C $SourceRoot rev-parse HEAD).Trim()
Set-Content -LiteralPath (Join-Path $OutputRoot 'SOURCE-REVISION.txt') -Value $sha -Encoding ascii
Set-Content -LiteralPath (Join-Path $OutputRoot 'README-LIMITATIONS.txt') -Encoding UTF8 -Value @(
  'TELEGRAM DRIVE PHASE 1 - FILESYSTEM PORTABLE BUILD',
  'NOT FULLY PORTABLE. Windows Credential Manager remains in use.',
  'Telegram API hashes, proxy passwords and supporter-license material are NOT stored in this folder.',
  'You may need to enter credentials again after reinstalling Windows.',
  'Do not copy old installed app files while Telegram Drive is running.',
  'The vault passphrase and recovery materials are NOT recoverable from this package.',
  'This is an experimental unsigned executable. It has not been tested on a physical Windows system.',
  'WebView2 and Microsoft Visual C++ runtimes may need to be present in Windows.',
  'Do not use the upstream in-app updater; the portable patch blocks update checks/install.',
  'Keep separate backups; do not remove original AppData until complete acceptance testing.'
)
Write-Host "Assembled Phase 1 artifact: $OutputRoot" -ForegroundColor Green
