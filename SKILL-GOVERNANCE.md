# Skill Governance Runbook

This runbook implements balanced multi-skill governance with dynamic core pool control.

## One-time bootstrap

1. Reconcile runtime + filesystem:
   - `powershell -File skills/local/skill-governance/scripts/reconcile-ready.ps1 -Root C:\Users\davemelo\.openclaw\workspace`
2. Evaluate core pool:
   - `powershell -File skills/local/skill-governance/scripts/update-core-pool.ps1 -Root C:\Users\davemelo\.openclaw\workspace`

## Install acceptance (required after each install/update)

1. Reconcile:
   - `powershell -File skills/local/skill-governance/scripts/reconcile-ready.ps1 -Root C:\Users\davemelo\.openclaw\workspace`
2. Audit:
   - `powershell -File skills/local/skill-governance/scripts/audit-skill.ps1 -Root C:\Users\davemelo\.openclaw\workspace -SkillName <name>`
3. Check status:
   - `Get-Content -Raw skill-registry.json`

Only pass if all checks are true:

- `structure`
- `runtime`
- `evidence`
- `registration`

## Usage telemetry

Record every important skill execution:

- Success:
  - `powershell -File skills/local/skill-governance/scripts/record-skill-usage.ps1 -Root C:\Users\davemelo\.openclaw\workspace -SkillName <name> -Outcome success -TaskId <task>`
- Failure:
  - `powershell -File skills/local/skill-governance/scripts/record-skill-usage.ps1 -Root C:\Users\davemelo\.openclaw\workspace -SkillName <name> -Outcome failure -TaskId <task>`

## Dynamic cap tuning

Update latest metrics, then evaluate:

1. Set metrics:
   - `powershell -File skills/local/skill-governance/scripts/set-runtime-metrics.ps1 -Root C:\Users\davemelo\.openclaw\workspace -P95FirstResponseMs 13500 -SkillErrorRate 0.07 -OndemandHitRate 0.29`
2. Recompute core pool:
   - `powershell -File skills/local/skill-governance/scripts/update-core-pool.ps1 -Root C:\Users\davemelo\.openclaw\workspace`

## Routing chain

Route with `core -> ready -> explore`:

- `powershell -File skills/local/skill-governance/scripts/route-skill.ps1 -Root C:\Users\davemelo\.openclaw\workspace -TaskText "fix whatsapp timeout" -Candidates "cn-vpn-foreign-app-link,task-execution-guard,failure-pattern-learner"`

Result:

- `skill-selected`: execute selected skill
- `explore-required`: no eligible skill, start autonomous exploration and produce reusable solution

## Weekly cleanup

Run once a week:

- `powershell -File skills/local/skill-governance/scripts/weekly-cleanup.ps1 -Root C:\Users\davemelo\.openclaw\workspace`

This marks stale candidates and missing skills as `retired` without deleting files.
