# Global Salesforce AI Development Guidelines

**Version**: 2.0 (April 2026)
**Developer**: Naresh | Senior Salesforce Developer
**Purpose**: Master rules governing all AI-assisted Salesforce development. Attach this file to any AI agent session working on Salesforce metadata, code, or configuration. This file defines the operating contract, architecture standards, security rules, naming conventions, bulkification requirements, governor limit awareness, Definition of Done, and anti-patterns. Every other guideline file in this library inherits and extends these rules.

---

## Table of Contents

1. [Agent Operating Contract](#1-agent-operating-contract)
2. [Plan-First Requirement](#2-plan-first-requirement)
3. [File Diff Requirement](#3-file-diff-requirement)
4. [Security Rules](#4-security-rules)
5. [Architecture Layering](#5-architecture-layering)
6. [Naming Conventions](#6-naming-conventions)
7. [Bulkification Rules](#7-bulkification-rules)
8. [Governor Limits Reference](#8-governor-limits-reference)
9. [Trigger and Flow Coexistence Rules](#9-trigger-and-flow-coexistence-rules)
10. [Token-Saving Guidance](#10-token-saving-guidance)
11. [Definition of Done](#11-definition-of-done)
12. [Common Anti-Patterns](#12-common-anti-patterns)
13. [Review Checklist](#13-review-checklist)
14. [Official References](#14-official-references)

---

## 1. Agent Operating Contract

This section defines the non-negotiable rules that govern how an AI agent must behave during any Salesforce development session. These rules apply regardless of which component area is being worked on and regardless of which specific guideline file is attached alongside this one.

### 1.1 Mandatory Pre-Implementation Steps

Before producing any code, metadata, or configuration, the agent MUST:

1. **Confirm scope** — restate the task in your own words and ask for clarification if any requirement is ambiguous. Do not assume. Do not proceed on incomplete information.
2. **Produce a numbered plan** — see Section 2 for the full plan-first requirement.
3. **List exact files** to be created, modified, or deleted — see Section 3 for the file diff requirement.
4. **Identify security considerations** — flag CRUD/FLS touchpoints, sharing model decisions, hardcoded value risks, and callout credential concerns before writing a single line.
5. **Identify governor limit risks** — flag any operation that could approach SOQL, DML, CPU, or heap limits in a bulk scenario before implementing.

### 1.2 Mandatory Output Format

Every AI agent response for a development task MUST follow this exact output structure. Do not skip or reorder sections. Do not collapse sections unless the task genuinely does not require that section (e.g., no deployment needed for a pure code review).

```
## Plan
[Numbered list of steps and decisions]

## Files
[Exact list of files to create / modify / delete with reasons]

## Implementation
[All code, metadata XML, flow descriptions, configuration — complete and production-ready]

## Security
[CRUD/FLS approach, sharing model decision, hardcoded value audit, callout credential approach]

## Testing
[Test class(es), Jest specs, or test plan — complete and production-ready]

## Validation
[How to verify the change works correctly in a sandbox or scratch org]

## Rollback
[Exact steps to safely undo this change if it needs to be reverted in production]
```

### 1.3 Scope Restriction

- The agent MUST NOT modify metadata, code, or configuration that is not explicitly in scope for the current task.
- If the agent identifies a pre-existing bug or issue outside the current scope, it MUST flag it as a separate finding rather than silently fixing it. Silent "helpful" changes to unrelated files are prohibited.
- If a requested change requires touching an unexpectedly large surface area, the agent MUST pause, report this to the developer, and confirm before proceeding.

### 1.4 Prohibition on Hardcoded Values

The agent MUST NEVER produce code or configuration containing:

- Record type IDs (e.g., `'012000000000000AAA'`)
- Queue IDs or Group IDs
- User IDs or Profile IDs
- Org-specific metadata IDs of any kind
- API endpoints, base URLs, or host names (use Named Credentials)
- API keys, client IDs, client secrets, OAuth tokens, passwords, or any credentials
- Non-configurable magic strings or numbers that should be externalised to Custom Metadata

Any of the above found in existing code must be flagged as a security/quality finding.

### 1.5 Standards Citation Requirement

In the Security section of every response, the agent MUST explicitly cite which rules from this guideline file (or the attached component-specific guideline file) are being applied. This makes the review process auditable and ensures the agent is not hallucinating compliance.

Example: *"Applying Section 4.2 (with sharing enforcement), Section 4.5 (Named Credentials for callout), and Section 7 (bulk-safe Map lookups)."*

### 1.6 File Diff Summary

Before writing any implementation code, the agent MUST produce a brief file diff summary listing every file change. See Section 3.

---

## 2. Plan-First Requirement

No implementation output may appear in a response until a complete, explicit plan has been stated. This rule prevents the AI agent from jumping to code before understanding the full scope and implications of a change.

### 2.1 Required Plan Structure

Every plan MUST be a numbered list and MUST address the following items. If an item is not applicable, state "N/A — [reason]" rather than omitting it silently.

1. **Objective** — one sentence describing what will be built or changed
2. **Impacted metadata types** — list every metadata type that will be created or modified (e.g., ApexClass, Flow, CustomObject, PermissionSet)
3. **Files to change** — list every file by name (see also Section 3)
4. **Architecture decisions** — which layer handles which logic, how the layers interact
5. **Security considerations** — CRUD/FLS strategy, sharing model decision, credential handling
6. **Governor limit risks** — identify any operation that could approach limits in a 200-record bulk scenario
7. **Dependencies and order** — if multiple files must be deployed in a specific order, state that order
8. **Rollback approach** — how to safely undo this change

### 2.2 Plan Approval

In an interactive session, the agent should pause after the plan and invite the developer to confirm or refine the approach before proceeding to implementation. In automated/non-interactive sessions, the agent must state clearly in the plan that it is proceeding based on the stated requirements.

### 2.3 Plan Changes During Implementation

If, during implementation, the agent discovers that the actual scope is different from the plan (e.g., a dependency was not anticipated), the agent MUST update the plan inline and note the revision rather than silently changing course.

---

## 3. File Diff Requirement

Before writing any code or metadata, the agent MUST produce a structured file diff summary. This ensures the developer can review and approve the scope of changes before any output is produced.

### 3.1 File Diff Format

```
### File Diff Summary

CREATE:
- force-app/main/default/classes/CaseService.cls  [New service class for case assignment logic]
- force-app/main/default/classes/CaseService.cls-meta.xml  [Metadata descriptor]
- force-app/main/default/classes/CaseServiceTest.cls  [Test class]
- force-app/main/default/classes/CaseServiceTest.cls-meta.xml  [Metadata descriptor]

MODIFY:
- force-app/main/default/triggers/CaseTrigger.trigger  [Add invocation of CaseService.handleAssignment()]

DELETE:
(none)
```

### 3.2 File Diff Rules

- List every file, including metadata XML descriptors (`.cls-meta.xml`, `.trigger-meta.xml`, etc.)
- State the reason for each change in square brackets
- Do not merge multiple changes into a vague "update this file" statement
- If a file will be significantly refactored versus minimally changed, say so explicitly
- Prefer **minimal targeted diffs** over broad refactors — change only what is required to meet the objective
- If a broad refactor is genuinely necessary, justify it explicitly in the plan

---

## 4. Security Rules

Security is non-negotiable. Every piece of Apex code, every Flow, every integration configuration must be assessed against these rules. Violations must be flagged as blocking issues, not suggestions.

### 4.1 CRUD/FLS Enforcement

**Rule:** CRUD (Create, Read, Update, Delete) and FLS (Field-Level Security) must be enforced at every Apex entry point where user-context data access occurs.

- **CRUD enforcement**: Check `SObjectType.isAccessible()`, `isCreateable()`, `isUpdateable()`, `isDeletable()` before performing the corresponding DML or SOQL operation when running in system mode.
- **FLS enforcement**: Check `SObjectField.isAccessible()` and `isUpdateable()` for each field read or written in user-context operations.
- **Preferred approach in API version 50.0+**: Use `WITH USER_MODE` in SOQL and `allOrNone` DML in user mode, or use `Security.stripInaccessible()` for bulk field-stripping.
- **Minimum acceptable**: Any entry point accessible by an end user (VF controller, REST endpoint, invocable, LWC controller) must enforce CRUD/FLS. Internal service-to-service calls may use explicit sharing declarations (see 4.2) without per-field checks when the caller has already enforced access.

### 4.2 Sharing Model: with sharing / without sharing / inherited sharing

Understanding and correctly declaring the sharing keyword is mandatory. The wrong choice is a security vulnerability.

| Keyword | Behaviour | When To Use |
|---|---|---|
| `with sharing` | Enforces the running user's record sharing rules (org-wide defaults, sharing rules, manual sharing, role hierarchy) | Default choice for all classes accessed by end users — controllers, invocable methods, REST services, LWC Apex controllers |
| `without sharing` | Ignores record sharing — the class can see and modify all records of any type regardless of the running user's access | Only for system-level operations that genuinely need cross-user record access (e.g., batch jobs, system integrations, admin utilities). Must be explicitly justified in a code comment. |
| `inherited sharing` | Inherits the sharing context of the calling class | Service/utility classes that are called from multiple contexts — they adapt to the caller's sharing context. Good for the service and domain layers. |
| (no keyword — implicit) | Behaviour is undefined / defaults to `without sharing` in most contexts | NEVER omit the sharing keyword. Always declare it explicitly. |

**Rule:** Every Apex class MUST explicitly declare its sharing keyword. No class may be missing this declaration.

### 4.3 User Mode vs System Mode

- **User mode** (`WITH USER_MODE` in SOQL, or DML on SObjects in user context): Enforces CRUD, FLS, and sharing rules as the running user. Use this when processing user-initiated requests.
- **System mode** (`WITH SYSTEM_MODE` in SOQL, or explicit `without sharing`): Bypasses CRUD, FLS, and sharing. Use only when explicitly required and with a documented justification.
- **Rule:** Default to user mode for all user-facing operations. Escalate to system mode only when the business requirement genuinely cannot be met in user mode, and document why.

### 4.4 Security.stripInaccessible

Use `Security.stripInaccessible(AccessType.READABLE, records)` before returning records to a user context to strip fields the running user cannot see. Use `Security.stripInaccessible(AccessType.UPSERTABLE, records)` before DML to strip fields the user cannot write.

This is the recommended bulk-safe approach for FLS enforcement when using system mode classes.

```apex
SObjectAccessDecision decision = Security.stripInaccessible(
    AccessType.READABLE,
    [SELECT Id, Name, Case_Category__c FROM Case WHERE AccountId = :accountId]
);
List<Case> safeRecords = (List<Case>) decision.getRecords();
```

### 4.5 WITH USER_MODE vs WITH SECURITY_ENFORCED

- **`WITH USER_MODE`** (available from API v51.0+): Enforces CRUD, FLS, and sharing rules inline in the SOQL query. This is the **preferred and current standard**.
- **`WITH SECURITY_ENFORCED`** (available from API v45.0): Enforces FLS only (not CRUD or sharing). **Note: This clause is being deprecated in favour of `WITH USER_MODE` in newer API versions. Verify the deprecation status for your target org's API version before using it.** New code should use `WITH USER_MODE`.
- **Rule:** Use `WITH USER_MODE` for new code in orgs on API v51.0+. Do not use `WITH SECURITY_ENFORCED` in new code.

### 4.6 No Hardcoded Org-Specific IDs

The following values MUST NEVER be hardcoded anywhere in code, flows, configuration, or metadata:

- Record type developer names should be looked up via `Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName()` — never hardcode the 18-character ID
- Queue IDs — query `Group` where `Type = 'Queue'` and `DeveloperName = 'My_Queue'`
- User IDs — never hardcode; pass via configuration or query by username/email (with care)
- Profile IDs or names — use permission sets instead; if profile names must be referenced, query them
- Organisation IDs, environment-specific IDs of any type

### 4.7 No Hardcoded Endpoints, Credentials, or Secrets

- All external callouts MUST use a Named Credential as the endpoint (`callout:MyNamedCredential/path`)
- Authentication credentials MUST be stored in External Credentials (OAuth) or Named Credentials (legacy)
- API keys, client secrets, OAuth tokens, passwords, certificates — all MUST be stored in Salesforce platform credential stores, never in code or Custom Metadata
- Custom Metadata Types are appropriate for non-secret configuration (URLs that are not credentials, feature flags, thresholds, timeout values)

### 4.8 Custom Metadata for Non-Secret Configuration

Use Custom Metadata Types (`__mdt`) for any configuration value that:
- May change between environments (sandbox vs production)
- Is shared across multiple classes or flows
- Should be changeable without a code deployment (CMDT records can be deployed separately)

Examples: Integration timeout values, retry counts, feature flags, threshold values, mapping tables, routing rules.

Do NOT store secrets in Custom Metadata — CMDT records are readable by all users with object access. Use platform credentials for anything secret.

---

## 5. Architecture Layering

All Salesforce implementations on this team follow a four-layer architecture. Understanding where logic belongs is as important as writing the logic correctly.

### 5.1 Layer Definitions

```
┌─────────────────────────────────────────────────────────────────────┐
│  ENTRY LAYER                                                        │
│  Triggers · Flows · LWC · REST/SOAP APIs · Invocable Apex          │
│  Visualforce Controllers · Batch entry points                       │
│  Responsibility: Accept input, validate surface-level, delegate     │
│  DO NOT: Contain business logic, SOQL queries (beyond entry fetch)  │
├─────────────────────────────────────────────────────────────────────┤
│  APPLICATION LAYER                                                  │
│  Service Classes · Orchestration classes · Transaction managers     │
│  Responsibility: Orchestrate business operations, manage tx bounds  │
│  DO NOT: Contain direct DML/SOQL — delegate to Domain/Infra layers │
├─────────────────────────────────────────────────────────────────────┤
│  DOMAIN LAYER                                                       │
│  Domain classes · Business rule validators · Idempotency checkers   │
│  Responsibility: Encode and enforce business rules and invariants   │
│  DO NOT: Know about persistence details (no direct SOQL/DML here)  │
├─────────────────────────────────────────────────────────────────────┤
│  INFRASTRUCTURE LAYER                                               │
│  Selector/Repository classes · DML wrappers · HTTP clients         │
│  Platform Event publishers · Callout clients                        │
│  Responsibility: All persistence, external communication, I/O      │
└─────────────────────────────────────────────────────────────────────┘
```

### 5.2 Layer Rules

**Entry Layer rules:**
- A trigger body MUST contain only a single call to the handler class. No SOQL, no DML, no business logic inside the trigger body itself.
- A Flow MUST delegate complex calculations or multi-object operations to Invocable Apex or subflows. Flows should not contain deeply nested decision trees with more than 3-4 decision elements for a single logical path.
- An LWC JavaScript file MUST NOT contain business logic. All data manipulation beyond simple UI formatting belongs in Apex.
- A VF controller method MUST call a service class rather than implementing logic directly.

**Application Layer rules:**
- Service class methods represent named business operations (e.g., `CaseService.assignToQueue(List<Case> cases)`).
- Service classes own transaction boundaries. If an operation must be atomic, it is the service class's responsibility to ensure that.
- Service classes use `inherited sharing` by default so they adapt to the caller's context.

**Domain Layer rules:**
- Domain classes contain pure business logic — validation, transformation, rule evaluation — with no dependency on the database or external systems.
- Domain classes are highly testable because they have no I/O dependencies.

**Infrastructure Layer rules:**
- All SOQL queries live in Selector classes (also called Repository classes).
- All DML operations are wrapped or centralised.
- All HTTP callouts are encapsulated in dedicated HTTP client classes.
- Platform Event publishing is handled by dedicated publisher classes.

### 5.3 Integration Isolation Rule

Any integration with an external system MUST be isolated behind a dedicated provider client class (e.g., `SalesforceToNetSuiteClient`, `TwilioSmsClient`). The rest of the application interacts with an interface (`IEmailProvider`, `ISmsProvider`), not the concrete implementation. This enables:
- Mocking in tests without `HttpCalloutMock` boilerplate scattered everywhere
- Swapping providers without touching business logic
- Centralised error handling and retry logic

---

## 6. Naming Conventions

Consistent naming is a team standard, not a preference. Deviations create confusion and make metadata searches unreliable. The agent MUST apply these conventions to every piece of code and metadata it produces.

### 6.1 Apex Naming

| Component | Pattern | Example |
|---|---|---|
| Apex Class (service) | `<Domain>Service` | `CaseService`, `AccountService` |
| Apex Class (selector) | `<Domain>Selector` | `CaseSelector`, `OpportunitySelector` |
| Apex Class (domain) | `<Domain>Domain` or `<Domain>Rules` | `CaseDomain`, `AccountRules` |
| Apex Class (handler) | `<Object>TriggerHandler` | `CaseTriggerHandler` |
| Apex Class (batch) | `<Domain>BatchJob` or `<Domain>Batch` | `CaseEscalationBatch` |
| Apex Class (queueable) | `<Domain>Queueable` | `CaseNotificationQueueable` |
| Apex Class (scheduled) | `<Domain>Scheduler` | `CaseEscalationScheduler` |
| Apex Class (HTTP client) | `<Provider>Client` | `TwilioSmsClient`, `NetSuiteClient` |
| Apex Interface | `I<Capability>` | `IEmailSender`, `ISmsProvider` |
| Apex Test Class | `<ClassName>Test` | `CaseServiceTest`, `CaseTriggerHandlerTest` |
| Apex Test Factory | `TestDataFactory` (single shared) or `<Domain>TestFactory` | `CaseTestFactory` |
| Trigger | `<Object>Trigger` | `CaseTrigger`, `OpportunityTrigger` |
| Trigger Handler | `<Object>TriggerHandler` | `CaseTriggerHandler` |

### 6.2 Flow Naming

| Flow Type | Pattern | Example |
|---|---|---|
| Record-triggered (before save) | `<Domain>_BeforeSave_RecordTriggered` | `Case_BeforeSave_RecordTriggered` |
| Record-triggered (after save) | `<Domain>_AfterSave_RecordTriggered` | `Case_AfterSave_RecordTriggered` |
| Autolaunched (no trigger) | `<Domain>_Autolaunched` | `CaseNotification_Autolaunched` |
| Subflow | `<Domain>_Subflow` | `LogError_Subflow`, `CaseEscalation_Subflow` |
| Screen flow | `<Domain>_ScreenFlow` | `CaseCreation_ScreenFlow` |
| Scheduled flow | `<Domain>_Scheduled` | `CaseEscalationCheck_Scheduled` |

**Flow variable naming:**
- Input variables: `input<DescriptiveName>` (e.g., `inputCaseRecord`, `inputAccountId`)
- Output variables: `output<DescriptiveName>` (e.g., `outputIsEscalated`, `outputErrorMessage`)
- Collection variables: `col<ObjectType>Records` (e.g., `colCaseRecords`)
- Loop variables: `loop<ObjectType>Record` (e.g., `loopCaseRecord`)
- Text/boolean/number variables: descriptive camelCase (e.g., `isEscalationRequired`, `escalationThresholdHours`)

### 6.3 Object and Field Naming

| Component | Pattern | Example |
|---|---|---|
| Custom Object | `<Domain>__c` (descriptive, stable, no abbreviations) | `Support_Case__c`, `Loyalty_Programme__c` |
| Custom Field | descriptive, stable, no abbreviations | `Case_Category__c`, `Escalation_Reason__c` |
| Lookup Field | `<Related_Object>__c` | `Primary_Contact__c`, `Account__c` |
| Junction Object | `<ObjectA>_<ObjectB>__c` | `Case_Product__c` |
| Custom Metadata Type | `CMDT_<Domain>__mdt` | `CMDT_IntegrationConfig__mdt`, `CMDT_FeatureFlag__mdt` |
| Custom Setting (avoid if possible) | `CS_<Domain>__c` | `CS_OrgConfig__c` |
| Record Type | `<Descriptive_Name>` (no underscores in label; developer name uses underscores) | Developer name: `Enterprise_Support`, Label: `Enterprise Support` |

### 6.4 Validation Rule Naming

| Component | Pattern | Example |
|---|---|---|
| Validation Rule | `VR_<Object>_<Intent>` | `VR_Case_SubjectRequired`, `VR_Account_PhoneFormatInvalid` |

### 6.5 Access Control Naming

| Component | Pattern | Example |
|---|---|---|
| Permission Set | `PS_<DomainOrRole>` | `PS_SupportAgent`, `PS_CaseManager` |
| Permission Set Group | `PSG_<DomainOrRole>` | `PSG_SupportAgent`, `PSG_SalesRep` |
| Muting Permission Set | `MPS_<Restriction>` | `MPS_RestrictCaseDelete` |

### 6.6 LWC Naming

| Component | Pattern | Example |
|---|---|---|
| LWC component folder/name | lowerCamelCase, descriptive | `caseDetailCard`, `accountSearchModal` |
| LWC event name | kebab-case | `case-selected`, `account-updated` |
| LWC public property (`@api`) | camelCase | `caseId`, `isReadOnly` |
| LWC private property | camelCase with leading underscore if reactive | `_caseRecord`, `_isLoading` |

### 6.7 Integration and Infrastructure Naming

| Component | Pattern | Example |
|---|---|---|
| Named Credential | `NC_<ProviderName>` | `NC_Twilio`, `NC_NetSuite` |
| External Credential | `EC_<ProviderName>` | `EC_Twilio_OAuth` |
| Platform Event | `<Domain>_Event__e` | `Case_Escalated__e`, `Integration_Error__e` |
| Change Data Capture | Standard Salesforce auto-naming applies | `CaseChangeEvent` |

---

## 7. Bulkification Rules

Salesforce processes records in batches of up to 200 in a single transaction. All code and automation must be designed to handle 200 records correctly and efficiently. Failure to bulkify is among the most common causes of governor limit exceptions in production.

### 7.1 Apex Bulkification Rules

1. **No SOQL inside loops** — collect all IDs first, then execute a single SOQL query outside the loop.
2. **No DML inside loops** — collect all records to insert/update/delete in a List, then execute a single DML operation outside the loop.
3. **Use Maps for O(1) lookups** — after a SOQL query, build a `Map<Id, SObject>` immediately. Never use a nested loop to find a record by ID.
4. **Invocable Apex MUST accept `List` inputs** — `@InvocableMethod` methods must have `List<InputClass>` parameters, not single-record parameters. Flows call invocable methods in bulk from collections.
5. **Selector/query methods must accept Sets or Lists of IDs** — never write a selector that queries for a single record by ID; always accept `Set<Id>` and return `List<SObject>`.
6. **Avoid large String concatenations in loops** — use `List<String>` and `String.join()` instead of `+=` in a loop to avoid heap pressure.

### 7.2 Correct Bulkification Pattern (Apex Example)

```apex
// WRONG — SOQL inside loop
for (Case c : cases) {
    Account acc = [SELECT Id, Name FROM Account WHERE Id = :c.AccountId]; // BAD
    c.Description = acc.Name;
}

// CORRECT — Collect IDs, query once, build Map, use Map in loop
Set<Id> accountIds = new Set<Id>();
for (Case c : cases) {
    accountIds.add(c.AccountId);
}
Map<Id, Account> accountMap = new Map<Id, Account>(
    [SELECT Id, Name FROM Account WHERE Id IN :accountIds]
);
for (Case c : cases) {
    Account acc = accountMap.get(c.AccountId);
    if (acc != null) {
        c.Description = acc.Name;
    }
}
```

### 7.3 Flow Bulkification Rules

1. **Use collection variables** — store records in collection variables rather than processing one at a time in loops with SOQL Get Records elements.
2. **Get Records before loops** — query all needed records before entering a loop. Never place a Get Records element inside a loop.
3. **Update Records after loops** — collect all records to update in a collection variable during the loop, then execute a single Update Records element after the loop exits.
4. **Avoid large loops** — flows that loop over more than a few hundred records risk hitting CPU limits. Delegate large-dataset operations to Batch Apex via invocable methods.

### 7.4 Batch and Async Rules

- **Batch Apex** (`Database.Batchable`): Use when processing more than 50,000 records or when the operation must be chunked to avoid governor limits. Set `executeBatch` scope appropriately (default 200; reduce if complex per-record processing approaches CPU limits).
- **Queueable Apex** (`Queueable`): Use for async chaining (one queueable enqueuing the next), for operations that need more CPU than a future method allows, or for passing complex objects between async contexts.
- **Future methods** (`@future`): Use sparingly — limited to primitive parameters, no chaining, no re-queuing. Prefer Queueable for new code.
- **Platform Events**: Use for fire-and-forget async processing, cross-system notifications, and decoupled event-driven architectures. Consumers process events in their own transaction context.

---

## 8. Governor Limits Reference

Know these limits. Design for them. The agent must consider all of the following when producing a solution and must flag any risk in the Security / Plan sections of a response.

### 8.1 Per-Transaction Limits

| Limit | Synchronous | Asynchronous | Mitigation Strategy |
|---|---|---|---|
| SOQL queries | 100 | 200 | Bulkify queries; use Maps; avoid SOQL in loops |
| DML statements | 150 | 150 | Bulkify DML; collect records before DML |
| DML rows | 10,000 | 10,000 | Batch large operations; chunk updates |
| Heap size | 6 MB | 12 MB | Avoid large String concatenation; use streaming patterns |
| CPU time | 10,000 ms | 60,000 ms | Avoid nested loops; pre-build Maps; offload to async |
| Callouts per transaction | 100 | 100 | Batch callout data; use async for non-blocking callouts |
| Future methods per transaction | 50 | — | Use Queueable chaining instead |
| Queueable jobs per transaction | 50 | 1 (from Queueable) | Design chains carefully |
| Email invocations | 10 | 10 | Batch email sends |
| SOSL queries | 20 | 20 | Minimise SOSL; use SOQL with LIKE where feasible |
| Aggregate SOQL query rows | 50,000 | 50,000 | Limit query scope; use LIMIT clauses |
| Total records retrieved via SOQL | 50,000 | 50,000 | Use selective queries; filter aggressively |

### 8.2 Flow-Specific Considerations

Flows share the same per-transaction governor limits as Apex when they operate in the same transaction. A record-triggered flow running on 200 records in a single save operation contributes SOQL queries and DML statements to the same transaction bucket as any Apex trigger or Process Builder running in the same save event.

- **Flow SOQL (Get Records)**: Each Get Records element counts as a SOQL query against the 100-query limit
- **Flow DML (Create/Update/Delete Records)**: Counts against the 150 DML statement limit
- **Loop limits**: Salesforce enforces a 2,000-iteration limit per flow interview; this is separate from the Apex limit but must be respected

### 8.3 Identifying Governor Limit Risks

For any proposed solution, the agent must ask:
- If this trigger/flow runs on 200 records, how many SOQL queries will execute? (Count Get Records elements + Apex queries)
- If this flow loops over 200 records and calls an action per record, how many DML statements will that be?
- Does this solution call a future method, queueable, or callout inside a loop?
- Does this batch job have the right scope size for the complexity of each record's processing?

---

## 9. Trigger and Flow Coexistence Rules

Triggers and Flows both automate record processing, and they can conflict if not carefully coordinated. This section defines the rules for managing both in the same org.

### 9.1 Design-Time Coordination

Before building any automation, define — in writing — which automation type handles which logic for each object. This decision document (a comment at the top of the trigger handler, or a Confluence page) must answer:
- What does the trigger handle? (synchronous, Apex-only operations; cross-object logic requiring complex Apex; operations that can't be done in Flow)
- What does the Flow handle? (declarative automations, simple field updates, notifications, record creation with standard logic)
- Is there any overlap? (if yes, one must be eliminated or the interface must be clearly defined)

### 9.2 Order of Execution Awareness

Salesforce processes automation in a defined order during a save event. The agent must be aware of this order to avoid infinite loops and unexpected interactions:

1. Before-save flows (record-triggered, before insert/update)
2. Apex before triggers
3. System validation rules
4. Custom validation rules
5. After-save flows (record-triggered, after insert/update)
6. Apex after triggers
7. Assignment rules, auto-response rules, workflow rules (legacy), escalation rules
8. Entitlement rules
9. Roll-up summary field recalculations
10. Criteria-based sharing rules

**Important:** This order can vary slightly based on API version and release. Always verify against the [official Salesforce documentation](https://help.salesforce.com/s/articleView?id=sf.flow_concepts_trigger_order_of_execution.htm) for your target org's release.

### 9.3 Recursion Prevention

**In Apex triggers:**
Use a static boolean flag in a dedicated `TriggerContext` or `RecursionGuard` class to prevent a trigger from running more than once per transaction on the same records.

```apex
public class TriggerContext {
    public static Boolean isCaseTriggerRunning = false;
}

// In CaseTrigger.trigger:
if (!TriggerContext.isCaseTriggerRunning) {
    TriggerContext.isCaseTriggerRunning = true;
    CaseTriggerHandler.handleAfterUpdate(Trigger.new, Trigger.oldMap);
}
```

**In record-triggered flows:**
Use entry conditions to detect actual field changes rather than running on every save. Use the `{!$Record.FieldName} != {!$Record__Prior.FieldName}` pattern in the flow's start conditions to ensure the flow only runs when the specific data it acts on has actually changed.

### 9.4 Infinite Loop Prevention (Cross-Automation)

Never allow a trigger and a flow to update the same field on the same record without a guard. This creates an infinite loop:
- Trigger updates Field A → Flow fires on Field A change → Flow updates Field B → Trigger fires again...

Guards required:
- Static boolean flags in Apex (see 9.3)
- `{!$Record.FieldName} != {!$Record__Prior.FieldName}` in flow entry conditions
- Idempotency checks: if the value to be written is already the correct value, skip the DML

### 9.5 Trigger vs Flow Decision Matrix

| Requirement | Use Trigger | Use Flow |
|---|---|---|
| Simple same-record field default | No | Yes — before-save flow |
| Complex same-record calculation requiring Apex | Yes (invocable from flow) | Delegate to invocable Apex |
| Related record creation (simple) | No | Yes — after-save flow |
| Related record creation (complex, multi-object) | Yes — service class | Delegate to invocable Apex |
| HTTP callout to external system | Yes — async (future/queueable) | Delegate to invocable Apex |
| Send email notification | No | Yes — after-save flow |
| Platform Event publication | Yes (for tight tx coupling) | Yes (for decoupled) |
| Assignment rule replacement | No | Yes — autolaunched/record-triggered |
| Complex approval orchestration | No | Yes — combined with Approval Process |

---

## 10. Token-Saving Guidance

AI agent context windows are finite. Attaching too many large files degrades response quality and increases cost. Follow these guidelines to maximise the value of attached context.

### 10.1 File Attachment Strategy

- **Single-component task** (e.g., "write one Apex class"): Attach only `global_ai_development_guidelines.md` + the relevant component file (e.g., `apex_guidelines.md`).
- **Multi-component task** (e.g., "build a feature with Apex + Flow + LWC"): Attach `global_ai_development_guidelines.md` + the 2-3 most relevant component files. Handle each component in a separate conversation turn if the task is large.
- **Review task**: Attach only the component file relevant to what is being reviewed. Skip this global file if the reviewer is focused on component-specific rules.
- **This file is the base**: Always attach this file when attaching any other file. The component files assume these global rules are in context.

### 10.2 When To Skip This File

Skip attaching this file if:
- The task is a single, isolated, trivial change (e.g., renaming a field label)
- The AI agent session already has this file loaded in its persistent context (e.g., Claude Project instructions)
- The conversation is a clarification or question only, with no code generation

### 10.3 Referencing Instead of Repeating

In long conversations, instead of re-pasting guideline content, reference it: *"Apply the security rules from Section 4 of global_ai_development_guidelines.md."* This works when the file has already been loaded earlier in the same conversation.

---

## 11. Definition of Done

A change is not complete until every applicable item in this checklist is confirmed. The agent MUST include a DoD verification in the Validation section of every response that produces code or configuration.

### 11.1 Functional Completeness

- [ ] All stated acceptance criteria are met
- [ ] The metadata compiles and validates without errors in the target org (sandbox or scratch org)
- [ ] Backward compatibility is maintained, or breaking changes are explicitly documented and communicated
- [ ] Edge cases identified during planning are handled (nulls, empty collections, missing lookups, etc.)
- [ ] Error cases return meaningful error messages, not generic exceptions

### 11.2 Security

- [ ] CRUD/FLS is enforced at all user-facing Apex entry points
- [ ] Sharing model is explicitly declared on every Apex class (`with sharing`, `without sharing`, or `inherited sharing`)
- [ ] The sharing model decision is documented in a class-level comment where it is not the obvious default
- [ ] No hardcoded record type IDs, queue IDs, user IDs, or profile names anywhere
- [ ] No hardcoded endpoints, API keys, tokens, passwords, or any credentials
- [ ] Named Credentials are used for all HTTP callouts
- [ ] Custom Metadata Types are used for non-secret configurable values
- [ ] `WITH USER_MODE` is used in SOQL queries for user-context operations (API v51.0+)

### 11.3 Code Quality

- [ ] All Apex classes include the standard developer header (Developer: Naresh, Title: Senior Salesforce Developer, creation date, last modified date, description, change log)
- [ ] Naming conventions from Section 6 are applied throughout
- [ ] All code is bulk-safe and handles 200 records per transaction without hitting governor limits
- [ ] No SOQL or DML inside loops
- [ ] Maps are used for O(1) lookups where record iteration requires related data
- [ ] Recursion and idempotency guards are in place for all automation
- [ ] Every Flow DML element, Create Records element, Update Records element, Delete Records element, and Action element has a fault path
- [ ] Logging is added for all critical operations (errors, integration calls, escalations) — see `observability_logging_guidelines.md`
- [ ] No dead code, commented-out blocks, or TODO stubs left in production-committed code

### 11.4 Testing

- [ ] Apex test classes follow the Arrange-Act-Assert (AAA) pattern
- [ ] Tests cover: success path, negative/error path, bulk path (200+ records), async path (if applicable)
- [ ] All HTTP callouts are mocked using `HttpCalloutMock` implementations
- [ ] `@isTest(SeeAllData=false)` is applied to all test classes (exceptions require explicit documented justification)
- [ ] Test data is created in test methods or via a TestDataFactory class — no dependency on existing org data
- [ ] Overall Apex code coverage is at or above 75% (Salesforce deployment minimum); team target is 85%+
- [ ] LWC components have Jest unit tests covering public API, user interactions, and error states

### 11.5 Release Readiness

- [ ] Deployment order is correct (see `deployment_guidelines.md`): custom objects → custom fields → record types → layouts → flows → Apex classes → Apex triggers → permission sets → permission set groups
- [ ] A validation deployment (check-only) has been executed successfully against the target org
- [ ] Quick deploy has been used if applicable (within 10-day validation window)
- [ ] A rollback plan is documented — including the exact steps to undo this change in production
- [ ] Destructive changes (deletions of metadata) are isolated in a separate `destructiveChanges.xml` and have been explicitly reviewed and approved

---

## 12. Common Anti-Patterns

These tables define what to do and what never to do. The agent MUST flag any deviation from the DO column or any occurrence of the DON'T column as a blocking issue.

### 12.1 DO — Required Practices

| Practice | Rationale |
|---|---|
| One trigger per object, using the handler class pattern | Multiple triggers on the same object have non-deterministic execution order; handler pattern keeps logic organised and testable |
| Enforce CRUD/FLS at every user-facing Apex entry point | Prevents unauthorised data access through API bypasses and custom UI; required by Salesforce security review |
| Use Named Credentials and External Credentials for all callouts | Credentials never appear in code; rotating credentials requires no code change or deployment |
| Implement the service/domain/selector architecture layering | Separates concerns; makes each layer independently testable; prevents business logic from leaking into infrastructure |
| Use before-save flows for same-record field updates | Before-save flows do not consume a DML statement; after-save flows do; incorrect choice wastes DML limit |
| Include a fault path on every Flow DML and action element | Unhandled faults surface as cryptic "unhandled exception" errors to users; fault paths allow graceful error messaging and logging |
| Use Custom Metadata Types for configurable non-secret values | Values are environment-specific and deployable without code changes; no hardcoding risk |
| Implement idempotency checks in all automation | Prevents duplicate processing when records are saved multiple times, or when batch jobs retry |
| Use permission sets and PSGs for feature access; profiles for baseline only | Profiles are global and hard to manage at scale; permission sets are composable, deployable, and revokable per user |
| Include the standard developer header on every Apex class | Provides traceability, ownership, and change history without relying solely on version control |
| Query record type developer names at runtime using Schema methods | Developer names are stable across orgs; IDs are org-specific and will break between environments |
| Use `inherited sharing` on service and utility classes | They adapt to the caller's sharing context, making them reusable across user and system contexts |
| Write all Apex selector methods to accept `Set<Id>` parameters | Ensures selectors are always bulk-safe by design |
| Document the sharing model decision on every `without sharing` class | Makes the security choice auditable and reviewable |

### 12.2 DON'T — Prohibited Practices

| Anti-Pattern | Why It Is Prohibited |
|---|---|
| Hardcoding record type IDs, queue IDs, user IDs, or profile IDs | Breaks immediately when deployed to a different org; breaks after a metadata refresh; constitutes a security risk in multi-environment setups |
| Hardcoding endpoints, API keys, tokens, passwords, or any credentials | Credentials in code are a critical security vulnerability; they leak in version control, logs, and debug output |
| Placing SOQL or DML inside a loop | Causes `System.LimitException: Too many SOQL queries: 101` or `Too many DML statements: 151` in bulk scenarios — guaranteed production failure |
| Placing business logic directly in a trigger body | Untestable without firing the trigger; hard to read; impossible to reuse; triggers have no easy way to return errors |
| Using `@isTest(SeeAllData=true)` without explicit justification | Makes tests dependent on org data; causes intermittent failures; hides missing test data factories |
| Writing multiple triggers for the same object | Non-deterministic execution order; conflicting logic; maintenance nightmare |
| Skipping fault paths on Flow DML and action elements | Any runtime error causes an unhandled exception that disrupts the save, corrupts partial data, and presents a cryptic error to users |
| Using `without sharing` without a documented justification | Silent privilege escalation; passes code review but violates least-privilege principle |
| Editing profiles to grant feature access instead of using permission sets | Profile changes affect all users assigned to that profile; impossible to target; creates regression risk |
| Placing a Get Records element inside a Flow loop | Each iteration queries the database; on 200 records this hits the 100 SOQL query limit immediately |
| Chaining automation without idempotency guards | A trigger fires a flow fires an invocable fires a platform event subscriber fires another flow — infinite loop, or at minimum unexpected repeated processing |
| Writing a consolidation without reading the source XML/code in full first | Field-level details (Subject suffixes, Origin overrides, specific formula expressions) are missed; gaps discovered late in QA cost more to fix than gaps caught at authoring time |
| Batching multiple changes before running a validation | Makes it harder to identify which change introduced a component error; increases debugging time | Run a dry-run (`--dry-run`) after every significant change, not only at the end |
| Using `WITH SECURITY_ENFORCED` in new code | Being deprecated in favour of `WITH USER_MODE`; inconsistent enforcement (FLS only, not CRUD); creates technical debt |
| Writing test classes that depend on existing data (no `TestDataFactory`) | Brittle tests; breaks in full sandboxes where data changes; fails in scratch orgs |
| Omitting the sharing keyword from an Apex class | Implicit `without sharing` behaviour in most contexts; silent security regression |
| Using Custom Settings for new configuration | Custom Metadata Types are the modern replacement; CMDT records are deployable, subscribable, and do not have the sharing/visibility issues of Custom Settings |

---

## 13. Review Checklist

Use this checklist before merging any pull request or promoting any change to a higher environment. All items must be confirmed.

### 13.1 Pre-Merge Review Checklist

**Plan and Scope:**
- [ ] The plan from Section 2 was followed — no scope creep, no undocumented changes
- [ ] Only the files listed in the file diff (Section 3) were changed
- [ ] Any out-of-scope findings were filed as separate tickets, not fixed silently

**Security:**
- [ ] CRUD/FLS is enforced at all user-facing entry points — verified line by line
- [ ] Every Apex class has an explicit sharing keyword — no omissions
- [ ] No hardcoded IDs, endpoints, tokens, or secrets present anywhere in the diff
- [ ] Named Credentials used for all HTTP callouts
- [ ] `WITH USER_MODE` used in SOQL queries for user-context operations

**Quality and Architecture:**
- [ ] The layering rules from Section 5 are respected — no business logic in triggers, LWC JS, or VF controllers
- [ ] All Apex is bulk-safe — no SOQL or DML in loops, Maps used for lookups
- [ ] All Flow DML and action elements have fault paths
- [ ] Naming conventions from Section 6 are applied throughout
- [ ] Developer header is present on all Apex classes

**Testing:**
- [ ] Test classes cover: success, negative, bulk (200 records), async paths
- [ ] All callouts are mocked
- [ ] `SeeAllData=false` on all test classes
- [ ] Coverage is at or above 85% (team target) / 75% (Salesforce minimum)

**Release:**
- [ ] Deployment order is correct
- [ ] Validation deployment (check-only) passed
- [ ] Rollback plan is documented
- [ ] Destructive changes are isolated and approved

**Definition of Done:**
- [ ] All DoD items from Section 11 are checked

---

## 14. Official References

The following official Salesforce documentation sources are the authoritative references for all rules in this guideline file. When in doubt, consult these sources. The agent should also consult these when a rule in this document conflicts with a more recent Salesforce release note.

| Resource | URL |
|---|---|
| Apex Developer Guide | https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/ |
| Apex Security and Sharing | https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_security_sharing_understand.htm |
| Apex Testing | https://trailhead.salesforce.com/content/learn/modules/apex_testing |
| Metadata API Developer Guide | https://developer.salesforce.com/docs/atlas.en-us.api_meta.meta/api_meta/ |
| Salesforce Governor Limits Cheat Sheet | https://developer.salesforce.com/docs/atlas.en-us.salesforce_app_limits_cheatsheet.meta/salesforce_app_limits_cheatsheet/ |
| Flow Trigger Order of Execution | https://help.salesforce.com/s/articleView?id=sf.flow_concepts_trigger_order_of_execution.htm |
| Security and Sharing (Apex) | https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_security_sharing_understand.htm |
| WITH USER_MODE in SOQL | https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_classes_with_user_mode.htm |
| Named Credentials | https://help.salesforce.com/s/articleView?id=sf.named_credentials_about.htm |
| Permission Sets | https://help.salesforce.com/s/articleView?id=sf.perm_sets_overview.htm |
| Custom Metadata Types | https://help.salesforce.com/s/articleView?id=sf.custommetadatatypes_overview.htm |
| Lightning Web Components Developer Guide | https://developer.salesforce.com/docs/component-library/documentation/en/lwc |
| Salesforce CLI (sf) Command Reference | https://developer.salesforce.com/docs/atlas.en-us.sfdx_cli_reference.meta/sfdx_cli_reference/ |
| Platform Events Developer Guide | https://developer.salesforce.com/docs/atlas.en-us.platform_events.meta/platform_events/ |

---

*This document is the master standard for all AI-assisted Salesforce development on this team.*
*Developer: Naresh | Senior Salesforce Developer*
*Version: 2.0 | April 2026*
*Attach this file to every AI agent session working on Salesforce metadata, code, or configuration.*
