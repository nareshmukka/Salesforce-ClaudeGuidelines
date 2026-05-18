# Agent Script — Canonical DSL Reference

Authoritative grammar for `.agent` files in this project. Other Agentforce skill files reference this one.

**Verified against:** [Agent Script Developer Guide](https://developer.salesforce.com/docs/ai/agentforce/guide/agent-script.html) · [Agent Script Blocks](https://developer.salesforce.com/docs/ai/agentforce/guide/ascript-blocks.html) · [Language Characteristics](https://developer.salesforce.com/docs/ai/agentforce/guide/ascript-lang.html) · [Actions Reference](https://developer.salesforce.com/docs/ai/agentforce/guide/ascript-ref-actions.html) · [Reference Index](https://developer.salesforce.com/docs/ai/agentforce/guide/ascript-reference.html) · [Agent Script Decoded (blog)](https://developer.salesforce.com/blogs/2026/02/agent-script-decoded-intro-to-agent-script-language-fundamentals) · [trailheadapps/agent-script-recipes](https://github.com/trailheadapps/agent-script-recipes) (30+ working `.agent` files) · [forcedotcom/sf-skills `developing-agentforce`](https://github.com/forcedotcom/sf-skills/tree/main/skills/developing-agentforce) (complete reference library). Last verified 2026-05-16.

> **April 2026 rename:** "topics" are now called **subagents**. Functionality unchanged. Use `subagent` in all new authoring.

---

## 1. File Layout

A script-version agent lives in one directory:

```
force-app/main/default/aiAuthoringBundles/<Developer_Name>/
   <Developer_Name>.agent              # Agent Script source
   <Developer_Name>.bundle-meta.xml    # Metadata wrapper
```

`<Developer_Name>.bundle-meta.xml` — minimal valid form:

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
4. connection messaging:    optional (singular, standalone — service agents only)
5. knowledge:               optional
6. language:                optional
7. start_agent <id>:        required — the router
8. subagent <id>:           one or more required
```

> Note: many working recipes (trailheadapps) put `config:` first. Both forms compile. **Use `system:` first** per the forcedotcom canonical order — the platform's own skill library follows it.

**Internal order within `start_agent` and `subagent`:**
1. `description:` (required)
2. `label:` (optional display)
3. `system:` (optional override of global)
4. `before_reasoning:` (optional)
5. `reasoning:` (required)
6. `after_reasoning:` (optional)
7. `actions:` (optional — subagent-level definitions)

---

## 3. Syntax Fundamentals

| Element | Rule |
|---|---|
| Indentation | 3 spaces per level (or 4 — be consistent). Never tabs. Never mix. |
| Booleans | `True` / `False` only. Lowercase `true`/`false` fails. |
| Strings | Always double-quoted. |
| Comments | `#` to end of line. No multi-line syntax. **Never use comments alone as an `if`/`else` body — the parser strips them and the block becomes an empty no-op.** |
| Procedural opener | `->` after a key (`instructions: ->`) — deterministic logic |
| Prompt opener | `|` after a key, or inside a `->` block — LLM prompt text |
| Template interpolation | `{!@variables.x}` — only inside prompt text |
| Slot-fill placeholder | `...` — only valid as an action input value (never as a variable default) |
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

`else if` is **not** supported. Use compound `if x and y:` or sequential flat `if` blocks. `<>` is invalid — use `!=`.

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
      You are a server-invoked email-analysis specialist for Plusgrade.
      Ground every output in Get_Email_Resend_Context outputs — never invent
      Case data, customer email content, or email history.
      Return JSON only when in STRUCTURED_ANALYSIS mode.
   messages:
      welcome: "Ready."                          # REQUIRED — first message of conversation
      error: "Operation cancelled for safety."    # REQUIRED — fallback on internal failure
```

A subagent can override `system.instructions` with its own `system:` block inside the subagent.

**Welcome-message gotchas (Issues #11, #12):**
- `{!@variables.x}` interpolation does NOT work in the welcome message — runtime renders welcome before variables initialize. Use a static welcome.
- Line breaks in welcome are stripped. Keep welcome single-line; put multi-line greetings in the first subagent's `instructions:`.

---

## 5. `config:` Block

```
config:
   developer_name: "Email_Analysis_Agent"          # REQUIRED — API name. Must match directory + filename exactly.
   agent_label: "Email Analysis Agent"             # Optional display name
   description: "Server-invoked agent that analyzes inbound support emails..."
   role: "AI assistant for Plusgrade support reps."
   company: "Plusgrade — global airline/hotel loyalty programs operating across 30+ markets, partnering with major carriers and hotel groups."
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
   # mutable — read+write. MUST have a default value.
   case_id: mutable id = ""
      description: "Salesforce Case Id this conversation is anchored to"

   confirmation_from_body: mutable string = ""
      description: "Confirmation code captured from the email body"

   context_loaded: mutable boolean = False

   history_items: mutable list[object] = []

   # linked — read-only. MUST have a `source:`. MUST NOT have a default.
   session_id: linked string
      description: "Session ID injected by the runtime"
      source: @session.sessionID
```

**Type vs modifier matrix**

| Type | mutable | linked | action I/O |
|---|:-:|:-:|:-:|
| `string` | ✓ | ✓ | ✓ |
| `number` | ✓ | ✓ | ✓ (with caveat — see §9) |
| `boolean` | ✓ | ✓ | ✓ |
| `id` | ✓ | ✓ | ✓ |
| `date` | ✓ | ✓ | ✓ |
| `currency` | ✓ | ✓ | ✓ |
| `timestamp` | compiles but absent from GA docs — avoid | | |
| `object` | ✓ | ✗ | ✓ |
| `list[T]` | ✓ | ✗ | ✓ |
| `integer`, `long`, `datetime`, `time` | ✗ | ✗ | ✓ |

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

## 7. `start_agent <router_id>:` Block — The Router

The `start_agent` IS the router. **Do not create a separate routing subagent** — that adds an LLM hop (~3-5s latency) and confuses the planner.

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

Every transition action MUST have its own `description:` — that's the only signal the LLM uses to pick.

---

## 8. `subagent <id>:` Block

```
subagent structured_analysis:
   label: "Structured Analysis"
   description: "Analyze an inbound email and return JSON for the LWC parser"

   # Optional — override system.instructions for this subagent only
   system:
      instructions: |
         You are an email-analysis specialist. Return JSON only.

   # Subagent-level action definitions — declare inputs/outputs/target
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

   # Reasoning — condition-based steps + LLM-available actions
   reasoning:
      instructions: ->
         # STEP 1 — Load context if not yet loaded
         if @variables.context_loaded == False:
            | Load the Case and EmailMessage using {!@actions.get_context}.

         # STEP 2 — Body parse
         if @variables.context_loaded == True and @variables.confirmation_from_body == "":
            | Scan the email body for the canonical 5-group code
              xxxx-xxxx-xxxx-xxxx-xxxx (alphanumeric, hyphens/no-hyphens/spaces accepted).
              Save the captured value via {!@actions.set_confirmation_from_body}.

         # STEP 3 — Image OCR fallback when body has no code
         if @variables.context_loaded == True and @variables.confirmation_from_body == "":
            | Fall back to {!@actions.get_image_confirmation} for embedded-image OCR.

         # STEP 4 — Return JSON contract
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

   # Optional — deterministic step AFTER the LLM's reasoning loop
   after_reasoning:
      # Content goes DIRECTLY here. NO `instructions:` wrapper.
      if @variables.context_loaded == True and @variables.confirmation_from_body == "":
         transition to @subagent.exit_summary
```

### Reasoning grammar

- `instructions: ->` opens a **procedural** block: deterministic. `if`, `set`, `run`, `transition to`, and `| <prompt line>` are all valid inside.
- `instructions: |` opens a **prompt-only** block: the entire body goes to the LLM verbatim. Logic is not allowed.
- Inside a `->` block, `| <line>` lines are conditional prompt fragments — they're appended to the LLM's prompt only when their enclosing `if` is True.
- A bare line continuation (no leading `|`) extends the previous `| <line>`.

### `reasoning.actions` — what the LLM can invoke

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

      # Conditional availability — LLM only sees this action when the gate is True
      admin_op: @actions.admin_function
         available when @variables.user_role == "admin"
```

### Utility shortcuts (only in `reasoning.actions`)

| Utility | Behavior |
|---|---|
| `@utils.transition to @subagent.X` | **Handoff** — child takes over completely and generates the user-facing reply |
| `@utils.escalate` | Route to human (service agents only; needs `connection messaging:`) |
| `@utils.setVariables` | LLM sets variables from conversation slots |
| `@subagent.X` (without `transition to`) | **Supervision** — child runs, returns control to parent, parent synthesizes |

**Handoff vs Supervision** is a critical distinction. Handoff is one-way; supervision returns.

---

## 9. Action Definitions — Targets & Types

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
| `require_user_confirmation:` (bool — runtime no-op per Issue #6) | `is_user_input:` (bool — LLM extracts from convo) | `filter_from_agent:` (bool — hide from LLM) |
| `include_in_progress_indicator:` (bool) | `complex_data_type_name:` | `is_used_by_planner:` (bool — let LLM reason about it) |
| `progress_indicator_message:` (string) | | `complex_data_type_name:` |

**`outputs:` block is REQUIRED** — Issue #15: subagent-level action definitions without an `outputs:` block fail at publish with "Internal Error, try again later". CLI validate passes but publish fails.

### Numeric output gotcha — target-dependent

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
| `lightning__dateTimeStringType` | DateTime returned as ISO string (preferred — `lightning__dateTimeType` per upstream docs but `lightning__dateTimeStringType` is the tested value) |
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
# WRONG — snake_case doesn't match @InvocableVariable venueName
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

## 10. Transition Syntax — Context-Sensitive

| Context | Syntax |
|---|---|
| Inside `reasoning.actions:` (LLM picks) | `name: @utils.transition to @subagent.X` |
| Inside `instructions: ->`, `before_reasoning:`, `after_reasoning:` (deterministic) | bare `transition to @subagent.X` |

Mixing the two = parser error.

`before_reasoning:` and `after_reasoning:` content goes DIRECTLY under the block — no `instructions:` wrapper.

---

## 11. Lifecycle — From Source to Live Agent

| Phase | Command | What it does |
|---|---|---|
| Generate | `sf agent generate authoring-bundle --json --no-spec --name "<Label>" --api-name <Dev_Name>` | Create `.agent` + `.bundle-meta.xml` locally |
| Validate | `sf agent validate authoring-bundle --json --api-name <Dev_Name>` | Syntax + structure check (does NOT contact the org) |
| Deploy | `sf project deploy start --json --metadata AiAuthoringBundle:<Dev_Name>` | Push authoring bundle to org. Authoring domain only. |
| Publish | `sf agent publish authoring-bundle --json --api-name <Dev_Name>` | Compile + create Bot + BotVersion + GenAiPlannerBundle. Self-contained — no prior deploy needed. |
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

**Service-agent gotcha — `EinsteinAgentApiChannel` not auto-generated:** the `connection messaging:` block only produces a `Messaging` plannerSurface. `CustomerWebClient` is dropped on every publish. Patch the GenAiPlannerBundle after each publish (see Issue #18).

---

## 12. Architecture Patterns (FSM)

| Pattern | Use when |
|---|---|
| Hub-and-Spoke | Two or more distinct subagents with different intents. Most common. |
| Verification Gate | Sensitive data / payments / PII require identity verification first |
| Post-Action Loop | An action's output drives follow-up logic that needs to re-evaluate |
| Single Subagent | One focused purpose, no routing |

**Hub-and-Spoke:** `start_agent` routes to N spoke subagents. Each spoke has a "back to hub" transition: `@utils.transition to @subagent.agent_router`. Routing lives in `start_agent` — never duplicate it into a `main_menu` subagent.

**Verification Gate:** protected subagents use `available when @variables.is_verified == True` on their entry transitions.

**Post-Action Loop:** put post-action checks at the TOP of `instructions: ->`. The runtime re-resolves the block after the action completes.

---

## 13. Anti-Patterns (Compile or Runtime Failures)

| # | Anti-pattern | Why it fails |
|---|---|---|
| 1 | `agent_name:` in `config:` | Field doesn't exist — use `developer_name:` |
| 2 | `default_agent_user` on `AgentforceEmployeeAgent` | Publish fails with cryptic "Internal Error, try again later" |
| 3 | `@utils.escalate` on employee agent | Requires `connection messaging:` (service-agent-only) |
| 4 | Paragraph prose in `reasoning.instructions:` | LLM controllability poor — use condition-based `if @variables.X:` |
| 5 | Boolean `true` / `false` (lowercase) | Compile error |
| 6 | `mutable string = ...` | `...` is slot-fill syntax, not a default value |
| 7 | `mutable <type>` with no `= <default>` | Compile error — every mutable needs a default |
| 8 | `linked string = "x"` | linked has no default — only `source:` |
| 9 | `linked list[string]` / `linked object` | linked cannot wrap collections or objects |
| 10 | `@utils.transition to` in `after_reasoning:` or `instructions: ->` | Wrong context — use bare `transition to` |
| 11 | bare `transition to` in `reasoning.actions:` | Wrong context — use `@utils.transition to` |
| 12 | `@inputs.x` in a `set` directive | Silent runtime failure |
| 13 | `else if` | Not supported — use compound `if x and y:` or sequential `if` blocks |
| 14 | `number` on action I/O | Fails at publish — use `object` + `complex_data_type_name` |
| 15 | Bare action name (no `@actions.`) in `run` or `{!...}` | Resolution failure |
| 16 | `run @actions.X` where X is a `@utils.setVariables` only | `run` resolves against subagent-level `actions:`, not reasoning-level utilities |
| 17 | Action definition without `outputs:` block | Publish fails with "Internal Error" (Issue #15) |
| 18 | Two consecutive underscores in any name | Compile error |
| 19 | Transition action without its own `description:` | LLM can't pick correctly |
| 20 | Comment-only body inside an `if` block | Parser strips comments → empty body → silent no-op (Issue #19) |
| 21 | `before_reasoning:`/`after_reasoning:` with an `instructions:` wrapper | Wrong structure — content goes DIRECTLY under the block |
| 22 | `<>` as inequality operator | Use `!=` |
| 23 | `connections:` (plural wrapper) block | Must be `connection messaging:` (singular, standalone) — Issue #16 |
| 24 | `outbound_route_name: "Flow_Name"` (no prefix) | Must be `"flow://Flow_Name"` — bare name causes `ERROR_HTTP_404` on publish |
| 25 | Variable `{!@variables.x}` interpolation in `system.messages.welcome` | Runtime renders before variables exist (Issue #11) |

---

## 14. Validation Checklist (Pre-Validate Mental Model)

Before running `sf agent validate authoring-bundle`, verify:

- [ ] Block order: `system` → `config` → `variables` → ... → `start_agent` → `subagent`
- [ ] `config.developer_name` present, matches directory + filename exactly
- [ ] `system.messages.welcome`, `system.messages.error`, `system.instructions` all present
- [ ] `start_agent` block has `description:` and at least one transition action
- [ ] Each `subagent:` has `description:` and `reasoning:`
- [ ] All `mutable` variables have default values
- [ ] All `linked` variables have `source:` and NO default
- [ ] All boolean literals are `True` / `False`
- [ ] Every action target uses a valid prefix (`apex://`, `flow://`, `prompt://`, …)
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
| 1 | Using `agent_name:` in `config:` | `developer_name:` — canonical. `agent_name` is rejected. |
| 2 | Writing reasoning as paragraph prose | `instructions: ->` with `if @variables.X:` condition blocks. Prose only inside `\|` lines. |
| 3 | Lowercase `true`/`false` | Capitalized `True`/`False` |
| 4 | `mutable string = ...` (slot-fill as default) | `mutable string = ""` |
| 5 | `linked` variable with default OR no `source` | linked needs `source:` and no default |
| 6 | `@utils.transition to` in `after_reasoning:` | Bare `transition to` for deterministic contexts |
| 7 | Bare `transition to` in `reasoning.actions:` | `@utils.transition to @subagent.X` for LLM-selected |
| 8 | Bare action name in `run` or template | Always `@actions.<name>` |
| 9 | `else if` | Split into separate `if` or compound `if x and y:` |
| 10 | `number` on action I/O | `object` + `complex_data_type_name` (use `lightning__integerType` for apex, `lightning__numberType` for flow) |
| 11 | Action definition without `outputs:` | Always include `outputs:` — publish fails otherwise (Issue #15) |
| 12 | Comment-only body in `if` block | Always include at least one `|`/`set`/`run`/`transition` (Issue #19) |
| 13 | `default_agent_user` on EmployeeAgent | Omit entirely on EmployeeAgent |
| 14 | `instructions:` wrapper inside `before_reasoning:` / `after_reasoning:` | Content goes DIRECTLY under the block |

---

## 16. Empirical Findings & Implementation Notes

When Salesforce's documented approach doesn't work in this org, the workaround goes here. Date-stamp every entry.

| # | Date | Documented approach | What actually works | Why / Context |
|---|---|---|---|---|
| 1 | 2026-05-15 | `date` is a first-class scalar variable type for datetime values | For an action output that Apex returns as `Datetime`, `sf agent retrieve` writes it back as `type: object` + `complex_data_type_name: "lightning__dateTimeStringType"`. Both compile and deploy at API v66.0. The retrieved form round-trips correctly but is the wrong form for new authoring | Observed in `Email_Resend_Agent.agent` and `UnitedMiles_Refund_Agent_v2.agent` on 2026-05-15 (FullSB, Spring '26 / v66.0). Standardise NEW authoring on `type: date`; accept the `object + complex_data_type_name` form when retrieved |
| 2 | 2026-05-15 | `id` is a first-class scalar type for Salesforce record IDs | Three idioms exist in this org's bundles for the same semantic: (a) `type: string`; (b) `type: id` (canonical); (c) `type: object` + `complex_data_type_name: "lightning__recordIdType"`. Form (c) is what `sf agent retrieve` writes back | Standardise NEW authoring on form (b); accept form (c) when retrieved |
| 3 | 2026-05-16 | Salesforce Agentforce Employee Agent Builder UI documentation prescribes per-topic `SCOPE`, `INSTRUCTIONS`, `GUARDRAILS`, `USER INPUT EXAMPLES` | The `.agent` DSL has no separate `scope:` or `guardrails:` keys. Convention: Classification + Scope → `subagent.description:`; Instructions → `reasoning.instructions:`; Guardrails → trailing `\| GUARDRAILS:` block; User Input Examples → `start_agent` transition `description:` strings | Builder UI structure doesn't map 1:1 to DSL keys |
| 4 | 2026-05-15 | Some sketches imply a `contains` (substring-match) operator in `->` blocks | No `contains` operator exists. Documented operators only: `==`, `!=`, `<`, `<=`, `>`, `>=`, `is`, `is not`, `and`, `or`, `not`. Use LLM-mediated routing instead | Discovered while authoring `Email_Analysis_Agent` two-mode router on PlusGradeFullSB, Spring '26 |
| 5 | 2026-05-16 | Live SF Help pages (`help.salesforce.com`) render via JavaScript | WebFetch returns CSS error / empty body. The canonical body of knowledge lives in `developer.salesforce.com/docs/ai/agentforce/guide/*` plus the `forcedotcom/sf-skills` and `trailheadapps/agent-script-recipes` repos — both deeper than the live Help pages | Browse the cloned repos for ground truth. WebFetch the developer.salesforce.com doc pages with very targeted prompts; expect the small summarization model to return partial content — use multiple passes per page |
| 6 | 2026-05-16 | `type: id` is canonical for record-Id action inputs across all action targets per §6 type matrix and Finding #2 above | `type: id` is accepted ONLY for `apex://` targets (Apex `Id` is a String subtype and tolerates the agent's `id` declaration). For `flow://` targets, the input type MUST match the Flow variable's declared type — typically `type: string` for record-Id Text variables. The Atlas Reasoning Engine validates Flow input contracts at `sf agent preview start --use-live-actions` session-start time and rejects mismatches with `PreviewStartFailed: Validation failed for action 'X' due to invalid data type for the input parameter 'Y'. To fix, update the data type to 'object' type and 'complex_data_type_name' to 'lightning__textType'`. The legacy `Email_Resend_Agent` v15 used `type: string` on `Get_Image_Confirmation.emailMessageId` (flow target) and worked; the v2-v5 rebuild standardised on `type: id` and broke at first live-preview attempt | Discovered during `Email_Analysis_Agent` v5→v6 cutover testing on PlusGradeFullSB, Spring '26 / API v66.0. The Empirical Finding #2 recommendation to standardise on `type: id` applies to Apex targets only — Flow targets must match the Flow's variable type. Updated v6 to `string` on the one flow-target input; remaining `apex://` action inputs stay on `type: id` |
| 7 | 2026-05-16 | `sf agent preview send --json --authoring-bundle <Name>` returns the agent's final response in `result.messages[].message` | For a multi-step subagent (router → subagent → action loop), the CLI's `messages` array contains ONLY the first post-transition LLMStep response. Subsequent reasoning iterations (FunctionStep action calls, additional LLMSteps, final PlannerResponseStep summary) are NOT aggregated into the CLI's `messages` payload. Trace inspection shows `tool_invocations: null` on the first subagent LLMStep even when later iterations (visible only in raw trace JSON or Builder UI) DO invoke actions and produce the final answer. This produced a false-negative "agent didn't call action" QA verdict during the Email_Analysis_Agent v6 cutover that was later disproved by Builder UI test + production trigger-path verification (EmailMessage 02sAs000007HOGPIA4 on Case 500As00000WAZa1IAH, image OCR extraction returned canonical confirmation code, full SFMC callout success). **Use Agentforce Builder UI OR a real Apex `Agent.generateAiAgentResponse` invocation for end-to-end functional validation. CLI `preview send` is a session-debugger surface, not a functional-test surface** | Production trigger-path verification on PlusGradeFullSB 2026-05-16 confirmed the v6 agent works end-to-end after CLI false-negative reports; the empirical lesson is the CLI's response-aggregation limitation |

---

## 17. Official References

- [Agent Script Developer Guide](https://developer.salesforce.com/docs/ai/agentforce/guide/agent-script.html)
- [Agent Script Blocks](https://developer.salesforce.com/docs/ai/agentforce/guide/ascript-blocks.html)
- [Reference Index](https://developer.salesforce.com/docs/ai/agentforce/guide/ascript-reference.html)
- [Language Characteristics](https://developer.salesforce.com/docs/ai/agentforce/guide/ascript-lang.html)
- [Actions Reference](https://developer.salesforce.com/docs/ai/agentforce/guide/ascript-ref-actions.html)
- [Agent Script Decoded — blog](https://developer.salesforce.com/blogs/2026/02/agent-script-decoded-intro-to-agent-script-language-fundamentals)
- [Agentforce DX — Code Your Agent](https://developer.salesforce.com/docs/ai/agentforce/guide/agent-dx-nga-script.html)
- [trailheadapps/agent-script-recipes](https://github.com/trailheadapps/agent-script-recipes) — 30+ working `.agent` files
- [forcedotcom/sf-skills `developing-agentforce`](https://github.com/forcedotcom/sf-skills/tree/main/skills/developing-agentforce) — complete reference library

---

*Agent Script Canonical Reference | v3.0 | Last verified 2026-05-16*
