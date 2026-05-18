---
name: salesforce-media-search
description: Production Salesforce AI skill for searching, selecting, and attributing Salesforce-relevant images/media for docs, demos, UI mockups, and enablement content.
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
- The task asks for media, screenshots, product images, architecture visuals, demo assets, or documentation visuals.

## DO NOT TRIGGER when
- The task is code/metadata-only or the user provided all assets.

## Cross-skill routing
- Always read `../salesforce-global-development/SKILL.md`.
- Also read: Diagrams or LWC/UI skills when the media supports implementation.

## Best Practices
- Prefer official Salesforce images/docs, repo-local screenshots, or generated visuals when licensing is unclear.
- Attribute external media and record source URLs.
- Avoid using customer data, PII, org-specific screenshots, or credentials in visuals.
- For UI work, prefer visuals that show the actual product/state rather than decorative stock imagery.
- Verify image dimensions, readability, and relevance before adding to docs.

## Output contract
- Media need
- Sources checked
- Selected asset(s)
- Attribution/licensing notes
- Usage notes
