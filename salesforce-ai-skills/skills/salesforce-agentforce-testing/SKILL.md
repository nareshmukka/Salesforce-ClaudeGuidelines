---
name: salesforce-agentforce-testing
description: Production Salesforce AI skill for Agentforce test specs, utterance coverage, preview validation, trace review, AiEvaluationDefinition, and agent quality scoring.
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
- The task involves Agentforce testing, preview validation, trace analysis, test utterances, AiEvaluationDefinition, test spec YAML, quality scoring, or regression coverage for agents.

## DO NOT TRIGGER when
- The task is agent authoring without test/validation scope; use Agentforce Script or Authoring Bundle first.

## Cross-skill routing
- Always read `../salesforce-global-development/SKILL.md`.
- Also read: Agentforce Script + Agentforce Authoring Bundle + Testing + Observability.

## Workflow
1. Establish Agent Spec or reverse-engineer expected behavior from `.agent` source.
2. Map subagents, actions, variables, gates, and protected paths to coverage targets.
3. Design utterances for happy paths, edge cases, refusal/guardrail behavior, permission failures, and action failures.
4. Run preview with live actions when available and inspect traces for routing, action I/O, and reasoning evidence.
5. Create or update AiEvaluationDefinition/test spec only after expected behavior is clear.
6. Iterate until failures are classified as agent code, backing logic, permissions, or test-spec defects.

## Best Practices
- One utterance is never enough; test each subagent and adjacent regression paths.
- Publish is not testing; preview and trace validation come first.
- Test write/send actions with confirmation gates and negative responses.
- Keep test data non-PII and resettable.
- Score agents on structure, safety, deterministic logic, instruction resolution, FSM architecture, action config, and deployment readiness.

## Output contract
- Test goal
- Agent/artifacts inspected
- Coverage map
- Test scenarios/spec changes
- Results / trace findings
- Risks and next steps
