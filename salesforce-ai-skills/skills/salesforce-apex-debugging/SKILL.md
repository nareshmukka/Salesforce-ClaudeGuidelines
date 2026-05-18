---
name: salesforce-apex-debugging
description: Production Salesforce AI skill for Apex debug logs, trace flags, governor-limit diagnosis, runtime exception triage, and production-safe debugging.
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
- The task involves Apex debug logs, trace flags, runtime exceptions, CPU/SOQL/DML limits, transaction debugging, or log-based root cause analysis.

## DO NOT TRIGGER when
- The task is pure Apex authoring without runtime/debug evidence.

## Cross-skill routing
- Always read `../salesforce-global-development/SKILL.md`.
- Also read: Apex + Observability + Testing.

## Workflow
1. Capture exact symptom, user/context, timestamp, target environment alias, and transaction entry point.
2. Gather logs or reproduce with the smallest safe input.
3. Classify failure: permissions, null/data shape, validation rule, automation side effect, governor limit, callout, async, or platform issue.
4. Trace from entry point through service/selector/domain/integration layers.
5. Propose the smallest fix and validation path.

## Best Practices
- Do not add broad `System.debug()` noise to production code; use existing logging framework or scoped temporary logs.
- Redact PII/secrets from logs before sharing.
- Use Limits metrics to validate governor hypotheses.
- Confirm whether failures are data-dependent before changing code.
- Add regression tests for the diagnosed failure path.

## Output contract
- Symptom
- Evidence inspected
- Root cause
- Fix/recommendation
- Validation
- Residual risk
