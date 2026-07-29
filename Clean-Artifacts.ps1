[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param(
	[string]$ArtifactsPath = 'artifacts',
	[int]$KeepNewest = 5,
	[int]$KeepDays = 7,
	[switch]$PurgeAll,
	[switch]$IncludeSubdirectories
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if ($KeepNewest -lt 0) {
	throw '-KeepNewest must be >= 0.'
}

if ($KeepDays -lt 0) {
	throw '-KeepDays must be >= 0.'
}

$repoRoot = Split-Path -Parent $PSCommandPath
$resolvedArtifactsPath = if ([System.IO.Path]::IsPathRooted($ArtifactsPath)) {
	$ArtifactsPath
} else {
	Join-Path $repoRoot $ArtifactsPath
}

if (-not (Test-Path $resolvedArtifactsPath)) {
	Write-Host "Artifacts folder does not exist: $resolvedArtifactsPath"
	exit 0
}

$fileQuery = if ($IncludeSubdirectories) {
	Get-ChildItem -Path $resolvedArtifactsPath -File -Recurse
} else {
	Get-ChildItem -Path $resolvedArtifactsPath -File
}

$files = @($fileQuery | Sort-Object LastWriteTime -Descending)

if ($files.Count -eq 0) {
	Write-Host "No files found in: $resolvedArtifactsPath"
	exit 0
}

$cutoff = (Get-Date).AddDays(-$KeepDays)

$keepMap = @{}

if (-not $PurgeAll) {
	$index = 0
	foreach ($f in $files) {
		$shouldKeep = ($index -lt $KeepNewest) -or ($f.LastWriteTime -ge $cutoff)
		$keepMap[$f.FullName] = $shouldKeep
		$index++
	}
}

$deletedCount = 0
$deletedBytes = [int64]0

foreach ($f in $files) {
	$deleteThis = $PurgeAll -or (-not $keepMap[$f.FullName])

	if ($deleteThis) {
		if ($PSCmdlet.ShouldProcess($f.FullName, 'Delete artifact file')) {
			$deletedBytes += $f.Length
			Remove-Item -LiteralPath $f.FullName -Force
			$deletedCount++
		}
	}
}

# Remove empty directories after file cleanup.
$dirs = Get-ChildItem -Path $resolvedArtifactsPath -Directory -Recurse | Sort-Object FullName -Descending
foreach ($d in $dirs) {
	$remaining = @(Get-ChildItem -LiteralPath $d.FullName -Force)
	if ($remaining.Count -eq 0) {
		if ($PSCmdlet.ShouldProcess($d.FullName, 'Remove empty folder')) {
			Remove-Item -LiteralPath $d.FullName -Force
		}
	}
}

$remainingCount = @(
	Get-ChildItem -Path $resolvedArtifactsPath -File -Recurse
).Count
$deletedMB = [Math]::Round(($deletedBytes / 1MB), 2)

Write-Host "Cleanup complete."
Write-Host "Deleted files: $deletedCount"
Write-Host "Freed space:  $deletedMB MB"
Write-Host "Files left:   $remainingCount"

