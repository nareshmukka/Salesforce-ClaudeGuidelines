# Codex Skills Compatibility

Codex repo-scoped skills are normally discovered from `.agents/skills`.

This repo keeps canonical Salesforce skills under `salesforce-ai-skills/skills`.

Do not duplicate skills by default. If native Codex skill discovery is required, prefer a symlink/junction setup or a separate setup script.

Do not create `.agents/skills` copies unless explicitly requested.
