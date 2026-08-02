[CmdletBinding()]
param(
    [string]$LazbuildPath = 'C:\lazarus-2.2.2\lazbuild.exe',
    [string]$BuildMode = 'Release 64-Bit',
    [string]$OutputDirectory = 'artifacts',
    [switch]$SkipBuild
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repositoryRoot = $PSScriptRoot
$projectDirectory = Join-Path $repositoryRoot 'Cheat Engine'
$projectPath = Join-Path $projectDirectory 'cheatengine.lpi'
$binaryDirectory = Join-Path $projectDirectory 'bin'
$executablePath = Join-Path $binaryDirectory 'cheatengine-x86_64.exe'
$artifactDirectory = Join-Path $repositoryRoot $OutputDirectory
$stagingDirectory = Join-Path $artifactDirectory 'CheatEngine-Portable-x64'
$archivePath = Join-Path $artifactDirectory ("CheatEngine-7.5-TRR-Portable-x64-{0}.zip" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))

if (-not $SkipBuild) {
    if (-not (Test-Path -LiteralPath $LazbuildPath -PathType Leaf)) {
        throw "lazbuild.exe was not found at: $LazbuildPath"
    }

    Push-Location $projectDirectory
    try {
        & $LazbuildPath $projectPath "--bm=$BuildMode" --build-all --no-write-project
        if ($LASTEXITCODE -ne 0) {
            throw "Lazarus build failed with exit code $LASTEXITCODE"
        }
    }
    finally {
        Pop-Location
    }
}

if (-not (Test-Path -LiteralPath $executablePath -PathType Leaf)) {
    throw "Expected 64-bit executable was not found at: $executablePath"
}

New-Item -ItemType Directory -Path $artifactDirectory -Force | Out-Null
Remove-Item -LiteralPath $stagingDirectory -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path $stagingDirectory | Out-Null

Get-ChildItem -LiteralPath $binaryDirectory -Force | ForEach-Object {
    Copy-Item -LiteralPath $_.FullName -Destination $stagingDirectory -Recurse -Force
}

Get-ChildItem -LiteralPath $stagingDirectory -Recurse -File |
    Where-Object { $_.Extension -in '.dbg', '.bat' } |
    Remove-Item -Force

Compress-Archive -Path (Join-Path $stagingDirectory '*') -DestinationPath $archivePath -CompressionLevel Optimal
Remove-Item -LiteralPath $stagingDirectory -Recurse -Force

$archive = Get-Item -LiteralPath $archivePath
[pscustomobject]@{
    Archive = $archive.FullName
    SizeMiB = [math]::Round($archive.Length / 1MB, 2)
    Executable = $executablePath
}