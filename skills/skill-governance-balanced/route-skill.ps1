param(
  [string]$Root = "C:\Users\davemelo\.openclaw\workspace",
  [Parameter(Mandatory = $true)]
  [string]$TaskText,
  [string]$Candidates = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$registryPath = Join-Path $Root "skill-registry.json"
$registry = Get-Content -Raw -Path $registryPath | ConvertFrom-Json

$candidateList = @()
if ($Candidates) {
  $candidateList = $Candidates.Split(",") | ForEach-Object { $_.Trim() } | Where-Object { $_ }
}

if ($candidateList.Count -eq 0) {
  # Fallback heuristic: pick all tracked skills as candidates when caller did not pre-filter.
  $candidateList = @($registry.skills.PSObject.Properties | ForEach-Object { $_.Name })
}

$core = @()
$ready = @()
$trackedNames = @($registry.skills.PSObject.Properties | ForEach-Object { $_.Name })
foreach ($name in $candidateList) {
  if (-not ($trackedNames -contains $name)) { continue }
  $status = $registry.skills.$name.status
  if ($status -eq "core") { $core += $name }
  elseif ($status -eq "ready") { $ready += $name }
}

$selected = $null
$chainStep = $null

if ($core.Count -gt 0) {
  $selected = $core[0]
  $chainStep = "core"
} elseif ($ready.Count -gt 0) {
  $selected = $ready[0]
  $chainStep = "ondemand-ready"
}

if ($selected) {
  [PSCustomObject]@{
    result = "skill-selected"
    step = $chainStep
    selectedSkill = $selected
    task = $TaskText
    considered = [PSCustomObject]@{
      core = $core
      ready = $ready
      totalCandidates = $candidateList.Count
    }
    fallback = "If selected skill fails once, try next ready skill. If all fail, switch to explore."
  } | ConvertTo-Json -Depth 20
  exit 0
}

[PSCustomObject]@{
  result = "explore-required"
  step = "explore"
  task = $TaskText
  message = "No eligible core/ready skill matched. Start autonomous exploration using official docs, issues, and prior memory; then write reusable fix proposal."
  proposal = [PSCustomObject]@{
    produceArtifact = "skills/local/<new-skill>/SKILL.md + scripts + verification"
    verify = "Run acceptance audit before marking ready."
  }
} | ConvertTo-Json -Depth 20
