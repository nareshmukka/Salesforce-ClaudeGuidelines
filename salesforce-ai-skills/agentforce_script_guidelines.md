# Agentforce Agent Script — Authoring Guidelines

How to write `.agent` files well. Pair with **[agentforce-agent-script-reference.md](agentforce-agent-script-reference.md)** for the DSL grammar and **[agentforce_authoring_bundle_guide.md](agentforce_authoring_bundle_guide.md)** for the lifecycle.

**Verified against** the same canonical sources. Last verified 2026-05-16.

---

## 1. Two Execution Phases — The Mental Model

Every reasoning turn has two phases. Understanding them is the prerequisite for writing good instructions.

**Phase 1 — Deterministic Resolution.** The runtime walks `instructions: ->` top to bottom. It evaluates `if`/`else`, executes `run @actions.X`, runs `set` directives, and accumulates matching `| <prompt line>` text into the LLM's prompt. The LLM is not involved yet.

**Phase 2 — LLM Reasoning.** The runtime hands the resolved prompt + the available `reasoning.actions` (as tools) to the LLM. The LLM decides what to do: call a tool, transition, escalate, or compose a text response. It CANNOT modify the prompt — it only reasons against what Phase 1 produced.

This split is the single most important rule:

> **Deterministic logic controls what the agent KNOWS. The LLM controls WHETHER and HOW to act on that knowledge.**

Whenever you can pre-compute something with conditions or actions, do it. Don't ask the LLM to "remember", "check", or "decide" — set the prompt to only contain what's relevant for this turn.

---

## 2. Condition-Based Instructions — Not Paragraph Prose

The single biggest authoring mistake is writing reasoning as flowing prose. The DSL exists to give you condition-based **steps** that compile into a turn-specific prompt.

### Anti-pattern (paragraph prose — DON'T)

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

### Canonical pattern (condition-based steps — DO)

```
reasoning:
   instructions: ->
      # STEP 1 — Ground context
      if @variables.context_loaded == False:
         | Load the Case and EmailMessage via {!@actions.get_context}.

      # STEP 2 — Parse confirmation from body
      if @variables.context_loaded == True and @variables.confirmation_from_body == "":
         | Scan the email body for the canonical 5-group code
           xxxx-xxxx-xxxx-xxxx-xxxx (alphanumeric, hyphens/no-hyphens/spaces accepted).
           Save the captured value via {!@actions.set_confirmation_from_body}.

      # STEP 3 — Fallback to image OCR if body empty
      if @variables.context_loaded == True and @variables.confirmation_from_body == "":
         | If the body has no code, run {!@actions.get_image_confirmation} for OCR.

      # STEP 4 — Return JSON when we have a code
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

## 3. Block Labels — Use the Canonical Names

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

`system.instructions` is the agent's constitution. Keep it 15–30 lines covering:

```
system:
   instructions: |
      ROLE
      You are a server-invoked email-analysis specialist for Plusgrade.

      GROUNDING
      Ground every output in the data returned by Get_Email_Resend_Context.
      Never invent Case data, customer email content, or email history.

      RETURN CONTRACT
      - STRUCTURED_ANALYSIS mode → ONLY the prescribed JSON. No markdown fence. No prose.
      - EMAIL_TEMPLATE mode → ONLY a plain-text email body. No JSON. No sign-off.

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
      round numbers. Do not address the customer ("Dear...") — this is
      server-invoked, there is no human in the loop.
```

Notes:
- Section headers (ROLE / GROUNDING / RETURN CONTRACT / DATA PRIVACY / FABRICATION / ERROR DEFAULT / WHAT NOT TO DO) are a Plusgrade convention — they help reviewers, the LLM happily reads them.
- Use **operational third-person** for server-invoked agents (no "ask the customer..." since there is no customer).
- For service agents, switch to **second-person imperative** ("Help the customer...", "Ask for their order number").
- Subagents can override with their own `system:` block when domain expertise differs.

### Role, company, description — write these properly

The `description`, `role`, and `company` fields in `config:` are not cosmetic. The LLM sees them. A two-word `role:` makes the agent generic; a focused one makes it useful.

```
config:
   description: "Server-invoked employee agent that analyzes inbound support emails (STRUCTURED_ANALYSIS mode) and drafts personalized reply emails from named templates (EMAIL_TEMPLATE mode). Clean rebuild of Email_Resend_Agent v15."
   role: "Senior support specialist for Plusgrade — fluent in airline/hotel loyalty redemption flows, frequent-flyer programs, and the canonical 20-character confirmation-code format (xxxx-xxxx-xxxx-xxxx-xxxx). Reads emails like a tier-2 agent who has seen the same 30 failure modes a hundred times."
   company: "Plusgrade — global airline/hotel loyalty solutions operating across 30+ markets in partnership with major carriers (United, JetBlue, Air Canada, Lufthansa) and hotel groups (Hilton, Hyatt, IHG). The core product is point-based redemption and ancillary-upsell tooling that integrates with carrier reservation systems via the Plusgrade platform."
```

Three sentences of company context costs nothing and meaningfully grounds the agent in the right vocabulary.

---

## 5. Variables — State That Matters

Use `variables:` to store anything that:
- Gates a step (`context_loaded`, `is_verified`, `template_loaded`)
- Was captured from a previous action (`case_subject`, `confirmation_from_body`)
- Came from the runtime (`session_id`, `user_role` — `linked`)

Don't use variables for:
- Constants — bake them into prompt text or use a Custom Metadata Type read by an action
- Things only one subagent needs that don't outlive that subagent — local instruction text is fine

```
variables:
   # Identity
   case_id: mutable id = ""
      description: "Case Id the conversation is anchored to (slot-filled from the request)"
   email_message_id: mutable id = ""
      description: "EmailMessage Id of the inbound email"

   # State machine flags
   mode: mutable string = "STRUCTURED_ANALYSIS"
      description: "STRUCTURED_ANALYSIS or EMAIL_TEMPLATE — router sets at hand-off"
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
- Every transition action MUST have its own `description:` — that's the only signal the LLM uses to pick.
- Add the trigger phrasing into the `description:` ("'Use the email template named ...'") so the LLM doesn't have to guess.
- Use `instructions: |` (prompt-only) — the router has no state, just classification.
- Do NOT define backing-logic actions in `start_agent` — they'd be visible to the planner from every subagent, polluting the action space.

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
         You are an email-analysis specialist. Return JSON only — no markdown, no prose.

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

   # Reasoning — condition-based steps
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
      description: "Classified intent — used for routing"
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

## 9. Transition Syntax — Context-Sensitive

| Context | Syntax |
|---|---|
| Inside `reasoning.actions:` (LLM picks) | `name: @utils.transition to @subagent.X` |
| Inside `instructions: ->`, `before_reasoning:`, `after_reasoning:` (deterministic) | bare `transition to @subagent.X` |

Mixing the two = parser error.

`@utils.transition to` is a **handoff** — the target subagent takes over completely and generates the user-facing reply.

`@subagent.X` (without `transition to`) is **supervision** — the target subagent runs, returns control to the parent, and the parent synthesizes the final response.

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

For server-invoked employee agents handling PII (like `Email_Analysis_Agent`):
- `<logPrivateConversationData>false</logPrivateConversationData>` re-asserted via override manifest after every publish
- `system.instructions` contains an explicit PII redaction policy
- Every backing-Apex SOQL uses `WITH USER_MODE`

---

## 11. Variable Hygiene

- Every `mutable` variable has a default value.
- Every `linked` variable has a `source:` and no default.
- `True` / `False` only (never lowercase).
- `...` only as a slot-fill placeholder for action inputs — never as a variable default.
- Description present for any variable the LLM may need to slot-fill.

---

## 12. Loop Prevention

The runtime has a built-in guardrail that breaks out of reasoning loops after ~3–4 iterations. To prevent unintended loops:

1. **Use `available when`** to hide actions once they've completed.
2. **Set a "done" variable** in the post-action `set` block and gate the action on its negation.
3. **In `reasoning.instructions:`**, explicitly tell the LLM what to do AFTER the action: "Do NOT call the action again — you have the result."

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
           confirm the order number and stop — do not call the action again.

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

## 13. Architecture Patterns — Quick Pick

| Pattern | Use when |
|---|---|
| **Hub-and-Spoke** | 2+ distinct intents. `start_agent` routes; each spoke has a "back to hub" transition. |
| **Verification Gate** | PII / payments / sensitive ops. `available when @variables.is_verified == True` on protected entries. |
| **Post-Action Loop** | An action's output gates the next prompt. Put post-action checks at the TOP of `instructions: ->`. |
| **Single Subagent** | One focused purpose, no routing. Skip the hub. |

Full code for each is in **[agentforce-agent-script-reference.md §12](agentforce-agent-script-reference.md)**.

---

## 14. Testing Strategy

1. **Validate**: `sf agent validate authoring-bundle --json --api-name <Name>` — syntax check.
2. **Live preview per subagent**: one utterance for each subagent based on its `description:` keywords.
3. **Trigger-utterance per action**: one utterance that should fire each key action.
4. **Off-topic utterance**: tests guardrails ("tell me a joke").
5. **Multi-turn pair**: tests subagent transitions ("Check my order" → "Actually I want to return it").
6. **Trace inspection**: read `traces/<PLAN_ID>.json` after each turn. Confirm subagent routing, action invocation, grounding.

Use `jq` to extract specific signals (transitions, actions called, grounding result) — full snippet library in **[agentforce_authoring_bundle_guide.md §10](agentforce_authoring_bundle_guide.md)**.

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
| 90–100 | Production-ready |
| 75–89 | Fix minor issues, then deploy |
| 60–74 | Structural rework needed |
| < 60 | BLOCK — major rewrite |

---

## 16. Anti-Patterns

| # | Anti-pattern | Why |
|---|---|---|
| 1 | Paragraph prose in `reasoning.instructions:` | LLM controllability poor; re-resolves identically every turn; re-entry repeats completed steps |
| 2 | Monolithic agent in one `start_agent` block with no subagents | Tools all visible everywhere; planner confused; cannot scope state |
| 3 | Welcome message with `{!@variables.x}` | Welcome renders before variables initialize — interpolation never resolves |
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
- [ ] 7-category safety review run — zero BLOCK findings
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
| 1 | 2026-05-15 | Salesforce Agentforce Employee Agent help-doc topic-instruction style uses second-person imperative ("Ask the customer…", "Say to the user…") | For server-invoked employee agents (no live conversation), the conversational style doesn't apply. Reframe in operational third-person: "Extract caseId from the user message", "Return JSON with these keys", "Do not include sign-off" | This org's server-invoked EmployeeAgents are programmatically called from Apex. The agent's messages never reach a human. Help-doc style assumes a user-facing copilot |
| 2 | 2026-05-16 | Welcome messages support `{!@variables.x}` template interpolation | Welcome message renderer runs BEFORE variables initialize. Interpolation literals appear in the rendered text. Use static welcome; put personalized greeting in the first subagent's `reasoning.instructions:` (Issue #11) | Discovered when a draft welcome string contained `{!@variables.case_id}` and shipped to a test session with literal `{!@variables.case_id}` text |
| 3 | 2026-05-16 | Welcome messages support multi-line content | Line breaks are stripped on render. Multi-line greetings must live in the first subagent's instructions (Issue #12) | |
| 4 | 2026-05-16 | The 7-section "constitution" header style (ROLE / GROUNDING / RETURN CONTRACT / DATA PRIVACY / FABRICATION / ERROR DEFAULT / WHAT NOT TO DO) is documented as best practice for agent `system.instructions` | The headers are a Plusgrade convention modeled on `Global_Care_Service_Agent_Script.agent`. They are NOT documented by Salesforce — but they compile fine as prose and make the agent's responsibilities reviewable. Keep them; new authoring matches the convention | |

---

## 19. Official References

- [Agent Script Developer Guide](https://developer.salesforce.com/docs/ai/agentforce/guide/agent-script.html)
- [Agent Script Decoded — blog](https://developer.salesforce.com/blogs/2026/02/agent-script-decoded-intro-to-agent-script-language-fundamentals)
- [forcedotcom/sf-skills `developing-agentforce`](https://github.com/forcedotcom/sf-skills/tree/main/skills/developing-agentforce) — full reference library
- [trailheadapps/agent-script-recipes](https://github.com/trailheadapps/agent-script-recipes) — 30+ working `.agent` files
- [Agent Script Canonical Reference](agentforce-agent-script-reference.md) — DSL grammar (this skill set)
- [Agentforce Authoring Bundle Guide](agentforce_authoring_bundle_guide.md) — lifecycle (this skill set)

---

*Agentforce Script Authoring Guidelines | v3.0 | Last verified 2026-05-16*
