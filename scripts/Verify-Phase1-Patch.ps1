param([Parameter(Mandatory=$true)][string]$SourceRoot)
$ErrorActionPreference = 'Stop'
$app = Join-Path $SourceRoot 'app'
$main = Get-Content -LiteralPath (Join-Path $app 'src-tauri\src\main.rs') -Raw
$updates = Get-Content -LiteralPath (Join-Path $app 'src\hooks\useUpdateCheck.ts') -Raw
$schema = Join-Path $app 'node_modules\@tauri-apps\cli\config.schema.json'
if (-not (Test-Path -LiteralPath $schema)) { throw 'Tauri CLI config schema missing.' }
$schemaText = Get-Content -LiteralPath $schema -Raw
if (-not $schemaText.Contains('"appDirectoriesOverride"')) { throw 'Tauri CLI lacks appDirectoriesOverride support.' }
$lockFile = Join-Path $app 'src-tauri\Cargo.lock'
if (-not (Test-Path -LiteralPath $lockFile)) { throw 'Rust Cargo.lock missing.' }
$lockText = Get-Content -LiteralPath $lockFile -Raw
function Get-Version([string]$Name) {
  $rx = '(?ms)\[\[package\]\]\s*name\s*=\s*"' + [regex]::Escape($Name) + '"\s*version\s*=\s*"([^\"]+)"'
  $m = [regex]::Match($lockText, $rx)
  if (-not $m.Success) { throw "Rust package missing: $Name" }
  return [version]$m.Groups[1].Value
}
$tauri = Get-Version 'tauri'
$utils = Get-Version 'tauri-utils'
Write-Host "Rust tauri: $tauri | tauri-utils: $utils"
if ($tauri -lt [version]'2.12.0' -or $utils -lt [version]'2.10.0') {
  throw 'Tauri Rust crates do not support the portable directory override.'
}
foreach ($check in @(
  @{Ok=$main.Contains('TELEGRAMDRIVE_PORTABLE_TEMP_V1'); Name='early TEMP setup'},
  @{Ok=$main.Contains('app_lib::run()'); Name='original entrypoint preserved'},
  @{Ok=$updates.Contains('TELEGRAMDRIVE_PORTABLE_UPDATER_V1'); Name='updater disabled'},
  @{Ok=$updates.Contains('if (PORTABLE_UPDATES_DISABLED)'); Name='manual updater guard'},
  @{Ok=(Test-Path (Join-Path $SourceRoot '.telegramdrive-phase1-patch.json')); Name='build marker'}
)) {
  if (-not $check.Ok) { throw "Verification FAILED: $($check.Name)" }
  Write-Host "PASS: $($check.Name)" -ForegroundColor Green
}
Write-Host 'Verified source patch; Windows credential manager intentionally unchanged.'
