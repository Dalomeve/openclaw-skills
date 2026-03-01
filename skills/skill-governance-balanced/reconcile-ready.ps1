param(
  [string]$Root = "C:\Users\davemelo\.openclaw\workspace"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-RegistryPath {
  param([string]$Base)
  return (Join-Path $Base "skill-registry.json")
}

function Read-Registry {
  param([string]$Path)
  if (-not (Test-Path $Path)) {
    throw "Missing registry file: $Path"
  }
  return (Get-Content -Raw -Path $Path | ConvertFrom-Json)
}

function Write-Registry {
  param(
    [string]$Path,
    [object]$Registry
  )
  $Registry.updatedAt = [DateTime]::UtcNow.ToString("o")
  $Registry | ConvertTo-Json -Depth 100 | Set-Content -Path $Path -Encoding UTF8
}

function Get-ReadySkillsFromRuntime {
  $out = & openclaw skills check 2>&1
  if ($LASTEXITCODE -ne 0) {
    throw "openclaw skills check failed: $($out -join "`n")"
  }

  $ready = @()
  $inReady = $false
  foreach ($line in $out) {
    if ($line -match "^Ready to use:") {
      $inReady = $true
      continue
    }
    if ($inReady -and [string]::IsNullOrWhiteSpace($line)) {
      break
    }
    if ($inReady -and $line -match "^\s{2,}(.+)$") {
      $raw = $Matches[1].Trim()
      $name = $raw -replace "\[USAGE\]\s*", ""
      $name = ($name -replace "[^\x20-\x7E]", "").Trim()
      $dashTokens = @($name.Split(" ") | Where-Object { $_ -match "^[A-Za-z0-9][A-Za-z0-9-]*-[A-Za-z0-9-]+$" })
      if ($dashTokens.Count -gt 0) {
        $name = $dashTokens[-1]
      } else {
        $tokens = @($name.Split(" ") | Where-Object { $_ })
        if ($tokens.Count -gt 0) {
          $name = $tokens[-1]
        }
      }
      if (-not [string]::IsNullOrWhiteSpace($name)) {
        $ready += $name
      }
    }
  }
  return $ready | Sort-Object -Unique
}

function Ensure-SkillEntry {
  param(
    [object]$Registry,
    [string]$SkillName
  )
  $skillNames = @($Registry.skills.PSObject.Properties | ForEach-Object { $_.Name })
  if (-not ($skillNames -contains $SkillName)) {
    $Registry.skills | Add-Member -NotePropertyName $SkillName -NotePropertyValue ([PSCustomObject]@{
      status = "ready"
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
        registration = $true
        lastAuditAt = $null
      }
      tags = @()
    })
  } else {
    $entry = $Registry.skills.$SkillName
    if ($entry.status -eq "quarantine") {
      # Keep quarantine unless explicitly audited as healthy.
      return
    }
    if ($entry.status -ne "core") {
      $entry.status = "ready"
    }
    if (-not $entry.audit) {
      $entry | Add-Member -NotePropertyName audit -NotePropertyValue ([PSCustomObject]@{})
    }
    $entry.audit.registration = $true
  }
}

$registryPath = Get-RegistryPath -Base $Root
$registry = Read-Registry -Path $registryPath
$runtimeReady = Get-ReadySkillsFromRuntime
$filesystemSkillNames = @()

foreach ($skill in $runtimeReady) {
  Ensure-SkillEntry -Registry $registry -SkillName $skill
}

# Add filesystem skills as candidate when unseen in runtime.
$skillRoots = @(
  (Join-Path $Root "skills"),
  (Join-Path $Root "skills\local")
)

foreach ($sr in $skillRoots) {
  if (-not (Test-Path $sr)) { continue }
  Get-ChildItem -Path $sr -Directory | ForEach-Object {
    $name = $_.Name
    $skillFile = Join-Path $_.FullName "SKILL.md"
    if (-not (Test-Path $skillFile)) { return }
    $filesystemSkillNames += $name
    $tracked = @($registry.skills.PSObject.Properties | ForEach-Object { $_.Name })
    if (-not ($tracked -contains $name)) {
      $registry.skills | Add-Member -NotePropertyName $name -NotePropertyValue ([PSCustomObject]@{
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
          registration = $false
          lastAuditAt = $null
        }
        tags = @()
      })
    }
  }
}

$runtimeSet = @($runtimeReady | Sort-Object -Unique)
$filesystemSet = @($filesystemSkillNames | Sort-Object -Unique)
foreach ($n in @($registry.skills.PSObject.Properties | ForEach-Object { $_.Name })) {
  $entry = $registry.skills.$n
  $existsInRuntime = ($runtimeSet -contains $n)
  $existsInFs = ($filesystemSet -contains $n)
  if (-not $existsInRuntime -and -not $existsInFs) {
    $entry.status = "retired"
    if ($entry.audit) {
      $entry.audit.registration = $false
    }
  }
}

Write-Registry -Path $registryPath -Registry $registry

[PSCustomObject]@{
  result = "ok"
  registry = $registryPath
  runtimeReadyCount = @($runtimeReady).Count
  totalTrackedSkills = @($registry.skills.PSObject.Properties | ForEach-Object { $_.Name }).Count
} | ConvertTo-Json -Depth 10
