# Security Policy

## Supported Branch

Security fixes are accepted for the default branch, `main`.

## Reporting a Vulnerability

Please do not report security vulnerabilities in public issues.

Use one of these private paths:

- Open a private GitHub security advisory for this repository, if available.
- Contact the repository owner directly through GitHub.

Include:

- A clear description of the issue.
- The affected file, skill, template, or workflow.
- Steps to reproduce or validate the concern.
- Any evidence of exposed secrets, sensitive data, or unsafe guidance.

## Sensitive Data Rules

Do not commit:

- Secrets, passwords, tokens, private keys, or credentials.
- Salesforce org URLs, instance URLs, auth aliases, or session details.
- Customer names, record IDs, user IDs, or production data.
- Internal environment names or deployment targets.

If sensitive data is committed, rotate the secret or credential immediately and rewrite repository history only after confirming the safe replacement branch with the maintainer.

## Maintainer Response

The maintainer will review valid reports, remove or replace unsafe content, and publish remediation notes when appropriate.
