---
name: salesforce-agentforce-script
description: Production Salesforce AI skill for Agent instructions/topics/actions/guardrails editing.
license: Apache-2.0
compatibility:
  - Claude Code
  - Claude Agents
  - Codex / ChatGPT
  - GitHub Copilot
metadata:
  version: 2.0.0
  last_updated: 2026-05-20
  owner: Reusable Salesforce AI Skills Library
---

## TRIGGER when
- The task involves Agent instructions/topics/actions/guardrails editing.
- The user asks for implementation, refactor, troubleshooting, review, or best-practice validation in this area.
- The assistant must produce Salesforce-safe code/metadata with explicit security/testing notes.

## DO NOT TRIGGER when
- The task is unrelated to this component.
- Another specialized skill is the primary owner and this area is only incidental.
- The user asks for operational execution (deploy/publish/activate/destructive change) without explicit approval.

## Cross-skill routing
- Always read `../salesforce-global-development/SKILL.md`.
- Also read: Global Development + Prompt Template + Agentforce Authoring Bundle.
- Deep guidance is included in this `SKILL.md`.

## Purpose
Provide independently usable, production-ready assistant guidance for this Salesforce domain without relying on external memory.

## Pre-edit workflow (must follow)
1. Identify target files and component type(s).
2. Read existing implementation and recent commit history around touched files.
3. Capture assumptions, dependencies, and security boundaries.
4. Plan smallest safe change with backward compatibility.
5. List validation commands/checks before editing.

## Post-edit workflow (must follow)
1. Re-open changed files and self-review for correctness.
2. Run local checks/tests relevant to touched component.
3. Verify no secrets, no org-specific IDs, and no unsafe automation instructions were introduced.
4. Document security review, validation results, deployment notes, and rollback notes.
5. Stop short of deploy/publish/activate unless explicitly approved.

## Salesforce best practices
Define concise system policy, clear topic/subagent boundaries, and explicit action selection criteria. Ground responses in known data/actions and require confirmation for write/send operations.

## Upstream Salesforce Skill Patterns
- Agent Script is its own language; never infer syntax from JavaScript, Python, AppleScript, YAML, or Apex.
- Create or update an Agent Spec before meaningful agent changes. The spec is the behavioral baseline for subagents, actions, variables, gates, and tests.
- Always use `sf` agent commands with `--json`; confirm target environment before org interaction.
- Diagnose behavior with live preview and traces before editing: validate, preview with live actions, send representative utterances, then inspect routing, action availability, action I/O, and reasoning.
- Publish is not validation and creates a permanent version. Do not publish or activate until compile validation, live preview, trace review, and explicit user approval are complete.
- Treat Agent Spec approval as a hard gate for meaningful new-agent or major-change work. Capture subagents, actions, variables, routing, backing logic, safety gates, test plan, and any knowledge-grounding requirements before editing.
- For document-grounded agents, capture the source corpus path during requirements/spec work, provision Agentforce Data Library early, wire `knowledge:` and the `AnswerQuestionsWithKnowledge` action deliberately, and wait for a non-null retriever before grounded preview tests.
- Include an LLM-driven safety review across identity/transparency, user safety, data/privacy, content safety, fairness, deception/manipulation, and scope/boundaries before publish.
- Common syntax guardrails: 4-space indentation, no tabs, capitalized booleans, double-quoted strings, no `else if`, no `instructions:` wrapper under `after_reasoning`, and treat `@inputs`/`@outputs` as short-lived action-scope values.
- Prefer architecture patterns from the recipe catalog: hub-and-spoke routing, verification gates before protected work, post-action loops, and safety confirmation gates for write/send actions.

## Examples
### Good example patterns
1. Topic routes billing question to billing subagent with limited actions.
2. Agent asks for confirmation before case update/email action.

### Bad examples / avoid
1. Conflicting instructions between global and topic scopes.
2. Agent claims action results without executing action or evidence.

## Review checklist
- [ ] Change scope is minimal and component-appropriate.
- [ ] Security model (sharing + CRUD/FLS + least privilege) is explicit.
- [ ] Bulk/performance constraints are addressed.
- [ ] Naming and metadata references are stable across orgs.
- [ ] User-facing behavior and error handling are deterministic.

## Validation checklist
- [ ] Relevant tests/checks executed and results captured.
- [ ] No hardcoded IDs, tokens, endpoints, credentials, or customer PII.
- [ ] No deploy/publish/activate/destructive command executed without approval.
- [ ] Links/paths/config references resolve in repo.
- [ ] Rollback approach documented.

## Common AI Mistakes to Avoid
| Mistake | Why it is dangerous | Correct approach |
|---|---|---|
| Editing before reading existing files fully | Breaks local conventions and causes regressions | Inspect target files, surrounding dependencies, and history first |
| Skipping security analysis | Can expose data or violate compliance | Explicitly review sharing, CRUD/FLS, auth, and least privilege |
| Treating happy-path as complete | Misses failures and edge cases | Add negative-path, bulk/performance, and error handling checks |
| Over-scoping changes | Increases risk and review time | Make smallest safe change and defer unrelated refactors |
| Assuming deployment/publish is allowed | Can cause production incidents | Require explicit approval for deploy/publish/activate/destructive actions |

## Output contract (assistant response format)
- Understanding
- Files inspected
- Changes made
- Security review
- Tests / validation
- Deployment notes
- Rollback notes


## Full Guidance

# Agentforce Agent Script -- Authoring Guidelines

How to write `.agent` files well. Pair with **[../salesforce-agentforce-script/SKILL.md](../salesforce-agentforce-script/SKILL.md)** for the DSL grammar and **[../salesforce-agentforce-authoring-bundle/SKILL.md](../salesforce-agentforce-authoring-bundle/SKILL.md)** for the lifecycle.

**Verified against** the same canonical sources. Last verified 2026-05-16.

---

## 1. Two Execution Phases -- The Mental Model

Every reasoning turn has two phases. Understanding them is the prerequisite for writing good instructions.

**Phase 1 -- Deterministic Resolution.** The runtime walks `instructions: ->` top to bottom. It evaluates `if`/`else`, executes `run @actions.X`, runs `set` directives, and accumulates matching `| <prompt line>` text into the LLM's prompt. The LLM is not involved yet.

**Phase 2 -- LLM Reasoning.** The runtime hands the resolved prompt + the available `reasoning.actions` (as tools) to the LLM. The LLM decides what to do: call a tool, transition, escalate, or compose a text response. It CANNOT modify the prompt -- it only reasons against what Phase 1 produced.

This split is the single most important rule:

> **Deterministic logic controls what the agent KNOWS. The LLM controls WHETHER and HOW to act on that knowledge.**

Whenever you can pre-compute something with conditions or actions, do it. Don't ask the LLM to "remember", "check", or "decide" -- set the prompt to only contain what's relevant for this turn.

---

## 2. Condition-Based Instructions -- Not Paragraph Prose

The single biggest authoring mistake is writing reasoning as flowing prose. The DSL exists to give you condition-based **steps** that compile into a turn-specific prompt.

### Anti-pattern (paragraph prose -- DON'T)

```
reasoning:
   instructions: |
      You are an email analysis specialist. First load the case context using
      Get_Email_Resend_Context. Then look at the email body. If you find a 5-group
      confirmation code in the format xxxx-xxxx-xxxx-xxxx-xxxx save it. If you
      don't find one in the body, fall back to the image OCR action. After all
      that, return the JSON. Do not paraphrase, do not invent fields...
```

The LLM has to keep all that in mind every turn. The prompt is identical regardless of state. Re-entry repeats every step. Re-reads happen unnecessarily.

### Canonical pattern (condition-based steps -- DO)

```
reasoning:
   instructions: ->
      # STEP 1 -- Ground context
      if @variables.context_loaded == False:
         | Load the Case and EmailMessage via {!@actions.get_context}.

      # STEP 2 -- Parse confirmation from body
      if @variables.context_loaded == True and @variables.confirmation_from_body == "":
         | Scan the email body for the canonical 5-group code
           xxxx-xxxx-xxxx-xxxx-xxxx (alphanumeric, hyphens/no-hyphens/spaces accepted).
           Save the captured value via {!@actions.set_confirmation_from_body}.

      # STEP 3 -- Fallback to image OCR if body empty
      if @variables.context_loaded == True and @variables.confirmation_from_body == "":
         | If the body has no code, run {!@actions.get_image_confirmation} for OCR.

      # STEP 4 -- Return JSON when we have a code
      if @variables.confirmation_from_body != "" or @variables.confirmation_from_image != "":
         | Return EXACTLY this JSON, no markdown fence, no prose:
           {"summary":"","category":"","intent":"","confirmationNumber":"",
            "newEmailAddress":null,"confidence":0.0}
           Use action-output values verbatim. Do not paraphrase or round.
```

What changed:
- Each step has its own `if @variables.X:` gate. The LLM only sees the prompt fragment when it's relevant.
- Re-entry doesn't repeat completed steps (`if @variables.context_loaded == False:` is False after the first turn).
- Step boundaries are visible to a reviewer.
- Inline action references `{!@actions.get_context}` are explicit, not buried in prose.

---

## 3. Block Labels -- Use the Canonical Names

Field names matter. The parser rejects unknown fields without helpful errors. **Use these exact names:**

| Block / property | Canonical name | Common wrong forms |
|---|---|---|
| Agent identifier | `developer_name` | ~~`agent_name`~~, ~~`api_name`~~ |
| Display name | `agent_label` | ~~`name`~~, ~~`displayName`~~ |
| Agent type | `agent_type` | ~~`type`~~ |
| Welcome message | `system.messages.welcome` | ~~`welcome_message`~~ |
| Error message | `system.messages.error` | ~~`error_message`~~, ~~`fallback`~~ |
| Global instructions | `system.instructions` | ~~`prompt`~~, ~~`persona`~~ |
| Variables block | `variables` | ~~`state`~~, ~~`memory`~~ |
| Router entry point | `start_agent <id>` | ~~`router`~~, ~~`entry`~~ |
| Subagent | `subagent <id>` | ~~`topic`~~ (renamed April 2026) |
| Action definitions | `actions:` (under subagent) | ~~`tools`~~, ~~`functions`~~ |
| Reasoning | `reasoning:` | ~~`logic`~~ |
| Reasoning instructions | `reasoning.instructions` | ~~`reasoning.prompt`~~ |
| LLM-available actions | `reasoning.actions` | ~~`reasoning.tools`~~ |
| Pre-reasoning hook | `before_reasoning:` (no `instructions:` wrapper) | ~~`pre_reasoning`~~ |
| Post-reasoning hook | `after_reasoning:` (no `instructions:` wrapper) | ~~`post_reasoning`~~ |
| Action target | `target:` | ~~`url`~~, ~~`endpoint`~~ |
| Input gate | `available when` | ~~`enabled_if`~~, ~~`visible_when`~~ |

---

## 4. Writing System Instructions

`system.instructions` is the agent's constitution. Keep it 15--30 lines covering:

```
system:
   instructions: |
      ROLE
      You are a server-invoked email-analysis specialist for project.

      GROUNDING
      Ground every output in the data returned by Get_Email_Resend_Context.
      Never invent Case data, customer email content, or email history.

      RETURN CONTRACT
      - STRUCTURED_ANALYSIS mode -> ONLY the prescribed JSON. No markdown fence. No prose.
      - EMAIL_TEMPLATE mode -> ONLY a plain-text email body. No JSON. No sign-off.

      DATA PRIVACY
      Treat the Case payload as PII. Do not echo personally identifiable details
      back into the response unless the user explicitly asked for them.

      FABRICATION
      If a value isn't present in action outputs, leave the corresponding JSON
      field null/empty. Never guess.

      ERROR DEFAULT
      If get_context returns errorMessage, return {"summary":"","category":"FAILED",
      "intent":"NEEDS_HUMAN","confirmationNumber":"","newEmailAddress":null,
      "confidence":0.0}.

      WHAT NOT TO DO
      Do not call the same action twice. Do not paraphrase dates. Do not
      round numbers. Do not address the customer ("Dear...") -- this is
      server-invoked, there is no human in the loop.
```

Notes:
- Section headers (ROLE / GROUNDING / RETURN CONTRACT / DATA PRIVACY / FABRICATION / ERROR DEFAULT / WHAT NOT TO DO) are a project convention -- they help reviewers, the LLM happily reads them.
- Use **operational third-person** for server-invoked agents (no "ask the customer..." since there is no customer).
- For service agents, switch to **second-person imperative** ("Help the customer...", "Ask for their order number").
- Subagents can override with their own `system:` block when domain expertise differs.

### Role, company, description -- write these properly

The `description`, `role`, and `company` fields in `config:` are not cosmetic. The LLM sees them. A two-word `role:` makes the agent generic; a focused one makes it useful.

```
config:
   description: "Server-invoked employee agent that analyzes inbound support emails (STRUCTURED_ANALYSIS mode) and drafts personalized reply emails from named templates (EMAIL_TEMPLATE mode). Clean rebuild of Example_Service_Agent v15."
   role: "Senior support specialist for project -- fluent in airline/hotel loyalty redemption flows, frequent-flyer programs, and the canonical 20-character confirmation-code format (xxxx-xxxx-xxxx-xxxx-xxxx). Reads emails like a tier-2 agent who has seen the same 30 failure modes a hundred times."
   company: "<company/domain context relevant to the assistant>"
```

Three sentences of company context costs nothing and meaningfully grounds the agent in the right vocabulary.

---

## 5. Variables -- State That Matters

Use `variables:` to store anything that:
- Gates a step (`context_loaded`, `is_verified`, `template_loaded`)
- Was captured from a previous action (`case_subject`, `confirmation_from_body`)
- Came from the runtime (`session_id`, `user_role` -- `linked`)

Don't use variables for:
- Constants -- bake them into prompt text or use a Custom Metadata Type read by an action
- Things only one subagent needs that don't outlive that subagent -- local instruction text is fine

```
variables:
   # Identity
   case_id: mutable id = ""
      description: "Case Id the conversation is anchored to (slot-filled from the request)"
   email_message_id: mutable id = ""
      description: "EmailMessage Id of the inbound email"

   # State machine flags
   mode: mutable string = "STRUCTURED_ANALYSIS"
      description: "STRUCTURED_ANALYSIS or EMAIL_TEMPLATE -- router sets at hand-off"
   context_loaded: mutable boolean = False
   template_loaded: mutable boolean = False

   # Action outputs captured for re-use
   confirmation_from_body: mutable string = ""
      description: "Confirmation code extracted from the email body"
   confirmation_from_image: mutable string = ""
      description: "Confirmation code extracted from the image OCR action"
   template_error_message: mutable string = ""
      description: "Populated by Get_Email_Template when it fails"
```

**Always include a `description:`** when the LLM may need context for slot-filling (`@utils.setVariables`).

**Naming**: snake_case, descriptive, no abbreviations. `case_id` (good) vs `cid` (bad). `confirmation_from_body` (good) vs `conf_str` (bad).

---

## 6. The Router Pattern

The `start_agent` IS the router. Keep it thin:

```
start_agent agent_router:
   label: "Agent Router"
   description: "Classify the inbound request and route to the right subagent"

   reasoning:
      instructions: |
         You are a router only. Do NOT analyze, summarise, or answer yourself.
         Pick exactly one transition action and route immediately.
         - If the message asks to draft a reply using a named email template,
           use go_email_template.
         - Otherwise use go_structured_analysis.

      actions:
         go_structured_analysis: @utils.transition to @subagent.structured_analysis
            description: "Analyze an inbound support email and return STRUCTURED_ANALYSIS JSON"

         go_email_template: @utils.transition to @subagent.email_template_drafting
            description: "Draft a reply using a named email template ('Use the email template named ...')"
```

Rules for routers:
- Every transition action MUST have its own `description:` -- that's the only signal the LLM uses to pick.
- Add the trigger phrasing into the `description:` ("'Use the email template named ...'") so the LLM doesn't have to guess.
- Use `instructions: |` (prompt-only) -- the router has no state, just classification.
- Do NOT define backing-logic actions in `start_agent` -- they'd be visible to the planner from every subagent, polluting the action space.

---

## 7. Subagent Anatomy

Every subagent is a self-contained domain:

```
subagent structured_analysis:
   label: "Structured Analysis"
   description: "Analyze an inbound email and return JSON for the LWC parser"

   # Optional system override
   system:
      instructions: |
         You are an email-analysis specialist. Return JSON only -- no markdown, no prose.

   # Subagent-level ACTION DEFINITIONS (the "what exists" layer)
   actions:
      get_context:
         description: "Fetches Case + EmailMessage + recent email history"
         label: "Get Email Resend Context"
         include_in_progress_indicator: True
         progress_indicator_message: "Loading case context..."
         inputs:
            caseId: id
               description: "Salesforce Case Id"
               is_required: True
            emailMessageId: id
               description: "Source EmailMessage Id"
               is_required: True
         outputs:
            caseSubject: string
            emailBody: string
            history: list[object]
               complex_data_type_name: "@apexClassType/c__GetEmailResendContextAction$EmailHistoryItem"
            errorMessage: string
               description: "Populated on failure. Empty on success."
               filter_from_agent: True
         target: "apex://GetEmailResendContextAction"

   # Reasoning -- condition-based steps
   reasoning:
      instructions: ->
         if @variables.context_loaded == False:
            | Load the Case and EmailMessage via {!@actions.get_context}.

         if @variables.context_loaded == True and @variables.confirmation_from_body == "":
            | Scan the email body for the canonical 5-group code.
              Save it via {!@actions.set_confirmation_from_body}.

         # ... more steps ...

      actions:
         get_context: @actions.get_context
            with caseId = @variables.case_id
            with emailMessageId = @variables.email_message_id
            set @variables.case_subject = @outputs.caseSubject
            set @variables.email_body = @outputs.emailBody
            set @variables.context_loaded = True

         set_confirmation_from_body: @utils.setVariables
            description: "Save the confirmation code extracted from the email body"
            with confirmation_from_body = ...
```

The split between **subagent-level `actions:`** (definitions: target, inputs, outputs) and **`reasoning.actions:`** (invocations: with, set, gates) is intentional. Definitions describe what's possible; reasoning describes when and how.

---

## 8. Action Design

### Inputs

- **Slot-fill (`...`)** when the value comes from conversation context: `with order_id = ...`
- **Bound** when the value is already known: `with case_id = @variables.case_id`
- **Literal** when the value is fixed: `with limit = 10`

### Outputs

Every output should have a `description:` and (for non-displayable internals) `filter_from_agent: True`:

```
outputs:
   intent_classification: string
      description: "Classified intent -- used for routing"
      filter_from_agent: True       # Don't show to user
      is_used_by_planner: True       # Let LLM reason about it for routing
   summary: string
      description: "Customer-facing summary of the analysis"
      is_displayable: True
   errorMessage: string
      description: "Populated on failure. Empty on success."
      filter_from_agent: True
```

### errorMessage is the deterministic safety net

If the action's failure must change agent behavior, declare `errorMessage: string` in `outputs:`. The Apex `@InvocableMethod` populates it inside a try/catch (never throws). Then your guardrail is deterministic:

```
reasoning:
   actions:
      get_template: @actions.get_email_template
         with templateName = @variables.requested_template
         set @variables.template_body = @outputs.body
         set @variables.template_error_message = @outputs.errorMessage
         set @variables.template_loaded = True

   instructions: ->
      if @variables.template_loaded == True and @variables.template_error_message != "":
         | The requested template could not be loaded. Return a graceful
           fallback explaining the issue and asking the user to try again.
```

If `errorMessage` doesn't exist on the action, the guardrail collapses to prose ("if action fails..."), and the LLM has to infer failure. Don't ship that pattern.

### `available when` gates

Use `available when` to hide actions until prerequisites are met:

```
reasoning:
   actions:
      check_eligibility: @actions.check_eligibility
         available when @variables.is_verified == True

      proceed_with_refund: @actions.process_refund
         available when @variables.is_verified == True and @variables.eligible == True
```

This is how to prevent the LLM from calling actions out of order.

---

## 9. Transition Syntax -- Context-Sensitive

| Context | Syntax |
|---|---|
| Inside `reasoning.actions:` (LLM picks) | `name: @utils.transition to @subagent.X` |
| Inside `instructions: ->`, `before_reasoning:`, `after_reasoning:` (deterministic) | bare `transition to @subagent.X` |

Mixing the two = parser error.

`@utils.transition to` is a **handoff** -- the target subagent takes over completely and generates the user-facing reply.

`@subagent.X` (without `transition to`) is **supervision** -- the target subagent runs, returns control to the parent, and the parent synthesizes the final response.

---

## 10. Safety Guardrails

Apply the 7-category framework on every new agent before publish. Score severity: **BLOCK** stops the pipeline; **WARN** flags for review; **INFO** is best practice.

| Category | Check (selection) |
|---|---|
| Identity & Transparency | AI disclosure in `system.instructions`; no impersonation of licensed professionals, authorities, brands |
| User Safety | No pressure tactics, dark patterns, emotional manipulation; escalation paths for crisis/sensitive topics |
| Data Handling | No unnecessary PII collection; data minimization; explicit "don't echo PII" rules |
| Content Safety | No harmful content facilitation; jailbreak resistance instructions |
| Fairness | No direct or proxy discrimination |
| Deception | No false claims, no fake urgency, no astroturfing |
| Scope & Boundaries | Explicit "only handle X" + "do not Y" clauses; clear out-of-scope deflection |

For server-invoked employee agents handling PII (like `Example_Agent`):
- `<logPrivateConversationData>false</logPrivateConversationData>` re-asserted via override manifest after every publish
- `system.instructions` contains an explicit PII redaction policy
- Every backing-Apex SOQL uses `WITH USER_MODE`

---

## 11. Variable Hygiene

- Every `mutable` variable has a default value.
- Every `linked` variable has a `source:` and no default.
- `True` / `False` only (never lowercase).
- `...` only as a slot-fill placeholder for action inputs -- never as a variable default.
- Description present for any variable the LLM may need to slot-fill.

---

## 12. Loop Prevention

The runtime has a built-in guardrail that breaks out of reasoning loops after ~3--4 iterations. To prevent unintended loops:

1. **Use `available when`** to hide actions once they've completed.
2. **Set a "done" variable** in the post-action `set` block and gate the action on its negation.
3. **In `reasoning.instructions:`**, explicitly tell the LLM what to do AFTER the action: "Do NOT call the action again -- you have the result."

Anti-pattern (loops):

```
reasoning:
   instructions: ->
      | Place an order using {!@actions.create_order}.
   actions:
      create_order: @actions.create_order
         with items = @variables.cart_items
```

Fixed:

```
reasoning:
   instructions: ->
      if @variables.order_id == "":
         | Place the order using {!@actions.create_order}. After success,
           confirm the order number and stop -- do not call the action again.

      if @variables.order_id != "":
         | The order is placed (id: {!@variables.order_id}).
           Confirm to the user and ask what else they need.

   actions:
      create_order: @actions.create_order
         available when @variables.order_id == "" and @variables.cart_total > 0
         with items = @variables.cart_items
         set @variables.order_id = @outputs.id
```

Three mitigations applied: post-action variable set, `available when` gate, explicit "do not call again" in instructions.

---

## 13. Architecture Patterns -- Quick Pick

| Pattern | Use when |
|---|---|
| **Hub-and-Spoke** | 2+ distinct intents. `start_agent` routes; each spoke has a "back to hub" transition. |
| **Verification Gate** | PII / payments / sensitive ops. `available when @variables.is_verified == True` on protected entries. |
| **Post-Action Loop** | An action's output gates the next prompt. Put post-action checks at the TOP of `instructions: ->`. |
| **Single Subagent** | One focused purpose, no routing. Skip the hub. |

Full code for each is in **[../salesforce-agentforce-script/SKILL.md Section 12 salesforce-agentforce-script/SKILL.md)**.

---

## 14. Testing Strategy

1. **Validate**: `sf agent validate authoring-bundle --json --api-name <Name>` -- syntax check.
2. **Live preview per subagent**: one utterance for each subagent based on its `description:` keywords.
3. **Trigger-utterance per action**: one utterance that should fire each key action.
4. **Off-topic utterance**: tests guardrails ("tell me a joke").
5. **Multi-turn pair**: tests subagent transitions ("Check my order" -> "Actually I want to return it").
6. **Trace inspection**: read `traces/<PLAN_ID>.json` after each turn. Confirm subagent routing, action invocation, grounding.

Use `jq` to extract specific signals (transitions, actions called, grounding result) -- full snippet library in **[../salesforce-agentforce-authoring-bundle/SKILL.md Section 10 salesforce-agentforce-authoring-bundle/SKILL.md)**.

---

## 15. 100-Point Scoring Rubric (per forcedotcom)

Score every agent against this rubric before publish:

| Category | Points | Key criteria |
|---|---:|---|
| Structure & Syntax | 15 | Required blocks present in correct order, consistent indentation, valid field names |
| Safety & Responsible AI | 15 | Passes 7-category safety review; no BLOCK findings |
| Deterministic Logic | 20 | `after_reasoning` for post-action routing; FSM with no dead-ends; `available when` on sensitive actions |
| Instruction Resolution | 20 | Condition-based steps (`->` + `if`) where conditionals are needed; prompt-only (`\|`) where static |
| FSM Architecture | 10 | Hub-and-spoke or verification gate; every subagent reachable; every subagent has an exit |
| Action Configuration | 10 | Proper definition layer (target, inputs, outputs); proper invocation layer (with, set); correct type mapping |
| Deployment Readiness | 10 | Valid `default_agent_user` (or absent for EmployeeAgent); `developer_name` matches folder; correct linked vars for ServiceAgents |

| Score | Action |
|---|---|
| 90--100 | Production-ready |
| 75--89 | Fix minor issues, then deploy |
| 60--74 | Structural rework needed |
| < 60 | BLOCK -- major rewrite |

---

## 16. Anti-Patterns

| # | Anti-pattern | Why |
|---|---|---|
| 1 | Paragraph prose in `reasoning.instructions:` | LLM controllability poor; re-resolves identically every turn; re-entry repeats completed steps |
| 2 | Monolithic agent in one `start_agent` block with no subagents | Tools all visible everywhere; planner confused; cannot scope state |
| 3 | Welcome message with `{!@variables.x}` | Welcome renders before variables initialize -- interpolation never resolves |
| 4 | Action with no `outputs:` block | Publish fails with "Internal Error" |
| 5 | Action whose failure should change behavior but lacks `errorMessage` output | Guardrail collapses to prose; LLM has to infer failure |
| 6 | Asking the LLM "remember X" or "check if Y" in prose | Promote to deterministic `set @variables.X` + `if @variables.X:` |
| 7 | Generic prompt-extraction descriptions ("a code with dashes") | Describe the literal format: "5 groups of 4 alphanumeric, e.g. ABCD-1234-EFGH-5678-WXYZ" |
| 8 | Paraphrased colon-label strings when an LWC parses agent output | LWC doesn't fuzzy-match. Output exact strings (colon, casing, spacing) |
| 9 | JSON output fields without matching text in the summary | JSON drives automation; summary drives humans. State data in BOTH; never contradict |
| 10 | Defining 12 actions in one subagent | The planner sees them all every turn. Split by domain. |
| 11 | Action loops (no gate, no "do not call again") | Use `available when` + post-action variable set + explicit stop instruction |
| 12 | Conversational style ("ask the customer...") on server-invoked agent | No customer in the loop. Use operational third-person. |
| 13 | Welcome message with multi-line content | Line breaks stripped. Use single-line welcome; multi-line greeting in first subagent. |

---

## 17. Definition of Done

A new or modified agent is NOT done until every item is true:

**Design**
- [ ] Each subagent has clear, non-overlapping scope expressed in `description:`
- [ ] `system.instructions` covers ROLE / GROUNDING / RETURN CONTRACT / DATA PRIVACY / FABRICATION / ERROR DEFAULT / WHAT NOT TO DO
- [ ] Every subagent's `reasoning.instructions:` uses condition-based step blocks
- [ ] Every transition action has its own `description:` with trigger keywords/phrases

**Actions & Variables**
- [ ] Every action that can fail in a behavior-changing way declares `errorMessage: string` in `outputs:`
- [ ] Every output that gates routing has `is_used_by_planner: True`; PII/internals have `filter_from_agent: True`
- [ ] Variable names match downstream consumer expectations (LWC labels, Apex parsers)
- [ ] Every `mutable` has a default; every `linked` has a `source:` and no default
- [ ] `True` / `False` everywhere (no lowercase)

**Safety**
- [ ] 7-category safety review run -- zero BLOCK findings
- [ ] Verification gate (if any) enforced both in agent script AND in backing-logic code (dual enforcement)
- [ ] PII policy stated in `system.instructions`
- [ ] Escalation triggers defined for: verification failure, action failure, out-of-scope

**Deployment**
- [ ] `sf agent validate authoring-bundle` passes with zero errors
- [ ] Live preview tested per subagent with representative utterances
- [ ] Traces confirm correct routing and action invocation
- [ ] Bot-meta override prepared (if PII; `logPrivateConversationData=false`)
- [ ] Rollback plan documented (previous active version known)

---

## 18. Empirical Findings & Implementation Notes

| # | Date | Documented approach | What actually works | Why / Context |
|---|---|---|---|---|
| 1 | 2026-05-15 | Salesforce Agentforce Employee Agent help-doc topic-instruction style uses second-person imperative ("Ask the customer...", "Say to the user...") | For server-invoked employee agents (no live conversation), the conversational style doesn't apply. Reframe in operational third-person: "Extract caseId from the user message", "Return JSON with these keys", "Do not include sign-off" | This org's server-invoked EmployeeAgents are programmatically called from Apex. The agent's messages never reach a human. Help-doc style assumes a user-facing copilot |
| 2 | 2026-05-16 | Welcome messages support `{!@variables.x}` template interpolation | Welcome message renderer runs BEFORE variables initialize. Interpolation literals appear in the rendered text. Use static welcome; put personalized greeting in the first subagent's `reasoning.instructions:` (Issue #11) | Discovered when a draft welcome string contained `{!@variables.case_id}` and shipped to a test session with literal `{!@variables.case_id}` text |
| 3 | 2026-05-16 | Welcome messages support multi-line content | Line breaks are stripped on render. Multi-line greetings must live in the first subagent's instructions (Issue #12) | |
| 4 | 2026-05-16 | The 7-section "constitution" header style (ROLE / GROUNDING / RETURN CONTRACT / DATA PRIVACY / FABRICATION / ERROR DEFAULT / WHAT NOT TO DO) is documented as best practice for agent `system.instructions` | The headers are a project convention modeled on `Global_Care_Service_Agent_Script.agent`. They are NOT documented by Salesforce -- but they compile fine as prose and make the agent's responsibilities reviewable. Keep them; new authoring matches the convention | |

---

## 19. Official References

- [Agent Script Developer Guide](https://developer.salesforce.com/docs/ai/agentforce/guide/agent-script.html)
- [Agent Script Decoded -- blog](https://developer.salesforce.com/blogs/2026/02/agent-script-decoded-intro-to-agent-script-language-fundamentals)
- [forcedotcom/sf-skills `developing-agentforce`](https://github.com/forcedotcom/sf-skills/tree/main/skills/developing-agentforce) -- full reference library
- [trailheadapps/agent-script-recipes](https://github.com/trailheadapps/agent-script-recipes) -- 30+ working `.agent` files
- [Agent Script Canonical Reference](../salesforce-agentforce-script/SKILL.md) -- DSL grammar (this skill set)
- [Agentforce Authoring Bundle Guide](../salesforce-agentforce-authoring-bundle/SKILL.md) -- lifecycle (this skill set)

---

*Agentforce Script Authoring Guidelines | v3.0 | Last verified 2026-05-16*


## Reference

# Agent Script -- Canonical DSL Reference

Authoritative grammar for `.agent` files in this project. Other Agentforce skill files reference this one.

**Verified against:** [Agent Script Developer Guide](https://developer.salesforce.com/docs/ai/agentforce/guide/agent-script.html) - [Agent Script Blocks](https://developer.salesforce.com/docs/ai/agentforce/guide/ascript-blocks.html) - [Language Characteristics](https://developer.salesforce.com/docs/ai/agentforce/guide/ascript-lang.html) - [Actions Reference](https://developer.salesforce.com/docs/ai/agentforce/guide/ascript-ref-actions.html) - [Reference Index](https://developer.salesforce.com/docs/ai/agentforce/guide/ascript-reference.html) - [Agent Script Decoded (blog)](https://developer.salesforce.com/blogs/2026/02/agent-script-decoded-intro-to-agent-script-language-fundamentals) - [trailheadapps/agent-script-recipes](https://github.com/trailheadapps/agent-script-recipes) (30+ working `.agent` files) - [forcedotcom/sf-skills `developing-agentforce`](https://github.com/forcedotcom/sf-skills/tree/main/skills/developing-agentforce) (complete reference library). Last verified 2026-05-16.

> **April 2026 rename:** "topics" are now called **subagents**. Functionality unchanged. Use `subagent` in all new authoring.

---

## 1. File Layout

A script-version agent lives in one directory:

```
force-app/main/default/aiAuthoringBundles/<Developer_Name>/
   <Developer_Name>.agent              # Agent Script source
   <Developer_Name>.bundle-meta.xml    # Metadata wrapper
```

`<Developer_Name>.bundle-meta.xml` -- minimal valid form:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<AiAuthoringBundle xmlns="http://soap.sforce.com/2006/04/metadata">
   <bundleType>AGENT</bundleType>
</AiAuthoringBundle>
```

After publish, a `<target>X.vN</target>` element may appear. Its presence **locks** the bundle to that published version (read-only). Remove `<target>` to re-enable edits.

**Critical:** The directory name, the `.agent` filename, and `developer_name` in the `config:` block must all match exactly (case-sensitive).

---

## 2. Block Order

Top-level blocks must appear in this order. Wrong order = compile error.

```
1. system:                  required
2. config:                  required
3. variables:               optional
4. connection messaging:    optional (singular, standalone -- service agents only)
5. knowledge:               optional
6. language:                optional
7. start_agent <id>:        required -- the router
8. subagent <id>:           one or more required
```

> Note: many working recipes (trailheadapps) put `config:` first. Both forms compile. **Use `system:` first** per the forcedotcom canonical order -- the platform's own skill library follows it.

**Internal order within `start_agent` and `subagent`:**
1. `description:` (required)
2. `label:` (optional display)
3. `system:` (optional override of global)
4. `before_reasoning:` (optional)
5. `reasoning:` (required)
6. `after_reasoning:` (optional)
7. `actions:` (optional -- subagent-level definitions)

---

## 3. Syntax Fundamentals

| Element | Rule |
|---|---|
| Indentation | 3 spaces per level (or 4 -- be consistent). Never tabs. Never mix. |
| Booleans | `True` / `False` only. Lowercase `true`/`false` fails. |
| Strings | Always double-quoted. |
| Comments | `#` to end of line. No multi-line syntax. **Never use comments alone as an `if`/`else` body -- the parser strips them and the block becomes an empty no-op.** |
| Procedural opener | `->` after a key (`instructions: ->`) -- deterministic logic |
| Prompt opener | `|` after a key, or inside a `->` block -- LLM prompt text |
| Template interpolation | `{!@variables.x}` -- only inside prompt text |
| Slot-fill placeholder | `...` -- only valid as an action input value (never as a variable default) |
| Reference prefix | `@` |

**Reference forms**

| Reference | Where it's valid |
|---|---|
| `@variables.<name>` | Logic (`if`, `set`, `with`); also in prompt text wrapped as `{!@variables.x}` |
| `@actions.<name>` | `run`, `set`, `with`, `available when`, and as template `{!@actions.x}` |
| `@subagent.<name>` | Transitions and delegations |
| `@outputs.<name>` | **Only** in `set` / `if` immediately after the action call |
| `@inputs.<name>` | **Only** in `with` during invocation. Using in `set` = silent runtime failure |
| `@utils.<utility>` | `escalate`, `transition to`, `setVariables` |
| `@session.<field>` | `source:` for linked variables |
| `@system_variables.user_input` | The last customer utterance (read-only) |

**Operators**

| Category | Operators |
|---|---|
| Comparison | `==`, `!=`, `<`, `<=`, `>`, `>=`, `is`, `is not` |
| Logical | `and`, `or`, `not` |
| Arithmetic | `+`, `-` only (no `*`, `/`, `%`) |
| Conditional expression | `x if condition else y` |

`else if` is **not** supported. Use compound `if x and y:` or sequential flat `if` blocks. `<>` is invalid -- use `!=`.

**Naming rules** (developer_name, subagent names, variable names, action names, transition names)
- Letters, numbers, underscores only
- Must begin with a letter
- Cannot end with an underscore
- No two consecutive underscores
- Max 80 characters
- No spaces
- `snake_case` strongly recommended

---

## 4. `system:` Block

```
system:
   instructions: |
      You are a server-invoked email-analysis specialist for project.
      Ground every output in Get_Email_Resend_Context outputs -- never invent
      Case data, customer email content, or email history.
      Return JSON only when in STRUCTURED_ANALYSIS mode.
   messages:
      welcome: "Ready."                          # REQUIRED -- first message of conversation
      error: "Operation cancelled for safety."    # REQUIRED -- fallback on internal failure
```

A subagent can override `system.instructions` with its own `system:` block inside the subagent.

**Welcome-message gotchas (Issues #11, #12):**
- `{!@variables.x}` interpolation does NOT work in the welcome message -- runtime renders welcome before variables initialize. Use a static welcome.
- Line breaks in welcome are stripped. Keep welcome single-line; put multi-line greetings in the first subagent's `instructions:`.

---

## 5. `config:` Block

```
config:
   developer_name: "Example_Agent"                 # REQUIRED -- API name. Must match directory + filename exactly.
   agent_label: "Example Agent"                    # Optional display name
   description: "Server-invoked agent that analyzes inbound support emails..."
   role: "AI assistant for project support reps."
   company: "<company/domain context relevant to the assistant>"
   agent_type: "AgentforceEmployeeAgent"           # or "AgentforceServiceAgent"
   default_agent_user: "agent.user@example.com"   # REQUIRED for ServiceAgent. PROHIBITED for EmployeeAgent.
   enable_enhanced_event_logs: True
   user_locale: "en_US"
```

**`default_agent_user` trap:** setting it on an `AgentforceEmployeeAgent` causes publish to fail with the cryptic `Internal Error, try again later`. The error message gives no hint that `default_agent_user` is the cause. Always omit on employee agents.

**`AgentforceEmployeeAgent` MUST NOT include:**
- `default_agent_user`
- `connection messaging:` block
- MessagingSession linked variables (`EndUserId`, `RoutableId`, `ContactId`, `EndUserLanguage`)
- `@utils.escalate` (requires `connection messaging:`)

**Field check:** It is `developer_name`, **not** `agent_name`. `agent_name` is not a valid field.

---

## 6. `variables:` Block

Two kinds: `mutable` and `linked`.

```
variables:
   # mutable -- read+write. MUST have a default value.
   case_id: mutable id = ""
      description: "Salesforce Case Id this conversation is anchored to"

   confirmation_from_body: mutable string = ""
      description: "Confirmation code captured from the email body"

   context_loaded: mutable boolean = False

   history_items: mutable list[object] = []

   # linked -- read-only. MUST have a `source:`. MUST NOT have a default.
   session_id: linked string
      description: "Session ID injected by the runtime"
      source: @session.sessionID
```

**Type vs modifier matrix**

| Type | mutable | linked | action I/O |
|---|:-:|:-:|:-:|
| `string` | yes | yes | yes |
| `number` | yes | yes | yes (with caveat -- see Section 9 `boolean` | yes | yes | yes |
| `id` | yes | yes | yes |
| `date` | yes | yes | yes |
| `currency` | yes | yes | yes |
| `timestamp` | compiles but absent from GA docs -- avoid | | |
| `object` | yes | -- | yes |
| `list[T]` | yes | -- | yes |
| `integer`, `long`, `datetime`, `time` | -- | -- | yes |

**Linked-variable rules**
- `source:` required, default forbidden.
- Cannot be `list[T]` or `object`.
- Common sources: `@session.sessionID`, `@MessagingSession.MessagingEndUserId`, `@MessagingSession.Id`, `@MessagingEndUser.ContactId`, `@context.userRole`.

**Service-agent linked variables (do NOT add to employee agents):**

```
EndUserId: linked string
   source: @MessagingSession.MessagingEndUserId
   description: "Messaging End User ID"
   visibility: "External"

RoutableId: linked string
   source: @MessagingSession.Id
   visibility: "External"

ContactId: linked string
   source: @MessagingEndUser.ContactId
   visibility: "External"
```

---

## 7. `start_agent <router_id>:` Block -- The Router

The `start_agent` IS the router. **Do not create a separate routing subagent** -- that adds an LLM hop (~3-5s latency) and confuses the planner.

```
start_agent agent_router:
   label: "Agent Router"
   description: "Classify the inbound request and route to the correct subagent"

   reasoning:
      instructions: |
         You are a router only. Do NOT answer questions or draft replies yourself.
         Always pick exactly one transition action and route immediately.
         - If the message asks to draft a reply using a named email template,
           use go_email_template.
         - Otherwise use go_structured_analysis.
      actions:
         go_structured_analysis: @utils.transition to @subagent.structured_analysis
            description: "Analyze an inbound support email and return STRUCTURED_ANALYSIS JSON"

         go_email_template: @utils.transition to @subagent.email_template_drafting
            description: "Draft a reply using a named email template ('Use the email template named ...')"
```

Every transition action MUST have its own `description:` -- that's the only signal the LLM uses to pick.

---

## 8. `subagent <id>:` Block

```
subagent structured_analysis:
   label: "Structured Analysis"
   description: "Analyze an inbound email and return JSON for the LWC parser"

   # Optional -- override system.instructions for this subagent only
   system:
      instructions: |
         You are an email-analysis specialist. Return JSON only.

   # Subagent-level action definitions -- declare inputs/outputs/target
   actions:
      get_context:
         description: "Fetches Case + EmailMessage + recent email history"
         label: "Get Email Resend Context"
         include_in_progress_indicator: True
         progress_indicator_message: "Loading case context..."
         inputs:
            caseId: id
               description: "Salesforce Case Id"
               is_required: True
            emailMessageId: id
               description: "Source EmailMessage Id"
               is_required: True
         outputs:
            caseSubject: string
               description: "Case Subject"
            emailBody: string
               description: "Plain-text email body"
            history: list[object]
               description: "Recent EmailMessage history"
               complex_data_type_name: "@apexClassType/c__GetEmailResendContextAction$EmailHistoryItem"
            errorMessage: string
               description: "Populated when the action fails. Empty on success."
               filter_from_agent: True
         target: "apex://GetEmailResendContextAction"

   # Reasoning -- condition-based steps + LLM-available actions
   reasoning:
      instructions: ->
         # STEP 1 -- Load context if not yet loaded
         if @variables.context_loaded == False:
            | Load the Case and EmailMessage using {!@actions.get_context}.

         # STEP 2 -- Body parse
         if @variables.context_loaded == True and @variables.confirmation_from_body == "":
            | Scan the email body for the canonical 5-group code
              xxxx-xxxx-xxxx-xxxx-xxxx (alphanumeric, hyphens/no-hyphens/spaces accepted).
              Save the captured value via {!@actions.set_confirmation_from_body}.

         # STEP 3 -- Image OCR fallback when body has no code
         if @variables.context_loaded == True and @variables.confirmation_from_body == "":
            | Fall back to {!@actions.get_image_confirmation} for embedded-image OCR.

         # STEP 4 -- Return JSON contract
         if @variables.confirmation_from_body != "" or @variables.confirmation_from_image != "":
            | Return EXACTLY this JSON shape, no markdown fence, no prose:
              {"summary":"","category":"","intent":"","confirmationNumber":"",
               "newEmailAddress":null,"confidence":0.0}
              Use values returned by the actions verbatim. Do not paraphrase dates,
              do not round numbers, do not invent fields.

      actions:
         get_context: @actions.get_context
            with caseId = @variables.case_id
            with emailMessageId = @variables.email_message_id
            set @variables.case_subject = @outputs.caseSubject
            set @variables.email_body = @outputs.emailBody
            set @variables.context_loaded = True

         set_confirmation_from_body: @utils.setVariables
            description: "Save the confirmation code extracted from the email body"
            with confirmation_from_body = ...

         get_image_confirmation: @actions.get_image_confirmation
            available when @variables.context_loaded == True and @variables.confirmation_from_body == ""
            with caseId = @variables.case_id
            with emailMessageId = @variables.email_message_id
            set @variables.confirmation_from_image = @outputs.outMessage

   # Optional -- deterministic step AFTER the LLM's reasoning loop
   after_reasoning:
      # Content goes DIRECTLY here. NO `instructions:` wrapper.
      if @variables.context_loaded == True and @variables.confirmation_from_body == "":
         transition to @subagent.exit_summary
```

### Reasoning grammar

- `instructions: ->` opens a **procedural** block: deterministic. `if`, `set`, `run`, `transition to`, and `| <prompt line>` are all valid inside.
- `instructions: |` opens a **prompt-only** block: the entire body goes to the LLM verbatim. Logic is not allowed.
- Inside a `->` block, `| <line>` lines are conditional prompt fragments -- they're appended to the LLM's prompt only when their enclosing `if` is True.
- A bare line continuation (no leading `|`) extends the previous `| <line>`.

### `reasoning.actions` -- what the LLM can invoke

```
reasoning:
   actions:
      # Slot-fill all params (LLM extracts from convo)
      search: @actions.search_products
         with query = ...
         with category = ...

      # Mixed: bound + slot-fill + fixed
      lookup: @actions.lookup_customer
         with customer_id = @variables.current_customer_id   # bound
         with include_history = ...                          # LLM decides
         with limit = 10                                     # fixed literal

      # Capture outputs AFTER the action runs
      process: @actions.process_order
         with order_id = @variables.order_id
         set @variables.status = @outputs.status
         set @variables.total = @outputs.total
         if @outputs.needs_review:
            transition to @subagent.review

      # Conditional availability -- LLM only sees this action when the gate is True
      admin_op: @actions.admin_function
         available when @variables.user_role == "admin"
```

### Utility shortcuts (only in `reasoning.actions`)

| Utility | Behavior |
|---|---|
| `@utils.transition to @subagent.X` | **Handoff** -- child takes over completely and generates the user-facing reply |
| `@utils.escalate` | Route to human (service agents only; needs `connection messaging:`) |
| `@utils.setVariables` | LLM sets variables from conversation slots |
| `@subagent.X` (without `transition to`) | **Supervision** -- child runs, returns control to parent, parent synthesizes |

**Handoff vs Supervision** is a critical distinction. Handoff is one-way; supervision returns.

---

## 9. Action Definitions -- Targets & Types

```
actions:
   apex_action:
      target: "apex://InvocableClassName"
   flow_action:
      target: "flow://Flow_API_Name"
   prompt_action:
      target: "prompt://Prompt_Template_API_Name"
```

Other valid prefixes: `standardInvocableAction://`, `externalService://`, `quickAction://`, `api://`, `apexRest://`, `serviceCatalog://`, `integrationProcedureAction://`, `expressionSet://`, `cdpMlPrediction://`, `externalConnector://`, `slack://`, `namedQuery://`, `auraEnabled://`, `mcpTool://`, `retriever://`.

**Action property reference**

| Action-level | Input | Output |
|---|---|---|
| `target:` (req) | `description:` | `description:` |
| `description:` (req) | `label:` | `label:` |
| `label:` | `is_required:` (bool) | `is_displayable:` (bool) |
| `require_user_confirmation:` (bool -- runtime no-op per Issue #6) | `is_user_input:` (bool -- LLM extracts from convo) | `filter_from_agent:` (bool -- hide from LLM) |
| `include_in_progress_indicator:` (bool) | `complex_data_type_name:` | `is_used_by_planner:` (bool -- let LLM reason about it) |
| `progress_indicator_message:` (string) | | `complex_data_type_name:` |

**`outputs:` block is REQUIRED** -- Issue #15: subagent-level action definitions without an `outputs:` block fail at publish with "Internal Error, try again later". CLI validate passes but publish fails.

### Numeric output gotcha -- target-dependent

Bare `number` works for variables but **fails at publish** for action I/O. Use `object` + `complex_data_type_name`. **The correct value differs by target:**
- `flow://` targets: `lightning__numberType`
- `apex://` targets: `lightning__integerType`

```
outputs:
   order_count: object
      description: "Total orders"
      complex_data_type_name: "lightning__integerType"      # apex target
```

### Complex type aliases

| `complex_data_type_name` | Maps to |
|---|---|
| `lightning__integerType` | Integer (apex I/O) |
| `lightning__numberType` | Integer (flow I/O) |
| `lightning__doubleType` | Decimal / floating-point |
| `lightning__booleanType` | Boolean |
| `lightning__dateType` | Date |
| `lightning__dateTimeStringType` | DateTime returned as ISO string (preferred -- `lightning__dateTimeType` per upstream docs but `lightning__dateTimeStringType` is the tested value) |
| `lightning__currencyType` | Currency |
| `lightning__recordIdType` | Salesforce record Id |
| `lightning__recordInfoType` | SObject record wrapper |
| `lightning__objectType` | Generic structured object |
| `lightning__listType` | List wrapper |
| `lightning__textType` | Text / list[string] / list[object] |
| `@apexClassType/<ns>__<ClassName>$<InnerType>` | Apex inner class |

**Reserved Apex `@InvocableVariable` names** that fail Agent Script compilation: `model`, `description`, `label`. Use any other name.

### Apex parameter name match

Action input names must EXACTLY match Apex `@InvocableVariable` field names (case-sensitive). Snake_case Agent Script with camelCase Apex won't bind:

```
# WRONG -- snake_case doesn't match @InvocableVariable venueName
inputs:
   venue_name: string

# RIGHT
inputs:
   venueName: string
```

### Prompt-template actions are different

Prompt templates use a quoted `"Input:"` prefix and a fixed `promptResponse` output. Long-form target is `generatePromptResponse://`.

```
actions:
   Generate_Schedule:
      target: "prompt://Generate_Personalized_Schedule"   # or "generatePromptResponse://..."
      inputs:
         "Input:email": string
            description: "User's email address"
            is_required: True
      outputs:
         promptResponse: string
            description: "Generated schedule text"

reasoning:
   actions:
      generate: @actions.Generate_Schedule
         with "Input:email" = @variables.user_email
         set @variables.schedule = @outputs.promptResponse
```

---

## 10. Transition Syntax -- Context-Sensitive

| Context | Syntax |
|---|---|
| Inside `reasoning.actions:` (LLM picks) | `name: @utils.transition to @subagent.X` |
| Inside `instructions: ->`, `before_reasoning:`, `after_reasoning:` (deterministic) | bare `transition to @subagent.X` |

Mixing the two = parser error.

`before_reasoning:` and `after_reasoning:` content goes DIRECTLY under the block -- no `instructions:` wrapper.

---

## 11. Lifecycle -- From Source to Live Agent

| Phase | Command | What it does |
|---|---|---|
| Generate | `sf agent generate authoring-bundle --json --no-spec --name "<Label>" --api-name <Dev_Name>` | Create `.agent` + `.bundle-meta.xml` locally |
| Validate | `sf agent validate authoring-bundle --json --api-name <Dev_Name>` | Syntax + structure check (does NOT contact the org) |
| Deploy | `sf project deploy start --json --metadata AiAuthoringBundle:<Dev_Name>` | Push authoring bundle to org. Authoring domain only. |
| Publish | `sf agent publish authoring-bundle --json --api-name <Dev_Name>` | Compile + create Bot + BotVersion + GenAiPlannerBundle. Self-contained -- no prior deploy needed. |
| Activate | `sf agent activate --json --api-name <Bot_API_Name>` | Make a published version live |
| Preview (dev) | `sf agent preview start --json --use-live-actions --authoring-bundle <Dev_Name>` | Preview from local source against the org |
| Preview (published) | `sf agent preview start --json --api-name <Bot_API_Name>` | Preview the active published version |
| Deactivate | `sf agent deactivate --json --api-name <Bot_API_Name>` | Take a version offline (keeps version) |
| Retrieve source | `sf project retrieve start --json --metadata AiAuthoringBundle:<Dev_Name>` | Pull `.agent` source back |
| Retrieve runtime | `sf project retrieve start --json --metadata Agent:<Dev_Name>` | Pull Bot + BotVersion + GenAiPlannerBundle. **Does NOT include AiAuthoringBundle.** |

**Always include `--json` first.** Always use `--no-spec` on `generate` (the interactive spec prompt hangs).

**Deploy vs Publish:** Deploy = push source to org. Publish = compile + create runtime entities (Bot, BotVersion, GenAiPlannerBundle). Deploy alone never creates a usable agent.

**After publish, retrieve to inspect:** `sf agent publish` does not tell you which version number was created. Retrieve the bundle and read `<target>` in `bundle-meta.xml`.

**Lock recovery:** If `<target>` appears in `bundle-meta.xml` after a retrieve, the bundle is locked. Remove the `<target>` line and deploy to unlock.

**Service-agent gotcha -- `EinsteinAgentApiChannel` not auto-generated:** the `connection messaging:` block only produces a `Messaging` plannerSurface. `CustomerWebClient` is dropped on every publish. Patch the GenAiPlannerBundle after each publish (see Issue #18).

---

## 12. Architecture Patterns (FSM)

| Pattern | Use when |
|---|---|
| Hub-and-Spoke | Two or more distinct subagents with different intents. Most common. |
| Verification Gate | Sensitive data / payments / PII require identity verification first |
| Post-Action Loop | An action's output drives follow-up logic that needs to re-evaluate |
| Single Subagent | One focused purpose, no routing |

**Hub-and-Spoke:** `start_agent` routes to N spoke subagents. Each spoke has a "back to hub" transition: `@utils.transition to @subagent.agent_router`. Routing lives in `start_agent` -- never duplicate it into a `main_menu` subagent.

**Verification Gate:** protected subagents use `available when @variables.is_verified == True` on their entry transitions.

**Post-Action Loop:** put post-action checks at the TOP of `instructions: ->`. The runtime re-resolves the block after the action completes.

---

## 13. Anti-Patterns (Compile or Runtime Failures)

| # | Anti-pattern | Why it fails |
|---|---|---|
| 1 | `agent_name:` in `config:` | Field doesn't exist -- use `developer_name:` |
| 2 | `default_agent_user` on `AgentforceEmployeeAgent` | Publish fails with cryptic "Internal Error, try again later" |
| 3 | `@utils.escalate` on employee agent | Requires `connection messaging:` (service-agent-only) |
| 4 | Paragraph prose in `reasoning.instructions:` | LLM controllability poor -- use condition-based `if @variables.X:` |
| 5 | Boolean `true` / `false` (lowercase) | Compile error |
| 6 | `mutable string = ...` | `...` is slot-fill syntax, not a default value |
| 7 | `mutable <type>` with no `= <default>` | Compile error -- every mutable needs a default |
| 8 | `linked string = "x"` | linked has no default -- only `source:` |
| 9 | `linked list[string]` / `linked object` | linked cannot wrap collections or objects |
| 10 | `@utils.transition to` in `after_reasoning:` or `instructions: ->` | Wrong context -- use bare `transition to` |
| 11 | bare `transition to` in `reasoning.actions:` | Wrong context -- use `@utils.transition to` |
| 12 | `@inputs.x` in a `set` directive | Silent runtime failure |
| 13 | `else if` | Not supported -- use compound `if x and y:` or sequential `if` blocks |
| 14 | `number` on action I/O | Fails at publish -- use `object` + `complex_data_type_name` |
| 15 | Bare action name (no `@actions.`) in `run` or `{!...}` | Resolution failure |
| 16 | `run @actions.X` where X is a `@utils.setVariables` only | `run` resolves against subagent-level `actions:`, not reasoning-level utilities |
| 17 | Action definition without `outputs:` block | Publish fails with "Internal Error" (Issue #15) |
| 18 | Two consecutive underscores in any name | Compile error |
| 19 | Transition action without its own `description:` | LLM can't pick correctly |
| 20 | Comment-only body inside an `if` block | Parser strips comments -> empty body -> silent no-op (Issue #19) |
| 21 | `before_reasoning:`/`after_reasoning:` with an `instructions:` wrapper | Wrong structure -- content goes DIRECTLY under the block |
| 22 | `<>` as inequality operator | Use `!=` |
| 23 | `connections:` (plural wrapper) block | Must be `connection messaging:` (singular, standalone) -- Issue #16 |
| 24 | `outbound_route_name: "Flow_Name"` (no prefix) | Must be `"flow://Flow_Name"` -- bare name causes `ERROR_HTTP_404` on publish |
| 25 | Variable `{!@variables.x}` interpolation in `system.messages.welcome` | Runtime renders before variables exist (Issue #11) |

---

## 14. Validation Checklist (Pre-Validate Mental Model)

Before running `sf agent validate authoring-bundle`, verify:

- [ ] Block order: `system` -> `config` -> `variables` -> ... -> `start_agent` -> `subagent`
- [ ] `config.developer_name` present, matches directory + filename exactly
- [ ] `system.messages.welcome`, `system.messages.error`, `system.instructions` all present
- [ ] `start_agent` block has `description:` and at least one transition action
- [ ] Each `subagent:` has `description:` and `reasoning:`
- [ ] All `mutable` variables have default values
- [ ] All `linked` variables have `source:` and NO default
- [ ] All boolean literals are `True` / `False`
- [ ] Every action target uses a valid prefix (`apex://`, `flow://`, `prompt://`, ...)
- [ ] Every action definition has an `outputs:` block (Issue #15)
- [ ] No `agent_name:` anywhere
- [ ] No `else if`, no `<>`
- [ ] Indentation is consistent (3 spaces, no tabs)
- [ ] Every transition action in `reasoning.actions:` has its own `description:`
- [ ] Employee agents have no `default_agent_user`, no `connection messaging:`, no MessagingSession linked vars, no `@utils.escalate`
- [ ] Numeric action I/O uses `object` + `complex_data_type_name` (target-correct value)

---

## 15. Common AI Mistakes to Avoid

| # | Mistake | Correct approach |
|---|---|---|
| 1 | Using `agent_name:` in `config:` | `developer_name:` -- canonical. `agent_name` is rejected. |
| 2 | Writing reasoning as paragraph prose | `instructions: ->` with `if @variables.X:` condition blocks. Prose only inside `\|` lines. |
| 3 | Lowercase `true`/`false` | Capitalized `True`/`False` |
| 4 | `mutable string = ...` (slot-fill as default) | `mutable string = ""` |
| 5 | `linked` variable with default OR no `source` | linked needs `source:` and no default |
| 6 | `@utils.transition to` in `after_reasoning:` | Bare `transition to` for deterministic contexts |
| 7 | Bare `transition to` in `reasoning.actions:` | `@utils.transition to @subagent.X` for LLM-selected |
| 8 | Bare action name in `run` or template | Always `@actions.<name>` |
| 9 | `else if` | Split into separate `if` or compound `if x and y:` |
| 10 | `number` on action I/O | `object` + `complex_data_type_name` (use `lightning__integerType` for apex, `lightning__numberType` for flow) |
| 11 | Action definition without `outputs:` | Always include `outputs:` -- publish fails otherwise (Issue #15) |
| 12 | Comment-only body in `if` block | Always include at least one `|`/`set`/`run`/`transition` (Issue #19) |
| 13 | `default_agent_user` on EmployeeAgent | Omit entirely on EmployeeAgent |
| 14 | `instructions:` wrapper inside `before_reasoning:` / `after_reasoning:` | Content goes DIRECTLY under the block |

---

## 16. Empirical Findings & Implementation Notes

When Salesforce's documented approach doesn't work in the target environment, the workaround goes here. Date-stamp every entry.

| # | Date | Documented approach | What actually works | Why / Context |
|---|---|---|---|---|
| 1 | 2026-05-15 | `date` is a first-class scalar variable type for datetime values | For an action output that Apex returns as `Datetime`, `sf agent retrieve` writes it back as `type: object` + `complex_data_type_name: "lightning__dateTimeStringType"`. Both compile and deploy at API v66.0. The retrieved form round-trips correctly but is the wrong form for new authoring | Observed in `Example_Service_Agent.agent` and `Example_Refund_Agent_v2.agent` on 2026-05-15 (<target-env-alias>, Spring '26 / v66.0). Standardise NEW authoring on `type: date`; accept the `object + complex_data_type_name` form when retrieved |
| 2 | 2026-05-15 | `id` is a first-class scalar type for Salesforce record IDs | Three idioms exist in the target environment's bundles for the same semantic: (a) `type: string`; (b) `type: id` (canonical); (c) `type: object` + `complex_data_type_name: "lightning__recordIdType"`. Form (c) is what `sf agent retrieve` writes back | Standardise NEW authoring on form (b); accept form (c) when retrieved |
| 3 | 2026-05-16 | Salesforce Agentforce Employee Agent Builder UI documentation prescribes per-topic `SCOPE`, `INSTRUCTIONS`, `GUARDRAILS`, `USER INPUT EXAMPLES` | The `.agent` DSL has no separate `scope:` or `guardrails:` keys. Convention: Classification + Scope -> `subagent.description:`; Instructions -> `reasoning.instructions:`; Guardrails -> trailing `\| GUARDRAILS:` block; User Input Examples -> `start_agent` transition `description:` strings | Builder UI structure doesn't map 1:1 to DSL keys |
| 4 | 2026-05-15 | Some sketches imply a `contains` (substring-match) operator in `->` blocks | No `contains` operator exists. Documented operators only: `==`, `!=`, `<`, `<=`, `>`, `>=`, `is`, `is not`, `and`, `or`, `not`. Use LLM-mediated routing instead | Discovered while authoring an example two-mode router on <target-env-alias>, Spring '26 |
| 5 | 2026-05-16 | Live SF Help pages (`help.salesforce.com`) render via JavaScript | WebFetch returns CSS error / empty body. The canonical body of knowledge lives in `developer.salesforce.com/docs/ai/agentforce/guide/*` plus the `forcedotcom/sf-skills` and `trailheadapps/agent-script-recipes` repos -- both deeper than the live Help pages | Browse the cloned repos for ground truth. WebFetch the developer.salesforce.com doc pages with very targeted prompts; expect the small summarization model to return partial content -- use multiple passes per page |
| 6 | 2026-05-16 | `type: id` is canonical for record-Id action inputs across all action targets per Section 6 type matrix and Finding #2 above | `type: id` is accepted ONLY for `apex://` targets (Apex `Id` is a String subtype and tolerates the agent's `id` declaration). For `flow://` targets, the input type MUST match the Flow variable's declared type -- typically `type: string` for record-Id Text variables. The Atlas Reasoning Engine validates Flow input contracts at `sf agent preview start --use-live-actions` session-start time and rejects mismatches with `PreviewStartFailed: Validation failed for action 'X' due to invalid data type for the input parameter 'Y'. To fix, update the data type to 'object' type and 'complex_data_type_name' to 'lightning__textType'`. The legacy `Example_Service_Agent` used `type: string` on `Example_Flow_Action.recordId` (flow target) and worked; a rebuild that standardised on `type: id` broke at first live-preview attempt | Discovered during `Example_Agent` cutover testing on <target-env-alias>, Spring '26 / API v66.0. The Empirical Finding #2 recommendation to standardise on `type: id` applies to Apex targets only -- Flow targets must match the Flow's variable type. Updated the flow-target input to `string`; remaining `apex://` action inputs stay on `type: id` |
| 7 | 2026-05-16 | `sf agent preview send --json --authoring-bundle <Name>` returns the agent's final response in `result.messages[].message` | For a multi-step subagent (router -> subagent -> action loop), the CLI's `messages` array contains ONLY the first post-transition LLMStep response. Subsequent reasoning iterations (FunctionStep action calls, additional LLMSteps, final PlannerResponseStep summary) are NOT aggregated into the CLI's `messages` payload. Trace inspection shows `tool_invocations: null` on the first subagent LLMStep even when later iterations (visible only in raw trace JSON or Builder UI) DO invoke actions and produce the final answer. This produced a false-negative "agent didn't call action" QA verdict during an example cutover that was later disproved by Builder UI test + platform-path verification (`<email-message-id>` on `<case-id>`, image OCR extraction returned a canonical confirmation code, full external-provider callout success). **Use Agentforce Builder UI OR a real Apex `Agent.generateAiAgentResponse` invocation for end-to-end functional validation. CLI `preview send` is a session-debugger surface, not a functional-test surface** | Platform-path verification on <target-env-alias> 2026-05-16 confirmed the example agent works end-to-end after CLI false-negative reports; the empirical lesson is the CLI's response-aggregation limitation |

---

## 17. Official References

- [Agent Script Developer Guide](https://developer.salesforce.com/docs/ai/agentforce/guide/agent-script.html)
- [Agent Script Blocks](https://developer.salesforce.com/docs/ai/agentforce/guide/ascript-blocks.html)
- [Reference Index](https://developer.salesforce.com/docs/ai/agentforce/guide/ascript-reference.html)
- [Language Characteristics](https://developer.salesforce.com/docs/ai/agentforce/guide/ascript-lang.html)
- [Actions Reference](https://developer.salesforce.com/docs/ai/agentforce/guide/ascript-ref-actions.html)
- [Agent Script Decoded -- blog](https://developer.salesforce.com/blogs/2026/02/agent-script-decoded-intro-to-agent-script-language-fundamentals)
- [Agentforce DX -- Code Your Agent](https://developer.salesforce.com/docs/ai/agentforce/guide/agent-dx-nga-script.html)
- [trailheadapps/agent-script-recipes](https://github.com/trailheadapps/agent-script-recipes) -- 30+ working `.agent` files
- [forcedotcom/sf-skills `developing-agentforce`](https://github.com/forcedotcom/sf-skills/tree/main/skills/developing-agentforce) -- complete reference library

---

*Agent Script Canonical Reference | v3.0 | Last verified 2026-05-16*

