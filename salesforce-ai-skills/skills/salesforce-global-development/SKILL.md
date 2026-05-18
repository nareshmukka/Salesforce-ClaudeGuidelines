---
name: salesforce-global-development
description: Production Salesforce AI skill for any Salesforce implementation/review/design task.
license: Apache-2.0
compatibility:
  - Claude Code
  - Claude Agents
  - Codex / ChatGPT
  - GitHub Copilot
metadata:
  version: 2.0.0
  last_updated: 2026-05-16
  owner: Reusable Salesforce AI Skills Library
---

## TRIGGER when
- The task involves any Salesforce implementation/review/design task.
- The user asks for implementation, refactor, troubleshooting, review, or best-practice validation in this area.
- The assistant must produce Salesforce-safe code/metadata with explicit security/testing notes.

## DO NOT TRIGGER when
- The task is unrelated to this component.
- Another specialized skill is the primary owner and this area is only incidental.
- The user asks for operational execution (deploy/publish/activate/destructive change) without explicit approval.

## Cross-skill routing
- Always read `../salesforce-global-development/SKILL.md`.
- Also read: Apex, Trigger, Flow, LWC, Testing, Metadata, Integration, Deployment.
- Deep guidance is included in this `SKILL.md`.

## Purpose
Provide independently usable, production-ready assistant guidance for this Salesforce domain without relying on external memory.

## Pre-edit workflow (must follow)
1. Identify target files and component type(s).
2. Read existing implementation and recent commit history around touched files.
3. Capture assumptions, dependencies, and security boundaries.
4. Plan smallest safe change with backward compatibility.
5. List validation commands/checks before editing.

## Post-edit workflow (must follow)
1. Re-open changed files and self-review for correctness.
2. Run local checks/tests relevant to touched component.
3. Verify no secrets, no org-specific IDs, and no unsafe automation instructions were introduced.
4. Document security review, validation results, deployment notes, and rollback notes.
5. Stop short of deploy/publish/activate unless explicitly approved.

## Salesforce best practices
Architecture layering: UI -> orchestration -> service -> selector/domain -> integration.
Security baseline: with/inherited sharing, CRUD/FLS checks, least privilege, Named Credentials for callouts.
No deploy/publish/activate/destructive changes without explicit user approval.

## Upstream Salesforce Skill Alignment
- Treat `forcedotcom/sf-skills` as the baseline style for Salesforce AI skills: precise trigger scope, hard-stop constraints, required inputs, validation steps, and completion format.
- Treat `trailheadapps/agent-script-recipes` as the canonical example set for Agent Script patterns: learn from recipe categories, then adapt patterns to this repo instead of copying examples blindly.
- Prefer `sf` CLI v2 commands with `--json` for automation-friendly output when interacting with orgs, agents, deploys, tests, or metadata.
- Diagnose before editing: reproduce errors, inspect generated/runtime evidence, and only then change code or metadata.
- Keep skills self-contained, but do not duplicate complete upstream repositories; record durable rules and patterns, not every upstream example.

## Examples
### Good example patterns
1. Separate orchestration in Flow from reusable Apex service methods.
2. Use CMDT + Named Credentials for environment configuration.

### Bad examples / avoid
1. Mix UI, SOQL, and callouts in one Apex controller method.
2. Apply destructive changes without manifest review and explicit approval.

## Review checklist
- [ ] Change scope is minimal and component-appropriate.
- [ ] Security model (sharing + CRUD/FLS + least privilege) is explicit.
- [ ] Bulk/performance constraints are addressed.
- [ ] Naming and metadata references are stable across orgs.
- [ ] User-facing behavior and error handling are deterministic.

## Validation checklist
- [ ] Relevant tests/checks executed and results captured.
- [ ] No hardcoded IDs, tokens, endpoints, credentials, or customer PII.
- [ ] No deploy/publish/activate/destructive command executed without approval.
- [ ] Links/paths/config references resolve in repo.
- [ ] Rollback approach documented.

## Common AI Mistakes to Avoid
| Mistake | Why it is dangerous | Correct approach |
|---|---|---|
| Editing before reading existing files fully | Breaks local conventions and causes regressions | Inspect target files, surrounding dependencies, and history first |
| Skipping security analysis | Can expose data or violate compliance | Explicitly review sharing, CRUD/FLS, auth, and least privilege |
| Treating happy-path as complete | Misses failures and edge cases | Add negative-path, bulk/performance, and error handling checks |
| Over-scoping changes | Increases risk and review time | Make smallest safe change and defer unrelated refactors |
| Assuming deployment/publish is allowed | Can cause production incidents | Require explicit approval for deploy/publish/activate/destructive actions |

## Output contract (assistant response format)
- Understanding
- Files inspected
- Changes made
- Security review
- Tests / validation
- Deployment notes
- Rollback notes


## Full Guidance

# Global AI Development Guidelines -- Master Skill File

**The constitution for AI-assisted Salesforce development on this team. Every other skill file in this library inherits from and extends this one. Attach this file to every agent session that touches Salesforce metadata, code, or configuration.**

**Verified against:** [Apex Developer Guide](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/) - [Apex Security and Sharing](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_security_sharing_chapter.htm) - [Set an Access Mode for Database Operations](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_classes_enforce_usermode.htm) - [Write Simplified and Secure Apex with Spring '23 Updates](https://developer.salesforce.com/blogs/2023/05/write-simplified-and-secure-apex-with-spring-23-updates) - [Apex Enterprise Patterns -- Service Layer (Trailhead)](https://trailhead.salesforce.com/content/learn/modules/apex_patterns_sl) - [Apex Enterprise Patterns -- Domain & Selector Layers (Trailhead)](https://trailhead.salesforce.com/content/learn/modules/apex_patterns_dsl) - [Salesforce Governor Limits Cheat Sheet](https://developer.salesforce.com/docs/atlas.en-us.salesforce_app_limits_cheatsheet.meta/salesforce_app_limits_cheatsheet/) - [Named Credentials](https://help.salesforce.com/s/articleView?id=sf.named_credentials_about.htm) - [Flow Trigger Order of Execution](https://help.salesforce.com/s/articleView?id=sf.flow_concepts_trigger_order_of_execution.htm). Last verified 2026-05-16.

> **Project context lives in [CLAUDE.md](../CLAUDE.md).** Target environment alias, manifest, current-API-version, agentic-pipeline lifecycle, lesson-routing table, project-specific flow inventory. This skill file is the **technical** constitution; CLAUDE.md is the **behavioral** contract. Read both at session start.

---

## 1. Identity & Authoring Convention

Every artifact this team produces is owned by one author and carries a consistent header.

| Field | Value | Source |
|---|---|---|
| Author | `the release owner` | `project configuration -> author` |
| Title | `Salesforce Developer` | `project configuration -> title` |
| Target environment alias | `<target-env-alias>` | `project configuration -> environmentAlias` |
| Manifest | `manifest/package.xml` | `project configuration -> manifest` |
| Current API version | `66.0` (Spring '26) | `project configuration -> currentApiVersion` |

**Hard rule:** never hardcode these values in a skill file, command prompt, or generated artifact. Read `project configuration` at session start and use those values. When a new release bumps the API version, bump it in `project configuration` only.

### 1.1 Standard Apex Doc-Block Header

Every new Apex class -- service, selector, handler, trigger, batch, queueable, scheduled, test -- opens with this header. No exceptions.

```apex
/**
 * @description  <One-line purpose. What this class does and which layer it belongs to.>
 * @author       the release owner | Salesforce Developer
 * @created      YYYY-MM-DD
 * @lastModified YYYY-MM-DD
 * @layer        Entry | Application | Domain | Infrastructure
 * @sharing      with sharing | without sharing | inherited sharing  (must match class declaration)
 *
 * Change log:
 *  - YYYY-MM-DD  the release owner  Initial version.
 *  - YYYY-MM-DD  the release owner  <change summary>.
 */
public inherited sharing class CaseService {
   // ...
}
```

For LWC, Flow, and metadata XML the same five pieces of information go into the description / interview label / `<description>` element. Agentic-pipeline output never ships an artifact without authorship traceability.

---

## 2. The Routing Table -- Don't Duplicate, Link Out

Each component area owns its own skill file. **This master file deliberately stays thin on component-specific guidance.** When the task involves a specific component, read the matching file in addition to this one.

| Task surface | Skill file (relative to `salesforce-ai-skills/`) |
|---|---|
| Apex class -- service, batch, queueable, scheduled, invocable | `../salesforce-apex/SKILL.md` |
| Apex trigger and trigger handler | `../salesforce-trigger/SKILL.md` |
| Apex test class, Jest spec, test data factory | `../salesforce-testing/SKILL.md` |
| Flow -- record-triggered, autolaunched, screen, subflow | `../salesforce-flow/SKILL.md` |
| Lightning Web Component | `../salesforce-lwc/SKILL.md` |
| Custom object, field, validation rule, CMDT, record type | `../salesforce-metadata/SKILL.md` |
| Permission set, Permission Set Group, Muting PS | `../salesforce-permissions/SKILL.md` |
| Callout, Named Credential, Platform Event, CDC, integration | `../salesforce-integration/SKILL.md` |
| Logging, error tracking, AppLog, correlation IDs | `../salesforce-observability/SKILL.md` |
| Deployment, package.xml, validation, rollback | `../salesforce-deployment/SKILL.md` |
| Email template | `../salesforce-email-template/SKILL.md` |
| Prompt Builder template | `../salesforce-prompt-template/SKILL.md` |
| Lightning App Builder page (FlexiPage) | `../salesforce-flexipage/SKILL.md` |
| Visualforce page or controller | `../salesforce-visualforce/SKILL.md` |
| Agentforce agent topic / instruction (Builder UI) | `../salesforce-agentforce-script/SKILL.md` |
| Agentforce Builder metadata (Bot, BotVersion, GenAiPlannerBundle) | `../salesforce-agentforce-builder/SKILL.md` |
| Agentforce `.agent` DSL -- authoring bundle, lifecycle | `../salesforce-agentforce-authoring-bundle/SKILL.md` |
| Agent Script grammar reference (read-only canonical) | `../salesforce-agentforce-script/SKILL.md` |
| Agentforce Service Assistant on Case (the target environment) | `../salesforce-service-assistant/SKILL.md` |

Multi-component task -> read every applicable file. Single-component task -> this file + the one matching file. Pure-question or clarification task -> CLAUDE.md only.

---

## 3. Architecture Layering -- The Four-Layer Model

Every implementation on this team conforms to a four-layer architecture grounded in the [Apex Enterprise Patterns](https://trailhead.salesforce.com/content/learn/modules/apex_patterns_sl). Knowing **where** code belongs is as important as writing it correctly.

```
"Œ""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
"‚  ENTRY LAYER                                                        "‚
"‚  Triggers - Flows - LWC - REST/SOAP APIs - Invocable Apex          "‚
"‚  Visualforce controllers - Batch entry points - Schedulers          "‚
"‚  Responsibility: Accept input, surface-validate, delegate           "‚
"‚  PROHIBITED:    Business logic, SOQL/DML, branching beyond surface  "‚
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""¤
"‚  APPLICATION (SERVICE) LAYER                                        "‚
"‚  Service classes - Orchestration - Transaction-boundary owners      "‚
"‚  Responsibility: Orchestrate business operations, own tx atomicity  "‚
"‚  PROHIBITED:    Direct SOQL/DML -- delegate to Domain/Infrastructure "‚
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""¤
"‚  DOMAIN LAYER                                                       "‚
"‚  Domain classes - Business-rule validators - Idempotency guards     "‚
"‚  Responsibility: Encode and enforce business invariants             "‚
"‚  PROHIBITED:    Persistence concerns, callouts, async enqueueing    "‚
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""¤
"‚  INFRASTRUCTURE LAYER                                               "‚
"‚  Selectors (repositories) - DML wrappers - HTTP clients             "‚
"‚  Platform-Event publishers - Async dispatchers - Logger             "‚
"‚  Responsibility: All persistence, all I/O, all external comm        "‚
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""˜
```

### 3.1 Layer Rules

**Entry layer**
- A trigger body contains exactly one line: a call to its handler class. No SOQL, no DML, no branching.
- A Flow delegates anything beyond simple field updates and decisions to an Invocable Apex method.
- An LWC JavaScript file contains presentation logic only. Data shaping, validation, calculation lives in Apex.
- A Visualforce controller method calls a service class. It does not implement business logic.

**Application (service) layer**
- Service methods are named business operations: `CaseService.assignToQueue(List<Case> cases)`, `OrderService.cancel(Set<Id> orderIds)`.
- The service owns the transaction boundary. If the operation must be atomic, the service ensures it (savepoints if rollback needed).
- Default sharing keyword: `inherited sharing` -- the service adapts to its caller's context.
- A service NEVER queries directly. It calls a selector. A service NEVER does DML directly. It calls an infrastructure wrapper or domain method that delegates.

**Domain layer**
- Pure business logic -- validation, transformation, rule evaluation. No I/O. No platform dependencies. Highly testable.
- Domain classes accept SObject lists/maps in their constructors and expose methods like `validate()`, `applyDefaults()`, `isEligibleForEscalation()`.

**Infrastructure layer**
- All SOQL lives in selectors. A selector method accepts `Set<Id>` or a filter struct and returns `List<SObject>` or a typed wrapper.
- All HTTP callouts live in dedicated client classes (`TwilioSmsClient`, `NetSuiteClient`). Other layers consume an interface (`ISmsProvider`), never the concrete class.
- All Platform Event publishing lives in dedicated publishers.
- The Logger (see `../salesforce-observability/SKILL.md`) is the only path to `AppLog__c`.

### 3.2 Integration Isolation

Any external system gets a dedicated provider client class. The rest of the application talks to an interface, never the concrete client. This enables:

- Mocking in tests without scattering `HttpCalloutMock` boilerplate
- Swapping providers without touching business logic
- Centralised retry, idempotency, and error handling

Details: `../salesforce-integration/SKILL.md`.

---

## 4. Security & Access Control

Security is non-negotiable. Every violation is a blocking finding, not a suggestion.

### 4.1 The Sharing Keyword Is Mandatory

Every Apex class declares its sharing keyword explicitly. **A missing sharing keyword is a security regression** -- implicit behaviour defaults to `without sharing` in most contexts. This is enforced by code review, not by the compiler.

| Keyword | Behaviour | When to use |
|---|---|---|
| `with sharing` | Enforces the running user's record sharing | Default for user-facing classes -- controllers, invocable methods, REST endpoints, LWC Apex controllers |
| `without sharing` | Ignores all record sharing | System operations that genuinely require cross-user access (batch jobs, system integrations). Must be justified in a class-level comment. |
| `inherited sharing` | Inherits the caller's sharing context | Service and utility classes -- they adapt to whoever invokes them. Default for the application/service layer. |

### 4.2 CRUD/FLS Enforcement

CRUD (object-level) and FLS (field-level) must be enforced at every Apex entry point where user-context data access occurs.

**Preferred approach (API v56.0+, Winter '23+):** use `WITH USER_MODE` in SOQL and `AccessLevel.USER_MODE` on Database operations. Per the [Spring '23 blog](https://developer.salesforce.com/blogs/2023/05/write-simplified-and-secure-apex-with-spring-23-updates), this enforces CRUD, FLS, **and** record sharing inline.

```apex
// SOQL -- user mode
List<Case> cases = [
    SELECT Id, Subject, Status FROM Case WHERE AccountId IN :acctIds
    WITH USER_MODE
];

// DML -- user mode via Database method
Database.SaveResult[] results = Database.update(
    casesToUpdate, /* allOrNone */ false, AccessLevel.USER_MODE
);
```

**For graceful degradation** (skip inaccessible fields rather than throw `QueryException`), use `Security.stripInaccessible`:

```apex
SObjectAccessDecision decision = Security.stripInaccessible(
    AccessType.READABLE,
    [SELECT Id, Name, Case_Category__c FROM Case WHERE AccountId = :accountId]
);
List<Case> safeRecords = (List<Case>) decision.getRecords();
```

**Prohibited:** `WITH SECURITY_ENFORCED` in new code. It enforces FLS only (not CRUD or sharing) and has been superseded by `WITH USER_MODE` since Spring '23. Existing usages should be migrated when touched.

Component-specific patterns (selector boilerplate, `@AuraEnabled` controllers, REST endpoints) live in `../salesforce-apex/SKILL.md`.

### 4.3 Named Credentials for All Callouts

Every outbound HTTP call uses a Named Credential as the endpoint. `callout:NC_Twilio/messages` -- never a raw URL, never an API key in code.

- API endpoints, base URLs, host names -> Named Credential
- API keys, OAuth tokens, client secrets, passwords, certificates -> External Credential (OAuth) or Named Credential (legacy auth)
- Non-secret per-environment configuration (timeouts, feature flags, thresholds) -> Custom Metadata Type

Details: `../salesforce-integration/SKILL.md`.

### 4.4 PII Handling Baseline

This baseline applies to every component. Component files may extend it; they may not relax it.

| Concern | Baseline rule |
|---|---|
| Logging | Never log: passwords, API keys, OAuth tokens, full credit-card numbers, government IDs, full email body content. Log: record Id, object type, operation, correlation Id, error message. See `../salesforce-observability/SKILL.md`. |
| Debug logs | `System.debug()` is for development only. Production code uses the `AppLogger` class. Debug-only `System.debug` lines are removed before commit. |
| Display | LWC and Visualforce that surface PII honor the running user's FLS -- use `WITH USER_MODE` or `stripInaccessible` so a user without permission never sees the field. |
| Storage | PII fields are marked Compliance Categorization on the Field metadata where applicable. Encrypted-at-rest via Shield where the data classification requires it. |
| Outbound | When sending PII to an external system, scrub via a dedicated mapper class that explicitly lists each field. Never serialize a raw SObject to a third party. |
| Tests | Test data factories generate fake PII (e.g., `user+test@example.invalid`). Never check real PII into source control. |

---

## 5. Hard-Stop Constraints

These are absolute. An agent that violates any of these has failed the task regardless of other quality.

1. **No hardcoded org-specific IDs** -- record types, queues, profiles, users, groups, record IDs. Always look up at runtime via Schema methods or query by developer name. See Section 6 2. **No hardcoded endpoints, credentials, or secrets** -- every URL behind a Named Credential, every secret in External Credentials or platform credential stores. See Section 4 3.
3. **No SOQL or DML inside loops** -- collect IDs first, query once, build a Map, iterate over the Map. See `../salesforce-apex/SKILL.md` for the canonical pattern.
4. **No unilateral destructive operations** -- do not delete metadata, deactivate flows, drop permission sets, or remove fields without explicit user direction. The Salesforce delivery guidance project specifically forbids deactivating old flows and activating new flows (see [CLAUDE.md Section 3 CLAUDE.md)).
5. **No silent scope expansion** -- if a change requires touching files outside the stated scope, pause and ask. Do not "helpfully" fix adjacent issues.
6. **No bypass of the agentic pipeline gates** -- Architect -> Developer -> QA. QA findings block release; the developer iterates until QA passes, capped at `qaDevIterationCap` (currently 2) per `project configuration`.
7. **No `@isTest(SeeAllData=true)` without a documented justification** -- test classes own their data. See `../salesforce-testing/SKILL.md`.
8. **No `WITH SECURITY_ENFORCED` in new code** -- use `WITH USER_MODE`. See Section 4 2.
9. **No missing sharing keyword on Apex classes** -- every class declares one. See Section 4 1.
10. **No commit of secrets, API keys, or production data** to the repo. Tests use factories; integration credentials live in Named/External Credentials.

---

## 6. Hardcoded-Values Prohibition (Expanded)

The following are **never** acceptable in code, flow XML, metadata, or configuration:

| Prohibited | Correct approach |
|---|---|
| Record type ID (`'012000000000000AAA'`) | `Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('Enterprise_Support').getRecordTypeId()` |
| Queue / Group ID | `[SELECT Id FROM Group WHERE Type='Queue' AND DeveloperName='Support_Tier_1' LIMIT 1]` |
| User ID | Lookup by username; pass via parameter; never embed |
| Profile ID or Profile name | Use Permission Sets -- profile-based gating is fragile and not granular |
| Org ID | Use `UserInfo.getOrganizationId()` if comparison needed; never embed a literal |
| API endpoint, base URL, host | Named Credential -- `callout:NC_<Provider>/path` |
| API key, OAuth token, client secret, password, certificate | External Credential (OAuth) or Named Credential (legacy) |
| Timeout, retry count, batch size, threshold | Custom Metadata Type (`__mdt`) |
| Feature flag | Custom Metadata Type record, queried at runtime |
| Picklist string value used in branching | Reference the picklist via `Schema.PicklistEntry.getValue()`, or centralise in a constants class |
| Email address used by automation | CMDT record or Custom Setting (CMDT preferred) |
| Magic number / magic string | Named `static final` constant with a comment explaining why |

Any of the above found in existing code during a task -- flag it as a finding, even if not in the immediate scope of the change.

---

## 7. Naming Conventions (Project-Wide)

Consistent naming is a team standard. The agent applies these conventions to every artifact it produces. Deviations require explicit justification.

### 7.1 Apex

| Component | Pattern | Example |
|---|---|---|
| Service | `<Domain>Service` | `CaseService`, `AccountService` |
| Selector / Repository | `<Domain>Selector` | `CaseSelector`, `OpportunitySelector` |
| Domain | `<Domain>Domain` or `<Domain>Rules` | `CaseDomain`, `AccountRules` |
| Trigger | `<Object>Trigger` | `CaseTrigger`, `OpportunityTrigger` |
| Trigger Handler | `<Object>TriggerHandler` | `CaseTriggerHandler` |
| Batch | `<Domain>Batch` or `<Domain>BatchJob` | `CaseEscalationBatch` |
| Queueable | `<Domain>Queueable` | `CaseNotificationQueueable` |
| Scheduled | `<Domain>Scheduler` | `CaseEscalationScheduler` |
| HTTP client | `<Provider>Client` | `TwilioSmsClient`, `NetSuiteClient` |
| Interface | `I<Capability>` | `IEmailSender`, `ISmsProvider` |
| Test class | `<ClassName>Test` | `CaseServiceTest` |
| Test factory | `<Domain>TestFactory` or shared `TestDataFactory` | `CaseTestFactory` |

### 7.2 Flow

| Flow type | Pattern | Example |
|---|---|---|
| Record-triggered before-save | `<Object>_BS_<Purpose>` | `Case_BS_Normalize_Case` |
| Record-triggered after-save | `<Object>_AS_<Purpose>` | `Case_AS_Status_SLA`, `Case_AS_Escalation` |
| Autolaunched | `<Domain>_Autolaunched` | `CaseNotification_Autolaunched` |
| Subflow | `<Domain>_Subflow` | `LogError_Subflow` |
| Screen flow | `<Domain>_ScreenFlow` | `CaseCreation_ScreenFlow` |
| Scheduled flow | `<Domain>_Scheduled` | `CaseEscalationCheck_Scheduled` |

Flow variable naming: `inputX`, `outputX`, `colObjectRecords`, `loopObjectRecord`, descriptive camelCase for primitives. Details in `../salesforce-flow/SKILL.md`.

### 7.3 Metadata

| Component | Pattern | Example |
|---|---|---|
| Custom Object | `<Descriptive>__c` | `Support_Case__c`, `Loyalty_Programme__c` |
| Custom Field | descriptive, no abbreviations | `Case_Category__c`, `Escalation_Reason__c` |
| Junction Object | `<ObjectA>_<ObjectB>__c` | `Case_Product__c` |
| Custom Metadata Type | `CMDT_<Domain>__mdt` | `CMDT_IntegrationConfig__mdt` |
| Record Type developer name | `<Snake_Case>` | `Enterprise_Support` |
| Validation Rule | `VR_<Object>_<Intent>` | `VR_Case_SubjectRequired` |

### 7.4 Access Control

| Component | Pattern | Example |
|---|---|---|
| Permission Set | `PS_<DomainOrRole>` | `PS_SupportAgent` |
| Permission Set Group | `PSG_<DomainOrRole>` | `PSG_SupportAgent` |
| Muting Permission Set | `MPS_<Restriction>` | `MPS_RestrictCaseDelete` |

### 7.5 Integration

| Component | Pattern | Example |
|---|---|---|
| Named Credential | `NC_<Provider>` | `NC_Twilio`, `NC_NetSuite` |
| External Credential | `EC_<Provider>` | `EC_Twilio_OAuth` |
| Platform Event | `<Domain>_Event__e` | `Case_Escalated__e` |

### 7.6 LWC

| Component | Pattern | Example |
|---|---|---|
| LWC folder/component | lowerCamelCase | `caseDetailCard`, `accountSearchModal` |
| Public property (`@api`) | camelCase | `caseId`, `isReadOnly` |
| Event name | kebab-case | `case-selected`, `account-updated` |

---

## 8. Definition of Done -- Universal Checklist

A change is complete only when every applicable item is checked. This is the **universal** DoD; component skill files may add to it but never relax it.

### 8.1 Functional

- [ ] All stated acceptance criteria are met.
- [ ] Metadata compiles and validates in the target environment (test environment or scratch).
- [ ] Edge cases identified during planning are handled (nulls, empty collections, missing lookups).
- [ ] Error paths return meaningful messages, not generic exceptions.
- [ ] Backward compatibility maintained, or breaking changes explicitly documented.

### 8.2 Security

- [ ] CRUD/FLS enforced at every user-facing entry point (`WITH USER_MODE` or `stripInaccessible`).
- [ ] Sharing keyword declared explicitly on every Apex class.
- [ ] `without sharing` declarations carry a class-level comment justifying the choice.
- [ ] No hardcoded record-type IDs, queue IDs, user IDs, profile names, endpoints, or secrets (Section 5 Section 6 Named Credentials used for every HTTP callout.
- [ ] Custom Metadata Types used for non-secret per-environment configuration.
- [ ] PII handling baseline (Section 4 4) satisfied.

### 8.3 Architecture & Code Quality

- [ ] Standard Apex doc-block header (Section 1 1) present on every new/modified class.
- [ ] Layering (Section 3 respected -- no business logic in triggers, LWC JS, or VF controllers.
- [ ] Naming conventions (Section 7 applied throughout.
- [ ] Bulk-safe -- no SOQL/DML in loops; Maps used for O(1) lookups; bulk path mentally simulated for 200 records.
- [ ] Recursion / idempotency guards on all automation that can re-fire.
- [ ] Every Flow DML, Create/Update/Delete Records element, and Action element has a fault path.
- [ ] Logging added for errors, integration calls, escalations (see `../salesforce-observability/SKILL.md`).
- [ ] No dead code, no commented-out blocks, no TODO stubs left in committed code.

### 8.4 Testing

- [ ] Test classes follow Arrange-Act-Assert (AAA).
- [ ] Tests cover success, negative, bulk (200+), and async paths where applicable.
- [ ] All HTTP callouts mocked via `HttpCalloutMock`.
- [ ] `@isTest(SeeAllData=false)` on every test class (exceptions documented and justified).
- [ ] Test data created by a factory -- no dependency on existing org data.
- [ ] Coverage >= 75% (Salesforce minimum); team target >= 85%.
- [ ] LWC components have Jest unit tests for public API, user interactions, error states.
- [ ] **Project exception:** Salesforce delivery guidance defers test classes per CLAUDE.md Section 3 `testsDefault: deferred`). Resume tests after test-environment functional testing.

### 8.5 Release Readiness

- [ ] Deployment order correct (see `../salesforce-deployment/SKILL.md`).
- [ ] Validation deployment (check-only / dry-run) passed in target environment. Project default command:
      ```bash
      sf project deploy start \
        --manifest manifest/package.xml \
        --target-org <target-env-alias> \
        --dry-run --test-level RunLocalTests --wait 60
      ```
- [ ] Quick deploy used when applicable (within 10-day validation window).
- [ ] Rollback plan documented -- exact steps to revert in production.
- [ ] Destructive changes isolated in `destructiveChanges.xml` and explicitly approved.
- [ ] **Project rules from CLAUDE.md Section 3 honored:** new flows deployed as `Draft` (not active); old flows not deactivated by the agent.

---

## 9. Process Anti-Patterns

Component-level anti-patterns (specific Apex / Flow / LWC mistakes) live in the **Common AI Mistakes to Avoid** tables of the respective skill files. This master file owns the **process-level** anti-patterns -- how AI agents work, not what they write.

### 9.1 DO -- Required Process Practices

| Practice | Rationale |
|---|---|
| Read the source file in full before writing | Field-level details (Subject suffixes, Origin overrides, specific formulas) are missed when skimming. Gaps caught at QA cost more than gaps caught at authoring. |
| Validate frequently -- after each significant change, not only at the end | When something breaks, the smaller the diff the easier the diagnosis. |
| State scope explicitly at the start of every task | Anchors the agent and the human to the same boundaries. Re-anchor after any clarification. |
| Pause when scope expands unexpectedly | "I noticed N also needs to change -- confirm before proceeding?" beats silent helpful fixes. |
| Apply the rule from the skill file even if it conflicts with general best-practice training data | This library is project-tested. Generic best practice is not. |
| Cite which section / rule was applied in the Security and Architecture summaries | Auditable. Prevents hallucinated compliance. |
| Read CLAUDE.md and `project configuration` at session start | Project-specific rules and current values live there. Hardcoding from memory drifts. |
| Use the agentic pipeline (`/sf-lead`) for any non-trivial change | Architect -> Developer -> QA gates catch what one-shot prompts miss. |

### 9.2 DON'T -- Prohibited Process Practices

| Anti-pattern | Why it is prohibited |
|---|---|
| Writing a consolidation or refactor without reading the source XML/code in full first | Misses field-level details; gaps caught late in QA cost more than gaps caught at authoring |
| Batching multiple changes before running a validation | Harder to identify which change introduced an error; longer debug cycles. Validate after every significant change. |
| Silently fixing pre-existing bugs outside the task scope | Pollutes the diff; review can't trace the change to a ticket; risks regressions in unrelated areas |
| Activating new flows or deactivating old flows (Salesforce delivery guidance) | Explicitly forbidden by CLAUDE.md Section 3 the release owner handles activation manually after test-environment validation |
| Deploying without a dry-run | Production-impacting metadata changes must validate against the target environment first |
| Quoting a Salesforce feature's minimum API version from memory or training data | Training data drifts. `WITH USER_MODE` is API 56.0 (Winter '23), not 50.0 or 51.0. Always cross-check developer.salesforce.com or the release blog before citing a version |
| Bypassing the skill file because "I know how to do this" | The skill files encode project-specific patterns and lessons. They override training data. |
| Treating CLAUDE.md or `project configuration` values as defaults that can be overridden | They are the single source of truth. Bump in config, never inline. |
| Skipping the `Plan / Files / Implementation / Security / Testing / Validation / Rollback` output sections | These sections make the work auditable. Skipping them shifts review burden onto the human. |
| Producing a fix without proposing a rollback | Every production change must be reversible. |

---

## 10. Pre-Implementation Steps (Every Task)

Before generating any code, metadata, or configuration, the agent confirms each of the following.

1. **Restate scope in own words.** Ask for clarification on any ambiguity. Never assume.
2. **Produce a numbered plan.** What will be built, in which layer, with what dependencies. State assumptions explicitly.
3. **List exact files** to be created, modified, or deleted. Include `.cls-meta.xml`, `.flow-meta.xml`, layout XML, etc.
4. **Identify security touchpoints.** CRUD/FLS, sharing model, credential handling, callout endpoints, PII surfaces.
5. **Identify governor-limit risks.** Bulk path for 200 records -- SOQL count, DML count, CPU pressure, heap.
6. **Identify rollback steps.** Exact `sf` commands or metadata changes to undo.
7. **Cite the skill files in play.** "Applying Section 4 2 of `../salesforce-global-development/SKILL.md` and Section 5 of `../salesforce-apex/SKILL.md`."

Output sections in every response, in this order: **Plan - Files - Implementation - Security - Testing - Validation - Rollback**. Section may be `N/A -- <reason>` but must not be silently dropped.

---

## 11. Cross-Cutting Empirical Findings & Implementation Notes

When a process-level finding emerges -- something about how Salesforce documentation, CLI tooling, or AI-agent behavior interacts with this project -- it goes here. Component-specific findings go to the matching skill file (see [CLAUDE.md Section 6 CLAUDE.md) routing table).

| # | Date | Documented approach | What actually works | Why / Context |
|---|---|---|---|---|
| 1 | 2026-05-13 | `WebFetch` against a `developer.salesforce.com/docs/...` page returns the full doc content for AI-agent consumption | WebFetch returns only the empty HTML shell (no content). Workaround: WebSearch first (Google has indexed the rendered HTML and returns useful summaries); then `WebFetch` on the specific result URL. Pages on `release-notes.docs.salesforce.com` and `developer.salesforce.com/blogs/*` DO return full content directly. | developer.salesforce.com doc pages are JavaScript-rendered client-side. WebFetch executes no JS, so the shell is all you get. Discovered during `/sf-lead` review of `salesforce-ai-skills/` on 2026-05-13. Affects all AI agents (Claude Code, Claude API, etc.) doing doc verification. |

---

## 12. Common AI Mistakes to Avoid (Process-Level)

Reactive ledger -- each row records a mistake actually made by an AI agent or developer against the rules above, and the corrected approach. Component-specific mistakes (specific Apex / Flow / LWC patterns) go into the matching skill file per the routing table in [CLAUDE.md Section 6 CLAUDE.md).

| # | Mistake | Correct approach |
|---|---|---|
| 1 | Hardcoding record type IDs, queue IDs, user IDs, or profile IDs | Look up at runtime via Schema methods or query by developer name (Section 6 2 | Hardcoding endpoints, API keys, tokens, passwords, or any credentials | Named Credential for endpoints; External Credential for auth; CMDT for non-secret config (Section 4 3, Section 6 3 | Placing SOQL or DML inside a loop | Collect IDs first, query once, build a Map, iterate the Map outside the loop (Section 5 hard-stop #3) |
| 4 | Placing business logic in a trigger body, LWC JS, or VF controller | Delegate to a service class; entry layer is for surface validation and delegation only (Section 3 5 | Using `@isTest(SeeAllData=true)` without documented justification | Use a TestDataFactory; tests own their data |
| 6 | Skipping fault paths on Flow DML and action elements | Every DML/action element gets a fault path that logs and surfaces a meaningful message |
| 7 | Using `without sharing` without a documented justification | Default to `with sharing` or `inherited sharing`; document any escalation in a class comment (Section 4 1) |
| 8 | Editing profiles to grant feature access instead of using permission sets | Profiles are baseline only; features are gated by Permission Sets / PSGs (Section 7 4) |
| 9 | Placing a Get Records element inside a Flow loop | Move the query outside the loop; collect IDs in a collection variable first |
| 10 | Chaining automation without idempotency guards | Static boolean flags in Apex; entry conditions `$Record.X != $Record__Prior.X` in flows; skip DML if value unchanged |
| 11 | Writing a consolidation without reading the source XML/code in full first | Field-level details (Subject suffixes, Origin overrides, specific formulas) are missed; gaps caught at QA cost more than gaps caught at authoring time |
| 12 | Batching multiple changes before running a validation | Run a dry-run (`--dry-run`) after every significant change, not only at the end |
| 13 | Using `WITH SECURITY_ENFORCED` in new code | Use `WITH USER_MODE` (API v56.0+); `WITH SECURITY_ENFORCED` enforces FLS only and is superseded (Section 4 2) |
| 14 | Quoting a Salesforce feature's minimum API version from memory or training data | Training data is dated; minimum API versions drift (e.g. `WITH USER_MODE` is API 56.0, NOT 50.0 or 51.0). Always cross-check developer.salesforce.com or the release blog before citing a version, and align with the file that owns that specific feature (e.g. ../salesforce-apex/SKILL.md for Apex features) |
| 15 | Writing test classes that depend on existing data (no `TestDataFactory`) | Brittle tests; breaks in full test environmentes where data changes; fails in scratch orgs |
| 16 | Omitting the sharing keyword from an Apex class | Implicit `without sharing` behaviour in most contexts; silent security regression (Section 4 1) |
| 17 | Using Custom Settings for new configuration | Custom Metadata Types are the modern replacement -- deployable, subscribable, no sharing/visibility issues |
| 18 | Writing multiple triggers for the same object | One trigger per object via handler class -- multiple triggers have non-deterministic execution order |
| 19 | Activating new flows or deactivating old flows on the Salesforce delivery guidance project | Forbidden by CLAUDE.md Section 3 the release owner handles activation manually after test-environment validation. Deploy new flows as `Draft`. |
| 20 | Hardcoding `apiVersion` (e.g. `<apiVersion>62.0</apiVersion>`) in component metadata | Read `currentApiVersion` from `project configuration` (currently `66.0`) -- bump in config on each release, never inline |

---

## 13. Review Checklist (Pre-Merge / Pre-Promote)

Before merging a PR or promoting a change to a higher environment, confirm every item.

**Plan and scope**
- [ ] Plan from Section 10 was followed -- no scope creep, no undocumented changes.
- [ ] Only the files listed in the file diff were changed.
- [ ] Out-of-scope findings filed as separate tickets, not silently fixed.

**Security**
- [ ] CRUD/FLS enforced at every user-facing entry point -- verified line by line.
- [ ] Every Apex class has an explicit sharing keyword.
- [ ] No hardcoded IDs, endpoints, tokens, or secrets in the diff.
- [ ] Named Credentials used for every callout.
- [ ] `WITH USER_MODE` used in SOQL for user-context operations.
- [ ] PII handling baseline (Section 4 4) satisfied.

**Architecture and quality**
- [ ] Layering (Section 3 respected -- no business logic in entry layer.
- [ ] Bulk-safe -- no SOQL/DML in loops; Maps for lookups.
- [ ] Every Flow DML / action element has a fault path.
- [ ] Naming conventions (Section 7 applied throughout.
- [ ] Apex doc-block header (Section 1 1) present.

**Testing**
- [ ] Tests cover success, negative, bulk, async paths (or deferred per project rule).
- [ ] All callouts mocked.
- [ ] `SeeAllData=false` on all test classes.
- [ ] Coverage >= 85% (team target) or >= 75% (Salesforce minimum).

**Release**
- [ ] Deployment order correct.
- [ ] Validation deployment (dry-run) passed.
- [ ] Rollback plan documented.
- [ ] Destructive changes isolated and approved.
- [ ] CLAUDE.md project rules honored (Draft status, no flow deactivation by agent).

**Definition of Done**
- [ ] Every applicable item from Section 8 checked.

---

## 14. Official References

Authoritative sources for the rules in this file. When a rule here conflicts with a more recent release note, the release note wins -- and an empirical-findings row gets added to Section 11 Resource | URL |
|---|---|
| Apex Developer Guide | https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/ |
| Apex Security and Sharing | https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_security_sharing_chapter.htm |
| Set an Access Mode for Database Operations (`WITH USER_MODE`) | https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_classes_enforce_usermode.htm |
| Write Simplified and Secure Apex with Spring '23 Updates | https://developer.salesforce.com/blogs/2023/05/write-simplified-and-secure-apex-with-spring-23-updates |
| Apex Enterprise Patterns -- Service Layer (Trailhead) | https://trailhead.salesforce.com/content/learn/modules/apex_patterns_sl |
| Apex Enterprise Patterns -- Domain & Selector Layers (Trailhead) | https://trailhead.salesforce.com/content/learn/modules/apex_patterns_dsl |
| Apex Testing (Trailhead) | https://trailhead.salesforce.com/content/learn/modules/apex_testing |
| Salesforce Governor Limits Cheat Sheet | https://developer.salesforce.com/docs/atlas.en-us.salesforce_app_limits_cheatsheet.meta/salesforce_app_limits_cheatsheet/ |
| Flow Trigger Order of Execution | https://help.salesforce.com/s/articleView?id=sf.flow_concepts_trigger_order_of_execution.htm |
| Named Credentials | https://help.salesforce.com/s/articleView?id=sf.named_credentials_about.htm |
| Permission Sets Overview | https://help.salesforce.com/s/articleView?id=sf.perm_sets_overview.htm |
| Custom Metadata Types | https://help.salesforce.com/s/articleView?id=sf.custommetadatatypes_overview.htm |
| Lightning Web Components Developer Guide | https://developer.salesforce.com/docs/component-library/documentation/en/lwc |
| Platform Events Developer Guide | https://developer.salesforce.com/docs/atlas.en-us.platform_events.meta/platform_events/ |
| Salesforce CLI (sf) Command Reference | https://developer.salesforce.com/docs/atlas.en-us.sfdx_cli_reference.meta/sfdx_cli_reference/ |
| Metadata API Developer Guide | https://developer.salesforce.com/docs/atlas.en-us.api_meta.meta/api_meta/ |

---

*Global AI Development Guidelines -- Master skill file | Reusable Salesforce Agent Guidelines | the release owner | Salesforce Developer*
*Last verified 2026-05-16*
*Attach to every AI agent session that touches Salesforce metadata, code, or configuration. Read CLAUDE.md alongside.*

