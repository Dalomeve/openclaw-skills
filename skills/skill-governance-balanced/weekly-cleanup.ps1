param(
  [string]$Root = "C:\Users\davemelo\.openclaw\workspace",
  [int]$RetireCandidateDays = 14
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$registryPath = Join-Path $Root "skill-registry.json"
$registry = Get-Content -Raw -Path $registryPath | ConvertFrom-Json
$now = [DateTime]::UtcNow
$retired = @()

foreach ($p in @($registry.skills.PSObject.Properties)) {
  $name = $p.Name
  $entry = $p.Value

  if ($entry.source -eq "runtime") {
    continue
  }

  $exists = $false
  $candidatePaths = @(
    (Join-Path $Root ("skills\" + $name + "\SKILL.md")),
    (Join-Path $Root ("skills\local\" + $name + "\SKILL.md")),
    (Join-Path $Root ("skills\installed\" + $name + "\SKILL.md"))
  )
  foreach ($cp in $candidatePaths) {
    if (Test-Path $cp) { $exists = $true; break }
  }

  if (-not $exists -and ($entry.status -ne "retired")) {
    $entry.status = "retired"
    $retired += $name
    continue
  }

  if ($entry.status -eq "candidate") {
    $ageOk = $false
    if ($entry.installedAt) {
      $age = $now - [DateTime]::Parse($entry.installedAt).ToUniversalTime()
      $ageOk = ($age.TotalDays -ge $RetireCandidateDays)
    }
    $unused = (-not $entry.lastUsedAt)
    if ($ageOk -and $unused) {
      $entry.status = "retired"
      $retired += $name
    }
  }
}

$registry.updatedAt = $now.ToString("o")
$registry | ConvertTo-Json -Depth 100 | Set-Content -Path $registryPath -Encoding UTF8

[PSCustomObject]@{
  result = "ok"
  registry = $registryPath
  retiredCount = @($retired).Count
  retired = $retired | Sort-Object -Unique
} | ConvertTo-Json -Depth 20
