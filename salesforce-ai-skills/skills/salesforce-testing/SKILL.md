---
name: salesforce-testing
description: Production Salesforce AI skill for Apex/Jest/Flow validation strategy and test implementation.
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
- The task involves Apex/Jest/Flow validation strategy and test implementation.
- The user asks for implementation, refactor, troubleshooting, review, or best-practice validation in this area.
- The assistant must produce Salesforce-safe code/metadata with explicit security/testing notes.

## DO NOT TRIGGER when
- The task is unrelated to this component.
- Another specialized skill is the primary owner and this area is only incidental.
- The user asks for operational execution (deploy/publish/activate/destructive change) without explicit approval.

## Cross-skill routing
- Always read `../salesforce-global-development/SKILL.md`.
- Also read: Global Development + Apex/Flow/LWC + Integration.
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
Use AAA pattern, @testSetup for shared data, TestDataFactory for readability. Include positive, negative, bulk, and permission/security tests. Mock callouts via HttpCalloutMock.

## Upstream Salesforce Skill Patterns
- One behavior per test method; split null, empty, valid, invalid, bulk, and exception paths instead of compressing them into one broad test.
- Bulk tests should cross the trigger chunk boundary with 251+ records unless the component has a narrower technical limit.
- Use `@TestSetup` plus a reusable `TestDataFactory`; never depend on org data, hardcoded IDs, or existing setup records.
- Use the modern `Assert` class with clear failure messages. Avoid legacy `System.assert*` in new tests.
- Always wrap the code under test in `Test.startTest()` and `Test.stopTest()` so governor limits and async execution are meaningful.
- Mock external boundaries with `HttpCalloutMock`, SOSL fixed search results, platform-event delivery helpers, or dependency injection as appropriate.
- Debug failures narrowly first: run one class or method, inspect root cause, fix, then widen to local tests or deployment validation.

## Examples
### Good example patterns
1. Test.startTest/stopTest around async invocation assertions.
2. Jest test verifies loading/error/success rendering branches.

### Bad examples / avoid
1. Rely on org data with seeAllData=true by default.
2. Only happy-path tests without permission or bulk cases.

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

# Testing Guidelines -- Canonical Reference

Authoritative grammar for Salesforce tests in this project: Apex unit tests, async/callout patterns, LWC Jest, and Agentforce agent tests. Attach when writing or reviewing any test code.

**Verified against:** [Apex Testing Introduction](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_testing_introduction.htm) - [Apex Testing Best Practices](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_testing_best_practices.htm) - [HttpCalloutMock Interface](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_testing_using_mock_interface.htm) - [Async Apex Testing](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_testing_tools_async.htm) - [LWC Jest Introduction](https://developer.salesforce.com/docs/component-library/documentation/en/lwc/lwc.unit_testing_using_jest_introduction) - [forcedotcom/sf-skills `generating-apex-test`](https://github.com/forcedotcom/sf-skills/tree/main/skills/generating-apex-test) - [`running-apex-tests`](https://github.com/forcedotcom/sf-skills/tree/main/skills/running-apex-tests) - [`testing-agentforce`](https://github.com/forcedotcom/sf-skills/tree/main/skills/testing-agentforce). Last verified 2026-05-16.

---

## 1. Core Principles

| # | Principle | Why |
|---|---|---|
| 1 | One behaviour per `@isTest` method | Failures point to a single cause. Never combine "null and empty" -- split into `_NullInput_` and `_EmptyInput_`. |
| 2 | Arrange / Act / Assert (Given / When / Then) | Three labelled blocks per test. Setup -> invoke -> verify, no interleaving. |
| 3 | Bulk-test with 200 records (251 recommended) | Triggers fire in batches of 200. 251 crosses the boundary. Batch Apex is the exception -- set `batchSize >= recordCount`. |
| 4 | Test data via `TestDataFactory` only | No inline records in tests. No hardcoded record Ids. No reliance on org data. |
| 5 | `Assert` class only | `Assert.areEqual`, `Assert.isTrue`, `Assert.isNotNull`, `Assert.fail`. Legacy `System.assertEquals` still compiles but new code uses `Assert`. |
| 6 | Every assertion has a descriptive message | Third argument is mandatory. Bare `Assert.areEqual(expected, actual)` is forbidden. |
| 7 | Mock external boundaries | `HttpCalloutMock` for callouts, `Test.setFixedSearchResults` for SOSL, `StubProvider` for class deps, DML interface injection for DB-free unit tests. |
| 8 | Pair `Test.startTest()` with `Test.stopTest()` | Resets governor limits; forces async (Queueable / Batch / `@future` / Scheduled) to execute synchronously. |
| 9 | Test negative paths | Validate invalid input, missing fields, exception types, CRUD/FLS denials. Happy path alone is not a test suite. |

---

## 2. Test Class Skeleton

```apex
@isTest
private class CaseServiceTest {

    // @TestSetup runs once per test method. Rolled back between methods.
    @TestSetup
    static void setupTestData() {
        Account acc = TestDataFactory.createAccount(true);
        TestDataFactory.createCases(5, acc.Id, true);
    }

    @isTest
    static void shouldCreateCase_WhenInputIsValid() {
        // Given
        Account acc = [SELECT Id FROM Account LIMIT 1];

        // When
        Test.startTest();
        Case result = CaseService.createCase(acc.Id, 'Subject', 'High');
        Test.stopTest();

        // Then
        Assert.isNotNull(result.Id, 'Case should be inserted with an Id');
        Assert.areEqual('High', result.Priority, 'Priority should match input');
    }
}
```

**Naming.** `should<ExpectedResult>_When<Scenario>` is canonical. `<Subject>_<Scenario>_<Result>` is accepted for legacy classes. Whatever shape, the name must read as a sentence describing what is verified.

**`@TestSetup` rules.** Use only when **two or more** methods share the data -- single-method data goes inline. Always re-query setup data inside each `@isTest`; never store SObjects in static variables across methods.

---

## 3. `Test.startTest()` / `Test.stopTest()` -- Required Placement

| Block | Contents |
|---|---|
| Before `startTest()` | All setup DML, all `Test.setMock(...)`, all `Test.setFixedSearchResults(...)`. |
| Between `startTest()` / `stopTest()` | Exactly the code under test. Async enqueues go here. |
| After `stopTest()` | Re-query records and run all assertions. Async work has now completed. |

`Test.setMock(HttpCalloutMock.class, ...)` MUST be called **before** `Test.startTest()`, even for async code whose callout fires inside `stopTest()`. Setting it later silently no-ops.

---

## 4. Assertions

```apex
// CORRECT
Assert.areEqual(200, results.size(), 'All 200 cases should be inserted');
Assert.isNotNull(c.Id, 'Case should be inserted with an Id');
Assert.isTrue(result.success, 'Integration call should succeed for valid payload');
Assert.fail('Expected InvalidInputException for null subject');

// WRONG -- vague comparison, no message, legacy API
System.assertEquals(200, results.size());
Assert.isTrue(results.size() > 0);   // use areEqual with exact count
Assert.isTrue(count != 0);            // use areEqual with deterministic value
```

| Anti-pattern | Fix |
|---|---|
| `Assert.isTrue(results.size() > 0)` | `Assert.areEqual(expectedCount, results.size(), '...')` |
| Coverage-only test (no assertion) | Add at least one `Assert.*` call that proves behaviour |
| Generic `catch (Exception e)` | Catch the specific type (`DmlException`, `CalloutException`, `MyService.InvalidInputException`) |
| Asserting on implementation detail | Assert on observable outcomes -- field values, record counts, dispatched events |

---

## 5. Test Data Factory

A single `TestDataFactory.cls` lives in `force-app/main/default/classes/`. Every test class delegates record creation to it.

**Design rules.**
1. Every method accepts `Boolean doInsert` so callers control DML timing.
2. Single-record methods delegate to bulk: `createAccount(doInsert) -> createAccounts(1, doInsert)[0]`.
3. Methods return the created record(s).
4. Append the loop index to fields covered by Duplicate Rules or unique constraints.
5. Set every field enforced by validation rules -- not just schema-required ones.
6. Never hardcode a Salesforce Id. Use the `.Id` of an inserted record.

```apex
@isTest
public class TestDataFactory {

    public static Account createAccount(Boolean doInsert) {
        return createAccounts(1, doInsert)[0];
    }

    public static List<Account> createAccounts(Integer count, Boolean doInsert) {
        List<Account> accounts = new List<Account>();
        for (Integer i = 0; i < count; i++) {
            accounts.add(new Account(Name = 'Test Account ' + i, Type = 'Customer'));
        }
        if (doInsert) insert accounts;
        return accounts;
    }

    public static List<Case> createCases(Integer count, Id accountId, Boolean doInsert) {
        List<Case> cases = new List<Case>();
        for (Integer i = 0; i < count; i++) {
            cases.add(new Case(
                Subject = 'Test Case ' + i, Status = 'New',
                Priority = 'Medium', Origin = 'Email', AccountId = accountId
            ));
        }
        if (doInsert) insert cases;
        return cases;
    }

    public static User createMinimumAccessUser(Boolean doInsert) {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Minimum Access - Salesforce' LIMIT 1];
        String suffix = String.valueOf(System.currentTimeMillis());
        User u = new User(
            FirstName = 'Test', LastName = 'Restricted',
            Email = 'restricted' + suffix + '@test.example.com',
            Username = 'restricted' + suffix + '@test.example.com',
            Alias = 'rstd', TimeZoneSidKey = 'America/New_York',
            LocaleSidKey = 'en_US', EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US', ProfileId = p.Id
        );
        if (doInsert) insert u;
        return u;
    }
}
```

**Field-override pattern.** Pass a map instead of forking the method:

```apex
public static Account createAccount(Map<String, Object> overrides, Boolean doInsert) {
    Account acc = new Account(Name = 'Test Account', Industry = 'Technology');
    for (String f : overrides.keySet()) { acc.put(f, overrides.get(f)); }
    if (doInsert) insert acc;
    return acc;
}
```

**Duplicate-rule handling.** Use `Database.DMLOptions`:

```apex
Database.DMLOptions dml = new Database.DMLOptions();
dml.DuplicateRuleHeader.allowSave = true;
Database.insert(accounts, dml);
```

---

## 6. Bulk Tests -- 200 Records (Mandatory)

Every trigger, every service that processes a list, every batch class needs one test that processes 200 records (251 to cross the trigger-batch boundary explicitly). Code that works for one record but throws `Too many SOQL queries: 101` at 200 is a production defect -- the bulk test is the catch.

```apex
@isTest
static void shouldProcessAllCases_When200InsertedAtOnce() {
    Account acc = TestDataFactory.createAccount(true);
    List<Case> cases = TestDataFactory.createCases(200, acc.Id, false);

    Test.startTest();
    insert cases;            // fires trigger with Trigger.new.size() == 200
    Test.stopTest();

    List<Case> results = [SELECT Id, Status FROM Case WHERE AccountId = :acc.Id];
    Assert.areEqual(200, results.size(), 'All 200 cases should be inserted');
    for (Case c : results) {
        Assert.isNotNull(c.Status, 'Status should be populated for case ' + c.Id);
    }
}
```

**Batch Apex -- special rule.** In test context Batch Apex runs only **one** `execute()` invocation. Always set `batchSize >= recordCount`:

```apex
Database.executeBatch(new CaseClosingBatch(), 200);   // batchSize == recordCount
```

---

## 7. Async Testing

`Test.stopTest()` forces all pending async work (Queueable, Batch, `@future`, Scheduled) to execute synchronously. Without it, async never runs and assertions fail silently.

### Queueable

```apex
@isTest
static void shouldUpdateStatus_WhenQueueableExecutes() {
    Account acc = TestDataFactory.createAccount(true);
    Case c = TestDataFactory.createCase(acc.Id, true);

    Test.startTest();
    System.enqueueJob(new CaseProcessingQueueable(new Set<Id>{ c.Id }));
    Test.stopTest();

    Case updated = [SELECT Status FROM Case WHERE Id = :c.Id];
    Assert.areEqual('Processed', updated.Status, 'Queueable should update Status');
}
```

**Queueable chaining.** Only the first chained job runs inside one test. Verify (a) the first job's side effects, (b) the chain was enqueued (query `AsyncApexJob`), (c) each downstream link has its own test method.

### `@future`

Project rule: prefer Queueable + `System.Finalizer` over `@future`. New `@future` code is rejected at review. Test legacy `@future` like Queueable -- call inside `startTest/stopTest`, assert after `stopTest`.

### Scheduled Apex

```apex
@isTest
static void shouldRegisterCron_WhenJobScheduled() {
    Test.startTest();
    String jobId = System.schedule('Test Daily Sync', '0 0 2 * * ?', new NightlyCaseSyncSchedulable());
    Test.stopTest();

    CronTrigger ct = [SELECT CronExpression, State FROM CronTrigger WHERE Id = :jobId];
    Assert.areEqual('0 0 2 * * ?', ct.CronExpression, 'CRON should match');
}
```

Direct execution also acceptable: `new MyScheduledClass().execute(null);` inside `startTest/stopTest`.

### Async + callout

Mock **before** `Test.startTest()`, even when the callout fires inside the async job:

```apex
Test.setMock(HttpCalloutMock.class, new MockHttpResponse(200, '{"ok":true}'));
Test.startTest();
System.enqueueJob(new MyCalloutQueueable(recordId));
Test.stopTest();
```

---

## 8. Mocking

### HTTP -- `HttpCalloutMock`

Apex doesn't allow real HTTP in tests. Every code path containing `new Http().send(req)` needs a registered mock or it throws `System.CalloutException`.

```apex
@isTest
public class MockHttpResponse implements HttpCalloutMock {
    private Integer statusCode;
    private String body;
    public MockHttpResponse(Integer statusCode, String body) {
        this.statusCode = statusCode; this.body = body;
    }
    public HTTPResponse respond(HTTPRequest req) {
        HttpResponse res = new HttpResponse();
        res.setStatusCode(statusCode); res.setBody(body);
        res.setHeader('Content-Type', 'application/json');
        return res;
    }
}
```

```apex
Test.setMock(HttpCalloutMock.class, new MockHttpResponse(200, '{"id":"EXT-001"}'));
```

**Every HTTP client must be tested against:**

| Scenario | Status | Proves |
|---|---|---|
| Success | 200 / 201 | Happy path -- payload parsed, record updated |
| Bad request | 400 | Permanent failure, no retry, logged |
| Auth failure | 401 / 403 | `isAuthFailure = true`, ops alert fires |
| Not found | 404 | Permanent, logged, no retry |
| Rate limited | 429 | `isRetryable = true`, retry scheduled |
| Server error | 500 | `isRetryable = true` |
| Timeout | `CalloutException` | `IntegrationException` re-thrown |

For multi-endpoint transactions use a `MultiRequestMock` that routes `req.getEndpoint()` substrings to per-endpoint mocks.

### `StubProvider` -- class dependencies

```apex
@isTest
public class CaseGatewayMock implements System.StubProvider {
    public Object handleMethodCall(Object stubbed, String methodName, Type returnType,
                                   List<Type> paramTypes, List<String> paramNames, List<Object> args) {
        if (methodName == 'fetchById') return new Case(Subject = 'Mocked', Status = 'New');
        return null;
    }
}

@isTest
static void shouldUseInjectedGateway() {
    ICaseGateway mock = (ICaseGateway) Test.createStub(ICaseGateway.class, new CaseGatewayMock());
    Test.startTest();
    String r = new CaseController(mock).renderCaseSummary();
    Test.stopTest();
    Assert.isTrue(r.contains('Mocked'), 'Controller should use injected gateway');
}
```

Pair with constructor injection in production code (`@TestVisible private MyService(IGateway g)`).

### SOSL

SOSL returns empty in tests by default. Pre-seed before `Test.startTest()`:

```apex
Test.setFixedSearchResults(new List<Id>{ acc.Id });
```

### Platform Events

```apex
Test.startTest();
Test.enableChangeDataCapture();
EventBus.publish(new Case_Status_Change__e(CaseId__c = c.Id, NewStatus__c = 'Closed'));
Test.getEventBus().deliver();
Test.stopTest();
```

### Email

Apex doesn't actually send mail in tests. Verify via `Limits.getEmailInvocations()`.

---

## 9. `System.runAs()` and Security Tests

`@AuraEnabled`, `@InvocableMethod`, `@RestResource`, and any UI-exposed controller need at least one test that runs as a restricted user.

```apex
@isTest
static void shouldThrowAuraHandledException_WhenUserHasNoCaseAccess() {
    User restricted = TestDataFactory.createMinimumAccessUser(true);

    System.runAs(restricted) {
        try {
            Test.startTest();
            CaseDashboardController.getCases();
            Test.stopTest();
            Assert.fail('AuraHandledException should be thrown');
        } catch (AuraHandledException e) {
            // Message is sanitized -- just verify the throw
        }
    }
}
```

Production-code CRUD/FLS checks the tests validate:

```apex
if (!Schema.sObjectType.Case.isCreateable()) {
    throw new InsufficientAccessException('No create access on Case');
}
// Or use USER_MODE on DML / SOQL
List<Case> cases = [SELECT Id, Subject FROM Case WITH USER_MODE LIMIT 100];
Database.insert(newCases, AccessLevel.USER_MODE);
// Or strip inaccessible fields
SObjectAccessDecision d = Security.stripInaccessible(AccessType.READABLE, cases);
List<Case> safe = (List<Case>) d.getRecords();
```

---

## 10. `SeeAllData=false` Enforcement

`@isTest` defaults to `SeeAllData=false` -- tests cannot see org data. **Do not change this default.**

`SeeAllData=true` is forbidden except: (1) tests for org-setup data that cannot be mocked (e.g., `CurrencyType`), (2) legacy code pre-dating `@isTest` isolation that cannot be safely refactored, (3) Visualforce/Apex that intentionally reads org data and has a documented tech-debt ticket. Any exception needs a justification comment and an approval:

```apex
@isTest(SeeAllData=true)
// REASON: CurrencyType records are unavailable in test context.
// Tech-debt: JIRA-1234 -- refactor to inject currency data.
private class CurrencyConversionTest { ... }
```

Custom Metadata Type records ARE accessible in test context without `SeeAllData=true` -- use CMDT for configuration data.

---

## 11. Negative Tests -- Exception Verification

Every validation, every business-rule branch, every catch block needs a negative test:

```apex
@isTest
static void shouldThrowInvalidInputException_WhenSubjectIsNull() {
    Account acc = TestDataFactory.createAccount(true);

    Test.startTest();
    try {
        CaseService.createCase(acc.Id, null, 'High');
        Assert.fail('InvalidInputException should be thrown for null subject');
    } catch (CaseService.InvalidInputException e) {
        Assert.isTrue(e.getMessage().contains('subject'),
            'Exception message should mention subject field');
    }
    Test.stopTest();
}
```

- Catch the **specific** exception type, never `Exception`.
- Always assert on message content -- proves the failure cause.
- Always include `Assert.fail(...)` inside the `try` -- catches "no exception was thrown" silently passing.

Empty / null input is its own test -- should return gracefully, no exception:

```apex
@isTest
static void shouldReturnGracefully_WhenInputListIsEmpty() {
    Test.startTest();
    CaseService.processCases(new List<Id>());
    Test.stopTest();
    Assert.areEqual(0, [SELECT COUNT() FROM Case], 'No cases should be created');
}
```

---

## 12. Flow Testing via Apex

Salesforce Flows have no native unit-test framework. Test Record-Triggered and Autolaunched Flows from Apex -- create the triggering record, assert on downstream effects.

```apex
@isTest
static void shouldCreateFollowUpTask_WhenHighPriorityCaseInserted() {
    Account acc = TestDataFactory.createAccount(true);

    Test.startTest();
    Case c = new Case(Subject = 'Critical', Status = 'New', Priority = 'High', AccountId = acc.Id);
    insert c;
    Test.stopTest();

    List<Task> tasks = [SELECT Subject FROM Task WHERE WhatId = :c.Id];
    Assert.areEqual(1, tasks.size(), 'Escalation Flow should create one task');
}
```

If the Flow calls Invocable Apex, unit-test the Apex directly **and** integration-test by triggering the Flow.

For interactive debugging: Flow Builder -> **Debug** -> optionally **Run as another user**.

---

## 13. LWC Jest Tests

Per-component contract:

| Category | Cover |
|---|---|
| Render -- initial | Mounts with defaults, no errors |
| Render -- data | `getX.mockResolvedValue(payload)`, assert rendered DOM |
| Render -- empty | API returns `[]` -> empty-state element present |
| Render -- loading | Spinner visible while promise unresolved |
| Render -- error | `getX.mockRejectedValue({...})` -> error display visible |
| Interaction | Clicks, form changes, child-event handlers |
| Event contract | Custom events dispatched with correct `detail` payload |
| Accessibility | ARIA roles, labels, landmarks |

```js
import { createElement } from 'lwc';
import CaseDashboard from 'c/caseDashboard';
import getCases from '@salesforce/apex/CaseDashboardController.getCases';

jest.mock('@salesforce/apex/CaseDashboardController.getCases',
    () => ({ default: jest.fn() }), { virtual: true });

describe('c-case-dashboard', () => {
    afterEach(() => {
        while (document.body.firstChild) document.body.removeChild(document.body.firstChild);
        jest.clearAllMocks();
    });

    it('renders cases when API resolves', async () => {
        getCases.mockResolvedValue([{ Id: '5000000000000001AAA', Subject: 'Case 1' }]);
        const el = createElement('c-case-dashboard', { is: CaseDashboard });
        document.body.appendChild(el);
        await Promise.resolve();
        await Promise.resolve();

        const cards = el.shadowRoot.querySelectorAll('c-case-card');
        expect(cards).toHaveLength(1);
    });
});
```

For `@wire`-bound Apex, use `registerApexTestWireAdapter` from `@salesforce/sfdx-lwc-jest`; call `.emit(data)` / `.emitError(err)` from the test.

**Jest anti-patterns.** Skipping `afterEach` cleanup (DOM bleeds between tests). Asserting on private fields (`element._foo`) -- assert only on rendered DOM and dispatched events. Missing `await Promise.resolve()` after async (assertions race the promise).

---

## 14. Agentforce Agent Tests

Two modes -- ad-hoc preview (Mode A) and persistent test suites (Mode B). Mode A during authoring; Mode B for regression and CI/CD.

### Mode A -- `sf agent preview`

```bash
SESSION_ID=$(sf agent preview start --json --authoring-bundle MyAgent -o <target-env-alias> | jq -r '.result.sessionId')
sf agent preview send --json --session-id $SESSION_ID --authoring-bundle MyAgent \
  --utterance "test utterance" -o <target-env-alias>
sf agent preview end  --json --session-id $SESSION_ID --authoring-bundle MyAgent -o <target-env-alias>
```

Traces land at `.sfdx/agents/<BundleName>/sessions/<sessionId>/traces/<planId>.json`. `--authoring-bundle` must appear on **all three** subcommands. Strip control chars before piping JSON to `jq`. Always run safety probes (PII, prompt injection, off-topic) and emit a verdict: **SAFE / UNSAFE / NEEDS_REVIEW**.

### Mode B -- `sf agent test`

```yaml
# tests/MyAgent-testing-center.yaml
name: "Email Analysis Smoke"
subjectType: AGENT
subjectName: Example_Agent
testCases:
  - utterance: "Analyze this inbound support email"
    expectedTopic: structured_analysis
    expectedActions:
      - get_context          # Level 2 invocation name from reasoning.actions
    expectedOutcome: "Agent returns STRUCTURED_ANALYSIS JSON"
```

```bash
sf agent test create  --json --spec tests/MyAgent-testing-center.yaml --api-name MyAgentSuite -o <target-env-alias>
sf agent test run     --json --api-name MyAgentSuite --wait 10 --result-format json -o <target-env-alias> | tee /tmp/run.json
JOB_ID=$(jq -r '.result.runId' /tmp/run.json)
sf agent test results --json --job-id "$JOB_ID" --result-format json -o <target-env-alias>
```

**Key rules.**
- `expectedActions` uses **Level 2 invocation names** (from `reasoning: actions:`), NOT Level 1 definitions.
- Action assertion is superset matching -- actual actions >= expected.
- For guardrail tests omit `expectedTopic`, rely on `expectedOutcome`; filter `topic_assertion` FAILURE.
- Topic-hash drift: runtime topic name changes after each republish. Re-discover names after every publish.
- Always use `--job-id`, never `--use-most-recent`.

Place test files under `tests/<AgentApiName>-{testing-center,regression,smoke}.yaml`.

---

## 15. Coverage Targets

| Target | Threshold | Notes |
|---|---|---|
| Salesforce platform minimum | **75%** org-wide Apex | Hard limit. Production deploy is blocked below this. |
| Team healthy bar | **>= 90%** per class | Coverage **with assertions**, not execution inflation. New classes meet this before merge. |
| Critical / business-logic | **100%** | Pricing, billing, escalation, security paths. |
| Jest (LWC) | branches >= 75%, lines/funcs/statements >= 85% | Configured in `package.json` `coverageThreshold`. |

What doesn't count: lines executed without assertions; test classes / interfaces / abstract classes / `@TestSetup` (excluded by Salesforce); negative-path lines no test triggers.

---

## 16. Governor-Limit Awareness Inside Tests

Tests run under the same limits as production. Inflated tests fail at unrelated boundaries.

- `Test.startTest()` / `stopTest()` **resets limits** so the test measures only code under test.
- Sanity-check with `Limits.getQueries()`, `Limits.getDmlStatements()`, `Limits.getEmailInvocations()` when the test asserts no governor regression:
  ```apex
  Assert.isTrue(Limits.getQueries() < 100, 'SOQL count should stay under 100: ' + Limits.getQueries());
  ```
- Never create more records than production would see. If 5 records exercise the logic, don't insert 200 -- keep the bulk test as its own dedicated method.

---

## 17. CLI Commands

```bash
# Single test class with coverage (development loop)
sf apex run test \
  --class-names CaseServiceTest \
  --target-org <target-env-alias> --code-coverage --result-format human

# Specific methods (fastest fix loop)
sf apex run test \
  --tests CaseServiceTest.shouldCreateCase_WhenInputIsValid \
  --target-org <target-env-alias>

# Full local-tests run with coverage (pre-PR)
sf apex run test \
  --test-level RunLocalTests --target-org <target-env-alias> \
  --code-coverage --result-format json \
  --output-dir ./test-results --wait 30

# Detailed line-by-line coverage
sf apex run test --class-names CaseServiceTest \
  --target-org <target-env-alias> --code-coverage --detailed-coverage

# Check-only deploy gate
sf project deploy start \
  --manifest manifest/package.xml \
  --target-org <target-env-alias> --dry-run \
  --test-level RunLocalTests --wait 60

# Async + poll
sf apex run test --test-level RunLocalTests --target-org <target-env-alias> --async
sf apex get test --test-run-id <runId> --target-org <target-env-alias>

# LWC Jest
npm run test:unit -- --coverage
npx lwc-jest force-app/main/default/lwc/<bundle>/__tests__/<bundle>.test.js --coverage

# Agentforce
sf agent test create  --json --spec <spec.yaml> --api-name <Suite> -o <target-env-alias>
sf agent test run     --json --api-name <Suite> --wait 10 --result-format json -o <target-env-alias>
sf agent test results --json --job-id <runId> --result-format json -o <target-env-alias>
```

---

## 18. Definition of Done (Testing)

- [ ] `TestDataFactory` used for all standard-object setup; no inline hardcoded records
- [ ] AAA / Given-When-Then blocks present in every `@isTest` method
- [ ] Happy-path test with assertions on every observable output
- [ ] Negative test for every validation, exception path, and catch block
- [ ] Bulk test with 200 (or 251) records for every trigger, service, batch, invocable
- [ ] Async test using `Test.startTest()` / `Test.stopTest()` for every Queueable / Batch / `@future` / Scheduled
- [ ] Security test using `System.runAs(restrictedUser)` for every `@AuraEnabled`, `@InvocableMethod`, `@RestResource`
- [ ] `HttpCalloutMock` registered via `Test.setMock(...)` BEFORE `Test.startTest()` for every HTTP path
- [ ] Mock coverage: 2xx, 4xx (400/401/403/404/429), 5xx, `CalloutException`
- [ ] `SeeAllData=false` (the default). Any exception is justified and ticketed
- [ ] Every assertion uses `Assert.*` with a descriptive message argument
- [ ] Coverage >= 75% (platform) and >= 90% (team) for the class(es) under test
- [ ] Jest tests cover data / empty / loading / error / interaction / event states
- [ ] Jest thresholds met (branches >= 75%, lines/functions/statements >= 85%)
- [ ] `sf project deploy start --dry-run --test-level RunLocalTests` passes for the manifest

---

## 19. Common AI Mistakes to Avoid

| Mistake | Description | Correct Approach |
|---|---|---|
| `SeeAllData=true` without justification | Blindly adding SeeAllData without a reason | Use TestDataFactory; add explicit comment and approval if truly needed |
| Coverage without assertions | Writing tests that execute code but never assert anything | Every test method must have at least one `System.assert*` call with a message |
| No bulk test (200 records) | Only testing with one record | Always include a 200-record test for triggers, services, and batches |
| Missing `Test.startTest/stopTest` for async | Async jobs enqueued but never executed in test | Wrap async calls in `Test.startTest()` / `Test.stopTest()` |
| No callout mock | Tests that call HTTP client code without `Test.setMock` | Always implement and register `HttpCalloutMock` before any callout code |
| Hardcoded Salesforce IDs | `AccountId = '0010000000XYZ000AAA'` in test data | Use inserted records and reference their actual `.Id` field |
| Testing only happy path | No negative, bulk, security, or async tests | Cover all scenario types per the Required Test Scenarios table |
| No negative/error test | Missing test for invalid input or exception paths | Always test what happens when things go wrong |
| No security test | Controllers and invocables never tested with restricted users | Always test `@AuraEnabled` and `@InvocableMethod` with a minimum-access user |
| Sharing test data between unrelated methods | Relying on `@TestSetup` for data only one method needs | Create data inline in the test method when it is not shared |
| SOQL in `@TestSetup` with hard-coded criteria | `[SELECT Id FROM Account WHERE Name = 'Acme']` -- breaks if factory changes | Query with variables: `[SELECT Id FROM Account LIMIT 1]` |
| Not cleaning up DOM in Jest tests | Forgetting `afterEach` cleanup in LWC tests | Always include `document.body.removeChild` and `jest.clearAllMocks()` in `afterEach` |
| Asserting on implementation details in Jest | `expect(element._privateField).toBe(...)` | Assert only on rendered DOM and dispatched events |
| Missing `await` in Jest async tests | Test completes before data resolves | Always `await Promise.resolve()` after async operations before asserting |

---

## 20. Empirical Findings & Implementation Notes

When Salesforce's documented approach doesn't work in the target environment, the workaround goes here. Date-stamp every entry.

| # | Date | Documented approach | What actually works | Why / Context |
|---|---|---|---|---|

---

## 21. Official References

- [Apex Testing Introduction](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_testing_introduction.htm)
- [Apex Testing Best Practices](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_testing_best_practices.htm)
- [HttpCalloutMock Interface](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_testing_using_mock_interface.htm)
- [Test.setMock Reference](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_testing_httpcallout.htm)
- [Async Apex Testing](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_testing_tools_async.htm)
- [Stub API (System.StubProvider)](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_testing_stub_api.htm)
- [System.runAs and Sharing in Apex](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_classes_keywords_sharing.htm)
- [LWC Jest Testing Introduction](https://developer.salesforce.com/docs/component-library/documentation/en/lwc/lwc.unit_testing_using_jest_introduction)
- [Flow Testing Trailhead Module](https://trailhead.salesforce.com/content/learn/modules/flow_testing_debugging)
- [Salesforce CLI `apex run test`](https://developer.salesforce.com/docs/atlas.en-us.sfdx_cli_reference.meta/sfdx_cli_reference/cli_reference_apex_commands_unified.htm)
- [Salesforce CLI `agent test`](https://developer.salesforce.com/docs/atlas.en-us.sfdx_cli_reference.meta/sfdx_cli_reference/cli_reference_agent_commands_unified.htm)
- [forcedotcom/sf-skills `generating-apex-test`](https://github.com/forcedotcom/sf-skills/tree/main/skills/generating-apex-test)
- [forcedotcom/sf-skills `running-apex-tests`](https://github.com/forcedotcom/sf-skills/tree/main/skills/running-apex-tests)
- [forcedotcom/sf-skills `testing-agentforce`](https://github.com/forcedotcom/sf-skills/tree/main/skills/testing-agentforce)

---

*Testing Guidelines Canonical Reference | v3.0 | Last verified 2026-05-16*

