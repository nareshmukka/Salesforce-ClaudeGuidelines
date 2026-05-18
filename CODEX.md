# CODEX.md -- Salesforce AI Skills Guide for VS Code Inline Chat

## Purpose
Default operating contract for Codex/ChatGPT inline chat in this repository.

## Startup checklist
1. Read this file.
2. Read `salesforce-ai-skills/SKILL_INDEX.md`.
3. Read `salesforce-ai-skills/skills/salesforce-global-development/SKILL.md`.
4. Read `LESSONS.md`.
5. Read task skill(s) from `salesforce-ai-skills/skills/<skill-name>/SKILL.md`.
6. Inspect source files before proposing edits.
7. Make smallest safe local change.
8. Validate locally.
9. Summarize security/testing/rollback.

## Portability rules
- Do not add company names, person names, target environment aliases, instance URLs, record IDs, secrets, or customer-specific process names to shared skills or agents.
- Use placeholders such as `<target-env-alias>`, `<manifest-path>`, `<agent-api-name>`, and `<object-api-name>` in reusable examples.
- Put project-specific details in local working notes or implementation files, not in reusable agent/skill instructions.

## VS Code Copilot discovery
VS Code Copilot discovers project skills from default folders such as `.github/skills`, `.claude/skills`, and `.agents/skills`. This repo stores skills in `salesforce-ai-skills/skills`, so `.vscode/settings.json` adds that folder to `chat.agentSkillsLocations`.

If skills do not appear, run `Chat: Open Customizations`, open the Skills tab, or type `/skills` in chat. Then reload the window after changing settings.

## Skill routing quick map
- Apex: `salesforce-ai-skills/skills/salesforce-apex/SKILL.md`
- Apex debugging/logs: `salesforce-ai-skills/skills/salesforce-apex-debugging/SKILL.md`
- Trigger: `salesforce-ai-skills/skills/salesforce-trigger/SKILL.md`
- Flow: `salesforce-ai-skills/skills/salesforce-flow/SKILL.md`
- LWC: `salesforce-ai-skills/skills/salesforce-lwc/SKILL.md`
- Testing: `salesforce-ai-skills/skills/salesforce-testing/SKILL.md`
- Metadata: `salesforce-ai-skills/skills/salesforce-metadata/SKILL.md`
- Validation Rules: `salesforce-ai-skills/skills/salesforce-validation-rules/SKILL.md`
- Integration: `salesforce-ai-skills/skills/salesforce-integration/SKILL.md`
- Deployment: `salesforce-ai-skills/skills/salesforce-deployment/SKILL.md`
- Permissions: `salesforce-ai-skills/skills/salesforce-permissions/SKILL.md`
- SOQL / data retrieval: `salesforce-ai-skills/skills/salesforce-soql/SKILL.md`
- Data operations: `salesforce-ai-skills/skills/salesforce-data-operations/SKILL.md`
- Data Cloud: `salesforce-ai-skills/skills/salesforce-datacloud/SKILL.md`
- OmniStudio: `salesforce-ai-skills/skills/salesforce-omnistudio/SKILL.md`
- UI Bundle: `salesforce-ai-skills/skills/salesforce-ui-bundle/SKILL.md`
- Connected Apps: `salesforce-ai-skills/skills/salesforce-connected-apps/SKILL.md`
- Custom app/tab/list view UI: `salesforce-ai-skills/skills/salesforce-custom-app-ui/SKILL.md`
- Custom Lightning Types: `salesforce-ai-skills/skills/salesforce-custom-lightning-types/SKILL.md`
- B2B Commerce: `salesforce-ai-skills/skills/salesforce-b2b-commerce/SKILL.md`
- Diagrams: `salesforce-ai-skills/skills/salesforce-diagrams/SKILL.md`
- Docs research: `salesforce-ai-skills/skills/salesforce-docs-research/SKILL.md`
- Agentforce Script: `salesforce-ai-skills/skills/salesforce-agentforce-script/SKILL.md`
- Agentforce Authoring Bundle: `salesforce-ai-skills/skills/salesforce-agentforce-authoring-bundle/SKILL.md`
- Agentforce Builder: `salesforce-ai-skills/skills/salesforce-agentforce-builder/SKILL.md`
- Agentforce Testing: `salesforce-ai-skills/skills/salesforce-agentforce-testing/SKILL.md`
- Agentforce Service Assistant: `salesforce-ai-skills/skills/salesforce-service-assistant/SKILL.md`
- Prompt Templates: `salesforce-ai-skills/skills/salesforce-prompt-template/SKILL.md`
- AI prompt templates: `salesforce-ai-skills/skills/salesforce-ai-prompt-templates/SKILL.md`
- Media search: `salesforce-ai-skills/skills/salesforce-media-search/SKILL.md`

## Non-negotiable safety rules
- Do not deploy unless explicitly asked.
- Do not publish/activate Agentforce agents unless explicitly approved.
- Ask before destructive changes.
- Ask before customer-facing write/send/post actions.
- Ask before live data load/export/update/delete, auth rotation, connector activation, or storefront/agent activation.
- Never bypass CRUD/FLS/sharing.
- Never hardcode IDs/secrets/tokens.

## Library validation
After changing any skill or routing doc, run:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/validate-salesforce-ai-skills.ps1
```

## Codex Agent Pipeline

For structured project work, use the Codex agent definitions under `.codex/agents/`.

| Agent | Role |
|---|---|
| `codex-sf-lead` | Orchestrator. Classifies the task, selects skills, delegates to Architect -> Dev -> QA, enforces gates, and owns the final response. |
| `codex-sf-architect` | Designs the Salesforce solution, dependency order, acceptance criteria, validation plan, and rollback plan. |
| `codex-sf-dev` | Implements scoped local changes after lead/architect direction. |
| `codex-sf-qa` | Reviews implementation against design, skills, tests, security, deployment safety, and lesson candidates. |

Default entry point for non-trivial Codex work: `codex-sf-lead`. The lead manages the other agents; direct worker use is only for single-stage tasks.

## Codex Agent Team Rules

- Default entry point remains `codex-sf-lead`.
- `codex-sf-lead` must classify task size before delegating.
- `codex-sf-lead` must create a Context Packet for non-trivial work.
- Do not invoke Architect/Dev/QA for trivial work.
- Worker agents must follow selected skills from the Context Packet.
- Do not let workers independently load broad or unrelated skills.
- Full pipeline is required for Agentforce, Flow, Integration, Permission, Deployment-sensitive, Data Cloud, Service Assistant, or multi-metadata changes.
- Reference `salesforce-ai-skills/agent-teams/CODEX_AGENT_TEAM_PLAYBOOK.md`.
- Amazon Q rules are separate and should not be mixed into Codex agent definitions.

## Standard inline chat prompts
### Review only
"Read CODEX.md + relevant skills. Review `{targetFile}` only. Do not implement changes. Do not deploy. Report security, bulkification, test gaps, and rollback notes."

### Implement local change only
"Read CODEX.md + relevant skills. Implement local changes for `{task}` in `{targetFiles}` only. Inspect files first. Do not deploy/publish/activate. Provide tests and rollback plan."

### Prepare package.xml only
"Read CODEX.md + deployment + metadata skills. Prepare `manifest/package.xml` for `{scope}` only. Do not run deployment commands. Include validation command examples only."

## Concrete task examples
- Apex review: "Read CODEX.md + Apex + Testing skills. Review `{className}` for sharing model, CRUD/FLS, bulk safety, partial DML handling, and tests."
- LWC review: "Read CODEX.md + LWC + Apex + Testing skills. Review `{componentName}` for wire vs imperative calls, error states, a11y, and Jest gaps."
- Flow review: "Read CODEX.md + Flow + Observability skills. Review `{flowName}` for before/after-save fit, idempotency, fault paths, and loop DML anti-patterns."
- Agentforce script review: "Read CODEX.md + Agentforce Script skill. Review `{agentName}` instructions for guardrails, grounding, and confirmation gates."
- Agentforce bundle review: "Read CODEX.md + Agentforce Authoring Bundle skill. Review `.agent` blocks (`system/config/start_agent/subagent`) and action contracts; do not publish/activate."
- Integration review: "Read CODEX.md + Integration + Observability skills. Review `{serviceName}` for Named Credential use, retry/idempotency, DTO contracts, and correlation logging."
- Deployment review: "Read CODEX.md + Deployment skill. Validate release plan for `{changeSet}` with check-only strategy and rollback notes; do not deploy."

## Response format
- Understanding
- Files inspected
- Plan / changes made
- Security review
- Tests / validation
- Deployment notes
- Rollback notes
