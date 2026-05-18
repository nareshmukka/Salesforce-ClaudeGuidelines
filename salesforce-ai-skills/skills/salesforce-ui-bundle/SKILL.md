---
name: salesforce-ui-bundle
description: Production Salesforce AI skill for Salesforce UI Bundle apps, frontends, sites, metadata, features, Agentforce conversation clients, file upload, Salesforce data usage, and SLDS 2 uplift.
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
- The task involves Salesforce UI Bundle app/frontend/site metadata, UI bundle deployment, SLDS 2 uplift, Agentforce conversation clients, file upload, or Salesforce data access from a UI bundle.
- The user asks for implementation, review, troubleshooting, or deployment planning in this area.

## DO NOT TRIGGER when
- The task is a normal LWC bundle inside `force-app/main/default/lwc`.
- The task is generic frontend work with no Salesforce UI Bundle surface.

## Cross-skill routing
- Always read `../salesforce-global-development/SKILL.md`.
- Also read: LWC + Integration + Deployment + Permissions + Agentforce Script when conversation clients are involved.

## Purpose
Cover upstream UI Bundle skills as one local skill while keeping the repo concise.

## Workflow
1. Identify UI bundle type: app, frontend, site, feature, metadata, conversation client, file upload, or Salesforce data integration.
2. Inspect bundle structure, build/runtime config, authentication assumptions, and deployment target.
3. Map data access, user actions, file handling, and Agentforce conversation flows.
4. Validate accessibility, SLDS 2 alignment, responsive behavior, security, and error states.
5. Run local build/test/lint where available before deployment guidance.

## Best Practices
- Keep UI bundles composed and domain-focused; avoid mixing unrelated app, site, and feature concerns.
- Use SLDS 2 tokens/hooks and accessible components; avoid hardcoded visual values.
- For Salesforce data, centralize data access and handle CRUD/FLS, auth, and errors explicitly.
- For file upload, validate type/size, scan/security requirements, retry behavior, and user feedback.
- For Agentforce conversation clients, separate UI state from agent/session state and test reconnect/failure paths.

## Review checklist
- [ ] Bundle type and deployment target are explicit.
- [ ] Auth, data access, and file/session security are reviewed.
- [ ] Accessibility/responsive behavior is checked.
- [ ] Build/test validation is captured.
- [ ] Deployment/rollback path is documented.

## Output contract
- Understanding
- Files inspected
- Changes made
- UX/security review
- Tests / validation
- Deployment notes
- Rollback notes
