param([string]$Path)
$bytes = [System.IO.File]::ReadAllBytes($Path)
$text = [System.Text.Encoding]::ASCII.GetString($bytes)
$patterns = @('respawnroom','filter_activator_tfteam','func_door','door','trigger_multiple','spawn_door','garage')
foreach ($p in $patterns) {
  Write-Host "=== $p ==="
  $matches = [regex]::Matches($text, ".{0,80}" + [regex]::Escape($p) + ".{0,120}")
  $seen = @{}
  $count = 0
  foreach ($m in $matches) {
    $s = ($m.Value -replace "`0", '')
    if (-not $seen.ContainsKey($s)) {
      $seen[$s] = $true
      Write-Host $s
      $count++
      if ($count -ge 20) { break }
    }
  }
}
