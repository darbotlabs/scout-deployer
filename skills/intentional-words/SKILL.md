---
name: "intentional-words"
description: "Calculate and refine wording by launching multiple complete independent runtime agents in parallel, each challenging the words from a unique perspective, then collaborating through subloops and Near/Far/Long horizon synthesis."
---

# Intentional Words Skill

This is an operational multi-agent orchestration skill. It is not a notes page, a single prompt, or a simulated checklist. When invoked, it MUST create complete independent runtime agent sessions in parallel and use those agents to calculate, challenge, and improve the user's words.

Use this skill to draft, review, rewrite, or decide whether to send wording that could affect people, relationships, trust, clarity, accountability, morale, risk, public perception, or long-term outcomes.

## Non-negotiable execution contract

1. **Load this skill before execution** using `m_get_skill("intentional-words")`.
2. **Launch independent runtime agents** using the `task` tool in `background` mode. Each role MUST receive its own complete session, full context, and role-specific prompt.
3. **Run the first subloop in parallel.** Do not analyze all roles inside the main assistant response as a substitute for agents.
4. **No fake panel.** If the runtime cannot create independent agents, stop and tell the user the skill is blocked. Do not simulate unless the user explicitly asks for a dry run.
5. **Use same sessions across rounds.** After the first pass, use `write_agent` to send collaboration, cross-challenge, and final-recommendation prompts back into the same agent sessions.
6. **Read every required agent output** with `read_agent` before synthesis. Do not claim panel consensus or completion unless the agents returned.
7. **Disclose failures.** If an agent fails, retry that role once. If it still fails, tell the user and ask whether to continue without that perspective.
8. **Keep outbound safety.** This skill produces proposed wording only. Do not send, reply, post, or update external content unless the user separately confirms through the normal outbound-communication policy.

## Required independent agent panel

Launch these six agents by default. Use `general-purpose` agents unless a more appropriate specialized agent is explicitly available. Preferred models are `gpt-5.5` and `claude-opus-4.8`; if either is unavailable, disclose the unavailable model and ask before substituting.

1. **Literal Clarity Agent**
   - Preferred model: `gpt-5.5`
   - Mission: find ambiguity, vague asks, unclear ownership, missing next steps, undefined terms, and sentence-level confusion.

2. **Recipient Meaning Agent**
   - Preferred model: `claude-opus-4.8`
   - Mission: analyze what the words could mean to the person receiving them emotionally, socially, professionally, and relationally.

3. **Adversarial Interpretation Agent**
   - Preferred model: `gpt-5.5`
   - Mission: examine how a skeptical, hurt, hostile, exhausted, legalistic, or out-of-context reader could interpret, quote, or weaponize the wording.

4. **Power, Trust, and Dignity Agent**
   - Preferred model: `claude-opus-4.8`
   - Mission: evaluate power dynamics, psychological safety, perceived respect, agency, dignity, blame, defensiveness, and trust impact.

5. **Equity, Inclusion, and Access Agent**
   - Preferred model: `gpt-5.5`
   - Mission: identify assumptions about identity, seniority, culture, geography, accessibility, language fluency, work style, authority, or access to context.

6. **Prediction Horizons Agent**
   - Preferred model: `claude-opus-4.8`
   - Mission: forecast consequences across Near, Far, and Long Horizons and determine whether the wording advances the intended outcome.

Optional agents for higher-stakes wording:
- Legal/Compliance Risk Agent.
- HR/People Risk Agent.
- Executive Reader Agent.
- Customer Reader Agent.
- Public/Media Interpretation Agent.
- Affected-Person Advocate Agent.

## Required parallel subloop protocol

### Subloop 1: Independent perspective pass
Launch all six required agents in parallel. Each agent receives:
- Exact draft wording.
- Intended recipient or audience.
- Desired outcome.
- Channel and context.
- Known relationship and power dynamics.
- Constraints: tone, urgency, confidentiality, compliance, what must remain true, and what must not be softened away.

Each agent returns concise structured output:
- Strongest concern.
- Strongest strength.
- What the words could mean to the receiver.
- Specific rewrite advice.
- Near/Far/Long Horizon notes from that role.
- Confidence.

### Subloop 2: Cross-challenge and collaboration
After every Subloop 1 output is read, create a neutral digest. Send it to the same six agent sessions with `write_agent` and ask:
- Which other perspective raised the most important concern?
- Which concern is overstated?
- What wording change would survive the strongest criticism?
- What must not be softened, hidden, or diluted?
- What receiver interpretation remains most important?

### Subloop 3: Final role recommendations
Send a final prompt to the same six sessions asking each for:
- Recommended wording.
- Why it is stronger.
- Remaining risk.
- Confidence.
- One thing that would change its recommendation.

### Optional Subloop 4: High-stakes red team
For HR, legal, executive, customer, public, termination, performance, incident, crisis, or conflict-sensitive wording, launch additional specialist agents or rerun the panel with narrower roles before final synthesis.

## Required final synthesis

Only synthesize after all required agent outputs have been read.

Return:

1. **Panel execution status**
   - List each independent agent, model, and completion status.

2. **Intent read**
   - One sentence describing what the message appears to be trying to accomplish.

3. **Receiver meaning**
   - What the words may mean to the person or people receiving them.

4. **Parallel findings**
   - Highest-signal strengths and risks from the agents.

5. **Prediction horizons**
   - **Near Horizon:** immediate reaction, confusion, defensiveness, relief, escalation, or likely next action.
   - **Far Horizon:** downstream trust, motivation, collaboration, accountability, precedent, and relationship effects.
   - **Long Horizon:** durable narrative, culture, reputation, ethics, auditability, and how the words may be remembered or quoted.

6. **Recommended wording**
   - A polished version that is clearer, more intentional, more receiver-aware, and still honest.

7. **Why this wording**
   - Short explanation of the meaningful changes.

8. **Residual risks and assumptions**
   - What remains context-dependent or sensitive.

## Required task prompt template

Use this shape when launching each agent:

```text
You are the [ROLE NAME] for /intentional-words. You are running as a complete independent runtime agent session using model [MODEL]. Do not assume other agents' conclusions. Do not simulate other roles. Evaluate only from your assigned perspective.

Draft wording:
[EXACT WORDING]

Recipient/audience:
[RECIPIENT OR UNKNOWN]

Desired outcome:
[OUTCOME OR UNKNOWN]

Channel/context/constraints:
[CONTEXT OR UNKNOWN]

Relationship and power dynamics:
[KNOWN DYNAMICS OR UNKNOWN]

Mission:
[ROLE-SPECIFIC MISSION]

Return concise structured output with: strongest concern, strongest strength, receiver meaning, rewrite advice, Near/Far/Long Horizon notes, confidence, and any critical question. Do not provide hidden chain-of-thought.
```

## Wording principles enforced by the panel

- Words are received, not merely sent.
- Consider receiver interpretation before sender justification.
- Preserve truth while improving clarity, empathy, precision, accountability, dignity, and actionability.
- Avoid manipulation, threat-coded ambiguity, hidden blame, false certainty, corporate filler, and over-softening that removes necessary truth.
- Replace vague judgment with observable facts.
- Replace blame with ownership, support paths, and clear requests.
- Keep apologies specific and proportionate.
- Keep gratitude sincere and non-performative.
- Make the next action clear.

## Fast mode

Fast mode is allowed only when the user explicitly asks for a quick pass. Even then, launch at least three independent agents:
- Literal Clarity Agent.
- Recipient Meaning Agent.
- Adversarial Interpretation Agent.

Do not call a one-pass internal review fast mode.

## Safety and ethics

Do not help craft manipulative, coercive, deceptive, harassing, discriminatory, retaliatory, or threatening messages. If the user's requested wording risks harm, propose a safer alternative that preserves legitimate goals. For legal, HR, medical, safety, crisis, or compliance-sensitive content, recommend appropriate professional review while still helping improve clarity and care.
