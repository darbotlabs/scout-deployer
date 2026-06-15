---
name: "inverse-debate-theory"
description: "Run a problem through inverse-debate-theory by launching four complete independent parallel agent sessions: GPT-5.5 agree, GPT-5.5 disagree, Opus 4.8 agree, and Opus 4.8 disagree, with four collaborative rounds and Near/Far/Long synthesis."
---

# Inverse Debate Theory Skill

This is an operational multi-agent orchestration skill. It MUST launch complete independent agent sessions for the debate panel. It is not acceptable to simulate the four roles in one internal answer unless the user explicitly asks for a no-tools dry run.

Use this skill to stress-test a problem, decision, claim, strategy, design, message, or assumption through structured adversarial and supportive reasoning.

## Non-negotiable execution contract

1. **Load this skill first** using the platform skill-loading mechanism.
2. **Launch four independent subagents** using the `task` tool in `background` mode. Each role gets a complete session, full context, and a role-specific prompt.
3. **Run all four initial agents in parallel** whenever tool orchestration allows parallel calls.
4. **Use the requested model IDs exactly when available:**
   - GPT agree: `gpt-5.5`
   - GPT disagree: `gpt-5.5`
   - Opus agree: `claude-opus-4.8`
   - Opus disagree: `claude-opus-4.8`
5. **If a required model is unavailable, do not silently substitute and do not simulate.** Tell the user the exact model that is unavailable and ask whether to use the strongest available substitute.
6. **Keep the agents independent in Round 1.** Do not share one agent's output with another until the explicit cross-examination round.
7. **Use the same agent sessions across rounds** with `write_agent`; do not restart each round unless an agent fails.
8. **Read every agent result** before synthesis. Do not claim a panel conclusion unless the panel actually returned outputs.
9. **If any agent fails**, report the failure and either retry that role once or ask whether to continue without it. Do not silently fill in the missing role.
10. **Expose outputs as role summaries, not hidden chain-of-thought.** Ask agents for concise structured findings, evidence, assumptions, risks, and recommendations.

## Four-agent panel

1. **GPT-5.5 Agree Agent**
   - Tool model: `gpt-5.5`
   - Role: build the strongest affirmative case for the proposal, claim, or direction.
   - Bias: charitable, constructive, rigorous agreement.

2. **GPT-5.5 Disagree Agent**
   - Tool model: `gpt-5.5`
   - Role: build the strongest opposing case.
   - Bias: adversarial, skeptical, failure-seeking disagreement.

3. **Opus 4.8 Agree Agent**
   - Tool model: `claude-opus-4.8`
   - Role: build an independently reasoned affirmative case from a different model family.
   - Bias: subtle strengths, long-horizon upside, narrative coherence, strategic leverage.

4. **Opus 4.8 Disagree Agent**
   - Tool model: `claude-opus-4.8`
   - Role: build an independently reasoned opposing case from a different model family.
   - Bias: hidden fragility, adversarial interpretation, ethical risks, stakeholder harms, long-horizon failure modes.

## Required four-round protocol

### Round 1: Independent frame and steelman
Launch all four agents in parallel. Each agent receives the full problem context and only its own role. Each returns:
- Clearest problem framing.
- Strongest role-specific argument.
- Assumptions.
- Key evidence needed.
- Stakeholder/receiver meaning.
- Near/Far/Long horizon forecast.
- Confidence.

Synthesis checkpoint after all outputs:
- Shared facts.
- Disputed assumptions.
- Strongest agree arguments.
- Strongest disagree arguments.
- Clarified decision or claim under debate.

### Round 2: Inversion and failure search
Send the checkpoint digest to each existing agent with `write_agent`. Ask each role:
- If the opposite were true, what evidence would support it?
- What would make this fail?
- What did the other side identify that your role must answer?
- What stakeholder interpretation risk matters most?
- What evidence would change your recommendation?

Synthesis checkpoint:
- Rank strongest objections.
- Separate fatal risks from manageable risks.
- Identify uncertainty that actually matters.

### Round 3: Cross-examination and refinement
Send the Round 2 checkpoint to each existing agent. Ask each role:
- What did your side overstate?
- What did the other side miss?
- Which assumptions survived scrutiny?
- What revised option or wording would be harder to reject?
- What guardrails are required?

Synthesis checkpoint:
- Revised thesis/decision option.
- Remaining dissent.
- Practical guardrails.

### Round 4: Convergence, decision, and horizons
Send the Round 3 checkpoint to each existing agent. Ask each role for:
- Final recommendation.
- Confidence and caveats.
- Best next action.
- Near/Far/Long horizon forecast.
- One sentence that would change its mind.

Final synthesis:
- Compare recommendations.
- Highlight consensus, dissent, and uncertainty.
- Make a final recommendation or present decision options.
- Include receiver/stakeholder impact and Near/Far/Long horizons.

## Required task launch prompt template

Use this shape for each initial subagent:

```text
You are the [ROLE NAME] for /inverse-debate-theory. You are running as a complete independent agent session using model [MODEL]. Do not assume or simulate other agents' views. Do not wait for collaboration in Round 1.

Problem / proposal / claim:
[USER INPUT]

Context and constraints:
[KNOWN CONTEXT]

Round 1 mission:
[ROLE-SPECIFIC MISSION]

Return concise structured output with: problem framing, strongest argument, assumptions, evidence needed, stakeholder/receiver meaning, Near/Far/Long forecast, confidence, and questions. Do not provide hidden chain-of-thought.
```

## Output format after full run

1. **Panel execution status**
   - List each agent, model, and whether it completed.

2. **Problem framing**
   - Clearest statement of the decision or claim.

3. **Round summaries**
   - Round 1: frame and steelman.
   - Round 2: inversion and failure search.
   - Round 3: cross-examination and refinement.
   - Round 4: convergence and decision.

4. **Consensus and dissent**
   - What all roles agree on.
   - What remains contested.

5. **Receiver and stakeholder impact**
   - How the conclusion, decision, or wording may land.

6. **Near/Far/Long horizon forecast**
   - Near Horizon.
   - Far Horizon.
   - Long Horizon.

7. **Final synthesis**
   - Recommendation, confidence, caveats, and next action.

8. **If wording is involved**
   - Provide polished wording and why it is stronger.

## Quality bar

- Real independent sessions are mandatory.
- Disagreement must be strong, not token opposition.
- Agreement must be rigorous, not cheerleading.
- Distinguish facts, assumptions, predictions, values, and preferences.
- Do not manufacture consensus when dissent remains meaningful.
- Do not claim real model execution unless actual model-specific agents were dispatched and completed.
- Prefer actionable synthesis over exhaustive transcript.

## Safety and boundaries

Do not help craft deceptive, manipulative, discriminatory, coercive, retaliatory, or harassing arguments. If a requested debate involves harm, abuse, or evasion of accountability, redirect to a safer framing. For legal, HR, medical, financial, safety, or compliance-sensitive decisions, recommend appropriate expert review while still clarifying assumptions, risks, and communication.
