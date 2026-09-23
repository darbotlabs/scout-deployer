# ScoutDeployer

Deploy Microsoft Scout 0.22.333 to Windows cluster nodes in the Cypherdyne tenant
and provision skills, connectors, MCP tools, permissions, memory, extensions,
session history, and automations — all over SSH via PuTTY.

## Fleet nodes

| Node        | IP          | Status                      |
|-------------|-------------|-----------------------------|
| smax/darbot | 10.1.8.68   | Scout Frontier v0.22.333    |
| darbotlm    | 10.1.8.69   | Gateway + 16-route /scout   |
| anton_studio | (LAN)      | Deployed 2026-06-15         |

## Prerequisites

- PuTTY (`plink.exe` / `pscp.exe`) at `C:\Program Files\PuTTY\`
- SSH key `C:\Users\dayour\.ssh\id_ed25519_shared` authorised on every target node
- `darbot` account is a local Administrator on every target node
- Scout installer at the default path or supplied via `--installer`
- Node.js 18+ (for `npx` usage only)

## Usage

### Double-click (simplest)

```
ScoutDeployer.cmd
```

Opens a console window, prompts for target machine and darbot password,
then runs the full deployment interactively.

### PowerShell direct

```powershell
.\ScoutDeployer.ps1
# With explicit parameters:
.\ScoutDeployer.ps1 -InstallerPath "C:\path\to\Setup.exe" -DarbotPassword "secret"
```

### npx (from any directory after npm link / npx path)

```
npx scout-deployer
npx scout-deployer --installer "C:\Downloads\MicrosoftScout-Windows-0.22.333-x64-Setup.exe"
npx scout-deployer --target 10.1.8.71 --log-dir "C:\Logs\scout"
```

#### All npx flags

| Flag             | PowerShell param        | Default                                   |
|------------------|------------------------|-------------------------------------------|
| `--installer`    | `-InstallerPath`        | `C:\Users\dayour\Downloads\MicrosoftScout-Windows-0.22.333-x64-Setup.exe` |
| `--password`     | `-DarbotPassword`       | prompted                                  |
| `--putty-dir`    | `-PuTTYDir`             | `C:\Program Files\PuTTY`                  |
| `--log-dir`      | `-LogDir`               | `<script-dir>\Logs\`                      |
| `--skills`       | `-LocalSkillsRoot`      | `C:\Users\dayour\.copilot\skills`         |
| `--memory`       | `-LocalMemoryRoot`      | `C:\Users\dayour\.copilot\memory`         |
| `--sessions`     | `-LocalSessionRoot`     | `C:\Users\dayour\.copilot\session-state`  |
| `--connectors`   | `-LocalConnectorsRoot`  | `<script-dir>\connectors\`                |
| `--mcp`          | `-LocalMcpManifestsRoot`| `<script-dir>\mcp-manifests\`             |
| `--automations`  | `-LocalAutomationsRoot` | `<script-dir>\automations\`               |
| `--extensions`   | `-LocalExtensionsList`  | `<script-dir>\extensions.txt`             |

## Phase 2 provisioning menu

After the binary is installed, an interactive menu offers:

```
[1] Skills         — Deploy ~/.copilot/skills/ to each user profile
[2] Connectors     — Deploy connector manifest JSONs
[3] Tools (MCP)    — Register MCP server manifests (odr.exe or manifest drop)
[4] Permissions    — Apply HKLM Scout policy keys + .copilot ACLs
[5] Memory         — Deploy copilot-memory plugin data
[6] Extensions     — Install VS Code extensions list
[7] Session History — Archive and restore Copilot session-state
[8] Automations    — Deploy scheduled tasks, startup scripts, runbooks
[A] All above
[S] Skip
```

## Logs

Every run writes a timestamped log to `Logs\ScoutDeployer_<YYYYMMDD_HHmmss>.log`.
Format: `[YYYY-MM-DD HH:MM:SS] [LEVEL] message`
Levels: STEP, OK, WARN, ERROR, INFO, DEBUG

## Provisioning a new node

Two steps are required and both must complete:

1. Registry policy key (set automatically by this script):
   `HKLM\SOFTWARE\Policies\Scout\AllowScoutFrontierAccess = 1`

2. Interactive Frontier sign-in (cannot be automated):
   The user must launch Scout on the node and sign in as `darbot@timelarp.com`
   through the ClippyClaw app registration (`cb08267c`).

## Repository layout

```
scout-deployer\
  ScoutDeployer.ps1       Main deployment script
  ScoutDeployer.cmd       Double-click launcher
  package.json            npx package manifest
  extensions.txt          VS Code extension IDs for Extension provisioning
  README.md               This file
  bin\
    scout-deployer.js     npx entry point
  connectors\             Connector manifest JSONs (add your own)
  mcp-manifests\          MCP server manifest JSONs (add your own)
  automations\            .ps1 / .xml / .cmd automation files
  Logs\                   Generated at runtime — timestamped run logs
  docs\
    swe-scout-wiki.html   Full Cypherdyne Scout deployment blueprint (source of truth)
    swe_clippyclaw_app_reg.html  ClippyClaw Entra app registration record
```

## Source of truth

`docs\swe-scout-wiki.html` — Cypherdyne Scout Deployment Blueprint (captured 2026-06-14)
Contains: tenant IDs, app registration, fleet node inventory, Intune policy ID, full repo map.
