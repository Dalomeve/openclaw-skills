# Security Notes

This repository contains OpenClaw governance skills intended for local operations.

## Threat model (current scope)

- Local workspace governance only
- No built-in external API calls
- No secret exfiltration logic

## What scripts are allowed to do

- Read and write local files under the workspace
- Execute local `openclaw` CLI checks
- Update skill lifecycle state in `skill-registry.json`

## What scripts do not do

- Download and execute remote payloads
- Send credentials/tokens to external endpoints
- Delete workspace files during cleanup

## Operator guidance

- Review diffs before upgrading versions
- Keep third-party skills as `candidate` until acceptance audit passes
- Use least privilege for local shell/runtime
