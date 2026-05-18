---
name: salesforce-custom-app-ui
description: Production Salesforce AI skill for custom applications, Lightning apps, tabs, list views, app visibility, navigation, and related app metadata.
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
- The task involves custom applications, Lightning apps, tabs, list views, navigation items, app visibility, app metadata, or app-level UX setup.

## DO NOT TRIGGER when
- The task is a page layout/FlexiPage or LWC implementation; use those specific skills.

## Cross-skill routing
- Always read `../salesforce-global-development/SKILL.md`.
- Also read: Metadata + Permissions + FlexiPage + Deployment.

## Best Practices
- Use stable API names and clear labels/descriptions for apps, tabs, and list views.
- Ensure tabs/apps are paired with permission-set access and object permissions.
- For standard object tabs, use platform tab names; for custom object tabs, include the exact custom object API name.
- Validate navigation order, default landing item, form factor, and target persona.
- Do not expose admin-only tabs or objects to broad personas.

## Output contract
- Understanding
- App/UI metadata inspected
- Changes made
- Access review
- Validation
- Deployment notes
