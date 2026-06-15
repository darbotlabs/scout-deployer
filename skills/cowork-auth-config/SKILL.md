---
name: "cowork-auth-config"
description: "Manage Cowork authentication and configuration with `cowork auth` and `cowork config` commands."
---

Use this skill when the user wants to check, log in, refresh, log out, initialize, view, or set Cowork CLI configuration.

Command surface:
- Auth: `cowork auth login`, `cowork auth check`, `cowork auth status`, `cowork auth whoami`, `cowork auth refresh`, `cowork auth logout`.
- Config: `cowork config init`, `cowork config show`, `cowork config set <key> <value>`.

Workflow:
1. Verify `cowork` exists before running.
2. For health checks, prefer `cowork auth status` or `cowork auth check`, then `cowork auth whoami` if identity details are needed.
3. For expired tokens, run `cowork auth refresh` first when appropriate.
4. For interactive login, tell the user before launching `cowork auth login` because it may require browser/device authentication.
5. Only run `cowork auth logout` when the user explicitly asks to sign out or clear tokens.
6. For config inspection, use `cowork config show`.
7. For config changes, confirm the exact key/value before running `cowork config set`, unless the user provided them explicitly.
8. For reset/init, avoid destructive config reset unless explicitly requested.

Privacy and safety:
- Do not reveal tokens or secrets. If command output includes sensitive token material, redact it in summaries.
- Do not auto-install or update Cowork from this skill unless explicitly requested.
