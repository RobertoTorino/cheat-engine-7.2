[![release-main](https://github.com/RobertoTorino/cheat-engine-7.2/actions/workflows/release-main.yml/badge.svg)](https://github.com/RobertoTorino/cheat-engine-7.2/actions/workflows/release-main.yml) [![nightly-develop](https://github.com/RobertoTorino/cheat-engine-7.2/actions/workflows/nightly-develop.yml/badge.svg)](https://github.com/RobertoTorino/cheat-engine-7.2/actions/workflows/nightly-develop.yml)

## Cheat Engine 7.2 - TRR

This repository contains a customized Cheat Engine 7.2 build used for Tekken Revolution Reborn.

## Local Build (Windows)

### Prerequisites

1. Windows 10/11
2. PowerShell 5.1+ or PowerShell 7+
3. Lazarus 2.0.10 with FPC 3.2.0 (64-bit)

Download Lazarus 2.0.10 (64-bit):
https://sourceforge.net/projects/lazarus/files/Lazarus%20Windows%2064%20bits/Lazarus%202.0.10/lazarus-2.0.10-fpc-3.2.0-win64.exe/download

Recommended install locations:

- `C:\lazarus`
- `C:\lazarus-2.0.10`
- `C:\Program Files\Lazarus`
- `C:\Program Files (x86)\Lazarus`

The build script auto-detects `lazbuild.exe` in those locations.

### Build Command

From repository root:

```powershell
.\Build-CE64-Portable.ps1
```

If auto-detection fails, provide the path explicitly:

```powershell
.\Build-CE64-Portable.ps1 -LazbuildPath 'C:\lazarus\lazbuild.exe'
```

### Output

Artifacts are written to:

- `artifacts\CheatEngine-Portable-x64-<timestamp>.zip`

Cleanup old artifacts (keeps newest 5 files and anything from last 7 days): `./Clean-Artifacts.ps1`

Optional short log file:

```powershell
.\Build-CE64-Portable.ps1 -WriteShortLog
```

This writes:

- `artifacts\Build-CE64-<timestamp>.log.txt`

### Script Parameters

`Build-CE64-Portable.ps1` supports:

- `-LazbuildPath <path>`: Explicit `lazbuild.exe` path
- `-BuildMode <name>`: Lazarus build mode (default: `Release 64-Bit`)
- `-OutputDir <dir>`: Artifact directory (default: `artifacts`)
- `-SkipBuild`: Skip compile and only package existing binaries
- `-WriteShortLog`: Write a compact summary log
- `-ShortLogPath <path>`: Custom short-log file path

### Troubleshooting

If you see a linker error like:

`Can't create object file ...\cheatengine-x86_64.exe (error code: 5)`

then the target executable is locked or not writable.

1. Close all running Cheat Engine instances.
2. Close tools that may hold the file (Explorer preview, debugger, antivirus scanner).
3. Run the build command again.

The script performs a pre-build write/rename lock check and will fail early with a clear message when this happens.

## GitHub Actions Workflows

### Release build (main)

File: `.github/workflows/release-main.yml`

Triggers:

- Push to `main`
- Manual run (`workflow_dispatch`)

Behavior:

1. Installs Lazarus 2.0.10
2. Runs `Build-CE64-Portable.ps1`
3. Uploads artifact
4. Creates a GitHub release with zip assets

### Nightly build (develop)

File: `.github/workflows/nightly-develop.yml`

Triggers:

- Push to `develop`
- Daily scheduled run (`0 3 * * *` UTC)
- Manual run (`workflow_dispatch`)

Behavior:

1. Installs Lazarus 2.0.10
2. Runs `Build-CE64-Portable.ps1`
3. Uploads artifact (14-day retention)


