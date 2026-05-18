---
name: salesforce-b2b-commerce
description: Production Salesforce AI skill for B2B Commerce store setup, catalog/product model, buyer groups, pricing, entitlement, checkout, and commerce metadata review.
license: Apache-2.0
compatibility:
  - Claude Code
  - Claude Agents
  - Codex / ChatGPT
  - GitHub Copilot
metadata:
  version: 2.0.0
  last_updated: 2026-05-18
  owner: Naresh Salesforce AI Skills Library
---

## TRIGGER when
- The task involves B2B Commerce stores, products, catalogs, price books, buyer groups, entitlements, checkout, commerce setup, or commerce metadata.

## DO NOT TRIGGER when
- The task is generic Experience Cloud or standard object work unrelated to Commerce.
- The user asks to publish/activate a live store without explicit approval.

## Cross-skill routing
- Always read `../salesforce-global-development/SKILL.md`.
- Also read: Metadata + Permissions + Deployment + Integration.

## Best Practices
- Model catalog, products, price books, buyer groups, and entitlements before UI work.
- Confirm storefront/environment and whether changes affect live buyers.
- Keep pricing and entitlement changes auditable and reversible.
- Validate checkout integrations, tax/shipping/payment assumptions, and failure paths.
- Do not publish storefront changes without explicit approval and rollback plan.

## Output contract
- Understanding
- Commerce artifacts inspected
- Changes made/recommended
- Access/data/security review
- Validation
- Publish/deployment notes
- Rollback notes
