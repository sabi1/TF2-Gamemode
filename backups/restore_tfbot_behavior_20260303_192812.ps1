$ErrorActionPreference = "Stop"

$scriptPath = $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent (Split-Path -Parent $scriptPath)
$timestamp = "20260303_192812"
$zipPath = Join-Path $repoRoot ("backups\tfbot_behavior_pre_valve_port_{0}.zip" -f $timestamp)
$manifestPath = Join-Path $repoRoot ("backups\tfbot_behavior_pre_valve_port_{0}_manifest.txt" -f $timestamp)
$extractPath = Join-Path $repoRoot ("backups\.restore_tmp_{0}" -f $timestamp)

if (-not (Test-Path $zipPath)) {
	throw "Backup zip not found: $zipPath"
}
if (-not (Test-Path $manifestPath)) {
	throw "Manifest not found: $manifestPath"
}

if (Test-Path $extractPath) {
	Remove-Item -Recurse -Force $extractPath
}
New-Item -ItemType Directory -Path $extractPath | Out-Null
Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force

$manifestLines = Get-Content $manifestPath | Where-Object { $_ -and -not $_.StartsWith("#") }
$ok = 0
$fail = 0

foreach ($line in $manifestLines) {
	if ($line -notmatch '^([A-Fa-f0-9]{64}) \*(.+)$') {
		Write-Host "[SKIP] malformed manifest line: $line"
		continue
	}

	$expected = $Matches[1].ToUpperInvariant()
	$rel = $Matches[2]
	$src = Join-Path $extractPath $rel
	$dst = Join-Path $repoRoot $rel

	if (-not (Test-Path $src)) {
		Write-Host "[FAIL] missing in archive: $rel"
		$fail++
		continue
	}

	$actual = (Get-FileHash -Algorithm SHA256 -Path $src).Hash.ToUpperInvariant()
	if ($actual -ne $expected) {
		Write-Host "[FAIL] hash mismatch: $rel"
		$fail++
		continue
	}

	New-Item -ItemType Directory -Path (Split-Path -Parent $dst) -Force | Out-Null
	Copy-Item -Path $src -Destination $dst -Force
	Write-Host "[OK] restored $rel"
	$ok++
}

if (Test-Path $extractPath) {
	Remove-Item -Recurse -Force $extractPath
}

Write-Host "Restore complete. OK=$ok FAIL=$fail"
exit ([int]($fail -gt 0))
