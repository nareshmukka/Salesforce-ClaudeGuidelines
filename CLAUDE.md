# CLAUDE.md -- Behavioral Contract for Claude Code and Claude Agents

**Project:** Plusgrade PlusGradeFullSB | **Maintained by:** Naresh | Senior Salesforce Developer

This file is read automatically by **Claude Code** at session start and must be included in the system prompt for any **Claude Agent** (spawned subagent) working in this repo. It defines what to read, what to do, and how to record lessons. For the full guideline library index and cross-agent usage instructions, see [README.md](README.md).

---

## 1. Repository Structure

```
force-app/main/default/    <- Deployable Salesforce metadata
salesforce-ai-skills/      <- AI guideline library -- rules, patterns, lessons learned
docs/                      <- Reference: architecture, requirements, and working notes
manifest/                  <- Deployment manifests
scripts/                   <- Utility scripts
.claude/                   <- Claude agent definitions
.codex/                    <- Codex agent definitions
```

> **docs/ is reference material.** Read a docs file only when you need business context or architecture background for a specific task -- not as a routine pre-task step. If a lead/architect creates a task-specific working note under `docs/`, that file becomes active context for that requirement.

---

## 2. What to Read Before Any Task

**Always read first:**
1. `salesforce-ai-skills/SKILL_INDEX.md` -- complete routing index.
2. `salesforce-ai-skills/skills/salesforce-global-development/SKILL.md` -- master contract, architecture, security, anti-patterns, DoD.

**Then read the file matching your task:**

| Task | Skill file |
|---|---|
| Flow (record-triggered, autolaunched, screen) | `salesforce-ai-skills/skills/salesforce-flow/SKILL.md` |
| Apex class, service, batch, queueable, invocable | `salesforce-ai-skills/skills/salesforce-apex/SKILL.md` |
| Apex logs, runtime exceptions, governor-limit debugging | `salesforce-ai-skills/skills/salesforce-apex-debugging/SKILL.md` |
| Apex trigger or trigger handler | `salesforce-ai-skills/skills/salesforce-trigger/SKILL.md` |
| Apex or Jest test class | `salesforce-ai-skills/skills/salesforce-testing/SKILL.md` |
| Custom object, field, validation rule, CMDT | `salesforce-ai-skills/skills/salesforce-metadata/SKILL.md` |
| Validation rule formula, bypass, error message | `salesforce-ai-skills/skills/salesforce-validation-rules/SKILL.md` |
| Lightning Web Component | `salesforce-ai-skills/skills/salesforce-lwc/SKILL.md` |
| Callout, Platform Event, CDC, integration | `salesforce-ai-skills/skills/salesforce-integration/SKILL.md` |
| SOQL/SOSL query design or Salesforce data retrieval | `salesforce-ai-skills/skills/salesforce-soql/SKILL.md` |
| Data import/export/update/delete, seed data, Bulk API | `salesforce-ai-skills/skills/salesforce-data-operations/SKILL.md` |
| Data Cloud activation, connection, schema, harmonization, segment, activation | `salesforce-ai-skills/skills/salesforce-datacloud/SKILL.md` |
| OmniStudio OmniScript, FlexCard, DataMapper/DataRaptor, Integration Procedure, DataPacks | `salesforce-ai-skills/skills/salesforce-omnistudio/SKILL.md` |
| UI Bundle app/frontend/site, file upload, Agentforce conversation client, SLDS 2 uplift | `salesforce-ai-skills/skills/salesforce-ui-bundle/SKILL.md` |
| Connected App, OAuth, callback URL, external client access | `salesforce-ai-skills/skills/salesforce-connected-apps/SKILL.md` |
| Custom app, Lightning app, tab, list view, app navigation | `salesforce-ai-skills/skills/salesforce-custom-app-ui/SKILL.md` |
| Custom Lightning type / LightningTypeBundle contract | `salesforce-ai-skills/skills/salesforce-custom-lightning-types/SKILL.md` |
| B2B Commerce store, catalog, buyer group, entitlement, checkout | `salesforce-ai-skills/skills/salesforce-b2b-commerce/SKILL.md` |
| Mermaid/visual diagrams for architecture, data model, automation, Agentforce maps | `salesforce-ai-skills/skills/salesforce-diagrams/SKILL.md` |
| Current Salesforce docs/release/CLI/API verification | `salesforce-ai-skills/skills/salesforce-docs-research/SKILL.md` |
| Deployment, package.xml, validation | `salesforce-ai-skills/skills/salesforce-deployment/SKILL.md` |
| Logging, error tracking, monitoring | `salesforce-ai-skills/skills/salesforce-observability/SKILL.md` |
| Permission set or access control | `salesforce-ai-skills/skills/salesforce-permissions/SKILL.md` |
| Agentforce agent topic / instruction | `salesforce-ai-skills/skills/salesforce-agentforce-script/SKILL.md` |
| Agentforce authoring bundle (.agent DSL), new agent from scratch, deploy, test, lessons learned | `salesforce-ai-skills/skills/salesforce-agentforce-authoring-bundle/SKILL.md` |
| Agentforce tests, preview validation, traces, AiEvaluationDefinition | `salesforce-ai-skills/skills/salesforce-agentforce-testing/SKILL.md` |
| Agentforce Builder metadata | `salesforce-ai-skills/skills/salesforce-agentforce-builder/SKILL.md` |
| Email template | `salesforce-ai-skills/skills/salesforce-email-template/SKILL.md` |
| Prompt Builder template | `salesforce-ai-skills/skills/salesforce-prompt-template/SKILL.md` |
| Lightning App Builder page | `salesforce-ai-skills/skills/salesforce-flexipage/SKILL.md` |
| Visualforce page or controller | `salesforce-ai-skills/skills/salesforce-visualforce/SKILL.md` |
| Agentforce Service Assistant on Case (this org-specific implementation) | `salesforce-ai-skills/skills/salesforce-service-assistant/SKILL.md` |
| Media/image search for Salesforce docs, demos, enablement | `salesforce-ai-skills/skills/salesforce-media-search/SKILL.md` |

All paths are relative to the repository root. For multi-component tasks, read all relevant files.

**Before writing any code or flow XML:** check the **"Common AI Mistakes to Avoid"** table in the matching skill file. These record mistakes made in this project -- do not repeat them.

**Canonical sources** that ground the skill files (for cross-checking):
- Salesforce official docs at `developer.salesforce.com/docs/*` (JS-rendered; WebFetch sometimes returns shell only -- use WebSearch first then WebFetch the result URL)
- [forcedotcom/sf-skills](https://github.com/forcedotcom/sf-skills) -- Salesforce's authored skill library (Apex, Flow, LWC, Agentforce, metadata, etc.)
- [trailheadapps/agent-script-recipes](https://github.com/trailheadapps/agent-script-recipes) -- 30+ working `.agent` files demonstrating canonical patterns

Both repos can be cloned locally and read directly for ground truth.

---

## 3. Project Context -- Case Flow Migration

- **Do NOT deactivate or delete old flows.** Naresh does that manually after sandbox validation.
- **Do NOT activate new flows.** Deploy as `status = Draft`. Naresh activates manually.
- **Org alias:** `PlusGradeFullSB` | **Manifest:** `manifest/package-case-flow-optimization.xml` (or a dedicated per-delivery manifest when scoped tighter)
- **Test classes:** Deferred until after sandbox functional testing.
- **PII-handling Agentforce agents:** `<logPrivateConversationData>false</logPrivateConversationData>` MUST be re-asserted via a Bot-only override manifest after every `sf agent publish authoring-bundle` (the publish step auto-resets it to `true`). See `salesforce-ai-skills/skills/salesforce-agentforce-authoring-bundle/SKILL.md` Section 8 for the override pattern.

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
| `CaseTrigger` / `CaseTriggerHandler` | Single trigger -> handler dispatch |
| `CaseEscalationService` | `@InvocableMethod` -- escalation paths |
| `CaseLinkedCaseService` | `@InvocableMethod` -- duplicate/merge/split |
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
2. Read `salesforce-ai-skills/SKILL_INDEX.md`.
3. Read `salesforce-ai-skills/skills/salesforce-global-development/SKILL.md`.
4. Read the skill file matching the task (Section 2 table).
5. Check "Common AI Mistakes to Avoid" in that skill file.
6. If business context is needed, read the relevant `docs/` file -- only when required.
7. Apply every rule. No exceptions.

---

## 6. Recording New Lessons Learned

Every skill file carries two complementary lesson ledgers -- together they form the project's **second brain**: a continuously updated, battle-tested knowledge base on top of Salesforce's official docs.

### Two lesson types

| Type | Captures | Format | When to use |
|---|---|---|---|
| **Common AI Mistakes to Avoid** | Reactive -- AI/developer errors that should not repeat | `\| # \| Mistake (brief) \| Correct approach \|` | When a code review or production incident reveals that an AI agent or developer produced something wrong against the existing rules |
| **Empirical Findings & Implementation Notes** | Proactive -- gaps where Salesforce's documented approach doesn't work in this org/version/feature combination; the working alternative | `\| # \| Date \| Documented approach \| What actually works \| Why / Context \|` | When implementation reveals that the official docs are incomplete, wrong for our context, or that a working alternative exists. The date column matters -- Salesforce evolves; tag every finding |

Both tables live in the same skill file. The Common AI Mistakes table is reactive prevention; the Empirical Findings table is proactive knowledge augmentation. Over many projects this dual-layer builds a Plusgrade-specific knowledge graph that goes beyond what any single Salesforce doc page can offer.

### Routing -- which skill file does the lesson go to?

When a mistake is discovered or a new constraint confirmed, add it to the **correct skill file** -- not to this file.

| Lesson type | Skill file to update |
|---|---|
| Flow XML structure, canvas mode, element ordering, filterFormula, decision connectors | `salesforce-ai-skills/skills/salesforce-flow/SKILL.md` |
| Apex patterns, bulk safety, allOrNone, hardcoded IDs, invocable signatures | `salesforce-ai-skills/skills/salesforce-apex/SKILL.md` |
| Apex logs, trace flags, runtime errors, governor-limit diagnosis | `salesforce-ai-skills/skills/salesforce-apex-debugging/SKILL.md` |
| Trigger design, recursion, handler pattern | `salesforce-ai-skills/skills/salesforce-trigger/SKILL.md` |
| Test patterns, mocking, coverage, test data factories | `salesforce-ai-skills/skills/salesforce-testing/SKILL.md` |
| Deployment order, package.xml, check-only, rollback | `salesforce-ai-skills/skills/salesforce-deployment/SKILL.md` |
| Custom objects, fields, validation rules, Custom Metadata Types | `salesforce-ai-skills/skills/salesforce-metadata/SKILL.md` |
| Validation rule formula/bypass/error-message lessons | `salesforce-ai-skills/skills/salesforce-validation-rules/SKILL.md` |
| LWC architecture, wire adapters, event patterns, Jest | `salesforce-ai-skills/skills/salesforce-lwc/SKILL.md` |
| Callouts, Named Credentials, Platform Events, idempotency | `salesforce-ai-skills/skills/salesforce-integration/SKILL.md` |
| SOQL/SOSL selectivity, relationship query, aggregate query lessons | `salesforce-ai-skills/skills/salesforce-soql/SKILL.md` |
| Data import/export/load/delete, seed data, Bulk API lessons | `salesforce-ai-skills/skills/salesforce-data-operations/SKILL.md` |
| Data Cloud setup/schema/harmonization/segment/activation lessons | `salesforce-ai-skills/skills/salesforce-datacloud/SKILL.md` |
| OmniStudio OmniScript/FlexCard/DataMapper/IP/DataPack lessons | `salesforce-ai-skills/skills/salesforce-omnistudio/SKILL.md` |
| UI Bundle app/frontend/site/file/conversation-client lessons | `salesforce-ai-skills/skills/salesforce-ui-bundle/SKILL.md` |
| Connected App/OAuth/client access lessons | `salesforce-ai-skills/skills/salesforce-connected-apps/SKILL.md` |
| Custom app/tab/list view/navigation lessons | `salesforce-ai-skills/skills/salesforce-custom-app-ui/SKILL.md` |
| Custom Lightning type / LightningTypeBundle contract lessons | `salesforce-ai-skills/skills/salesforce-custom-lightning-types/SKILL.md` |
| B2B Commerce catalog/store/buyer/checkout lessons | `salesforce-ai-skills/skills/salesforce-b2b-commerce/SKILL.md` |
| Diagram conventions and architecture visualization lessons | `salesforce-ai-skills/skills/salesforce-diagrams/SKILL.md` |
| Docs lookup, release/API verification, source reliability lessons | `salesforce-ai-skills/skills/salesforce-docs-research/SKILL.md` |
| Logging patterns, AppLog, correlation IDs | `salesforce-ai-skills/skills/salesforce-observability/SKILL.md` |
| Permission sets, PSGs, access control | `salesforce-ai-skills/skills/salesforce-permissions/SKILL.md` |
| Agentforce agent topics, instructions, guardrails | `salesforce-ai-skills/skills/salesforce-agentforce-script/SKILL.md` |
| Agentforce authoring bundle: ID injection, flow output traps, publish command, lessons | `salesforce-ai-skills/skills/salesforce-agentforce-authoring-bundle/SKILL.md` |
| Agentforce testing, preview traces, AiEvaluationDefinition lessons | `salesforce-ai-skills/skills/salesforce-agentforce-testing/SKILL.md` |
| Agentforce Builder metadata, orchestration, model config | `salesforce-ai-skills/skills/salesforce-agentforce-builder/SKILL.md` |
| Email templates, merge fields, dynamic content | `salesforce-ai-skills/skills/salesforce-email-template/SKILL.md` |
| Prompt Builder templates, grounding, merge fields | `salesforce-ai-skills/skills/salesforce-prompt-template/SKILL.md` |
| Lightning App Builder pages, Dynamic Forms, visibility rules | `salesforce-ai-skills/skills/salesforce-flexipage/SKILL.md` |
| Visualforce pages, controllers, view state | `salesforce-ai-skills/skills/salesforce-visualforce/SKILL.md` |
| Agentforce Service Assistant on Case -- Plusgrade implementation specifics | `salesforce-ai-skills/skills/salesforce-service-assistant/SKILL.md` |
| Ready-to-use Agentforce authoring + Apex caller + LWC integration templates | `salesforce-ai-skills/skills/salesforce-ai-prompt-templates/SKILL.md` |
| Media/image search and attribution lessons | `salesforce-ai-skills/skills/salesforce-media-search/SKILL.md` |
| Process: reading source before writing, validate frequently, scope discipline | `salesforce-ai-skills/skills/salesforce-global-development/SKILL.md` |

**How -- Common AI Mistakes to Avoid:** Find the table in the skill file and append one row:
```
| <next #> | <what was wrong -- brief> | <correct approach -- actionable> |
```
For `salesforce-ai-skills/skills/salesforce-global-development/SKILL.md` add to the "DON'T" table in Section 12 2. Keep entries to one row.

**How -- Empirical Findings & Implementation Notes:** Find (or create, if first) the "Empirical Findings & Implementation Notes" table in the skill file and append one row:
```
| <next #> | YYYY-MM-DD | <documented approach -- what Salesforce docs say> | <what actually works -- the workaround/alternative> | <why / context -- org version, feature interaction, observed failure> |
```
Always date-stamp. Always cite the source (Salesforce doc URL where the documented approach was claimed). No lessons in CLAUDE.md.

The `claude-sf-lead` pipeline (see Section 7) automates this write-back: QA proposes lesson candidates of both types, Lead reviews and appends to the right file/table with a dedup check.

---

## 7. Claude Agent Pipeline

For structured project work, this repo provides Claude subagent definitions under [.claude/agents/](.claude/agents/):

| Agent | Role |
|---|---|
| `claude-sf-lead` | Orchestrator. Classifies the task, selects skills, delegates to Architect -> Dev -> QA, enforces gates, reviews lesson candidates, and owns the final report. |
| `sf-architect` | Validates requirements, designs the solution, identifies impacted metadata, splits open questions into BLOCKING vs ASSUMPTION, and defines acceptance criteria. |
| `sf-dev` | Implements Apex / Flow / LWC / metadata / docs inside the approved scope. Reports changed files, validation, and rollback notes. |
| `sf-qa` | Reviews against the design, skill-file standards, tests, security, deployment safety, and lesson candidates. |

**Default entry point for any non-trivial Claude task:** `claude-sf-lead`. The lead manages the other agents; do not invoke Architect, Dev, and QA independently unless the user explicitly asks for a single-stage review or implementation.

For ad-hoc one-shot work without the pipeline, follow Sections 2-6 above and use the prompt templates in `salesforce-ai-skills/skills/salesforce-ai-prompt-templates/SKILL.md`.

---

*CLAUDE.md | Plusgrade PlusGradeFullSB | Naresh | Senior Salesforce Developer*
