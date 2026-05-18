---
name: salesforce-omnistudio
description: Production Salesforce AI skill for OmniStudio OmniScripts, FlexCards, DataMappers/DataRaptors, Integration Procedures, EPC modeling, dependencies, and DataPack deployment.
license: Apache-2.0
compatibility:
  - Claude Code
  - Claude Agents
  - Codex / ChatGPT
  - GitHub Copilot
metadata:
  version: 2.0.0
  last_updated: 2026-05-18
  owner: Reusable Salesforce AI Skills Library
---

## TRIGGER when
- The task involves OmniStudio, OmniScript, FlexCard, Integration Procedure, DataMapper/DataRaptor, OmniStudio callable Apex, EPC/catalog modeling, dependency analysis, or DataPack deployment.
- The user asks for implementation, review, troubleshooting, or deployment planning in this area.

## DO NOT TRIGGER when
- The task is standard Flow/LWC/Apex without OmniStudio runtime or DataPack metadata.
- The user asks for deploy/import/activation/destructive DataPack work without explicit approval.

## Cross-skill routing
- Always read `../salesforce-global-development/SKILL.md`.
- Also read: Apex + Integration + Deployment + Permissions + Metadata.

## Purpose
Unify upstream OmniStudio skills into one local skill for practical authoring, review, dependency analysis, and deployment safety.

## Workflow
1. Identify artifact type and runtime surface: OmniScript, FlexCard, Integration Procedure, DataMapper/DataRaptor, callable Apex, or EPC metadata.
2. Inspect existing DataPack structure and dependencies before editing.
3. Map data flow from UI input through actions/transforms to persistence/integration.
4. Validate error branches, null handling, versioning, activation state, and deployment dependencies.
5. Plan reversible deployment/import sequence and rollback.

## Best Practices
- Keep Integration Procedures thin and composable; avoid hiding complex business logic in nested steps without documentation.
- Use DataMappers/DataRaptors for predictable mapping and transformation, not as a dumping ground for business rules.
- Validate response shapes and null/empty cases for every remote/action step.
- Keep FlexCards accessible, state-aware, and explicit about data source contracts.
- For callable Apex, use invocable/bulk-safe patterns and return structured errors.
- Deploy OmniStudio DataPacks in dependency order and avoid broad imports without review.

## Review checklist
- [ ] Artifact type, version, activation state, and dependencies are known.
- [ ] Data contracts and transforms are documented.
- [ ] Fault/error paths are handled.
- [ ] Deployment/import order is safe.
- [ ] Rollback/reimport plan is documented.

## Output contract
- Understanding
- Artifacts inspected
- Changes made
- Dependency/security review
- Validation
- Deployment notes
- Rollback notes
