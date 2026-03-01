param(
  [string]$Root = "C:\Users\davemelo\.openclaw\workspace"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$registryPath = Join-Path $Root "skill-registry.json"
$registry = Get-Content -Raw -Path $registryPath | ConvertFrom-Json
$now = [DateTime]::UtcNow

function Get-Total([object]$Stats) {
  return [Math]::Max(1, [int]$Stats.total)
}

function Get-FailureRate([object]$Stats) {
  $total = Get-Total -Stats $Stats
  $bad = [int]$Stats.failure + [int]$Stats.blocked
  return ($bad / $total)
}

$policy = $registry.policy.core
$demoteWindow = [TimeSpan]::FromDays([int]$policy.demoteAfterDays)
$promoteWindow = [TimeSpan]::FromDays([int]$policy.promoteWindowDays)
$noBlockWindow = [TimeSpan]::FromHours([int]$policy.promoteRequireNoBlockingHours)

# Auto cap adjustment based on latest metrics vs baseline.
$baseline = $registry.metrics.baseline
$latest = $registry.metrics.latest
$autoCap = [int]$policy.autoCap

$shrink = $false
if ($latest.p95FirstResponseMs -gt ($baseline.p95FirstResponseMs * 1.25)) { $shrink = $true }
if ($latest.skillErrorRate -gt 0.08) { $shrink = $true }

$expand = $false
if (($latest.p95FirstResponseMs -le ($baseline.p95FirstResponseMs * 1.10)) -and
    ($latest.skillErrorRate -le 0.08) -and
    ($latest.ondemandHitRate -gt 0.35)) {
  $expand = $true
}

if ($shrink) {
  $policy.autoCap = [Math]::Max([int]$policy.min, $autoCap - 1)
} elseif ($expand) {
  $policy.autoCap = [Math]::Min([int]$policy.max, $autoCap + 1)
}

$promoted = @()
$demoted = @()

$allNames = @($registry.skills.PSObject.Properties | ForEach-Object { $_.Name })

# Demote inactive core skills first.
foreach ($name in $allNames) {
  $entry = $registry.skills.$name
  if ($entry.status -ne "core") { continue }
  if (-not $entry.lastUsedAt) { continue }
  $lastUsed = [DateTime]::Parse($entry.lastUsedAt).ToUniversalTime()
  if (($now - $lastUsed) -gt $demoteWindow) {
    $entry.status = "ready"
    $demoted += $name
  }
}

$coreCount = (@($registry.skills.PSObject.Properties | Where-Object { $_.Value.status -eq "core" })).Count
$targetCap = [int]$policy.autoCap
$slots = [Math]::Max(0, $targetCap - $coreCount)

if ($slots -gt 0) {
  $candidates = @()
  foreach ($name in $allNames) {
    $entry = $registry.skills.$name
    if ($entry.status -ne "ready") { continue }

    $total = [int]$entry.stats.total
    $success = [int]$entry.stats.success
    $blocked = [int]$entry.stats.blocked
    $failureRate = Get-FailureRate -Stats $entry.stats

    $lastUsed = $null
    if ($entry.lastUsedAt) {
      $lastUsed = [DateTime]::Parse($entry.lastUsedAt).ToUniversalTime()
    }

    $recentEnough = $false
    if ($lastUsed) {
      $recentEnough = (($now - $lastUsed) -le $promoteWindow)
    }

    $noRecentBlocking = ($blocked -eq 0)
    if ($lastUsed) {
      if (($now - $lastUsed) -le $noBlockWindow) {
        $noRecentBlocking = ($blocked -eq 0)
      } else {
        $noRecentBlocking = $true
      }
    }

    if ($recentEnough -and
        ($success -ge [int]$policy.promoteMinSuccessCount) -and
        ($failureRate -lt [double]$policy.promoteMaxFailureRate) -and
        $noRecentBlocking) {
      $candidates += [PSCustomObject]@{
        name = $name
        success = $success
        failureRate = $failureRate
        lastUsedAt = $entry.lastUsedAt
      }
    }
  }

  $toPromote = $candidates |
    Sort-Object -Property @{Expression = "success"; Descending = $true}, @{Expression = "failureRate"; Descending = $false} |
    Select-Object -First $slots

  foreach ($p in $toPromote) {
    $registry.skills.$($p.name).status = "core"
    $promoted += $p.name
  }
}

# Cold start bootstrap: ensure at least min core skills when telemetry is not rich yet.
$coreNamesAfterPromote = @($registry.skills.PSObject.Properties | Where-Object { $_.Value.status -eq "core" } | ForEach-Object { $_.Name })
if ($coreNamesAfterPromote.Count -lt [int]$policy.min) {
  $need = [int]$policy.min - $coreNamesAfterPromote.Count
  $readyPool = @(
    $registry.skills.PSObject.Properties |
      Where-Object { $_.Value.status -eq "ready" } |
      Sort-Object -Property @{Expression = { [int]$_.Value.stats.total }; Descending = $true}, @{Expression = { $_.Name }; Descending = $false} |
      Select-Object -First $need
  )
  foreach ($r in $readyPool) {
    $registry.skills.$($r.Name).status = "core"
    $promoted += $r.Name
  }
}

# Ensure core does not exceed cap.
$coreNames = @($registry.skills.PSObject.Properties | Where-Object { $_.Value.status -eq "core" } | ForEach-Object { $_.Name })
if ($coreNames.Count -gt $policy.autoCap) {
  $overflow = $coreNames.Count - [int]$policy.autoCap
  $toDemote = @(
    $coreNames | Sort-Object {
      $e = $registry.skills.$_
      if ($e.lastUsedAt) { [DateTime]::Parse($e.lastUsedAt).ToUniversalTime() } else { [DateTime]"1900-01-01" }
    } | Select-Object -First $overflow
  )
  foreach ($name in $toDemote) {
    $registry.skills.$name.status = "ready"
    $demoted += $name
  }
}

$registry.metrics.lastEvaluatedAt = $now.ToString("o")
$registry.updatedAt = $now.ToString("o")
$registry | ConvertTo-Json -Depth 100 | Set-Content -Path $registryPath -Encoding UTF8

[PSCustomObject]@{
  result = "ok"
  registry = $registryPath
  autoCap = $policy.autoCap
  promoted = $promoted | Sort-Object -Unique
  demoted = $demoted | Sort-Object -Unique
  coreCount = (@($registry.skills.PSObject.Properties | Where-Object { $_.Value.status -eq "core" })).Count
} | ConvertTo-Json -Depth 20
