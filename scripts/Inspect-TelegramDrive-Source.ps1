param(
    [Parameter(Mandatory = $true)]
    [string]$SourceRoot,

    [Parameter(Mandatory = $true)]
    [string]$OutputRoot
)

$ErrorActionPreference = "Stop"
$SourceRoot = [System.IO.Path]::GetFullPath($SourceRoot)
$OutputRoot = [System.IO.Path]::GetFullPath($OutputRoot)

$appRoot = Join-Path $SourceRoot "app"
$rustRoot = Join-Path $appRoot "src-tauri\src"
$frontendRoot = Join-Path $appRoot "src"

if (-not (Test-Path -LiteralPath $rustRoot -PathType Container)) {
    throw "Missing expected backend directory: $rustRoot (upstream layout may have changed)."
}
if (-not (Test-Path -LiteralPath $frontendRoot -PathType Container)) {
    throw "Missing expected frontend directory: $frontendRoot (upstream layout may have changed)."
}

if (Test-Path -LiteralPath $OutputRoot) {
    Remove-Item -LiteralPath $OutputRoot -Force -Recurse
}
New-Item -ItemType Directory -Path $OutputRoot -Force | Out-Null
$selectedSource = Join-Path $OutputRoot "SelectedSource"
$metadata = Join-Path $OutputRoot "Metadata"
New-Item -ItemType Directory -Path $selectedSource,$metadata -Force | Out-Null

$sha = (git -C $SourceRoot rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($sha)) {
    throw "Could not identify the checked-out commit."
}

$groups = [ordered]@{
    "App config and Tauri data paths" = @(
        'app_data_dir', 'app_local_data_dir', 'app_config_dir', 'app_cache_dir',
        'app_log_dir', 'BaseDirectory', 'PathResolver', 'appHandle.path',
        'path_resolver', 'ProjectDirs', 'BaseDirs', 'directories::',
        'LOCALAPPDATA', 'APPDATA', 'user_data_dir', 'config_dir',
        'localStorage', 'sessionStorage', 'indexedDB', 'tauri-plugin-store'
    )
    "Telegram sessions and sign-in" = @(
        'grammers', 'Session::', 'session_path', 'session_file',
        'telegram_session', 'save_session', 'load_session',
        'api_hash', 'api_id', 'phone_code', 'qr_login', 'auth_key', 'login_token'
    )
    "Windows credential/keychain and secrets" = @(
        'keyring', 'keytar', 'credential_manager', 'CredentialManager',
        'CredRead', 'CredWrite', 'windows_credentials', 'windows-sys',
        'dpapi', 'CryptProtectData', 'CryptUnprotectData',
        'secret_service', 'secure_storage', 'secure_store',
        'api_hash', 'proxy_password', 'supporter_token', 'recovery_code'
    )
    "Vault and encrypted transfer storage" = @(
        'vault', 'TDENC2', 'passphrase', 'recovery_bundle',
        'XChaCha20Poly1305', 'Argon2', 'key_material',
        'encrypt_file', 'decrypt_file', 'encryption_registry'
    )
    "Databases, transfers, file sync, downloads" = @(
        'shares.db', 'sqlite', 'rusqlite', 'sqlx', 'open_database',
        'transfer_queue', 'queue.db', 'folder_sync', 'sync_state',
        'download_dir', 'cache_dir', 'temp_dir', 'tempfile',
        'media_cache', 'thumbnail_cache', 'download_path'
    )
    "WebView, logs, crash reporting and plugins" = @(
        'WebviewWindow', 'webview_data', 'data_directory',
        'user_data_folder', 'app.setPath', 'log_plugin',
        'tauri_plugin_log', 'tauri-plugin-log', 'crash_report',
        'tracing_appender', 'tauri_plugin_sql', 'tauri-plugin-sql'
    )
    "Windows startup, updater, shell and registry" = @(
        'autostart', 'set_login_item', 'schtasks', 'TaskScheduler',
        'winreg', 'HKEY_CURRENT_USER', 'CurrentVersion\\Run',
        'RegSetValue', 'Registry', 'updater',
        'createUpdaterArtifacts', 'process:allow-restart',
        'NSIS', 'windows', 'install_mode'
    )
    "REST, WebDAV, supporter and system-linked data" = @(
        'webdav', 'rest_api', 'rest_server', 'loopback',
        'supporter', 'device_key', 'activation', 'license',
        'backup_restore', 'settings_backup', 'stored_secret'
    )
}

$validExt = @('.rs','.ts','.tsx','.js','.jsx','.mjs','.cjs','.json','.toml','.yaml','.yml')
$excludedParts = @('node_modules','target','dist','build','coverage','.git','.next','vendor')
$all = New-Object 'System.Collections.Generic.List[object]'

foreach ($searchRoot in @($rustRoot,$frontendRoot)) {
    Get-ChildItem -LiteralPath $searchRoot -Recurse -File -ErrorAction Stop | ForEach-Object {
        $file = $_
        if ($file.Extension.ToLowerInvariant() -notin $validExt) { return }
        if ($file.Length -gt 2097152) { return }
        $rel = $file.FullName.Substring($SourceRoot.Length).TrimStart('\','/')
        $parts = $rel -split '[\\/]'
        foreach ($part in $parts) {
            if ($part -in $excludedParts) { return }
        }
        $all.Add($file)
    }
}

$report = New-Object System.Text.StringBuilder
function Append([string]$s = '') { [void]$report.AppendLine($s) }

Append 'TELEGRAM DRIVE — PORTABILITY SOURCE INSPECTION'
Append "Revision: $sha"
Append "Generated: $(Get-Date -Format o)"
Append 'Source: checked-out GitHub repository only'
Append ''
Append 'This inspection NEVER reads data on your Windows PC.'
Append 'It does NOT access Telegram accounts, your local AppData, user credentials, registry, vault contents, or Windows Credential Manager.'
Append 'It does NOT execute or compile Telegram Drive.'
Append 'Do not upload actual session/vault/private keys as a follow-up.'
Append ''
Append "Total application source files scanned: $($all.Count)"
Append ''

$rank = @{}
$hitCounts = [ordered]@{}
$contextLimitPerFilePerGroup = 3

foreach ($group in $groups.GetEnumerator()) {
    Append ('=' * 92)
    Append "CATEGORY: $($group.Key)"
    Append ('=' * 92)
    $count = 0
    foreach ($file in $all) {
        try { $lines = [System.IO.File]::ReadAllLines($file.FullName) }
        catch { continue }
        $snippets = 0
        for ($i = 0; $i -lt $lines.Count; $i++) {
            $line = [string]$lines[$i]
            $found = $null
            foreach ($needle in $group.Value) {
                if ($line.IndexOf($needle,[StringComparison]::OrdinalIgnoreCase) -ge 0) {
                    $found = $needle
                    break
                }
            }
            if ($null -eq $found) { continue }
            $count++
            $path = $file.FullName
            if (-not $rank.ContainsKey($path)) { $rank[$path] = 0 }
            $rank[$path] += 1
            if ($snippets -ge $contextLimitPerFilePerGroup) { continue }
            $rel = $path.Substring($SourceRoot.Length).TrimStart('\','/')
            Append "FILE: $rel | line $($i+1) | matched: $found"
            $start = [Math]::Max(0,$i - 4)
            $finish = [Math]::Min($lines.Count - 1,$i + 7)
            for ($j=$start; $j -le $finish; $j++) {
                Append ('{0,6}: {1}' -f ($j + 1),$lines[$j])
            }
            Append ''
            $snippets++
        }
    }
    $hitCounts[$group.Key] = $count
    Append "Total matching lines in category: $count"
    Append ''
}

# Capture the most relevant full source files, not only snippets.
# This is intentionally capped to avoid extremely large artifacts.
# Every entry comes from the PUBLIC SOURCE checkout, never from the user's PC.
$limit = 180
$chosen = @($rank.GetEnumerator() |
    Sort-Object -Property @{Expression = 'Value';Descending = $true},@{Expression = 'Key';Descending = $false} |
    Select-Object -First $limit)

$priority = @(
    'app\src-tauri\src\main.rs',
    'app\src-tauri\src\lib.rs',
    'app\src-tauri\Cargo.toml'
)
$selected = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
foreach ($entry in $chosen) { [void]$selected.Add([string]$entry.Key) }
foreach ($relative in $priority) {
    $p = Join-Path $SourceRoot $relative
    if (Test-Path -LiteralPath $p -PathType Leaf) { [void]$selected.Add($p) }
}

foreach ($filePath in ($selected | Sort-Object)) {
    if (-not (Test-Path -LiteralPath $filePath -PathType Leaf)) { continue }
    $rel = $filePath.Substring($SourceRoot.Length).TrimStart('\','/')
    $destination = Join-Path $selectedSource $rel
    New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force | Out-Null
    Copy-Item -LiteralPath $filePath -Destination $destination -Force
}

# These manifest/config and documentation files help determine build constraints,
# storage configuration, update settings, and any license/redistribution limits.
$important = @(
    'README.md', 'PRIVACY.md','SECURITY.md', 'LICENSE','LICENSE.md','LICENSE.txt',
    'SUPPORTER_LICENSE_INVARIANTS.md','SUPPORTER_BACKUP_RECOVERY.md',
    'app\package.json','app\package-lock.json',
    'app\src-tauri\Cargo.toml','app\src-tauri\tauri.conf.json',
    'app\src-tauri\tauri.conf.json5','app\src-tauri\capabilities\default.json',
    'app\src-tauri\build.rs'
)
foreach ($relative in $important) {
    $p = Join-Path $SourceRoot $relative
    if (-not (Test-Path -LiteralPath $p -PathType Leaf)) { continue }
    $dest = Join-Path $metadata ($relative -replace '[\\/:*?"<>|]', '_')
    Copy-Item -LiteralPath $p -Destination $dest -Force
}

# Small supplementary source files (e.g. capability JSON) can be useful.
$capabilities = Join-Path $appRoot 'src-tauri\capabilities'
if (Test-Path -LiteralPath $capabilities -PathType Container) {
    $capsOutput = Join-Path $metadata 'capabilities'
    New-Item -ItemType Directory -Path $capsOutput -Force | Out-Null
    Get-ChildItem -LiteralPath $capabilities -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Extension -in @('.json','.toml') -and $_.Length -lt 1048576 } |
        ForEach-Object { Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $capsOutput $_.Name) -Force }
}

Append ('=' * 92)
Append 'SOURCE PACKAGE SUMMARY'
Append ('=' * 92)
Append "Public source files selected and copied: $($selected.Count)"
Append "Available backend files: $(@($all | Where-Object { $_.FullName.StartsWith($rustRoot, [StringComparison]::OrdinalIgnoreCase) }).Count)"
Append "Available frontend files: $(@($all | Where-Object { $_.FullName.StartsWith($frontendRoot, [StringComparison]::OrdinalIgnoreCase) }).Count)"
Append ''
Append 'Next: Upload the GitHub Actions inspection ARTIFACT to ChatGPT.'
Append 'Do not include any Windows AppData backup, Telegram session, API hash, recovery bundle or passwords.'

[System.IO.File]::WriteAllText((Join-Path $OutputRoot 'Portability-Inspection.txt'),$report.ToString(),[System.Text.UTF8Encoding]::new($false))
[System.IO.File]::WriteAllText((Join-Path $OutputRoot 'SOURCE-REVISION.txt'),$sha,[System.Text.UTF8Encoding]::new($false))
$hitCounts | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $OutputRoot 'Category-Counts.json') -Encoding UTF8

Write-Host "Inspection finished."
Write-Host "Commit: $sha"
Write-Host "Scanned $($all.Count) source files."
Write-Host "Copied $($selected.Count) relevant public source files."
Write-Host "Artifact directory: $OutputRoot"
