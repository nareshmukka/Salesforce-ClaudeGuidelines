---
name: salesforce-agentforce-authoring-bundle
description: Production Salesforce AI skill for Editing `.agent` bundles and related Agent Script block design.
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
- The task involves Editing `.agent` bundles and related Agent Script block design.
- The user asks for implementation, refactor, troubleshooting, review, or best-practice validation in this area.
- The assistant must produce Salesforce-safe code/metadata with explicit security/testing notes.

## DO NOT TRIGGER when
- The task is unrelated to this component.
- Another specialized skill is the primary owner and this area is only incidental.
- The user asks for operational execution (deploy/publish/activate/destructive change) without explicit approval.

## Cross-skill routing
- Always read `../salesforce-global-development/SKILL.md`.
- Also read: Global Development + Agentforce Script + Agentforce Builder + Prompt Template.
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
Agent Script is block-based: system, config, variables, language, connection, subagent, start_agent. config includes developer_name/default_agent_user/agent_label/description/company/role/agent_version/agent_type/enable_enhanced_event_logs/user_locale. start_agent routes; subagent defines reasoning/actions/contracts.

## Upstream Salesforce Skill Patterns
- Do not hand-create bundles when CLI generation is available; generate the authoring bundle, then edit the `.agent` source and bundle metadata.
- For new agents, stop after Agent Spec drafting until the user approves the spec. The spec should identify subagents, actions, backing logic, variables, routing, safety gates, and required org setup.
- Scan existing project metadata before inventing actions: invocable Apex, autolaunched Flows, prompt templates, objects, and fields may already provide backing logic.
- Validate in this order: environment prerequisites, authoring-bundle compile, backing-logic deploy, live preview with `--use-live-actions`, trace analysis, then publish/activate only after explicit approval.
- Service agents require careful default agent user and permission validation. Employee agents must not be configured like service/messaging agents.
- For behavior issues, traces are the source of truth; preview text alone is not enough to diagnose routing/action problems.
- Agent Script Recipes provide progressive examples: language essentials, action configuration, reasoning mechanics, and architectural patterns. Use them as pattern references, not as copy-paste output.

## Examples
### Good example patterns
1. Subagent reasoning actions reference only declared available actions.
2. Write action gated by explicit user confirmation step and audit note.

### Bad examples / avoid
1. Publish used as substitute for validation/preview.
2. Auto-activate agent after publish with no approval gate.

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

## Agentforce authoring bundle deep guidance
- `.agent` files define block-based behavior contracts and runtime routing.
- Block map: `system`, `config`, `variables`, `language`, `connection`, `subagent`, `start_agent`.
- `system` must include clear policy + welcome/error response behavior.
- `config` should define: `developer_name`, `default_agent_user`, `agent_label`, `description`, `company`, `role`, `agent_version`, `agent_type`, `enable_enhanced_event_logs`, `user_locale`.
- Employee Agent vs Service Agent: Employee focuses internal productivity/workflows; Service is customer-facing with stricter response and confirmation boundaries.
- `variables` defines reusable global values that subagents and actions can reference consistently.
- `language` defines supported language behavior and localization boundaries for responses.
- `connection` defines integration/escalation connection context and external handoff constraints.
- `start_agent` is the entry router; `subagent` blocks scope reasoning and action availability.
- Action contracts: define required input schema, output schema, and failure modes; reasoning references must align to available actions.

### Minimal `.agent` skeleton (example)
```agent
system {
  instruction: "Follow policy and ask for confirmation before write actions."
  welcome: "Hello, how can I help?"
  error: "I could not complete that request safely."
}
config {
  developer_name: "case_support_agent"
  agent_label: "Case Support Agent"
  agent_type: "service"
  user_locale: "en_US"
}
start_agent {
  route_to: "case_triage"
}
subagent case_triage {
  description: "Case triage and safe updates"
}
```

### Good subagent pattern
- Narrow topic scope, explicit allowed actions, and deterministic confirmation gate for any write/send action.

### Bad conflicting instruction pattern
- `system` says "never update records" while `subagent` says "always update record automatically".

### Safe write-action confirmation pattern
- Ask user to confirm intent + target record + fields before invoking update action, then echo planned change.

### Validation flow
1. Inspect script and dependency assumptions.
2. Validate syntax and block references.
3. Preview behavior locally/in Builder.
4. Review action contracts and reasoning-action mappings.
5. Publish only after explicit approval.
6. Activate only after explicit approval.

**Warning:** Publish is not validation. Never auto-publish or auto-activate.


## Full Guidance

# Agentforce Authoring Bundle -- Lifecycle & Deployment

End-to-end guide for the `AiAuthoringBundle` lifecycle: design -> generate -> write -> validate -> deploy -> publish -> activate -> preview -> test. Pair with **[../salesforce-agentforce-script/SKILL.md](../salesforce-agentforce-script/SKILL.md)** for the DSL grammar.

**Verified against** the same canonical sources listed in the reference file. Last verified 2026-05-16.

---

## 1. The Two-Domain Model

Agent Script lives across two **separate** metadata domains. Confusing them is the #1 source of lifecycle errors.

```
AUTHORING DOMAIN (developer-owned)
   AiAuthoringBundle
      """ <name>.agent              # Agent Script source
      """" <name>.bundle-meta.xml    # bundleType=AGENT, optional <target>

RUNTIME DOMAIN (created by `sf agent publish`)
   Bot                                 # top-level container, one per agent
      """" BotVersion                   # one per published version (v1, v2, ...)
            """" GenAiPlannerBundle    # compiled definition, scoped to this version
```

- **Deploy** = push the AiAuthoringBundle (authoring domain only). Does NOT make the agent usable.
- **Publish** = compile the bundle + create Bot + BotVersion + GenAiPlannerBundle (runtime domain). Self-contained -- does not need a prior deploy.

`Agent:<Name>` (pseudo-type) retrieves the runtime entities. `AiAuthoringBundle:<Name>` retrieves the source. **They are not interchangeable.**

---

## 2. Choosing the Agent Type

| Type | API value | Use when |
|---|---|---|
| Employee | `AgentforceEmployeeAgent` | Server-invoked from Apex via `generateAiAgentResponse`. Internal tools, case automation, server-side workflows. |
| Service | `AgentforceServiceAgent` | Customer-facing channels (chat, messaging). Requires `default_agent_user` (Einstein Agent license). |

**Server-side `generateAiAgentResponse` from Apex works ONLY with `AgentforceEmployeeAgent`.** This is non-negotiable.

**`AgentforceEmployeeAgent` MUST NOT include** any of these (each one causes publish to fail with "Internal Error, try again later"):
- `default_agent_user`
- `connection messaging:` block
- MessagingSession linked variables (`EndUserId`, `RoutableId`, `ContactId`, `EndUserLanguage`)
- `@utils.escalate` actions

---

## 3. Project Setup

### Prerequisites
- Salesforce CLI v2 (the legacy `sf bot` commands were removed; use `sf agent`)
- `--json` on every `sf agent`/`sf project` command
- Project default target org set: `sf config set target-org <alias>`
- Agentforce license enabled in the org
- For service agents: an active **Einstein Agent User** (see Section 11 Local folder structure

```
force-app/main/default/
   aiAuthoringBundles/
      <Developer_Name>/
         <Developer_Name>.agent
         <Developer_Name>.bundle-meta.xml
   bots/
      <Developer_Name>/              # auto-created by publish
         <Developer_Name>.bot-meta.xml
         v1.botVersion-meta.xml
   genAiPlannerBundles/
      <Developer_Name>_v1/           # auto-created by publish
         localActions/
         <Developer_Name>_v1.genAiPlannerBundle
```

The folder name, the `.agent` filename, and the `developer_name:` in the `config:` block must match exactly -- case-sensitive.

---

## 4. The Lifecycle Pipeline

```
generate -> edit -> validate -> deploy -> publish -> activate -> preview/test -> iterate
```

| Phase | CLI command | Notes |
|---|---|---|
| Generate | `sf agent generate authoring-bundle --json --no-spec --name "<Label>" --api-name <Dev_Name>` | `--no-spec` is REQUIRED -- without it, the CLI hangs on interactive spec input. |
| Validate | `sf agent validate authoring-bundle --json --api-name <Dev_Name>` | Local syntax check. Does NOT contact the org. Does NOT validate `default_agent_user` or backing logic. |
| Deploy | `sf project deploy start --json --metadata AiAuthoringBundle:<Dev_Name>` | Authoring domain only. Useful for pro-code + low-code collaboration. |
| Publish | `sf agent publish authoring-bundle --json --api-name <Dev_Name>` | Compile + create runtime entities. Self-contained. |
| Activate | `sf agent activate --json --api-name <Bot_API_Name>` | Make the most-recent published version live. |
| Preview (source) | `sf agent preview start --json --use-live-actions --authoring-bundle <Dev_Name>` | Test from local source against the org. |
| Preview (published) | `sf agent preview start --json --api-name <Bot_API_Name>` | Test the activated version. Real actions execute. |
| Send utterance | `sf agent preview send --json --authoring-bundle <Dev_Name> --session-id <ID> -u "<message>"` | Same `--authoring-bundle` (or `--api-name`) as start. |
| End session | `sf agent preview end --json --authoring-bundle <Dev_Name> --session-id <ID>` | Returns trace file paths. |
| Deactivate | `sf agent deactivate --json --api-name <Bot_API_Name>` | Take version offline (keeps version). |
| Retrieve source | `sf project retrieve start --json --metadata AiAuthoringBundle:<Dev_Name>` | Pulls `.agent` + `.bundle-meta.xml`. |
| Retrieve runtime | `sf project retrieve start --json --metadata Agent:<Dev_Name>` | Pulls Bot + BotVersion + GenAiPlannerBundle. Does NOT include AiAuthoringBundle. |

**Always include `--json` first.** Many mid-tier wrappers drop trailing flags.

---

## 5. Generate

```bash
sf agent generate authoring-bundle --json --no-spec --name "Email Analysis Agent" --api-name Email_Analysis_Agent
```

| Flag | Purpose |
|---|---|
| `--name` | Display label (quoted if spaces). Becomes `agent_label`. |
| `--api-name` | Developer name. Letters/numbers/underscores. Becomes `developer_name` AND the directory name. |
| `--no-spec` | REQUIRED -- skip the interactive spec prompt (hangs otherwise). |
| `--force-overwrite` | Overwrite existing bundle. Use only when intentional. |

Creates:

```
aiAuthoringBundles/Email_Analysis_Agent/
   Email_Analysis_Agent.agent
   Email_Analysis_Agent.bundle-meta.xml
```

The starter `.agent` file has placeholder content. You edit it in place.

---

## 6. Validate

```bash
sf agent validate authoring-bundle --json --api-name Email_Analysis_Agent
```

- Local syntax + structure check. Fast feedback during inner-loop authoring.
- Does **not** validate `default_agent_user`, backing logic references, or runtime behavior.
- On success: `{"status": 0, "result": {"success": true}}`.
- On failure: information is in the `message` field (other fields are CLI internals).

**The pre-validate mental checklist** (see [../salesforce-agentforce-script/SKILL.md Section 14 salesforce-agentforce-script/SKILL.md)) catches the most common errors before you spend time on the CLI round-trip.

---

## 7. Deploy

```bash
# Deploy backing logic FIRST -- bundle compile validates Apex/Flow references
sf project deploy start --json --metadata ApexClass Flow

# Then (optional) push the authoring bundle to the org
sf project deploy start --json --metadata AiAuthoringBundle:Email_Analysis_Agent
```

**Scope deploys explicitly.** A bare `sf project deploy start` deploys all local changes -- that can accidentally push an outdated `.agent` file and overwrite in-progress work in Builder. Always list metadata types.

**Multiple types are space-separated, NOT comma-separated:** `--metadata ApexClass Flow` (correct), `--metadata ApexClass,Flow` (wrong).

**Wildcards must be quoted:** `--metadata "AiAuthoringBundle:Email_Analysis_Agent_*"`.

---

## 8. Publish

```bash
sf agent publish authoring-bundle --json --api-name Email_Analysis_Agent
```

What publish does:
1. Deploys the authoring bundle (if not already deployed)
2. Compiles Agent Script -> Agent DSL
3. Creates the runtime entity graph: Bot, BotVersion (e.g., `v1`), GenAiPlannerBundle (`<Name>_v1`)
4. Auto-retrieves the new metadata back to local source (unless `--skip-retrieve`)

**Publish is self-contained.** A brand-new bundle can be published directly with no prior deploy.

**Publish does NOT activate.** The new version ships Inactive. Run `sf agent activate` separately.

**`--api-name` is the developer name** (the directory under `aiAuthoringBundles/`).

### Publish failure troubleshooting (in order)

1. **`Internal Error, try again later`** -- almost always `default_agent_user`. Validate:
   - EmployeeAgent -> `default_agent_user` must be ABSENT entirely.
   - ServiceAgent -> `default_agent_user` must reference an active user with the `Einstein Agent` license:
     ```bash
     sf data query --json -q "SELECT Username, IsActive, Profile.UserLicense.Name FROM User WHERE Username = '<value>'"
     ```
2. **Backing logic references unresolved** -- ensure every `apex://ClassName`, `flow://FlowName`, `prompt://TemplateName` resolves to a deployed component. For Apex, the class must have an `@InvocableMethod`.
3. **Stale `<target>` lock** -- open `bundle-meta.xml`. If a `<target>` element is present, remove it, redeploy, retry publish.
4. **Active version blocking changes to `default_agent_user`** -- deactivate, change, republish, reactivate.
5. **Missing `outputs:` block on a subagent action definition** -- publish fails with "Internal Error" (Issue #15). Always include `outputs:` even when minimal.

### Publish-then-override pattern (PII safety)

`sf agent publish authoring-bundle` overwrites the local `Bot.bot-meta.xml` with the org's auto-generated defaults -- including resetting `<logPrivateConversationData>` to `true`. For any agent processing PII, deploy a Bot-only override **immediately after every publish**:

`manifest/package-<agent>-bot-override.xml`:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<Package xmlns="http://soap.sforce.com/2006/04/metadata">
   <types>
      <members>Email_Analysis_Agent</members>
      <name>Bot</name>
   </types>
   <version>66.0</version>
</Package>
```

Then:
```bash
sf project deploy start --json --manifest manifest/package-email-analysis-bot-override.xml --target-org <alias>
```

Verify post-deploy by retrieving and checking the value:
```bash
sf project retrieve start --json --metadata Bot:Email_Analysis_Agent
grep logPrivateConversationData force-app/main/default/bots/Email_Analysis_Agent/Email_Analysis_Agent.bot-meta.xml
```

---

## 9. Activate

```bash
sf agent activate --json --api-name <Bot_API_Name>
sf agent deactivate --json --api-name <Bot_API_Name>
```

- Only one published version can be active at a time. Activating a new version automatically deactivates the previous.
- `--api-name` here is the **Bot** API name (same as `developer_name`).
- DRAFT-only agents cannot be activated.
- Tests run against activated published agents only.

---

## 10. Preview & Debug

```bash
# Start session against local source (real actions)
sf agent preview start --json --use-live-actions --authoring-bundle Email_Analysis_Agent

# Start session against the published live version
sf agent preview start --json --api-name Email_Analysis_Agent

# Send an utterance
sf agent preview send --json --authoring-bundle Email_Analysis_Agent --session-id <ID> -u "Analyze Case 500..."

# End and get trace paths
sf agent preview end --json --authoring-bundle Email_Analysis_Agent --session-id <ID>
```

| Mode | Flag pair | When |
|---|---|---|
| Simulated | `--authoring-bundle <name>` (no `--use-live-actions`) | Backing logic doesn't exist yet; quick instruction iteration. LLM fakes action outputs. |
| Live (source) | `--authoring-bundle <name> --use-live-actions` | Real Apex/Flow/Prompt run. Required for grounding tests. |
| Live (published) | `--api-name <name>` (no `--use-live-actions` needed) | User-visible behavior. Real actions always. |

**Mutual exclusion.** `--authoring-bundle` and `--api-name` are mutually exclusive. `--use-live-actions` is only valid with `--authoring-bundle`.

**Context variable limitation.** `sf agent preview` does NOT support context/session variable injection -- there are no `--context`, `--session-var`, or `--variables` flags. If your agent's behavior depends on `@session.X` or `@context.X`, test in the channel (messaging / API).

### Session traces

Traces are written at:
```
.sfdx/agents/<AGENT_NAME>/sessions/<SESSION_ID>/
   metadata.json           # session info
   transcript.jsonl        # one JSON object per line, conversation log
   traces/<PLAN_ID>.json   # per-turn detailed execution log
```

Traces are available immediately after each `send`. The transcript's agent-response entry includes a `raw[].planId` that maps to the trace filename.

### Trace step types

| Step | What it reveals |
|---|---|
| `UserInputStep` | The user's utterance for this turn |
| `SessionInitialStateStep` | Variable values at turn start |
| `NodeEntryStateStep` | Which subagent is executing, full state snapshot |
| `VariableUpdateStep` | Variable change with old/new + reason |
| `BeforeReasoningIterationStep` | `before_reasoning` block ran |
| `EnabledToolsStep` | Actions available to the LLM this turn |
| `LLMStep` | Full prompt sent, tools sent, LLM response, latency |
| `FunctionStep` | Action execution: inputs, outputs, latency |
| `ReasoningStep` | Grounding check: `GROUNDED` or `UNGROUNDED` (with reason) |
| `TransitionStep` | Subagent transition |
| `PlannerResponseStep` | Final response delivered to user, safety scores |

### Diagnostic jq snippets

```bash
TRACE=".sfdx/agents/<NAME>/sessions/<SESSION>/traces/<PLAN>.json"

# Where did we transition?
jq '[.steps[] | select(.stepType == "TransitionStep") | .data.to]' "$TRACE"

# Which actions ran?
jq '[.steps[] | select(.stepType == "FunctionStep") | .data.function]' "$TRACE"

# Grounding outcome
jq '[.steps[] | select(.stepType == "ReasoningStep") | .data.groundingAssessment]' "$TRACE"

# Tools the LLM saw
jq '[.steps[] | select(.stepType == "EnabledToolsStep") | .data.enabled_tools]' "$TRACE"

# Safety score
jq '.steps[] | select(.stepType == "PlannerResponseStep") | .data.safetyScore' "$TRACE"
```

---

## 11. Einstein Agent User (Service Agents Only)

```bash
# Does a valid user exist?
sf data query --json -q "SELECT Username, Name, IsActive FROM User WHERE Profile.UserLicense.Name = 'Einstein Agent' AND IsActive = true LIMIT 5"

# License availability
sf data query --json -q "SELECT TotalLicenses, UsedLicenses FROM UserLicense WHERE Name = 'Einstein Agent'"
```

If no user exists, create one -- see [forcedotcom/sf-skills `developing-agentforce` Section 12 https://github.com/forcedotcom/sf-skills/tree/main/skills/developing-agentforce) for the User import JSON template.

For employee agents, **skip this section entirely.**

---

## 12. Test Execution

```bash
# Create test from local YAML spec
sf agent test create --json --spec specs/<Dev_Name>-testSpec.yaml --api-name <Test_API_Name> --force-overwrite

# Run synchronously
sf agent test run --json --api-name <Test_API_Name> --wait 5

# Or async + poll
sf agent test results --json --job-id <JOB_ID>
```

- Tests run against **activated published agents only.**
- `--wait 5` forces synchronous execution (5-minute timeout).
- `sf agent generate test-spec` is interactive; do not call from automation unless paired with `--from-definition`.

---

## 13. Apex Caller Pattern (Server-Invoked EmployeeAgent)

```apex
public with sharing class EmailAnalysisAgentInvoker {

   public static Map<String, Object> invokeStructuredAnalysis(Id caseId, Id emailMessageId) {
      // Embed record IDs in the message text. sessionVariables JSON is silently dropped.
      String message = String.format(
         'Analyze the email for Case {0} and EmailMessage {1}.',
         new List<String>{ caseId, emailMessageId }
      );

      Agent.GenerateAiAgentResponseInput input = new Agent.GenerateAiAgentResponseInput();
      input.agentApiName = 'Email_Analysis_Agent';
      input.message = message;

      Agent.GenerateAiAgentResponseOutput out = Agent.generateAiAgentResponse(input);
      return parse(out);
   }
}
```

| Trap | Fix |
|---|---|
| Passing IDs via `sessionVariables` JSON | Silently dropped -- embed IDs in the message text |
| Calling `invokeAgent()` when the agent returns free text | Use `invokeAgentForText()` and unwrap `{"type":"Text","value":"..."}` |
| Using `agent_type = AgentforceServiceAgent` | `generateAiAgentResponse` requires `AgentforceEmployeeAgent` |
| Missing `WITH USER_MODE` on backing-logic SOQL | Adds silent CRUD/FLS gaps; required per `../salesforce-apex/SKILL.md` |

---

## 14. JSON Return Contract Pattern

When the agent must return structured JSON, encode the contract in `reasoning.instructions:` and parse on the Apex side:

```
# In .agent reasoning instructions:
| Return EXACTLY this JSON, no markdown fence, no prose before or after:
  {"summary":"","category":"","intent":"","confirmationNumber":"",
   "newEmailAddress":null,"confidence":0.0}
```

Apex side: strip any accidental ```json``` fence, JSON.deserializeUntyped, validate every key. Treat the structured `outputs:` block (when the action has one) as the authoritative source -- the LLM's textual response is the fallback.

---

## 15. Deployment Checklist

Before publishing a new or updated agent, verify every item:

- [ ] `developer_name` matches directory and filename exactly
- [ ] `agent_type` correct (`AgentforceEmployeeAgent` or `AgentforceServiceAgent`)
- [ ] No `default_agent_user` on EmployeeAgent; valid Einstein Agent username on ServiceAgent
- [ ] All referenced Apex classes deployed AND confirmed to have `@InvocableMethod`
- [ ] All referenced Flows deployed AND Active AND AutoLaunchedFlow type
- [ ] All referenced Prompt Templates deployed AND Active
- [ ] Action input names match `@InvocableVariable` field names exactly (case-sensitive)
- [ ] Every action definition has an `outputs:` block (Issue #15 guard)
- [ ] Reserved names not used as `@InvocableVariable`: `model`, `description`, `label`
- [ ] Bot-meta override prepared if PII (`logPrivateConversationData=false`)
- [ ] Validate passes locally with zero errors
- [ ] Live preview tested with representative utterances per subagent
- [ ] Traces confirm correct subagent routing + action invocation
- [ ] Rollback prepared (previous active version, override manifest)

---

## 16. Common AI Mistakes to Avoid

| # | Mistake | Correct approach |
|---|---|---|
| 1 | Passing record IDs via `sessionVariables` JSON in `generateAiAgentResponse` | Silently dropped -- embed IDs in the user-message text |
| 2 | Using `invokeAgent()` when the agent returns free text | Use `invokeAgentForText()` and unwrap the `{"type":"Text","value":"..."}` envelope |
| 3 | Wrapping flow actions in a standalone `GenAiFunction` metadata file | Inline action with `target: "flow://Flow_API_Name"` is authoritative for authoring bundles |
| 4 | Using `AgentforceServiceAgent` for server-invoked Apex | `generateAiAgentResponse` requires `AgentforceEmployeeAgent` |
| 5 | `sf agent publish authoring-bundle --authoring-bundle <Name>` | The CLI flag is `--api-name`. `--authoring-bundle` is rejected on publish. Short flag is `-n`. Verify with `sf agent publish authoring-bundle --help` |
| 6 | Generic prompt extraction descriptions ("a code with dashes") | Describe the actual format: "5 groups of 4 alphanumeric characters separated by hyphens, e.g. ABCD-1234-EFGH-5678-WXYZ" |
| 7 | Paraphrased / inconsistent colon-label strings when an LWC parses `context.summary` | LWCs don't fuzzy-match. Output exact strings (colon, casing, spacing) |
| 8 | JSON output fields without matching text in the summary | JSON drives automation; summary is what humans read. State extracted data in BOTH -- never contradict |
| 9 | PII-handling EmployeeAgent shipped with `logPrivateConversationData=true` AND SOQL missing `WITH USER_MODE` AND no PII redaction policy | Three controls must align: (a) `<logPrivateConversationData>false</logPrivateConversationData>` re-asserted via override manifest after every publish; (b) every backing-logic SOQL uses `WITH USER_MODE`; (c) `system.instructions` includes an explicit PII redaction policy |
| 10 | Authoring a script-version agent as one monolithic `start_agent` block with paragraph prose and no `variables:` | Thin `start_agent` router with `@utils.transition to @subagent.X` actions + one focused `subagent` per domain. State in `variables:`. Condition-based `reasoning.instructions:` |
| 11 | Writing guardrails as prose when the action's `outputs:` declares no `errorMessage`/`status` field | Every action whose failure changes agent behavior must declare `errorMessage: string` (and ideally `status: string`) in `outputs:`. Apex `@InvocableMethod` populates these in try/catch (never throws). Guardrails then become deterministic: `if @outputs.errorMessage != "":` |
| 12 | Leaving legacy standalone `GenAiFunction:<Name>` metadata alongside the inline action declaration in a new authoring bundle | Pick one source of truth. Inline `apex://ClassName` is authoritative. Delete the standalone `GenAiFunction` via `destructiveChanges.xml` after grep confirms no peer bundle binds to it |
| 13 | Apex `@InvocableMethod` action class with zero logging -- relying on `enable_enhanced_event_logs: True` for observability | Enhanced event logs capture only LLM-side envelope. Apex-side observability is separate -- log entry (INFO), success (INFO), exception (ERROR). Pass a correlation ID so `AppLog__c` rows join to Agentforce event logs |
| 14 | Defining an action without an `outputs:` block | Publish fails with "Internal Error, try again later" (Issue #15). Always include `outputs:` |
| 15 | Bare `number` type on action I/O | Use `object` + `complex_data_type_name: "lightning__integerType"` (apex target) or `"lightning__numberType"` (flow target) |
| 16 | Setting `default_agent_user` on EmployeeAgent | Publish fails with cryptic "Internal Error". The field must be ABSENT on EmployeeAgent |

---

## 17. Empirical Findings & Implementation Notes

When Salesforce's documented approach doesn't work in this org, the workaround goes here. Date-stamp every entry.

| # | Date | Documented approach | What actually works | Why / Context |
|---|---|---|---|---|
| 1 | 2026-05-15 | `../salesforce-agentforce-script/SKILL.md` lists `date` as a first-class scalar type for datetime values | For an action output that Apex returns as `Datetime`, `sf agent retrieve` writes it back as `type: object` + `complex_data_type_name: "lightning__dateTimeStringType"`. Both compile at API v66.0. Standardise NEW authoring on `type: date`; accept the object form when retrieved | Observed in `Email_Resend_Agent.agent` and `UnitedMiles_Refund_Agent_v2.agent` on 2026-05-15 |
| 2 | 2026-05-15 | `id` listed as first-class scalar for record IDs | Three idioms exist for the same semantic: `type: string`, `type: id`, and `type: object` + `complex_data_type_name: "lightning__recordIdType"`. Form (b) `type: id` is canonical for new authoring | PlusGradeFullSB observation, Spring '26 |
| 3 | 2026-05-15 | Builder UI doc lists per-topic SCOPE / INSTRUCTIONS / GUARDRAILS / USER INPUT EXAMPLES | The DSL has no separate `scope:` / `guardrails:` keys. Convention: Classification + Scope -> `subagent.description:`; Instructions -> `reasoning.instructions:`; Guardrails -> trailing `\|GUARDRAILS:` block; User Input Examples -> `start_agent` transition `description:` strings | Builder UI structure doesn't map 1:1 to DSL keys |
| 4 | 2026-05-15 | Some sketches imply a `contains` (substring-match) operator in `->` blocks | No `contains` operator is documented. Use LLM-mediated routing instead: narrow STEP 0 prose + `@utils.transition to @subagent.X` actions with narrow `description:` strings | PlusGradeFullSB, Spring '26 |
| 5 | 2026-05-15 | Section 4 deploy-order ("Apex -> Flows -> GenAiFunctions -> publish") + peer manifests imply a brand-new agent can be bootstrapped via `sf project deploy start --manifest` | That order ONLY works for UPDATES. For first-time creation: (1) Deploy Apex + Flow via manifest; (2) `sf agent publish authoring-bundle --api-name <Name>` creates Bot + v1 BotVersion + GenAiPlannerBundle atomically; (3) `sf project retrieve start --metadata Bot:<Name>` populates source files. Deploying BotVersion via manifest fails with "Required fields are missing: [PlannerId]" | Discovered while bootstrapping `Email_Analysis_Agent` |
| 6 | 2026-05-15 | The `AiAuthoringBundle` deploy path is implicit | `AiAuthoringBundle` is never deployed via `sf project deploy start --manifest` in this project's workflow. `sf agent publish authoring-bundle` is the sole publish path. No peer manifest lists `AiAuthoringBundle` under `<types>` | Cross-references finding #5 |
| 7 | 2026-05-15 | `sf agent publish authoring-bundle` uses the locally-authored `Bot.bot-meta.xml` as source of truth | The publish command IGNORES the local bot-meta and creates the Bot from org-template defaults. It auto-retrieves the org's Bot state back, OVERWRITING the local file. Three security-critical fields were stripped during a real publish: `<logPrivateConversationData>false</logPrivateConversationData>` flipped to `true`; `<agentTemplate>EmployeeCopilot__AgentforceEmployeeAgent</agentTemplate>` dropped; the 5 standard `<contextVariables>` dropped. **Workaround:** deploy a Bot-only override manifest IMMEDIATELY after every publish | CRITICAL for any agent processing PII -- org default `logPrivateConversationData=true` re-introduces PII-logging risk. See Section 8 publish-then-override pattern |
| 8 | 2026-05-15 | Canonical-form regex `(?i)(?:confirmation\s*(?:number\|#\|code)?\s*[:\-]?\s*)?([A-Z0-9]{4}(?:[\s-]?[A-Z0-9]{4}){4})\b` for confirmation codes | Missing leading `\b` causes greedy-match into preceding English words. Example: `"Please resend ABCD-1234-EFGH-5678-WXYZ"` mis-captures `"send ABCD-1234-EFGH-5678"` (taking "send" from "re**send**" + first 4 groups). Fix: prepend `\b` so the first capture group must begin at a word boundary | Caught by sandbox test T4f-body on 2026-05-15; fix deployed same day |
| 9 | 2026-05-16 | `sf agent publish authoring-bundle --authoring-bundle <Name>` per [agent-dx-nga-publish doc page](https://developer.salesforce.com/docs/ai/agentforce/guide/agent-dx-nga-publish.html) | CLI rejects `--authoring-bundle` on publish -- only `--api-name` (short `-n`) is accepted. The cited doc page is stale relative to the shipping CLI. Always cross-check with `sf agent publish authoring-bundle --help` before authoring publish commands | PlusGradeFullSB, sf CLI v2 on 2026-05-15 |
| 10 | 2026-05-16 | `sf agent preview send --json --authoring-bundle <Name>` returns the agent's complete response, suitable for end-to-end functional testing | The CLI's `result.messages[]` payload only contains the FIRST post-transition LLMStep response. Multi-iteration reasoning loops (subagent action calls -> variable updates -> next LLMStep -> final summary) are NOT aggregated into the response payload. A trace where `prompt_response.tool_invocations: null` on the first subagent LLMStep does NOT mean the agent failed to call actions -- only that the CLI captured the response before subsequent iterations completed. **For end-to-end functional validation use:** (a) Agentforce Builder UI (Test panel), or (b) a real `Agent.generateAiAgentResponse` invocation from Apex (which is what production runs anyway), or (c) trigger the actual production path (e.g., insert a test EmailMessage to a Resend Email Testing recordtype Case and check `Agent_Activity_Log__c` after the async Queueable completes) | Production-validated on PlusGradeFullSB 2026-05-16 when CLI `preview send --authoring-bundle Email_Analysis_Agent` reported empty agent responses for 5 live tests, but Builder UI test + real EmailMessage trigger test both succeeded end-to-end. Spent ~1 hour chasing the CLI false-negative before the Builder UI test exposed it. Use the right test surface for the right phase: CLI for session-debugging individual steps, Builder UI / production-path for functional verification |
| 11 | 2026-05-16 | `Agent_Activity_Log__c.AI_Tool_Name__c` reflects the active agent in use | The trigger-path (`InboundEmailOrchestrator.invokeAndDecide` lines 213, 227) and SFMC queueable (`SfmcCalloutQueueable.buildLog` line 192) **hardcode** `'Email Resend Agent'` as `AI_Tool_Name__c`. After the cutover to `Email_Analysis_Agent` v6, the logs still say "Email Resend Agent" -- misleading for reporting and observability. The actual agent invoked is `ResendConfiguration.getConfig().agentApiName` ('Email_Analysis_Agent') but the log label doesn't track the cutover. **Recommendation:** refactor to read the label from `ResendConfiguration` (add an `agentLogLabel` field) or derive from `agentApiName` at log-write time | Observed during end-to-end cutover verification: Case 500As00000WAZa1IAH with EmailMessage 02sAs000007HOGPIA4 logged `ALOG-01299/01300` with `AI_Tool_Name__c = 'Email Resend Agent'` even though the agent that actually ran was `Email_Analysis_Agent v6`. File a maintenance ticket -- not blocking |

---

## 18. Official References

- [Agentforce DX -- Code Your Agent](https://developer.salesforce.com/docs/ai/agentforce/guide/agent-dx-nga-script.html)
- [Agentforce DX -- Publish](https://developer.salesforce.com/docs/ai/agentforce/guide/agent-dx-nga-publish.html) (verify against current CLI; doc lags shipping flags)
- [forcedotcom/sf-skills `developing-agentforce`](https://github.com/forcedotcom/sf-skills/tree/main/skills/developing-agentforce) -- full reference library, lifecycle, validation, traces
- [trailheadapps/agent-script-recipes](https://github.com/trailheadapps/agent-script-recipes) -- 30+ working `.agent` files and Apex backing patterns
- [Agent Script Canonical Reference](../salesforce-agentforce-script/SKILL.md) -- companion file in this skill set

---

*Agentforce Authoring Bundle Lifecycle Guide | v2.0 | Last verified 2026-05-16*

