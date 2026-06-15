#Requires -Version 5.1
<#
.SYNOPSIS
    ScoutDeployer — Deploy Microsoft Scout and provision extensions, skills, connectors,
    tools, permissions, memory, session history, and automations to remote cluster nodes.

.DESCRIPTION
    Phase 1 — Binary Deployment:
      1. Prompts for target machine (IP or hostname) and darbot credentials.
      2. Discovers host key fingerprint and validates SSH connectivity.
      3. Enumerates user profiles under C:\Users\ on the remote node.
      4. Presents a selection menu — pick individual accounts or deploy to all.
      5. For each selected account:
         - Stages the Scout installer to C:\Windows\Temp\ (once, shared).
         - Sets HKLM\SOFTWARE\Policies\Scout\AllowScoutFrontierAccess = 1.
         - Runs the installer silently under the target user via a scheduled task.
         - Waits and verifies the install completed.

    Phase 2 — Provisioning (optional, post-install):
      After binary deployment succeeds, an interactive menu offers:
        [1] Skills         — Deploy Copilot skill directories from local ~/.copilot/skills/
        [2] Connectors     — Deploy Power Platform / API connector manifests
        [3] Tools (MCP)    — Register MCP server manifests via odr.exe or manifest drop
        [4] Permissions    — Apply additional registry policy keys and file ACLs
        [5] Memory         — Copy copilot-memory plugin data and Scout memory files
        [6] Extensions     — Install VS Code extensions list on the remote node
        [7] Session History — Archive and restore Copilot session-state data
        [8] Automations    — Deploy scheduled tasks, startup scripts, and runbooks
        [A] All above
        [S] Skip / exit

    Logging:
      All output is written to both console and a timestamped .log file under
      $LogDir (default: clippy_cluster_nodes\Logs\).
      Log format: [YYYY-MM-DD HH:MM:SS] [LEVEL] message

.PARAMETER InstallerPath
    Path to MicrosoftScout-Windows-*.exe on the local machine.

.PARAMETER DarbotPassword
    darbot account password on the target. Prompted if blank.

.PARAMETER PuTTYDir
    Directory containing plink.exe and pscp.exe.

.PARAMETER LogDir
    Directory where .log files are written. Created if absent.

.PARAMETER LocalSkillsRoot
    Local source for skills deployment. Default: C:\Users\dayour\.copilot\skills

.PARAMETER LocalMemoryRoot
    Local source for memory data deployment. Default: C:\Users\dayour\.copilot\memory

.PARAMETER LocalSessionRoot
    Local source for session history deployment. Default: C:\Users\dayour\.copilot\session-state

.PARAMETER LocalConnectorsRoot
    Local source for connector manifests. Default: <script-dir>\connectors

.PARAMETER LocalMcpManifestsRoot
    Local source for MCP server manifests. Default: <script-dir>\mcp-manifests

.PARAMETER LocalAutomationsRoot
    Local source for automation scripts and task XMLs. Default: <script-dir>\automations

.PARAMETER LocalExtensionsList
    Path to a text file listing VS Code extension IDs (one per line).
    Default: <script-dir>\extensions.txt

.NOTES
    Prerequisites:
      - PuTTY (plink.exe / pscp.exe) at C:\Program Files\PuTTY\
      - SSH key C:\Users\dayour\.ssh\id_ed25519_shared authorised on the target.
      - darbot account is a local Administrator on the target node.
      - Scout installer at $InstallerPath (default: dayour Downloads folder).
      - Cypherdyne tenant: 6b104499-c49f-45dc-b3a2-df95efd6eeb4
      - ClippyClaw app reg: cb08267c-55a2-4f0d-9c5a-58d90444b82d

    Frontier gate requires interactive sign-in as darbot@timelarp.com after deploy.
#>

[CmdletBinding()]
param(
    [string] $InstallerPath = "C:\Users\dayour\Downloads\MicrosoftScout-Windows-0.22.333-x64-Setup.exe",
    [string] $DarbotPassword = "",
    [string] $PuTTYDir       = "C:\Program Files\PuTTY",
    [string] $LogDir         = "",
    [string] $LocalSkillsRoot       = "C:\Users\dayour\.copilot\skills",
    [string] $LocalMemoryRoot       = "C:\Users\dayour\.copilot\memory",
    [string] $LocalSessionRoot      = "C:\Users\dayour\.copilot\session-state",
    [string] $LocalConnectorsRoot   = "",
    [string] $LocalMcpManifestsRoot = "",
    [string] $LocalAutomationsRoot  = "",
    [string] $LocalExtensionsList   = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ── Script-level paths ────────────────────────────────────────────────────────

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

if ([string]::IsNullOrEmpty($LogDir)) {
    $LogDir = Join-Path $ScriptDir "Logs"
}
if ([string]::IsNullOrEmpty($LocalConnectorsRoot))   { $LocalConnectorsRoot   = Join-Path $ScriptDir "connectors" }
if ([string]::IsNullOrEmpty($LocalMcpManifestsRoot)) { $LocalMcpManifestsRoot = Join-Path $ScriptDir "mcp-manifests" }
if ([string]::IsNullOrEmpty($LocalAutomationsRoot))  { $LocalAutomationsRoot  = Join-Path $ScriptDir "automations" }
if ([string]::IsNullOrEmpty($LocalExtensionsList))   { $LocalExtensionsList   = Join-Path $ScriptDir "extensions.txt" }

if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir | Out-Null }

$RunTimestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$LogFile      = Join-Path $LogDir "ScoutDeployer_${RunTimestamp}.log"

# ── Logging framework ─────────────────────────────────────────────────────────

function Write-Log {
    param(
        [string] $Level,   # INFO | WARN | ERROR | DEBUG | STEP | OK
        [string] $Message,
        [System.ConsoleColor] $Color = [System.ConsoleColor]::White
    )
    $ts   = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "[$ts] [$Level] $Message"
    Add-Content -Path $LogFile -Value $line
    Write-Host $line -ForegroundColor $Color
}

function Log-Step  { param($msg) Write-Log "STEP"  $msg  Cyan }
function Log-Ok    { param($msg) Write-Log "OK"    "  $msg"  Green }
function Log-Warn  { param($msg) Write-Log "WARN"  "  $msg"  Yellow }
function Log-Error { param($msg) Write-Log "ERROR" "  $msg"  Red }
function Log-Info  { param($msg) Write-Log "INFO"  "  $msg"  White }
function Log-Debug { param($msg) if ($VerbosePreference -ne 'SilentlyContinue') { Write-Log "DEBUG" "  $msg" DarkGray } }

function Log-Section {
    param($title)
    $line = "=" * 60
    Write-Log "INFO" $line Cyan
    Write-Log "INFO" "  $title" Cyan
    Write-Log "INFO" $line Cyan
}

function Log-RemoteOutput {
    param([string[]] $Lines, [string] $Prefix = "    remote> ")
    foreach ($l in $Lines) {
        if ($l.Trim()) { Log-Debug "$Prefix$l" }
    }
}

# ── Banner ────────────────────────────────────────────────────────────────────

Log-Section "ScoutDeployer — $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Log-Info "Log file: $LogFile"
Log-Info "Scout installer: $InstallerPath"

# ── Validate local prerequisites ──────────────────────────────────────────────

$plink = Join-Path $PuTTYDir "plink.exe"
$pscp  = Join-Path $PuTTYDir "pscp.exe"

foreach ($bin in $plink, $pscp) {
    if (-not (Test-Path $bin)) {
        Log-Error "Required binary not found: $bin"
        Log-Error "Install PuTTY or set -PuTTYDir to the correct directory."
        exit 1
    }
}
Log-Ok "PuTTY binaries found at $PuTTYDir"

if (-not (Test-Path $InstallerPath)) {
    Log-Error "Scout installer not found: $InstallerPath"
    Log-Error "Set -InstallerPath to the correct path and retry."
    exit 1
}
Log-Ok "Scout installer confirmed: $InstallerPath"

$installerName = Split-Path $InstallerPath -Leaf

# ── Step 1 — Target machine ───────────────────────────────────────────────────

Log-Step "Step 1/8 — Target machine"
$target = (Read-Host "  Enter IP address or hostname").Trim()
if ([string]::IsNullOrEmpty($target)) { Log-Error "No target specified."; exit 1 }
Log-Ok "Target: $target"

# ── Step 2 — Credentials ─────────────────────────────────────────────────────

Log-Step "Step 2/8 — darbot credentials"
if ([string]::IsNullOrEmpty($DarbotPassword)) {
    $securePw      = Read-Host "  darbot password for $target" -AsSecureString
    $DarbotPassword = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePw))
}
Log-Info "Credentials accepted (password not logged)."

# ── Step 3 — Host key & connectivity ─────────────────────────────────────────

Log-Step "Step 3/8 — Discover host key and validate connectivity"

$keyScan     = & $plink -ssh "darbot@$target" -pw $DarbotPassword -batch "echo CONNECTED" 2>&1
$hostKeyLine = $keyScan | Where-Object { $_ -match "SHA256:" } | Select-Object -First 1
$hostKey     = ""

if ($hostKeyLine -match "(ssh-\S+\s+\d+\s+SHA256:\S+)") {
    $hostKey = $matches[1]
    Log-Ok "Host key fingerprint: $hostKey"
} else {
    Log-Warn "Could not parse host key; will rely on PuTTY known_hosts cache (-batch)."
}

function Invoke-Remote {
    param([string] $Cmd, [switch] $NoLog)
    $out = if ($hostKey) {
        & $plink -ssh "darbot@$target" -pw $DarbotPassword -hostkey $hostKey $Cmd 2>&1
    } else {
        & $plink -ssh "darbot@$target" -pw $DarbotPassword -batch $Cmd 2>&1
    }
    if (-not $NoLog) { Log-RemoteOutput $out }
    return $out
}

function Copy-ToRemote {
    param([string] $Local, [string] $Remote)
    Log-Info "Copying $Local -> darbot@${target}:$Remote"
    $out = if ($hostKey) {
        & $pscp -pw $DarbotPassword -hostkey $hostKey $Local "darbot@${target}:$Remote" 2>&1
    } else {
        & $pscp -pw $DarbotPassword -batch $Local "darbot@${target}:$Remote" 2>&1
    }
    Log-RemoteOutput $out "    pscp> "
    return $out
}

function Copy-DirToRemote {
    param([string] $LocalDir, [string] $RemoteDir)
    Log-Info "Recursive copy $LocalDir -> darbot@${target}:$RemoteDir"
    $out = if ($hostKey) {
        & $pscp -pw $DarbotPassword -hostkey $hostKey -r $LocalDir "darbot@${target}:$RemoteDir" 2>&1
    } else {
        & $pscp -pw $DarbotPassword -batch -r $LocalDir "darbot@${target}:$RemoteDir" 2>&1
    }
    Log-RemoteOutput $out "    pscp> "
    return $out
}

$test = Invoke-Remote "echo SCOUT_DEPLOYER_CONNECTED" -NoLog
if ($test -notcontains "SCOUT_DEPLOYER_CONNECTED") {
    Log-Error "SSH connection failed to $target as darbot."
    Log-Error ($test -join " | ")
    exit 1
}
Log-Ok "SSH connectivity confirmed: darbot@$target"

# ── Step 4 — Discover user profiles ──────────────────────────────────────────

Log-Step "Step 4/8 — Discover user profiles on $target"

$dirOutput    = Invoke-Remote 'dir /ad /b C:\Users' -NoLog
$systemFolders = @("Public", "Default", "Default User", "All Users", "desktop.ini", "")
$profiles     = $dirOutput | Where-Object {
    $_.Trim() -ne "" -and $_ -notin $systemFolders -and $_ -notmatch "^\s*$"
}

if ($profiles.Count -eq 0) {
    Log-Error "No user profiles found under C:\Users\ on $target."
    exit 1
}

Log-Ok "Found $($profiles.Count) profile(s): $($profiles -join ', ')"

# System facts
$remoteHostname = (Invoke-Remote "hostname" -NoLog | Select-Object -First 1).Trim()
$remoteOS       = (Invoke-Remote "ver" -NoLog | Select-Object -First 1).Trim()
Log-Info "Remote hostname: $remoteHostname"
Log-Info "Remote OS: $remoteOS"

# ── Step 5 — Account selection ────────────────────────────────────────────────

Log-Step "Step 5/8 — Select target accounts"
Write-Host ""
Write-Host "  Available profiles on ${target}:"
for ($i = 0; $i -lt $profiles.Count; $i++) {
    Write-Host ("  [{0,2}] {1}" -f ($i + 1), $profiles[$i])
}
Write-Host "  [ A] All profiles"
Write-Host ""

$selection = (Read-Host "  Enter numbers separated by commas, or A for all").Trim().ToUpper()
[string[]] $selectedProfiles = @()

if ($selection -eq "A") {
    $selectedProfiles = $profiles
    Log-Ok "Deploying to all $($profiles.Count) profile(s)."
} else {
    $indices = $selection -split "," | ForEach-Object { $_.Trim() } | Where-Object { $_ -match "^\d+$" }
    foreach ($idx in $indices) {
        $i = [int]$idx - 1
        if ($i -ge 0 -and $i -lt $profiles.Count) {
            $selectedProfiles += $profiles[$i]
        } else {
            Log-Warn "Index $idx out of range — skipped."
        }
    }
    if ($selectedProfiles.Count -eq 0) {
        Log-Error "No valid profiles selected."
        exit 1
    }
    Log-Ok "Selected profiles: $($selectedProfiles -join ', ')"
}

# ── Step 6 — Pre-flight ───────────────────────────────────────────────────────

Log-Step "Step 6/8 — Pre-flight: stage installer and set machine policy"

$remoteStaging = "C:\Windows\Temp\$installerName"
$remoteCheck   = Invoke-Remote "if exist `"$remoteStaging`" (echo EXISTS) else (echo MISSING)" -NoLog

if ($remoteCheck -contains "MISSING") {
    Log-Info "Staging installer on $target at $remoteStaging (293 MB — may take a few minutes)..."
    $copyResult = Copy-ToRemote $InstallerPath $remoteStaging
    if ($LASTEXITCODE -ne 0) {
        Log-Error "Failed to copy installer to $target."
        Log-Error ($copyResult -join " | ")
        exit 1
    }
    Log-Ok "Installer staged: $remoteStaging"
} else {
    Log-Ok "Installer already present on remote: $remoteStaging"
}

# Verify remote file size
$remoteSize = Invoke-Remote "for %F in (`"$remoteStaging`") do @echo %~zF" -NoLog
Log-Info "Remote installer size: $($remoteSize | Select-Object -First 1) bytes"

# Machine-wide Frontier policy key
$policyResult = Invoke-Remote 'reg add "HKLM\SOFTWARE\Policies\Scout" /v AllowScoutFrontierAccess /t REG_DWORD /d 1 /f' -NoLog
if ($policyResult -match "successfully") {
    Log-Ok "AllowScoutFrontierAccess = 1 written to HKLM\SOFTWARE\Policies\Scout"
} else {
    Log-Warn "Policy key response: $($policyResult -join ' ')"
}

# Confirm policy key reads back
$policyRead = Invoke-Remote 'reg query "HKLM\SOFTWARE\Policies\Scout" /v AllowScoutFrontierAccess' -NoLog
Log-Info "Policy key current value: $($policyRead | Select-Object -Last 2 | ForEach-Object { $_.Trim() } | Where-Object { $_ } | Select-Object -First 1)"

# ── Step 7 — Deploy per account ───────────────────────────────────────────────

Log-Step "Step 7/8 — Deploy Scout binary to selected profiles"

$deployResults = @()

foreach ($profile in $selectedProfiles) {
    Log-Info "---"
    Log-Info "Processing profile: $profile"

    $installDir = "C:\Users\$profile\AppData\Local\Programs\Microsoft Scout"
    $exePath    = "$installDir\Microsoft Scout.exe"

    # Skip if already installed
    $alreadyInstalled = Invoke-Remote "if exist `"$exePath`" (echo INSTALLED) else (echo NOT_INSTALLED)" -NoLog
    if ($alreadyInstalled -contains "INSTALLED") {
        Log-Ok "Scout already installed for $profile — skipping binary install."
        $deployResults += [PSCustomObject]@{
            Profile = $profile; Phase = "Binary"; Status = "Already installed"; Detail = $exePath
        }
        continue
    }

    # Determine account type: local vs AzureAD (Entra-joined)
    $localCheckOut = Invoke-Remote "net user `"$profile`" >nul 2>&1 && echo LOCAL || echo NOTLOCAL" -NoLog
    $isLocal = ($localCheckOut -join "") -match "LOCAL" -and ($localCheckOut -join "") -notmatch "NOTLOCAL"
    $ruUser  = if ($isLocal) { "$remoteHostname\$profile" } else { "AzureAD\$profile" }
    Log-Info "Account type for ${profile}: $(if ($isLocal) {'local'} else {'AzureAD/Entra'}) — schtasks RU: $ruUser"

    $taskName = "ScoutDeploy_$($profile -replace '[^a-zA-Z0-9]','')"

    # Delete any stale task with same name
    Invoke-Remote "schtasks /Delete /TN `"$taskName`" /F >nul 2>&1" -NoLog | Out-Null

    # Create scheduled task to run installer as target user
    $createOut = Invoke-Remote (
        "schtasks /Create /TN `"$taskName`" /TR `"`"$remoteStaging`" /S`" " +
        "/SC ONCE /ST 00:00 /RU `"$ruUser`" /RL HIGHEST /F"
    ) -NoLog

    if (($createOut -join "") -notmatch "SUCCESS") {
        Log-Warn "schtasks create as '$ruUser' did not report SUCCESS: $($createOut -join ' ')"
        Log-Info "Retrying with local account format: $remoteHostname\$profile"
        $ruUser    = "$remoteHostname\$profile"
        $createOut = Invoke-Remote (
            "schtasks /Delete /TN `"$taskName`" /F >nul 2>&1 & " +
            "schtasks /Create /TN `"$taskName`" /TR `"`"$remoteStaging`" /S`" " +
            "/SC ONCE /ST 00:00 /RU `"$ruUser`" /RL HIGHEST /F"
        ) -NoLog
        if (($createOut -join "") -notmatch "SUCCESS") {
            Log-Warn "Second attempt also did not return SUCCESS. Proceeding anyway."
        }
    }
    Log-Ok "Scheduled task created: $taskName (RU: $ruUser)"

    # Run the task
    $runOut = Invoke-Remote "schtasks /Run /TN `"$taskName`"" -NoLog
    Log-Info "Task triggered. Waiting 45 seconds for Squirrel installer to complete..."
    Start-Sleep -Seconds 45

    # Check task last run result
    $taskInfo = Invoke-Remote "schtasks /Query /TN `"$taskName`" /FO LIST /V 2>&1" -NoLog
    $lastResult = $taskInfo | Where-Object { $_ -match "Last Run Result" } | Select-Object -First 1
    Log-Info "Scheduled task status: $($lastResult.Trim())"

    # Verify installation
    $verifyOut = Invoke-Remote "if exist `"$exePath`" (echo INSTALLED) else (echo NOT_INSTALLED)" -NoLog

    # Clean up scheduled task
    Invoke-Remote "schtasks /Delete /TN `"$taskName`" /F" -NoLog | Out-Null
    Log-Info "Scheduled task $taskName cleaned up."

    if ($verifyOut -contains "INSTALLED") {
        $exeVer = Invoke-Remote (
            "powershell -NoProfile -Command `"" +
            "(Get-Item \`"$exePath\`").VersionInfo.FileVersion`""
        ) -NoLog | Select-Object -First 1
        Log-Ok "Scout installed for $profile — exe: $exePath (version: $($exeVer.Trim()))"
        $deployResults += [PSCustomObject]@{
            Profile = $profile; Phase = "Binary"; Status = "Installed"; Detail = $exeVer.Trim()
        }
    } else {
        Log-Error "Binary did not appear for $profile within 45s."
        Log-Warn "Installer may still be running. Re-run or check $target manually."
        $deployResults += [PSCustomObject]@{
            Profile = $profile; Phase = "Binary"; Status = "Pending/Unverified"; Detail = $exePath
        }
    }
}

# ── Step 8 — Phase 2: Provisioning ───────────────────────────────────────────

Log-Step "Step 8/8 — Phase 2: Provisioning"
Write-Host ""
Write-Host "  Binary deployment complete. Select provisioning components to deploy."
Write-Host "  Target:   $target"
Write-Host "  Profiles: $($selectedProfiles -join ', ')"
Write-Host ""
Write-Host "  Provisioning menu:"
Write-Host "   [1] Skills         — Copy Copilot skill directories to each user profile"
Write-Host "   [2] Connectors     — Deploy connector manifests (Power Platform / API)"
Write-Host "   [3] Tools (MCP)    — Register MCP server manifests via odr.exe or manifest drop"
Write-Host "   [4] Permissions    — Apply additional registry policy keys and file ACLs"
Write-Host "   [5] Memory         — Copy copilot-memory plugin data and Scout memory files"
Write-Host "   [6] Extensions     — Install VS Code extensions on the remote node"
Write-Host "   [7] Session History — Archive and restore Copilot session-state data"
Write-Host "   [8] Automations    — Deploy scheduled tasks, startup scripts, runbooks"
Write-Host "   [A] All above"
Write-Host "   [S] Skip (finish)"
Write-Host ""

$provSelection = (Read-Host "  Enter numbers (e.g. 1,3,5), A for all, or S to skip").Trim().ToUpper()

[int[]] $provChoices = @()
if ($provSelection -eq "A") {
    $provChoices = 1..8
} elseif ($provSelection -ne "S" -and $provSelection -ne "") {
    $provChoices = $provSelection -split "," |
        ForEach-Object { $_.Trim() } |
        Where-Object { $_ -match "^\d+$" } |
        ForEach-Object { [int]$_ } |
        Where-Object { $_ -ge 1 -and $_ -le 8 }
}

$provResults = @()

# ── Provision: Skills ─────────────────────────────────────────────────────────

if (1 -in $provChoices) {
    Log-Section "Provision: Skills"
    if (-not (Test-Path $LocalSkillsRoot)) {
        Log-Warn "Local skills root not found: $LocalSkillsRoot — skipping skills deployment."
        $provResults += [PSCustomObject]@{ Component="Skills"; Status="Skipped (source missing)"; Detail=$LocalSkillsRoot }
    } else {
        $skillDirs  = Get-ChildItem -Path $LocalSkillsRoot -Directory
        $skillCount = $skillDirs.Count
        Log-Info "Found $skillCount skill director(ies) in $LocalSkillsRoot"

        foreach ($prof in $selectedProfiles) {
            $remoteSkillsDir = "C:/Users/$prof/.copilot/skills"
            Invoke-Remote "if not exist `"C:\Users\$prof\.copilot\skills`" mkdir `"C:\Users\$prof\.copilot\skills`"" -NoLog | Out-Null
            Log-Info "Deploying $skillCount skills to $prof on $target..."
            $copyOut = Copy-DirToRemote $LocalSkillsRoot $remoteSkillsDir
            if ($LASTEXITCODE -eq 0) {
                Log-Ok "Skills deployed to $prof ($skillCount dirs)"
                $provResults += [PSCustomObject]@{ Component="Skills"; Status="Deployed"; Detail="$prof — $skillCount skills" }
            } else {
                Log-Error "Skills copy failed for $prof"
                $provResults += [PSCustomObject]@{ Component="Skills"; Status="Failed"; Detail="$prof — $($copyOut -join ' | ')" }
            }
        }
    }
}

# ── Provision: Connectors ─────────────────────────────────────────────────────

if (2 -in $provChoices) {
    Log-Section "Provision: Connectors"
    if (-not (Test-Path $LocalConnectorsRoot)) {
        Log-Warn "Local connectors root not found: $LocalConnectorsRoot"
        Log-Info "Create $LocalConnectorsRoot and place connector manifest JSON files there."
        $provResults += [PSCustomObject]@{ Component="Connectors"; Status="Skipped (source missing)"; Detail=$LocalConnectorsRoot }
    } else {
        $connFiles = Get-ChildItem -Path $LocalConnectorsRoot -Filter "*.json" -Recurse
        Log-Info "Found $($connFiles.Count) connector manifest(s) in $LocalConnectorsRoot"
        foreach ($prof in $selectedProfiles) {
            $remoteConnDir = "C:\Users\$prof\.copilot\connectors"
            Invoke-Remote "if not exist `"$remoteConnDir`" mkdir `"$remoteConnDir`"" -NoLog | Out-Null
            foreach ($cf in $connFiles) {
                $remotePath = "$remoteConnDir\$($cf.Name)"
                Copy-ToRemote $cf.FullName $remotePath | Out-Null
                Log-Ok "Connector '$($cf.Name)' -> $prof"
            }
            $provResults += [PSCustomObject]@{
                Component="Connectors"; Status="Deployed"; Detail="$prof — $($connFiles.Count) manifests"
            }
        }
    }
}

# ── Provision: Tools (MCP) ────────────────────────────────────────────────────

if (3 -in $provChoices) {
    Log-Section "Provision: Tools / MCP Servers"
    if (-not (Test-Path $LocalMcpManifestsRoot)) {
        Log-Warn "Local MCP manifests root not found: $LocalMcpManifestsRoot"
        Log-Info "Create $LocalMcpManifestsRoot and place MCP server manifest JSON files there."
        $provResults += [PSCustomObject]@{ Component="Tools/MCP"; Status="Skipped (source missing)"; Detail=$LocalMcpManifestsRoot }
    } else {
        $mcpFiles = Get-ChildItem -Path $LocalMcpManifestsRoot -Filter "*.json" -Recurse
        Log-Info "Found $($mcpFiles.Count) MCP manifest(s)."
        # Check for odr.exe on remote
        $odrCheck = Invoke-Remote 'where odr.exe 2>nul' -NoLog
        $hasOdr   = $odrCheck -notmatch "Could not find"
        Log-Info "odr.exe available on remote: $hasOdr"

        foreach ($prof in $selectedProfiles) {
            $remoteMcpDir = "C:\Users\$prof\.copilot\mcp-servers"
            Invoke-Remote "if not exist `"$remoteMcpDir`" mkdir `"$remoteMcpDir`"" -NoLog | Out-Null
            foreach ($mf in $mcpFiles) {
                $remotePath = "$remoteMcpDir\$($mf.Name)"
                Copy-ToRemote $mf.FullName $remotePath | Out-Null
                if ($hasOdr) {
                    $odrOut = Invoke-Remote "odr.exe register `"$remotePath`"" -NoLog
                    if ($odrOut -match "success|registered") {
                        Log-Ok "odr.exe registered: $($mf.Name) for $prof"
                    } else {
                        Log-Warn "odr.exe result for $($mf.Name): $($odrOut -join ' ')"
                    }
                } else {
                    Log-Info "Manifest dropped (no odr.exe): $($mf.Name) -> $remotePath"
                }
            }
            $provResults += [PSCustomObject]@{
                Component="Tools/MCP"; Status="Deployed"; Detail="$prof — $($mcpFiles.Count) manifests$(if($hasOdr){' + odr registered'})"
            }
        }
    }
}

# ── Provision: Permissions ────────────────────────────────────────────────────

if (4 -in $provChoices) {
    Log-Section "Provision: Permissions"

    # Policy keys for all Scout/Copilot features
    $policyKeys = @(
        @{ Name="AllowScoutFrontierAccess";      Type="REG_DWORD"; Value="1" },
        @{ Name="DisableUsageTelemetry";         Type="REG_DWORD"; Value="0" },
        @{ Name="AllowExtensions";               Type="REG_DWORD"; Value="1" }
    )

    foreach ($key in $policyKeys) {
        $regOut = Invoke-Remote (
            "reg add `"HKLM\SOFTWARE\Policies\Scout`" /v $($key.Name) /t $($key.Type) /d $($key.Value) /f"
        ) -NoLog
        if ($regOut -match "successfully") {
            Log-Ok "Policy key: $($key.Name) = $($key.Value)"
        } else {
            Log-Warn "Policy key $($key.Name) result: $($regOut -join ' ')"
        }
    }

    # Per-profile .copilot directory ACLs
    foreach ($prof in $selectedProfiles) {
        $copilotDir = "C:\Users\$prof\.copilot"
        $aclOut = Invoke-Remote (
            "if exist `"$copilotDir`" (icacls `"$copilotDir`" /grant `"$remoteHostname\$prof`":(OI)(CI)(F)" +
            " /grant `"AzureAD\$prof`":(OI)(CI)(F) /T /C /Q)"
        ) -NoLog
        Log-Info "ACL for $copilotDir — $($aclOut | Select-Object -Last 1)"
    }

    $provResults += [PSCustomObject]@{ Component="Permissions"; Status="Applied"; Detail="$($policyKeys.Count) policy keys + profile ACLs" }
}

# ── Provision: Memory ─────────────────────────────────────────────────────────

if (5 -in $provChoices) {
    Log-Section "Provision: Memory"
    if (-not (Test-Path $LocalMemoryRoot)) {
        Log-Warn "Local memory root not found: $LocalMemoryRoot — skipping."
        $provResults += [PSCustomObject]@{ Component="Memory"; Status="Skipped (source missing)"; Detail=$LocalMemoryRoot }
    } else {
        $memFiles = Get-ChildItem -Path $LocalMemoryRoot -Recurse -File
        Log-Info "Found $($memFiles.Count) memory file(s) in $LocalMemoryRoot"
        foreach ($prof in $selectedProfiles) {
            $remoteMemDir = "C:\Users\$prof\.copilot\memory"
            Invoke-Remote "if not exist `"$remoteMemDir`" mkdir `"$remoteMemDir`"" -NoLog | Out-Null
            Copy-DirToRemote $LocalMemoryRoot "C:/Users/$prof/.copilot/memory" | Out-Null
            Log-Ok "Memory data deployed to $prof ($($memFiles.Count) files)"
            $provResults += [PSCustomObject]@{ Component="Memory"; Status="Deployed"; Detail="$prof — $($memFiles.Count) files" }
        }
    }
}

# ── Provision: Extensions ─────────────────────────────────────────────────────

if (6 -in $provChoices) {
    Log-Section "Provision: VS Code Extensions"
    if (-not (Test-Path $LocalExtensionsList)) {
        Log-Warn "Extensions list not found: $LocalExtensionsList"
        Log-Info "Create $LocalExtensionsList with one VS Code extension ID per line."
        $provResults += [PSCustomObject]@{ Component="Extensions"; Status="Skipped (list missing)"; Detail=$LocalExtensionsList }
    } else {
        $extIds = Get-Content $LocalExtensionsList |
            Where-Object { $_.Trim() -ne "" -and -not $_.StartsWith("#") }
        Log-Info "Extension list: $($extIds.Count) extension(s) to install"

        # Check if code.exe is present on remote
        $codeCheck = Invoke-Remote 'where code 2>nul' -NoLog
        if ($codeCheck -match "code") {
            foreach ($ext in $extIds) {
                $extOut = Invoke-Remote "code --install-extension `"$ext`" --force" -NoLog
                if ($extOut -match "already installed|successfully installed") {
                    Log-Ok "Extension: $ext"
                } else {
                    Log-Warn "Extension '$ext' result: $($extOut -join ' ')"
                }
            }
            $provResults += [PSCustomObject]@{
                Component="Extensions"; Status="Deployed"; Detail="$($extIds.Count) extensions via code CLI"
            }
        } else {
            Log-Warn "VS Code (code.exe) not found on $target — dropping extensions.txt for manual install."
            $remoteExtPath = "C:\Windows\Temp\extensions.txt"
            Copy-ToRemote $LocalExtensionsList $remoteExtPath | Out-Null
            $provResults += [PSCustomObject]@{
                Component="Extensions"; Status="Staged (no code.exe)"; Detail="$remoteExtPath — manual: code --install-extension @extensions.txt"
            }
        }
    }
}

# ── Provision: Session History ────────────────────────────────────────────────

if (7 -in $provChoices) {
    Log-Section "Provision: Session History"
    if (-not (Test-Path $LocalSessionRoot)) {
        Log-Warn "Local session-state root not found: $LocalSessionRoot — skipping."
        $provResults += [PSCustomObject]@{ Component="Session History"; Status="Skipped (source missing)"; Detail=$LocalSessionRoot }
    } else {
        # Create a zip of session-state for transport
        $zipName = "session-state-${RunTimestamp}.zip"
        $zipPath = Join-Path $env:TEMP $zipName

        Log-Info "Archiving session history from $LocalSessionRoot -> $zipPath"
        Compress-Archive -Path "$LocalSessionRoot\*" -DestinationPath $zipPath -Force
        $zipSize = (Get-Item $zipPath).Length
        Log-Info "Archive size: $zipSize bytes"

        $remoteZip     = "C:\Windows\Temp\$zipName"
        Copy-ToRemote $zipPath $remoteZip | Out-Null

        foreach ($prof in $selectedProfiles) {
            $remoteSessDir = "C:\Users\$prof\.copilot\session-state"
            Invoke-Remote "if not exist `"$remoteSessDir`" mkdir `"$remoteSessDir`"" -NoLog | Out-Null
            # Expand-Archive via PowerShell on remote
            $expandOut = Invoke-Remote (
                "powershell -NoProfile -Command `"Expand-Archive -Path '$remoteZip' -DestinationPath '$remoteSessDir' -Force`""
            ) -NoLog
            Log-Ok "Session history restored for $prof at $remoteSessDir"
            $provResults += [PSCustomObject]@{ Component="Session History"; Status="Deployed"; Detail="$prof — $zipSize bytes" }
        }

        # Clean up temp archive
        Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
        Invoke-Remote "del /F /Q `"$remoteZip`"" -NoLog | Out-Null
    }
}

# ── Provision: Automations ────────────────────────────────────────────────────

if (8 -in $provChoices) {
    Log-Section "Provision: Automations"
    if (-not (Test-Path $LocalAutomationsRoot)) {
        Log-Warn "Local automations root not found: $LocalAutomationsRoot"
        Log-Info "Create $LocalAutomationsRoot and place .ps1, .xml (task definitions), or .cmd files there."
        $provResults += [PSCustomObject]@{ Component="Automations"; Status="Skipped (source missing)"; Detail=$LocalAutomationsRoot }
    } else {
        $autoFiles = Get-ChildItem -Path $LocalAutomationsRoot -Recurse -File
        Log-Info "Found $($autoFiles.Count) automation file(s)."
        $remoteAutoDir = "C:\ProgramData\ScoutDeployer\automations"
        Invoke-Remote "if not exist `"$remoteAutoDir`" mkdir `"$remoteAutoDir`"" -NoLog | Out-Null

        foreach ($af in $autoFiles) {
            $remotePath = "$remoteAutoDir\$($af.Name)"
            Copy-ToRemote $af.FullName $remotePath | Out-Null
            Log-Info "Staged automation: $($af.Name)"

            # Auto-register scheduled task XMLs
            if ($af.Extension -eq ".xml") {
                $taskName  = [IO.Path]::GetFileNameWithoutExtension($af.Name)
                $registerOut = Invoke-Remote "schtasks /Create /XML `"$remotePath`" /TN `"ScoutAuto_$taskName`" /F" -NoLog
                if ($registerOut -match "SUCCESS") {
                    Log-Ok "Scheduled task registered from XML: $taskName"
                } else {
                    Log-Warn "Task XML registration result: $($registerOut -join ' ')"
                }
            }

            # Auto-execute .ps1 startup scripts if named startup-*.ps1
            if ($af.Name -match "^startup-.*\.ps1$") {
                $runOut = Invoke-Remote (
                    "powershell -NoProfile -ExecutionPolicy Bypass -File `"$remotePath`""
                ) -NoLog
                Log-Info "Startup script result: $($runOut -join ' | ')"
            }
        }
        $provResults += [PSCustomObject]@{
            Component="Automations"; Status="Deployed"; Detail="$($autoFiles.Count) files — XMLs registered, startup scripts executed"
        }
    }
}

# ── Final Summary ─────────────────────────────────────────────────────────────

$allResults = $deployResults + $provResults

Log-Section "ScoutDeployer — Final Summary — $target — $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"

Write-Host ""
Write-Host "  Target  : $target ($remoteHostname)"
Write-Host "  Profiles: $($selectedProfiles -join ', ')"
Write-Host "  Log     : $LogFile"
Write-Host ""
Write-Host "  Deployment results:"
$allResults | Format-Table -AutoSize | Tee-Object -Append -FilePath $LogFile

# Policy key confirmation
Write-Host ""
Log-Info "Current Scout policy keys on ${target}:"
$finalPolicy = Invoke-Remote 'reg query "HKLM\SOFTWARE\Policies\Scout"' -NoLog
$finalPolicy | Where-Object { $_.Trim() } | ForEach-Object { Log-Info "  $_" }

Write-Host ""
Write-Host "NOTE: Each deployed user must interactively launch Microsoft Scout on $target"
Write-Host "      and sign in as darbot@timelarp.com to clear the Frontier gate."
Write-Host "      App registration: cb08267c-55a2-4f0d-9c5a-58d90444b82d"
Write-Host "      Tenant: cypherdyne.ai (6b104499-c49f-45dc-b3a2-df95efd6eeb4)"
Write-Host ""
Log-Ok "ScoutDeployer run complete. Full log: $LogFile"
