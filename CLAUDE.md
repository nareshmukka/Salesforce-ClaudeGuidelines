# CLAUDE.md — Behavioral Contract for Claude Code and Claude Agents

**Project:** Plusgrade PlusGradeFullSB | **Maintained by:** Naresh | Senior Salesforce Developer

This file is read automatically by **Claude Code** at session start and must be included in the system prompt for any **Claude Agent** (spawned subagent) working in this repo. It defines what to read, what to do, and how to record lessons. For the full guideline library index and cross-agent usage instructions, see [README.md](README.md).

---

## 1. Repository Structure

```
force-app/main/default/    ← Deployable Salesforce metadata
salesforce-ai-skills/      ← AI guideline library — rules, patterns, lessons learned
docs/                      ← Reference: architecture, requirements (per-requirement docs created by /sf-architect)
manifest/                  ← Deployment manifests
scripts/                   ← Utility scripts
.claude/                   ← Agentic pipeline: commands, templates, runtime config
```

> **docs/ is reference material.** Read a docs file only when you need business context or architecture background for a specific task — not as a routine pre-task step. The exception is `docs/<slug>.md` files created by the `/sf-architect` pipeline; those are the active working doc for the current requirement.

---

## 2. What to Read Before Any Task

**Always read first:**
`salesforce-ai-skills/global_ai_development_guidelines.md` — master contract, architecture, security, anti-patterns, DoD.

**Then read the file matching your task:**

| Task | Skill file |
|---|---|
| Flow (record-triggered, autolaunched, screen) | `flow_guidelines.md` |
| Apex class, service, batch, queueable, invocable | `apex_guidelines.md` |
| Apex trigger or trigger handler | `trigger_guidelines.md` |
| Apex or Jest test class | `testing_guidelines.md` |
| Custom object, field, validation rule, CMDT | `metadata_guidelines.md` |
| Lightning Web Component | `lwc_guidelines.md` |
| Callout, Platform Event, CDC, integration | `integration_guidelines.md` |
| Deployment, package.xml, validation | `deployment_guidelines.md` |
| Logging, error tracking, monitoring | `observability_logging_guidelines.md` |
| Permission set or access control | `permission_set_guidelines.md` |
| Agentforce agent topic / instruction | `agentforce_script_guidelines.md` |
| Agentforce authoring bundle (.agent DSL), new agent from scratch, deploy, test, lessons learned | `agentforce_authoring_bundle_guide.md` |
| Agentforce Builder metadata | `agentforce_builder_guidelines.md` |
| Email template | `email_template_guidelines.md` |
| Prompt Builder template | `prompt_template_guidelines.md` |
| Lightning App Builder page | `flexipage_guidelines.md` |
| Visualforce page or controller | `visualforce_guidelines.md` |
| Agentforce Service Assistant on Case (this org-specific implementation) | `service_assistant_guidelines.md` |

All paths are relative to `salesforce-ai-skills/`. For multi-component tasks, read all relevant files.

**Before writing any code or flow XML:** check the **"Common AI Mistakes to Avoid"** table in the matching skill file. These record mistakes made in this project — do not repeat them.

**Canonical sources** that ground the skill files (for cross-checking):
- Salesforce official docs at `developer.salesforce.com/docs/*` (JS-rendered; WebFetch sometimes returns shell only — use WebSearch first then WebFetch the result URL)
- [forcedotcom/sf-skills](https://github.com/forcedotcom/sf-skills) — Salesforce's authored skill library (Apex, Flow, LWC, Agentforce, metadata, etc.)
- [trailheadapps/agent-script-recipes](https://github.com/trailheadapps/agent-script-recipes) — 30+ working `.agent` files demonstrating canonical patterns

Both repos can be cloned locally and read directly for ground truth.

---

## 3. Project Context — Case Flow Migration

- **Do NOT deactivate or delete old flows.** Naresh does that manually after sandbox validation.
- **Do NOT activate new flows.** Deploy as `status = Draft`. Naresh activates manually.
- **Org alias:** `PlusGradeFullSB` | **Manifest:** `manifest/package-case-flow-optimization.xml` (or a dedicated per-delivery manifest when scoped tighter)
- **Test classes:** Deferred until after sandbox functional testing.
- **PII-handling Agentforce agents:** `<logPrivateConversationData>false</logPrivateConversationData>` MUST be re-asserted via a Bot-only override manifest after every `sf agent publish authoring-bundle` (the publish step auto-resets it to `true`). See `agentforce_authoring_bundle_guide.md` §8 for the override pattern.

| Flow | triggerOrder | Purpose |
|---|---|---|
| `Case_BS_Normalize_Case` | 10 (before-save) | Field normalization |
| `Case_AS_Status_SLA` | 10 | Status log, SLA timestamps, RH SLA calcs |
| `Case_AS_Escalation` | 20 | Child case creation on escalation |
| `Case_AS_Linked_Case` | 30 | Linked_Case__c for duplicate/merge/split |
| `Case_AS_Routing` | 40 | Owner follower, product lookup, PBU |
| `Case_AS_Notifications` | 50 | Nexus email alerts (blocked on OV-14) |

| Apex Class | Role |
|---|---|
| `CaseTrigger` / `CaseTriggerHandler` | Single trigger → handler dispatch |
| `CaseEscalationService` | `@InvocableMethod` — escalation paths |
| `CaseLinkedCaseService` | `@InvocableMethod` — duplicate/merge/split |
| `CaseListViewService` | Platform event publisher |
| `CaseAcknowledgementService` | Auto-acknowledge on Resolved |

---

## 4. Validation Command

Run after every significant change. Zero component errors required.

```bash
sf project deploy start \
  --manifest manifest/package-case-flow-optimization.xml \
  --target-org PlusGradeFullSB \
  --dry-run --test-level RunLocalTests --wait 60
```

13 pre-existing Opportunity test failures are expected and do not block Case deployment.

---

## 5. Session Startup Checklist

1. Read this file.
2. Read `salesforce-ai-skills/global_ai_development_guidelines.md`.
3. Read the skill file matching the task (Section 2 table).
4. Check "Common AI Mistakes to Avoid" in that skill file.
5. If business context is needed, read the relevant `docs/` file — only when required.
6. Apply every rule. No exceptions.

---

## 6. Recording New Lessons Learned

Every skill file carries two complementary lesson ledgers — together they form the project's **second brain**: a continuously updated, battle-tested knowledge base on top of Salesforce's official docs.

### Two lesson types

| Type | Captures | Format | When to use |
|---|---|---|---|
| **Common AI Mistakes to Avoid** | Reactive — AI/developer errors that should not repeat | `\| # \| Mistake (brief) \| Correct approach \|` | When a code review or production incident reveals that an AI agent or developer produced something wrong against the existing rules |
| **Empirical Findings & Implementation Notes** | Proactive — gaps where Salesforce's documented approach doesn't work in this org/version/feature combination; the working alternative | `\| # \| Date \| Documented approach \| What actually works \| Why / Context \|` | When implementation reveals that the official docs are incomplete, wrong for our context, or that a working alternative exists. The date column matters — Salesforce evolves; tag every finding |

Both tables live in the same skill file. The Common AI Mistakes table is reactive prevention; the Empirical Findings table is proactive knowledge augmentation. Over many projects this dual-layer builds a Plusgrade-specific knowledge graph that goes beyond what any single Salesforce doc page can offer.

### Routing — which skill file does the lesson go to?

When a mistake is discovered or a new constraint confirmed, add it to the **correct skill file** — not to this file.

| Lesson type | Skill file to update |
|---|---|
| Flow XML structure, canvas mode, element ordering, filterFormula, decision connectors | `flow_guidelines.md` |
| Apex patterns, bulk safety, allOrNone, hardcoded IDs, invocable signatures | `apex_guidelines.md` |
| Trigger design, recursion, handler pattern | `trigger_guidelines.md` |
| Test patterns, mocking, coverage, test data factories | `testing_guidelines.md` |
| Deployment order, package.xml, check-only, rollback | `deployment_guidelines.md` |
| Custom objects, fields, validation rules, Custom Metadata Types | `metadata_guidelines.md` |
| LWC architecture, wire adapters, event patterns, Jest | `lwc_guidelines.md` |
| Callouts, Named Credentials, Platform Events, idempotency | `integration_guidelines.md` |
| Logging patterns, AppLog, correlation IDs | `observability_logging_guidelines.md` |
| Permission sets, PSGs, access control | `permission_set_guidelines.md` |
| Agentforce agent topics, instructions, guardrails | `agentforce_script_guidelines.md` |
| Agentforce authoring bundle: ID injection, flow output traps, publish command, lessons | `agentforce_authoring_bundle_guide.md` |
| Agentforce Builder metadata, orchestration, model config | `agentforce_builder_guidelines.md` |
| Email templates, merge fields, dynamic content | `email_template_guidelines.md` |
| Prompt Builder templates, grounding, merge fields | `prompt_template_guidelines.md` |
| Lightning App Builder pages, Dynamic Forms, visibility rules | `flexipage_guidelines.md` |
| Visualforce pages, controllers, view state | `visualforce_guidelines.md` |
| Agentforce Service Assistant on Case — Plusgrade implementation specifics | `service_assistant_guidelines.md` |
| Ready-to-use Agentforce authoring + Apex caller + LWC integration templates | `ai_agent_prompt_templates.md` |
| Process: reading source before writing, validate frequently, scope discipline | `global_ai_development_guidelines.md` |

**How — Common AI Mistakes to Avoid:** Find the table in the skill file and append one row:
```
| <next #> | <what was wrong — brief> | <correct approach — actionable> |
```
For `global_ai_development_guidelines.md` add to the "DON'T" table in Section 12.2. Keep entries to one row.

**How — Empirical Findings & Implementation Notes:** Find (or create, if first) the "Empirical Findings & Implementation Notes" table in the skill file and append one row:
```
| <next #> | YYYY-MM-DD | <documented approach — what Salesforce docs say> | <what actually works — the workaround/alternative> | <why / context — org version, feature interaction, observed failure> |
```
Always date-stamp. Always cite the source (Salesforce doc URL where the documented approach was claimed). No lessons in CLAUDE.md.

The `/sf-lead` pipeline (see Section 7) automates this write-back: QA proposes lesson candidates of both types, Lead reviews and appends to the right file/table with a dedup check.

---

## 7. Agentic Pipeline

For structured project work, this repo provides a four-stage agentic pipeline under [.claude/commands/](.claude/commands/):

| Command | Role |
|---|---|
| `/sf-lead` | Orchestrator. Classifies the task (new / modification / trivial), runs Architect → Developer → QA, enforces gates, writes lessons-learned, produces the final report. |
| `/sf-architect` | Validates requirements, designs the solution, creates or updates `docs/<slug>.md`, splits open questions into BLOCKING vs ASSUMPTION. |
| `/sf-developer` | Implements Apex / Flows / LWC / metadata per the architect's design. Updates the requirement doc. |
| `/sf-qa` | Reviews against design + skill-file standards, runs DoD checklist, proposes lesson candidates. |

Runtime configuration (org alias, manifest, author, defaults, project rules) lives at [.claude/sf-config.json](.claude/sf-config.json) — single source of truth, no values are hardcoded in the command prompts.

New requirements get a working doc at `docs/<slug>.md` created from [.claude/templates/requirement-doc.md](.claude/templates/requirement-doc.md). Modifications reuse the existing doc.

**Default entry point for any non-trivial task:** `/sf-lead <task description>`. For ad-hoc one-shot work without the pipeline, follow Sections 2–6 above and use the prompt templates in `salesforce-ai-skills/ai_agent_prompt_templates.md`.

---

*CLAUDE.md | Plusgrade PlusGradeFullSB | Naresh | Senior Salesforce Developer*
