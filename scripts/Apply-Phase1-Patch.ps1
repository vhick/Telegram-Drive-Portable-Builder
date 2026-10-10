param([Parameter(Mandatory=$true)][string]$SourceRoot)
$ErrorActionPreference = 'Stop'
$SourceRoot = [IO.Path]::GetFullPath($SourceRoot)
$mainFile = Join-Path $SourceRoot 'app\src-tauri\src\main.rs'
$updatesFile = Join-Path $SourceRoot 'app\src\hooks\useUpdateCheck.ts'
$markerFile = Join-Path $SourceRoot '.telegramdrive-phase1-patch.json'

# GitHub Actions runs this script on Windows. A Git checkout and a PowerShell
# here-string can use CRLF, while the upstream Rust/TypeScript files can use LF.
# Normalize BOTH the source and the patch's expected text to avoid false
# "upstream changed" failures caused by newline formatting alone.
function Normalize-Eol([string]$Text) {
  return $Text.Replace("`r`n", "`n").Replace("`r", "`n")
}

$mainText = Normalize-Eol (Get-Content -LiteralPath $mainFile -Raw -Encoding UTF8)
$updateText = Normalize-Eol (Get-Content -LiteralPath $updatesFile -Raw -Encoding UTF8)

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

# Normalize here-strings too. On Windows, PowerShell usually creates CRLF
# here-strings; only normalizing main.rs would make a correct source look wrong.
$oldMain = Normalize-Eol $oldMain
$newMain = Normalize-Eol $newMain
$newCheck = Normalize-Eol $newCheck
$newInstall = Normalize-Eol $newInstall

# Fail closed when semantic anchors actually differ; never emit an unpatched EXE.
$mainOccurrences = ([regex]::Matches($mainText, [regex]::Escape($oldMain))).Count
if ($mainOccurrences -ne 1) {
  Write-Host "Expected exactly one known main() entrypoint, found $mainOccurrences." -ForegroundColor Red
  Write-Host 'The comparison already ignores CRLF versus LF differences.' -ForegroundColor Yellow
  Write-Host 'Matched revision is available in SOURCE-REVISION.txt from the last inspection.'
  throw 'main.rs no longer matches the inspected entrypoint; a source inspection is required.'
}
foreach ($part in @($oldAuto, $oldCheck, $oldInstall, $importsEnd)) {
  $hits = ([regex]::Matches($updateText, [regex]::Escape($part))).Count
  if ($hits -ne 1) { throw "Expected exactly one instance of useUpdateCheck.ts anchor (found $hits): $part" }
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
