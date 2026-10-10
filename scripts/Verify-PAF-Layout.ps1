param([Parameter(Mandatory=$true)][string]$SourceRoot)
$ErrorActionPreference = 'Stop'
$main = Get-Content -LiteralPath (Join-Path $SourceRoot 'app\src-tauri\src\main.rs') -Raw
$configuration = Join-Path $PSScriptRoot '..\portable\tauri.paf.conf.json'
$config = Get-Content -LiteralPath $configuration -Raw | ConvertFrom-Json
if ($config.app.appDirectoriesOverride -ne '../../Data/AppState') { throw 'Tauri PAF relative path is incorrect.' }
if (-not $main.Contains('TELEGRAMDRIVE_PAF_DATA_V1')) { throw 'PAF code marker missing.' }
if (-not $main.Contains('let data = portable_root.join("Data");')) { throw 'Missing top-level Data path.' }
if ($main.Contains('let data = exe_dir.join("Data");')) { throw 'Legacy exe-adjacent path remains.' }
if (-not $main.Contains('Some("TelegramDrive")') -or -not $main.Contains('Some("App")')) { throw 'PAF layout guard missing.' }
if (-not (Test-Path -LiteralPath (Join-Path $SourceRoot '.telegramdrive-paf-patch.json'))) { throw 'PAF patch marker missing.' }
Write-Host 'PASS: source and config target top-level PortableApps Data directly.' -ForegroundColor Green
