# Telegram Drive Portable — Source Inspection Edition

This repository is for the **first inspection stage**, not the finished portable app.

## What it does

The GitHub Actions workflow checks out your clean `Telegram-Drive` fork and inspects **public source code only**. It searches for Tauri data-path usage, Telegram sessions, OS credential storage, vaults, local databases, WebView state, updater behavior, and registry/startup code.

The workflow does **not** compile, run, or connect the app to Telegram; it does not read your PC, private settings, Telegram tokens, credentials, or Windows registry.

## Run

**Actions → Inspect Telegram Drive for Portability → Run workflow**

Keep the default source fields if your clean fork is named `YOUR-USERNAME/Telegram-Drive` on branch `main`.

Then download `TelegramDrive-Portability-Inspection-<commit>` under **Artifacts** and upload the ZIP to ChatGPT.

## Repository roles

- `Telegram-Drive` — clean fork of `caamer20/Telegram-Drive`, synchronized by your existing fork-sync controller.
- `Telegram-Drive-Portable-Builder` — this custom tool repository.

Do **not** add custom workflows to the force-synced fork. Do **not** change your working ZyntaxAI, GemType or YASB builder repositories or your Universal Fork Sync for this inspection.

## Sensitive-data warning

The app's own documentation treats API hashes, Telegram sessions, encryption credentials, REST/WebDAV keys and recovery material as secrets. Never upload real profile or AppData folders, session files, vault files or recovery material for this inspection.

The final portable builder will only be designed once its storage/security source code has been verified. The current repository does not represent a working Telegram Drive portable EXE.
