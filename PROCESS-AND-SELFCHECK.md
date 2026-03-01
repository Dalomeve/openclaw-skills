# OpenClaw Skill Governance - Process and Self Check

Date: 2026-03-02
Owner: Dalomeve
Published Skill: `skill-governance-balanced@1.0.0`
Skill ID: `k9754j4ft6s2e1fs9rn02emja1823fvr`

## What was optimized today

1. Built a unified skill lifecycle state model:
   - `candidate -> ready -> core -> quarantine -> retired`
2. Added a dual-pool routing model:
   - `core` first
   - then all `ready` skills (on-demand)
   - then autonomous exploration when no eligible skill exists
3. Added install acceptance gate:
   - structure check
   - runtime check
   - evidence check
   - registration check
4. Added dynamic core pool controls:
   - core range `8..14`
   - inactivity demotion window `3 days`
   - telemetry-based cap tuning
5. Added failure governance:
   - usage telemetry
   - failure streak quarantine
   - weekly non-destructive cleanup
6. Added source-of-truth registry:
   - `skill-registry.json`

## Implemented scripts

- `reconcile-ready.ps1`
- `audit-skill.ps1`
- `record-skill-usage.ps1`
- `set-runtime-metrics.ps1`
- `update-core-pool.ps1`
- `route-skill.ps1`
- `weekly-cleanup.ps1`

## Workspace integration changes

- `AGENTS.md`: required routing chain + acceptance gate + dynamic core rules
- `HEARTBEAT.md`: daily governance refresh
- `TOOLS.md`: governance runtime contract and script index
- `CAPABILITIES.md`: quick recheck commands
- `SKILL-GOVERNANCE.md`: runbook

## Publish proof

- `npx clawhub@latest publish ...`
- Result: `Published skill-governance-balanced@1.0.0 (k9754j4ft6s2e1fs9rn02emja1823fvr)`
- `npx clawhub@latest inspect skill-governance-balanced` confirms owner/version/summary

## New-user self-check flow

1. Install:
   - `npx clawhub@latest install skill-governance-balanced`
2. Reconcile:
   - `powershell -File skills/local/skill-governance/scripts/reconcile-ready.ps1 -Root <workspace>`
3. Audit one known ready skill:
   - `powershell -File skills/local/skill-governance/scripts/audit-skill.ps1 -Root <workspace> -SkillName task-execution-guard`
4. Route test:
   - `powershell -File skills/local/skill-governance/scripts/route-skill.ps1 -Root <workspace> -TaskText "smoke test" -Candidates "task-execution-guard,cn-vpn-foreign-app-link"`
5. Record usage:
   - `powershell -File skills/local/skill-governance/scripts/record-skill-usage.ps1 -Root <workspace> -SkillName task-execution-guard -Outcome success -TaskId smoke -Evidence "manual check"`

If steps 2-5 succeed, governance is working for a fresh OpenClaw deployment.
