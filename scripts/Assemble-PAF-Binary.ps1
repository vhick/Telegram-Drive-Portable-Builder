param(
  [Parameter(Mandatory=$true)][string]$SourceRoot,
  [Parameter(Mandatory=$true)][string]$OutputRoot
)
$ErrorActionPreference = 'Stop'
$release = Join-Path $SourceRoot 'app\src-tauri\target\release'
$exe = Join-Path $release 'app.exe'
if (-not (Test-Path -LiteralPath $exe -PathType Leaf)) {
  $matches = @(Get-ChildItem -LiteralPath $release -Filter '*.exe' -File -ErrorAction Stop |
    Where-Object { $_.Name -match '(?i)telegram|drive' })
  if ($matches.Count -ne 1) { throw 'Could not safely identify the one Telegram Drive EXE.' }
  $exe = $matches[0].FullName
}
$marker=Join-Path $SourceRoot '.telegramdrive-paf-patch.json'
if (-not (Test-Path -LiteralPath $marker)) { throw 'PAF source marker is missing.' }
New-Item -ItemType Directory -Force -Path $OutputRoot | Out-Null
Copy-Item -LiteralPath $exe -Destination (Join-Path $OutputRoot 'TelegramDrive-Portable.exe') -Force
Copy-Item -LiteralPath $marker -Destination (Join-Path $OutputRoot 'PAF-PATH-BUILD.json') -Force
Set-Content -LiteralPath (Join-Path $OutputRoot 'INSTALL-INSTRUCTIONS.txt') -Encoding UTF8 -Value @(
 'PAF-specific Telegram Drive build. This EXE is NOT standalone.',
 'COPY TelegramDrive-Portable.exe into TelegramDrivePortable\App\TelegramDrive\',
 'The app requires that exact App\TelegramDrive layout.',
 'It writes directly to TelegramDrivePortable\Data\AppState and Data\Temp.',
 'DO NOT create an App\TelegramDrive\Data folder or junction.',
 'API hashes, proxy passwords and supporter credentials still use Windows Credential Manager.',
 'Do not replace the executable in your standalone Phase 1 folder with this PAF build.'
)
Write-Host 'PASS: PAF-specific executable artifact ready.' -ForegroundColor Green
