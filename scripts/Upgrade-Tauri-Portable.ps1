param([Parameter(Mandatory=$true)][string]$SourceRoot)
$ErrorActionPreference = 'Stop'
$SourceRoot = [IO.Path]::GetFullPath($SourceRoot)
$app = Join-Path $SourceRoot 'app'
$rust = Join-Path $app 'src-tauri'
if (-not (Test-Path (Join-Path $app 'package.json'))) { throw 'app/package.json missing' }
if (-not (Test-Path (Join-Path $rust 'Cargo.toml'))) { throw 'Rust Cargo.toml missing' }

function Run([string]$Exe, [string[]]$Arguments) {
  Write-Host "> $Exe $($Arguments -join ' ')" -ForegroundColor Cyan
  & $Exe @Arguments
  if ($LASTEXITCODE -ne 0) { throw "$Exe failed with exit code $LASTEXITCODE" }
}

Push-Location $app
try {
  # Never changes your synced fork. GitHub Actions discards this checkout afterward.
  # The JS CLI and Rust crate stack must both support appDirectoriesOverride.
  # Tauri requires matching major/minor versions of the Rust runtime and
  # JavaScript API. Updating only @tauri-apps/cli leaves the old API installed.
  # Both package.json and package-lock.json are changed in THIS TEMPORARY checkout.
  Run 'npm.cmd' @('install', '--save-dev', '--save-exact', '--ignore-scripts=false', '@tauri-apps/cli@2.12.0')
  Run 'npm.cmd' @('install', '--save', '--save-exact', '--ignore-scripts=false', '@tauri-apps/api@2.12.0')

  # Fail here with an understandable message instead of later at `tauri build`.
  foreach ($item in @(
    @{ Name='@tauri-apps/cli'; Expected='2.12.0' },
    @{ Name='@tauri-apps/api'; Expected='2.12.0' }
  )) {
    $packageFile = Join-Path $app ('node_modules/' + $item.Name + '/package.json')
    if (-not (Test-Path -LiteralPath $packageFile -PathType Leaf)) {
      throw "Tauri package missing after npm install: $($item.Name)"
    }
    $actual = [string]((Get-Content -LiteralPath $packageFile -Raw | ConvertFrom-Json).version)
    Write-Host "Tauri JavaScript package: $($item.Name) $actual"
    if ($actual -ne $item.Expected) {
      throw "Tauri version mismatch: $($item.Name) is $actual, expected $($item.Expected)."
    }
  }
}
finally { Pop-Location }

Push-Location $rust
try {
  Run 'cargo' @('update', '-p', 'tauri', '--precise', '2.12.0')
  # The build and utils crates have independent versions, so Cargo must refresh them.
  Run 'cargo' @('update', '-p', 'tauri-build')
  Run 'cargo' @('update', '-p', 'tauri-utils')
}
finally { Pop-Location }
Write-Host 'Temporary Tauri dependency upgrade completed.' -ForegroundColor Green
