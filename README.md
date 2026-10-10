# Telegram Drive – Phase 1 Filesystem Portable Builder

**Status:** Experimental. No compiled Windows binary is included in this repository. This builder has not yet been run and verified on a Windows machine.

This GitHub Actions builder checks out a **clean fork** at `YOUR-USERNAME/Telegram-Drive`, upgrades the temporary build checkout to Tauri 2.12+, applies a storage and updater patch, and produces an **unbundled EXE** without an MSI/NSIS installer.

The portable EXE is meant to keep application-managed files under `Data/AppState` and temporary files under `Data/Temp`, including when launched directly. An optional launcher, Startup-folder scripts, a read-only verifier, and a conservative copy-only migration tool are packaged with it.

## Important limitations

* **Not fully portable:** Telegram API hash, proxy passwords, and supporter-license materials remain in Windows Credential Manager. These do **not** travel with the portable folder after reinstalling Windows.
* No scripts export, modify, or bypass the original credential-store code, and the supporter activation rules remain intact.
* The vault passphrase is not included or recoverable by this kit.
* The **official in-app updater is disabled** so it cannot replace our custom EXE.
* Runtime libraries such as WebView2 and VC++ may need to be installed on the host.
* Windows and other apps can still leave independent system traces.

## Run

`Actions` → `Build Telegram Drive Portable (Phase 1)` → `Run workflow` → `filesystem-portable`.

The workflow has no automatic schedule. First verify the manual build and its state on a test Windows installation; only then add this builder to your Universal Fork Sync mapping.

Use the `inspect-source` mode if upstream changes and the patch fails.
