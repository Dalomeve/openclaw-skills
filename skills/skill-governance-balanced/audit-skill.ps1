param(
  [string]$Root = "C:\Users\davemelo\.openclaw\workspace",
  [Parameter(Mandatory = $true)]
  [string]$SkillName
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Read-Registry([string]$Path) {
  return (Get-Content -Raw -Path $Path | ConvertFrom-Json)
}

function Write-Registry([string]$Path, [object]$Registry) {
  $Registry.updatedAt = [DateTime]::UtcNow.ToString("o")
  $Registry | ConvertTo-Json -Depth 100 | Set-Content -Path $Path -Encoding UTF8
}

function Find-SkillDir([string]$Base, [string]$Name) {
  $candidates = @(
    (Join-Path $Base ("skills\" + $Name)),
    (Join-Path $Base ("skills\local\" + $Name)),
    (Join-Path $Base ("skills\installed\" + $Name))
  )
  foreach ($c in $candidates) {
    if (Test-Path $c) { return $c }
  }
  return $null
}

function Get-ReadyRuntimeNames {
  $out = & openclaw skills check 2>&1
  if ($LASTEXITCODE -ne 0) { return @() }
  $ready = @()
  $inReady = $false
  foreach ($line in $out) {
    if ($line -match "^Ready to use:") {
      $inReady = $true
      continue
    }
    if ($inReady -and [string]::IsNullOrWhiteSpace($line)) { break }
    if ($inReady -and $line -match "^\s{2,}(.+)$") {
      $raw = $Matches[1].Trim()
      $name = $raw -replace "\[USAGE\]\s*", ""
      $name = ($name -replace "[^\x20-\x7E]", "").Trim()
      $dashTokens = @($name.Split(" ") | Where-Object { $_ -match "^[A-Za-z0-9][A-Za-z0-9-]*-[A-Za-z0-9-]+$" })
      if ($dashTokens.Count -gt 0) {
        $name = $dashTokens[-1]
      } else {
        $tokens = @($name.Split(" ") | Where-Object { $_ })
        if ($tokens.Count -gt 0) { $name = $tokens[-1] }
      }
      if ($name) { $ready += $name }
    }
  }
  return $ready | Sort-Object -Unique
}

$registryPath = Join-Path $Root "skill-registry.json"
$auditDir = Join-Path $Root "memory\skill-audit"
New-Item -Path $auditDir -ItemType Directory -Force | Out-Null

$registry = Read-Registry -Path $registryPath
$skillDir = Find-SkillDir -Base $Root -Name $SkillName

$structureOk = $false
$runtimeOk = $false
$registrationOk = $false
$evidenceOk = $false
$errors = @()
$smokeOutput = $null

if ($skillDir) {
  $structureOk = (Test-Path (Join-Path $skillDir "SKILL.md"))
  if (-not $structureOk) { $errors += "SKILL.md missing" }
} else {
  $errors += "Skill directory not found"
}

$readyNames = Get-ReadyRuntimeNames
$registrationOk = $readyNames -contains $SkillName
if (-not $registrationOk) {
  $errors += "Not present in runtime ready list"
}

if ($skillDir) {
  $smoke = Join-Path $skillDir "scripts\smoke-test.ps1"
  if (Test-Path $smoke) {
    try {
      $smokeOutput = & $smoke -Root $Root 2>&1
      $runtimeOk = ($LASTEXITCODE -eq 0)
      if (-not $runtimeOk) {
        $errors += "Smoke test returned non-zero exit code"
      }
    } catch {
      $runtimeOk = $false
      $errors += ("Smoke test error: " + $_.Exception.Message)
    }
  } else {
    # No explicit smoke script: fallback to runtime registration as minimal runtime proof.
    $runtimeOk = $registrationOk
  }
}

$timestamp = [DateTime]::UtcNow.ToString("yyyyMMdd-HHmmss")
$reportPath = Join-Path $auditDir ("audit-" + $SkillName + "-" + $timestamp + ".json")

$report = [PSCustomObject]@{
  skill = $SkillName
  auditedAt = [DateTime]::UtcNow.ToString("o")
  skillDir = $skillDir
  checks = [PSCustomObject]@{
    structure = $structureOk
    runtime = $runtimeOk
    registration = $registrationOk
    evidence = $true
  }
  smokeOutput = $smokeOutput
  errors = $errors
}

$report | ConvertTo-Json -Depth 20 | Set-Content -Path $reportPath -Encoding UTF8
$evidenceOk = (Test-Path $reportPath)

$trackedNames = @($registry.skills.PSObject.Properties | ForEach-Object { $_.Name })
if (-not ($trackedNames -contains $SkillName)) {
  $registry.skills | Add-Member -NotePropertyName $SkillName -NotePropertyValue ([PSCustomObject]@{
    status = "candidate"
    source = "filesystem"
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
$entry.audit.structure = $structureOk
$entry.audit.runtime = $runtimeOk
$entry.audit.registration = $registrationOk
$entry.audit.evidence = $evidenceOk
$entry.audit.lastAuditAt = [DateTime]::UtcNow.ToString("o")

if ($structureOk -and $runtimeOk -and $registrationOk -and $evidenceOk) {
  if ($entry.status -ne "core") {
    $entry.status = "ready"
  }
} else {
  if ($entry.status -eq "core") {
    $entry.status = "ready"
  } elseif ($entry.status -ne "quarantine") {
    $entry.status = "candidate"
  }
}

Write-Registry -Path $registryPath -Registry $registry

[PSCustomObject]@{
  result = if ($structureOk -and $runtimeOk -and $registrationOk -and $evidenceOk) { "pass" } else { "fail" }
  skill = $SkillName
  report = $reportPath
  checks = [PSCustomObject]@{
    structure = $structureOk
    runtime = $runtimeOk
    registration = $registrationOk
    evidence = $evidenceOk
  }
  errors = $errors
} | ConvertTo-Json -Depth 20
