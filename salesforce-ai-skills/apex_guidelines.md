# Apex Development Guidelines

Canonical authoring contract for production Apex in this project — classes, triggers, async jobs, invocables, REST resources, and tests.

**Verified against:** [Apex Developer Guide](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/) · [Apex Security & Sharing](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_security_sharing_understand.htm) · [Sharing keywords](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_bulk_sharing_creating_with_keywords.htm) · [WITH USER_MODE / SYSTEM_MODE](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_classes_enforce_usermode.htm) · [Security.stripInaccessible](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_classes_with_security_stripInaccessible.htm) · [Invocable Apex](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_classes_annotation_InvocableMethod.htm) · [Batch Apex](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_batch_interface.htm) · [Queueable](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_queueing_jobs.htm) · [Named Credentials](https://help.salesforce.com/s/articleView?id=sf.named_credentials_about.htm) · [Governor Limits](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_gov_limits.htm) · [forcedotcom/sf-skills `generating-apex`](https://github.com/forcedotcom/sf-skills/tree/main/skills/generating-apex) · [forcedotcom/sf-skills `generating-apex-test`](https://github.com/forcedotcom/sf-skills/tree/main/skills/generating-apex-test). Last verified 2026-05-16.

**Project defaults:** API `66.0` · Author `Naresh` · Title `Senior Salesforce Developer` · Org `PlusGradeFullSB` · Manifest `manifest/package-case-flow-optimization.xml` · Test classes deferred per project policy (do NOT generate tests inline unless the task is itself a test task).

---

## 1. Output Contract

Every Apex implementation response must include — before any code — a tight version of these:

| Section | Content |
|---|---|
| Plan | Impacted classes (new/modified), interfaces, test classes, one-line behaviour description |
| Files | `path — CREATE/MODIFY — purpose` lines |
| Security | Sharing keyword chosen; entry-point CRUD/FLS strategy; justification for any `without sharing` |
| Test strategy | Scenarios: happy / negative / bulk (200+) / async / security / mock callout. Min ≥75% with meaningful asserts |
| Validation | The check-only `sf project deploy start` command and any targeted `sf apex run test` |
| Rollback | Metadata dependencies; whether prior version is preserved |

Skip the test-strategy section only if the project's "tests deferred" rule applies to this task and you say so explicitly.

---

## 2. Class Header & ApexDoc

Every class, interface, enum, and trigger handler MUST carry this header verbatim:

```apex
/**
 * Description: <one or two sentences — what this class does and why it exists>
 * Developer: Naresh
 * Title: Senior Salesforce Developer
 */
```

Every `public` / `protected` / `global` method MUST have an ApexDoc block:

```apex
/**
 * Description: Escalates open cases for the given account IDs.
 * @param accountIds  Set of Account IDs whose open cases should be escalated
 * @return            Number of cases successfully escalated
 * @throws CaseDomainException  if the running user lacks Update permission
 */
public static Integer escalateOpenCases(Set<Id> accountIds) { ... }
```

Private helpers: at least a one-line comment naming purpose.

---

## 3. Naming

| Type | Pattern | Example |
|---|---|---|
| Service | `{SObject}Service` | `CaseService` |
| Selector | `{SObject}Selector` | `CaseSelector` |
| Domain | `{SObject}Domain` | `CaseDomain` |
| Batch | `{Descriptive}Batch` | `ClosedCaseArchiveBatch` |
| Queueable | `{Descriptive}Queueable` or `{Descriptive}Job` | `CaseEscalationNotificationJob` |
| Schedulable | `{Descriptive}Scheduler` | `ClosedCaseArchiveScheduler` |
| Invocable | `{Descriptive}Invocable` | `EscalateCasesInvocable` |
| Trigger | `{SObject}Trigger` (one per object) | `CaseTrigger` |
| Trigger Handler | `{SObject}TriggerHandler` | `CaseTriggerHandler` |
| DTO / Wrapper | `{Descriptive}DTO` / `{Descriptive}Wrapper` | `CaseMergeRequestDTO` |
| Utility | `{Descriptive}Util` | `StringUtil` |
| Interface | `I{Descriptive}` | `INotificationService` |
| Abstract | `Abstract{Descriptive}` | `AbstractIntegrationService` |
| Exception | `{Descriptive}Exception` | `CaseDomainException` |
| REST Resource | `{SObject}RestResource` | `CaseRestResource` |
| Test | `{ClassName}Test` | `CaseServiceTest` |
| Mock | `{ClassName}Mock` | `CaseNotificationClientMock` |

Identifier casing: classes `PascalCase` · methods/variables `camelCase` · constants `UPPER_SNAKE_CASE`. Method verbs lead (`get`, `create`, `process`, `validate`, `is`, `has`, `can`). Collections: lists are plural nouns (`accounts`), maps are `{value}By{key}` (`accountsById`), sets of IDs are `{noun}Ids`. No abbreviations (`acc`, `tks`, `rec`).

---

## 4. Layered Architecture

| Layer | Owns | Must NOT contain |
|---|---|---|
| Entry (Trigger / Handler / Controller / Invocable / REST) | Routing, parameter validation, calling Service | Business rules, SOQL, DML, HTTP |
| Service | Orchestration, transaction boundary, partial-success handling, logging | Inline SOQL, direct queries, parsing details |
| Domain | Business rules, validations, field derivation on in-memory records | SOQL, DML, callouts |
| Selector | All SOQL for ONE SObject; returns `List<SObject>` or `Map<Id, SObject>` | Business logic, DML, callouts |
| Integration | HTTP callouts via Named Credentials; request/response parsing | Business decisions |

Hard rules:
- Triggers contain NO logic — they route to a single handler entry method per context.
- Controllers and Invocables are thin wrappers — validate input, call Service, return result.
- Selectors never call DML. Domains never query. Services never embed SOQL.
- A class > 500 lines must be split.

---

## 5. Sharing Keywords

Sharing keywords control **record-level visibility**. They do NOT enforce FLS or CRUD — those are separate (Section 6).

| Keyword | Behaviour | Use when |
|---|---|---|
| `with sharing` | Enforces org sharing rules for the running user | UI / Flow / REST entry points; any class invoked in user context |
| `without sharing` | Ignores sharing rules entirely | Batch, async, integration jobs that need full org access; requires justification comment |
| `inherited sharing` | Inherits caller's sharing context | Utility / Selector classes reused in both user and system contexts |

Rules:
- Default to `with sharing`.
- `without sharing` MUST carry a justification comment immediately above the class declaration:
  ```apex
  // without sharing: batch runs as system user; no user context; full org access required for reconciliation
  public without sharing class AccountReconciliationBatch implements Database.Batchable<SObject> {
  ```
- Selectors should use `inherited sharing` to be context-neutral.
- Never declare a class with NO sharing keyword — the implicit default is unsafe and unclear.
- Never use `without sharing` in an LWC `@AuraEnabled` controller or `@RestResource` without compensating CRUD/FLS checks.

**Decision flow:**

```
Entry point invoked by user action (LWC, button, Flow, REST)?
   YES -> with sharing
   NO  -> Reused in multiple contexts (selector, utility)?
          YES -> inherited sharing
          NO  -> Background / integration / batch / scheduled?
                 YES -> without sharing (+ justification)
                 NO  -> with sharing
```

---

## 6. User Mode vs System Mode (FLS / CRUD)

Salesforce API 56.0+ added explicit access-level modifiers for SOQL and DML. Use them at every entry point.

| Mode | SOQL | DML | Effect |
|---|---|---|---|
| **User Mode** | `WITH USER_MODE` | `Database.<op>(records, AccessLevel.USER_MODE)` | Enforces FLS + CRUD + sharing for the running user. Excludes inaccessible fields; throws on inaccessible objects |
| **System Mode** | `WITH SYSTEM_MODE` | `Database.<op>(records, AccessLevel.SYSTEM_MODE)` | Bypasses FLS / CRUD. Use only in explicitly `without sharing` background classes |
| `WITH SECURITY_ENFORCED` | legacy | n/a | Deprecated — do NOT use in new code. Throws `QueryException` if user can't read any field. Replaced by `WITH USER_MODE` |

```apex
// SOQL — user mode (preferred at entry points)
List<Case> cases = [SELECT Id, Subject FROM Case WHERE OwnerId = :uid WITH USER_MODE];

// SOQL — system mode (explicit override in a background class)
List<Case> cases = [SELECT Id FROM Case WITH SYSTEM_MODE];

// Dynamic SOQL — bind variables prevent injection
List<Case> cases = Database.queryWithBinds(
    'SELECT Id FROM Case WHERE Status = :s WITH USER_MODE',
    new Map<String, Object>{ 's' => 'Open' },
    AccessLevel.USER_MODE
);

// DML — user mode (enforces CRUD/FLS for running user)
Database.insert(records, AccessLevel.USER_MODE);
Database.update(records, AccessLevel.USER_MODE);
```

Every entry point must make an explicit choice. Never rely on the silent default of pre-56.0 system-mode DML.

---

## 7. SOQL — Bulk-Safe & Secure

| Rule | Rationale |
|---|---|
| No SOQL inside loops | 100-query governor limit |
| No `SELECT *` (does not exist in SOQL) | Always list exact fields needed |
| Bind variables for all user/dynamic input | Prevents SOQL injection |
| `WITH USER_MODE` at entry-point queries | FLS enforcement |
| `LIMIT` on any query that could return large sets | Heap/CPU safety |
| Filter on indexed fields where possible | Selective query |
| CMDT uses `getAll()` / `getInstance()` — NOT SOQL | Faster, no query consumed |
| Use `Map<Id, SObject>` constructor for ID-keyed lookups | Avoids manual loops |
| Use `Map<Id, List<SObject>>` to group child records by parent | Build the map in a single loop before processing |
| Use relationship subqueries when parent+child needed | One SOQL instead of two |
| Use `AggregateResult` with `GROUP BY` for rollups | Avoids querying + counting in Apex |

```apex
// Bulk-safe lookup
Set<Id> accountIds = new Set<Id>();
for (Case c : caseList) if (c.AccountId != null) accountIds.add(c.AccountId);

Map<Id, Account> accountById = new Map<Id, Account>(
    [SELECT Id, Name FROM Account WHERE Id IN :accountIds WITH USER_MODE]);

for (Case c : caseList) {
    Account acc = accountById.get(c.AccountId);
    if (acc != null) { /* use acc */ }
}

// SOQL injection — WRONG vs RIGHT
String q = 'SELECT Id FROM Case WHERE Status = \'' + userInput + '\'';  // WRONG
List<Case> cases = Database.query(q);

String status = userInput;                                                // RIGHT
List<Case> cases = [SELECT Id FROM Case WHERE Status = :status WITH USER_MODE];
```

---

## 8. DML — Partial Success & CRUD

Default to **partial success** in bulk / automation paths — one bad record should not fail the batch. CRUD checks at entry points before DML.

| CRUD method | Question |
|---|---|
| `Schema.sObjectType.Case.isCreateable()` | Can user create? |
| `Schema.sObjectType.Case.isUpdateable()` | Can user update? |
| `Schema.sObjectType.Case.isDeletable()` | Can user delete? |
| `Schema.sObjectType.Case.isAccessible()` | Can user read? |

```apex
if (!Schema.sObjectType.Case.isCreateable()) {
    throw new CaseDomainException('Running user lacks Create permission on Case.');
}
List<Database.SaveResult> results = Database.update(records, false);
for (Integer i = 0; i < results.size(); i++) {
    if (!results[i].isSuccess()) {
        AppLogger.log('CaseService.escalateOpenCases', AppLogger.Severity.ERROR,
            'Update failed: ' + results[i].getErrors()[0].getMessage(), records[i].Id);
    }
}
```

---

## 9. Security.stripInaccessible

Bulk-safe FLS enforcement for records assembled in memory or sourced from external input — use when `WITH USER_MODE` on the originating query is not possible. Does NOT enforce CRUD (still call `isCreateable()` / `isUpdateable()`). Call once on the whole list; never inside a loop.

| AccessType | Use before |
|---|---|
| `READABLE` | Returning records to the user |
| `CREATABLE` | Insert |
| `UPDATABLE` | Update |
| `UPSERTABLE` | Upsert (strips fields inaccessible for either create or update) |

```apex
SObjectAccessDecision decision = Security.stripInaccessible(AccessType.UPDATABLE, cases);
List<Case> cleaned = (List<Case>) decision.getRecords();
for (String f : decision.getRemovedFields().get('Case')) {
    AppLogger.log('CaseService.process', AppLogger.Severity.WARNING, 'Field stripped: ' + f, null);
}
Database.update(cleaned, false);
```

---

## 10. Triggers (One Per Object)

Project enforces a single trigger per SObject delegating to a handler. Trigger has NO logic — only `new CaseTriggerHandler().run();`. Handler routes by `Trigger.operationType` to Service entry methods. Manage recursion via field-value comparison against `Trigger.oldMap`, not a global static boolean (fragile across nested contexts).

```apex
trigger CaseTrigger on Case (before insert, before update, before delete,
    after insert, after update, after delete, after undelete) {
    new CaseTriggerHandler().run();
}

public with sharing class CaseTriggerHandler {
    public void run() {
        switch on Trigger.operationType {
            when BEFORE_INSERT { CaseService.onBeforeInsert(Trigger.new); }
            when BEFORE_UPDATE { CaseService.onBeforeUpdate(Trigger.new, (Map<Id, Case>) Trigger.oldMap); }
            when AFTER_INSERT  { CaseService.onAfterInsert(Trigger.new); }
            when AFTER_UPDATE  { CaseService.onAfterUpdate(Trigger.new, (Map<Id, Case>) Trigger.oldMap); }
        }
    }
}

// Recursion-safe field-change detection
public static void applyEscalation(List<Case> newCases, Map<Id, Case> oldMap) {
    for (Case c : newCases) {
        Case prior = (oldMap != null) ? oldMap.get(c.Id) : null;
        if (c.Priority == 'Critical' && (prior == null || prior.Priority != 'Critical')) {
            c.EscalationReason__c = 'Priority set to Critical';
            c.EscalationDate__c   = Date.today();
        }
    }
}
```

---

## 11. Invocable Apex

| Rule | Detail |
|---|---|
| `@InvocableMethod(label='…' description='…' category='…')` | Flow Builder display + grouping. Add `callout=true` if the method makes HTTP callouts |
| Method = `public static` | Non-static or single-record signatures fail to compile |
| I/O = `List<Request>` in, `List<Response>` out | Required for Flow bulkification |
| `Request` / `Response` are inner classes; fields use `@InvocableVariable(label='…' …)` | `label` is required on every variable |
| `@InvocableVariable` supported types | Primitives, `Id`, `SObject`, `List<T>`. No `Map`, `Set`, `Blob` |
| Always return errors via Response — never let exceptions bubble | Bubbling fires the Flow Fault path. Catch + return `isSuccess=false`, `errorMessage`, `errorType` |
| Delegate to Service — no business logic in the invocable | SRP |

```apex
public with sharing class EscalateCasesInvocable {
    @InvocableMethod(label='Escalate Open Cases' category='Case Management'
        description='Escalates all open cases for the provided Account IDs.')
    public static List<Response> escalateCases(List<Request> requests) {
        List<Response> responses = new List<Response>();
        Set<Id> accountIds = new Set<Id>();
        for (Request r : requests) if (r.accountId != null) accountIds.add(r.accountId);

        try {
            CaseService.escalateOpenCases(accountIds);
            for (Integer i = 0; i < requests.size(); i++) {
                Response r = new Response(); r.isSuccess = true; responses.add(r);
            }
        } catch (Exception ex) {
            AppLogger.log('EscalateCasesInvocable', AppLogger.Severity.ERROR, ex.getMessage(), null);
            for (Integer i = 0; i < requests.size(); i++) {
                Response r = new Response();
                r.isSuccess = false; r.errorMessage = ex.getMessage(); r.errorType = ex.getTypeName();
                responses.add(r);
            }
        }
        return responses;
    }

    public class Request {
        @InvocableVariable(label='Account ID' required=true) public Id accountId;
    }
    public class Response {
        @InvocableVariable(label='Is Success') public Boolean isSuccess;
        @InvocableVariable(label='Error Message') public String errorMessage;
        @InvocableVariable(label='Error Type') public String errorType;
    }
}
```

---

## 12. Async — Decision Matrix

| Scenario | Choose | Notes |
|---|---|---|
| Standard async work (chaining, callouts from trigger context) | **Queueable** | Returns Job ID; supports `Database.AllowsCallouts`; configurable delay via `AsyncOptions`; finalizer support |
| Very large datasets (> 50k records) | **Batch Apex** | Chunked; max 5 concurrent; use `QueryLocator` for big scopes |
| Modern alternative to Batch | **CursorStep** (`Database.Cursor`) | 2000-record chunks, no 5-job ceiling |
| Recurring schedule | **Scheduled Flow** (preferred) or **Schedulable** | Schedulable should only dispatch to Batch / Queueable |
| Post-job cleanup regardless of outcome | **`System.Finalizer`** attached to Queueable | Runs whether Queueable succeeded or failed |
| Long-running callouts | **Continuation** | ≤3 per transaction, ≤3 parallel |
| Delays > 10 minutes | `System.scheduleBatch()` | Schedules a Batch at a specific future time |
| Legacy fire-and-forget | ~~`@future`~~ | **Do NOT use in new code.** Cannot chain; cannot be called from Batch; cannot accept non-primitive types. Replace with Queueable + Finalizer |

### Queueable — pass a correlation ID via the constructor so AppLog entries across the chain join

```apex
public class CaseEscalationNotificationJob implements Queueable, Database.AllowsCallouts {
    private final List<Id> caseIds;
    private final String   correlationId;
    public CaseEscalationNotificationJob(List<Id> caseIds, String corrId) {
        this.caseIds = caseIds; this.correlationId = corrId;
    }
    public void execute(QueueableContext ctx) {
        try { CaseService.sendEscalationNotifications(caseIds); }
        catch (Exception ex) {
            AppLogger.log('CaseEscalationNotificationJob', AppLogger.Severity.ERROR,
                'corr=' + correlationId + ' | ' + ex.getMessage(), null);
        }
    }
}
// Enqueue: System.enqueueJob(new CaseEscalationNotificationJob(caseIds, corrId));
```

### Batch — `Database.Stateful` only when accumulating across chunks; tune batch size, drop to 1 for per-record callouts

```apex
// without sharing: batch runs as system user; full org access required for archive
public without sharing class ClosedCaseArchiveBatch implements Database.Batchable<SObject> {
    public Database.QueryLocator start(Database.BatchableContext ctx) {
        Date cutoff = Date.today().addYears(-1);
        return Database.getQueryLocator(
            'SELECT Id FROM Case WHERE Status = \'Closed\' AND CreatedDate < :cutoff');
    }
    public void execute(Database.BatchableContext ctx, List<Case> scope) {
        CaseService.archiveCases(scope);
    }
    public void finish(Database.BatchableContext ctx) {
        AppLogger.log('ClosedCaseArchiveBatch', AppLogger.Severity.INFO, 'JobId=' + ctx.getJobId(), null);
    }
}
```

### Schedulable — `execute()` does ONE thing: dispatch a Batch or Queueable

```apex
public class ClosedCaseArchiveScheduler implements Schedulable {
    public void execute(SchedulableContext ctx) {
        Database.executeBatch(new ClosedCaseArchiveBatch(), 200);
    }
}
// System.schedule('Nightly Case Archive', '0 0 2 * * ?', new ClosedCaseArchiveScheduler());
```

---

## 13. Callouts — Named Credentials Only

Hard rules:
- **All HTTP endpoints via Named Credentials**: `'callout:MyNamedCred/path'`. No hardcoded URLs, API keys, tokens, usernames, passwords — in code, Custom Settings, or CMDT.
- Use **External Credentials** for OAuth flows.
- Always set timeout: `req.setTimeout(30000)` (default 10s, max 120s).
- Check status code BEFORE deserializing the body.
- Wrap `Http().send()` in try/catch for `CalloutException`.

```apex
public with sharing class CaseNotificationClient {
    private static final String NAMED_CRED = 'callout:CaseNotificationAPI';
    public static Boolean sendEscalationNotification(Id caseId, String reason) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(NAMED_CRED + '/v1/escalations');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setTimeout(30000);
        req.setBody(JSON.serialize(new Map<String, Object>{
            'caseId' => String.valueOf(caseId), 'reason' => reason
        }));

        HttpResponse res;
        try { res = new Http().send(req); }
        catch (CalloutException ex) {
            AppLogger.log('CaseNotificationClient', AppLogger.Severity.ERROR,
                'Callout failed: ' + ex.getMessage(), caseId);
            return false;
        }
        if (res.getStatusCode() == 200 || res.getStatusCode() == 201) return true;
        AppLogger.log('CaseNotificationClient', AppLogger.Severity.ERROR,
            'HTTP ' + res.getStatusCode() + ' | ' + res.getBody(), caseId);
        return false;
    }
}
```

---

## 14. Exception Handling

| Rule | Detail |
|---|---|
| Custom exception per domain | `public class CaseDomainException extends Exception {}` |
| Catch specific type; reserve generic `Exception` for outermost handlers | Avoids hiding bugs |
| Never swallow — log before returning or re-throwing | `AppLogger.log(...)` then act |
| Re-throw with cause to preserve the chain | `throw new CaseDomainException('wrapped', ex);` |
| `try/catch` only around code that can throw | DML, callouts, JSON parse, casts. Not assignments or arithmetic |
| `@AuraEnabled` methods: rethrow as `AuraHandledException` with sanitized message | Internals stay server-side |
| Invocable methods: return errors in `Response`, do NOT throw | Bubbling triggers the Flow Fault path |

```apex
public static void createCases(List<Case> cases) {
    if (!Schema.sObjectType.Case.isCreateable()) {
        throw new CaseDomainException('Running user lacks Create permission on Case.');
    }
    try { Database.insert(cases, AccessLevel.USER_MODE); }
    catch (DmlException ex) {
        AppLogger.log('CaseService.createCases', AppLogger.Severity.ERROR, ex.getMessage(), null);
        throw new CaseDomainException('Case creation failed: ' + ex.getMessage(), ex);
    }
}
```

---

## 15. Logging — `AppLogger`

| Rule | Detail |
|---|---|
| Centralized logger to `App_Log__c` | No `System.debug()` as primary logging in production |
| `Database.insert(log, false)` + own try/catch | Logging never breaks business logic |
| No PII / secrets | Names, emails, phones, SSNs, tokens, passwords are forbidden in log message |
| Severity | `INFO` (milestone) · `WARNING` (non-fatal) · `ERROR` (failure) |
| Include `class.method` context + record ID | Lets queries on `App_Log__c` join by record |

```apex
// without sharing: logging must succeed regardless of running user's record access
public without sharing class AppLogger {
    public enum Severity { INFO, WARNING, ERROR }

    public static void log(String context, Severity severity, String message, Id recordId) {
        try {
            App_Log__c entry = new App_Log__c(
                Context__c   = context,
                Severity__c  = severity.name(),
                Message__c   = message != null ? message.abbreviate(32000) : '',
                Record_Id__c = recordId != null ? String.valueOf(recordId) : null,
                Timestamp__c = System.now());
            Database.insert(entry, false);
        } catch (Exception ex) {
            System.debug(LoggingLevel.ERROR, 'AppLogger failed: ' + ex.getMessage());
        }
    }
}
```

---

## 16. Test Classes

**Project rule:** test classes are deferred until after sandbox functional testing. Do NOT generate tests inline with Apex changes unless the task is explicitly a testing task. When generating, follow the rules below.

| Rule | Detail |
|---|---|
| `@isTest` on every test class | Required |
| `@TestSetup` for shared data | Improves performance; no assertions or complex logic inside |
| No `SeeAllData=true` | Hard-stop unless legacy contract demands it — document with a comment |
| `TestDataFactory` for all data creation | Never build records inline in test methods |
| AAA / Given-When-Then structure | One behaviour per test method |
| `Assert.areEqual` / `Assert.isTrue` / `Assert.fail` | Use the `Assert` class (not legacy `System.assert*`) |
| Test names: `should<Result>_When<Scenario>` | E.g. `shouldEscalate_WhenPriorityRisesToCritical` |
| Bulk test = 200+ records (251 to cross the trigger batch boundary) | Required for any class processing collections |
| `Test.startTest()` / `Test.stopTest()` around code under test | Resets governor limits; forces async |
| `HttpCalloutMock` for all callouts | Set BEFORE `Test.startTest()` |
| `System.runAs(restrictedUser)` for security tests | Validates `with sharing` / FLS paths |
| Coverage: ≥75% deploy minimum, target 90%+, 100% for critical paths | Meaningful assertions, not just coverage |

### Factory + negative + mock patterns

```apex
@isTest
public class TestDataFactory {
    public static List<Case> createCases(Id accountId, Integer count, String status) {
        List<Case> cases = new List<Case>();
        for (Integer i = 0; i < count; i++) {
            cases.add(new Case(Subject='Test ' + i, Status=status, Priority='Medium', AccountId=accountId));
        }
        insert cases;
        return cases;
    }
}

@isTest
static void shouldThrow_WhenAccountIdNull() {
    Test.startTest();
    try {
        CaseService.escalateOpenCases(null);
        Assert.fail('Expected CaseDomainException');
    } catch (CaseDomainException e) {
        Assert.isTrue(e.getMessage().contains('cannot be null'), 'Wrong message');
    }
    Test.stopTest();
}

@isTest
public class CaseNotificationClientMock implements HttpCalloutMock {
    private final Integer statusCode; private final String body;
    public CaseNotificationClientMock(Integer s, String b) { statusCode = s; body = b; }
    public HTTPResponse respond(HTTPRequest req) {
        HttpResponse r = new HttpResponse();
        r.setStatusCode(statusCode); r.setBody(body); return r;
    }
}
// Test.setMock(HttpCalloutMock.class, new CaseNotificationClientMock(200, '{"status":"ok"}'));
```

### What to test, by component

| Component | Scenarios |
|---|---|
| Trigger | Bulk insert/update/delete (251+), recursion guard, field-change detection |
| Service | Valid + invalid inputs, bulk, exception handling, security via `runAs` |
| Controller / `@AuraEnabled` | Happy path, restricted user, exception → `AuraHandledException` |
| Batch | start/execute/finish; `batchSize >= testRecordCount` (only one `execute()` invocation runs in test) |
| Queueable | Bulkification, chain depth, callout mocks set BEFORE `Test.startTest()` |
| Schedulable | Direct `execute(null)`, CRON via `CronTrigger` query |
| Selector | Valid / null / empty inputs, bulk, field population, `runAs` for FLS |
| Callout | Success, error, timeout responses |
| Platform Event | `Test.enableChangeDataCapture()`, `Test.getEventBus().deliver()` |

---

## 17. Validation Commands

```bash
# Full check-only deploy with local tests (the project standard)
sf project deploy start \
  --manifest manifest/package-case-flow-optimization.xml \
  --target-org PlusGradeFullSB \
  --dry-run --test-level RunLocalTests --wait 60

# Run a specific test class
sf apex run test \
  --class-names CaseServiceTest \
  --target-org PlusGradeFullSB \
  --code-coverage --result-format human --wait 10

# Run multiple test classes
sf apex run test \
  --class-names CaseServiceTest,CaseSelectorTest,CaseDomainTest \
  --target-org PlusGradeFullSB \
  --result-format human

# Retrieve a class before modifying
sf project retrieve start \
  --metadata "ApexClass:CaseService" \
  --target-org PlusGradeFullSB
```

**Expected noise:** 13 pre-existing Opportunity test failures are known and do not block Case deployment.

---

## 18. Definition of Done

- [ ] Class header (`Description` / `Developer: Naresh` / `Title: Senior Salesforce Developer`) on every new/modified class
- [ ] ApexDoc on every public/global/protected method
- [ ] Sharing keyword explicitly declared (no implicit default)
- [ ] `without sharing` carries a justification comment on the line above the class declaration
- [ ] No SOQL inside loops; no DML inside loops (anywhere — including transitive callees)
- [ ] `WITH USER_MODE` at every entry-point query, OR explicit `WITH SYSTEM_MODE` in a justified background class
- [ ] DML at entry points uses `AccessLevel.USER_MODE` or `stripInaccessible` before `Database.insert/update`
- [ ] Bulk automation DML uses partial-success: `Database.insert(list, false)` + `SaveResult` inspection + AppLogger
- [ ] Invocable methods: `public static`, `List<Request>` in / `List<Response>` out, errors returned in Response
- [ ] All HTTP callouts use Named Credentials with explicit `setTimeout()`
- [ ] Custom exception class defined for the domain
- [ ] `AppLogger.log()` calls on every error path and significant info milestone
- [ ] No hardcoded IDs, URLs, secrets — anywhere
- [ ] No `@future` (use Queueable + Finalizer)
- [ ] No `System.debug()` as primary logging in production paths
- [ ] No `WITH SECURITY_ENFORCED` in new code (use `WITH USER_MODE`)
- [ ] Class ≤ 500 lines (split if exceeded)
- [ ] Check-only deploy passes with `RunLocalTests` (only the 13 known Opportunity failures)
- [ ] If tests authored: `@TestSetup` + `TestDataFactory` + 200+ bulk + negative + async (`startTest/stopTest`) + mock callout + ≥75% coverage with meaningful asserts

---

## 19. Common AI Mistakes to Avoid

| # | Mistake | Correct approach |
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

## 20. Empirical Findings & Implementation Notes

When Salesforce's documented approach doesn't work in this org / version / feature combination, record the working alternative here. Date-stamp every entry.

| # | Date | Documented approach | What actually works | Why / Context |
|---|---|---|---|---|

*(No entries yet — append rows as production findings emerge.)*

---

## 21. Official References

- [Apex Developer Guide](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/)
- [Apex Security and Sharing](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_security_sharing_understand.htm)
- [Sharing Keywords (with/without/inherited)](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_bulk_sharing_creating_with_keywords.htm)
- [WITH USER_MODE / WITH SYSTEM_MODE](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_classes_enforce_usermode.htm)
- [Security.stripInaccessible](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_classes_with_security_stripInaccessible.htm)
- [Invocable Apex](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_classes_annotation_InvocableMethod.htm)
- [Batch Apex](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_batch_interface.htm)
- [Queueable Apex](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_queueing_jobs.htm)
- [System.Finalizer](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_class_System_Finalizer.htm)
- [Named Credentials](https://help.salesforce.com/s/articleView?id=sf.named_credentials_about.htm)
- [Apex Governor Limits](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_gov_limits.htm)
- [Apex Testing — Trailhead](https://trailhead.salesforce.com/content/learn/modules/apex_testing)
- [forcedotcom/sf-skills `generating-apex`](https://github.com/forcedotcom/sf-skills/tree/main/skills/generating-apex)
- [forcedotcom/sf-skills `generating-apex-test`](https://github.com/forcedotcom/sf-skills/tree/main/skills/generating-apex-test)

---

*Apex Development Guidelines | v3.0 | Last verified 2026-05-16*
