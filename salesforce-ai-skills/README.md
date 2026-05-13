# Salesforce AI Skills — Guideline Library

A curated set of standalone Markdown guideline documents for AI-assisted Salesforce development. Each file is a self-contained specification governing how an AI agent should think, plan, and produce output for a specific Salesforce component area.

Portable across Claude, Codex/ChatGPT, Amazon Q Developer, GitHub Copilot, and Claude Agents (SDK). Version-controlled alongside your source code.

> **About the `docs/` folder:** The `docs/` folder in this repo contains architecture designs, requirements, and component documentation — it is **reference material only**. Read a docs file when you need business context for a specific task; do not treat it as a task-execution input like the skill files.

> **For Claude Code:** See `salesforce-ai-skills/CLAUDE.md` — it is the behavioral contract read automatically at session start and contains project-specific rules on top of this library.

---

## Guideline File Index

| File | Covers | Attach when… |
|---|---|---|
| `global_ai_development_guidelines.md` | Architecture layering, naming, security, governor limits, bulkification, DoD, anti-patterns | **Always — base context for every task** |
| `flow_guidelines.md` | Record-triggered flow design, before/after-save rules, fault paths, loop anti-patterns, idempotency | Any Flow work |
| `apex_guidelines.md` | Apex class design, sharing models, CRUD/FLS, service layer, async, callouts, developer header | Any Apex work |
| `trigger_guidelines.md` | One-trigger-per-object, handler pattern, recursion prevention, bulk safety | Any trigger work |
| `testing_guidelines.md` | AAA pattern, Jest tests, callout mocking, test data factories, bulk/negative tests | Any test class work |
| `metadata_guidelines.md` | Custom objects/fields, record types, validation rules, Custom Metadata Types | Any schema or declarative metadata work |
| `lwc_guidelines.md` | LWC architecture, wire adapters, error states, accessibility, Jest, event patterns | Any LWC work |
| `integration_guidelines.md` | Named Credentials, Platform Events, CDC, callouts, idempotency, error handling | Any integration work |
| `deployment_guidelines.md` | Salesforce CLI, package.xml, deployment order, validation, quick deploy, rollback | Any deployment work |
| `observability_logging_guidelines.md` | Logging patterns, Platform Event log shipping, correlation IDs, alerting | Any logging/monitoring work |
| `permission_set_guidelines.md` | Permission sets, PSGs, muting permission sets, least-privilege, profile migration | Any access control work |
| `flexipage_guidelines.md` | Lightning App Builder, Dynamic Forms, Dynamic Actions, page activation | Any Lightning page work |
| `prompt_template_guidelines.md` | Prompt Builder, grounding, merge fields, output safety, versioning | Any Prompt Builder work |
| `email_template_guidelines.md` | Lightning/Classic email templates, merge fields, dynamic content, deployment | Any email template work |
| `agentforce_script_guidelines.md` | Agent instructions, topic/action definitions, guardrails, response tone | Any Agentforce agent scripting |
| `agentforce_builder_guidelines.md` | GenAiPlannerBundle, GenAiPlugin, GenAiFunction, orchestration, model config | Any Agentforce Builder metadata |
| `visualforce_guidelines.md` | VF page and controller design, view state management, CRUD/FLS in controllers, PDF rendering, legacy migration | When writing or reviewing Visualforce pages or controllers |
| `ai_agent_prompt_templates.md` | Reusable prompt starters for common Salesforce tasks | Starting a new AI-assisted task |

---

## How To Use With Each AI Agent

### Claude Agents (Anthropic Agent SDK)

When spawning a subagent for Salesforce work, include the relevant guideline file(s) in the agent's system prompt or task prompt.

**Minimal system prompt pattern:**
```
You are a Salesforce developer agent. Follow all rules in the attached guideline files.
Read global_ai_development_guidelines.md first, then the component-specific file for this task.
Before writing any code or flow XML, check the "Common AI Mistakes to Avoid" table in the matching file.
```

**Recommended files per agent role:**

| Agent role | Files to include |
|---|---|
| Solution Architect | `global_ai_development_guidelines.md` + component file(s) for the task |
| Developer | `global_ai_development_guidelines.md` + component file(s) + `testing_guidelines.md` |
| QA Reviewer | `global_ai_development_guidelines.md` + component file(s) being reviewed |
| Deployment agent | `global_ai_development_guidelines.md` + `deployment_guidelines.md` |

**Lessons learned:** The "Common AI Mistakes to Avoid" table in each skill file is the persistent lesson ledger. Agents must check it before producing output and append new lessons at the end of a session (see `CLAUDE.md` Section 6 for routing rules).

---

### Claude (claude.ai / API)

1. Upload or paste the relevant `.md` file(s) at the start of the conversation.
2. Instruct Claude: *"Follow all rules in the attached guideline file for every response in this session."*
3. Always include `global_ai_development_guidelines.md` as base context.

**Tip:** In Claude Projects, add `global_ai_development_guidelines.md` to persistent instructions so it applies automatically to every conversation.

---

### Codex / ChatGPT (OpenAI)

1. In **ChatGPT Projects**, paste guideline file contents into Custom Instructions or Project Instructions.
2. For API/Codex, place the guideline content in the `system` message before user messages.
3. Alternatively, upload the `.md` file as an attachment and reference it in the first message.

---

### Amazon Q Developer

1. Paste guideline file contents as the first chat message: *"These are my team's Salesforce development standards. Follow them for all responses in this session:"*
2. In IDEs (VS Code, JetBrains), place the guideline file in the project root and reference it in the prompt.
3. CLI: `cat global_ai_development_guidelines.md | amazon-q chat --context -`
4. Re-attach at the start of each session — Q Developer does not persist context across sessions.

---

### GitHub Copilot

1. **Recommended:** Add guideline content to `.github/copilot-instructions.md` — Copilot reads this automatically for all chat and code completion in the repo.
2. Copilot Chat: `#file:salesforce-ai-skills/apex_guidelines.md Review this class against these standards.`
3. Copilot Enterprise: add guideline files to the Knowledge Base for org-wide availability.

---

## Common Multi-File Combinations

| Task | Attach |
|---|---|
| Apex with tests | `global` + `apex_guidelines` + `testing_guidelines` |
| Flow with error logging | `global` + `flow_guidelines` + `observability_logging_guidelines` |
| Full integration feature | `global` + `integration_guidelines` + `testing_guidelines` + `deployment_guidelines` |
| LWC with Apex data layer | `global` + `lwc_guidelines` + `apex_guidelines` |
| New object + access control | `global` + `metadata_guidelines` + `permission_set_guidelines` |
| Agentforce agent (end to end) | `global` + `agentforce_script_guidelines` + `agentforce_builder_guidelines` + `prompt_template_guidelines` |
| Trigger + handler rewrite | `global` + `trigger_guidelines` + `apex_guidelines` + `testing_guidelines` |
| Code review | `global` + component file(s) being reviewed |

**Token tip:** Attaching more than 3–4 files consumes significant context. For large tasks, attach `global_ai_development_guidelines.md` as base and rotate component files per sub-task.

---

## Non-Negotiable Standards (Quick Reference)

These apply to every task. Full rules are in the skill files.

- Developer header on every Apex class (Developer: Naresh, Title: Senior Salesforce Developer)
- One trigger per object — handler class pattern, no business logic in trigger body
- Before-save flows for same-record updates; after-save for related records and actions
- Fault path on every Flow DML and action element
- No hardcoded IDs, endpoints, tokens, or secrets anywhere
- Custom Metadata Types for non-secret configuration values
- Permission sets for feature access; profiles for baseline only
- Every agent response: Plan → Files → Implementation → Security → Testing → Validation → Rollback

---

*Library maintained by Naresh | Senior Salesforce Developer | April 2026*
