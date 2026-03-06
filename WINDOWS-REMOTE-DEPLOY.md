# Windows Remote Deploy Baseline

This document is the minimum remote bootstrap flow for a fresh Windows machine where OpenClaw will be installed first and then upgraded to the governance baseline from this repo.

It is intentionally pragmatic:

- native Windows flow
- no WSL2 requirement
- no Docker requirement
- no Cursor requirement

## What to install on the new Windows host

Run these in the built-in Windows PowerShell as Administrator.

### 1. Node.js

```powershell
winget install OpenJS.NodeJS.LTS
```

Verify in a new terminal:

```powershell
node -v
npm -v
```

### 2. Git

```powershell
winget install Git.Git
```

Verify:

```powershell
git --version
```

### 3. Chrome

```powershell
winget install Google.Chrome
```

Chrome is used for dashboard login, browser relay, and web automation flows.

### 4. Optional Python

Install only if the remote bootstrap or later skills will use Python scripts.

```powershell
winget install Python.Python.3.12
```

Verify:

```powershell
python --version
pip --version
```

### 5. OpenClaw

```powershell
npm install -g openclaw@latest
```

Verify:

```powershell
openclaw --version
```

If `openclaw` is not found, inspect npm global prefix:

```powershell
npm config get prefix
```

Typical Windows npm global bin:

```text
C:\Users\<User>\AppData\Roaming\npm
```

If needed, add that path to the current user PATH and reopen the terminal:

```powershell
[Environment]::SetEnvironmentVariable(
  "Path",
  $env:Path + ";C:\Users\<User>\AppData\Roaming\npm",
  "User"
)
```

### 6. First OpenClaw bootstrap

```powershell
openclaw onboard
openclaw doctor
```

If PowerShell blocks script execution:

```powershell
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
```

Then reopen the terminal and rerun the failing command.

## Prepare SSH for remote handoff

Run in built-in Windows PowerShell as Administrator:

```powershell
Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0
Start-Service sshd
Set-Service -Name sshd -StartupType Automatic
New-NetFirewallRule -Name sshd -DisplayName "OpenSSH Server (sshd)" -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22
```

Verify:

```powershell
ssh -V
Get-Service sshd
```

Expected:

- `ssh -V` returns a version string
- `Get-Service sshd` shows `Running`

## Information the remote operator needs

The target host should send back the output of these commands:

```powershell
whoami
hostname
ipconfig
curl ifconfig.me
ssh -V
Get-Service sshd
```

Minimum fields to share:

```text
User: <whoami output>
HostName: <hostname output>
LAN_IP: <IPv4 from ipconfig>
Public_IP: <curl ifconfig.me output>
SSH_Port: 22
SSHD_Status: Running
```

If a non-default SSH port is used, include that instead of `22`.

## How the remote operator connects

Password auth:

```powershell
ssh <User>@<Host>
```

Custom port:

```powershell
ssh -p <Port> <User>@<Host>
```

Private key auth:

```powershell
ssh -i C:\path\to\key <User>@<Host>
```

## What happens after SSH access is ready

Once SSH works, the remote operator can:

1. install or verify Git and OpenClaw
2. clone the GitHub repo
3. pull governance assets into the target workspace
4. install `skill-governance-balanced`
5. run reconciliation and audit acceptance
6. apply workspace rule files and verify doctor/browser health

This repo currently covers the governance layer well.
It does not yet provide a full one-command machine bootstrap for:

- provider/model templates
- gateway token provisioning
- workspace core-file templating
- browser login state transfer

Those remain operator-guided steps after the base install.

## Fresh-host validation checklist

Run these after installation:

```powershell
node -v
npm -v
git --version
openclaw --version
ssh -V
openclaw doctor
```

Then validate the governance layer:

```powershell
npx clawhub@latest install skill-governance-balanced
powershell -File skills/local/skill-governance/scripts/reconcile-ready.ps1 -Root <workspace>
powershell -File skills/local/skill-governance/scripts/audit-skill.ps1 -Root <workspace> -SkillName task-execution-guard
```

If these pass, the host is ready for the next stage: workspace rules, skill registry, and task-specific automation setup.
