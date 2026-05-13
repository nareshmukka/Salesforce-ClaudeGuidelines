# Trigger Development Guidelines

**Version**: 2.0 (April 2026)
**Developer**: Naresh | Senior Salesforce Developer
**Purpose**: Standalone guidelines for Apex Trigger development. Attach this file when writing, reviewing, or refactoring any Salesforce Trigger or trigger handler.

---

## Table of Contents

1. [Required Agent Output Contract](#1-required-agent-output-contract)
2. [One Trigger Per Object — Mandatory Rule](#2-one-trigger-per-object--mandatory-rule)
3. [Trigger Handler Pattern](#3-trigger-handler-pattern)
4. [Context-Specific Methods](#4-context-specific-methods)
5. [Recursion Guards](#5-recursion-guards)
6. [Idempotency](#6-idempotency)
7. [Change Detection Pattern](#7-change-detection-pattern)
8. [Trigger + Flow Coexistence](#8-trigger--flow-coexistence)
9. [Before vs After Decision Guide](#9-before-vs-after-decision-guide)
10. [Delete / Undelete Handling](#10-delete--undelete-handling)
11. [Bulk Safety](#11-bulk-safety)
12. [Testing 200 Records](#12-testing-200-records)
13. [Common AI Mistakes to Avoid](#13-common-ai-mistakes-to-avoid)
14. [Definition of Done](#14-definition-of-done)
15. [Validation Commands](#15-validation-commands)
16. [Official References](#16-official-references)

---

## 1. Required Agent Output Contract

Every trigger implementation response MUST include ALL of the following sections before any code is generated. This ensures the developer can review scope, security posture, recursion strategy, and rollback plan before accepting the changes.

### 1.1 Plan
- State which object the trigger operates on (e.g., `Case`)
- List all trigger contexts being implemented (e.g., `before insert`, `before update`, `after insert`)
- List all contexts being explicitly excluded and why (e.g., `after undelete — not applicable to this use case`)
- Describe what the trigger does in plain language

### 1.2 Files to Create / Modify
Explicit list with file path, action (create / modify), and one-line purpose:
```
force-app/main/default/triggers/CaseTrigger.trigger       — CREATE: thin trigger entry point for Case
force-app/main/default/classes/CaseTriggerHandler.cls     — CREATE: routes trigger events to service layer
force-app/main/default/classes/CaseService.cls            — MODIFY: add onBeforeInsert, onAfterInsert methods
force-app/main/default/classes/CaseServiceTest.cls        — MODIFY: add bulk trigger test scenarios
```

### 1.3 Security Notes
- Declare sharing keyword chosen for the handler class and justification
- State which methods enforce CRUD/FLS (triggered via service layer, with USER_MODE queries)
- Identify if any `without sharing` is used and why

### 1.4 Recursion Guard Strategy
- State which recursion guard mechanism will be used (static boolean, static Set<Id>, or both)
- Explain why this approach is sufficient for this object's automation landscape
- Document any known Flow + Trigger interactions on this object that require extra care

### 1.5 Test Strategy
Enumerate all test scenarios:
- Bulk insert (200 records)
- Bulk update (200 records) with change detection
- Single record happy path
- Negative / validation error path
- All relevant trigger contexts (insert, update, delete, undelete as applicable)
- Recursion guard test (verify no infinite loop)

### 1.6 Validation Commands
```bash
sf project deploy start --manifest manifest/package.xml --target-org <alias> --check-only --test-level RunLocalTests --wait 60
sf apex run test --class-names CaseServiceTest --target-org <alias> --result-format human
```

### 1.7 Rollback Notes
- State whether an existing trigger is being modified (and what the prior state was)
- Identify any metadata dependencies (custom fields, custom objects, permission sets) needed before deployment
- Confirm whether a previous version of the handler or service is preserved

---

## 2. One Trigger Per Object — Mandatory Rule

**There MUST be exactly ONE Apex trigger per Salesforce object. No exceptions.**

### 2.1 Why This Rule Exists

When multiple triggers exist for the same object, Salesforce does NOT guarantee the order of execution between them. This leads to:
- Non-deterministic behavior that is nearly impossible to test
- Race conditions where one trigger undoes another's work
- Debugging nightmares in production environments
- Inconsistent behavior between sandbox refreshes

### 2.2 The Correct Approach

One trigger file. One handler class. All contexts handled within the same handler. New requirements extend the existing handler — they do NOT create a second trigger file.

```
CaseTrigger.trigger              ← ONE trigger file, never a second one
CaseTriggerHandler.cls           ← Routes all contexts via switch statement
CaseService.cls                  ← All business logic lives here
```

### 2.3 How to Check for Existing Triggers Before Creating a New One

Always retrieve first:

```bash
# Retrieve existing trigger for the object
sf project retrieve start \
  --metadata "ApexTrigger:CaseTrigger" \
  --target-org <alias>

# List all triggers in the org (useful for audit)
sf data query \
  --query "SELECT Name, TableEnumOrId, Status FROM ApexTrigger ORDER BY TableEnumOrId" \
  --target-org <alias> \
  --result-format human
```

If a trigger already exists for the object:
1. Retrieve the existing trigger and handler
2. Extend the existing handler with the new method
3. Add the new context to the switch statement if it is not already there
4. Do NOT create a second trigger file

### 2.4 Enforcement

If an AI agent proposes creating a second trigger for an object that already has one, **reject the output immediately** and instruct the agent to extend the existing handler instead.

---

## 3. Trigger Handler Pattern

The trigger handler pattern separates the trigger file (which cannot be unit-tested in isolation) from the handler class (which can), and delegates all business logic to the service layer (which is fully testable).

### 3.1 Architecture

```
CaseTrigger.trigger
    └── CaseTriggerHandler.cls (routes by context; owns recursion guard)
            └── CaseService.cls (owns all business logic and DML)
                    ├── CaseSelector.cls (all SOQL for Case)
                    └── CaseDomain.cls (all validation and derivation for Case)
```

### 3.2 Complete Implementation

**Trigger file — thin; no logic whatsoever:**

```apex
trigger CaseTrigger on Case (
    before insert,
    before update,
    before delete,
    after insert,
    after update,
    after delete,
    after undelete
) {
    CaseTriggerHandler.run(
        Trigger.operationType,
        Trigger.new,
        Trigger.newMap,
        Trigger.old,
        Trigger.oldMap
    );
}
```

**Handler class — routes by context; owns recursion guard:**

```apex
/**
 * Description: Handler for CaseTrigger — routes execution to service layer by operation type.
 *              Contains recursion guard to prevent re-entrant trigger execution.
 * Developer: Naresh
 * Title: Senior Salesforce Developer
 */
public with sharing class CaseTriggerHandler {

    // Recursion guard: prevents re-entrant trigger execution within the same transaction
    private static Boolean isRunning = false;

    /**
     * Description: Main entry point called by CaseTrigger.
     *              Routes each trigger operation type to the appropriate service method.
     * @param op      The trigger operation type (BEFORE_INSERT, AFTER_UPDATE, etc.)
     * @param newList Trigger.new — records in their new state (null for delete contexts)
     * @param newMap  Trigger.newMap — Id-to-new-record map (null for before insert and delete)
     * @param oldList Trigger.old — records in their prior state (null for insert contexts)
     * @param oldMap  Trigger.oldMap — Id-to-old-record map (null for insert contexts)
     */
    public static void run(
        System.TriggerOperation op,
        List<Case>    newList,
        Map<Id, Case> newMap,
        List<Case>    oldList,
        Map<Id, Case> oldMap
    ) {
        if (isRunning) return;  // Guard: exit immediately if we are already inside a trigger invocation

        isRunning = true;
        try {
            switch on op {
                when BEFORE_INSERT  { CaseService.onBeforeInsert(newList); }
                when BEFORE_UPDATE  { CaseService.onBeforeUpdate(newList, oldMap); }
                when BEFORE_DELETE  { CaseService.onBeforeDelete(oldList); }
                when AFTER_INSERT   { CaseService.onAfterInsert(newList); }
                when AFTER_UPDATE   { CaseService.onAfterUpdate(newList, oldMap); }
                when AFTER_DELETE   { CaseService.onAfterDelete(oldList); }
                when AFTER_UNDELETE { CaseService.onAfterUndelete(newList); }
            }
        } finally {
            // Reset in finally to ensure flag is cleared even if an exception is thrown
            isRunning = false;
        }
    }
}
```

### 3.3 Key Design Decisions

| Decision | Rationale |
|---|---|
| `switch on op` instead of `if/else if` | Cleaner, exhaustive, compiler-validated; easier to read and extend |
| `finally` block resets `isRunning` | Ensures flag is reset even when an exception propagates; prevents permanently locked state |
| Handler uses `with sharing` | Handler is an entry point; use user context unless the service explicitly needs otherwise |
| No `Trigger.isInsert` / `Trigger.isUpdate` boolean checks | `TriggerOperation` enum is more explicit and maps 1:1 to contexts; prefer it |
| All business logic in service class | Handler is testable indirectly through the trigger; service class is directly unit-testable |

---

## 4. Context-Specific Methods

### 4.1 Available Variables per Context

| Context | Trigger.new | Trigger.newMap | Trigger.old | Trigger.oldMap |
|---|---|---|---|---|
| before insert | Available (no IDs yet) | Not available (no IDs) | Not available | Not available |
| before update | Available | Available | Available | Available |
| after insert | Available (IDs assigned) | Available | Not available | Not available |
| after update | Available | Available | Available | Available |
| before delete | Not available | Not available | Available | Available |
| after delete | Not available | Not available | Available | Available |
| after undelete | Available | Available | Not available | Not available |

### 4.2 Rules Per Context

**before insert:**
- Use for: setting default field values, validation, field derivation from related records
- Modify `Trigger.new` records directly — no DML needed (changes are committed automatically)
- `Id` is NOT yet assigned — do not reference `c.Id` for before insert records
- Do NOT query for duplicate checks using the record's own ID (it does not exist yet)

**before update:**
- Use for: field validation, preventing changes to locked records, computing derived fields
- Modify `Trigger.new` records directly — changes are committed without DML
- Use `oldMap.get(c.Id)` to compare previous values and detect what changed

**after insert:**
- Use for: creating related records, enqueueing async jobs, publishing platform events
- Records now have IDs — safe to reference `c.Id`
- Do NOT modify `Trigger.new` records here (changes will not be persisted without explicit DML)
- Perform DML to create child records or related data

**after update:**
- Use for: cascading updates to related records, sending notifications, async processing
- Build filtered lists of records where the relevant field actually changed before processing
- Never update the same record that fired the trigger without a recursion guard

**before delete:**
- Use for: preventing deletion of records that should not be deleted (add error to record)
- `Trigger.old` is the only available collection
- Call `record.addError('Deletion blocked: ...')` to prevent the delete

**after delete:**
- Use for: archiving related data, cleaning up orphaned child records
- `Trigger.old` and `Trigger.oldMap` are the only available collections

**after undelete:**
- Use for: restoring soft-deleted related records, re-associating records
- `Trigger.new` and `Trigger.newMap` are available with the restored record IDs

---

## 5. Recursion Guards

### 5.1 Why Recursion Guards Are Needed

Salesforce automation is recursive by nature. Common scenarios that cause re-entrant trigger execution:

1. **Trigger updates a record → Workflow Rule / Flow fires → updates the same record → Trigger fires again**
2. **After insert trigger creates a child record → child record's trigger fires parent logic**
3. **Flow calls an Apex action → Apex performs DML → Trigger fires → Apex action called again**
4. **Scheduled job updates records → Trigger fires → Queueable enqueued → Queueable updates records → Trigger fires again**

Without a recursion guard, this produces infinite loops that consume governor limits and fail with `System.LimitException: Too many SOQL queries` or similar errors.

### 5.2 Static Boolean Pattern

The static boolean is the baseline recursion guard. Static variables persist for the lifetime of a single Apex transaction (not across transactions).

```apex
public with sharing class CaseTriggerHandler {

    private static Boolean isRunning = false;

    public static void run(...) {
        if (isRunning) return;   // Short-circuit if already in progress

        isRunning = true;
        try {
            // process trigger
        } finally {
            isRunning = false;   // Reset in finally to handle exceptions
        }
    }
}
```

**When this is sufficient:** When your trigger logic causes downstream DML that re-fires the SAME trigger (e.g., after update trigger updates the Case record → trigger fires again). The second invocation is skipped entirely.

**Limitation:** This approach blocks ALL re-entrant processing. If a legitimate second pass is needed (e.g., the record changed materially in the interim), use the Set<Id> pattern instead.

### 5.3 Processed IDs Pattern

Use a `Set<Id>` to track which records have been processed when you need to allow re-entry for records NOT yet processed, but skip records already handled:

```apex
public with sharing class CaseTriggerHandler {

    private static Set<Id> processedIds = new Set<Id>();

    public static void run(
        System.TriggerOperation op,
        List<Case>    newList,
        Map<Id, Case> newMap,
        List<Case>    oldList,
        Map<Id, Case> oldMap
    ) {
        // Filter to only unprocessed records
        List<Case> unprocessedCases = new List<Case>();
        for (Case c : (newList != null ? newList : oldList)) {
            if (c.Id != null && !processedIds.contains(c.Id)) {
                unprocessedCases.add(c);
            }
        }

        if (unprocessedCases.isEmpty()) return;

        // Mark as processed before DML to prevent re-entry
        for (Case c : unprocessedCases) {
            processedIds.add(c.Id);
        }

        try {
            switch on op {
                when AFTER_UPDATE { CaseService.onAfterUpdate(unprocessedCases, oldMap); }
                // other contexts...
            }
        } catch (Exception ex) {
            // Remove from processedIds if processing failed — allow retry if needed
            for (Case c : unprocessedCases) {
                processedIds.remove(c.Id);
            }
            throw ex;
        }
    }
}
```

### 5.4 Thread Safety and Transaction Scope

- Static variables are **transaction-scoped** — they are initialized fresh for every new Apex transaction
- They are NOT shared between concurrent transactions (each transaction gets its own static context)
- They ARE shared within a single transaction — which is exactly the behavior needed for recursion guards
- After a transaction completes (or fails), static variables are destroyed and re-initialized on the next request

---

## 6. Idempotency

Idempotency ensures that running the same trigger logic multiple times on the same record produces the same outcome as running it once. This is essential for reliability in Salesforce's multi-invocation environment.

### 6.1 Why Idempotency Matters

- Salesforce may invoke the same DML multiple times in a single save (e.g., validation rules, before/after, workflow re-evaluations)
- Retry mechanisms in integrations can send the same record twice
- Runbook-driven reruns of batch jobs may process the same records twice

### 6.2 Change Detection for Updates

Only process records where the relevant field actually changed:

```apex
public static void onAfterUpdate(List<Case> newList, Map<Id, Case> oldMap) {
    List<Case> escalatedCases = new List<Case>();
    for (Case c : newList) {
        Case oldCase = oldMap.get(c.Id);
        // Only process if Priority actually changed to Critical in this update
        if (c.Priority == 'Critical' && oldCase.Priority != 'Critical') {
            escalatedCases.add(c);
        }
    }
    if (!escalatedCases.isEmpty()) {
        CaseService.handleEscalation(escalatedCases);
    }
}
```

### 6.3 Set<Id> Transaction Guard

Prevent duplicate processing within a single transaction for records that appear in multiple DML batches:

```apex
private static Set<Id> processedCaseIds = new Set<Id>();

public static void onAfterInsert(List<Case> newList) {
    List<Case> toProcess = new List<Case>();
    for (Case c : newList) {
        if (!processedCaseIds.contains(c.Id)) {
            toProcess.add(c);
            processedCaseIds.add(c.Id);
        }
    }
    if (!toProcess.isEmpty()) {
        CaseService.onAfterInsert(toProcess);
    }
}
```

---

## 7. Change Detection Pattern

Change detection is the practice of comparing `Trigger.new` values against `Trigger.oldMap` values to determine which records actually changed in a meaningful way. This is essential for:

- Preventing unnecessary processing (performance)
- Preventing infinite loops (safety)
- Making trigger logic idempotent (correctness)

### 7.1 Basic Field Change Detection

```apex
List<Case> statusChangedCases = new List<Case>();
for (Case c : newList) {
    Case oldCase = oldMap.get(c.Id);
    if (c.Status != oldCase.Status) {
        statusChangedCases.add(c);
    }
}
if (!statusChangedCases.isEmpty()) {
    CaseService.handleStatusChange(statusChangedCases, oldMap);
}
```

### 7.2 Multi-Field Change Detection

```apex
List<Case> changedCases = new List<Case>();
for (Case c : newList) {
    Case old = oldMap.get(c.Id);
    Boolean priorityChanged = c.Priority != old.Priority;
    Boolean statusChanged   = c.Status   != old.Status;
    Boolean ownerChanged    = c.OwnerId  != old.OwnerId;

    if (priorityChanged || statusChanged || ownerChanged) {
        changedCases.add(c);
    }
}
if (!changedCases.isEmpty()) {
    CaseService.onSignificantFieldChange(changedCases, oldMap);
}
```

### 7.3 Helper Method Pattern

Extract change detection into a reusable helper in the service or domain class:

```apex
/**
 * Description: Returns the subset of cases where Status changed to the target value.
 * @param newList      New Case values from trigger
 * @param oldMap       Previous Case values
 * @param targetStatus Status value to detect transition to
 * @return             List of Cases that transitioned to targetStatus
 */
public static List<Case> getStatusTransitions(
    List<Case>    newList,
    Map<Id, Case> oldMap,
    String        targetStatus
) {
    List<Case> transitioned = new List<Case>();
    for (Case c : newList) {
        Case old = oldMap.get(c.Id);
        if (c.Status == targetStatus && old.Status != targetStatus) {
            transitioned.add(c);
        }
    }
    return transitioned;
}
```

Usage in the service:
```apex
public static void onAfterUpdate(List<Case> newList, Map<Id, Case> oldMap) {
    List<Case> closedCases = getStatusTransitions(newList, oldMap, 'Closed');
    if (!closedCases.isEmpty()) {
        CaseService.archiveCases(closedCases);
    }

    List<Case> escalatedCases = getStatusTransitions(newList, oldMap, 'Escalated');
    if (!escalatedCases.isEmpty()) {
        CaseService.notifyEscalationTeam(escalatedCases);
    }
}
```

---

## 8. Trigger + Flow Coexistence

Salesforce orgs frequently have both Apex Triggers and Record-Triggered Flows automating the same objects. This creates coordination requirements.

### 8.1 Order of Execution (Summary)

For a single record save, the Salesforce order of execution includes (simplified):
1. System validation rules
2. Apex before triggers
3. Record-triggered flows (before-save)
4. Assignment rules, auto-response rules
5. Workflow rules, processes
6. Escalation rules
7. Apex after triggers
8. Record-triggered flows (after-save)
9. Post-commit logic (emails, async)

For the authoritative and complete order, always verify at:
https://help.salesforce.com/s/articleView?id=sf.flow_concepts_trigger_order_of_execution.htm

### 8.2 Common Conflict Scenarios

| Scenario | Risk | Resolution |
|---|---|---|
| Trigger sets Field A → Flow reads Field A | Generally safe if trigger is before-save and flow is after-save | Document in design notes; test the combined behavior |
| Trigger fires → Flow does DML on related record → Trigger fires again | Infinite loop | Add recursion guard in trigger; add entry condition in flow |
| Flow sets Field A → Trigger reads Field A in after context | Flow before-save values are visible; after-save may cause second trigger invocation | Use change detection to avoid reprocessing |
| Both trigger and flow create child records | Duplicate child records created | Assign ownership clearly: only one automation creates each record type |

### 8.3 Rules

- **Document ownership**: For each object, maintain a design doc that lists which automation (Trigger or Flow) owns which logic. Never have both doing the same thing without coordination.
- **Use change detection in both**: A trigger guard does not help when a Flow sets a field and the trigger reacts to it — the trigger should check whether the field changed before processing.
- **Never have both trigger and flow do DML on the same child records** without a coordination mechanism (e.g., a custom field flag that marks the record as already processed).
- **Test combined behavior**: After deploying a new trigger, run tests in a sandbox that has the same active Flows as production.

### 8.4 Disabling Trigger Logic for Specific Flows

For edge cases where a Flow must bypass trigger logic, use a custom bypass flag:

```apex
// Custom metadata or field: Trigger_Bypass_Active__c (checkbox on Case)
// Set this field in the Flow before performing DML, clear it after
public static void onAfterUpdate(List<Case> newList, Map<Id, Case> oldMap) {
    List<Case> toProcess = new List<Case>();
    for (Case c : newList) {
        if (!c.Trigger_Bypass_Active__c) {
            toProcess.add(c);
        }
    }
    if (!toProcess.isEmpty()) {
        CaseService.processUpdates(toProcess, oldMap);
    }
}
```

---

## 9. Before vs After Decision Guide

Use this table to determine which trigger context is appropriate for each type of logic.

| Requirement | Correct Context | Reason |
|---|---|---|
| Set a default field value on the record being saved | before insert | Avoids extra DML; changes to Trigger.new are committed automatically |
| Derive a field from other fields on the same record | before insert / before update | No DML required; applied before record is written to DB |
| Validate and prevent a save with an error message | before insert / before update / before delete | `record.addError()` only works in before contexts |
| Create related child records | after insert / after update | Parent record must have an ID (only available after insert) |
| Update a related parent record | after insert / after update | Avoid circular updates; add change detection + recursion guard |
| Send email notifications | after insert / after update | Send only after record is confirmed committed |
| Publish a Platform Event | after insert / after update | Publish after committed state is known |
| Make an HTTP callout | after insert / after update (via @future or Queueable) | Callouts not allowed directly in triggers; enqueue a Queueable |
| Prevent deletion of a record | before delete | `record.addError()` in before delete blocks the DML |
| Archive data after a deletion | after delete | Record is committed as deleted; safe to clean up references |
| Restore related records on undelete | after undelete | Undeleted record has its ID restored; use it to restore children |

### 9.1 Critical Rules

- **Never perform DML in before contexts on the triggering record** — the record is not yet committed; your DML will create a second version or cause errors
- **Never call addError() in after contexts** — it has no effect in after triggers
- **Never make HTTP callouts directly in any trigger context** — enqueue a Queueable or use `@future(callout=true)`
- **after insert for enqueueing async work** is the safest pattern: wait until the save is confirmed before dispatching async jobs

---

## 10. Delete / Undelete Handling

### 10.1 Before Delete — Validation and Prevention

Use `addError()` to prevent deletion when business rules require it:

```apex
/**
 * Description: Validates that active cases cannot be deleted.
 * @param oldList  Case records being deleted (Trigger.old)
 */
public static void onBeforeDelete(List<Case> oldList) {
    for (Case c : oldList) {
        if (c.Status == 'Open' || c.Status == 'In Progress') {
            c.addError(
                'Active cases cannot be deleted. Close the case before deleting it.'
            );
        }
    }
}
```

Key rules:
- `Trigger.old` is the ONLY available collection in delete contexts — `Trigger.new` is null
- `addError()` on any record in before delete will block the entire DML operation (or just that record in partial DML)
- Throw custom exceptions for systemic errors; use `addError()` for user-facing validation messages

### 10.2 After Delete — Cleanup

```apex
/**
 * Description: Archives case-related data after case deletion.
 * @param oldList  Deleted Case records (Trigger.old)
 */
public static void onAfterDelete(List<Case> oldList) {
    Set<Id> deletedCaseIds = new Set<Id>();
    for (Case c : oldList) {
        deletedCaseIds.add(c.Id);
    }
    // Delegate cleanup to service layer
    CaseService.archiveRelatedData(deletedCaseIds);
}
```

### 10.3 After Undelete — Restoration

```apex
/**
 * Description: Restores related records when a Case is undeleted from the Recycle Bin.
 * @param newList  Undeleted Case records (Trigger.new)
 */
public static void onAfterUndelete(List<Case> newList) {
    Set<Id> restoredCaseIds = new Set<Id>();
    for (Case c : newList) {
        restoredCaseIds.add(c.Id);
    }
    CaseService.restoreRelatedData(restoredCaseIds);
}
```

Key rules for undelete:
- `Trigger.new` and `Trigger.newMap` are available; `Trigger.old` is NOT
- Related records in the Recycle Bin may need to be individually undeleted — this requires a separate DML call or a `Database.undelete()` on the child records
- Test undelete scenarios explicitly — they are frequently omitted from test coverage

---

## 11. Bulk Safety

Every trigger, handler, and service method called from a trigger MUST be safe for 200 records. Salesforce guarantees it will batch up to 200 records per trigger invocation, and bulk DML operations from code (e.g., `insert caseList`) can produce single trigger invocations with large lists.

### 11.1 Core Rules

1. **Never SOQL inside a for loop** — collect IDs into a Set first; query once outside the loop
2. **Never DML inside a for loop** — collect records into a List; DML once outside the loop
3. **Use Map for O(1) lookup** — after querying, put results in a `Map<Id, SObject>` for fast access
4. **Pass full collections to service methods** — never call a service method one record at a time
5. **Governor Limit awareness**: 100 SOQL queries per transaction, 150 DML statements, 10,000 DML rows — bulk patterns are mandatory, not optional

### 11.2 Anti-Pattern vs Correct Pattern

**WRONG — SOQL and DML inside loop:**
```apex
// NEVER DO THIS
for (Case c : newList) {
    Account acc = [SELECT Id, Name FROM Account WHERE Id = :c.AccountId]; // SOQL in loop
    c.Description = acc.Name;
    update c; // DML in loop
}
```

**CORRECT — Bulk-safe pattern:**
```apex
// Collect all Account IDs
Set<Id> accountIds = new Set<Id>();
for (Case c : newList) {
    if (c.AccountId != null) {
        accountIds.add(c.AccountId);
    }
}

// Single SOQL outside the loop
Map<Id, Account> accountMap = new Map<Id, Account>(
    [SELECT Id, Name FROM Account WHERE Id IN :accountIds WITH USER_MODE]
);

// Process in-memory — no DML inside loop
List<Case> casesToUpdate = new List<Case>();
for (Case c : newList) {
    Account acc = accountMap.get(c.AccountId);
    if (acc != null) {
        c.Description = acc.Name; // Before context: modify in place
    }
}
// After context: collect modified records and DML once
// (In before context: changes to Trigger.new are auto-committed)
```

### 11.3 Map Pattern for Related Record Lookup

```apex
// After insert: create related Task records for each new Case
public static void onAfterInsert(List<Case> newList) {
    List<Task> tasksToCreate = new List<Task>();
    for (Case c : newList) {
        tasksToCreate.add(new Task(
            Subject    = 'Follow up: ' + c.Subject,
            WhatId     = c.Id,
            Status     = 'Not Started',
            ActivityDate = Date.today().addDays(3)
        ));
    }
    if (!tasksToCreate.isEmpty()) {
        // Single DML for all 200 records
        Database.insert(tasksToCreate, false);
    }
}
```

---

## 12. Testing 200 Records

The 200-record bulk test is NON-NEGOTIABLE for every trigger scenario. Testing with a single record does not validate bulk safety. Every relevant context (insert, update, delete) must have a 200-record test.

### 12.1 Standard Bulk Insert Test

```apex
@isTest
static void testBulkInsert_200Records() {
    // Arrange
    Account acc = new Account(Name = 'Bulk Test Account');
    insert acc;

    List<Case> cases = new List<Case>();
    for (Integer i = 0; i < 200; i++) {
        cases.add(new Case(
            Subject   = 'Test Case ' + i,
            Status    = 'New',
            Priority  = 'Medium',
            AccountId = acc.Id
        ));
    }

    // Act
    Test.startTest();
    insert cases;
    Test.stopTest();

    // Assert
    List<Case> insertedCases = [SELECT Id, Subject, Status FROM Case WHERE AccountId = :acc.Id];
    System.assertEquals(200, insertedCases.size(),
        'Expected 200 cases to be inserted successfully');

    // Validate trigger logic was applied (e.g., default field set)
    for (Case c : insertedCases) {
        System.assertNotEquals(null, c.Status, 'Status should be set on all records');
    }
}
```

### 12.2 Standard Bulk Update Test

```apex
@isTest
static void testBulkUpdate_statusChange_200Records() {
    // Arrange — create records first
    Account acc = new Account(Name = 'Bulk Update Test Account');
    insert acc;

    List<Case> cases = new List<Case>();
    for (Integer i = 0; i < 200; i++) {
        cases.add(new Case(
            Subject   = 'Update Test ' + i,
            Status    = 'New',
            AccountId = acc.Id
        ));
    }
    insert cases;

    // Act — bulk update all to 'In Progress'
    for (Case c : cases) {
        c.Status = 'In Progress';
    }

    Test.startTest();
    update cases;
    Test.stopTest();

    // Assert
    List<Case> updatedCases = [SELECT Id, Status FROM Case WHERE AccountId = :acc.Id];
    System.assertEquals(200, updatedCases.size(), 'Expected 200 records after update');
    for (Case c : updatedCases) {
        System.assertEquals('In Progress', c.Status,
            'All 200 cases should have status In Progress');
    }
}
```

### 12.3 Bulk Delete Test

```apex
@isTest
static void testBulkDelete_200Records() {
    // Arrange
    Account acc = new Account(Name = 'Delete Test Account');
    insert acc;

    List<Case> cases = new List<Case>();
    for (Integer i = 0; i < 200; i++) {
        cases.add(new Case(
            Subject   = 'Delete Test ' + i,
            Status    = 'Closed',  // Only closed cases can be deleted per our validation rule
            AccountId = acc.Id
        ));
    }
    insert cases;

    // Act
    Test.startTest();
    delete cases;
    Test.stopTest();

    // Assert
    List<Case> remaining = [SELECT Id FROM Case WHERE AccountId = :acc.Id];
    System.assertEquals(0, remaining.size(), 'All 200 cases should be deleted');
}
```

### 12.4 Recursion Guard Test

```apex
@isTest
static void testRecursionGuard_noInfiniteLoop() {
    Account acc = new Account(Name = 'Recursion Test Account');
    insert acc;

    Case c = new Case(Subject = 'Recursion Test', Status = 'New', AccountId = acc.Id);
    insert c;

    // Act — trigger update that would cause re-entry without guard
    c.Status = 'In Progress';
    c.Priority = 'High';

    Test.startTest();
    Boolean exceptionThrown = false;
    try {
        update c;
    } catch (Exception ex) {
        exceptionThrown = true;
    }
    Test.stopTest();

    System.assertFalse(exceptionThrown, 'No exception expected — recursion guard should prevent infinite loop');
    Case updated = [SELECT Id, Status FROM Case WHERE Id = :c.Id];
    System.assertEquals('In Progress', updated.Status, 'Status should be updated to In Progress');
}
```

---

## 13. Common AI Mistakes to Avoid

These patterns are frequently generated by AI tools. Every one of them MUST be caught in code review. Reject any AI output that contains these patterns and request a corrected version.

| # | Mistake | Correct Approach |
|---|---|---|
| 1 | Writing business logic (if/else, field assignments, SOQL) directly inside the trigger file | Trigger file must contain ONLY the handler dispatch call; all logic lives in service class |
| 2 | Creating a second trigger for the same object | Retrieve the existing trigger; extend the existing handler — never create a second trigger |
| 3 | No recursion guard in the handler class | Every handler must have a static boolean guard with a finally-block reset |
| 4 | SOQL inside the trigger for loop or inside a per-record service method | Collect IDs in a Set; query once outside all loops; use Map for lookup |
| 5 | DML inside the trigger for loop or inside a per-record service method | Collect records in a List; single DML call outside all loops |
| 6 | Referencing `Trigger.new` in a delete context | `Trigger.new` is null in before/after delete; use `Trigger.old` only |
| 7 | Referencing `Trigger.old` in an insert context | `Trigger.old` is null in before/after insert; only `Trigger.new` is available |
| 8 | Using `Trigger.newMap` in before insert context | `Trigger.newMap` is not available in before insert (records have no ID yet) |
| 9 | No change detection in update contexts | Always compare `newList` values against `oldMap` before processing; do not process unchanged records |
| 10 | Testing only a single-record insert | Every trigger test class must include a 200-record bulk test for each relevant context |
| 11 | Hardcoded record IDs in trigger conditions (`if (c.RecordTypeId == '012ABC...')`) | Use dynamic lookup: `Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName()` |
| 12 | Using boolean trigger context variables (`Trigger.isInsert`, `Trigger.isUpdate`) instead of `TriggerOperation` enum | Use `switch on Trigger.operationType` for clarity and exhaustiveness |
| 13 | Missing developer documentation header on handler and service classes | Every class must have the 3-line developer header (Description, Developer, Title) |
| 14 | Handler class without a sharing keyword | Explicitly declare `with sharing`, `without sharing`, or `inherited sharing` on every class |
| 15 | Making HTTP callouts directly in trigger code | Enqueue a `Queueable` (with `Database.AllowsCallouts`) from the after context |
| 16 | Declaring before-insert / before-update contexts in the trigger "for completeness" when a before-save Flow already owns field normalization | Only declare contexts that have active handlers; each undeclared context is one fewer trigger invocation per transaction — if before-save logic lives in a Flow, do not duplicate the context in the trigger |
| 17 | Reading global `Trigger.*` variables inside the handler class (`Trigger.isAfter`, `Trigger.new`, etc.) instead of receiving them as parameters | Pass `Trigger.operationType`, `Trigger.new`, `Trigger.newMap`, `Trigger.old`, `Trigger.oldMap` explicitly from the trigger file to the handler; the handler class should be testable without an actual trigger invocation |

---

## 14. Definition of Done

Before marking any trigger task complete, verify every item on this checklist:

- [ ] Confirmed there is only ONE trigger for the object (ran retrieve command to check existing triggers)
- [ ] Trigger file is thin — contains only the handler dispatch call (`CaseTriggerHandler.run(...)`)
- [ ] Handler class has a recursion guard (`private static Boolean isRunning = false`) with `finally` block reset
- [ ] Handler uses `switch on Trigger.operationType` for context routing
- [ ] Service class handles all business logic; no logic in trigger or handler beyond routing
- [ ] Change detection is applied in all update contexts — only changed records are processed
- [ ] All relevant contexts are handled; excluded contexts have a comment explaining why
- [ ] No SOQL inside any for loop in the trigger stack
- [ ] No DML inside any for loop in the trigger stack
- [ ] Developer documentation header on handler class and service class
- [ ] `with sharing`, `without sharing`, or `inherited sharing` declared on handler and service classes
- [ ] Test class covers: 200-record bulk insert, 200-record bulk update, negative/validation path, recursion guard
- [ ] Test class covers delete context if delete is handled in the trigger
- [ ] Test class covers undelete context if undelete is handled in the trigger
- [ ] Check-only deployment passes with `RunLocalTests`

---

## 15. Validation Commands

```bash
# STEP 1: Always retrieve existing triggers for the object first
sf project retrieve start \
  --metadata "ApexTrigger:CaseTrigger" \
  --target-org <alias>

# STEP 2: Also retrieve the handler class if it exists
sf project retrieve start \
  --metadata "ApexClass:CaseTriggerHandler" \
  --target-org <alias>

# STEP 3: Audit all triggers in the org
sf data query \
  --query "SELECT Name, TableEnumOrId, Status FROM ApexTrigger ORDER BY TableEnumOrId" \
  --target-org <alias> \
  --result-format human

# STEP 4: Check-only deployment with all local tests
sf project deploy start \
  --manifest manifest/package.xml \
  --target-org <alias> \
  --check-only \
  --test-level RunLocalTests \
  --wait 60

# STEP 5: Run the specific trigger test class
sf apex run test \
  --class-names CaseServiceTest \
  --target-org <alias> \
  --result-format human \
  --wait 10

# STEP 6: Verify code coverage after run
sf apex get test \
  --test-run-id <jobId> \
  --target-org <alias> \
  --result-format human

# STEP 7: Full deploy (after check-only passes)
sf project deploy start \
  --manifest manifest/package.xml \
  --target-org <alias> \
  --test-level RunLocalTests \
  --wait 60
```

---

## 16. Official References

- Apex Triggers Developer Guide: https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_triggers.htm
- Apex Triggers — Bulk Idioms: https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_triggers_bulk_idioms.htm
- Order of Execution (Triggers and Flows): https://help.salesforce.com/s/articleView?id=sf.flow_concepts_trigger_order_of_execution.htm
- Apex Trigger Context Variables: https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_triggers_context_variables.htm
- Apex Testing: https://trailhead.salesforce.com/content/learn/modules/apex_triggers
- Apex Governor Limits: https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_gov_limits.htm
- Apex Security and Sharing: https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_security_sharing_understand.htm
- Queueable Apex: https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_queueing_jobs.htm
