# Testing Guidelines

**Version**: 2.0 (April 2026)
**Developer**: Naresh | Senior Salesforce Developer
**Purpose**: Standalone guidelines for all Salesforce testing: Apex unit tests, Flow testing, LWC Jest, callout mocks, and test data patterns. Attach when writing or reviewing any test code.

---

## Table of Contents

1. [Required Agent Output Contract](#required-agent-output-contract)
2. [Apex Test Fundamentals](#apex-test-fundamentals)
3. [Test Data Factory Pattern](#test-data-factory-pattern)
4. [Required Test Scenarios](#required-test-scenarios)
5. [SeeAllData=false Enforcement](#seealldatafalse-enforcement)
6. [Async Tests Pattern](#async-tests-pattern)
7. [Bulk Tests (200 Records) — Mandatory](#bulk-tests-200-records--mandatory)
8. [Negative Tests](#negative-tests)
9. [Security Tests](#security-tests)
10. [Flow Testing / Debugging Strategy](#flow-testing--debugging-strategy)
11. [LWC Jest Tests](#lwc-jest-tests)
12. [Callout Mocks](#callout-mocks)
13. [Test Coverage Policy](#test-coverage-policy)
14. [Deployment Coverage Gates](#deployment-coverage-gates)
15. [Common AI Mistakes to Avoid](#common-ai-mistakes-to-avoid)
16. [Definition of Done (Testing)](#definition-of-done-testing)
17. [Validation Commands](#validation-commands)
18. [Official References](#official-references)

---

## Required Agent Output Contract

Every testing implementation must include all of the following in its response. A test file that is missing any of these elements is incomplete.

### 1. Test Class List and Scenarios Covered
Provide an explicit list:
- Name of every test class created
- For each test class: list of `@isTest` methods and what scenario each method covers (happy path, negative, bulk, async, security)
- Confirmation that each component under test has a corresponding test class

### 2. Data Factory Usage
State:
- Which `TestDataFactory` methods are used in each test class
- Confirmation that no inline record creation bypasses the factory (except for intentional edge-case construction)
- Confirmation that no hardcoded IDs are used anywhere in test code

### 3. Mock Strategy for Callouts
For any component that performs HTTP callouts:
- Name of the `HttpCalloutMock` class(es) used
- Which HTTP status codes are covered by mocks (must include: success, 4xx, 5xx, network timeout)
- Whether `MultiRequestMock` is needed (if multiple endpoints are called in one transaction)
- Confirmation that `Test.setMock` is invoked before `Test.startTest()` in every relevant test method

### 4. Bulk Test Coverage (200 Records)
Confirm:
- Every trigger, service method, and batch class has at least one test that processes exactly 200 records in a single DML operation
- The bulk test asserts on all 200 results (not just one record)
- No governor limit exceptions occur during the bulk test

### 5. Async Test Pattern (startTest/stopTest)
Confirm:
- Every Queueable, Batch, Scheduled, and @future method is tested inside `Test.startTest()` / `Test.stopTest()`
- Assertions are placed AFTER `Test.stopTest()` (because `stopTest()` forces async execution)
- Nested async calls (Queueable chaining) are handled correctly

### 6. Coverage Result After Run
Include:
- The `sf apex run test` command used
- Expected coverage percentage for classes under test
- Any classes that fall below the 85% team target and the plan to improve them

### 7. Validation Commands
Provide the exact CLI commands to:
- Run all local tests
- Run the specific test classes for this component
- Retrieve the coverage report in JSON format
- Run Jest tests for LWC components

---

## Apex Test Fundamentals

### Required Annotations and Structure

```apex
@isTest
private class CaseServiceTest {

    // @TestSetup runs ONCE per test class — data is rolled back after each test method
    // Use for data shared by multiple test methods
    @TestSetup
    static void setupTestData() {
        Account acc = TestDataFactory.createAccount(true);
        TestDataFactory.createCases(5, acc.Id, true);
    }

    @isTest
    static void testCreateCase_HappyPath() {
        // Arrange
        Account acc = [SELECT Id FROM Account LIMIT 1];

        // Act
        Test.startTest();
        Case result = CaseService.createCase(acc.Id, 'Test Subject', 'High');
        Test.stopTest();

        // Assert
        System.assertNotNull(result.Id, 'Case should have been inserted and have an Id');
        System.assertEquals('High', result.Priority, 'Priority should be High as specified');
        System.assertEquals('New', result.Status, 'New case should default to Status = New');
    }
}
```

### Assertion Rules
- ALWAYS use `System.assertEquals(expected, actual, 'descriptive message')` — never bare `assertEquals` without a message
- The message is shown in test failure output — make it describe what was expected and why
- ALWAYS use `System.assertNotNull(value, 'descriptive message')` for non-null checks
- Use `System.assert(condition, 'descriptive message')` for boolean conditions
- Never assert without a message — undescribed failures waste debugging time

```apex
// CORRECT
System.assertEquals('Closed', c.Status, 'Status should be Closed after processing');
System.assertNotNull(c.Id, 'Case should have been inserted and have a valid Id');
System.assert(result.success, 'Integration call should succeed for valid payload');

// WRONG — no message
System.assertEquals('Closed', c.Status);
System.assertNotNull(c.Id);
```

### AAA Pattern — Required in Every Test Method

```apex
@isTest
static void testMethodName_ScenarioDescription() {
    // Arrange — set up data, mocks, inputs
    Account acc = TestDataFactory.createAccount(true);

    // Act — invoke the code under test
    Test.startTest();
    CaseService.processAccount(acc.Id);
    Test.stopTest();

    // Assert — verify the outcome
    Account updated = [SELECT Id, AnnualRevenue FROM Account WHERE Id = :acc.Id];
    System.assertNotNull(updated.AnnualRevenue, 'AnnualRevenue should be populated after processing');
}
```

### Test Naming Convention
Use the format: `test<MethodOrFeature>_<Scenario>`
- `testCreateCase_HappyPath`
- `testCreateCase_NullAccountId_ThrowsException`
- `testCreateCase_BulkOf200Records`
- `testSendNotification_AuthFailure_LogsError`
- `testProcessBatch_200Records_AllCompleted`

### @TestSetup Guidelines
- Use `@TestSetup` for data required by MULTIPLE test methods in the class
- Data created in `@TestSetup` is rolled back and re-created for each test method (isolation guaranteed)
- Do NOT use `@TestSetup` if only one test method needs the data — create inline in that method instead
- `@TestSetup` runs before each test method in the class — there is one setup run per test method execution

---

## Test Data Factory Pattern

### Design Principles
- Single `TestDataFactory` class for the entire org (or one per domain if the org is large)
- Every factory method accepts a `Boolean doInsert` parameter — callers control when DML happens
- Factory methods return the created object(s) — always return `Account`, `List<Case>`, etc.
- Use realistic field values — `Name = 'Test Account'` is fine for isolation; avoid cryptic abbreviations
- Never use hardcoded IDs (e.g., `AccountId = '0010000000XYZ'`) — always use actual inserted record Ids

### Complete TestDataFactory Class

```apex
/**
 * Description: Factory class for creating test data across all test classes.
 * All factory methods accept doInsert parameter to allow bulk DML optimization.
 * Developer: Naresh
 * Title: Senior Salesforce Developer
 * Last Modified: April 2026
 */
@isTest
public class TestDataFactory {

    // ─── Account ───────────────────────────────────────────────────────────────

    public static Account createAccount(Boolean doInsert) {
        Account acc = new Account(
            Name = 'Test Account',
            Type = 'Customer',
            BillingStreet = '123 Test Street',
            BillingCity = 'Toronto',
            BillingState = 'ON',
            BillingPostalCode = 'M5V 1A1',
            BillingCountry = 'Canada',
            Phone = '416-555-0100'
        );
        if (doInsert) insert acc;
        return acc;
    }

    public static List<Account> createAccounts(Integer count, Boolean doInsert) {
        List<Account> accounts = new List<Account>();
        for (Integer i = 0; i < count; i++) {
            accounts.add(new Account(
                Name = 'Test Account ' + i,
                Type = 'Customer'
            ));
        }
        if (doInsert) insert accounts;
        return accounts;
    }

    // ─── Contact ───────────────────────────────────────────────────────────────

    public static Contact createContact(Id accountId, Boolean doInsert) {
        Contact c = new Contact(
            FirstName = 'Test',
            LastName = 'Contact',
            Email = 'testcontact@example.com',
            Phone = '416-555-0200',
            AccountId = accountId
        );
        if (doInsert) insert c;
        return c;
    }

    public static List<Contact> createContacts(Integer count, Id accountId, Boolean doInsert) {
        List<Contact> contacts = new List<Contact>();
        for (Integer i = 0; i < count; i++) {
            contacts.add(new Contact(
                FirstName = 'Test',
                LastName = 'Contact ' + i,
                Email = 'testcontact' + i + '@example.com',
                AccountId = accountId
            ));
        }
        if (doInsert) insert contacts;
        return contacts;
    }

    // ─── Case ──────────────────────────────────────────────────────────────────

    public static Case createCase(Id accountId, Boolean doInsert) {
        Case c = new Case(
            Subject = 'Test Case Subject',
            Description = 'Test case description for unit testing.',
            Status = 'New',
            Priority = 'Medium',
            Origin = 'Email',
            AccountId = accountId
        );
        if (doInsert) insert c;
        return c;
    }

    public static List<Case> createCases(Integer count, Id accountId, Boolean doInsert) {
        List<Case> cases = new List<Case>();
        for (Integer i = 0; i < count; i++) {
            cases.add(new Case(
                Subject = 'Test Case ' + i,
                Description = 'Test case ' + i + ' description.',
                Status = 'New',
                Priority = 'Medium',
                Origin = 'Email',
                AccountId = accountId
            ));
        }
        if (doInsert) insert cases;
        return cases;
    }

    // ─── Opportunity ───────────────────────────────────────────────────────────

    public static Opportunity createOpportunity(Id accountId, Boolean doInsert) {
        Opportunity opp = new Opportunity(
            Name = 'Test Opportunity',
            AccountId = accountId,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30),
            Amount = 10000
        );
        if (doInsert) insert opp;
        return opp;
    }

    // ─── User (for security tests) ─────────────────────────────────────────────

    public static User createMinimumAccessUser(Boolean doInsert) {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Minimum Access - Salesforce' LIMIT 1];
        String uniqueSuffix = String.valueOf(System.currentTimeMillis());
        User u = new User(
            FirstName = 'Test',
            LastName = 'Restricted User',
            Email = 'restricted' + uniqueSuffix + '@test.example.com',
            Username = 'restricted' + uniqueSuffix + '@test.example.com',
            Alias = 'rstd',
            TimeZoneSidKey = 'America/New_York',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = p.Id
        );
        if (doInsert) insert u;
        return u;
    }

    public static User createStandardUser(Boolean doInsert) {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        String uniqueSuffix = String.valueOf(System.currentTimeMillis());
        User u = new User(
            FirstName = 'Test',
            LastName = 'Standard User',
            Email = 'standard' + uniqueSuffix + '@test.example.com',
            Username = 'standard' + uniqueSuffix + '@test.example.com',
            Alias = 'std',
            TimeZoneSidKey = 'America/New_York',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = p.Id
        );
        if (doInsert) insert u;
        return u;
    }

    // ─── Custom Metadata (for config tests) ───────────────────────────────────

    /**
     * Note: Custom Metadata records are org data and visible in test context (SeeAllData not required).
     * If your test requires specific CMDT values that differ from production, use dependency injection
     * or a test-specific CMDT record name.
     */
}
```

### Bulk Factory Usage Pattern
When creating 200 records, build the list without inserting, then insert all at once:

```apex
@isTest
static void testBulk_200Cases() {
    Account acc = TestDataFactory.createAccount(true);

    // Build list without DML (doInsert = false)
    List<Case> cases = TestDataFactory.createCases(200, acc.Id, false);

    // Insert all 200 at once — triggers the CaseTrigger in bulk
    Test.startTest();
    insert cases;
    Test.stopTest();

    // Assert on all 200 records
    List<Case> results = [SELECT Id, Status FROM Case WHERE AccountId = :acc.Id];
    System.assertEquals(200, results.size(), 'All 200 cases should have been inserted');
}
```

---

## Required Test Scenarios

### Mandatory Scenario Coverage Table

| Scenario Type | Description | Required For |
|---|---|---|
| Happy path | Normal, successful execution with valid inputs | All components |
| Negative / error path | Invalid input, missing required fields, violates business rules | All components |
| Bulk — 200 records | Insert or update exactly 200 records in a single DML operation | Triggers, service classes, batch classes, invocable actions |
| Null / empty input | Null objects, empty lists, empty/blank strings | All components |
| Async execution | Queueable, Batch, Scheduled, @future — tested via startTest/stopTest | All async components |
| Security — CRUD/FLS | Verify behavior when calling user lacks object/field permissions | Apex controllers, @AuraEnabled methods, @InvocableMethod |
| Callout mock | HTTP callout tested with mocked response (success and failure) | All classes with Http.send() calls |
| Governor limit safety | Confirm no governor limit exceptions at 200 records | Any code with SOQL, DML, or CPU-intensive logic in loops |
| Record sharing | Verify that `with sharing` behavior is respected | Classes where sharing rules apply |
| Edge cases | Empty list passthrough, already-processed records, concurrent execution patterns | Component-specific |

### Coverage Goal Per Component Type

| Component | Minimum Test Methods |
|---|---|
| Apex Trigger | Happy path insert, happy path update, bulk 200 records, null field handling |
| Service Class | Happy path, each error condition, bulk where applicable |
| Controller (@AuraEnabled) | Happy path, exception handling, security (restricted user), null input |
| HTTP Client | Success (2xx), auth failure (401), server error (5xx), timeout, rate limit (429) |
| Batch Apex | Batch of 1, batch of 200, finish() logic, error in execute() |
| Queueable | Enqueue and execute, async pattern, retry logic |
| Invocable Apex | Happy path, bulk (200 invocations), null input |
| @RestResource | Valid payload, invalid JSON, missing required fields, auth scenarios |

---

## SeeAllData=false Enforcement

### Default Behavior
The `@isTest` annotation automatically isolates test code from org data. Tests cannot see records in the org unless `SeeAllData=true` is explicitly set. **This is the correct default — do not change it.**

### Why SeeAllData=true Is Prohibited
- Tests become dependent on data that may not exist in all environments (sandbox, scratch org, production)
- Data changes in the org can break tests unexpectedly
- Tests are no longer isolated or repeatable
- Code reviews and CI pipelines cannot guarantee consistent results

### The Only Acceptable Exceptions
`SeeAllData=true` may be considered ONLY when:
1. Testing Visualforce pages or Apex code that directly accesses org setup/configuration data that cannot be mocked (e.g., Tax/fiscal year settings)
2. Legacy integrations that relied on org data before the `@isTest` isolation was properly implemented
3. The code under test cannot be refactored without significant risk (documented technical debt)

If `SeeAllData=true` is required:
- Add an inline comment explaining exactly why it is necessary
- Get explicit sign-off from the tech lead or architect
- Document it in the PR description
- Add a tech debt ticket to refactor the code to not require `SeeAllData=true`

```apex
// PROHIBITED — no justification
@isTest(SeeAllData=true)
private class BadTestClass { ... }

// ACCEPTABLE only with documented justification
@isTest(SeeAllData=true)
// REASON: CurrencyType records are not available in test context without SeeAllData.
// This class tests multi-currency conversion and cannot use factory data for CurrencyType.
// Tech Debt: JIRA-1234 — refactor to inject currency data via test helper.
private class CurrencyConversionTestWithJustification { ... }
```

### Access to Custom Metadata
Custom Metadata Type (CMDT) records ARE accessible in test context without `SeeAllData=true`. This is the recommended approach for configuration data.

### Access to Custom Settings
- **Hierarchy Custom Settings**: use `upsertSettings()` in `@TestSetup` to create test-specific values
- **List Custom Settings**: insert in `@TestSetup` like any other sObject

---

## Async Tests Pattern

### The Rule
Any Apex code that runs asynchronously (Queueable, Batch, Scheduled Apex, @future) MUST be tested using the `Test.startTest()` / `Test.stopTest()` block. Calling `Test.stopTest()` forces all pending async operations to execute synchronously within the test context.

### Why This Matters
Without `startTest/stopTest`:
- Queueable jobs are enqueued but never execute within the test — assertions will fail
- Batch jobs are submitted but never execute — no results to assert on
- @future methods are called but their side effects are not visible

### Complete Queueable Test Pattern

```apex
@isTest
static void testQueueableJob_ProcessesCasesSuccessfully() {
    // Arrange
    Account acc = TestDataFactory.createAccount(true);
    List<Case> cases = TestDataFactory.createCases(1, acc.Id, true);
    Set<Id> caseIds = new Map<Id, Case>(cases).keySet();

    // Act — enqueue inside startTest/stopTest to force execution
    Test.startTest();
    System.enqueueJob(new CaseProcessingQueueable(caseIds));
    Test.stopTest(); // Forces the queueable to execute NOW

    // Assert — after stopTest, the queueable has completed
    Case updated = [SELECT Id, Status FROM Case WHERE Id = :cases[0].Id];
    System.assertEquals('Processed', updated.Status,
        'Status should be updated to Processed by the queueable job');
}
```

### Batch Apex Test Pattern

```apex
@isTest
static void testCaseClosingBatch_MarksEligibleCasesClosed() {
    // Arrange
    Account acc = TestDataFactory.createAccount(true);
    List<Case> cases = TestDataFactory.createCases(200, acc.Id, false);
    for (Case c : cases) {
        c.Status = 'Pending Close';
    }
    insert cases;

    // Act
    Test.startTest();
    Database.executeBatch(new CaseClosingBatch(), 200); // Batch size = 200 for bulk test
    Test.stopTest(); // Forces execute() and finish() to run

    // Assert
    Integer closedCount = [SELECT COUNT() FROM Case WHERE Status = 'Closed' AND AccountId = :acc.Id];
    System.assertEquals(200, closedCount,
        'All 200 eligible cases should be closed by the batch');
}
```

### Scheduled Apex Test Pattern

```apex
@isTest
static void testScheduledJob_ExecutesWithoutError() {
    // Arrange
    Account acc = TestDataFactory.createAccount(true);

    // Act
    Test.startTest();
    String jobId = System.schedule(
        'Test Nightly Case Sync',
        '0 0 2 * * ?', // Cron: 2 AM daily
        new NightlyCaseSyncSchedulable()
    );
    Test.stopTest(); // Forces execute() to run

    // Assert
    CronTrigger ct = [SELECT Id, CronExpression, State FROM CronTrigger WHERE Id = :jobId];
    System.assertNotNull(ct, 'Scheduled job should have been created');
}
```

### @future Method Test Pattern

```apex
@isTest
static void testFutureMethod_UpdatesExternalId() {
    // Arrange
    Account acc = TestDataFactory.createAccount(true);

    // Act
    Test.startTest();
    AccountSyncService.syncToExternalSystemAsync(acc.Id); // @future method
    Test.stopTest(); // Forces the @future method to complete

    // Assert
    Account updated = [SELECT Id, External_Id__c FROM Account WHERE Id = :acc.Id];
    System.assertNotNull(updated.External_Id__c,
        'External_Id__c should be populated by the future method');
}
```

### Nested Async (Queueable Chaining)
Salesforce only executes one level of chained Queueables within a test:
```apex
// Only the FIRST enqueued job executes within Test.stopTest()
// If the first job re-enqueues a second job, that second job does NOT execute in the same test
// Test the second job in a separate test method
```

---

## Bulk Tests (200 Records) — Mandatory

### Why 200 Records
Salesforce triggers fire with up to 200 records per batch in a single DML operation. Code that works for one record but fails at 200 is a production defect. Every trigger, service, and batch that processes records MUST have a 200-record test.

### SOQL in Loops — Governor Limit Test
The bulk test is your safety net for catching SOQL/DML inside loops:
- `SOQL inside a for loop` — will fail at 200 records (>100 SOQL queries per transaction)
- `DML inside a for loop` — will fail at 151 records (>150 DML statements per transaction)
- The bulk test catches these at test time, not in production

### Complete Bulk Test Template

```apex
@isTest
static void testBulk_200Records_TriggerProcessesAllWithoutGovernorError() {
    // Arrange
    Account acc = TestDataFactory.createAccount(true);
    // Build list without inserting (doInsert = false) for efficient bulk DML
    List<Case> cases = TestDataFactory.createCases(200, acc.Id, false);

    // Act — single DML for all 200, fires trigger in one batch
    Test.startTest();
    insert cases; // Triggers CaseTrigger with 200 records in Trigger.new
    Test.stopTest();

    // Assert — verify ALL 200 records, not just one
    List<Case> results = [SELECT Id, Status, Priority FROM Case WHERE AccountId = :acc.Id];
    System.assertEquals(200, results.size(),
        'All 200 cases should have been inserted successfully');

    for (Case c : results) {
        System.assertNotEquals(null, c.Status,
            'Status should be populated for all cases — Case Id: ' + c.Id);
    }
}
```

### Bulk Test for Service Classes (without Trigger)

```apex
@isTest
static void testBulk_200CasesProcessed_ServiceHandlesAllRecords() {
    // Arrange
    Account acc = TestDataFactory.createAccount(true);
    List<Case> cases = TestDataFactory.createCases(200, acc.Id, true);
    List<Id> caseIds = new List<Id>(new Map<Id, Case>(cases).keySet());

    // Act
    Test.startTest();
    CaseService.processCases(caseIds);
    Test.stopTest();

    // Assert — check a representative sample and total count
    List<Case> processed = [
        SELECT Id, Status
        FROM Case
        WHERE Id IN :caseIds
        AND Status = 'In Progress'
    ];
    System.assertEquals(200, processed.size(),
        'All 200 cases should have been set to In Progress status');
}
```

### Bulk Test for Batch Apex

```apex
@isTest
static void testBatch_200RecordsInOneBatch_AllProcessed() {
    // Arrange — insert 200 records before the batch runs
    Account acc = TestDataFactory.createAccount(true);
    List<Case> cases = TestDataFactory.createCases(200, acc.Id, false);
    for (Case c : cases) c.Status = 'Pending';
    insert cases;

    // Act — run batch with batch size = 200 to test bulk processing in one execute() call
    Test.startTest();
    Database.executeBatch(new CaseStatusBatch(), 200);
    Test.stopTest();

    // Assert
    Integer updatedCount = [
        SELECT COUNT() FROM Case
        WHERE AccountId = :acc.Id
        AND Status = 'Completed'
    ];
    System.assertEquals(200, updatedCount,
        'Batch should have updated all 200 cases to Completed status');
}
```

---

## Negative Tests

### Purpose
Negative tests verify that the code behaves correctly under invalid or unexpected conditions. They confirm that:
- Appropriate exceptions are thrown with correct types and messages
- Invalid input does not corrupt data
- The system fails gracefully (no orphaned data, no silent failures)

### Pattern: Exception Type Verification

```apex
@isTest
static void testCreateCase_NullSubject_ThrowsInvalidInputException() {
    // Arrange
    Account acc = TestDataFactory.createAccount(true);
    String nullSubject = null;

    // Act + Assert
    Boolean exceptionThrown = false;
    try {
        Test.startTest();
        CaseService.createCase(acc.Id, nullSubject, 'High');
        Test.stopTest();
    } catch (CaseService.InvalidInputException e) {
        exceptionThrown = true;
        System.assert(e.getMessage().contains('subject'),
            'Exception message should mention the subject field requirement');
    }

    System.assert(exceptionThrown,
        'InvalidInputException should be thrown when subject is null');
}
```

### Pattern: Invalid Email Validation

```apex
@isTest
static void testCreateCaseForEmail_InvalidEmail_ThrowsException() {
    // Arrange
    String invalidEmail = 'not-an-email';

    // Act + Assert
    Boolean exceptionThrown = false;
    try {
        CaseService.createCaseForEmail(invalidEmail);
    } catch (CaseService.InvalidInputException e) {
        exceptionThrown = true;
        System.assert(e.getMessage().contains('invalid email'),
            'Exception message should describe the email validation failure');
    }
    System.assert(exceptionThrown,
        'Exception should have been thrown for invalid email address');
}
```

### Pattern: Empty List Input

```apex
@isTest
static void testProcessCases_EmptyList_ReturnsGracefully() {
    // Arrange
    List<Id> emptyCaseIds = new List<Id>();

    // Act — should not throw, should handle gracefully
    Test.startTest();
    CaseService.processCases(emptyCaseIds);
    Test.stopTest();

    // Assert — no exception was thrown, no records were modified
    Integer caseCount = [SELECT COUNT() FROM Case];
    System.assertEquals(0, caseCount,
        'No cases should exist or be modified when an empty list is provided');
}
```

### Pattern: Duplicate External ID

```apex
@isTest
static void testUpsertCase_DuplicateExternalId_UpdatesExistingRecord() {
    // Arrange — create case with External_Id__c already set
    Account acc = TestDataFactory.createAccount(true);
    Case existing = TestDataFactory.createCase(acc.Id, false);
    existing.External_Id__c = 'EXT-DUPLICATE-001';
    existing.Subject = 'Original Subject';
    insert existing;

    // Act — upsert with same External_Id__c
    Case duplicate = new Case(
        External_Id__c = 'EXT-DUPLICATE-001',
        Subject = 'Updated Subject',
        AccountId = acc.Id
    );
    Test.startTest();
    Database.upsert(duplicate, Case.External_Id__c, false);
    Test.stopTest();

    // Assert — only one record exists, original was updated
    List<Case> results = [SELECT Id, Subject FROM Case WHERE External_Id__c = 'EXT-DUPLICATE-001'];
    System.assertEquals(1, results.size(),
        'Exactly one case should exist for the External_Id__c — no duplicate should be created');
    System.assertEquals('Updated Subject', results[0].Subject,
        'Existing case subject should have been updated, not a new case created');
}
```

---

## Security Tests

### Purpose
Security tests verify that access-controlled Apex code enforces CRUD and FLS correctly when called by a user without the required permissions. Use `System.runAs(user)` to impersonate a restricted user.

### Pattern: CRUD — No Object Access

```apex
@isTest
static void testGetCases_RestrictedUser_ThrowsAuraHandledException() {
    // Arrange — create user with no Case access
    Profile p = [SELECT Id FROM Profile WHERE Name = 'Minimum Access - Salesforce' LIMIT 1];
    User restrictedUser = TestDataFactory.createMinimumAccessUser(true);

    // Act + Assert — run as restricted user
    System.runAs(restrictedUser) {
        Boolean exceptionThrown = false;
        try {
            CaseDashboardController.getCases();
        } catch (AuraHandledException e) {
            exceptionThrown = true;
            // AuraHandledException message is sanitized — just verify it was thrown
        }
        System.assert(exceptionThrown,
            'AuraHandledException should be thrown when user has no Case read access');
    }
}
```

### Pattern: FLS — No Field Access

```apex
@isTest
static void testGetCaseDetails_NoFieldAccess_FieldIsBlank() {
    // Arrange
    Account acc = TestDataFactory.createAccount(true);
    Case c = TestDataFactory.createCase(acc.Id, true);
    User standardUser = TestDataFactory.createStandardUser(true);
    // Note: In a real test, you would remove FLS access via Permission Set assignment
    // This pattern shows the System.runAs structure

    // Act
    System.runAs(standardUser) {
        // If the class uses WITH SECURITY_ENFORCED or stripInaccessible,
        // fields the user cannot read should be blank in the result
        Case result = CaseDashboardController.getCaseDetail(c.Id);
        // Assert based on what the restricted user should/should not see
        // Specific assertions depend on which fields are restricted
    }
}
```

### Pattern: Complete Security Test with runAs

```apex
@isTest
static void testDeleteCase_RestrictedUser_ThrowsSecurityException() {
    // Arrange
    Account acc = TestDataFactory.createAccount(true);
    Case c = TestDataFactory.createCase(acc.Id, true);
    User restrictedUser = TestDataFactory.createMinimumAccessUser(true);

    // Act + Assert
    System.runAs(restrictedUser) {
        Boolean securityExceptionThrown = false;
        try {
            CaseService.deleteCase(c.Id);
        } catch (CaseService.InsufficientAccessException e) {
            securityExceptionThrown = true;
            System.assert(e.getMessage().contains('delete'),
                'Exception should indicate lack of delete permission');
        } catch (DmlException e) {
            // DmlException is also acceptable if the class uses Database.delete without security check
            // (though the class SHOULD use with sharing / CRUD check)
            securityExceptionThrown = true;
        }
        System.assert(securityExceptionThrown,
            'A security exception should be thrown when restricted user attempts to delete a Case');
    }
}
```

### CRUD/FLS Check Implementation Reference
When implementing access control in Apex classes (what the security tests validate):

```apex
// Check object CRUD before DML
if (!Schema.sObjectType.Case.isCreateable()) {
    throw new InsufficientAccessException('Insufficient access to create Case records.');
}

// Check field-level security before reading sensitive fields
if (!Schema.sObjectType.Case.fields.SSN__c.isAccessible()) {
    throw new InsufficientAccessException('Insufficient access to read Case SSN field.');
}

// Or use WITH SECURITY_ENFORCED in SOQL (throws QueryException if FLS not met)
List<Case> cases = [SELECT Id, Subject, SSN__c FROM Case WITH SECURITY_ENFORCED LIMIT 100];

// Or use Security.stripInaccessible for bulk field stripping
SObjectAccessDecision decision = Security.stripInaccessible(
    AccessType.READABLE,
    cases
);
List<Case> accessibleCases = (List<Case>) decision.getRecords();
```

---

## Flow Testing / Debugging Strategy

### Apex Unit Test as Flow Test
Salesforce Flows do not have a standalone unit test framework. Test Flows by writing an Apex test that:
1. Creates the triggering record (or updates it to the condition that triggers the Flow)
2. Verifies the Flow's expected outcome (related record created, field updated, email sent, etc.)

```apex
@isTest
static void testCaseEscalationFlow_EscalatesHighPriorityCase() {
    // Arrange — create a Case that will trigger the escalation Flow
    Account acc = TestDataFactory.createAccount(true);
    Case c = new Case(
        Subject = 'Critical Issue',
        Status = 'New',
        Priority = 'High',
        AccountId = acc.Id
    );

    // Act — insert the Case, which triggers the Record-Triggered Flow
    Test.startTest();
    insert c;
    Test.stopTest();

    // Assert — verify the Flow created the expected follow-up task
    List<Task> tasks = [SELECT Id, Subject, WhatId FROM Task WHERE WhatId = :c.Id];
    System.assertEquals(1, tasks.size(),
        'Escalation Flow should have created one follow-up task for high priority case');
    System.assert(tasks[0].Subject.containsIgnoreCase('escalate'),
        'Task subject should indicate escalation');
}
```

### Testing Flows that Call Invocable Apex
If the Flow calls an Invocable Apex action:
1. Test the Invocable Apex class directly in its own test (for unit coverage and logic verification)
2. Test the Flow indirectly via the trigger-and-assert pattern above (for integration verification)

### Flow Debug (Interactive)
For runtime debugging in development/sandbox:
1. Open the Flow in Flow Builder
2. Click **Debug** (top-right)
3. Select **Run as another user** if testing sharing behavior
4. Provide input variable values
5. Step through the Flow elements to see which path is taken and inspect variable values

### Fault Path Testing
To test the Flow fault path (when an Invocable Apex action throws an exception):
1. Create a test Apex class that implements the Invocable interface and throws an exception for a specific input
2. Deploy to sandbox
3. Run the Flow in debug mode with the input that triggers the exception
4. Verify the fault connector path executes and the error is logged correctly

### Flow Coverage in Deployments
Salesforce counts Flow coverage when test code triggers the Flow. If your deployment includes a Flow and tests trigger it, the coverage counts. Verify that at least one test covers each Flow path (main path and fault path).

---

## LWC Jest Tests

### Project Setup

```json
// package.json
{
  "scripts": {
    "test:unit": "lwc-jest --coverage",
    "test:unit:watch": "lwc-jest --watch",
    "test:unit:debug": "lwc-jest --debug"
  },
  "jest": {
    "testPathPattern": "force-app/.+/__tests__/.+\\.test\\.js",
    "modulePathIgnorePatterns": ["<rootDir>/.localdevserver"],
    "coverageThreshold": {
      "global": {
        "branches": 75,
        "functions": 85,
        "lines": 85,
        "statements": 85
      }
    }
  }
}
```

### File Structure

```
force-app/main/default/lwc/
└── caseDashboardContainer/
    ├── caseDashboardContainer.html
    ├── caseDashboardContainer.js
    ├── caseDashboardContainer.js-meta.xml
    └── __tests__/
        └── caseDashboardContainer.test.js
```

### Complete LWC Jest Test Template

```js
import { createElement } from 'lwc';
import CaseDashboardContainer from 'c/caseDashboardContainer';
import getCases from '@salesforce/apex/CaseDashboardController.getCases';

// Mock data
const mockGetCasesSuccess = [
    { Id: '5000000000000001AAA', Subject: 'Test Case 1', Status: 'New', Priority: 'High' },
    { Id: '5000000000000002AAA', Subject: 'Test Case 2', Status: 'In Progress', Priority: 'Medium' }
];

const mockGetCasesEmpty = [];

// Mock the Apex wire adapter
jest.mock(
    '@salesforce/apex/CaseDashboardController.getCases',
    () => ({ default: jest.fn() }),
    { virtual: true }
);

describe('c-case-dashboard-container', () => {

    // Clean up DOM after each test to prevent test pollution
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.clearAllMocks();
    });

    // ─── Render States ────────────────────────────────────────────────────────

    it('renders case list when data is available', async () => {
        // Arrange
        getCases.mockResolvedValue(mockGetCasesSuccess);
        const element = createElement('c-case-dashboard-container', {
            is: CaseDashboardContainer
        });

        // Act
        document.body.appendChild(element);
        await Promise.resolve(); // Wait for initial render
        await Promise.resolve(); // Wait for async data resolution

        // Assert
        const items = element.shadowRoot.querySelectorAll('c-case-card');
        expect(items.length).toBe(2);
        expect(items[0].getAttribute('data-id')).toBe('5000000000000001AAA');
    });

    it('renders empty state when no cases are returned', async () => {
        // Arrange
        getCases.mockResolvedValue(mockGetCasesEmpty);
        const element = createElement('c-case-dashboard-container', {
            is: CaseDashboardContainer
        });

        // Act
        document.body.appendChild(element);
        await Promise.resolve();
        await Promise.resolve();

        // Assert
        const emptyState = element.shadowRoot.querySelector('p.empty-state');
        expect(emptyState).not.toBeNull();
        expect(emptyState.textContent).toContain('No cases found');

        const items = element.shadowRoot.querySelectorAll('c-case-card');
        expect(items.length).toBe(0);
    });

    it('shows loading spinner while data is being fetched', async () => {
        // Arrange — do not resolve the promise yet
        let resolvePromise;
        getCases.mockReturnValue(new Promise(resolve => { resolvePromise = resolve; }));
        const element = createElement('c-case-dashboard-container', {
            is: CaseDashboardContainer
        });

        // Act
        document.body.appendChild(element);
        await Promise.resolve();

        // Assert — spinner should be visible before data resolves
        const spinner = element.shadowRoot.querySelector('lightning-spinner');
        expect(spinner).not.toBeNull();

        // Resolve and verify spinner disappears
        resolvePromise(mockGetCasesSuccess);
        await Promise.resolve();
        await Promise.resolve();
        const spinnerAfter = element.shadowRoot.querySelector('lightning-spinner');
        expect(spinnerAfter).toBeNull();
    });

    it('shows error state when API call fails', async () => {
        // Arrange
        getCases.mockRejectedValue({ body: { message: 'An unexpected error occurred' }, status: 500 });
        const element = createElement('c-case-dashboard-container', {
            is: CaseDashboardContainer
        });

        // Act
        document.body.appendChild(element);
        await Promise.resolve();
        await Promise.resolve();

        // Assert
        const errorDisplay = element.shadowRoot.querySelector('c-error-display');
        expect(errorDisplay).not.toBeNull();

        const items = element.shadowRoot.querySelectorAll('c-case-card');
        expect(items.length).toBe(0);
    });

    // ─── Event Handling ───────────────────────────────────────────────────────

    it('dispatches caseselected event when a case card is selected', async () => {
        // Arrange
        getCases.mockResolvedValue(mockGetCasesSuccess);
        const element = createElement('c-case-dashboard-container', {
            is: CaseDashboardContainer
        });
        document.body.appendChild(element);
        await Promise.resolve();
        await Promise.resolve();

        // Set up event listener
        const caseSelectedHandler = jest.fn();
        element.addEventListener('caseselected', caseSelectedHandler);

        // Act — simulate child c-case-card dispatching the event
        const caseCard = element.shadowRoot.querySelector('c-case-card');
        caseCard.dispatchEvent(new CustomEvent('caseselected', {
            detail: { caseId: '5000000000000001AAA' },
            bubbles: true,
            composed: true
        }));

        // Assert
        expect(caseSelectedHandler).toHaveBeenCalledTimes(1);
        expect(caseSelectedHandler.mock.calls[0][0].detail.caseId)
            .toBe('5000000000000001AAA');
    });

    it('calls refresh when refresh button is clicked', async () => {
        // Arrange
        getCases.mockResolvedValue(mockGetCasesSuccess);
        const element = createElement('c-case-dashboard-container', {
            is: CaseDashboardContainer
        });
        document.body.appendChild(element);
        await Promise.resolve();
        await Promise.resolve();

        // Act
        const refreshButton = element.shadowRoot.querySelector('button.refresh-button');
        refreshButton.click();
        await Promise.resolve();

        // Assert — getCases should have been called again
        expect(getCases).toHaveBeenCalledTimes(2);
    });

    // ─── Accessibility ────────────────────────────────────────────────────────

    it('renders with accessible role for the container', async () => {
        // Arrange
        getCases.mockResolvedValue(mockGetCasesSuccess);
        const element = createElement('c-case-dashboard-container', {
            is: CaseDashboardContainer
        });

        // Act
        document.body.appendChild(element);
        await Promise.resolve();
        await Promise.resolve();

        // Assert
        const container = element.shadowRoot.querySelector('div[role="region"]');
        expect(container).not.toBeNull();
        expect(container.getAttribute('aria-label')).toBeTruthy();
    });
});
```

### Wire Adapter Testing (Alternative Pattern)

```js
import { registerApexTestWireAdapter } from '@salesforce/sfdx-lwc-jest';
import getCases from '@salesforce/apex/CaseDashboardController.getCases';

// For wire adapters (not imperative calls), use registerApexTestWireAdapter
const getCasesAdapter = registerApexTestWireAdapter(getCases);

it('handles wire data', async () => {
    const element = createElement('c-case-dashboard-container', { is: CaseDashboardContainer });
    document.body.appendChild(element);

    // Push data to the wire adapter
    getCasesAdapter.emit(mockGetCasesSuccess);
    await Promise.resolve();

    // Assert
    const items = element.shadowRoot.querySelectorAll('c-case-card');
    expect(items.length).toBe(2);
});

it('handles wire error', async () => {
    const element = createElement('c-case-dashboard-container', { is: CaseDashboardContainer });
    document.body.appendChild(element);

    // Push an error to the wire adapter
    getCasesAdapter.emitError({ body: { message: 'Wire error' } });
    await Promise.resolve();

    // Assert error state
    const error = element.shadowRoot.querySelector('c-error-display');
    expect(error).not.toBeNull();
});
```

### What to Test in Every LWC Component

| Test Category | What to Cover |
|---|---|
| Initial render state | Component renders without errors with default/null data |
| Data success state | Component renders correctly when API returns data |
| Empty data state | Component renders empty state message when API returns empty list |
| Loading state | Spinner or loading indicator is visible during async call |
| Error state | Error display is shown when API call rejects |
| User interactions | Button clicks, form input changes, selection events dispatch correctly |
| Event contracts | Custom events are dispatched with correct `detail` payload |
| Conditional rendering | `if:true` / `if:false` conditions render correctly |
| Accessibility | ARIA roles, labels, and landmarks are present |

---

## Callout Mocks

### The Rule
Every test method that invokes code containing `new Http().send(req)` — directly or indirectly — MUST register a mock via `Test.setMock(HttpCalloutMock.class, mockInstance)` BEFORE calling `Test.startTest()`. Without a mock, Salesforce throws `System.CalloutException: You have uncommitted work pending`.

### Single Endpoint Mock Template

```apex
@isTest
public class ExternalCaseApiMock implements HttpCalloutMock {

    private final Integer statusCode;
    private final String body;

    public ExternalCaseApiMock(Integer statusCode, String body) {
        this.statusCode = statusCode;
        this.body = body;
    }

    public HTTPResponse respond(HTTPRequest req) {
        HttpResponse res = new HttpResponse();
        res.setStatusCode(statusCode);
        res.setBody(body);
        res.setHeader('Content-Type', 'application/json');
        return res;
    }
}
```

### Multi-Endpoint Mock Template

```apex
@isTest
public class MultiRequestMock implements HttpCalloutMock {

    private final Map<String, HttpCalloutMock> mocksByEndpoint;

    public MultiRequestMock(Map<String, HttpCalloutMock> mocksByEndpoint) {
        this.mocksByEndpoint = mocksByEndpoint;
    }

    public HTTPResponse respond(HTTPRequest req) {
        String endpoint = req.getEndpoint();
        for (String urlFragment : mocksByEndpoint.keySet()) {
            if (endpoint.contains(urlFragment)) {
                return mocksByEndpoint.get(urlFragment).respond(req);
            }
        }
        // Fail the test explicitly if no mock is configured for this endpoint
        HttpResponse res = new HttpResponse();
        res.setStatusCode(500);
        res.setBody('{"error":"No mock configured for endpoint: ' + endpoint + '"}');
        return res;
    }
}
```

### Using Multi-Endpoint Mock

```apex
@isTest
static void testOrchestrationService_CallsBothApis() {
    // Arrange
    Map<String, HttpCalloutMock> mocks = new Map<String, HttpCalloutMock>{
        '/v1/cases'   => new ExternalCaseApiMock(201, '{"id":"EXT-001"}'),
        '/v1/accounts' => new ExternalCaseApiMock(200, '{"id":"ACC-001"}')
    };
    Test.setMock(HttpCalloutMock.class, new MultiRequestMock(mocks));

    // Act
    Test.startTest();
    OrchestrationService.syncCaseWithAccount('ACC-001', 'Case Subject');
    Test.stopTest();

    // Assert
    Case c = [SELECT Id, External_Id__c FROM Case WHERE External_Id__c = 'EXT-001' LIMIT 1];
    System.assertNotNull(c, 'Case should have been created with external ID from mock response');
}
```

### Mock Response Coverage Requirements
Every HTTP client class must be tested with ALL of these mock responses:

| Mock Scenario | Status Code | Test Purpose |
|---|---|---|
| Success | 200 or 201 | Happy path — data is processed correctly |
| Bad request | 400 | Permanent failure — no retry, logged correctly |
| Auth failure | 401 | Auth failure — ops alert triggered, `isAuthFailure = true` |
| Forbidden | 403 | Auth/permissions failure — same handling as 401 |
| Not found | 404 | Permanent failure — logged, no retry |
| Rate limited | 429 | Transient — `isRetryable = true` |
| Server error | 500 | Transient — `isRetryable = true` |
| Timeout | CalloutException | Network failure — `IntegrationException` thrown |

---

## Test Coverage Policy

### Salesforce Platform Minimum
- **75% overall Apex code coverage** is required to deploy to production
- If overall coverage drops below 75%, the deployment is BLOCKED by the Salesforce platform
- This is a hard limit — it cannot be bypassed

### Team Policy
- **Target: ≥ 85% meaningful coverage** — coverage with assertions, not just execution
- Coverage without any assertions is not meaningful testing; it is execution inflation
- Every new Apex class must meet the 85% target before merging to main

### What Coverage Counts
- Lines of code executed by test methods count toward coverage
- Coverage is calculated per class
- Test classes, interfaces, abstract classes, and `@TestSetup` methods are excluded from coverage calculation

### What Coverage Does NOT Count
- Coverage without assertions does not prove correctness — it just proves the code runs
- Lines inside catch blocks that are never triggered by a negative test are not covered
- Private methods that are only reachable through public methods need the public method tested for coverage

### Checking Coverage Per Class

```bash
# Run all local tests with coverage
sf apex run test \
  --test-level RunLocalTests \
  --target-org <alias> \
  --code-coverage \
  --result-format json \
  --wait 10 \
  --output-dir coverage/

# Run specific classes
sf apex run test \
  --class-names ExternalCaseApiClientTest,CaseServiceTest \
  --target-org <alias> \
  --code-coverage \
  --result-format human \
  --wait 10
```

### Coverage Anti-Patterns to Avoid

```apex
// WRONG: Coverage without assertion — this executes lines but proves nothing
@isTest
static void testCoverageOnly() {
    Account acc = TestDataFactory.createAccount(true);
    CaseService.createCase(acc.Id, 'Subject', 'High');
    // No assertions — this is coverage inflation, not testing
}

// CORRECT: Coverage with assertions
@isTest
static void testCreateCase_HappyPath() {
    Account acc = TestDataFactory.createAccount(true);
    Case result = CaseService.createCase(acc.Id, 'Subject', 'High');
    System.assertNotNull(result.Id, 'Case should be inserted and have an Id');
    System.assertEquals('High', result.Priority, 'Priority should match input');
}
```

---

## Deployment Coverage Gates

### Pre-Deployment Validation
Always run a check-only deployment before the actual deployment to verify:
- All tests pass
- Coverage is ≥ 75% (Salesforce minimum)
- No compilation errors

```bash
sf project deploy start \
  --manifest manifest/package.xml \
  --target-org <alias> \
  --check-only \
  --test-level RunLocalTests \
  --wait 60
```

### If Coverage Drops Below 75%
The deployment will be blocked with an error. Resolution:
1. Check the coverage report to identify which class(es) dropped coverage
2. Add missing test scenarios — especially negative tests, bulk tests, and error path tests
3. Do NOT add empty/assertion-free test methods to inflate coverage — this is technical debt that hides untested code
4. Re-run the check-only deploy after adding tests

### Test Level Options for Deployment

| Option | Description | Use When |
|---|---|---|
| `RunLocalTests` | Runs all Apex tests in the org except from managed packages | Standard deployment to production |
| `RunSpecifiedTests` | Runs only the test classes you specify | Targeted deployment when you know exactly which tests cover the deployed classes |
| `RunAllTestsInOrg` | Runs all tests including managed package tests | Full regression; use sparingly — slow |
| `NoTestRun` | Skips tests entirely | Development sandboxes ONLY — never for production |

### CI/CD Integration
In your CI pipeline:
1. Run `sf project deploy start --check-only --test-level RunLocalTests` on every PR
2. Fail the pipeline if the check-only deploy fails
3. Parse the coverage report and fail if any new class is below 85%
4. Generate a coverage report artifact for review

---

## Common AI Mistakes to Avoid

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
| SOQL in `@TestSetup` with hard-coded criteria | `[SELECT Id FROM Account WHERE Name = 'Acme']` — breaks if factory changes | Query with variables: `[SELECT Id FROM Account LIMIT 1]` |
| Not cleaning up DOM in Jest tests | Forgetting `afterEach` cleanup in LWC tests | Always include `document.body.removeChild` and `jest.clearAllMocks()` in `afterEach` |
| Asserting on implementation details in Jest | `expect(element._privateField).toBe(...)` | Assert only on rendered DOM and dispatched events |
| Missing `await` in Jest async tests | Test completes before data resolves | Always `await Promise.resolve()` after async operations before asserting |

---

## Definition of Done (Testing)

A feature or bug fix is considered fully tested and ready for production only when ALL of the following are checked:

- [ ] `TestDataFactory` used for ALL test data — no inline hardcoded record construction for standard objects
- [ ] Happy path test implemented with assertions on every key output
- [ ] Negative / error test implemented for every validation and exception path
- [ ] Bulk test implemented with exactly 200 records for all trigger, service, and batch code
- [ ] Async test implemented using `Test.startTest()` / `Test.stopTest()` for all Queueable, Batch, Scheduled, @future code
- [ ] Security test implemented for all `@AuraEnabled`, `@InvocableMethod`, and `@RestResource` endpoints
- [ ] `HttpCalloutMock` registered via `Test.setMock` for all HTTP callout paths
- [ ] Mock coverage includes: 2xx success, 4xx error, 5xx error, network timeout / `CalloutException`
- [ ] `SeeAllData=false` (default) — any exception is documented with justification and approval
- [ ] All assertions include a descriptive message as the third argument
- [ ] Apex test coverage ≥ 75% (Salesforce platform minimum) — deployment will not proceed below this
- [ ] Apex test coverage ≥ 85% (team target) — aim for this in all new code
- [ ] Jest tests written for all LWC components covering: data state, empty state, loading state, error state, user events, custom event dispatching
- [ ] Jest coverage meets configured thresholds (branches ≥ 75%, lines/functions/statements ≥ 85%)
- [ ] Check-only deployment validated: `sf project deploy start --check-only --test-level RunLocalTests`

---

## Validation Commands

```bash
# Run all local tests with human-readable output
sf apex run test \
  --test-level RunLocalTests \
  --target-org <alias> \
  --result-format human \
  --wait 10

# Run specific test class(es)
sf apex run test \
  --class-names CaseServiceTest,ExternalCaseApiClientTest \
  --target-org <alias> \
  --result-format human \
  --wait 10

# Run tests with code coverage report (JSON output for parsing)
sf apex run test \
  --test-level RunLocalTests \
  --target-org <alias> \
  --code-coverage \
  --result-format json \
  --wait 10 \
  --output-dir coverage/

# Check-only deploy with all local tests (pre-deployment validation)
sf project deploy start \
  --manifest manifest/package.xml \
  --target-org <alias> \
  --check-only \
  --test-level RunLocalTests \
  --wait 60

# Run Jest tests with coverage report
npm run test:unit -- --coverage

# Run a specific Jest test file
npx lwc-jest force-app/main/default/lwc/caseDashboardContainer/__tests__/caseDashboardContainer.test.js \
  --coverage

# Watch mode for Jest during active development
npm run test:unit:watch

# Retrieve test results for a specific async test run ID
sf apex get test --test-run-id <testRunId> --target-org <alias> --result-format human
```

---

## Official References

- Apex Testing Introduction: https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_testing_introduction.htm
- HttpCalloutMock Interface: https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_testing_using_mock_interface.htm
- LWC Jest Testing Introduction: https://developer.salesforce.com/docs/component-library/documentation/en/lwc/lwc.unit_testing_using_jest_introduction
- Apex Testing Trailhead Module: https://trailhead.salesforce.com/content/learn/modules/apex_testing
- Test.setMock Reference: https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_testing_httpcallout.htm
- Async Apex Testing: https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_testing_tools_async.htm
- Security and Sharing in Apex: https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_classes_keywords_sharing.htm
- Flow Testing Trailhead: https://trailhead.salesforce.com/content/learn/modules/flow_testing_debugging
- Salesforce CLI Apex Run Test: https://developer.salesforce.com/docs/atlas.en-us.sfdx_cli_reference.meta/sfdx_cli_reference/cli_reference_apex_commands_unified.htm
