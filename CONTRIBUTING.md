# Contributing

Thank you for helping improve this Salesforce AI skills library. Contributions are welcome when they keep the repository reusable, secure, and vendor/tool friendly.

## Required Workflow

Do not commit directly to `main`.

1. Create a feature branch from the latest `main`.
2. Make a focused change with clear scope.
3. Validate the skill library locally:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/validate-salesforce-ai-skills.ps1
```

4. Open a pull request into `main`.
5. Wait for maintainer review and approval before merge.

The repository owner is the required reviewer for protected branch changes.

## Contribution Standards

- Keep reusable guidance generic and portable.
- Do not add company names, person names, customer names, target environment aliases, org URLs, record IDs, secrets, tokens, or project-specific process names.
- Use placeholders such as `<target-env-alias>`, `<manifest-path>`, `<agent-api-name>`, and `<object-api-name>`.
- Keep changes small and easy to review.
- Update routing or index files when adding, removing, or renaming skills.
- Include validation notes in the pull request.

## Security

Never commit secrets, credentials, Salesforce org URLs, access tokens, private keys, customer data, or internal environment details. If you find a vulnerability or accidental secret exposure, follow [SECURITY.md](SECURITY.md).

## Code of Conduct

All participation must follow [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md).
