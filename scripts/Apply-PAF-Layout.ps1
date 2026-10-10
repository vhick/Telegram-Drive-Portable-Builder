param([Parameter(Mandatory=$true)][string]$SourceRoot)
$ErrorActionPreference = 'Stop'
$mainFile = Join-Path $SourceRoot 'app\src-tauri\src\main.rs'
$markerFile = Join-Path $SourceRoot '.telegramdrive-paf-patch.json'
if (-not (Test-Path -LiteralPath $mainFile)) { throw "Missing main.rs: $mainFile" }
$txt = (Get-Content -LiteralPath $mainFile -Raw -Encoding UTF8).Replace("`r`n","`n")
# Apply AFTER the existing, working Apply-Phase1-Patch.ps1.
$old = @'
    let data = exe_dir.join("Data");
    let temp = data.join("Temp");
'@
$new = @'
    // TELEGRAMDRIVE_PAF_DATA_V1
    // Dedicated PAF build. Never use a junction or a move-on-exit operation.
    // Only run this binary from <PortableRoot>\\App\\TelegramDrive.
    let exe_parent_name = exe_dir.file_name().and_then(|s| s.to_str());
    let app_parent = exe_dir.parent();
    let app_parent_name = app_parent.and_then(|p| p.file_name()).and_then(|s| s.to_str());
    if exe_parent_name != Some("TelegramDrive") || app_parent_name != Some("App") {
        return Err(Error::new(ErrorKind::InvalidInput, "PAF build must live in App\\TelegramDrive"));
    }
    let portable_root = app_parent
        .and_then(|p| p.parent())
        .ok_or_else(|| Error::new(ErrorKind::InvalidInput, "Cannot find PortableApps package root"))?;
    let data = portable_root.join("Data");
    let temp = data.join("Temp");
'@
$old = $old.Replace("`r`n","`n")
$new = $new.Replace("`r`n","`n")
if (-not $txt.Contains('TELEGRAMDRIVE_PORTABLE_TEMP_V1')) {
    throw 'First-stage portable patch is missing. Apply existing Apply-Phase1-Patch.ps1 first.'
}
$hits = ([regex]::Matches($txt, [regex]::Escape($old))).Count
if ($hits -ne 1) { throw "Expected exactly one original Phase 1 data/temp assignment; found $hits. Stop for re-inspection." }
$txt = $txt.Replace($old, $new)
Set-Content -LiteralPath $mainFile -Value $txt -Encoding UTF8
$sha = (git -C $SourceRoot rev-parse HEAD).Trim()
[ordered]@{
  type = 'telegramdrive-paf-layout'
  revision = $sha
  layout = 'TelegramDrivePortable/App/TelegramDrive/TelegramDrive-Portable.exe'
  root_data = 'TelegramDrivePortable/Data'
  tauri_app_root = '../../Data/AppState'
  temp_root = '../../Data/Temp'
  no_junction = $true
  no_shutdown_recovery = $true
  credential_manager_unchanged = $true
} | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $markerFile -Encoding UTF8
Write-Host 'PASS: PAF data/temp path patch applied.' -ForegroundColor Green
