# Flow Development Guidelines

**Version**: 2.0 (April 2026)
**Developer**: Naresh | Senior Salesforce Developer
**Purpose**: Standalone guidelines for Salesforce Flow development. This is the highest-risk area for AI agent mistakes. Attach this file for any Flow creation, modification, or review task.

---

## Table of Contents

1. [Required Agent Output Contract](#required-agent-output-contract)
2. [Flow Types Reference](#flow-types-reference)
3. [Before-Save Record-Triggered Flows](#before-save-record-triggered-flows)
4. [After-Save Record-Triggered Flows](#after-save-record-triggered-flows)
5. [Scheduled-Triggered Flows](#scheduled-triggered-flows)
6. [Autolaunched Flows (No Trigger)](#autolaunched-flows-no-trigger)
7. [Screen Flows](#screen-flows)
8. [Subflows](#subflows)
9. [Invocable Apex in Flows](#invocable-apex-in-flows)
10. [Entry Criteria Rules](#entry-criteria-rules)
11. [Decision Element Design](#decision-element-design)
12. [Formula Resources](#formula-resources)
13. [Collection Handling — Critical Rules](#collection-handling--critical-rules)
14. [Fault Paths — Mandatory](#fault-paths--mandatory)
15. [Logging Subflow Pattern](#logging-subflow-pattern)
16. [Flow Naming Standards](#flow-naming-standards)
17. [Variable Naming Standards](#variable-naming-standards)
18. [Input/Output Contracts](#inputoutput-contracts)
19. [Trigger Order and Coexistence with Apex](#trigger-order-and-coexistence-with-apex)
20. [Idempotency and Changed-Field Checks](#idempotency-and-changed-field-checks)
21. [Activation and Versioning Strategy](#activation-and-versioning-strategy)
22. [Testing and Debugging Strategy](#testing-and-debugging-strategy)
23. [Deployment Considerations](#deployment-considerations)
24. [Good Flow Design Examples](#good-flow-design-examples)
25. [Bad Flow Design Examples (Anti-Patterns)](#bad-flow-design-examples-anti-patterns)
26. [Common AI Mistakes to Avoid](#common-ai-mistakes-to-avoid)
27. [Definition of Done (Flow-specific)](#definition-of-done-flow-specific)
28. [Validation Commands](#validation-commands)
29. [Official References](#official-references)

---

## Required Agent Output Contract

Every Flow design response MUST include ALL of the following sections. If any section is missing, the response is incomplete and must not be used as a basis for implementation.

### 1. Flow Type Decision
State explicitly which flow type will be used and **why**:
- Before-save Record-Triggered
- After-save Record-Triggered
- Scheduled-Triggered
- Autolaunched (No Trigger)
- Screen Flow

Justify the choice against alternatives. If the choice is between before-save and after-save, explicitly document why the other was rejected.

### 2. Entry Criteria Definition
State the exact conditions under which the flow will fire. Include:
- Object name
- Trigger event (created, updated, created or updated, deleted)
- Field-level conditions with operators and values
- For update triggers: which field changes trigger the flow

Example format:
```
Object: Case
Trigger: When a record is updated
Condition: Status changed from any value TO 'Closed'
Additional: AND Escalated__c = false
```

### 3. Variable Contracts (Inputs, Outputs, Collections)
List every variable used in the flow in a table:

| Variable Name | Type | Direction | Required | Description |
|---|---|---|---|---|
| input_ContactEmail | Text | Input | Yes | Email of the contact to notify |
| output_CaseNumber | Text | Output | No | Case number created |
| col_TaskList | Record Collection (Task) | Internal | No | Tasks built in loop |
| var_IsVerified | Boolean | Internal | No | Whether record passed validation |

### 4. Element-by-Element Plan with Fault Paths
List every element in execution order. For each DML or action element, state the fault path:

```
1. Entry Criteria Check — auto (entry conditions defined above)
2. Decision: HasStatusChanged? — checks $Record.Status != $Record__Prior.Status
   - Outcome YES → continue
   - Outcome NO (default) → End
3. Get Records: ExistingTask — Query Task WHERE WhatId = {!$Record.Id}
   → No fault path needed (Get Records does not throw catchable fault)
4. Decision: IsTaskAlreadyExists? — checks col_TaskList size > 0
   - Outcome YES → End (idempotency guard)
   - Outcome NO (default) → continue
5. Create Records: NewTask — creates Task record
   → FAULT PATH: LogError_Subflow (flowName='Case_AfterSave_RecordTriggered', recordId={!$Record.Id}, elementName='CreateTask', errorMessage={!$Flow.FaultMessage})
6. End
```

### 5. Security and Mode Notes
State explicitly:
- Run Mode: System Context with Sharing / User Context / System Context without Sharing — and justification
- Whether the flow performs any cross-object reads/writes that need FLS consideration
- If Apex is invoked, note that Apex enforces its own CRUD/FLS

### 6. Test/Debug Strategy
Describe:
- How to trigger the flow for testing (specific record state)
- Which sandbox or scratch org to test in
- What to verify (entry criteria fires, correct outcomes, fault paths reachable)
- Apex test class requirements if flow is invoked from Apex

### 7. Deployment Steps
Step-by-step deployment order including any pre-deployment dependencies (e.g., LogError_Subflow must exist before deploying the flow that calls it).

### 8. Rollback Approach
What to do if the flow causes issues in production:
- Deactivate the new version
- Activate the prior version (keep prior version for at least one release cycle)
- Any data repair steps if DML was already partially executed

---

## Flow Types Reference

| Flow Type | Trigger | Use Cases | DML Allowed | Callouts |
|---|---|---|---|---|
| Before-Save Record-Triggered | Record save (before commit) | Set fields on same record, derive values, conditional defaulting | No DML on other records | No |
| After-Save Record-Triggered | Record save (after commit) | Create/update related records, send emails, invoke Apex, publish platform events | Yes | Via Apex invocable only |
| Scheduled-Triggered | Scheduled time + batch | Batch record updates, scheduled notifications, data cleanup | Yes | Via Apex invocable only |
| Autolaunched (no trigger) | Apex, Flow, API, REST | Reusable logic, subflows, invocable from Apex, API-driven workflows | Yes | Via Apex invocable only |
| Screen Flow | User interaction | Guided UI wizards, data entry, step-by-step processes | Yes | Via Apex invocable only |

### Key Differences

**Before-Save vs. After-Save — Decision Matrix**

| Need | Use |
|---|---|
| Set a field on the record being saved | Before-Save |
| Derive a value from the record's own fields | Before-Save |
| Update a related record | After-Save |
| Create a child record | After-Save |
| Send an email | After-Save |
| Invoke Apex for callout | After-Save |
| Publish a Platform Event | After-Save |
| Update the triggering record itself | Before-Save (NOT After-Save) |

---

## Before-Save Record-Triggered Flows

### When to Use
- Setting or updating fields on the **same record** being saved
- Deriving values (e.g., concatenating fields, computing dates)
- Conditional defaulting of field values on create
- Any logic that must complete before the record is written to the database

### When NOT to Use
- Creating or updating related records (use After-Save)
- Sending emails (use After-Save)
- Invoking Apex actions (use After-Save)
- Any operation requiring a callout
- Anything that needs a related record to already exist (it may not yet)

### Benefits
- Runs before the record is committed to the database
- No additional DML transaction (most performant flow type for same-record updates)
- Cannot cause recursion on the triggering record (record is not yet saved)

### Accessing Record Data
- `{!$Record.FieldName}` — current field value being saved
- `{!$Record__Prior.FieldName}` — field value before the current change (update triggers only)
- These are automatically available; no Get Records element is needed for the triggering record

### Entry Condition Best Practice
Use changed-field detection to avoid running logic when irrelevant fields change:
```
Condition: {!$Record.Status} != {!$Record__Prior.Status}
```
Or for creation-only flows:
```
Condition: Record is Created (not updated)
```

### Element Restrictions
- Assignment elements: allowed
- Decision elements: allowed
- Formula resources: allowed
- Loop elements: allowed (but no DML inside)
- Get Records elements: allowed (though query on self is unnecessary)
- Create Records: NOT allowed on other objects in before-save context (technically possible but anti-pattern)
- Update Records: NOT allowed in before-save (use Assignment to set `{!$Record.FieldName}`)
- Action elements (Send Email, Invocable Apex, etc.): NOT allowed

### Fault Paths
- No fault paths needed for Assignment and Decision elements
- No fault paths needed for Formula elements
- If you somehow have an Action element, add a fault path (but reconsider if before-save is right)

### Naming Convention
```
<Domain>_BeforeSave_RecordTriggered
```
Example: `Case_BeforeSave_RecordTriggered`

### Full Design Example
```
Object: Case
Flow Name: Case_BeforeSave_RecordTriggered
Version: 1.0
Description: Sets Resolved_Date__c to today when Status changes to 'Closed'.
             Clears Resolved_Date__c if Status changes away from 'Closed'.

Entry Criteria:
  - Trigger: Created or Updated
  - Condition: Status changed ({!$Record.Status} != {!$Record__Prior.Status})

Variables: None (uses $Record directly)

Elements:
  1. Decision: IsStatusChangedToClosed?
     - Outcome "StatusClosed": {!$Record.Status} = 'Closed'
     - Outcome "StatusReopened": {!$Record.Status} != 'Closed' AND {!$Record__Prior.Status} = 'Closed'
     - Default Outcome "NoRelevantChange": End

  2a. (From "StatusClosed") Assignment: SetResolvedDate
      - {!$Record.Resolved_Date__c} = {!$Flow.CurrentDate}

  2b. (From "StatusReopened") Assignment: ClearResolvedDate
      - {!$Record.Resolved_Date__c} = null

  3. End

Notes:
  - No DML elements, no action elements, no fault paths needed
  - $Record__Prior only available when trigger is "updated"; not needed on create path
```

---

## After-Save Record-Triggered Flows

### When to Use
- Creating related records (Tasks, Cases, Opportunities)
- Updating related records
- Sending email alerts
- Invoking Apex invocable methods (callouts, complex logic)
- Publishing Platform Events
- Posting to Chatter

### Critical Rules

**RULE 1: Every DML element MUST have a fault path.**
No exceptions. If you create a Create Records element and it has no fault path, the flow design is wrong.

**RULE 2: Every Action element MUST have a fault path.**
Send Email, Post to Chatter, Invocable Apex, Submit for Approval — all require fault paths.

**RULE 3: Never update the triggering record using Update Records in After-Save flow.**
This causes a second save event, which can trigger the flow again and cause recursion. Use Before-Save for same-record updates.

**RULE 4: Guard against recursion.**
Define entry criteria on specific field changes. Do not use "Always" or broad entry conditions.

**RULE 5: Check idempotency before creating related records.**
Always check if the related record already exists before creating it. Use Get Records + Decision.

### Idempotency Pattern
```
1. Get Records: ExistingFollowUpTask
   WHERE WhatId = {!$Record.Id}
   AND Subject = 'Follow Up'
   AND Status != 'Completed'
   → store count or first record in var_ExistingTask

2. Decision: IsFollowUpTaskAlreadyExists?
   - Outcome "AlreadyExists": {!$var_ExistingTask} is not null  → End
   - Default Outcome "DoesNotExist" → continue to Create Records
```

### Entry Criteria — Changed Field Example
```
Trigger: Updated
Condition 1: {!$Record.Status} equals 'Closed'
Condition 2: {!$Record__Prior.Status} does not equal 'Closed'
Logic: Condition 1 AND Condition 2
```
This ensures the flow only runs when Status changes **to** Closed, not on every save of a Closed case.

### Naming Convention
```
<Domain>_AfterSave_RecordTriggered
```
Example: `Case_AfterSave_RecordTriggered`

### Full Design Example
```
Object: Case
Flow Name: Case_AfterSave_RecordTriggered
Version: 1.0
Description: Creates a follow-up Task when a Case is closed.
             Guards against duplicate Task creation.

Entry Criteria:
  - Trigger: Updated
  - Condition: Status changed to 'Closed' (Status = 'Closed' AND prior Status != 'Closed')

Variables:
  - var_ExistingTask: Record Variable (Task) — stores result of Get Records query
  - var_NewTask: Record Variable (Task) — built before Create Records

Elements:
  1. Get Records: GetExistingFollowUpTask
     Object: Task
     Filter: WhatId = {!$Record.Id} AND Subject = 'Case Follow Up'
     Store: First Record → var_ExistingTask
     → No fault path needed for Get Records

  2. Decision: IsFollowUpTaskExists?
     - Outcome "TaskExists": {!var_ExistingTask.Id} is not null → End
     - Default Outcome "TaskDoesNotExist" → continue

  3. Assignment: BuildFollowUpTask
     - var_NewTask.Subject = 'Case Follow Up'
     - var_NewTask.WhatId = {!$Record.Id}
     - var_NewTask.OwnerId = {!$Record.OwnerId}
     - var_NewTask.ActivityDate = {!$Flow.CurrentDate} + 3 (formula resource)
     - var_NewTask.Status = 'Not Started'
     - var_NewTask.Priority = 'Normal'

  4. Create Records: CreateFollowUpTask
     - Record: {!var_NewTask}
     → FAULT PATH: Subflow LogError_Subflow
       flowName = 'Case_AfterSave_RecordTriggered'
       recordId = {!$Record.Id}
       elementName = 'CreateFollowUpTask'
       errorMessage = {!$Flow.FaultMessage}

  5. End

Security Notes:
  - Run Mode: System Context with Sharing
  - Task creation requires Task object Create permission; flow runs in System context so FLS not enforced
  - Consider switching to User Context if tasks must respect user permissions
```

---

## Scheduled-Triggered Flows

### When to Use
- Batch record updates on a schedule (e.g., nightly status cleanup)
- Scheduled reminder notifications (e.g., 7-day follow-up emails)
- Data hygiene jobs (e.g., archiving old records, clearing stale flags)
- Any recurring logic that does not depend on a user action or record event

### Critical Characteristics
- Runs on a schedule against a **batch** of records matching filter criteria
- Processes records in batches (not guaranteed single-record at a time)
- No guarantee of processing order
- Governor limits apply per batch, not per record
- DML statements and SOQL queries count against batch limits

### Design Rules
- Design for **bulk** processing from the start — never assume single-record execution
- Entry filter: always define a filter to limit the records processed
- Avoid Get Records inside a loop (bulkification)
- Collect records into collections before DML
- Always add fault paths to every DML and action element

### Entry Filter Best Practice
```
Object: Case
Schedule: Daily at 6 AM
Filter Conditions:
  - Status = 'Pending'
  - LastModifiedDate < LAST_N_DAYS:30
  - IsClosed = false
```
This restricts the batch to only the relevant records and prevents over-processing.

### Bulk Collection Pattern
```
1. Start (scheduled trigger with filter — collection of Case records passed in)
2. Loop: LoopThroughCases (iterates over each Case in the scheduled batch)
   2a. Decision: ShouldUpdateStatus? — checks each Case condition
       - Outcome "Update" → Assignment: AddToUpdateCollection
           col_CasesToUpdate add current loop variable
       - Default "Skip" → continue loop
3. End Loop
4. Decision: AreThereRecordsToUpdate? — checks col_CasesToUpdate size > 0
   - Outcome "Yes" → Update Records
   - Default "No" → End
5. Update Records: BulkUpdateCases — collection: col_CasesToUpdate
   → FAULT PATH: LogError_Subflow
6. End
```

### Naming Convention
```
<Domain>_Scheduled_Flow
```
Example: `CaseReminder_Scheduled_Flow`

---

## Autolaunched Flows (No Trigger)

### When to Use
- Reusable logic invoked from other flows (subflow pattern)
- Called from Apex using `Flow.Interview`
- Invoked via REST API or external systems
- Complex logic shared across multiple triggering contexts

### Invocation Contexts
| Caller | Method |
|---|---|
| Apex | `Flow.Interview.start()` |
| Another Flow | Subflow element |
| Process Builder (legacy) | Process Builder action |
| REST API | `/services/data/vXX.0/actions/custom/flow/FlowName` |
| Einstein Bots | Flow action |

### Design Rules
- Must define clear **input/output variable contracts** — document them in the flow description
- Use `Available for Input` and `Available for Output` checkboxes intentionally on all relevant variables
- All DML elements need fault paths
- Keep logic focused — one responsibility per autolaunched flow
- Do not embed org-specific IDs as hardcoded values; use Custom Metadata or Custom Settings

### Input/Output Variable Documentation
Every autolaunched flow's description field should contain:
```
INPUTS:
  input_ContactId (Text, Required): Salesforce Id of the Contact to process
  input_NotificationType (Text, Required): Type of notification ('EMAIL' or 'SMS')

OUTPUTS:
  output_Success (Boolean): True if notification sent successfully
  output_ErrorMessage (Text): Error message if notification failed
```

### Naming Convention
```
<Domain>_Autolaunched
<Domain>_Subflow
```
Examples: `CaseNotification_Autolaunched`, `LogError_Subflow`

---

## Screen Flows

### When to Use
- Guided multi-step user processes (wizards)
- Data entry forms with complex validation
- User-facing decision trees
- Replacement for Visualforce pages for simple input/output scenarios

### Key Characteristics
- Requires a user interface context (Lightning Experience, Experience Cloud, Flow Actions)
- Cannot be invoked headlessly without user interaction
- Supports back/next/finish navigation
- Can invoke Apex, create records, display dynamic data

### Screen Design Rules
- **One topic per screen** — do not cram multiple unrelated inputs on one screen
- Validate inputs before allowing the user to proceed (Decision element after screen, redirect to fault screen if invalid)
- Use `lightning-input`, `lightning-combobox`, and standard input components for accessibility
- Display a confirmation screen before committing irreversible actions
- NEVER store sensitive data (SSN, passwords, tokens) in screen flow variables

### Navigation and State
- Use `{!$Flow.CurrentStage}` and flow stages if multi-step navigation tracking is needed
- Pause elements allow users to save and resume — use carefully and only when needed
- For long forms, consider splitting into multiple subflows

### Error Screen Pattern
```
1. Screen: CollectInput (fields: Account lookup, Case Type, Description)
2. Decision: ValidateInput?
   - Outcome "Valid": all required fields populated → continue
   - Default "Invalid" → Screen: ValidationError (show message, Back button)
3. Create Records: CreateCase
   → FAULT PATH: Screen: CreateCaseError (show {!$Flow.FaultMessage} user-safe message, Finish button)
4. Screen: Success (show created Case number, Finish button)
```

### Naming Convention
```
<Domain>_ScreenFlow
```
Example: `CaseCreation_ScreenFlow`

---

## Subflows

### Purpose
Subflows are the primary mechanism for **code reuse** in Flow. Any logic that will be invoked from more than one place should be extracted into an autolaunched subflow.

### Standard Subflow Patterns

**1. LogError_Subflow** (required in every org — see full design in Logging Subflow Pattern section)
**2. Notification_Subflow** — reusable notification logic (email, SMS)
**3. RecordValidation_Subflow** — reusable validation that returns boolean and error message
**4. FieldUpdate_Subflow** — reusable field-update patterns

### Subflow Design Rules
- Every subflow MUST have documented input/output variable contracts (in the flow Description field)
- Keep subflows single-purpose — do not combine unrelated logic
- Subflows must handle their own fault paths internally; do not rely on the calling flow to catch errors from within the subflow
- Subflows can call other subflows (nested subflows) — but limit nesting to 2 levels to maintain debuggability
- Subflow input variables should be marked as `Available for Input`
- Subflow output variables should be marked as `Available for Output`

### Calling a Subflow (Element Configuration)
```
Element Type: Subflow
Flow: LogError_Subflow
Input Values:
  flowName = 'Case_AfterSave_RecordTriggered'
  recordId = {!$Record.Id}
  elementName = 'CreateFollowUpTask'
  errorMessage = {!$Flow.FaultMessage}
```

---

## Invocable Apex in Flows

### When to Use Invocable Apex
| Scenario | Use Invocable Apex? |
|---|---|
| HTTP callout to external system | Yes — flows cannot do callouts directly |
| Complex SOQL involving 5+ objects | Yes |
| Batch processing or async operations | Yes |
| String manipulation beyond formula capability | Yes |
| Platform Events outside Flow native action | Yes |
| Simple field update on same record | No — use Before-Save flow |
| Creating one related record | No — use Create Records element |
| Sending standard Salesforce email alert | No — use Send Email action |

### Apex Invocable Method Requirements
- Must accept `List<Request>` and return `List<Response>`
- Must be annotated `@InvocableMethod(label='...' description='...')`
- Must be bulkified — Flow may call it with multiple records in a batch
- Should handle null inputs gracefully
- Should throw `FlowException` (or return error in output) for recoverable errors
- Should use `with sharing` unless there is documented justification otherwise

### Bulkification Example
```apex
public with sharing class CaseNotificationInvocable {

    @InvocableMethod(label='Send Case Notification' description='Sends notification for a Case record')
    public static List<Response> sendNotification(List<Request> requests) {
        List<Response> responses = new List<Response>();
        for (Request req : requests) {
            Response res = new Response();
            try {
                // process each request
                res.success = true;
            } catch (Exception e) {
                res.success = false;
                res.errorMessage = e.getMessage();
            }
            responses.add(res);
        }
        return responses;
    }

    public class Request {
        @InvocableVariable(required=true) public Id caseId;
        @InvocableVariable(required=true) public String notificationType;
    }

    public class Response {
        @InvocableVariable public Boolean success;
        @InvocableVariable public String errorMessage;
    }
}
```

### Flow Side: Invocable Apex Element
```
Element Type: Action (Apex)
Action: CaseNotificationInvocable.sendNotification
Input: caseId = {!$Record.Id}, notificationType = 'EMAIL'
Output: var_NotificationSuccess, var_NotificationError
→ FAULT PATH: LogError_Subflow
```

### Important: Invocable Apex Enforces Its Own Security
Invocable Apex methods run in their own security context. `with sharing` or `without sharing` is determined by the Apex class, not by the Flow's run mode. Do not assume the Flow's security context applies inside the invocable method.

---

## Entry Criteria Rules

### Why Entry Criteria Matter
A flow without entry criteria runs on **every record save** of that object. On a high-volume org, this can cause severe performance issues, hit governor limits, and execute logic on records that should never be affected.

### Rule: Always Define Entry Criteria
Never leave entry criteria blank or set to "Always" unless there is a documented and justified business requirement to process every single record save.

### Changed-Field Detection Patterns

**Before-Save flows (use $Record__Prior):**
```
Condition: {!$Record.Status} != {!$Record__Prior.Status}
```

**After-Save flows (use entry conditions on specific values):**
```
Condition 1: {!$Record.Status} equals 'Closed'
Condition 2: {!$Record__Prior.Status} does not equal 'Closed'
Logic: 1 AND 2
```

**Creation-only flows:**
```
Trigger: Only when a record is created
(No update conditions needed)
```

**Multiple changed fields (any of these changes should fire):**
```
Condition 1: {!$Record.Priority} != {!$Record__Prior.Priority}
Condition 2: {!$Record.Status} != {!$Record__Prior.Status}
Logic: 1 OR 2
```

### Entry Criteria Anti-Patterns
| Anti-Pattern | Problem | Fix |
|---|---|---|
| No entry conditions | Runs on every record save | Add specific field conditions |
| Checking only current value, not prior | Fires on every save where that value exists | Add `!= $Record__Prior` check |
| Using `Status is not null` | Fires when any field changes if Status is populated | Use equality check on specific value |
| Entry conditions that are always true | Same as no entry conditions | Rethink the condition logic |

---

## Decision Element Design

### Naming Outcomes
Name decision outcomes as **positive condition statements**, not generic labels:
- Good: `IsEligibleForPromotion`, `HasExistingTask`, `IsAccountVerified`
- Bad: `Yes`, `No`, `True`, `Branch1`

### Default Outcome
- Always name the default outcome descriptively: `NoConditionMet`, `IsNotEligible`, `DoesNotExist`
- The default outcome should handle **unexpected state gracefully** — typically routing to End or an error handler
- Never leave the default outcome dangling (unconnected) — it must connect to an element or End

### Nesting Decisions
- Maximum recommended decision nesting: **3 levels deep**
- Beyond 3 levels: extract into formula resource or subflow
- Deeply nested decisions are extremely difficult to debug in Flow Builder

### Formula Resources for Complex Conditions
Instead of complex conditions in a Decision element:
```
Formula Resource: formula_IsEligibleForDiscount
Return Type: Boolean
Formula: AND(
  {!$Record.Account.Type} = 'Customer',
  {!$Record.Amount} >= 10000,
  {!$Record.CloseDate} <= TODAY() + 30
)
```
Then in Decision:
```
Condition: {!formula_IsEligibleForDiscount} = true
```

---

## Formula Resources

### Purpose
Formula resources compute values at runtime and can be referenced in decisions, assignments, and screen elements. They reduce complexity in decision conditions and make logic readable.

### Naming Convention
```
formula_<DescriptiveName>
```
Examples: `formula_IsEligible`, `formula_FullContactName`, `formula_DaysUntilClose`

### When to Use Formula Resources
| Scenario | Use Formula? |
|---|---|
| Complex boolean logic spanning multiple fields | Yes |
| String concatenation for display | Yes |
| Date arithmetic | Yes |
| Simple equality check in decision | No (put directly in decision) |
| Numeric computation used in multiple places | Yes |

### Examples
```
formula_FullContactName
Type: Text
Formula: {!$Record.FirstName} & ' ' & {!$Record.LastName}

formula_DaysOverdue
Type: Number (0 decimal places)
Formula: TODAY() - {!$Record.Due_Date__c}

formula_IsHighPriorityEscalation
Type: Boolean
Formula: AND(
  {!$Record.Priority} = 'High',
  {!$Record.IsEscalated} = true,
  {!$Record.OwnerId} != {!$Record.Account.OwnerId}
)
```

---

## Collection Handling — Critical Rules

### The Golden Rule: Never DML Inside a Loop
**This is the single most common AI mistake in Flow design.** Performing a Create Records, Update Records, or Delete Records element inside a Loop element causes a separate DML statement for every iteration. In a transaction processing 200 records, this will hit governor limits immediately.

### The Correct Bulk DML Pattern

```
WRONG:
  Loop: ForEachContact
    Create Records: CreateTask ← VIOLATION

CORRECT:
  Loop: ForEachContact
    Assignment: AddTaskToCollection
      col_NewTasks add {!var_TaskToCreate}
  [End Loop]
  Create Records: CreateAllTasks (collection: col_NewTasks) ← CORRECT: single DML outside loop
```

### What Is Allowed Inside a Loop
- Reading variables
- Making decisions
- Building a collection (Assignment: add to list)
- Incrementing counters

### What Is NOT Allowed Inside a Loop
- Create Records
- Update Records
- Delete Records
- Invocable Apex actions
- Send Email actions
- Post to Chatter actions
- Any other DML or action element

### Collection Variable Setup
For collecting records to DML outside a loop:

```
Variable: col_TasksToCreate
Type: Record Collection
Object: Task
Available for Input: No
Available for Output: No
```

Inside loop — Assignment element:
```
Operator: Add
Variable: col_TasksToCreate
Value: {!var_CurrentTask}  ← single Task record variable built in this iteration
```

After loop — Create Records element:
```
How to Store Records: Use separate variables for each field
OR
How to Create Records: All records in a collection
Collection: {!col_TasksToCreate}
```

### Get Records Inside a Loop — Also Prohibited
- Performing a Get Records (SOQL query) inside a Loop element also violates governor limits
- If you need to query inside a loop, reconsider the data model or use an Apex invocable that can batch the queries

---

## Fault Paths — Mandatory

### The Rule
**EVERY DML element and EVERY Action element MUST have a fault path.** There are no exceptions. A flow element without a fault path that throws an error will surface a generic, unhelpful error to the user and leave no trace of what failed.

### Elements That REQUIRE Fault Paths
| Element Type | Requires Fault Path |
|---|---|
| Create Records | YES |
| Update Records | YES |
| Delete Records | YES |
| Send Email (action) | YES |
| Post to Chatter (action) | YES |
| Invocable Apex (action) | YES |
| Submit for Approval (action) | YES |
| Subflow (if subflow can throw) | YES |
| Custom action | YES |

### Elements That Do NOT Require Fault Paths
| Element Type | Fault Path Required? |
|---|---|
| Assignment | No |
| Decision | No |
| Formula | No |
| Get Records | No (returns null/empty if no records found; no exception) |
| Loop | No |
| Screen | No (user input validation is separate) |

### Fault Path Routing

**Minimum (background flows):**
```
DML Element
└── [Fault] → Subflow: LogError_Subflow
                input: flowName, recordId, elementName, errorMessage={!$Flow.FaultMessage}
              → End
```

**User-facing flows (Screen Flow or after-save that notifies user):**
```
DML Element
└── [Fault] → Screen: ErrorScreen
                Display Text: 'An error occurred. Please contact support. Error: {!$Flow.FaultMessage}'
              → End
```

**NEVER do this:**
```
DML Element
└── [Fault] → [back to previous element or start of loop] ← INFINITE LOOP RISK
```

### The $Flow.FaultMessage Variable
- Automatically populated when a fault occurs
- Contains the technical error message from Salesforce
- Must be captured immediately — it is reset at the next element
- Pass it to LogError_Subflow as `errorMessage`

### Multiple Fault Paths in Same Flow
Each DML/action element gets its own fault path. Do not route all fault paths to a single shared handler element if they come from different parts of the flow — each needs to capture its own `{!$Flow.FaultMessage}` before it is overwritten.

```
Create Records: CreateTask
└── [Fault] → LogError_Subflow (elementName='CreateTask', errorMessage={!$Flow.FaultMessage})

[later in flow]
Send Email: NotifyOwner
└── [Fault] → LogError_Subflow (elementName='NotifyOwner', errorMessage={!$Flow.FaultMessage})
```

---

## Logging Subflow Pattern

### Required in Every Org
Every org using Flow automation should have a `LogError_Subflow` deployed before any other flows are deployed.

### LogError_Subflow Full Design

```
Flow Name: LogError_Subflow
Type: Autolaunched (No Trigger)
Version: 1.0
Description: Standard error logging subflow. Called from fault paths of all DML and action elements.

INPUTS:
  input_FlowName (Text, Required): API name of the calling flow
  input_RecordId (Text, Optional): Salesforce Id of the record being processed
  input_ElementName (Text, Required): Name of the flow element that faulted
  input_ErrorMessage (Text, Required): {!$Flow.FaultMessage} from calling flow

Input Variable Details:
  - input_FlowName: Available for Input = true
  - input_RecordId: Available for Input = true
  - input_ElementName: Available for Input = true
  - input_ErrorMessage: Available for Input = true

Elements:
  1. Create Records: CreateAppLog
     Object: AppLog__c
     Fields:
       - Flow_Name__c = {!input_FlowName}
       - Record_Id__c = {!input_RecordId}
       - Element_Name__c = {!input_ElementName}
       - Error_Message__c = {!input_ErrorMessage}
       - Log_Time__c = {!$Flow.CurrentDateTime}
     → FAULT PATH: End
        (Log creation failure must not cause a secondary error — fail silently)

  2. End
```

### AppLog__c Custom Object Requirements
```
Object API Name: AppLog__c
Fields:
  - Flow_Name__c (Text 255)
  - Record_Id__c (Text 18)
  - Element_Name__c (Text 255)
  - Error_Message__c (Long Text Area 32768)
  - Log_Time__c (DateTime)
  - User_Id__c (Text 18) — optional, can default to $User.Id
```

### Deployment Order
1. Deploy `AppLog__c` custom object and fields
2. Deploy `LogError_Subflow`
3. Deploy all other flows that reference `LogError_Subflow`

### Monitoring AppLog__c
Create a List View or Report on `AppLog__c` showing recent errors sorted by `Log_Time__c` descending. Check this after every deployment and regularly in production.

---

## Flow Naming Standards

| Flow Type | Pattern | Example |
|---|---|---|
| Before-save record-triggered | `<Domain>_BeforeSave_RecordTriggered` | `Case_BeforeSave_RecordTriggered` |
| After-save record-triggered | `<Domain>_AfterSave_RecordTriggered` | `Case_AfterSave_RecordTriggered` |
| Scheduled | `<Domain>_Scheduled_Flow` | `CaseReminder_Scheduled_Flow` |
| Autolaunched | `<Domain>_Autolaunched` | `CaseNotification_Autolaunched` |
| Subflow | `<Domain>_Subflow` | `LogError_Subflow` |
| Screen flow | `<Domain>_ScreenFlow` | `CaseCreation_ScreenFlow` |

### Domain Examples
| Domain | Meaning |
|---|---|
| `Case` | Case object flows |
| `Account` | Account object flows |
| `Opportunity` | Opportunity object flows |
| `Contact` | Contact object flows |
| `Lead` | Lead object flows |
| `CaseReminder` | Case-related reminder logic |
| `LogError` | Error logging infrastructure |
| `OrderFulfillment` | Cross-object order processing |

### Naming Anti-Patterns
- Bad: `Flow1`, `NewFlow`, `TestFlow`, `MyFlow`
- Bad: `CaseFlow` (too vague — which type?)
- Bad: `Case After Save` (spaces not allowed in API names)
- Bad: `case_aftersave_recordtriggered` (wrong casing — use PascalCase per component)

---

## Variable Naming Standards

| Variable Type | Pattern | Example |
|---|---|---|
| Text input | `input_<Name>` | `input_ContactEmail` |
| Text output | `output_<Name>` | `output_CaseNumber` |
| Boolean | `var_Is<State>` | `var_IsVerified` |
| Record variable | `var_<ObjectType>Record` | `var_CaseRecord` |
| Collection | `col_<ObjectType>List` | `col_TaskList` |
| Formula | `formula_<Name>` | `formula_FullName` |
| Constant/CMDT | `const_<Name>` | `const_MaxRetries` |
| Counter | `var_<Name>Count` | `var_RetryCount` |
| Loop variable | `var_Loop<ObjectType>` | `var_LoopCase` |

### Variable Type Reference
| Salesforce Type | Use For |
|---|---|
| Text | String values, IDs stored as text |
| Number | Numeric values, counters |
| Currency | Monetary amounts |
| Boolean | True/false flags |
| Date | Date values without time |
| DateTime | Date and time values |
| Record (SObject) | Single record of a specific object |
| Record Collection | Multiple records of a specific object |
| Apex-Defined | Complex types returned by Apex |
| Picklist | Picklist values |
| Multipicklist | Multipicklist values |

---

## Input/Output Contracts

### Documentation Requirement
All autolaunched flows and subflows must have their input/output variable contracts documented in the **Flow Description field** in Flow Builder. This is how AI agents and developers understand what the flow expects.

### Variable Checkbox Settings

| Purpose | Available for Input | Available for Output |
|---|---|---|
| Called from outside (Apex/another flow) | Yes | No |
| Returns value to caller | No | Yes |
| Bidirectional (in and out) | Yes | Yes |
| Internal-only variable | No | No |

### Contract Template for Flow Description Field
```
FLOW: CaseNotification_Autolaunched
PURPOSE: Sends a notification for a given Case record.

INPUTS:
  input_CaseId (Text, Required): Salesforce Id of the Case to notify on
  input_NotificationType (Text, Required): 'EMAIL' or 'CHATTER'
  input_RecipientEmail (Text, Optional): Override recipient email; defaults to Case owner

OUTPUTS:
  output_Success (Boolean): True if notification sent successfully
  output_ErrorMessage (Text): Error detail if Success = false

NOTES:
  - Expects AppLog__c to exist for error logging
  - Must be called with both input_CaseId and input_NotificationType populated
  - Does not create or update Case records
```

### For Invocable Flows (Called via REST API or Process Builder)
Document the JSON input/output structure expected by external callers:
```json
Input:
{
  "inputs": [
    {
      "input_CaseId": "5001000000XXXXX",
      "input_NotificationType": "EMAIL"
    }
  ]
}

Output:
{
  "output_Success": true,
  "output_ErrorMessage": null
}
```

---

## Trigger Order and Coexistence with Apex

### Salesforce Order of Execution (Simplified)
When a record save event occurs, the following happens in order:
1. System Validation (required fields, field formats)
2. Before Apex Triggers (`trigger T on Object (before insert, before update)`)
3. **Before-Save Record-Triggered Flows** ← flows run here
4. More System Validations (duplicate rules, etc.)
5. Record saved to database
6. After Apex Triggers (`trigger T on Object (after insert, after update)`)
7. **After-Save Record-Triggered Flows** ← flows run here
8. Escalation Rules, Assignment Rules, Auto-response Rules
9. Workflow Rules (legacy)
10. Processes (legacy)

Full reference: https://help.salesforce.com/s/articleView?id=sf.flow_concepts_trigger_order_of_execution.htm

### Coexistence Rules

**Rule: Apex Trigger and After-Save Flow should NOT both DML the same related records.**
If both an Apex trigger and an after-save flow both create Tasks for the same Case save event, you will get duplicate Tasks. Coordinate:
- Option A: Move the logic entirely to the flow; remove from Apex trigger
- Option B: Move the logic entirely to the Apex trigger; remove from flow
- Option C: Use a flag field (`Task_Created__c`) set by whichever runs first, checked by the other

**Rule: Before-Save Flow runs after Apex Before triggers.**
If an Apex before-trigger sets a field, the before-save flow sees the value that the Apex trigger set (not the original value). Be aware of this when debugging unexpected values in before-save flows.

**Rule: After-Save Flow runs after Apex After triggers.**
If an Apex after-trigger creates a related record, the after-save flow cannot query that record unless it is designed to handle the slight timing difference (it is in the same transaction, so the record exists, but the flow may need a fresh query).

### Recursion Prevention
After-save flows can cause recursion if:
- The flow updates a related record, which triggers another flow, which comes back to the original object

Prevention strategies:
- Use specific entry criteria that only fire on specific field changes (not on every save)
- Use a custom boolean field `Flow_Processed__c` set to true by the flow; add entry condition: `Flow_Processed__c = false`
- Use custom permission to guard flow execution: `$Permission.DisableFlowRecursion`

---

## Idempotency and Changed-Field Checks

### Definition
**Idempotency** means the flow can be safely re-executed on the same record without causing duplicate or incorrect side effects. An idempotent after-save flow that creates a Task will only ever create ONE Task, even if the flow runs twice due to a retry, re-save, or bug.

### When Idempotency Is Required
- Any after-save flow that creates related records
- Any after-save flow that sends emails
- Any after-save flow that calls external systems via Apex

### Idempotency Implementation Patterns

**Pattern 1: Check Before Create (most common)**
```
Get Records: ExistingTask WHERE WhatId = {!$Record.Id} AND Subject = 'Follow Up'
Decision: IsTaskExists? → if Yes: End; if No: Create Records
```

**Pattern 2: Flag Field**
```
Field: Task_Created__c (Checkbox) on Case object
Entry Condition: Task_Created__c = false
After Create Records: Update Case — set Task_Created__c = true
```

**Pattern 3: Changed-Field Detection (for update-triggered flows)**
```
Entry Conditions:
  - {!$Record.Status} = 'Closed'
  - {!$Record__Prior.Status} != 'Closed'
```
This ensures the flow only fires when Status changes **to** Closed, not on every save of a closed Case.

### Changed-Field Check Reference
| Check | Syntax | Available In |
|---|---|---|
| Field changed (any change) | `{!$Record.Field} != {!$Record__Prior.Field}` | Before-Save, After-Save |
| Field changed to specific value | Entry condition: `{!$Record.Field} = 'X'` + `{!$Record__Prior.Field} != 'X'` | Before-Save, After-Save |
| Field was null and now has value | `{!$Record.Field} != null` + `{!$Record__Prior.Field} = null` | Before-Save, After-Save |
| Field is now null (cleared) | `{!$Record.Field} = null` + `{!$Record__Prior.Field} != null` | Before-Save, After-Save |

---

## Activation and Versioning Strategy

### Rules
- Only **ONE version** of a flow should be Active at any time
- When you activate a new version, Salesforce automatically deactivates the previously active version
- **Never delete the prior version** immediately — keep it for at least one release cycle as rollback insurance
- Keep version notes (use the flow Description or a separate versioning document) describing what changed in each version

### Recommended Versioning Workflow

1. **Before changes**: retrieve and commit current flow metadata to source control
   ```bash
   sf project retrieve start --metadata "Flow:Case_AfterSave_RecordTriggered" --target-org sandbox
   git add force-app/main/default/flows/Case_AfterSave_RecordTriggered.flow-meta.xml
   git commit -m "chore: snapshot Case_AfterSave_RecordTriggered v1 before changes"
   ```

2. **Make changes**: edit in Flow Builder or update metadata in source control

3. **Test in sandbox**: activate new version in sandbox, run test records, verify behavior

4. **Deploy to production**: deploy creates a new inactive version; activate it in production

5. **Verify**: check flow interviews, check AppLog__c for errors, monitor for 24 hours

6. **Keep prior version**: do not delete version N-1 until version N+1 is stable

### Version Notes Template (in Flow Description)
```
Version 2 (April 2026): Added idempotency check for Task creation.
  Changed: Added Get Records + Decision before Create Records.
  Reason: Duplicate tasks were being created during bulk re-saves.
  By: Naresh

Version 1 (January 2026): Initial release.
  By: Naresh
```

### Flow Version in Package.xml
```xml
<types>
    <members>Case_AfterSave_RecordTriggered</members>
    <name>Flow</name>
</types>
```
Note: This deploys the **active** version of the flow metadata. Always verify which version is active before deploying.

---

## Testing and Debugging Strategy

### Flow Debug Mode
- Open flow in Flow Builder → click **Debug** button
- Select record type (for record-triggered flows) and enter a record ID
- Choose to run as a different user (for testing User Context flows)
- Step through each element and verify variables at each step
- Check: entry criteria evaluated, decision outcomes correct, variable values populated, DML elements executed

### Debug Logging
For flows invoked in production or complex sandboxes:
```
Setup → Debug Logs → Add → User: [your user]
Log Level: FLOW: FINEST, APEX_CODE: DEBUG
```
After triggering the flow, check the debug log for:
- `FLOW_START_INTERVIEW_BEGIN`
- `FLOW_ELEMENT_BEGIN/END` for each element
- `FLOW_BULK_ELEMENT_DETAIL` for DML elements
- `FLOW_ELEMENT_FAULT` for any faults

### Apex Test Coverage for Flows
Flows do not have their own unit tests, but they must be exercised by Apex tests that trigger them indirectly. Required test scenarios:

```apex
@IsTest
private class Case_AfterSave_RecordTriggered_Test {

    @TestSetup
    static void setupTestData() {
        // Create test Case in state just before the trigger condition
    }

    @IsTest
    static void testFollowUpTaskCreated_WhenCaseClosed() {
        Case c = new Case(Subject = 'Test', Status = 'New');
        insert c;
        Test.startTest();
        c.Status = 'Closed';
        update c;
        Test.stopTest();
        List<Task> tasks = [SELECT Id FROM Task WHERE WhatId = :c.Id AND Subject = 'Case Follow Up'];
        Assert.areEqual(1, tasks.size(), 'Expected exactly one follow-up task');
    }

    @IsTest
    static void testIdempotency_NoDuplicateTaskOnSecondClose() {
        Case c = new Case(Subject = 'Test', Status = 'New');
        insert c;
        c.Status = 'Closed';
        update c;
        // re-save
        Test.startTest();
        update c;
        Test.stopTest();
        List<Task> tasks = [SELECT Id FROM Task WHERE WhatId = :c.Id AND Subject = 'Case Follow Up'];
        Assert.areEqual(1, tasks.size(), 'Expected only one task even after re-save');
    }

    @IsTest
    static void testFlowDoesNotFire_WhenStatusNotChanged() {
        Case c = new Case(Subject = 'Test', Status = 'Closed');
        insert c;
        Test.startTest();
        c.Subject = 'Updated Subject'; // Status not changed
        update c;
        Test.stopTest();
        List<Task> tasks = [SELECT Id FROM Task WHERE WhatId = :c.Id AND Subject = 'Case Follow Up'];
        Assert.areEqual(0, tasks.size(), 'Flow should not fire when status unchanged');
    }
}
```

### Testing Checklist
- [ ] Entry criteria fires correctly (verify with matching record)
- [ ] Entry criteria does NOT fire for non-matching saves
- [ ] Correct decision branch taken
- [ ] Collections built correctly (check variable values in debug)
- [ ] DML creates expected records
- [ ] Fault path reachable (test by intentionally causing error with invalid data)
- [ ] AppLog__c record created when fault path fires
- [ ] Idempotency: re-run does not create duplicates
- [ ] Changed-field detection: flow does not fire on irrelevant saves

---

## Deployment Considerations

### Metadata Type
Flows are deployed as `Flow` metadata type. File location:
```
force-app/main/default/flows/<FlowAPIName>.flow-meta.xml
```

### Pre-Deployment Dependencies
Before deploying any flow, ensure its dependencies are already deployed:
1. All referenced custom objects and fields
2. `LogError_Subflow` and `AppLog__c` object
3. Any Apex classes referenced as invocable actions
4. Any referenced flows used as subflows
5. Custom Metadata Types used in the flow

### Package.xml Example
```xml
<?xml version="1.0" encoding="UTF-8"?>
<Package xmlns="http://soap.sforce.com/2006/04/metadata">
    <types>
        <members>LogError_Subflow</members>
        <members>Case_AfterSave_RecordTriggered</members>
        <name>Flow</name>
    </types>
    <version>59.0</version>
</Package>
```

### Activation on Deploy
- By default, deploying a flow does NOT activate it (it creates a new inactive version)
- To activate automatically on deploy: set `status` to `Active` in the flow metadata XML
- Recommended: deploy as inactive, verify, then activate manually in target org (safer)

### Rollback Procedure
1. Identify the prior active version in target org
2. Activate the prior version (this deactivates the current)
3. Check AppLog__c for errors caused by the broken version
4. If data was corrupted by DML in the broken flow: execute data repair scripts
5. Root-cause the issue in sandbox before re-deploying

---

## Good Flow Design Examples

### Example 1: Before-Save — Set Priority Based on Account Tier
```
Object: Case
Flow Type: Before-Save Record-Triggered
Entry: Case created OR Account_Tier__c changed

Elements:
1. Decision: WhatIsAccountTier?
   - Outcome "Platinum": {!$Record.Account.Account_Tier__c} = 'Platinum'
   - Outcome "Gold": {!$Record.Account.Account_Tier__c} = 'Gold'
   - Default "Standard": → no assignment (keep current priority)

2a. (Platinum) Assignment: SetHighPriority
    - {!$Record.Priority} = 'High'

2b. (Gold) Assignment: SetMediumPriority
    - {!$Record.Priority} = 'Medium'

3. End

Notes:
- No DML, no fault paths needed
- $Record__Prior used in entry criteria for update trigger
- No action elements
```

### Example 2: After-Save — Create Follow-Up Task on Case Close
```
Object: Case
Flow Type: After-Save Record-Triggered
Entry: Case updated AND Status changed to 'Closed' (prior Status != 'Closed')

Variables:
- var_ExistingTask (Record: Task) — idempotency check
- var_NewTask (Record: Task) — task to create

Elements:
1. Get Records: GetExistingFollowUpTask
   WHERE WhatId = {!$Record.Id} AND Subject = 'Case Follow Up'
   Store: First record → var_ExistingTask

2. Decision: IsFollowUpTaskAlreadyExists?
   - Outcome "Exists": {!var_ExistingTask.Id} is not null → End
   - Default "DoesNotExist" → continue

3. Assignment: BuildFollowUpTask
   - var_NewTask.Subject = 'Case Follow Up'
   - var_NewTask.WhatId = {!$Record.Id}
   - var_NewTask.OwnerId = {!$Record.OwnerId}
   - var_NewTask.ActivityDate = {!formula_FollowUpDate} (TODAY() + 3)
   - var_NewTask.Status = 'Not Started'

4. Create Records: CreateFollowUpTask
   → FAULT PATH: LogError_Subflow
     (flowName='Case_AfterSave_RecordTriggered', recordId={!$Record.Id},
      elementName='CreateFollowUpTask', errorMessage={!$Flow.FaultMessage})

5. End
```

### Example 3: Autolaunched — Reusable Notification Logic
```
Flow Name: CaseNotification_Autolaunched
Type: Autolaunched
Purpose: Sends notification to Case owner via email

Inputs:
  input_CaseId (Text, Required)
  input_TemplateName (Text, Required)

Outputs:
  output_Success (Boolean)
  output_Error (Text)

Elements:
1. Get Records: GetCase — WHERE Id = {!input_CaseId}
2. Decision: IsCaseFound? — {!var_CaseRecord.Id} is not null
   - Not Found → Assignment: SetFailure (output_Success = false, output_Error = 'Case not found') → End
3. Invocable Apex: SendEmailAction
   → FAULT PATH: Assignment SetFailureFromApex → End
4. Assignment: SetSuccess (output_Success = true)
5. End
```

---

## Bad Flow Design Examples (Anti-Patterns)

### Anti-Pattern 1: DML Inside a Loop
```
WRONG:
Loop: ForEachContact (iterates over col_ContactList)
  Create Records: Task for {!var_LoopContact.Id}  ← VIOLATION

CORRECT:
Loop: ForEachContact
  Assignment: AddToTaskCollection — col_NewTasks.add(var_NewTask)
[End Loop]
Create Records: CreateAllTasks — collection: col_NewTasks  ← single DML
```

### Anti-Pattern 2: Missing Fault Path
```
WRONG:
Create Records: CaseRecord
[no fault path]

CORRECT:
Create Records: CaseRecord
→ FAULT PATH: LogError_Subflow (flowName, recordId, elementName, errorMessage)
```

### Anti-Pattern 3: After-Save Flow for Same-Record Field Update
```
WRONG:
Object: Case
Type: After-Save Record-Triggered
Elements: Update Records: Case — set Priority = 'High'  ← WRONG: triggers recursion

CORRECT:
Object: Case
Type: Before-Save Record-Triggered
Elements: Assignment: {!$Record.Priority} = 'High'  ← no DML needed
```

### Anti-Pattern 4: No Entry Criteria
```
WRONG:
Object: Case
Trigger: Created or Updated
Entry Condition: (none — runs always)  ← PERFORMANCE RISK

CORRECT:
Object: Case
Trigger: Updated
Entry Condition: {!$Record.Status} = 'Closed' AND {!$Record__Prior.Status} != 'Closed'
```

### Anti-Pattern 5: Hardcoded Record ID in Flow
```
WRONG:
Decision: IsSpecialAccount
Condition: {!$Record.AccountId} = '0011000000AbCdE'  ← WRONG: hardcoded ID

CORRECT:
Use Custom Metadata Type or Custom Setting to store the ID:
Get Records: GetSpecialAccountConfig WHERE DeveloperName = 'Special_Account'
Decision: Is this the special account? — compare {!$Record.AccountId} = {!var_Config.AccountId__c}
```

### Anti-Pattern 6: No Idempotency Check Before Creating Related Record
```
WRONG:
After-Save flow triggered on Status = Closed
Create Records: Task — creates task every time flow runs
Result: duplicate Tasks on every subsequent save of a Closed case

CORRECT:
Get Records: CheckExistingTask WHERE WhatId = CaseId AND Subject = 'Follow Up'
Decision: IsTaskAlreadyExists? → if Yes: End; if No: Create Records
```

### Anti-Pattern 7: Fault Path Loops Back
```
WRONG:
Create Records: CaseRecord
└── [Fault] → back to Get Records (element 2)  ← INFINITE LOOP

CORRECT:
Create Records: CaseRecord
└── [Fault] → LogError_Subflow → End
```

### Anti-Pattern 8: Query Inside Loop
```
WRONG:
Loop: ForEachCase
  Get Records: GetRelatedTasks WHERE WhatId = {!var_LoopCase.Id}  ← SOQL in loop = governor limit risk

CORRECT:
Build a Set of Case IDs first, then do ONE Get Records with a filter on that set,
or use Apex invocable to batch-query all at once.
```

### Anti-Pattern 9: @AuraEnabled(cacheable=true) on DML Method Called from Flow
```
WRONG:
Invocable Apex method internally calls a cacheable=true Apex method
Result: DML not allowed in cached context

CORRECT:
Ensure Apex called from flows for mutations uses @AuraEnabled (no cacheable)
or plain Apex without @AuraEnabled if not called from LWC
```

### Anti-Pattern 10: No Version Notes
```
WRONG:
Deploy flow updates with no description of what changed

CORRECT:
Update flow Description field with:
"Version 2 (April 2026): Added idempotency check. Reason: duplicate tasks reported. By: Naresh"
```

---

## Common AI Mistakes to Avoid

| # | Mistake | Impact | Correct Approach |
|---|---|---|---|
| 1 | DML element inside Loop | Governor limit errors, transaction failures | Build collection in loop, single DML outside loop |
| 2 | Missing fault path on Create/Update/Delete Records | Silent failures, no error tracing | Add fault path to every DML element pointing to LogError_Subflow |
| 3 | Missing fault path on Action elements | Silent failures for Send Email, Apex calls | Add fault path to every action element |
| 4 | Using After-Save to update the triggering record | Recursion, infinite loop | Use Before-Save for same-record updates |
| 5 | No entry criteria defined | Performance risk; runs on every save | Define field-level change conditions |
| 6 | No idempotency check | Duplicate related records created | Get Records + Decision before every Create Records |
| 7 | Hardcoded Record IDs | Breaks across orgs, breaks after data migration | Use Custom Metadata Types or Custom Settings |
| 8 | Wrong flow type selected | Functional failures, performance issues | Use Before-Save for same-record; After-Save for related |
| 9 | Get Records (SOQL) inside Loop | Governor limit errors | Query before loop; pass collection into loop |
| 10 | Fault path loops back to earlier element | Infinite loop | Fault path must route to End or error screen |
| 11 | Not capturing {!$Flow.FaultMessage} | Loss of error detail | Capture FaultMessage immediately in fault path |
| 12 | Sensitive data stored in flow variables | Security exposure | Avoid storing tokens, passwords in flow variables |
| 13 | Activating without testing in sandbox | Production incidents | Always test in sandbox with representative data |
| 14 | Not keeping prior version | No rollback option | Keep N-1 version for at least one release cycle |
| 15 | No changed-field detection on update trigger | Flow fires on every unrelated save | Use $Record__Prior in entry conditions |
| 16 | Deeply nested decisions without formulas | Unmaintainable logic | Extract complex conditions to Formula resources |
| 17 | No documentation of input/output contracts | Callers cannot understand how to use the flow | Document inputs/outputs in flow Description field |
| 18 | Deploying LogError_Subflow after dependent flows | Dependent flow fails on first error | Deploy infrastructure flows first |
| 19 | Flow variable name conflicts with reserved names | Unexpected flow behavior | Follow naming conventions; avoid Salesforce reserved names |
| 20 | Missing LogError_Subflow in org | No error logging possible | Deploy AppLog__c and LogError_Subflow before any other flows |
| 21 | Missing `processMetadataValues` blocks (BuilderType + CanvasMode) | Flow shows as "built with Cloud Flow Designer"; cannot be opened or edited in Lightning Flow Builder | Every flow XML must include both `<processMetadataValues>` blocks before `<processType>`: `BuilderType=LightningFlowBuilder` and `CanvasMode=AUTO_LAYOUT_CANVAS` |
| 22 | Non-zero `locationX`/`locationY` values in AUTO_LAYOUT_CANVAS flow | Canvas positions are ignored; builder may reorder on first open | Set ALL `<locationX>0</locationX>` and `<locationY>0</locationY>` on every element when using `AUTO_LAYOUT_CANVAS` |
| 23 | Missing `<areMetricsLoggedToDataCloud>false</areMetricsLoggedToDataCloud>` | Field absent from exported XML; metadata mismatch against org state | Add immediately after `<apiVersion>` in every flow |
| 24 | XML comments (`<!-- ... -->`) inside flow files | Flow Builder does not write comments; causes visual noise and potential re-serialisation diffs | Remove all XML comments; put notes in `<description>` or `<label>` instead |
| 25 | Flow XML elements not in alphabetical order | Flow Builder re-orders elements on first open, creating large noise diffs | Write elements in strict alphabetical order: `actionCalls → apiVersion → areMetricsLoggedToDataCloud → assignments → decisions → description → environments → formulas → interviewLabel → label → processMetadataValues → processType → recordCreates → recordLookups → recordUpdates → start → status → triggerOrder → variables` |
| 26 | Decision `defaultConnector` missing — default path silently ends the flow | Logic intended to follow the decision is never reached (silent dead end, not an error) | Every non-terminal Decision MUST have an explicit `<defaultConnector>` pointing to the next element; trace every path after writing a Decision |
| 27 | `FaultEnd` assignment (reads `$Flow.FaultMessage`) used as a Decision `defaultConnector` target | On a non-fault path `$Flow.FaultMessage` is null; the assignment is a no-op and the intent is misleading | `FaultEnd` assignments must only be targets of `<faultConnector>` on DML/action elements — never of a Decision connector |
| 28 | Using `$Record__Prior.FieldName` inside after-save formula resources | `$Record__Prior` direct references only work in before-save entry conditions; after-save formulas require the function form | In after-save flow formula resources always use `PRIORVALUE({!$Record.FieldName})` |
| 29 | Mixed AND/OR conditions using `<conditionLogic>and</conditionLogic>` for all rules | All conditions are AND-ed even when OR is intended, producing wrong branching | Use explicit numeric logic for mixed rules: `<conditionLogic>1 AND 2 AND (3 OR 4)</conditionLogic>` |
| 30 | `<actionName>` in `<actionCalls>` does not exactly match the Apex class name | Deployment error — Salesforce cannot resolve the invocable | `actionName` must be the exact Apex class name (not the method name, not a label) |
| 31 | Before-save flow contains `<recordUpdates>` or `<actionCalls>` elements | DML/actions in before-save context cause recursion or are prohibited; same-record updates do not need a DML element | Before-save flows must use only Assignment and Decision elements; assign directly to `$Record` — the platform writes the values as part of the save |
| 32 | Single linear decision chain mixes all record-type logic together | Every record evaluates every decision regardless of its RT; cross-RT connector leaks (e.g. SBU_GC merged path wiring into HRG_CS decisions); unmaintainable as RT logic grows | Use a master RT gate decision after any early exits; fan out to RT-specific sub-chains; converge all branches to a shared common tail |
| 33 | Early-exit actions (dupe/spam close, bypass flag on merged case) continue into downstream decisions via connector | Logic intended only for that specific case type runs on records that should be fully processed (or not at all) | Terminal assignments must have no `<connector>` — omit the connector element entirely so the flow ends at that point; confirmed from old `Case_Shift_Close_as_Duplicate` and `Case_Before_Save_Case_Merge_to_Closed` flows |
| 34 | RT-specific decisions repeat `formula_IsRT` and `formula_IsNew` conditions that are already guaranteed by the upstream RT gate and IsNew gate | Redundant conditions add noise, inflate element count, and hide the true guard condition when reading the flow | Once a record enters a branch via an RT gate, remove the RT formula and IsNew formula from all decisions inside that branch — rely on the gate, not repeated conditions |
| 35 | Using hardcoded RecordType ID (e.g. `'012OG000000vJxBYAU'`) in formula variables to detect or assign record types | ID is org-specific; breaks on sandbox refresh, migration, or new org | For detection/branching: use `$Record.RecordType.DeveloperName` directly. For assigning RecordTypeId: use `Get Records` filtered by `DeveloperName` and assign the queried `Id` |
| 36 | `NexusTaskToProject` decision placed only in the update branch | Task-to-project upgrade should fire on create too (a new Nexus Task with 30+ hours must also become a Project) | Place `Decision_NexusTaskToProject` in both the IsNew=true Nexus branch and the IsNew=false Nexus branch; `Decision_NexusClosedLost` (update-only, relies on `IsChanged`) stays in the update branch only |
| 37 | Using `$Record.Status = 'Reopened'` to detect a reopen when `'Reopened'` is not assigned to any record type's picklist | Condition never evaluates true; reopen logic silently skips for all cases | Use `$Record__Prior.Status = 'Closed' AND $Record.Status != 'Closed'` — any transition OUT of Closed is a reopen; matches old Process Builder `PRIORVALUE(Status) = 'Closed'` parity |
| 38 | Running an unconditional action (e.g. `Update_LastStatusUpdate`) as the first element when the entry filter admits multiple unrelated triggers (status change OR first-response flag change) | Action fires on field changes that do not warrant it, producing incorrect timestamps | Add a `Decision_StatusOrNew` gate as the first element using `conditionLogic: 1 OR 2`; route each entry-type to its own path |
| 39 | Idempotency `Get Records` for status log filtering only on `Case__c` and `Status__c` without `End_Time__c IS NULL` | A previously closed log for the same status satisfies the filter and triggers "log exists — skip creation" on re-entry to that status, so no new open log is created | Always include `End_Time__c IS NULL` (or equivalent open-record indicator) in any "find existing open record" idempotency lookup |
| 40 | Omitting a `By_Pass__c` check in the SBU_GC status log gate when a before-save flow sets `By_Pass__c = true` for merged+closed cases | Status logs are created for merged cases that should be bypassed, producing orphan logs | Add `$Record.By_Pass__c = false` as an AND condition in the SBU_GC gate decision; the before-save flow has already set the flag by the time the after-save flow evaluates |
| 41 | `Get Records` for an idempotency null-check retrieves all fields when only `Id` is needed | Unnecessary SOQL data transfer on every flow execution | Add `<queriedFields>Id</queriedFields>` to any Get Records whose only downstream use is `var.Id IsNull` — matches the pattern used by `GetRecords_PriorStatusLog` |
| 42 | `recordTriggerType: Update` used when new cases can be created with the trigger field already populated | Flow never fires on record creation — escalation user stamp and child case creation are silently skipped for new cases with `Escalate_To__c` pre-populated | Set `recordTriggerType: CreateAndUpdate` whenever the business process can originate on create; confirmed: `Case_Current_User_Escalated_After_Flow` (old flow) ran on CreateAndUpdate |
| 43 | Entry filter missing RecordType gate — flow relies solely on field-change detection | Flow fires for all record types; non-target RTs enter the DEFAULT decision branch (e.g. STAMP_USER_ONLY) even when they should not be processed at all | Add RecordType DeveloperName filter directly in the `filterFormula`: `&& ($Record.RecordType.DeveloperName = 'RT1' \|\| ... = 'RT2')` — matches the design doc entry condition spec |
| 44 | `NOT(ISBLANK(MasterRecordId))` used in entry filter for merge detection without `ISCHANGED()` guard | Every subsequent update of a merged case re-triggers the flow and creates a duplicate `Linked_Case__c` record | Use `ISCHANGED(MasterRecordId) && NOT(ISBLANK(MasterRecordId))` — fires only at the exact moment of merge when the field transitions from null to a value |
| 45 | `Linked_Cases__c` and `Linked_Cases_SBUGC__c` field assignments reversed in `Linked_Case__c` records for DUPLICATE and MERGE paths | Data stored in the wrong lookup fields; any query or report relying on "original case in Linked_Cases__c" returns the wrong record | Convention confirmed from old `Case_Create_Linked_Case_Record` flow: `Linked_Cases__c` = primary/original/master case; `Linked_Cases_SBUGC__c` = derived/secondary case (duplicate, loser, or split) |
| 46 | Coding re-parent logic against a field that does not exist on the target object (e.g. `MergedCase__c` on `Case_SLA_Summary__c`) | Deployment fails with "No such column" error | Always verify field existence from `force-app/main/default/objects/<Object>/fields/` before writing SOQL or field assignments — never assume a field exists because it exists on a sibling object |
| 47 | DUPLICATE path in linked-case flow fires for all record types when old flow restricted to SBU_GC only | Non-SBU_GC cases with `Duplicate_with__c` populated receive unwanted `Linked_Case__c` records | Add RecordType DeveloperName gate to BOTH the entry `filterFormula` and the Decision rule for the DUPLICATE path — confirmed DeveloperName: `SBU_GC` |
| 48 | Hardcoded org IDs placed directly in flow formula expressions (`'00GC0000001srkn'`) or `<inputAssignments>` (`<stringValue>001Hn00001v3aLNIAY</stringValue>`) | Breaks on sandbox refresh, org migration, or config change; violates CLAUDE.md no-hardcoded-ID rule | Create a Custom Label per ID; reference it in a formula resource as `{!$Label.Label_Name}` (e.g. `LEFT(PRIORVALUE({!$Record.OwnerId}), 15) = {!$Label.Case_Routing_PSC_Queue_Id}`); then use `<elementReference>formula_name</elementReference>` in `<inputAssignments>` and decision `<rightValue>` elements |
| 49 | Old Before-Save flow (simple field assignments, no SOQL) pulled into an After-Save consolidated flow | Before-Save logic runs in record memory without DML — moving it to after-save adds a redundant `Update Records` DML call and risks recursion | Leave simple Before-Save flows (field assignment only, no record lookups) as independent before-save flows; only consolidate into After-Save when the logic needs SOQL or related-record DML after commit |
| 50 | Parity gap: old flow assigned a field via hardcoded record ID (e.g. `Points_Product__c = 'a0AC...'`); new flow omits the assignment entirely rather than replacing with a dynamic lookup | Silent functional gap — field stays blank in new flow for cases that previously received it | When an old flow set a field using a hardcoded record ID, flag it as VERIFY item: confirm whether the field is still used in business logic; if yes, implement dynamic lookup by name/DeveloperName; if the field is deprecated, document the intentional omission |
| 51 | Using `<operator>IsNull</operator><rightValue><booleanValue>false</booleanValue></rightValue>` on a Status (or any always-populated field) to detect a field change | Condition is always true when the field has any value — fires on every record save for that field | Use `<operator>IsChanged</operator><rightValue><booleanValue>true</booleanValue></rightValue>` to detect that a field value changed during this transaction |
| 52 | Missing fault connectors on `emailAlert` action elements (`<actionType>emailAlert</actionType>`) — treating them as passive actions that can't fail | Email alerts fail silently if the template is missing, recipient is invalid, or org email limits are hit | `emailAlert` is an action element — apply the same mandatory fault connector rule as `invocableApex`, `sendEmail`, and `customAction`; every `<actionCalls>` block with `<actionType>emailAlert</actionType>` requires `<faultConnector><targetReference>FaultEnd</targetReference></faultConnector>` |
| 53 | TODO placeholder Assignments that write to `var_FaultMessage` (a fault-tracking variable) used as stub nodes for unimplemented email or action logic | Abuses the fault variable for non-fault state; pollutes error tracking; stub is indistinguishable from a fault path when reading the flow | For stub/placeholder nodes, use a clearly-named no-op Assignment variable (e.g. `var_StubPlaceholder`) or omit the element entirely and block OV with a comment in the flow description until the API names are confirmed |

---

## Definition of Done (Flow-specific)

Use this checklist for every flow before marking it complete.

### Design
- [ ] Correct flow type chosen and documented (before-save vs after-save vs autolaunched)
- [ ] Entry criteria defined and documented (no blank or "Always" conditions without justification)
- [ ] Element-by-element plan completed with fault paths listed
- [ ] Input/output variable contracts documented in flow Description field

### Implementation
- [ ] No DML elements inside Loop elements
- [ ] No Action elements inside Loop elements
- [ ] No SOQL (Get Records) inside Loop elements
- [ ] Every Create Records element has a fault path to LogError_Subflow
- [ ] Every Update Records element has a fault path to LogError_Subflow
- [ ] Every Delete Records element has a fault path to LogError_Subflow
- [ ] Every Send Email action has a fault path
- [ ] Every Invocable Apex action has a fault path
- [ ] Every Subflow call (if subflow can throw) has a fault path
- [ ] Variable naming follows standards (col_, var_, input_, output_, formula_)
- [ ] No hardcoded Record IDs (use Custom Metadata or Custom Settings)
- [ ] Idempotency check implemented for any Create Records in after-save flow
- [ ] Changed-field detection implemented for update-triggered flows

### Security
- [ ] Run Mode documented (System Context with Sharing / User Context)
- [ ] Justification documented if System Context without Sharing is used

### Testing
- [ ] Tested in sandbox with record matching entry criteria
- [ ] Tested that flow does NOT fire on irrelevant record saves
- [ ] Fault path tested (confirmed AppLog__c record created)
- [ ] Idempotency tested (re-run produces no duplicate records)
- [ ] Apex test class exists covering flow invocation
- [ ] All test scenarios pass

### Deployment
- [ ] LogError_Subflow deployed in target org before this flow
- [ ] Version notes documented in flow Description
- [ ] Flow retrieved and committed to source control before deployment
- [ ] Deployed to sandbox successfully
- [ ] Activated in sandbox and tested
- [ ] Deployment to production passes check-only validation
- [ ] Activated in production and monitored for 24 hours

---

## Validation Commands

```bash
# Retrieve flow metadata from sandbox
sf project retrieve start \
  --metadata "Flow:Case_AfterSave_RecordTriggered" \
  --target-org <sandbox-alias>

# Retrieve multiple flows at once
sf project retrieve start \
  --metadata "Flow:LogError_Subflow,Flow:Case_AfterSave_RecordTriggered,Flow:Case_BeforeSave_RecordTriggered" \
  --target-org <sandbox-alias>

# Deploy flow (check-only first)
sf project deploy start \
  --metadata "Flow:Case_AfterSave_RecordTriggered" \
  --target-org <production-alias> \
  --check-only \
  --wait 60

# Deploy flow (actual deploy after check-only passes)
sf project deploy start \
  --metadata "Flow:Case_AfterSave_RecordTriggered" \
  --target-org <production-alias> \
  --wait 60

# Run Apex tests (which cover flow invocation)
sf apex run test \
  --class-names Case_AfterSave_RecordTriggered_Test \
  --target-org <sandbox-alias> \
  --wait 10 \
  --result-format human

# List all flows in org
sf data query \
  --query "SELECT Id, ApiName, ActiveVersionId, LatestVersionId, ProcessType FROM FlowDefinition" \
  --target-org <alias>

# Check for AppLog errors after deployment
sf data query \
  --query "SELECT Flow_Name__c, Record_Id__c, Element_Name__c, Error_Message__c, Log_Time__c FROM AppLog__c ORDER BY Log_Time__c DESC LIMIT 20" \
  --target-org <alias>
```

---

## Official References

- **Order of Execution**: https://help.salesforce.com/s/articleView?id=sf.flow_concepts_trigger_order_of_execution.htm
- **Create Records element**: https://help.salesforce.com/s/articleView?id=sf.flow_ref_elements_om_recordCreate.htm
- **Flow Developer Guide**: https://developer.salesforce.com/docs/atlas.en-us.flow.meta/flow/
- **Flow Trailhead**: https://trailhead.salesforce.com/content/learn/modules/business_process_automation
- **Fault Paths**: https://help.salesforce.com/s/articleView?id=sf.flow_build_fault_paths.htm
- **Record-Triggered Flow Best Practices**: https://help.salesforce.com/s/articleView?id=sf.flow_concepts_rt_bestpractices.htm
- **Flow Run Mode**: https://help.salesforce.com/s/articleView?id=sf.flow_concepts_run_mode.htm
- **Invocable Apex**: https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_classes_annotation_InvocableMethod.htm
- **Flow Limits and Considerations**: https://help.salesforce.com/s/articleView?id=sf.flow_considerations.htm
