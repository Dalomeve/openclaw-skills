# API Config Template Notes

Use `templates/openclaw.minimal.example.json` as the base for a fresh Windows host.

## Required manual replacements

1. `models.providers.bailian.apiKey`
- Replace with the target machine's valid Coding Plan API key.

2. `agents.defaults.workspace`
- Replace `REPLACE_WITH_WINDOWS_USER` with the real Windows username.

3. `gateway.auth.token`
- Set a human-readable token and keep the same value when binding dashboard or extensions.

## Recommended apply flow

1. Run `openclaw onboard` once to create the initial config directory.
2. Back up the generated file:
   - `C:\Users\<User>\.openclaw\openclaw.json`
3. Merge the example values into the real config instead of blindly overwriting unrelated future fields.
4. Save the final file as:
   - `C:\Users\<User>\.openclaw\openclaw.json`
5. Restart gateway and verify:
   - `openclaw doctor`
   - `openclaw browser status --json`

## Minimum validation

```powershell
openclaw --version
openclaw doctor
openclaw browser status --json
```

If doctor passes and the browser profile comes up, the host is ready for workspace rules and optional skill governance.
