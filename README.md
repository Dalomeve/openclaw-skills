# openclaw-skills

Practical skills and governance assets for OpenClaw, with a focus on stability for real-world multi-skill deployments.

## Included now

- `skill-governance-balanced`  
  Dual-pool governance (`core` + `ready`) with:
  - lifecycle states (`candidate/ready/core/quarantine/retired`)
  - install acceptance gate
  - dynamic core pool (8..14)
  - usage telemetry and quarantine
  - weekly non-destructive cleanup

- `PROCESS-AND-SELFCHECK.md`  
  Today’s optimization process, release result, and a new-user validation checklist.

- `SKILL-GOVERNANCE.md`  
  Operator runbook for daily/weekly governance operations.

## Install

```powershell
npx clawhub@latest install skill-governance-balanced
```

## Quick validation

```powershell
powershell -File skills/local/skill-governance/scripts/reconcile-ready.ps1 -Root <workspace>
powershell -File skills/local/skill-governance/scripts/audit-skill.ps1 -Root <workspace> -SkillName task-execution-guard
powershell -File skills/local/skill-governance/scripts/route-skill.ps1 -Root <workspace> -TaskText "smoke test" -Candidates "task-execution-guard,cn-vpn-foreign-app-link"
```

## Structure

- `skills/skill-governance-balanced/`
  - `SKILL.md`
  - `scripts/*.ps1`
- `PROCESS-AND-SELFCHECK.md`
- `SKILL-GOVERNANCE.md`

## Notes

- Designed for Windows PowerShell compatibility.
- Keep `skill-registry.json` as the single source of truth in your OpenClaw workspace.
