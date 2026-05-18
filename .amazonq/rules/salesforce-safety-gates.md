# Salesforce Safety Gates

- Do not deploy without explicit approval.
- Do not publish or activate Agentforce agents without explicit approval.
- Do not activate Flow changes without explicit approval.
- Do not delete metadata without explicit approval.
- Do not modify live data without explicit approval.
- Do not rotate credentials or activate connectors without explicit approval.
- Do not hardcode IDs, secrets, tokens, org URLs, environment aliases, or customer-specific values.
- Enforce CRUD/FLS/sharing, bulkification, governor-limit safety, test coverage, deployment notes, and rollback notes.
