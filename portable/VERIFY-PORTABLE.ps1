$ErrorActionPreference = 'Continue'
$root = $PSScriptRoot
$outDir = Join-Path $root 'Verification'
New-Item -ItemType Directory -Path $outDir -Force | Out-Null
$report = Join-Path $outDir ('Check-'+(Get-Date -Format 'yyyyMMdd-HHmmss')+'.txt')
function L([string]$s='') { Add-Content -LiteralPath $report -Value $s -Encoding UTF8 }
L 'TELEGRAM DRIVE PHASE 1 - FILESYSTEM PORTABILITY DIAGNOSTIC'
L "Timestamp: $(Get-Date)"
L "Executable folder: $root"
L 'This report only lists paths and existence. It does not read secret values.'
L ''
foreach($relative in @(
  'TelegramDrive-Portable.exe',
  'Data\AppState',
  'Data\AppState\caches',
  'Data\AppState\logs',
  'Data\Temp',
  'PHASE1-PORTABILITY.json',
  'SOURCE-REVISION.txt'
)) {
  $p=Join-Path $root $relative
  L ("{0} exists={1}" -f $relative,(Test-Path -LiteralPath $p))
}
L ''
L 'Portable AppState files (NAMES ONLY, limited to 250):'
Get-ChildItem -LiteralPath (Join-Path $root 'Data\AppState') -Recurse -Force -File -ErrorAction SilentlyContinue |
 Select-Object -First 250 | ForEach-Object { L $_.FullName }
L ''
L 'Potential normal Windows AppData residue (may predate this build):'
foreach($p in @(
  (Join-Path $env:APPDATA 'com.cameronamer.telegramdrive'),
  (Join-Path $env:LOCALAPPDATA 'com.cameronamer.telegramdrive')
)) { L ("{0} exists={1}" -f $p,(Test-Path -LiteralPath $p)) }
L ''
L 'Credential limitation: Windows Credential Manager entries remain external to the portable folder.'
L 'No registry or app-data deletion has been performed.'
Write-Host "Verification report: $report" -ForegroundColor Cyan
Read-Host 'Press Enter to close' | Out-Null
