---
name: "cowork-cli-install"
description: "Install cowork-cli natively on Windows and wire it into a reusable parallel persistent PowerShell session."
---

Use this skill when a user wants to install cowork-cli, run the aka.ms cowork PowerShell installer, make cowork available on PATH, or set up cowork inside a persistent/parallel PowerShell terminal.

Primary native install command on Windows PowerShell/PowerShell 7:

```powershell
irm https://aka.ms/cowork/ps1 | iex
```

Expected installer behavior:
- Detects Python, commonly `C:\Python314\python.exe` or another available Python.
- Installs/updates the Python package `cowork-cli`.
- Creates `cowork.exe`, often under the user scripts directory, for example:
  `C:\Users\<user>\AppData\Roaming\Python\Python314\Scripts\cowork.exe`
- The current terminal may need PATH refresh before `cowork` is directly callable.

Post-install verification commands:

```powershell
python -m pip show cowork-cli
Get-ChildItem "$env:APPDATA\Python" -Recurse -Filter 'cowork.exe' -ErrorAction SilentlyContinue | Select-Object -First 5 FullName
Get-Command cowork -ErrorAction SilentlyContinue
cowork --version
```

If `cowork` is installed but not on PATH, locate the scripts directory and prepend it for the current session:

```powershell
$coworkExe = Get-ChildItem "$env:APPDATA\Python" -Recurse -Filter 'cowork.exe' -ErrorAction SilentlyContinue | Select-Object -First 1
if ($coworkExe) {
  $coworkScripts = Split-Path $coworkExe.FullName -Parent
  if (($env:Path -split ';') -notcontains $coworkScripts) {
    $env:Path = "$coworkScripts;$env:Path"
  }
}
cowork --version
```

Parallel persistent PowerShell pattern:
1. Create a session workspace, preferably under the assistant/session artifacts folder.
2. Create a bootstrap script that sets environment variables, adds the cowork scripts directory to PATH, and defines helper functions.
3. Start an attached persistent PowerShell session with:

```powershell
pwsh.exe -NoLogo -NoProfile -NoExit -ExecutionPolicy Bypass -File "<bootstrap.ps1>"
```

Recommended bootstrap additions:

```powershell
$env:COWORK_CLI_BOOTSTRAPPED = '1'
$coworkExe = Get-ChildItem "$env:APPDATA\Python" -Recurse -Filter 'cowork.exe' -ErrorAction SilentlyContinue | Select-Object -First 1
if ($coworkExe) {
  $coworkScripts = Split-Path $coworkExe.FullName -Parent
  if (($env:Path -split ';') -notcontains $coworkScripts) {
    $env:Path = "$coworkScripts;$env:Path"
  }
}
function Install-CoworkCli {
  irm https://aka.ms/cowork/ps1 | iex
}
function Test-CoworkCli {
  Get-Command cowork -ErrorAction SilentlyContinue | Select-Object Source
  cowork --version
}
```

Usage inside the persistent shell:

```powershell
Install-CoworkCli
Test-CoworkCli
cowork --help
```

For Clawpilot/Copilot CLI style sessions:
- Use an attached async PowerShell session for an interactive persistent terminal that accepts follow-up commands.
- Use a detached process only for services/daemons that must survive assistant shutdown.
- Write logs to the session workspace and print compact summaries.
- Do not kill processes by name; stop by specific PID only.

Known-good validation example:
- Installed package: `cowork-cli 1.21.22`
- Executable path example: `C:\Users\dayour\AppData\Roaming\Python\Python314\Scripts\cowork.exe`
- Validation: `cowork --version` returns `cowork 1.21.22`.
