param(
  [string]$Root = "C:\Users\davemelo\.openclaw\workspace",
  [double]$P95FirstResponseMs,
  [double]$SkillErrorRate,
  [double]$OndemandHitRate
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$registryPath = Join-Path $Root "skill-registry.json"
$registry = Get-Content -Raw -Path $registryPath | ConvertFrom-Json

if ($PSBoundParameters.ContainsKey("P95FirstResponseMs")) {
  $registry.metrics.latest.p95FirstResponseMs = $P95FirstResponseMs
}
if ($PSBoundParameters.ContainsKey("SkillErrorRate")) {
  $registry.metrics.latest.skillErrorRate = $SkillErrorRate
}
if ($PSBoundParameters.ContainsKey("OndemandHitRate")) {
  $registry.metrics.latest.ondemandHitRate = $OndemandHitRate
}

$registry.updatedAt = [DateTime]::UtcNow.ToString("o")
$registry | ConvertTo-Json -Depth 100 | Set-Content -Path $registryPath -Encoding UTF8

[PSCustomObject]@{
  result = "ok"
  registry = $registryPath
  latest = $registry.metrics.latest
} | ConvertTo-Json -Depth 10
