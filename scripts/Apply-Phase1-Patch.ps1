param([Parameter(Mandatory=$true)][string]$SourceRoot)
$ErrorActionPreference = 'Stop'
$SourceRoot = [IO.Path]::GetFullPath($SourceRoot)
$mainFile = Join-Path $SourceRoot 'app\src-tauri\src\main.rs'
$updatesFile = Join-Path $SourceRoot 'app\src\hooks\useUpdateCheck.ts'
$markerFile = Join-Path $SourceRoot '.telegramdrive-phase1-patch.json'

$mainText = (Get-Content -LiteralPath $mainFile -Raw -Encoding UTF8).Replace("`r`n", "`n")
$updateText = (Get-Content -LiteralPath $updatesFile -Raw -Encoding UTF8).Replace("`r`n", "`n")

$oldMain = @'
fn main() {
    #[cfg(target_os = "linux")]
    app_lib::linux_startup::configure_before_webview();

    app_lib::run()
}
'@

$newMain = @'
// TELEGRAMDRIVE_PORTABLE_TEMP_V1
// Configure TEMP/TMP before Tauri, Grammers, and transfer workers start.
// The application's existing staging_root_in safety checks remain unchanged.
#[cfg(target_os = "windows")]
fn configure_portable_temp() -> std::io::Result<()> {
    use std::io::{Error, ErrorKind};

    let exe = std::env::current_exe()?;
    let exe_dir = exe.parent().ok_or_else(|| {
        Error::new(ErrorKind::InvalidInput, "Cannot determine executable directory")
    })?;
    let data = exe_dir.join("Data");
    let temp = data.join("Temp");

    // Avoid blindly following a symlink at either managed directory.
    for p in [&data, &temp] {
        if let Ok(meta) = std::fs::symlink_metadata(p) {
            if !meta.file_type().is_dir() || meta.file_type().is_symlink() {
                return Err(Error::new(ErrorKind::PermissionDenied, "Unsafe portable data directory"));
            }
        }
    }
    std::fs::create_dir_all(&temp)?;
    std::env::set_var("TEMP", &temp);
    std::env::set_var("TMP", &temp);
    Ok(())
}

fn main() {
    #[cfg(target_os = "windows")]
    configure_portable_temp().expect("Unable to initialize portable Temp directory");

    #[cfg(target_os = "linux")]
    app_lib::linux_startup::configure_before_webview();

    app_lib::run()
}
'@

$oldAuto = '    const automaticChecks = isLoaded && settings.autoUpdate !== false;'
$newAuto = '    const automaticChecks = isLoaded && settings.autoUpdate !== false && !PORTABLE_UPDATES_DISABLED;'
$oldCheck = '    const checkForUpdates = useCallback((): Promise<UpdateCheckResult> => {'
$newCheck = @'
    const checkForUpdates = useCallback((): Promise<UpdateCheckResult> => {
        // Never install an official update over a custom portable executable.
        if (PORTABLE_UPDATES_DISABLED) return Promise.resolve({ version: null, error: null });
'@
$oldInstall = '    const downloadAndInstall = useCallback((): Promise<UpdateInstallResult> => {'
$newInstall = @'
    const downloadAndInstall = useCallback((): Promise<UpdateInstallResult> => {
        if (PORTABLE_UPDATES_DISABLED) return Promise.resolve({ error: null });
'@

$importsEnd = "import { INITIAL_UPDATE_CHECK_DELAY_MS, UPDATE_RECHECK_INTERVAL_MS } from '../services/updatePolicy';"
$newImportsEnd = $importsEnd + "`n" + 'const PORTABLE_UPDATES_DISABLED = true; // TELEGRAMDRIVE_PORTABLE_UPDATER_V1'

# Fail closed if upstream has changed since the inspection. Do not leave a half-patch.
if (-not $mainText.Contains($oldMain)) { throw 'main.rs upstream changed; re-inspection required.' }
foreach ($part in @($oldAuto, $oldCheck, $oldInstall, $importsEnd)) {
  if (-not $updateText.Contains($part)) { throw "useUpdateCheck.ts upstream changed ($part); re-inspection required." }
}

$mainText = $mainText.Replace($oldMain, $newMain)
$updateText = $updateText.Replace($importsEnd, $newImportsEnd)
$updateText = $updateText.Replace($oldAuto, $newAuto)
$updateText = $updateText.Replace($oldCheck, $newCheck)
$updateText = $updateText.Replace($oldInstall, $newInstall)

Set-Content -LiteralPath $mainFile -Value $mainText -Encoding UTF8
Set-Content -LiteralPath $updatesFile -Value $updateText -Encoding UTF8

$sha = (git -C $SourceRoot rev-parse HEAD).Trim()
[ordered]@{
  phase = '1-filesystem-portable'
  revision = $sha
  created = (Get-Date).ToString('o')
  tauri_directory_root = './Data/AppState'
  temporary_directory = './Data/Temp'
  native_updater_disabled = $true
  windows_credential_manager_preserved = $true
  api_hash_portable = $false
  proxy_password_portable = $false
  supporter_credentials_portable = $false
  note = 'Partial portability only. Credential Manager secrets are NOT bundled and must be handled separately.'
} | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $markerFile -Encoding UTF8
Write-Host 'Phase 1 source patch applied to temporary checkout only.' -ForegroundColor Green
