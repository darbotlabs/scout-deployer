#!/usr/bin/env node
/**
 * skills-server.js — MCP stdio server exposing Copilot m-skills as MCP tools.
 *
 * Protocol: JSON-RPC 2.0 over stdio (MCP 2024-11-05 spec subset).
 * No external dependencies — runs with Node.js built-ins only.
 *
 * Tools exposed (one per skill):
 *   inverse_debate_theory  — adversarial 4-agent debate panel
 *   intentional_words      — multi-agent wording calculator
 *   cowork_auth_config     — Cowork CLI auth + config
 *   cowork_chat            — Cowork interactive REPL
 *   cowork_cli_install     — Install cowork-cli on Windows
 *   query_3dkg             — 3DKG knowledge graph queries
 *   persistent_powershell  — long-lived PowerShell session management
 *
 * Each tool:
 *   - Reads its SKILL.md from ../skills/<name>/SKILL.md
 *   - Accepts a "prompt" string and optional per-tool params
 *   - Invokes `copilot` CLI (GitHub Copilot CLI) with the skill if available,
 *     otherwise returns the skill content + prompt as a structured prompt block
 *     ready for the caller to forward to an LLM.
 *
 * Usage:
 *   node bin/skills-server.js
 *   npx scout-deployer --mode skills-server
 *
 * Registration (Windows odr.exe):
 *   odr.exe register mcp-manifests/scout-skills.json
 */

'use strict';

const path      = require('path');
const fs        = require('fs');
const readline  = require('readline');
const { execFileSync } = require('child_process');

const SKILLS_DIR = path.resolve(__dirname, '..', 'skills');
const SERVER_NAME    = 'scout-skills';
const SERVER_VERSION = '1.0.0';
const PROTOCOL_VERSION = '2024-11-05';

// ── Tool definitions ──────────────────────────────────────────────────────────

const TOOLS = [
  {
    name:        'inverse_debate_theory',
    skillDir:    'inverse-debate-theory',
    description: 'Run a problem through inverse-debate-theory: four independent parallel ' +
                 'agent sessions (GPT-5.5 agree, GPT-5.5 disagree, Opus 4.8 agree, ' +
                 'Opus 4.8 disagree), four collaborative rounds, and Near/Far/Long synthesis.',
    inputSchema: {
      type: 'object',
      properties: {
        problem: {
          type: 'string',
          description: 'The problem, decision, claim, strategy, design, or assumption to debate.'
        },
        rounds: {
          type: 'integer',
          description: 'Number of collaborative rounds (default: 4).',
          default: 4,
          minimum: 1,
          maximum: 8
        }
      },
      required: ['problem']
    }
  },
  {
    name:        'intentional_words',
    skillDir:    'intentional-words',
    description: 'Calculate and refine wording by launching multiple independent runtime ' +
                 'agents in parallel, each challenging the words from a unique perspective, ' +
                 'then collaborating through subloops and Near/Far/Long horizon synthesis.',
    inputSchema: {
      type: 'object',
      properties: {
        text: {
          type: 'string',
          description: 'The wording, message, or text to refine and stress-test.'
        },
        context: {
          type: 'string',
          description: 'Optional background context about the audience, relationship, or stakes.'
        },
        goal: {
          type: 'string',
          description: 'What the text needs to accomplish (inform, persuade, reassure, escalate, etc.).'
        }
      },
      required: ['text']
    }
  },
  {
    name:        'cowork_auth_config',
    skillDir:    'cowork-auth-config',
    description: 'Manage Cowork CLI authentication and configuration: cowork auth login/check/' +
                 'status/whoami/refresh/logout and cowork config init/show/set.',
    inputSchema: {
      type: 'object',
      properties: {
        command: {
          type: 'string',
          description: 'The cowork auth or config sub-command to run.',
          enum: [
            'auth login', 'auth check', 'auth status', 'auth whoami',
            'auth refresh', 'auth logout',
            'config init', 'config show', 'config set'
          ]
        },
        key: {
          type: 'string',
          description: 'Config key (required for config set).'
        },
        value: {
          type: 'string',
          description: 'Config value (required for config set).'
        }
      },
      required: ['command']
    }
  },
  {
    name:        'cowork_chat',
    skillDir:    'cowork-chat',
    description: 'Launch and manage the interactive cowork chat REPL in a persistent ' +
                 'PowerShell session for streaming multi-turn chat.',
    inputSchema: {
      type: 'object',
      properties: {
        message: {
          type: 'string',
          description: 'Initial message or prompt to send to the cowork chat REPL.'
        },
        island: {
          type: 'string',
          description: 'Cowork island/environment name (--island flag).'
        },
        model: {
          type: 'string',
          description: 'Model override (--model flag).'
        },
        resume: {
          type: 'boolean',
          description: 'Resume the latest conversation (--resume-latest).',
          default: false
        }
      },
      required: ['message']
    }
  },
  {
    name:        'cowork_cli_install',
    skillDir:    'cowork-cli-install',
    description: 'Install cowork-cli natively on Windows via the aka.ms PowerShell installer ' +
                 'and wire it into a reusable persistent PowerShell session.',
    inputSchema: {
      type: 'object',
      properties: {
        force: {
          type: 'boolean',
          description: 'Force reinstall even if cowork is already on PATH.',
          default: false
        },
        verify_only: {
          type: 'boolean',
          description: 'Only check if cowork-cli is installed and return its version.',
          default: false
        }
      },
      required: []
    }
  },
  {
    name:        'query_3dkg',
    skillDir:    '3dkg',
    description: 'Query and work with the 3DKG knowledge graph, txt2kg APIs, DarbotDB ' +
                 '(ArangoDB), and QMD MCP memory surface on 10.1.8.69.',
    inputSchema: {
      type: 'object',
      properties: {
        query: {
          type: 'string',
          description: 'Natural language query or AQL/SPARQL query against the knowledge graph.'
        },
        endpoint: {
          type: 'string',
          description: 'Target endpoint.',
          enum: ['txt2kg', 'darbotdb', 'qmd-mcp', 'triples-api'],
          default: 'txt2kg'
        },
        raw: {
          type: 'boolean',
          description: 'Return raw API response rather than summarised result.',
          default: false
        }
      },
      required: ['query']
    }
  },
  {
    name:        'persistent_powershell',
    skillDir:    'persistent-powershell',
    description: 'Create and manage long-lived PowerShell work sessions for parallel ' +
                 'command execution, coding agents, service probes, and reusable terminal ' +
                 'workflows.',
    inputSchema: {
      type: 'object',
      properties: {
        action: {
          type: 'string',
          description: 'Session action to perform.',
          enum: ['create', 'run', 'read', 'stop', 'list'],
          default: 'create'
        },
        shell_id: {
          type: 'string',
          description: 'Identifier for the persistent shell session.'
        },
        command: {
          type: 'string',
          description: 'PowerShell command to execute in the session (for run action).'
        },
        detach: {
          type: 'boolean',
          description: 'Run detached so the process survives session shutdown.',
          default: false
        }
      },
      required: ['action']
    }
  }
];

// ── Skill content cache ───────────────────────────────────────────────────────

const skillCache = {};

function loadSkill(skillDir) {
  if (skillCache[skillDir]) return skillCache[skillDir];
  const p = path.join(SKILLS_DIR, skillDir, 'SKILL.md');
  if (!fs.existsSync(p)) return null;
  skillCache[skillDir] = fs.readFileSync(p, 'utf8');
  return skillCache[skillDir];
}

// ── Tool execution ────────────────────────────────────────────────────────────

function executeTool(toolDef, args) {
  const skillContent = loadSkill(toolDef.skillDir);
  if (!skillContent) {
    return {
      isError: true,
      content: [{
        type: 'text',
        text: `ERROR: SKILL.md not found for '${toolDef.skillDir}' in ${SKILLS_DIR}`
      }]
    };
  }

  // Build a structured prompt block combining skill instructions + caller args.
  // If the Copilot CLI is available, we could pipe this to it.
  // For now, return the composed prompt so the MCP host can forward to its LLM.
  const argsBlock = Object.entries(args)
    .map(([k, v]) => `${k}: ${JSON.stringify(v)}`)
    .join('\n');

  const composed = [
    `## Skill: ${toolDef.name}`,
    '',
    '### Skill Instructions',
    skillContent,
    '',
    '### Invocation Parameters',
    argsBlock,
    '',
    '### Task',
    'Execute the skill as instructed above using the invocation parameters provided.',
  ].join('\n');

  // Attempt to detect and run via Copilot CLI if present
  let copilotResult = null;
  try {
    const result = execFileSync('copilot', ['skill', 'run', toolDef.skillDir, '--json'],
      { input: JSON.stringify(args), encoding: 'utf8', timeout: 10000 });
    copilotResult = result;
  } catch (_) {
    // Copilot CLI not available or skill runner not supported — return composed prompt
  }

  if (copilotResult) {
    return {
      content: [{
        type: 'text',
        text: copilotResult
      }]
    };
  }

  return {
    content: [{
      type: 'text',
      text: composed
    }]
  };
}

// ── JSON-RPC / MCP protocol handler ──────────────────────────────────────────

function makeResponse(id, result) {
  return JSON.stringify({ jsonrpc: '2.0', id, result });
}

function makeError(id, code, message, data) {
  return JSON.stringify({
    jsonrpc: '2.0', id,
    error: { code, message, ...(data ? { data } : {}) }
  });
}

function handleRequest(raw) {
  let req;
  try {
    req = JSON.parse(raw);
  } catch (e) {
    return makeError(null, -32700, 'Parse error');
  }

  const { id, method, params } = req;

  switch (method) {

    case 'initialize':
      return makeResponse(id, {
        protocolVersion: PROTOCOL_VERSION,
        serverInfo: { name: SERVER_NAME, version: SERVER_VERSION },
        capabilities: { tools: {} }
      });

    case 'notifications/initialized':
      return null; // no response for notifications

    case 'tools/list':
      return makeResponse(id, {
        tools: TOOLS.map(t => ({
          name:        t.name,
          description: t.description,
          inputSchema: t.inputSchema
        }))
      });

    case 'tools/call': {
      const toolName = params && params.name;
      const toolArgs = (params && params.arguments) || {};
      const toolDef  = TOOLS.find(t => t.name === toolName);
      if (!toolDef) {
        return makeError(id, -32602, `Unknown tool: ${toolName}`);
      }
      const execResult = executeTool(toolDef, toolArgs);
      return makeResponse(id, execResult);
    }

    case 'ping':
      return makeResponse(id, {});

    default:
      return makeError(id, -32601, `Method not found: ${method}`);
  }
}

// ── Stdio transport ───────────────────────────────────────────────────────────

const rl = readline.createInterface({ input: process.stdin, crlfDelay: Infinity });

rl.on('line', (line) => {
  const trimmed = line.trim();
  if (!trimmed) return;
  const response = handleRequest(trimmed);
  if (response) {
    process.stdout.write(response + '\n');
  }
});

rl.on('close', () => {
  process.exit(0);
});

process.on('SIGINT',  () => process.exit(0));
process.on('SIGTERM', () => process.exit(0));
