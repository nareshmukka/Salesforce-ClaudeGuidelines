---
name: salesforce-connected-apps
description: Production Salesforce AI skill for Connected Apps, OAuth, external client access, scopes, callback URLs, and integration auth review.
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
- The task involves Connected App metadata, OAuth scopes, callback URLs, JWT/client credentials flows, external app access, or integration authentication.

## DO NOT TRIGGER when
- The task only uses an existing Named Credential without changing auth configuration.
- The user asks to rotate secrets, enable production access, or change live auth without explicit approval.

## Cross-skill routing
- Always read `../salesforce-global-development/SKILL.md`.
- Also read: Integration + Permissions + Deployment.

## Purpose
Provide safe guidance for Connected App configuration and review.

## Workflow
1. Identify auth flow, client type, target environment, callback URLs, scopes, and token policy.
2. Confirm whether secrets/certificates exist and avoid reading or printing secret values.
3. Review least-privilege scopes, IP/session policy, profile/permission-set access, and callback URL exactness.
4. Validate metadata dependencies and rollout plan.
5. Document rotation, rollback, and monitoring.

## Best Practices
- Use the narrowest OAuth scopes and exact callback URLs.
- Prefer certificate/JWT or External Credentials where appropriate; avoid embedding client secrets in code.
- Separate test environment and production Connected Apps when policies differ.
- Restrict access by permission set and document the persona/application owner.
- Never commit secrets, private keys, refresh tokens, or generated client secrets.

## Output contract
- Understanding
- Auth configuration inspected
- Changes made
- Security review
- Validation
- Deployment notes
- Rollback notes
