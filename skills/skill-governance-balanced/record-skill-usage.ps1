param(
  [string]$Root = "C:\Users\davemelo\.openclaw\workspace",
  [Parameter(Mandatory = $true)]
  [string]$SkillName,
  [ValidateSet("success", "failure", "blocked")]
  [string]$Outcome = "success",
  [string]$TaskId = "",
  [string]$Evidence = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$registryPath = Join-Path $Root "skill-registry.json"
$usagePath = Join-Path $Root "memory\skill-usage.jsonl"
New-Item -Path (Split-Path -Parent $usagePath) -ItemType Directory -Force | Out-Null

$registry = Get-Content -Raw -Path $registryPath | ConvertFrom-Json

$trackedNames = @($registry.skills.PSObject.Properties | ForEach-Object { $_.Name })
if (-not ($trackedNames -contains $SkillName)) {
  $registry.skills | Add-Member -NotePropertyName $SkillName -NotePropertyValue ([PSCustomObject]@{
    status = "candidate"
    source = "runtime"
    riskLevel = "medium"
    platform = "windows"
    installedAt = [DateTime]::UtcNow.ToString("o")
    lastUsedAt = $null
    stats = [PSCustomObject]@{
      success = 0
      failure = 0
      blocked = 0
      total = 0
      failureStreak = 0
    }
    audit = [PSCustomObject]@{
      structure = $null
      runtime = $null
      evidence = $null
      registration = $null
      lastAuditAt = $null
    }
    tags = @()
  })
}

$entry = $registry.skills.$SkillName
$entry.lastUsedAt = [DateTime]::UtcNow.ToString("o")
$entry.stats.total = [int]$entry.stats.total + 1
$entry.stats.$Outcome = [int]$entry.stats.$Outcome + 1

if ($Outcome -eq "success") {
  $entry.stats.failureStreak = 0
} else {
  $entry.stats.failureStreak = [int]$entry.stats.failureStreak + 1
}

$threshold = [int]$registry.policy.quarantine.failureStreakToQuarantine
if ($entry.stats.failureStreak -ge $threshold) {
  $entry.status = "quarantine"
}

$row = [PSCustomObject]@{
  at = [DateTime]::UtcNow.ToString("o")
  skill = $SkillName
  outcome = $Outcome
  taskId = $TaskId
  evidence = $Evidence
}
Add-Content -Path $usagePath -Value ($row | ConvertTo-Json -Compress)

$registry.updatedAt = [DateTime]::UtcNow.ToString("o")
$registry | ConvertTo-Json -Depth 100 | Set-Content -Path $registryPath -Encoding UTF8

[PSCustomObject]@{
  result = "ok"
  registry = $registryPath
  usageFile = $usagePath
  skill = $SkillName
  outcome = $Outcome
  status = $entry.status
  failureStreak = $entry.stats.failureStreak
} | ConvertTo-Json -Depth 10
