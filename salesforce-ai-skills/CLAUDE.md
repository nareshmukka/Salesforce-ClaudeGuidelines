# CLAUDE.md — Behavioral Contract for Claude Code and Claude Agents

**Project:** Plusgrade DEV-FLOWMIGRATION | **Maintained by:** Naresh | Senior Salesforce Developer

This file is read automatically by **Claude Code** at session start and must be included in the system prompt for any **Claude Agent** (spawned subagent) working in this repo. It defines what to read, what to do, and how to record lessons. For the full guideline library index and usage instructions across all AI agents, see `salesforce-ai-skills/README.md`.

---

## 1. Repository Structure

```
force-app/main/default/    ← Deployable Salesforce metadata
salesforce-ai-skills/      ← AI guideline library — rules, patterns, lessons learned
docs/                      ← Reference only: architecture designs, requirements, component docs
manifest/                  ← Deployment manifests
scripts/                   ← Utility scripts
```

> **docs/ is reference material.** Read a docs file only when you need business context or architecture background for a specific task — not as a routine pre-task step.

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

All paths are relative to `salesforce-ai-skills/`. For multi-component tasks, read all relevant files.

**Before writing any code or flow XML:** check the **"Common AI Mistakes to Avoid"** table in the matching skill file. These record mistakes made in this project — do not repeat them.

---

## 3. Project Context — Case Flow Migration

- **Do NOT deactivate or delete old flows.** Naresh does that manually after sandbox validation.
- **Do NOT activate new flows.** Deploy as `status = Draft`. Naresh activates manually.
- **Org alias:** `DEV-FLOWMIGRATION` | **Manifest:** `manifest/package-case-flow-optimization.xml`
- **Test classes:** Deferred until after sandbox functional testing.

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
  --target-org DEV-FLOWMIGRATION \
  --dry-run --test-level RunLocalTests --wait 60
```

13 pre-existing Opportunity test failures are expected and do not block Case deployment.

---

## 5. Session Startup Checklist

1. Read this file.
2. Read `global_ai_development_guidelines.md`.
3. Read the skill file matching the task (Section 2 table).
4. Check "Common AI Mistakes to Avoid" in that skill file.
5. If business context is needed, read the relevant `docs/` file — only when required.
6. Apply every rule. No exceptions.

---

## 6. Recording New Lessons Learned

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
| Process: reading source before writing, validate frequently, scope discipline | `global_ai_development_guidelines.md` |

**How:** Find the "Common AI Mistakes to Avoid" table in the skill file and append one row:
```
| <next #> | <what was wrong — brief> | <correct approach — actionable> |
```
For `global_ai_development_guidelines.md` add to the "DON'T" table in Section 12.2. Keep entries to one row. No lessons in CLAUDE.md.

---

*CLAUDE.md | Plusgrade DEV-FLOWMIGRATION | Naresh | Senior Salesforce Developer*
