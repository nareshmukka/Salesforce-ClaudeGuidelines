# Salesforce AI Skill Index

This index is generated from each skill folder. Agents should use it for routing, then open the linked `SKILL.md`.

## Execution Rule

1. Read `salesforce-global-development/SKILL.md` first.
2. Select every task-specific skill that applies.
3. Read each selected `SKILL.md` before inspecting or editing implementation files.
4. Do not deploy, publish, activate, load/export live data, rotate auth, or run destructive changes without explicit approval.
5. Record validation, security review, deployment notes, and rollback notes in the final response.

## Inventory

| Skill | Description | File |
|---|---|---|
| `salesforce-agentforce-authoring-bundle` | Production Salesforce AI skill for Editing `.agent` bundles and related Agent Script block design. | [`SKILL.md`](skills/salesforce-agentforce-authoring-bundle/SKILL.md) |
| `salesforce-agentforce-builder` | Production Salesforce AI skill for GenAiFunction/GenAiPlugin/topic/action metadata design. | [`SKILL.md`](skills/salesforce-agentforce-builder/SKILL.md) |
| `salesforce-agentforce-script` | Production Salesforce AI skill for Agent instructions/topics/actions/guardrails editing. | [`SKILL.md`](skills/salesforce-agentforce-script/SKILL.md) |
| `salesforce-agentforce-testing` | Production Salesforce AI skill for Agentforce test specs, utterance coverage, preview validation, trace review, AiEvaluationDefinition, and agent quality scoring. | [`SKILL.md`](skills/salesforce-agentforce-testing/SKILL.md) |
| `salesforce-ai-prompt-templates` | Production Salesforce AI skill for Creating copy-paste prompts for Salesforce review/implementation. | [`SKILL.md`](skills/salesforce-ai-prompt-templates/SKILL.md) |
| `salesforce-apex` | Production Salesforce AI skill for Apex classes, invocables, async jobs, selectors/services. | [`SKILL.md`](skills/salesforce-apex/SKILL.md) |
| `salesforce-apex-debugging` | Production Salesforce AI skill for Apex debug logs, trace flags, governor-limit diagnosis, runtime exception triage, and production-safe debugging. | [`SKILL.md`](skills/salesforce-apex-debugging/SKILL.md) |
| `salesforce-b2b-commerce` | Production Salesforce AI skill for B2B Commerce store setup, catalog/product model, buyer groups, pricing, entitlement, checkout, and commerce metadata review. | [`SKILL.md`](skills/salesforce-b2b-commerce/SKILL.md) |
| `salesforce-connected-apps` | Production Salesforce AI skill for Connected Apps, OAuth, external client access, scopes, callback URLs, and integration auth review. | [`SKILL.md`](skills/salesforce-connected-apps/SKILL.md) |
| `salesforce-custom-app-ui` | Production Salesforce AI skill for custom applications, Lightning apps, tabs, list views, app visibility, navigation, and related app metadata. | [`SKILL.md`](skills/salesforce-custom-app-ui/SKILL.md) |
| `salesforce-custom-lightning-types` | Production Salesforce AI skill for custom Lightning types, LightningTypeBundle metadata, Agentforce/Prompt Builder type contracts, and UI/action schema review. | [`SKILL.md`](skills/salesforce-custom-lightning-types/SKILL.md) |
| `salesforce-datacloud` | Production Salesforce AI skill for Data Cloud activation, connection, schema retrieval, harmonization, querying, orchestration, and segmentation. | [`SKILL.md`](skills/salesforce-datacloud/SKILL.md) |
| `salesforce-data-operations` | Production Salesforce AI skill for Salesforce data query/import/export/update/delete, Bulk API, tree data, seed data, cleanup, and reversible experiments. | [`SKILL.md`](skills/salesforce-data-operations/SKILL.md) |
| `salesforce-deployment` | Production Salesforce AI skill for package.xml composition, validation, release planning. | [`SKILL.md`](skills/salesforce-deployment/SKILL.md) |
| `salesforce-diagrams` | Production Salesforce AI skill for Mermaid and visual diagrams of Salesforce architecture, data models, automations, integrations, and Agentforce subagent maps. | [`SKILL.md`](skills/salesforce-diagrams/SKILL.md) |
| `salesforce-docs-research` | Production Salesforce AI skill for fetching and verifying current Salesforce documentation, release notes, command syntax, and platform behavior before implementation. | [`SKILL.md`](skills/salesforce-docs-research/SKILL.md) |
| `salesforce-email-template` | Production Salesforce AI skill for Lightning/Classic email template creation/review. | [`SKILL.md`](skills/salesforce-email-template/SKILL.md) |
| `salesforce-flexipage` | Production Salesforce AI skill for Lightning Record/App/Home page composition and activation. | [`SKILL.md`](skills/salesforce-flexipage/SKILL.md) |
| `salesforce-flow` | Production Salesforce AI skill for Record-triggered/autolaunched/screen flow design or XML review. | [`SKILL.md`](skills/salesforce-flow/SKILL.md) |
| `salesforce-global-development` | Production Salesforce AI skill for any Salesforce implementation/review/design task. | [`SKILL.md`](skills/salesforce-global-development/SKILL.md) |
| `salesforce-integration` | Production Salesforce AI skill for HTTP callouts, Platform Events, CDC, external auth/data sync. | [`SKILL.md`](skills/salesforce-integration/SKILL.md) |
| `salesforce-lwc` | Production Salesforce AI skill for Lightning Web Component implementation/review/testing. | [`SKILL.md`](skills/salesforce-lwc/SKILL.md) |
| `salesforce-media-search` | Production Salesforce AI skill for searching, selecting, and attributing Salesforce-relevant images/media for docs, demos, UI mockups, and enablement content. | [`SKILL.md`](skills/salesforce-media-search/SKILL.md) |
| `salesforce-metadata` | Production Salesforce AI skill for Objects/fields/record types/validation/CMDT changes. | [`SKILL.md`](skills/salesforce-metadata/SKILL.md) |
| `salesforce-observability` | Production Salesforce AI skill for Logging, telemetry, monitoring, incident triage. | [`SKILL.md`](skills/salesforce-observability/SKILL.md) |
| `salesforce-omnistudio` | Production Salesforce AI skill for OmniStudio OmniScripts, FlexCards, DataMappers/DataRaptors, Integration Procedures, EPC modeling, dependencies, and DataPack deployment. | [`SKILL.md`](skills/salesforce-omnistudio/SKILL.md) |
| `salesforce-permissions` | Production Salesforce AI skill for Access model, permission sets/groups, muting, external auth access. | [`SKILL.md`](skills/salesforce-permissions/SKILL.md) |
| `salesforce-prompt-template` | Production Salesforce AI skill for Prompt Builder templates, AI output contracts, grounding controls. | [`SKILL.md`](skills/salesforce-prompt-template/SKILL.md) |
| `salesforce-service-assistant` | Production Salesforce AI skill for Plusgrade Agentforce Service Assistant on Case work. | [`SKILL.md`](skills/salesforce-service-assistant/SKILL.md) |
| `salesforce-soql` | Production Salesforce AI skill for SOQL/SOSL query design, optimization, selectivity, relationship queries, and Salesforce data retrieval. | [`SKILL.md`](skills/salesforce-soql/SKILL.md) |
| `salesforce-testing` | Production Salesforce AI skill for Apex/Jest/Flow validation strategy and test implementation. | [`SKILL.md`](skills/salesforce-testing/SKILL.md) |
| `salesforce-trigger` | Production Salesforce AI skill for Any trigger or trigger handler change. | [`SKILL.md`](skills/salesforce-trigger/SKILL.md) |
| `salesforce-ui-bundle` | Production Salesforce AI skill for Salesforce UI Bundle apps, frontends, sites, metadata, features, Agentforce conversation clients, file upload, Salesforce data usage, and SLDS 2 uplift. | [`SKILL.md`](skills/salesforce-ui-bundle/SKILL.md) |
| `salesforce-validation-rules` | Production Salesforce AI skill for Salesforce validation rule design, formulas, error messages, bypass strategy, and deployment review. | [`SKILL.md`](skills/salesforce-validation-rules/SKILL.md) |
| `salesforce-visualforce` | Production Salesforce AI skill for Visualforce page/controller maintenance or migration. | [`SKILL.md`](skills/salesforce-visualforce/SKILL.md) |

## Coverage Rating

Current rating: **10/10 for local agent execution readiness**.

Why: the library has broad practical domain coverage, a single-file skill contract per domain, explicit routing in Claude/Codex docs, safety gates, and an automated validator.
