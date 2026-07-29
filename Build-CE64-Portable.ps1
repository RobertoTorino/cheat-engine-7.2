param(
    [string]$LazbuildPath,
    [string]$BuildMode = 'Release 64-Bit',
    [string]$OutputDir = 'artifacts',
    [switch]$SkipBuild,
    [switch]$WriteShortLog,
    [string]$ShortLogPath
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Resolve-LazbuildPath {
    param([string]$PreferredPath)

    if ($PreferredPath) {
        if (Test-Path $PreferredPath) {
            return (Resolve-Path $PreferredPath).Path
        }
        throw "Provided lazbuild path does not exist: $PreferredPath"
    }

    $cmd = Get-Command lazbuild -ErrorAction SilentlyContinue
    if ($cmd) {
        return $cmd.Source
    }

    $candidates = @(
        'C:\lazarus\lazbuild.exe',
        'C:\lazarus-2.0.10\lazbuild.exe',
        'C:\Program Files\Lazarus\lazbuild.exe',
        'C:\Program Files (x86)\Lazarus\lazbuild.exe'
    )

    foreach ($candidate in $candidates) {
        if (Test-Path $candidate) {
            return $candidate
        }
    }

    throw 'Could not find lazbuild.exe. Pass -LazbuildPath explicitly.'
}

function Write-ShortBuildLog {
    param(
        [string]$Path,
        [string]$Status,
        [string]$Message,
        [string]$Lazbuild,
        [string]$Project,
        [string]$Mode,
        [string]$ExpectedExe,
        [string]$Zip,
        [int]$ExitCode,
        [object[]]$BuildOutput
    )

    $lines = @(
        "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')",
        "Status: $Status",
        "Message: $Message",
        "BuildMode: $Mode",
        "Lazbuild: $Lazbuild",
        "Project: $Project",
        "ExpectedExe: $ExpectedExe",
        "ZipPath: $Zip",
        "ExitCode: $ExitCode",
        ''
    )

    if ($BuildOutput -and $BuildOutput.Count -gt 0) {
        $signalLines = @(
            $BuildOutput |
            Select-String -Pattern 'Fatal:|Error:|Warning:' |
            Select-Object -Last 25 |
            ForEach-Object { $_.Line }
        )

        if ($signalLines.Count -gt 0) {
            $lines += 'Compiler signal lines (last 25):'
            $lines += $signalLines
            $lines += ''
        }

        $tailLines = @(
            $BuildOutput |
            Select-Object -Last 40 |
            ForEach-Object { $_.ToString() }
        )

        if ($tailLines.Count -gt 0) {
            $lines += 'Build output tail (last 40 lines):'
            $lines += $tailLines
        }
    }

    Set-Content -Path $Path -Value $lines -Encoding UTF8
    Write-Host "Short build log written: $Path"
}

function Test-FileRenameWritable {
    param([string]$Path)

    if (-not (Test-Path $Path)) {
        return $true
    }

    $probePath = "$Path.lockprobe"
    if (Test-Path $probePath) {
        Remove-Item $probePath -Force -ErrorAction SilentlyContinue
    }

    try {
        Move-Item -Path $Path -Destination $probePath -Force -ErrorAction Stop
        Move-Item -Path $probePath -Destination $Path -Force -ErrorAction Stop
        return $true
    }
    catch {
        return $false
    }
}

$repoRoot = Split-Path -Parent $PSCommandPath
$ceDir = Join-Path $repoRoot 'Cheat Engine'
$projectFile = Join-Path $ceDir 'cheatengine.lpi'
$binDir = Join-Path $ceDir 'bin'
$expectedExe = Join-Path $binDir 'cheatengine-x86_64.exe'
$artifactDir = Join-Path $repoRoot $OutputDir

New-Item -ItemType Directory -Path $artifactDir -Force | Out-Null

$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$zipPath = Join-Path $artifactDir "CheatEngine-Portable-x64-$timestamp.zip"
$shortLogEnabled = $WriteShortLog -or [bool]$ShortLogPath

if ($shortLogEnabled -and -not $ShortLogPath) {
    $ShortLogPath = Join-Path $artifactDir "Build-CE64-$timestamp.log.txt"
}

if (-not (Test-Path $projectFile)) {
    throw "Project file not found: $projectFile"
}

$lazbuild = Resolve-LazbuildPath -PreferredPath $LazbuildPath
Write-Host "Using lazbuild: $lazbuild"
Write-Host "Project: $projectFile"
Write-Host "Mode: $BuildMode"

$buildOutput = @()
$buildExitCode = 0

try {
    if (-not (Test-FileRenameWritable -Path $expectedExe)) {
        throw "Target executable is locked or not writable: $expectedExe. Close running Cheat Engine instances and tools that may hold this file (Explorer preview, AV scanner, debugger), then retry."
    }

    if (-not $SkipBuild) {
        Push-Location $ceDir
        try {
            $buildOutput = @(& $lazbuild $projectFile "--bm=$BuildMode" '--build-all' 2>&1)
            $buildOutput | ForEach-Object { $_ }
            $buildExitCode = $LASTEXITCODE

            if ($buildExitCode -ne 0) {
                throw "Build failed with exit code $buildExitCode"
            }
        }
        finally {
            Pop-Location
        }
    }

    if (-not (Test-Path $expectedExe)) {
        throw "Expected 64-bit executable not found: $expectedExe"
    }

    if (Test-Path $zipPath) {
        Remove-Item $zipPath -Force
    }

    Compress-Archive -Path (Join-Path $binDir '*') -DestinationPath $zipPath -CompressionLevel Optimal

    Write-Host "Portable zip created: $zipPath"

    try {
        Start-Process -FilePath explorer.exe -ArgumentList "/select,$zipPath"
    }
    catch {
        Write-Warning "Could not open Explorer automatically: $($_.Exception.Message)"
    }

    if ($shortLogEnabled) {
        Write-ShortBuildLog -Path $ShortLogPath -Status 'SUCCESS' -Message 'Build and packaging completed.' -Lazbuild $lazbuild -Project $projectFile -Mode $BuildMode -ExpectedExe $expectedExe -Zip $zipPath -ExitCode $buildExitCode -BuildOutput $buildOutput
    }

    Write-Host 'Done.'
}
catch {
    if ($shortLogEnabled) {
        Write-ShortBuildLog -Path $ShortLogPath -Status 'FAILED' -Message $_.Exception.Message -Lazbuild $lazbuild -Project $projectFile -Mode $BuildMode -ExpectedExe $expectedExe -Zip $zipPath -ExitCode $buildExitCode -BuildOutput $buildOutput
    }

    throw
}
