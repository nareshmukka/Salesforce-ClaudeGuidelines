# Apex Development Guidelines

**Version**: 2.0 (April 2026)
**Developer**: Naresh | Senior Salesforce Developer
**Purpose**: Standalone guidelines for AI-assisted Apex development. Attach this file when writing, reviewing, or refactoring any Apex class, interface, or test.

---

## Table of Contents

1. [Required Agent Output Contract](#1-required-agent-output-contract)
2. [Apex Class Design](#2-apex-class-design)
3. [with sharing / without sharing / inherited sharing](#3-with-sharing--without-sharing--inherited-sharing)
4. [User Mode vs System Mode (SOQL/DML)](#4-user-mode-vs-system-mode-soqldml)
5. [SOQL Security](#5-soql-security)
6. [DML Security](#6-dml-security)
7. [Security.stripInaccessible](#7-securitystripinaccessible)
8. [Service / Domain / Selector Pattern](#8-service--domain--selector-pattern)
9. [Invocable Apex](#9-invocable-apex)
10. [Queueable, Batch, Schedulable](#10-queueable-batch-schedulable)
11. [Callouts with Named Credentials](#11-callouts-with-named-credentials)
12. [Exception Handling](#12-exception-handling)
13. [Logging](#13-logging)
14. [Test Classes](#14-test-classes)
15. [Complete Working Examples](#15-complete-working-examples)
16. [Common AI Mistakes to Avoid](#16-common-ai-mistakes-to-avoid)
17. [Definition of Done](#17-definition-of-done)
18. [Validation Commands](#18-validation-commands)
19. [Official References](#19-official-references)

---

## 1. Required Agent Output Contract

Every Apex implementation response MUST include ALL of the following sections before any code is generated. This ensures the developer can review intent, security posture, and rollback strategy before accepting changes.

### 1.1 Plan
- List all impacted classes (new and modified)
- List all interfaces affected
- List all test classes required
- Describe the change in plain language: what triggers it, what it does, what it affects

### 1.2 Files to Create / Modify
Explicit list with file path, action (create / modify), and one-line purpose:
```
force-app/main/default/classes/CaseService.cls          — MODIFY: add handleEscalation method
force-app/main/default/classes/CaseServiceTest.cls      — MODIFY: add test for handleEscalation
force-app/main/default/classes/CaseSelector.cls         — MODIFY: add getEscalatedCases query
```

### 1.3 Security Notes
- Declare sharing keyword chosen and justification
- State which entry points enforce CRUD/FLS (via WITH USER_MODE, Security.stripInaccessible, or manual isCreateable/isUpdateable checks)
- Call out any `without sharing` usage with explicit justification comment
- Note if any fields or objects are accessed that the running user may not have permission to

### 1.4 Test Strategy
- List all scenarios to be covered:
  - Happy path
  - Negative / error path
  - Bulk (200 records)
  - Async (Test.startTest / Test.stopTest)
  - Security (running as restricted user)
  - Mock callout (if applicable)
- State minimum coverage target (≥75% meaningful assertions)

### 1.5 Validation Commands
```bash
sf project deploy start --manifest manifest/package.xml --target-org <alias> --check-only --test-level RunLocalTests --wait 60
sf apex run test --class-names CaseServiceTest --target-org <alias> --result-format human
```

### 1.6 Rollback Notes
- List any data migrations or field changes that cannot be auto-rolled back
- Identify any metadata dependencies (custom fields, objects, permission sets) that must be deployed before this code
- State whether a previous version of the class is preserved and how to restore it

---

## 2. Apex Class Design

### 2.1 Single Responsibility Principle

Each Apex class must have exactly one reason to change. Do not combine query logic, business logic, DML operations, and HTTP callouts in a single class. Split responsibilities across layers.

### 2.2 Layered Architecture

| Layer | Responsibility | Example Class |
|---|---|---|
| Entry Layer | Receives external input (controller, trigger handler, invocable, REST resource) | `CaseController`, `CaseTriggerHandler`, `CaseInvocable` |
| Service Layer | Orchestrates domain + selector + DML; owns transaction boundary | `CaseService` |
| Domain Layer | Business rules, validation, field-level logic; no direct DML | `CaseDomain` |
| Selector Layer | All SOQL queries for one object; no business logic | `CaseSelector` |

Rules:
- No business logic in trigger handlers, controllers, or invocable wrappers directly — delegate immediately to service
- Controllers must be thin: validate input, call service, return result
- Selectors must not call DML
- Domain classes must not query the database themselves (use injected data passed by service)

### 2.3 Class-Level Documentation Header (REQUIRED on every class)

```apex
/**
 * Description: <purpose of this class — one or two sentences>
 * Developer: Naresh
 * Title: Senior Salesforce Developer
 */
```

This header is MANDATORY on every Apex class, interface, enum, and test class. AI agents must include it on every file they create or modify. No exceptions.

### 2.4 Method-Level Documentation

Every `public`, `protected`, and `global` method must include an ApexDoc comment block immediately above the method signature:

```apex
/**
 * Description: <what this method does in one sentence>
 * @param recordList  List of Case records to process
 * @param oldMap      Map of Case Id to old Case values (null for insert contexts)
 * @return            List of updated Case records with escalation fields set
 */
public static List<Case> handleEscalation(List<Case> recordList, Map<Id, Case> oldMap) {
    // implementation
}
```

Private utility methods should have at minimum a single-line comment describing purpose.

### 2.5 Naming Conventions

| Type | Convention | Example |
|---|---|---|
| Class | PascalCase | `CaseService`, `AccountSelector` |
| Method | camelCase | `getOpenCases`, `processEscalation` |
| Variable | camelCase | `caseList`, `accountMap` |
| Constant | UPPER_SNAKE_CASE | `MAX_RETRY_COUNT`, `DEFAULT_TIMEOUT_MS` |
| Test class | `<ClassName>Test` | `CaseServiceTest` |
| Inner class | PascalCase | `Request`, `Response`, `CaseWrapper` |

---

## 3. with sharing / without sharing / inherited sharing

The sharing keyword controls whether Salesforce's record-level sharing model (org-wide defaults, sharing rules, manual shares, role hierarchy) is enforced for the running user when executing SOQL and DML.

### 3.1 Keyword Reference Table

| Keyword | Behavior | When to Use |
|---|---|---|
| `with sharing` | Enforces org sharing rules for the running user. Records outside user's access are invisible in SOQL and blocked in DML. | User-initiated operations: LWC/Aura controllers, entry-layer services called from UI, Invocable methods called from Flow in user context |
| `without sharing` | Ignores sharing rules entirely. Running user sees all records regardless of sharing model. **Does NOT bypass FLS or CRUD.** | Platform automation (batch, scheduled, queueable), system integrations, processes that need access to records the user does not own, integration user contexts |
| `inherited sharing` | Inherits the sharing context of the calling class. If called from a `with sharing` class, sharing is enforced; if called from `without sharing`, it is not. | Utility and helper classes reused in both user and system contexts; Selector classes that serve both contexts |

### 3.2 Rules and Enforcement

- **Default to `with sharing`** for all new classes unless there is a specific documented reason not to.
- **`without sharing` MUST be explicitly justified** with a code comment immediately on the class declaration line:
  ```apex
  // without sharing: batch job requires full record access for reconciliation; no user context available
  public without sharing class AccountReconciliationBatch implements Database.Batchable<SObject> {
  ```
- **Selector and query classes MAY use `inherited sharing`** to be context-neutral and reusable across both user-initiated and system-initiated flows.
- **Never use `without sharing` in LWC Apex controllers** or invocable entry points without adding compensating field-level and object-level access checks (CRUD/FLS) manually.
- If a class is declared without any sharing keyword, it defaults to the sharing context of its caller — this is equivalent to `inherited sharing` but is LESS EXPLICIT. Always declare sharing explicitly.

### 3.3 Quick Decision Flowchart

```
Is this an entry point called directly by a user action (LWC, button, Flow, REST)?
  YES → use with sharing
  NO → Is this a utility/helper class reused in multiple contexts?
    YES → use inherited sharing
    NO → Is this a background/automation class (batch, scheduled, integration)?
      YES → use without sharing (with justification comment)
      NO → default to with sharing
```

---

## 4. User Mode vs System Mode (SOQL/DML)

Sharing keywords control record visibility. User Mode vs System Mode controls **field-level security (FLS) and object-level CRUD** at the query/DML level.

### 4.1 SOQL Access Level Options

**WITH USER_MODE** (recommended for all entry-point queries — Salesforce API 56.0+):
```apex
List<Case> cases = [SELECT Id, Subject, Status FROM Case WHERE OwnerId = :userId WITH USER_MODE];
```
- Enforces FLS: fields the running user cannot read are excluded or an exception is thrown
- Enforces sharing: respects the class's sharing keyword
- Preferred approach for all user-context operations

**WITH SYSTEM_MODE** (explicit system context):
```apex
List<Case> cases = [SELECT Id, Subject FROM Case WITH SYSTEM_MODE];
```
- Bypasses FLS and shares checks
- Use only in explicitly `without sharing` batch/async classes

**WITH SECURITY_ENFORCED** (legacy — being deprecated):
```apex
List<Case> cases = [SELECT Id, Subject FROM Case WITH SECURITY_ENFORCED];
```
- Throws `System.QueryException` if user cannot read a field in the SELECT
- Being deprecated in favor of `WITH USER_MODE` — verify status in target org/release before use
- Do NOT introduce this pattern in new code

**Database.queryWithBinds() with AccessLevel.USER_MODE**:
```apex
Map<String, Object> bindMap = new Map<String, Object>{ 'statusVal' => 'Open' };
List<Case> cases = Database.queryWithBinds(
    'SELECT Id, Subject FROM Case WHERE Status = :statusVal WITH USER_MODE',
    bindMap,
    AccessLevel.USER_MODE
);
```
- Used when query string must be dynamically constructed
- Prevents SOQL injection via bind map (safer than string concatenation)

### 4.2 DML Access Level

```apex
// User Mode DML — enforces CRUD for running user
Database.insert(records, AccessLevel.USER_MODE);
Database.update(records, AccessLevel.USER_MODE);
Database.delete(records, AccessLevel.USER_MODE);

// System Mode DML — bypasses CRUD checks
Database.insert(records, AccessLevel.SYSTEM_MODE);
```

### 4.3 Entry Point Rule

At **every entry point** (controller method, invocable method, REST resource, trigger handler), explicitly choose the access level. Do NOT rely on default system-mode SOQL/DML silently bypassing security. Document your choice.

---

## 5. SOQL Security

### 5.1 Core Rules

1. **Use WITH USER_MODE** for all user-context queries at entry points
2. **Never return more fields than needed** — only SELECT the fields your logic uses
3. **Avoid SELECT \* patterns** — do not use dynamic SOQL to select all fields without FLS validation
4. **Use bind variables** — NEVER concatenate user input into SOQL strings (SOQL injection risk)
5. **Use field sets carefully** — field sets bypass FLS by default; verify behavior in your target org before using in security-sensitive contexts
6. **Enforce LIMIT** — always set a LIMIT on queries that could return large result sets in non-batch contexts
7. **Use Maps for lookups** — collect IDs into a Set, query once, put results in a Map; never query inside a loop

### 5.2 Safe SOQL Example (Bind Variable)

```apex
// CORRECT: bind variable prevents SOQL injection
String searchStatus = 'Open';
List<Case> cases = [
    SELECT Id, Subject, Status, Priority, OwnerId
    FROM Case
    WHERE Status = :searchStatus
    AND AccountId = :accountId
    WITH USER_MODE
    ORDER BY CreatedDate DESC
    LIMIT 200
];

// WRONG: string concatenation — SOQL injection vulnerability
String query = 'SELECT Id FROM Case WHERE Status = \'' + userInput + '\''; // NEVER DO THIS
List<Case> cases = Database.query(query);
```

### 5.3 Bulk-Safe Query Pattern

```apex
// Collect all IDs first
Set<Id> accountIds = new Set<Id>();
for (Case c : caseList) {
    accountIds.add(c.AccountId);
}

// Single query outside the loop
Map<Id, Account> accountMap = new Map<Id, Account>(
    [SELECT Id, Name, Industry FROM Account WHERE Id IN :accountIds WITH USER_MODE]
);

// Now iterate and use the map
for (Case c : caseList) {
    Account acc = accountMap.get(c.AccountId);
    if (acc != null) {
        // process
    }
}
```

---

## 6. DML Security

### 6.1 Manual CRUD Checks

Before performing DML at an entry point, verify the running user has the required object permission:

```apex
/**
 * Description: Inserts cases after verifying user has create permission on Case object.
 * @param cases  List of Case records to insert
 */
public static void createCases(List<Case> cases) {
    if (!Schema.sObjectType.Case.isCreateable()) {
        throw new CaseDomainException('Insufficient permissions to create Case records.');
    }
    insert cases;
}
```

CRUD check methods:
- `Schema.sObjectType.Case.isCreateable()` — can the user create Case records?
- `Schema.sObjectType.Case.isUpdateable()` — can the user update Case records?
- `Schema.sObjectType.Case.isDeletable()` — can the user delete Case records?
- `Schema.sObjectType.Case.isAccessible()` — can the user read Case records?

### 6.2 Field-Level Security Checks

```apex
// Check before setting a field
if (Schema.sObjectType.Case.fields.Priority.isUpdateable()) {
    caseRecord.Priority = 'High';
}
```

### 6.3 Partial Success DML with Failure Logging

```apex
/**
 * Description: Inserts records with partial success; logs any failures via AppLogger.
 * @param records  List of records to insert
 */
public static void insertWithLogging(List<SObject> records) {
    List<Database.SaveResult> results = Database.insert(records, false);
    for (Integer i = 0; i < results.size(); i++) {
        Database.SaveResult sr = results[i];
        if (!sr.isSuccess()) {
            for (Database.Error err : sr.getErrors()) {
                AppLogger.log(
                    'CaseService.insertWithLogging',
                    AppLogger.Severity.ERROR,
                    'DML failure: ' + err.getMessage() + ' | Fields: ' + err.getFields(),
                    null
                );
            }
        }
    }
}
```

---

## 7. Security.stripInaccessible

`Security.stripInaccessible` removes fields from SObject records that the running user does not have access to read or write. This is the recommended bulk-safe approach for FLS enforcement before DML.

### 7.1 When to Use

- Before inserting or updating records that were built from external/user-supplied input
- When you cannot use `WITH USER_MODE` on the originating query (legacy code, dynamic SOQL)
- When records are assembled in memory (not from a query) and need FLS enforcement before DML

### 7.2 AccessType Options

| AccessType | Use Before |
|---|---|
| `AccessType.READABLE` | Returning records to user — strips fields user cannot read |
| `AccessType.CREATABLE` | Inserting new records — strips fields user cannot set on create |
| `AccessType.UPDATABLE` | Updating existing records — strips fields user cannot modify |
| `AccessType.UPSERTABLE` | Upsert operations — strips fields inaccessible for either create or update |

### 7.3 Complete Working Example

```apex
/**
 * Description: Strips inaccessible fields from Case records before upsert, then performs DML.
 * @param cases  List of Case records assembled from external input
 */
public static void upsertCasesSecurely(List<Case> cases) {
    // Strip fields the running user cannot create or update
    SObjectAccessDecision decision = Security.stripInaccessible(
        AccessType.UPSERTABLE,
        cases
    );

    // Cast the cleaned records back to the concrete type
    List<Case> cleanedCases = (List<Case>) decision.getRecords();

    // Optionally log which fields were stripped for audit purposes
    for (String fieldName : decision.getRemovedFields().get('Case')) {
        AppLogger.log(
            'CaseService.upsertCasesSecurely',
            AppLogger.Severity.WARNING,
            'Field stripped by stripInaccessible: ' + fieldName,
            null
        );
    }

    // Perform DML on cleaned records
    Database.upsert(cleanedCases, false);
}
```

### 7.4 Important Notes

- `decision.getRecords()` returns `List<SObject>` — always cast to your concrete type
- `decision.getRemovedFields()` returns `Map<String, Set<String>>` — keyed by SObject API name
- Do NOT call `stripInaccessible` inside a loop — pass the entire list at once
- This does NOT enforce CRUD (object-level create/update permission) — still check `isCreateable()` / `isUpdateable()` separately

---

## 8. Service / Domain / Selector Pattern

### 8.1 Pattern Overview

```
Entry Point (Controller / Trigger Handler / Invocable)
    └── Service Class (orchestration, transaction owner)
            ├── Selector Class (SOQL queries)
            └── Domain Class (business rules, validation)
```

### 8.2 Selector Class

**Rules:**
- All SOQL for one SObject lives here; nothing queries that object elsewhere
- No business logic, no DML
- Use `inherited sharing` to be context-neutral
- Use `WITH USER_MODE` or `WITH SYSTEM_MODE` based on calling context (or accept AccessLevel parameter)
- Return `List<SObject>` or `Map<Id, SObject>` — never return primitives from SOQL

```apex
/**
 * Description: Selector for Case queries — single source of truth for all Case SOQL.
 * Developer: Naresh
 * Title: Senior Salesforce Developer
 */
public inherited sharing class CaseSelector {

    /**
     * Description: Returns open cases for the given account IDs.
     * @param accountIds  Set of Account IDs to query cases for
     * @return            List of Case records with relevant fields
     */
    public List<Case> getOpenCasesByAccountId(Set<Id> accountIds) {
        return [
            SELECT Id, Subject, Status, Priority, OwnerId, AccountId, CreatedDate
            FROM Case
            WHERE AccountId IN :accountIds
            AND Status != 'Closed'
            WITH USER_MODE
            ORDER BY CreatedDate DESC
        ];
    }

    /**
     * Description: Returns cases by ID set with full detail fields.
     * @param caseIds  Set of Case IDs to fetch
     * @return         Map of Case Id to Case record
     */
    public Map<Id, Case> getCasesById(Set<Id> caseIds) {
        return new Map<Id, Case>(
            [SELECT Id, Subject, Status, Priority, OwnerId, AccountId,
                    EscalationReason__c, LastModifiedDate
             FROM Case
             WHERE Id IN :caseIds
             WITH USER_MODE]
        );
    }
}
```

### 8.3 Domain Class

**Rules:**
- Contains all business rules, validation logic, field derivation
- Receives SObject collections passed in by the service — does NOT query
- Does NOT perform DML — returns modified records or throws exceptions
- Stateless static methods are preferred; instantiate only if state is needed

```apex
/**
 * Description: Domain class for Case business rules and field validation.
 * Developer: Naresh
 * Title: Senior Salesforce Developer
 */
public with sharing class CaseDomain {

    /**
     * Description: Sets escalation fields on cases whose priority changed to Critical.
     * @param newCases  New Case records from trigger or service
     * @param oldMap    Map of Case Id to previous values (null for insert)
     */
    public static void applyEscalationRules(List<Case> newCases, Map<Id, Case> oldMap) {
        for (Case c : newCases) {
            Case oldCase = (oldMap != null) ? oldMap.get(c.Id) : null;
            Boolean priorityChangedToCritical =
                c.Priority == 'Critical' &&
                (oldCase == null || oldCase.Priority != 'Critical');

            if (priorityChangedToCritical) {
                c.EscalationReason__c = 'Priority set to Critical';
                c.EscalationDate__c   = Date.today();
            }
        }
    }

    /**
     * Description: Validates that a Case has a Subject before insert.
     * @param cases  List of Cases to validate
     * @throws CaseDomainException if Subject is blank on any record
     */
    public static void validateRequiredFields(List<Case> cases) {
        for (Case c : cases) {
            if (String.isBlank(c.Subject)) {
                c.addError('Subject is required for all new cases.');
            }
        }
    }
}
```

### 8.4 Service Class

**Rules:**
- Owns the transaction boundary: one public method = one logical operation
- Calls Selector to get data, Domain to apply rules, then performs DML
- Handles exceptions and logs failures
- Does not contain SOQL directly — delegates to Selector

```apex
/**
 * Description: Service layer for Case operations — orchestrates domain logic, selectors, and DML.
 * Developer: Naresh
 * Title: Senior Salesforce Developer
 */
public with sharing class CaseService {

    private static final CaseSelector selector = new CaseSelector();

    /**
     * Description: Processes Case records on before insert — validates fields and applies defaults.
     * @param newCases  List of new Case records from trigger
     */
    public static void onBeforeInsert(List<Case> newCases) {
        CaseDomain.validateRequiredFields(newCases);
        CaseDomain.applyEscalationRules(newCases, null);
    }

    /**
     * Description: Processes Case records on before update — detects changes and applies rules.
     * @param newCases  New Case values
     * @param oldMap    Previous Case values keyed by Id
     */
    public static void onBeforeUpdate(List<Case> newCases, Map<Id, Case> oldMap) {
        CaseDomain.applyEscalationRules(newCases, oldMap);
    }

    /**
     * Description: Escalates open cases for a given list of account IDs.
     * @param accountIds  Set of Account IDs whose open cases should be escalated
     */
    public static void escalateOpenCases(Set<Id> accountIds) {
        if (accountIds == null || accountIds.isEmpty()) return;

        List<Case> openCases = selector.getOpenCasesByAccountId(accountIds);
        if (openCases.isEmpty()) return;

        CaseDomain.applyEscalationRules(openCases, null);

        // Strip inaccessible fields before DML
        SObjectAccessDecision decision = Security.stripInaccessible(
            AccessType.UPDATABLE, openCases
        );
        List<Case> cleanedCases = (List<Case>) decision.getRecords();

        List<Database.SaveResult> results = Database.update(cleanedCases, false);
        for (Integer i = 0; i < results.size(); i++) {
            if (!results[i].isSuccess()) {
                AppLogger.log(
                    'CaseService.escalateOpenCases',
                    AppLogger.Severity.ERROR,
                    'Update failed for Case: ' + cleanedCases[i].Id + ' | ' +
                        results[i].getErrors()[0].getMessage(),
                    cleanedCases[i].Id
                );
            }
        }
    }
}
```

---

## 9. Invocable Apex

### 9.1 Rules

- Must use `@InvocableMethod` annotation with `label` and `description` attributes
- Input and output MUST use inner classes annotated with `@InvocableVariable`
- MUST accept `List<Request>` and return `List<Response>` — this is required for Flow bulkification
- Enforce CRUD/FLS within the invocable — do NOT assume Flow enforces security (it does not for all contexts)
- Never let exceptions propagate uncaught back to Flow — catch and return error status in the response
- Do not perform business logic directly; delegate to the service layer

### 9.2 Complete Working Example

```apex
/**
 * Description: Invocable Apex for escalating open cases from a Flow.
 *              Delegates to CaseService; handles errors gracefully to prevent Flow failures.
 * Developer: Naresh
 * Title: Senior Salesforce Developer
 */
public with sharing class EscalateCasesInvocable {

    /**
     * Description: Flow-callable method to escalate open cases for given Account IDs.
     * @param requests  List of Request wrappers (required for bulkification)
     * @return          List of Response wrappers with success/error status
     */
    @InvocableMethod(
        label='Escalate Open Cases'
        description='Escalates all open cases for the provided Account IDs. Returns success or error message per request.'
        category='Case Management'
    )
    public static List<Response> escalateCases(List<Request> requests) {
        List<Response> responses = new List<Response>();

        // Collect all account IDs across all requests (bulk-safe)
        Set<Id> allAccountIds = new Set<Id>();
        for (Request req : requests) {
            if (req.accountId != null) {
                allAccountIds.add(req.accountId);
            }
        }

        try {
            CaseService.escalateOpenCases(allAccountIds);
            for (Request req : requests) {
                Response res = new Response();
                res.isSuccess = true;
                res.errorMessage = null;
                responses.add(res);
            }
        } catch (Exception ex) {
            AppLogger.log(
                'EscalateCasesInvocable.escalateCases',
                AppLogger.Severity.ERROR,
                ex.getMessage(),
                null
            );
            for (Request req : requests) {
                Response res = new Response();
                res.isSuccess = false;
                res.errorMessage = ex.getMessage();
                responses.add(res);
            }
        }

        return responses;
    }

    /**
     * Description: Input wrapper for escalate cases invocable.
     */
    public class Request {
        @InvocableVariable(label='Account ID' description='ID of the Account whose cases should be escalated' required=true)
        public Id accountId;
    }

    /**
     * Description: Output wrapper for escalate cases invocable.
     */
    public class Response {
        @InvocableVariable(label='Is Success' description='True if escalation succeeded; false if an error occurred')
        public Boolean isSuccess;

        @InvocableVariable(label='Error Message' description='Error details if isSuccess is false')
        public String errorMessage;
    }
}
```

---

## 10. Queueable, Batch, Schedulable

### 10.1 Queueable Apex

Use Queueable for async operations that need to be chained or when you need to make callouts from a trigger context.

**Rules:**
- Implement `Queueable` interface (add `Database.AllowsCallouts` if making HTTP callouts)
- Pass a correlation ID (job context identifier) in the constructor for log traceability
- Keep execute() focused — do not jam multiple unrelated operations into one Queueable
- Chain jobs carefully — avoid unbounded recursion in chained Queueables

```apex
/**
 * Description: Async job that sends case escalation notifications via external API.
 * Developer: Naresh
 * Title: Senior Salesforce Developer
 */
public class CaseEscalationNotificationJob implements Queueable, Database.AllowsCallouts {

    private final List<Id>  caseIds;
    private final String    correlationId;

    /**
     * Description: Constructor for job initialization.
     * @param caseIds        IDs of cases to notify about
     * @param correlationId  Unique identifier for log correlation (e.g. trigger transaction ID)
     */
    public CaseEscalationNotificationJob(List<Id> caseIds, String correlationId) {
        this.caseIds       = caseIds;
        this.correlationId = correlationId;
    }

    /**
     * Description: Async execute — processes case notifications and calls external API.
     * @param ctx  Queueable context provided by the platform
     */
    public void execute(QueueableContext ctx) {
        AppLogger.log(
            'CaseEscalationNotificationJob.execute',
            AppLogger.Severity.INFO,
            'Job started. CorrelationId: ' + correlationId + ' | Cases: ' + caseIds.size(),
            null
        );
        try {
            CaseService.sendEscalationNotifications(caseIds);
        } catch (Exception ex) {
            AppLogger.log(
                'CaseEscalationNotificationJob.execute',
                AppLogger.Severity.ERROR,
                'Job failed. CorrelationId: ' + correlationId + ' | ' + ex.getMessage(),
                null
            );
        }
    }
}
```

Enqueue from a trigger or service:
```apex
String corrId = UserInfo.getUserId() + '_' + System.now().getTime();
System.enqueueJob(new CaseEscalationNotificationJob(caseIds, corrId));
```

### 10.2 Batch Apex

Use Batch for processing > 50,000 records or for operations that exceed governor limits for a single transaction.

**Rules:**
- Implement `Database.Batchable<SObject>`
- Keep `execute()` bulk-safe — no SOQL inside loops
- Use `Database.executeBatch(job, 200)` — tune batch size based on workload (callouts require batch size = 1 per-callout Queueable workaround)
- Implement `Database.Stateful` only when you need to accumulate state across batches (increases heap usage — use sparingly)

```apex
/**
 * Description: Batch job to archive closed cases older than 1 year.
 * Developer: Naresh
 * Title: Senior Salesforce Developer
 */
// without sharing: batch runs as system user; no user context; justified for full org access
public without sharing class ClosedCaseArchiveBatch implements Database.Batchable<SObject> {

    /**
     * Description: Defines the scope — selects all closed cases older than 1 year.
     * @param ctx  Batch context
     * @return     QueryLocator for the batch
     */
    public Database.QueryLocator start(Database.BatchableContext ctx) {
        Date cutoffDate = Date.today().addYears(-1);
        return Database.getQueryLocator(
            'SELECT Id, Subject, Status, CreatedDate FROM Case ' +
            'WHERE Status = \'Closed\' AND CreatedDate < :cutoffDate'
        );
    }

    /**
     * Description: Processes each batch of closed cases for archival.
     * @param ctx     Batch context
     * @param scope   Current batch of Case records
     */
    public void execute(Database.BatchableContext ctx, List<Case> scope) {
        CaseService.archiveCases(scope);
    }

    /**
     * Description: Post-processing after all batches complete.
     * @param ctx  Batch context
     */
    public void finish(Database.BatchableContext ctx) {
        AppLogger.log(
            'ClosedCaseArchiveBatch.finish',
            AppLogger.Severity.INFO,
            'Batch job completed. JobId: ' + ctx.getJobId(),
            null
        );
    }
}
```

### 10.3 Schedulable Apex

Delegate all heavy logic to a Batch or Queueable. The `execute()` method of a Schedulable should contain only the job dispatch call.

```apex
/**
 * Description: Scheduler that fires the ClosedCaseArchiveBatch on a nightly schedule.
 * Developer: Naresh
 * Title: Senior Salesforce Developer
 */
public class ClosedCaseArchiveScheduler implements Schedulable {

    /**
     * Description: Scheduled entry point — delegates all processing to batch job.
     * @param ctx  Schedulable context
     */
    public void execute(SchedulableContext ctx) {
        Database.executeBatch(new ClosedCaseArchiveBatch(), 200);
    }
}
```

Schedule via Apex:
```apex
// Runs daily at 2:00 AM
String cronExp = '0 0 2 * * ?';
System.schedule('Nightly Case Archive', cronExp, new ClosedCaseArchiveScheduler());
```

---

## 11. Callouts with Named Credentials

### 11.1 Rules

- **ALWAYS use Named Credentials** for all HTTP callouts: `'callout:MyNamedCred/endpoint/path'`
- **Never hardcode** URLs, API keys, tokens, usernames, or passwords in Apex code
- **Never hardcode** in Custom Metadata Type or Custom Settings without proper access controls
- Use **External Credentials** for OAuth 2.0 per-user authentication flows (available in API 57.0+ — verify in target org)
- Always set a **timeout**: `req.setTimeout(30000)` — default timeout is 10 seconds; maximum is 120 seconds
- Parse responses **defensively** — check status code before deserializing
- Wrap callout logic in try/catch and log failures before re-throwing

### 11.2 Complete HTTP Client Class Example

```apex
/**
 * Description: HTTP client for the external case notification API.
 *              Uses Named Credentials for authentication; never stores credentials in code.
 * Developer: Naresh
 * Title: Senior Salesforce Developer
 */
public with sharing class CaseNotificationClient {

    private static final String NAMED_CRED   = 'callout:CaseNotificationAPI';
    private static final Integer TIMEOUT_MS  = 30000;
    private static final String CONTENT_TYPE = 'application/json';

    /**
     * Description: Posts an escalation event to the external notification service.
     * @param caseId   Salesforce Case ID being escalated
     * @param reason   Plain text escalation reason
     * @return         True if the API accepted the notification; false otherwise
     */
    public static Boolean sendEscalationNotification(Id caseId, String reason) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(NAMED_CRED + '/v1/escalations');
        req.setMethod('POST');
        req.setHeader('Content-Type', CONTENT_TYPE);
        req.setHeader('Accept', CONTENT_TYPE);
        req.setTimeout(TIMEOUT_MS);

        // Build request body — never concatenate user input directly into JSON strings
        Map<String, Object> body = new Map<String, Object>{
            'caseId' => String.valueOf(caseId),
            'reason' => reason,
            'timestamp' => System.now().formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'')
        };
        req.setBody(JSON.serialize(body));

        HttpResponse res;
        try {
            res = new Http().send(req);
        } catch (CalloutException ex) {
            AppLogger.log(
                'CaseNotificationClient.sendEscalationNotification',
                AppLogger.Severity.ERROR,
                'Callout failed: ' + ex.getMessage(),
                caseId
            );
            return false;
        }

        if (res.getStatusCode() == 200 || res.getStatusCode() == 201) {
            return true;
        }

        AppLogger.log(
            'CaseNotificationClient.sendEscalationNotification',
            AppLogger.Severity.ERROR,
            'API returned non-success: HTTP ' + res.getStatusCode() + ' | ' + res.getBody(),
            caseId
        );
        return false;
    }
}
```

---

## 12. Exception Handling

### 12.1 Custom Exception Classes

Define domain-specific exceptions for every service domain. This makes error handling explicit and avoids catching broad `Exception` types unintentionally.

```apex
/**
 * Description: Custom exception for Case domain business rule violations.
 * Developer: Naresh
 * Title: Senior Salesforce Developer
 */
public class CaseDomainException extends Exception {}

/**
 * Description: Custom exception for Case selector / data access failures.
 * Developer: Naresh
 * Title: Senior Salesforce Developer
 */
public class CaseSelectorException extends Exception {}
```

### 12.2 Rules

- **Catch specific exception types** — avoid bare `catch(Exception e)` unless you are a top-level handler that must catch everything
- **Never swallow exceptions silently** — always log before returning or re-throwing
- **Use custom exceptions** to communicate business rule failures; use `System.DmlException` / `System.QueryException` for data layer errors
- **Use finally** for cleanup (resetting static flags, closing resources)
- **Re-throw with context** when escalating to a higher layer

### 12.3 Exception Handling Pattern

```apex
/**
 * Description: Creates cases with full exception handling and logging.
 * @param cases  List of Case records to create
 * @throws CaseDomainException  if CRUD check fails
 */
public static void createCasesWithHandling(List<Case> cases) {
    if (!Schema.sObjectType.Case.isCreateable()) {
        throw new CaseDomainException('Running user lacks Create permission on Case.');
    }

    List<Database.SaveResult> results;
    try {
        results = Database.insert(cases, false);
    } catch (DmlException ex) {
        AppLogger.log(
            'CaseService.createCasesWithHandling',
            AppLogger.Severity.ERROR,
            'DML exception during insert: ' + ex.getMessage(),
            null
        );
        throw new CaseDomainException('Case creation failed: ' + ex.getMessage(), ex);
    } finally {
        // Reset any static state flags here if applicable
    }

    // Log partial failures without throwing
    for (Integer i = 0; i < results.size(); i++) {
        if (!results[i].isSuccess()) {
            String errorDetail = results[i].getErrors()[0].getMessage();
            AppLogger.log(
                'CaseService.createCasesWithHandling',
                AppLogger.Severity.WARNING,
                'Partial insert failure on record index ' + i + ': ' + errorDetail,
                null
            );
        }
    }
}
```

---

## 13. Logging

### 13.1 Rules

- Use a **centralized logging class** (`AppLogger`) — never use `System.debug()` as the sole logging mechanism in production code
- Log parameters: class.method context, severity level, message, related record ID
- Insert log records with `Database.insert(log, false)` — never let logging failures break business logic
- **Never log PII** (names, email addresses, phone numbers, SSNs) or sensitive field values (passwords, tokens)
- Log at the appropriate severity: INFO for normal milestones, WARNING for non-fatal issues, ERROR for failures

### 13.2 AppLogger Class

```apex
/**
 * Description: Centralized logging utility — writes App_Log__c records for audit and debugging.
 *              Uses Database.insert with false to ensure logging never blocks business logic.
 * Developer: Naresh
 * Title: Senior Salesforce Developer
 */
public without sharing class AppLogger {
    // without sharing: logging must succeed regardless of running user's record access

    public enum Severity { INFO, WARNING, ERROR }

    /**
     * Description: Writes a single log entry to the App_Log__c custom object.
     * @param context    Class and method name (e.g. 'CaseService.escalateOpenCases')
     * @param severity   Severity level (INFO, WARNING, ERROR)
     * @param message    Log message — do NOT include PII or secret values
     * @param recordId   Related Salesforce record ID (optional, may be null)
     */
    public static void log(String context, Severity severity, String message, Id recordId) {
        try {
            App_Log__c logEntry = new App_Log__c(
                Context__c   = context,
                Severity__c  = severity.name(),
                Message__c   = message != null ? message.abbreviate(32000) : '',
                Record_Id__c = recordId != null ? String.valueOf(recordId) : null,
                Timestamp__c = System.now()
            );
            Database.insert(logEntry, false);
        } catch (Exception ex) {
            // Last resort: surface to debug log only — do not propagate
            System.debug(LoggingLevel.ERROR,
                'AppLogger.log failed: ' + ex.getMessage() +
                ' | Original context: ' + context + ' | ' + message
            );
        }
    }
}
```

---

## 14. Test Classes

### 14.1 Core Rules

- Every Apex class must have a corresponding test class suffixed with `Test`
- `@isTest` annotation is REQUIRED on every test class
- `@TestSetup` is REQUIRED for any shared test data (avoids repetition and improves performance)
- **Never use `SeeAllData=true`** unless dealing with legacy integration that cannot be rewritten — if used, document why with a code comment
- Use **test data factories** (a dedicated `TestDataFactory` class) — never build test data inline in every test method
- Follow the **AAA pattern**: Arrange → Act → Assert
- **Assert specific values** — not just "no exception thrown"; use `System.assertEquals(expected, actual, 'Failure message')`

### 14.2 Required Test Scenarios

Every service/domain class test must cover:

| Scenario | What to Verify |
|---|---|
| Happy path | Expected output for valid input |
| Negative / error path | Custom exception thrown for invalid input |
| Bulk (200 records) | Logic handles 200 records without governor limit errors |
| Async | Queueable/Batch behavior tested with `Test.startTest()` / `Test.stopTest()` |
| Security | Running as a restricted user (via `System.runAs`) fails gracefully |
| Mock callout | `HttpCalloutMock` used; no real callouts in test context |

### 14.3 Test Data Factory Pattern

```apex
/**
 * Description: Factory for creating test data records consistently across all test classes.
 * Developer: Naresh
 * Title: Senior Salesforce Developer
 */
@isTest
public class TestDataFactory {

    /**
     * Description: Creates and inserts a list of Account records for testing.
     * @param count  Number of accounts to create
     * @return       List of inserted Account records
     */
    public static List<Account> createAccounts(Integer count) {
        List<Account> accounts = new List<Account>();
        for (Integer i = 0; i < count; i++) {
            accounts.add(new Account(Name = 'Test Account ' + i, Industry = 'Technology'));
        }
        insert accounts;
        return accounts;
    }

    /**
     * Description: Creates and inserts Case records for the given account.
     * @param accountId  Parent Account ID
     * @param count      Number of cases to create
     * @param status     Status value for all cases
     * @return           List of inserted Case records
     */
    public static List<Case> createCases(Id accountId, Integer count, String status) {
        List<Case> cases = new List<Case>();
        for (Integer i = 0; i < count; i++) {
            cases.add(new Case(
                Subject   = 'Test Case ' + i,
                Status    = status,
                Priority  = 'Medium',
                AccountId = accountId
            ));
        }
        insert cases;
        return cases;
    }
}
```

### 14.4 Mock Callout Pattern

```apex
/**
 * Description: Mock HTTP response for CaseNotificationClient unit tests.
 * Developer: Naresh
 * Title: Senior Salesforce Developer
 */
@isTest
public class CaseNotificationClientMock implements HttpCalloutMock {

    private final Integer statusCode;
    private final String  body;

    public CaseNotificationClientMock(Integer statusCode, String body) {
        this.statusCode = statusCode;
        this.body       = body;
    }

    public HTTPResponse respond(HTTPRequest req) {
        HttpResponse res = new HttpResponse();
        res.setStatusCode(statusCode);
        res.setBody(body);
        return res;
    }
}
```

---

## 15. Complete Working Examples

### 15.1 Full Service Class: CaseService

```apex
/**
 * Description: Service layer for Case operations — orchestrates domain, selector, and DML.
 *              Owns transaction boundaries; delegates queries to CaseSelector and rules to CaseDomain.
 * Developer: Naresh
 * Title: Senior Salesforce Developer
 */
public with sharing class CaseService {

    private static final CaseSelector selector = new CaseSelector();

    /**
     * Description: Entry point for before insert trigger context.
     * @param newCases  Newly inserted Case records from trigger
     */
    public static void onBeforeInsert(List<Case> newCases) {
        CaseDomain.validateRequiredFields(newCases);
        CaseDomain.applyEscalationRules(newCases, null);
    }

    /**
     * Description: Entry point for before update trigger context.
     * @param newCases  Updated Case records
     * @param oldMap    Previous values for changed records
     */
    public static void onBeforeUpdate(List<Case> newCases, Map<Id, Case> oldMap) {
        CaseDomain.applyEscalationRules(newCases, oldMap);
    }

    /**
     * Description: Escalates open cases for provided account IDs; updates records and logs failures.
     * @param accountIds  Set of Account IDs whose open cases should be escalated
     */
    public static void escalateOpenCases(Set<Id> accountIds) {
        if (accountIds == null || accountIds.isEmpty()) return;

        List<Case> openCases = selector.getOpenCasesByAccountId(accountIds);
        if (openCases.isEmpty()) return;

        CaseDomain.applyEscalationRules(openCases, null);

        SObjectAccessDecision decision = Security.stripInaccessible(AccessType.UPDATABLE, openCases);
        List<Case> cleanedCases = (List<Case>) decision.getRecords();

        List<Database.SaveResult> results = Database.update(cleanedCases, false);
        for (Integer i = 0; i < results.size(); i++) {
            if (!results[i].isSuccess()) {
                AppLogger.log(
                    'CaseService.escalateOpenCases',
                    AppLogger.Severity.ERROR,
                    'Update failed: ' + results[i].getErrors()[0].getMessage(),
                    cleanedCases[i].Id
                );
            }
        }
    }
}
```

### 15.2 Full Selector Class: CaseSelector

```apex
/**
 * Description: Selector for all Case SOQL — single source of truth for Case queries.
 *              Uses inherited sharing to be context-neutral; callers control sharing enforcement.
 * Developer: Naresh
 * Title: Senior Salesforce Developer
 */
public inherited sharing class CaseSelector {

    /**
     * Description: Returns open cases associated with the given account IDs.
     * @param accountIds  Set of Account IDs to query
     * @return            List of Case records
     */
    public List<Case> getOpenCasesByAccountId(Set<Id> accountIds) {
        return [
            SELECT Id, Subject, Status, Priority, OwnerId, AccountId,
                   EscalationReason__c, EscalationDate__c
            FROM Case
            WHERE AccountId IN :accountIds
            AND Status != 'Closed'
            WITH USER_MODE
            ORDER BY CreatedDate DESC
        ];
    }

    /**
     * Description: Returns a map of Case records by their IDs.
     * @param caseIds  Set of Case IDs to fetch
     * @return         Map of Case Id to Case record
     */
    public Map<Id, Case> getCasesById(Set<Id> caseIds) {
        return new Map<Id, Case>(
            [SELECT Id, Subject, Status, Priority, OwnerId, AccountId,
                    EscalationReason__c, EscalationDate__c, LastModifiedDate
             FROM Case
             WHERE Id IN :caseIds
             WITH USER_MODE]
        );
    }
}
```

### 15.3 Full Test Class: CaseServiceTest

```apex
/**
 * Description: Test class for CaseService — covers happy path, negative, bulk, async, and mock callout.
 * Developer: Naresh
 * Title: Senior Salesforce Developer
 */
@isTest
private class CaseServiceTest {

    @TestSetup
    static void setupData() {
        List<Account> accounts = TestDataFactory.createAccounts(1);
        TestDataFactory.createCases(accounts[0].Id, 5, 'New');
    }

    // ─── Happy Path ──────────────────────────────────────────────

    @isTest
    static void testEscalateOpenCases_happyPath() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Set<Id> accountIds = new Set<Id>{ acc.Id };

        Test.startTest();
        CaseService.escalateOpenCases(accountIds);
        Test.stopTest();

        List<Case> updatedCases = [SELECT Id, EscalationReason__c FROM Case WHERE AccountId = :acc.Id];
        System.assertEquals(5, updatedCases.size(), 'Expected 5 cases to be returned');
        for (Case c : updatedCases) {
            // Validate escalation was not incorrectly applied (priority was Medium, not Critical)
            System.assertEquals(null, c.EscalationReason__c,
                'EscalationReason should be null for non-Critical cases');
        }
    }

    // ─── Negative Path ───────────────────────────────────────────

    @isTest
    static void testEscalateOpenCases_emptyInput() {
        Test.startTest();
        // Should not throw for empty input
        CaseService.escalateOpenCases(new Set<Id>());
        CaseService.escalateOpenCases(null);
        Test.stopTest();
        System.assert(true, 'No exception expected for empty/null input');
    }

    // ─── Bulk (200 records) ───────────────────────────────────────

    @isTest
    static void testEscalateOpenCases_bulk200Records() {
        List<Account> bulkAccounts = TestDataFactory.createAccounts(1);
        Account bulkAccount = bulkAccounts[0];
        TestDataFactory.createCases(bulkAccount.Id, 200, 'New');

        Set<Id> accountIds = new Set<Id>{ bulkAccount.Id };

        Test.startTest();
        CaseService.escalateOpenCases(accountIds);
        Test.stopTest();

        List<Case> result = [SELECT Id FROM Case WHERE AccountId = :bulkAccount.Id];
        System.assertEquals(200, result.size(), 'Expected 200 cases to be processed');
    }

    // ─── Validation ───────────────────────────────────────────────

    @isTest
    static void testValidateRequiredFields_blankSubject() {
        List<Case> cases = new List<Case>{
            new Case(Status = 'New', Priority = 'Medium') // Subject intentionally missing
        };
        Boolean exceptionThrown = false;
        try {
            insert cases; // Trigger calls CaseDomain.validateRequiredFields via CaseService
        } catch (DmlException ex) {
            exceptionThrown = true;
            System.assert(ex.getMessage().contains('Subject'),
                'Exception should reference the Subject field');
        }
        System.assert(exceptionThrown, 'Expected DmlException for missing Subject');
    }

    // ─── Mock Callout ─────────────────────────────────────────────

    @isTest
    static void testSendEscalationNotification_successResponse() {
        Test.setMock(HttpCalloutMock.class,
            new CaseNotificationClientMock(200, '{"status":"accepted"}'));

        Test.startTest();
        Boolean result = CaseNotificationClient.sendEscalationNotification(
            [SELECT Id FROM Case LIMIT 1].Id,
            'Test escalation'
        );
        Test.stopTest();

        System.assertEquals(true, result, 'Expected true for HTTP 200 response');
    }

    @isTest
    static void testSendEscalationNotification_failureResponse() {
        Test.setMock(HttpCalloutMock.class,
            new CaseNotificationClientMock(500, '{"error":"internal server error"}'));

        Test.startTest();
        Boolean result = CaseNotificationClient.sendEscalationNotification(
            [SELECT Id FROM Case LIMIT 1].Id,
            'Test escalation'
        );
        Test.stopTest();

        System.assertEquals(false, result, 'Expected false for HTTP 500 response');
    }
}
```

---

## 16. Common AI Mistakes to Avoid

The following patterns are frequently generated by AI tools and MUST be caught in code review. If you see any of these in AI-generated output, reject and request a fix.

| # | Mistake | Correct Approach |
|---|---|---|
| 1 | Placing business logic directly in trigger handler (if/else logic, field updates, SOQL in handler) | Delegate all logic to the service layer; handler only routes by context |
| 2 | Using `without sharing` without justification comment | Every `without sharing` class must have a one-line justification comment |
| 3 | Missing CRUD/FLS checks in controllers, invocables, REST resources | Enforce at every entry point using `WITH USER_MODE`, `stripInaccessible`, or manual `isCreateable()` checks |
| 4 | SOQL inside a for loop | Collect IDs, query once outside the loop, use Map for lookup |
| 5 | DML inside a for loop | Collect records into a list, DML once outside the loop |
| 6 | `@InvocableMethod` accepting a single `Request` instead of `List<Request>` | Always `List<Request>` input and `List<Response>` return for bulkification |
| 7 | `SeeAllData=true` in test class | Use `@TestSetup` with explicitly created test data |
| 8 | Hardcoded IDs in Apex (e.g. `Id myId = '001ABC123...'`) | Use SOQL or relationships to fetch IDs dynamically |
| 9 | Hardcoded URLs or API keys in Apex or Custom Settings | Use Named Credentials for all endpoints; External Credentials for auth tokens |
| 10 | Empty catch blocks: `catch(Exception e) {}` | Always log the exception; never silently swallow errors |
| 11 | No developer documentation header on class | Every class must have the 3-line developer header block |
| 12 | No test for 200-record bulk scenario | Every service/domain test class must include a 200-record test |
| 13 | Business logic in test `@TestSetup` | `@TestSetup` is for data only; no assertions or complex logic |
| 14 | Asserting only "no exception thrown" | Assert specific field values, record counts, and state changes |
| 15 | Missing `req.setTimeout()` in HTTP callouts | Always set explicit timeout to avoid long-running callout failures |
| 16 | `insert list` / `update list` (allOrNone=true) in bulk automation | A single bad record fails the entire transaction; in platform automation partial success is usually correct | Use `Database.insert(list, false)` / `Database.update(list, false)` and log each `SaveResult` error via `System.debug(LoggingLevel.ERROR, ...)` |
| 17 | Creating a service class that is a 1-line wrapper delegating to an existing `@AuraEnabled` controller method | The service must own the business logic; LWC `@AuraEnabled` methods stay in the controller but trigger handler logic moves to the service class — mixing UI controller and trigger handler concerns in one class violates SRP |
| 18 | `without sharing` justification comment placed in the ApexDoc header block only | The justification comment must appear on the line immediately before the class declaration: `// without sharing: <reason>` followed by `public without sharing class Foo {}` — not buried in the doc block |
| 19 | Using `System.debug(LoggingLevel.ERROR, ...)` as the sole error logging mechanism in production service code | Use `AppLogger.log(context, AppLogger.Severity.ERROR, message, recordId)` for all error paths in service classes; reserve `System.debug` for development-time tracing only |

---

## 17. Definition of Done

Before marking any Apex task complete, verify every item on this checklist:

- [ ] Developer header (`Description`, `Developer: Naresh`, `Title: Senior Salesforce Developer`) on ALL new and modified classes
- [ ] `with sharing`, `without sharing`, or `inherited sharing` explicitly declared on every class (no implicit sharing)
- [ ] `without sharing` usage has a justification comment
- [ ] CRUD/FLS enforced at all entry points (controller methods, invocable methods, REST resources)
- [ ] No SOQL inside for loops anywhere in the class or its dependencies
- [ ] No DML inside for loops anywhere in the class or its dependencies
- [ ] Invocable methods accept `List<Request>` and return `List<Response>`
- [ ] All HTTP callouts use Named Credentials (`callout:<CredentialName>/path`)
- [ ] Custom exception classes defined for the domain (`extends Exception`)
- [ ] `AppLogger.log()` calls present for all error and significant info paths
- [ ] Test class includes: `@TestSetup`, `@isTest`, AAA pattern, 200-record bulk test, negative test, async test with `startTest/stopTest`, mock callout test (if applicable)
- [ ] Test coverage is ≥ 75% with meaningful field-value assertions (not just "no exception")
- [ ] Check-only deployment passes with `RunLocalTests`: `sf project deploy start --check-only --test-level RunLocalTests`

---

## 18. Validation Commands

```bash
# Full check-only deployment with all local tests
sf project deploy start \
  --manifest manifest/package.xml \
  --target-org <alias> \
  --check-only \
  --test-level RunLocalTests \
  --wait 60

# Run specific test class and display human-readable results
sf apex run test \
  --class-names CaseServiceTest \
  --target-org <alias> \
  --result-format human \
  --wait 10

# Run multiple test classes
sf apex run test \
  --class-names CaseServiceTest,CaseSelectorTest,CaseDomainTest \
  --target-org <alias> \
  --result-format human

# Retrieve current version of a class before modifying
sf project retrieve start \
  --metadata "ApexClass:CaseService" \
  --target-org <alias>

# Check code coverage for a specific class
sf apex get test \
  --test-run-id <jobId> \
  --target-org <alias> \
  --result-format human
```

---

## 19. Official References

- Apex Developer Guide: https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/
- Apex Security and Sharing: https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_security_sharing_understand.htm
- Security.stripInaccessible: https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_classes_with_security_stripInaccessible.htm
- Sharing Keywords (with/without/inherited): https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_bulk_sharing_creating_with_keywords.htm
- Apex Testing: https://trailhead.salesforce.com/content/learn/modules/apex_testing
- Invocable Apex: https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_classes_annotation_InvocableMethod.htm
- Batch Apex: https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_batch_interface.htm
- Named Credentials: https://help.salesforce.com/s/articleView?id=sf.named_credentials_about.htm
- Apex Governor Limits: https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_gov_limits.htm
- WITH USER_MODE / WITH SYSTEM_MODE: https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_classes_enforce_usermode.htm
