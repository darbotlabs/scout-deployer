#!/usr/bin/env node
/**
 * scout-deployer — npx entry point
 *
 * Usage:
 *   npx scout-deployer
 *   npx scout-deployer --installer "C:\path\to\MicrosoftScout-Windows-0.22.333-x64-Setup.exe"
 *   npx scout-deployer --target 10.1.8.70 --password secret
 *   npx scout-deployer --provision all
 *
 * All flags are forwarded to ScoutDeployer.ps1 as named parameters.
 * Requires Windows + PowerShell 5.1+.
 */

'use strict';

const { spawnSync } = require('child_process');
const path = require('path');
const fs   = require('fs');
const os   = require('os');

// ── Platform guard ────────────────────────────────────────────────────────────

if (os.platform() !== 'win32') {
  console.error('[ERROR] scout-deployer only runs on Windows (PowerShell + PuTTY required).');
  process.exit(1);
}

// ── Resolve ScoutDeployer.ps1 ─────────────────────────────────────────────────

// When installed as a package the .ps1 is one directory up from bin/
const scriptPath = path.resolve(__dirname, '..', 'ScoutDeployer.ps1');

if (!fs.existsSync(scriptPath)) {
  console.error(`[ERROR] ScoutDeployer.ps1 not found at: ${scriptPath}`);
  process.exit(1);
}

// ── Argument mapping ──────────────────────────────────────────────────────────
// Convert CLI flags to PowerShell named parameters.
// --installer "path"  -> -InstallerPath "path"
// --target host       -> -DarbotPassword is prompted (or --password value)
// --putty-dir path    -> -PuTTYDir "path"
// --log-dir path      -> -LogDir "path"
// --skills path       -> -LocalSkillsRoot "path"
// --memory path       -> -LocalMemoryRoot "path"
// --sessions path     -> -LocalSessionRoot "path"
// --connectors path   -> -LocalConnectorsRoot "path"
// --mcp path          -> -LocalMcpManifestsRoot "path"
// --automations path  -> -LocalAutomationsRoot "path"
// --extensions path   -> -LocalExtensionsList "path"
// Any unrecognised flag is passed through verbatim.

const flagMap = {
  '--installer':    '-InstallerPath',
  '--password':     '-DarbotPassword',
  '--putty-dir':    '-PuTTYDir',
  '--log-dir':      '-LogDir',
  '--skills':       '-LocalSkillsRoot',
  '--memory':       '-LocalMemoryRoot',
  '--sessions':     '-LocalSessionRoot',
  '--connectors':   '-LocalConnectorsRoot',
  '--mcp':          '-LocalMcpManifestsRoot',
  '--automations':  '-LocalAutomationsRoot',
  '--extensions':   '-LocalExtensionsList',
};

const psArgs = ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', scriptPath];
const argv   = process.argv.slice(2);

let i = 0;
while (i < argv.length) {
  const flag = argv[i];
  const psFlag = flagMap[flag.toLowerCase()];
  if (psFlag) {
    const val = argv[i + 1];
    if (!val || val.startsWith('--')) {
      console.error(`[ERROR] Flag ${flag} requires a value.`);
      process.exit(1);
    }
    psArgs.push(psFlag, val);
    i += 2;
  } else {
    // Pass through verbatim (e.g. -Verbose)
    psArgs.push(flag);
    i += 1;
  }
}

// ── Launch ────────────────────────────────────────────────────────────────────

console.log('[scout-deployer] Launching ScoutDeployer.ps1 ...');
console.log(`[scout-deployer] Script : ${scriptPath}`);
console.log(`[scout-deployer] PS args: ${psArgs.slice(4).join(' ')}\n`);

const result = spawnSync('powershell.exe', psArgs, {
  stdio: 'inherit',
  windowsHide: false,
  cwd: path.dirname(scriptPath),
});

if (result.error) {
  console.error(`[ERROR] Failed to launch powershell.exe: ${result.error.message}`);
  process.exit(1);
}

process.exit(result.status ?? 0);
