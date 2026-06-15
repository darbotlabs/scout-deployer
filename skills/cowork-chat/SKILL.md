---
name: "cowork-chat"
description: "Launch and manage the interactive `cowork chat` REPL in a persistent PowerShell session for streaming multi-turn chat."
---

Use this skill when the user wants an interactive Cowork chat REPL rather than the full TUI or one-shot send.

Command surface:
- `cowork chat [OPTIONS]`
- Useful options include `--island/-i`, `--user/-u`, `--model/-m`, `--profile/-p`, `--container-type`, `--resume`, `--resume-latest/-R`, `--auto-approve`, `--mock-mode`, `--poll`, and repeated `--flag key=value`.
- Slash commands inside chat include `/help`, `/new`, `/ref email:<subject>`, `/ref onedrive:<url>`, `/ref meeting:<title>`, `/upload <path>`, `/files`, `/download 1`, `/trace`, `/raw`, `/island <name>`, `/model <name>`, `/id`, and `/quit`.

Workflow:
1. Check whether a `cowork-chat` PowerShell session is already active with `list_powershell`.
2. If active, use `read_powershell` for current output and `write_powershell` for user messages or slash commands.
3. If not active, verify `cowork` exists and start `cowork chat` using `powershell` with `mode: "async"`, `shellId: "cowork-chat"`, and an initial wait around 10 seconds.
4. Include user-requested command flags when starting, such as model, profile, island, or resume latest.
5. Do not start duplicate chat sessions unless the user asks for a fresh session.
6. Stop only when the user asks, preferably by sending `/quit` with `write_powershell`; use `stop_powershell` only if needed.

Operational notes:
- Use async mode so the REPL stays interactive.
- Do not use detached mode unless the user explicitly wants a process that survives Clawpilot shutdown.
- Avoid name-based process termination.
- Keep responses concise: running, already active, message sent, or stopped.
