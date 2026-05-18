---
name: salesforce-agentforce-builder
description: Production Salesforce AI skill for GenAiFunction/GenAiPlugin/topic/action metadata design.
license: Apache-2.0
compatibility:
  - Claude Code
  - Claude Agents
  - Codex / ChatGPT
  - GitHub Copilot
metadata:
  version: 2.0.0
  last_updated: 2026-05-16
  owner: Naresh Salesforce AI Skills Library
---

## TRIGGER when
- The task involves GenAiFunction/GenAiPlugin/topic/action metadata design.
- The user asks for implementation, refactor, troubleshooting, review, or best-practice validation in this area.
- The assistant must produce Salesforce-safe code/metadata with explicit security/testing notes.

## DO NOT TRIGGER when
- The task is unrelated to this component.
- Another specialized skill is the primary owner and this area is only incidental.
- The user asks for operational execution (deploy/publish/activate/destructive change) without explicit approval.

## Cross-skill routing
- Always read `../salesforce-global-development/SKILL.md`.
- Also read: Global Development + Agentforce Script + Deployment + Permissions.
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
Differentiate Builder metadata orchestration from Script behavior definitions. Keep reusable functions/plugins with stable contracts. Validate bindings between topics, actions, and referenced metadata names.

## Upstream Salesforce Skill Patterns
- Use Builder-oriented metadata work for existing Builder agents, `GenAiFunction`, `GenAiPlugin`, `GenAiPromptTemplate`, Models API, and Lightning type wiring.
- Switch to Agent Script / authoring-bundle ownership when the work creates or edits `.agent` files, deterministic flow control, script canvas output, or authoring-bundle lifecycle.
- Keep Builder topics, actions, prompt templates, and permission personas mapped explicitly so deployment and access troubleshooting are not guesswork.
- Validate action targets and prompt template contracts before publish. Builder UI success does not replace source review or live preview.
- For ServicePlanner or org-specific Service Assistant work, route to the Service Assistant skill before applying EmployeeAgent assumptions.

## Examples
### Good example patterns
1. Reusable GenAiFunction used across two topics with consistent input schema.
2. Builder metadata names versioned and mapped in deployment manifest.

### Bad examples / avoid
1. Renaming function without updating topic/action references.
2. Mixing builder metadata assumptions into script-only behavior without checks.

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

# Agentforce Builder " Agent Script Parity Guide

How the Agentforce Builder UI concepts map to `.agent` DSL, and when to use which authoring surface. Pair with **[../salesforce-agentforce-script/SKILL.md](../salesforce-agentforce-script/SKILL.md)**, **[../salesforce-agentforce-authoring-bundle/SKILL.md](../salesforce-agentforce-authoring-bundle/SKILL.md)**, and **[../salesforce-agentforce-script/SKILL.md](../salesforce-agentforce-script/SKILL.md)**.

**Verified against** the same canonical sources. Last verified 2026-05-16.

> **Direction of travel:** Agent Script (the `.agent` DSL inside an `AiAuthoringBundle`) is the recommended approach for all new agents. The older Builder-driven `GenAiPlannerBundle / GenAiPlugin / GenAiFunction` metadata layout still works but is **legacy**. This file documents both, with the script approach as the default.

---

## 1. Choose the Authoring Surface

| Authoring surface | When to use |
|---|---|
| **Agent Script (`.agent`)** -- `AiAuthoringBundle` | Default for all new work. Pro-code authoring, version-controlled source, deterministic logic + LLM prompts in one file. |
| **Builder Canvas view** | Low-code authoring on top of an existing authoring bundle. Useful for non-developer refinement. Saves back to the same `.agent` source. |
| **Builder Script view** | Direct in-browser edits of the `.agent` source with syntax highlighting, autocompletion, and validation. |
| **Builder GenAi***** **metadata** (legacy) | Only when extending an existing legacy agent not yet migrated to authoring bundles. Do not start new agents here. |

The Builder Canvas, Builder Script, and CLI all edit the **same** AiAuthoringBundle. Pro-code/low-code collaboration works via deploy/retrieve.

---

## 2. Builder UI Concepts -> DSL Concept Map

| Builder UI label | DSL element |
|---|---|
| Agent -> "API Name" | `config.developer_name` |
| Agent -> "Display Name" / "Label" | `config.agent_label` |
| Agent -> "Description" | `config.description` |
| Agent -> "Role" | `config.role` |
| Agent -> "Company" | `config.company` |
| Agent -> "Agent Type" (Service / Employee) | `config.agent_type` |
| Welcome message | `system.messages.welcome` |
| Error message | `system.messages.error` |
| Global system instructions | `system.instructions` |
| Topic (renamed Subagent April 2026) | `subagent <id>:` |
| Topic -> Description | `subagent.description` (Classification + Scope go here per DSL convention) |
| Topic -> Instructions | `subagent.reasoning.instructions` |
| Topic -> Guardrails | Trailing `\| GUARDRAILS:` block inside `reasoning.instructions:` |
| Topic -> User Input Examples | Transition `description:` strings in `start_agent` router |
| Action / Tool | `subagent.actions.<name>` block (definition) + `reasoning.actions.<alias>` (invocation) |
| Action -> Input | `inputs.<name>:` |
| Action -> Output | `outputs.<name>:` |
| Action -> Target | `target: "apex://X"` / `target: "flow://X"` / `target: "prompt://X"` |
| Action -> Available when | `available when <expr>` in `reasoning.actions.<alias>` |
| Variable | `variables.<name>` (mutable or linked) |
| Knowledge | `knowledge:` block (or per-subagent `knowledge:`) |
| Language settings | `language:` block |
| Connection (escalation) | `connection messaging:` (singular; service agents only) |
| Bot definition | Auto-created by `sf agent publish` (don't author by hand) |
| Bot Version | Auto-created per publish; never one BotVersion per topic |

**Topic ‰  Plugin.** In the legacy GenAiPlannerBundle metadata, each topic became its own `GenAiPlugin` file. In the new authoring bundle, all subagents live in one `.agent` file and become one compiled `GenAiPlannerBundle` at publish time.

---

## 3. Topic Spec -> DSL Translation

Builder's help text prescribes per-topic fields. Here's how to translate each into the DSL.

### Topic spec

| Builder field | What it means | Where it lives in the DSL |
|---|---|---|
| DESCRIPTION (Classification) | When does this topic apply? | `subagent.description:` |
| SCOPE | What's in / out of bounds? | First paragraph(s) of `subagent.description:` or `subagent.system.instructions:` |
| INSTRUCTIONS | Step-by-step what to do | `subagent.reasoning.instructions:` (condition-based) |
| GUARDRAILS | What NOT to do | Trailing `\| GUARDRAILS:` block in `reasoning.instructions:` |
| USER INPUT EXAMPLES | Sample user phrases that trigger this topic | `start_agent` router transition `description:` strings |

### Worked example

Builder UI for an "Email Template Drafting" topic:

```
DESCRIPTION:    Used when the customer wants to draft a reply email using a named template.
SCOPE:          Drafting plain-text reply bodies from named templates.
                Out of scope: STRUCTURED_ANALYSIS / JSON output / image OCR.
INSTRUCTIONS:   1. Load case context.
                2. Load the named template.
                3. If the template load fails, return a graceful fallback.
                4. Otherwise compose the reply body with the canonical
                   xxxx-xxxx-xxxx-xxxx-xxxx confirmation code rendered verbatim.
                5. Return plain-text body only (no JSON, no sign-off).
GUARDRAILS:     Never invent a template. Never invent customer data. Never
                output a sign-off line. Never wrap output in JSON.
USER INPUT EX:  "Use the email template named CONFIRMATION_RESEND"
                "Draft a reply using template REFUND_DENIED"
```

DSL translation:

```
subagent email_template_drafting:
   label: "Email Template Drafting"
   description: |
      Used when the customer wants to draft a reply email using a named template.
      Scope: composing plain-text reply bodies from named templates.
      Out of scope: STRUCTURED_ANALYSIS / JSON output / image OCR.

   reasoning:
      instructions: ->
         # STEP 1 -- Ground context
         if @variables.context_loaded == False:
            | Load the Case and EmailMessage via {!@actions.get_context}.

         # STEP 2 -- Load named template
         if @variables.context_loaded == True and @variables.template_loaded == False:
            | Load the email template named {!@variables.requested_template}
              via {!@actions.get_email_template}.

         # STEP 3 -- Graceful fallback on template failure
         if @variables.template_loaded == True and @variables.template_error_message != "":
            | The requested template could not be loaded
              ({!@variables.template_error_message}). Return a polite reply
              explaining the issue and asking the user to try again.

         # STEP 4 -- Compose body using template
         if @variables.template_loaded == True and @variables.template_error_message == "":
            | Compose the reply body using the loaded template. Render the
              confirmation code in canonical xxxx-xxxx-xxxx-xxxx-xxxx form. Do not
              invent values. Use action-output values verbatim.

         # GUARDRAILS
         | Never invent a template. Never invent customer data.
           Never output a sign-off line. Never wrap output in JSON.

      actions:
         get_context: @actions.get_context
            with caseId = @variables.case_id
            with emailMessageId = @variables.email_message_id
            set @variables.context_loaded = True

         get_email_template: @actions.get_email_template
            with templateName = @variables.requested_template
            set @variables.template_body = @outputs.body
            set @variables.template_error_message = @outputs.errorMessage
            set @variables.template_loaded = True
```

User Input Examples appear in the router's transition `description:`:

```
start_agent agent_router:
   reasoning:
      actions:
         go_email_template: @utils.transition to @subagent.email_template_drafting
            description: "Draft a reply using a named email template ('Use the email template named ...' / 'Draft a reply using template ...')"
```

---

## 4. Bot Metadata -- What Publish Creates vs What You Author

When `sf agent publish authoring-bundle` runs, the org creates these files in your local project (auto-retrieved):

```
bots/
   <Developer_Name>/
      <Developer_Name>.bot-meta.xml       # Bot definition (one per agent)
      v1.botVersion-meta.xml              # one per published version
genAiPlannerBundles/
   <Developer_Name>_v1/
      localActions/                       # subagent-scoped compiled actions
      <Developer_Name>_v1.genAiPlannerBundle
```

**You do NOT author these by hand.** They are compiled outputs.

**Important caveat:** every publish OVERWRITES `Bot.bot-meta.xml` with org defaults. Security-critical settings get reset:
- `<logPrivateConversationData>` -> `true` (the org default -- bad for PII)
- `<agentTemplate>` -> dropped
- `<contextVariables>` -> all 5 standard ones dropped

**Workaround:** deploy a Bot-only override manifest immediately after every publish -- see [../salesforce-agentforce-authoring-bundle/SKILL.md Section 8 salesforce-agentforce-authoring-bundle/SKILL.md).

---

## 5. The Legacy GenAi*** Metadata Layout (for Migration Context Only)

For brownfield work on agents not yet migrated to authoring bundles, here is how the old metadata layout maps:

| Old metadata type | What it held | New replacement |
|---|---|---|
| `Bot` | Container | Same (created by publish) |
| `BotVersion` | Per-version compiled metadata | Same (created by publish) |
| `GenAiPlannerBundle` | Compiled agent definition | Same -- auto-generated from `.agent` |
| `GenAiPlugin` | One file per topic | Compiled subagent inside the `.genAiPlannerBundle` |
| `GenAiFunction` | One file per action with target / inputs / outputs | Inline in the `.agent` file's `subagent.actions:` block |

Migration strategy:
1. Keep the old layout running.
2. Author a new `.agent` AiAuthoringBundle with the same `developer_name`.
3. Publish -- this creates a new BotVersion with the compiled bundle.
4. Activate the new version. Deactivate the old.
5. Delete the standalone `GenAiFunction` metadata via `destructiveChanges.xml` only AFTER grep confirms no other bundle's `<invocationTarget>` references it.

---

## 6. Builder vs CLI for Specific Operations

| Operation | Best surface |
|---|---|
| Create new agent | CLI: `sf agent generate authoring-bundle --json --no-spec --name "Label" --api-name Dev_Name` |
| Edit `.agent` | VS Code with Agent Script extension (preferred) or Builder Script view |
| Visual subagent map | Builder Canvas view |
| Validate syntax | CLI: `sf agent validate authoring-bundle --json --api-name Dev_Name` |
| Live preview during dev | CLI: `sf agent preview start --json --use-live-actions --authoring-bundle Dev_Name` |
| Production preview | Builder UI (test panel) or CLI: `sf agent preview start --json --api-name Bot_Name` |
| Read session traces | Local files at `.sfdx/agents/<Name>/sessions/<SessionId>/traces/` (Builder doesn't expose them) |
| Publish | CLI: `sf agent publish authoring-bundle --json --api-name Dev_Name` |
| Activate | CLI: `sf agent activate --json --api-name Bot_Name` or Builder UI toggle |
| Configure end-user access (permissions) | Builder UI for low-code; PermissionSet metadata via CLI for source control |

**VS Code Pull/Push from source tracking is NOT supported** for `AiAuthoringBundle`. The error reads `UnsupportedBundleTypeError`. Use `sf project retrieve start --metadata AiAuthoringBundle:<Name>` instead (Issue documented in known-issues).

---

## 7. Channel & Surface Configuration

After publish, an agent must be wired to a channel/surface to be accessible:

| Surface | When it's used |
|---|---|
| `Messaging` | Customer messaging channels (default for service agents) |
| `CustomerWebClient` | Web-based chat embed; required for Builder Preview |
| `Telephony` | Voice channels |
| `NextGenChat` | Newer chat surfaces |
| `EinsteinAgentApiChannel` | Direct Agent API; not available on all orgs (Issue #17) |

The `connection messaging:` DSL block generates only `Messaging`. **`CustomerWebClient` is NOT auto-generated** -- every publish drops any manually-added `CustomerWebClient` surface. The 6-step post-publish patch workflow:

1. `sf agent publish authoring-bundle --json --api-name <Name>`
2. `sf project retrieve start --json --metadata "GenAiPlannerBundle:<Name>_vNN"`
3. Manually add a second `<plannerSurfaces>` block to the XML with `<surfaceType>CustomerWebClient</surfaceType>` (copy the `Messaging` block, change surfaceType and surface fields)
4. `sf agent deactivate --json --api-name <Name>`
5. `sf project deploy start --json --metadata "GenAiPlannerBundle:<Name>_vNN"`
6. `sf agent activate --json --api-name <Name>`

This is Issue #18 -- required after every publish for agents that need Builder Preview or Agent Runtime API.

---

## 8. Permissions -- Who Can Run the Agent

Agents that call backing Apex/Flow inherit the running user's permissions.

**Service agents** run as the `default_agent_user` (Einstein Agent User):
- Assign the `AgentforceServiceAgentUser` system permission set
- Assign a custom `<AgentName>_Access` permission set with `<classAccesses>` for every Apex class across every subagent
- Do NOT rely on the auto-generated `NextGen_<AgentName>_Permissions` -- it is frequently incomplete

**Employee agents** run as the invoking user. Each employee needs:
- A custom permission set or perm-set group with `<classAccesses>` for all backing Apex
- `<flowAccesses>` for every autolaunched Flow used by the agent

**Critical:** The planner validates permissions for **all** registered actions at startup, not lazily per-subagent. If the user lacks permission for ANY action in ANY subagent, the entire agent fails with a permission error (Issue #10).

---

## 9. Action Result Handling Patterns

### Patterns the Builder UI encourages (and how to replicate in DSL)

**Pattern: progress indicator while an action runs**

Builder UI: "Show progress message" toggle on the action.

DSL:

```
actions:
   slow_lookup:
      description: "Look up a complex record"
      include_in_progress_indicator: True
      progress_indicator_message: "Looking up the record..."
      target: "apex://SlowLookupAction"
```

**Pattern: hide an output from the LLM (use it only for routing)**

Builder UI: "Hide from agent" on an output.

DSL:

```
outputs:
   intent_classification: string
      filter_from_agent: True
      is_used_by_planner: True
```

**Pattern: action requires user confirmation**

Builder UI: "Require confirmation" toggle.

DSL: **does NOT work at runtime in script-version agents** (Issue #6). The property compiles but the runtime no-ops. Use the two-step pattern instead:

```
reasoning:
   instructions: ->
      if @variables.user_confirmed == False:
         | Confirm with the user before running the action.

   actions:
      confirm: @utils.setVariables
         description: "Save the user's confirmation"
         with user_confirmed = ...

      run_action: @actions.delete_record
         available when @variables.user_confirmed == True
         with record_id = @variables.record_id
```

---

## 10. Verification Gate Pattern

For PII / payments / sensitive operations, use a verification gate subagent:

```
start_agent agent_router:
   description: "Route through identity verification"
   reasoning:
      instructions: |
         You are a router only. Route ALL users to identity verification first.
      actions:
         verify: @utils.transition to @subagent.identity_verification
            description: "Begin verification"

subagent identity_verification:
   description: "Verify customer identity before granting access to protected subagents"
   reasoning:
      instructions: ->
         if @variables.failed_attempts >= 3:
            | Too many failed attempts. Transferring to a human agent.
            transition to @subagent.escalation

         if @variables.is_verified == True:
            | Identity verified. How can I help?

         if @variables.is_verified == False:
            | Please verify your identity.

      actions:
         verify_email: @actions.verify_identity
            description: "Verify customer email"
            with email = ...
            set @variables.is_verified = @outputs.verified

         to_account: @utils.transition to @subagent.account_mgmt
            description: "Account management (after verification)"
            available when @variables.is_verified == True

         escalate_now: @utils.escalate
            description: "Transfer to human"
            available when @variables.failed_attempts >= 3
```

**Dual enforcement principle:** EVERY protected action enforces `available when @variables.is_verified == True` AND the backing Apex/Flow re-checks `isVerified` from the request context. Never rely on instruction-level gating alone -- defense in depth.

---

## 11. Anti-Patterns Specific to Builder Workflows

| # | Anti-pattern | Correct approach |
|---|---|---|
| 1 | Editing the auto-generated `.bot-meta.xml` and expecting changes to persist after the next publish | Maintain a Bot-only override manifest and re-deploy after every publish |
| 2 | Creating a separate routing subagent (`main_menu`, `central_hub`) | `start_agent agent_router` IS the router -- don't add a hop |
| 3 | Using Builder Canvas to add an action that fires Supervision (`@subagent.X`) and expecting it to stay Supervision | KNOWN BUG: Canvas may convert Supervision references to Handoff transitions on save. Verify after each Canvas edit |
| 4 | Defining the same action in every subagent's `actions:` block (Builder UI auto-replication) | Define once where it makes sense; transition to the owning subagent rather than duplicating |
| 5 | Treating the Builder UI's "Required" field on Topic Description as cosmetic | The description IS the LLM's topic-selection signal. Write a focused 1-3 sentence description with keywords |
| 6 | Authoring an action in Asset Library and pulling it into Agent Script without quote-checking the input names | Asset Library actions sometimes ship with non-quoted `Input:foo` names that fail Agent Script parse. Always check and quote (Issue #7) |
| 7 | Using `Agent Testing Center` UI tests and expecting them in source control | UI tests cannot be retrieved. Author tests as YAML test specs and use `sf agent test create` |
| 8 | Setting `EinsteinAgentApiChannel` on an org that doesn't have the feature | Deploy fails. Use `CustomerWebClient` for Agent Runtime API testing (Issue #17) |

---

## 12. Definition of Done -- Builder + Source Combined

- [ ] All metadata files present in source: `AiAuthoringBundle`, `Bot`, `BotVersion`, `GenAiPlannerBundle` (the last three auto-generated; verify they exist)
- [ ] No standalone `GenAiPlugin` or `GenAiFunction` files for new authoring-bundle agents
- [ ] All referenced Flow API names exist as Active Flows in the target org
- [ ] All referenced Apex class names exist with `@InvocableMethod` and are deployed
- [ ] All variable names in action `description:` text match Flow/Apex parameter names case-sensitively
- [ ] Every variable declared is referenced by at least one action or instruction
- [ ] `logPrivateConversationData = false` re-asserted via override manifest (PII agents)
- [ ] Verification gate enforced in `available when` AND in backing-logic code
- [ ] No fabricated values in any test scenario response -- grounding traces all GROUNDED
- [ ] Test conversations: happy path + failed verification + action failure + out-of-scope + edge case
- [ ] Deployment dependency order: Apex/Flow -> publish authoring bundle -> activate
- [ ] Activate in sandbox, smoke-test, then activate in production

---

## 13. Empirical Findings & Implementation Notes

| # | Date | Documented approach | What actually works | Why / Context |
|---|---|---|---|---|
| 1 | 2026-05-16 | Builder UI describes per-topic fields (Description / Scope / Instructions / Guardrails / User Input Examples) as separate inputs | The `.agent` DSL has no separate `scope:` or `guardrails:` keys. Convention: Classification + Scope -> `subagent.description:`; Instructions -> `reasoning.instructions:` (condition-based steps); Guardrails -> trailing `\| GUARDRAILS:` block; User Input Examples -> `start_agent` transition `description:` strings | Builder UI structure doesn't map 1:1 to DSL keys; the DSL is more concise |
| 2 | 2026-05-15 | `sf agent publish authoring-bundle` preserves the locally-authored `Bot.bot-meta.xml` | The publish command auto-retrieves and OVERWRITES the local bot-meta with org defaults. Three security-critical fields get stripped: `<logPrivateConversationData>false</logPrivateConversationData>` -> `true`; `<agentTemplate>` dropped; the 5 standard `<contextVariables>` dropped. Workaround: Bot-only override manifest deployed after every publish | Critical for PII safety |
| 3 | 2026-05-16 | Adding a Supervision (`@subagent.X`) reference via Builder Canvas keeps it as Supervision | KNOWN BUG: Adding ANY new action in Canvas may inadvertently change existing Supervision references into Handoff (`@utils.transition to`) transitions. Verify after each Canvas edit | Issue documented in production-gotchas |
| 4 | 2026-05-16 | `require_user_confirmation: True` on an action triggers a Builder-style confirmation dialog before execution | Property compiles and publishes but is a RUNTIME NO-OP in Agent Script agents (Issue #6). Use the two-step pattern: ask user, capture confirmation in a variable, gate the action with `available when @variables.user_confirmed == True` | |
| 5 | 2026-05-16 | `EinsteinAgentApiChannel` surfaceType is universally available | Not available on all orgs -- deploy fails. Use `CustomerWebClient` for Agent Runtime API / CLI testing (Issue #17) | |
| 6 | 2026-05-16 | `connection messaging:` block automatically generates the `CustomerWebClient` plannerSurface for Builder Preview | Only `Messaging` is auto-generated. `CustomerWebClient` is dropped on every publish. Requires manual post-publish patch (Issue #18, 6-step workflow) | |

---

## 14. Official References

- [Agentforce Builder Help](https://help.salesforce.com/s/articleView?id=sf.ai_agent_build.htm) (verify URL with current release; live page JS-rendering blocks WebFetch)
- [Bot Metadata API](https://developer.salesforce.com/docs/atlas.en-us.api_meta.meta/api_meta/meta_bot.htm)
- [forcedotcom/sf-skills `developing-agentforce`](https://github.com/forcedotcom/sf-skills/tree/main/skills/developing-agentforce) -- full reference library
- Companion files in this skill set:
  - [Agent Script Canonical Reference](../salesforce-agentforce-script/SKILL.md)
  - [Agentforce Authoring Bundle Lifecycle](../salesforce-agentforce-authoring-bundle/SKILL.md)
  - [Agentforce Script Authoring Guidelines](../salesforce-agentforce-script/SKILL.md)

---

*Agentforce Builder " Agent Script Parity Guide | v3.0 | Last verified 2026-05-16*

