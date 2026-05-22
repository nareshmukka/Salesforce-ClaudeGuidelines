# Lessons Learned

Cross-skill lessons that every agent should check before editing. Skill-specific mistakes still live in each `SKILL.md`; this file is the quick front door that prevents repeat failures across agents and tools.

## Agent Startup Rule

Every Claude, Codex, or VS Code Copilot agent should read:

1. `AGENTS.md`
2. The relevant tool wrapper when applicable: `CLAUDE.md`, `CODEX.md`, or `AMAZONQ.md`
3. `salesforce-ai-skills/SKILL_INDEX.md`
4. `salesforce-ai-skills/skills/salesforce-global-development/SKILL.md` for Salesforce implementation/review/design work
5. Task-specific `SKILL.md` files
6. This `LESSONS.md`

## Common Mistakes To Avoid

| Mistake | Why it causes trouble | Correct behavior |
|---|---|---|
| Editing before reading the current source | Breaks local conventions and misses dependencies | Inspect the target files and nearby references before changing anything |
| Treating deploy/publish/activate as validation | Can change live behavior | Validation is dry-run/test/review only unless the user explicitly approves an operational action |
| Hardcoding environment-specific values | Makes skills unusable across projects | Use placeholders in reusable docs and read project-specific values from local context |
| Assuming a helper class or logging object exists | Causes compile failures in other orgs | Verify project utilities exist before referencing them; otherwise use platform-native fallback patterns |
| Skipping CRUD/FLS/sharing review | Creates data exposure risk | State sharing mode and data-access checks for every Apex/data path |
| Copying Agentforce patterns across agent types | ServicePlanner, `.agent` bundles, Builder metadata, and prompt templates have different contracts | Identify agent type before editing metadata or instructions |
| Adding lessons only to final chat | Future agents will not see them | Add durable lessons to this file or the matching skill's mistake table |

## Where New Lessons Go

Use `LESSONS.md` for cross-cutting process lessons that affect multiple skills or agents.

Use the matching `salesforce-ai-skills/skills/<skill-name>/SKILL.md` when the lesson is domain-specific, such as Apex bulk safety, Flow XML ordering, Agentforce bundle publishing, or permission-set metadata.

Every new lesson should be:
- reusable across projects
- free of company/person/environment details
- written as a mistake plus the correct behavior
- short enough for agents to scan quickly
