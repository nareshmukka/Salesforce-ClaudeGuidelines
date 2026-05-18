# Apex Trigger Guidelines

Authoritative rules for `.trigger` files and trigger handlers in this project. Attach this file to any task that creates, modifies, or reviews a Salesforce Apex trigger.

**Verified against:** [Apex Triggers Developer Guide](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_triggers.htm) · [Trigger Best Practices](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_triggers_bp.htm) · [Bulk Trigger Idioms](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_triggers_bulk_idioms.htm) · [Trigger Context Variables](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_triggers_context_variables.htm) · [Order of Execution](https://help.salesforce.com/s/articleView?id=sf.flow_concepts_trigger_order_of_execution.htm) · [`forcedotcom/sf-skills` generating-apex](https://github.com/forcedotcom/sf-skills/tree/main/skills/generating-apex) · [`trailheadapps/agent-script-recipes` APEX_RULES](https://github.com/trailheadapps/agent-script-recipes/blob/main/.airules/APEX_RULES.md) · [Mitch Spano `apex-trigger-actions-framework`](https://github.com/mitchspano/apex-trigger-actions-framework). Last verified 2026-05-16.

---

## 1. File Layout

One trigger file per object. One handler class (or one Trigger Actions metadata stack) behind it. Business logic lives in service / domain / selector classes — never in the trigger and never in the handler.

```
force-app/main/default/triggers/CaseTrigger.trigger      # thin entry point
force-app/main/default/classes/CaseTriggerHandler.cls    # routes by context, owns recursion guard
force-app/main/default/classes/CaseService.cls           # business logic + DML
force-app/main/default/classes/CaseSelector.cls          # all SOQL for Case
force-app/main/default/classes/CaseDomain.cls            # in-memory validation + derivation
force-app/main/default/classes/CaseServiceTest.cls       # bulk + change-detection + recursion tests
```

**Trigger Actions Framework (TAF) variant** — when adopted (Mitch Spano's framework):

```
force-app/main/default/triggers/CaseTrigger.trigger      # body: new MetadataTriggerHandler().run();
force-app/main/default/classes/TA_Case_SetDefaults.cls   # one class per concern per context
force-app/main/default/customMetadata/Trigger_Action.TA_Case_SetDefaults.md-meta.xml   # registration
```

Either pattern is acceptable. Pick **one per object** and stay consistent.

---

## 2. Required Agent Output Contract

Every trigger task response MUST include these sections before any code:

| # | Section | Required content |
|---|---|---|
| 1 | Plan | Object, contexts implemented, contexts excluded + why |
| 2 | Files | Absolute paths + `CREATE`/`MODIFY` + one-line purpose |
| 3 | Security | Sharing keyword + justification; `USER_MODE` plan for downstream SOQL/DML |
| 4 | Recursion guard | Static-boolean vs `Set<Id>` vs field-value-comparison — and why |
| 5 | Test strategy | Bulk-200 insert/update/delete, change-detection scenarios, recursion test, negative path |
| 6 | Validation commands | `sf project deploy start --check-only --test-level RunLocalTests` |
| 7 | Rollback | Prior handler preserved? Metadata dependencies? Plusgrade activation gate |

For Plusgrade PlusGradeFullSB, §7 must confirm: **deploy as `status = Draft` for new flows, do NOT deactivate old triggers/flows; activation is manual.**

---

## 3. One Trigger Per Object — Mandatory

Salesforce does NOT guarantee execution order between multiple triggers on the same object. Two triggers on `Case` = non-deterministic behavior, race conditions, and untestable production failures.

### 3.1 Audit before creating anything

```bash
sf project retrieve start --metadata "ApexTrigger:CaseTrigger" --target-org <alias>

sf data query \
   --query "SELECT Name, TableEnumOrId, Status FROM ApexTrigger ORDER BY TableEnumOrId" \
   --target-org <alias> --result-format human
```

If a trigger already exists: retrieve it, extend its handler, add the new context to the dispatch switch. **Never create a second trigger file.** Reject any AI output that proposes one.

---

## 4. Thin Trigger Pattern

The trigger file passes context variables to the handler. Zero business logic. Zero SOQL. Zero DML. Zero `if`.

```apex
// WRONG — logic in the trigger
trigger CaseTrigger on Case (before insert) {
   for (Case c : Trigger.new) {
      if (c.Status == null) c.Status = 'New';        // belongs in domain class
      Account a = [SELECT Name FROM Account WHERE Id = :c.AccountId];   // SOQL in loop
   }
}
```

```apex
// RIGHT — thin dispatch, context vars passed explicitly
trigger CaseTrigger on Case (
   before insert, before update, before delete,
   after insert,  after update,  after delete,
   after undelete
) {
   CaseTriggerHandler.run(
      Trigger.operationType,
      Trigger.new, Trigger.newMap,
      Trigger.old, Trigger.oldMap
   );
}
```

**Why pass context vars explicitly:** the handler becomes unit-testable. A test can call `CaseTriggerHandler.run(AFTER_UPDATE, mockNew, mockNewMap, mockOld, mockOldMap)` directly. Handlers that read `Trigger.new` / `Trigger.isAfter` from inside the class can only ever run through real DML.

---

## 5. Handler Class — Custom Pattern

The handler routes by `TriggerOperation` enum, owns the recursion guard, delegates every context to a service method.

```apex
/**
 * Handler for CaseTrigger. Routes execution by TriggerOperation. Owns recursion guard.
 * Developer: Naresh — Senior Salesforce Developer
 */
public with sharing class CaseTriggerHandler {

   @TestVisible private static Boolean isRunning = false;

   public static void run(
      System.TriggerOperation op,
      List<Case> newList,  Map<Id, Case> newMap,
      List<Case> oldList,  Map<Id, Case> oldMap
   ) {
      if (isRunning) return;
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
         isRunning = false;
      }
   }
}
```

### Design rationale

| Decision | Why |
|---|---|
| `switch on Trigger.operationType` | Exhaustive, compiler-validated. Beats stacked `if (Trigger.isBefore && Trigger.isInsert)` |
| `finally { isRunning = false; }` | Without it, an exception leaves the flag stuck True for the rest of the transaction |
| `@TestVisible` on the guard | Tests can reset between scenarios without making it public API |
| `with sharing` on handler | Entry point runs as the calling user. Elevation belongs in an isolated helper with a Custom Permission gate |
| Context vars as parameters | Handler is testable without DML; decoupled from `Trigger.*` globals |

---

## 6. Handler Class — Trigger Actions Framework (TAF)

TAF replaces the giant switch with a metadata table of action classes. **Adopt when** the object will have many independent concerns (5+ behaviors that should toggle independently per deployment, or admin-controlled enable/disable).

### 6.1 Trigger body

```apex
trigger CaseTrigger on Case (
   before insert, before update, before delete,
   after insert,  after update,  after delete,
   after undelete
) {
   new MetadataTriggerHandler().run();
}
```

### 6.2 Action class — one concern per context

```apex
public with sharing class TA_Case_SetDefaults implements TriggerAction.BeforeInsert {
   public void beforeInsert(List<Case> newList) {
      for (Case c : newList) {
         if (String.isBlank(c.Status))   c.Status   = 'New';
         if (String.isBlank(c.Origin))   c.Origin   = 'Web';
         if (String.isBlank(c.Priority)) c.Priority = 'Medium';
      }
   }
}
```

### 6.3 Registration — without this, the action is dead code

```xml
<!-- customMetadata/Trigger_Action.TA_Case_SetDefaults.md-meta.xml -->
<CustomMetadata xmlns="http://soap.sforce.com/2006/04/metadata">
   <values><field>Apex_Class_Name__c</field>  <value xsi:type="xsd:string">TA_Case_SetDefaults</value></values>
   <values><field>Object__c</field>           <value xsi:type="xsd:string">Case</value></values>
   <values><field>Trigger_Context__c</field>  <value xsi:type="xsd:string">BeforeInsert</value></values>
   <values><field>Order__c</field>            <value xsi:type="xsd:double">10</value></values>
   <values><field>Bypass_Execution__c</field> <value xsi:type="xsd:boolean">false</value></values>
</CustomMetadata>
```

### 6.4 TAF-specific rules

- One action class = one concern = one context. A second concern needs a second class.
- `Order__c` controls execution order within the same context. Use multiples of 10 so inserts later don't renumber everything.
- `Bypass_Execution__c = true` disables one action without removal — the framework's incident escape hatch.
- Name `TA_<SObject>_<Concern>` (see §15).
- **Recursion in TAF:** prefer field-value comparison (§7.3) over static booleans — TAF's per-action structure makes shared static flags awkward.

---

## 7. Recursion Guards

Salesforce automation is inherently recursive. Without a guard:

| Pattern | Loop trigger |
|---|---|
| After-update writes to same record | Trigger fires → service updates Case → trigger fires again → ∞ |
| After-insert creates child whose trigger updates parent | Parent trigger fires from child trigger's DML |
| Flow calls Apex action → Apex DMLs Case → Trigger fires → Apex action called again | Flow + Apex round-trip |

Three guard styles. Pick by scenario.

### 7.1 Static boolean (simplest)

```apex
@TestVisible private static Boolean isRunning = false;

public static void run(...) {
   if (isRunning) return;
   isRunning = true;
   try { /* dispatch */ } finally { isRunning = false; }
}
```

**Use when:** any second invocation of the trigger should be skipped entirely. Most Case/Account/Opportunity scenarios.
**Limitation:** blocks every re-entry, even legitimate ones.

### 7.2 Processed-IDs `Set<Id>`

```apex
@TestVisible private static Set<Id> processedIds = new Set<Id>();

public static void run(System.TriggerOperation op, List<Case> newList, ...) {
   List<Case> toProcess = new List<Case>();
   for (Case c : newList) {
      if (c.Id != null && !processedIds.contains(c.Id)) {
         toProcess.add(c);
         processedIds.add(c.Id);       // mark BEFORE downstream DML
      }
   }
   if (toProcess.isEmpty()) return;
   /* dispatch with toProcess */
}
```

**Use when:** mixed batch — some records should re-process, others shouldn't.

### 7.3 Field-value comparison (preferred for TAF and Flow-coexistence)

Don't remember "we already ran" with a flag. Check whether the field's current value differs from prior. Self-cleansing — no static state to leak.

```apex
public static void onAfterUpdate(List<Case> newList, Map<Id, Case> oldMap) {
   List<Case> escalated = new List<Case>();
   for (Case c : newList) {
      Case prior = oldMap.get(c.Id);
      if (c.Priority == 'Critical' && prior.Priority != 'Critical') {
         escalated.add(c);
      }
   }
   if (!escalated.isEmpty()) CaseService.handleEscalation(escalated);
}
```

**Use when:** the trigger reacts to specific field transitions. **This is the framework-agnostic guard preferred by Mitch Spano's TAF.**

### 7.4 Transaction scope facts

- Static variables persist for **one Apex transaction** — reset between separate DML calls.
- Not shared between concurrent transactions — no cross-user pollution.
- Shared inside one transaction — which is exactly the behavior the guard needs.
- A thrown exception kills the transaction; the next transaction starts fresh regardless. `finally` only matters when the same transaction continues.

---

## 8. Context Routing

### 8.1 Variables per context

| Context | `Trigger.new` | `Trigger.newMap` | `Trigger.old` | `Trigger.oldMap` |
|---|---|---|---|---|
| `before insert` | yes (no Ids) | **no** (no Ids) | no | no |
| `before update` | yes | yes | yes | yes |
| `before delete` | no | no | yes | yes |
| `after insert` | yes (Ids assigned) | yes | no | no |
| `after update` | yes | yes | yes | yes |
| `after delete` | no | no | yes | yes |
| `after undelete` | yes (restored Ids) | yes | no | no |

### 8.2 What belongs where

| Need | Context | Why |
|---|---|---|
| Default field value | `before insert` | Modify `Trigger.new` directly — no DML, auto-committed |
| Derive field from same record | `before insert` / `before update` | No DML required |
| Validation blocking the save | `before *` | `record.addError()` only works in before contexts |
| Create related child records | `after insert` / `after update` | Parent Id must exist |
| Update parent record | `after insert` / `after update` | Gate with change detection + recursion guard |
| Send email / publish Platform Event | `after *` | Only after commit is known |
| HTTP callout | **never directly** | Enqueue a `Queueable implements Database.AllowsCallouts` from after context |
| Prevent deletion | `before delete` | `addError()` blocks the DML |
| Archive after deletion | `after delete` | Record is committed as deleted |
| Restore related records | `after undelete` | Record's Id is restored |

### 8.3 Hard rules

- Never DML on the triggering record from a before context — modify `Trigger.new` in place; DML is automatic.
- Never call `record.addError()` from an after context — silently ignored.
- Never make an HTTP callout from a trigger — enqueue a Queueable from `after *`.
- Never reference `Trigger.new` in a delete context, or `Trigger.old` in an insert context — `null`.
- Never use `Trigger.newMap` in `before insert` — records have no Id yet, map is null.

### 8.4 Don't declare contexts you don't handle

Each declared context is a separate trigger invocation per transaction. Declaring `before insert` "for completeness" when no before-insert handler exists is wasted overhead — and in Plusgrade specifically, before-save logic on Case lives in `Case_BS_Normalize_Case` Flow, not in Apex.

```apex
// WRONG — declares before contexts the handler doesn't own
trigger CaseTrigger on Case (before insert, before update, after insert, after update) {
   CaseTriggerHandler.run(...);   // handler has no BEFORE_* branches
}

// RIGHT — declare only the contexts the handler actually owns
trigger CaseTrigger on Case (after insert, after update, after delete, after undelete) {
   CaseTriggerHandler.run(...);
}
```

---

## 9. Change Detection — the Idempotency Lever

Every `after update` should filter to records where the relevant field actually changed.

### 9.1 Single-field

```apex
List<Case> statusChanged = new List<Case>();
for (Case c : newList) {
   if (c.Status != oldMap.get(c.Id).Status) statusChanged.add(c);
}
if (!statusChanged.isEmpty()) CaseService.handleStatusChange(statusChanged, oldMap);
```

### 9.2 Multi-field

```apex
List<Case> changed = new List<Case>();
for (Case c : newList) {
   Case prior = oldMap.get(c.Id);
   if (c.Priority != prior.Priority || c.Status != prior.Status || c.OwnerId != prior.OwnerId) {
      changed.add(c);
   }
}
```

### 9.3 Transition-to helper

```apex
/**
 * Returns the subset of cases that transitioned TO targetStatus in this update.
 */
public static List<Case> transitionedTo(
   List<Case> newList, Map<Id, Case> oldMap, String targetStatus
) {
   List<Case> out = new List<Case>();
   for (Case c : newList) {
      Case prior = oldMap.get(c.Id);
      if (c.Status == targetStatus && prior.Status != targetStatus) out.add(c);
   }
   return out;
}
```

---

## 10. Trigger + Flow Coexistence

Plusgrade orgs run both triggers and Record-Triggered Flows on the same objects. Coordination is mandatory.

### 10.1 Order of Execution (simplified)

1. System validation rules
2. Apex **before** triggers
3. Record-triggered Flows (**before-save**)
4. Assignment rules, auto-response rules
5. Workflow rules, processes
6. Escalation rules
7. Apex **after** triggers
8. Record-triggered Flows (**after-save**)
9. Post-commit (emails, async)

Authoritative order: <https://help.salesforce.com/s/articleView?id=sf.flow_concepts_trigger_order_of_execution.htm>

### 10.2 Conflict scenarios

| Scenario | Risk | Resolution |
|---|---|---|
| Trigger sets Field A → before-save Flow reads A | Generally safe — trigger before runs first | Document ownership |
| Trigger fires → after-save Flow DMLs related record → that record's trigger fires the parent | Infinite loop | Recursion guard + entry condition in Flow |
| Flow sets Field A → after trigger reacts to A | After-save Flow re-fires the trigger | Change detection so unchanged fields skip |
| Both trigger and Flow create child records of the same type | Duplicate children | Single-owner rule per record type |

### 10.3 Coexistence rules

- **Document ownership.** Every object has a design doc listing which automation owns which behavior. Never two automations doing the same thing.
- **Change detection in both.** A trigger's recursion guard doesn't help when a Flow legitimately updates a field — the trigger should still check whether the relevant field changed.
- **Single owner per child-record type.** If the trigger creates Task records on Case insert, the Flow does not also create Tasks.
- **Test against active Flows.** A trigger test in a sandbox without the production Flow active does not validate the real interaction.
- **Plusgrade PlusGradeFullSB:** field normalization on Case lives in `Case_BS_Normalize_Case` (before-save Flow, triggerOrder 10). Do not duplicate that in a before trigger. See `CLAUDE.md` §3 for the full ownership table.

### 10.4 Bypass flag

```apex
// Custom field Trigger_Bypass_Active__c (checkbox) or Trigger_Bypass__mdt rows
public static void onAfterUpdate(List<Case> newList, Map<Id, Case> oldMap) {
   List<Case> toProcess = new List<Case>();
   for (Case c : newList) {
      if (!c.Trigger_Bypass_Active__c) toProcess.add(c);
   }
   if (!toProcess.isEmpty()) CaseService.processUpdates(toProcess, oldMap);
}
```

---

## 11. Delete / Undelete

### 11.1 `before delete` — validation

```apex
public static void onBeforeDelete(List<Case> oldList) {
   for (Case c : oldList) {
      if (c.Status == 'Open' || c.Status == 'In Progress') {
         c.addError('Active cases cannot be deleted. Close the case first.');
      }
   }
}
```

`Trigger.old` is the only collection. `addError()` on a record blocks just that record in partial DML, the whole DML in all-or-none.

### 11.2 `after delete` / `after undelete`

```apex
public static void onAfterDelete(List<Case> oldList) {
   Set<Id> deletedIds = new Map<Id, Case>(oldList).keySet();
   CaseService.archiveRelatedData(deletedIds);
}

public static void onAfterUndelete(List<Case> newList) {
   Set<Id> restoredIds = new Map<Id, Case>(newList).keySet();
   CaseService.restoreRelatedData(restoredIds);
}
```

Undelete is frequently omitted from coverage. If the trigger declares `after undelete`, the test class MUST cover it — restored related records often need their own `Database.undelete()` call, which is a separate code path.

---

## 12. Bulkification — Non-Negotiable

Salesforce guarantees up to 200 records per trigger invocation. Every handler, service method, and helper must be safe at 200. Governor limits per transaction: 100 SOQL queries, 150 DML statements, 10,000 DML rows.

```apex
// WRONG — SOQL and DML inside the loop
for (Case c : newList) {
   Account a = [SELECT Name FROM Account WHERE Id = :c.AccountId];   // SOQL in loop
   c.Description = a.Name;
   update c;                                                          // DML in loop
}
```

```apex
// RIGHT — collect, query once, build map, process in memory
Set<Id> accountIds = new Set<Id>();
for (Case c : newList) {
   if (c.AccountId != null) accountIds.add(c.AccountId);
}

Map<Id, Account> accountsById = new Map<Id, Account>(
   [SELECT Id, Name FROM Account WHERE Id IN :accountIds WITH USER_MODE]
);

for (Case c : newList) {
   Account a = accountsById.get(c.AccountId);
   if (a != null) c.Description = a.Name;       // before context — auto-committed
}
```

### Patterns to internalize

| Pattern | Why |
|---|---|
| `Set<Id>` of parent Ids → one SOQL → `Map<Id, SObject>` | O(1) per-record access, one query total |
| `Map<Id, List<SObject>>` to group children by parent | Group once, iterate in O(n) |
| Relationship subqueries when parent + child both needed | One SOQL replaces two |
| `AggregateResult` + `GROUP BY` for counts/sums | Replaces query + Apex loop count |
| Only DML records that actually changed | Compare to `oldMap` before adding to update list |
| `Limits.getQueries()` / `getDmlStatements()` mid-handler | Sanity check before you ship |

### USER_MODE everywhere

```apex
List<Case> cases = [SELECT Id, Status FROM Case WHERE AccountId IN :accountIds WITH USER_MODE];
Database.update(cases, AccessLevel.USER_MODE);
```

`WITH USER_MODE` (replaces older `WITH SECURITY_ENFORCED`) enforces CRUD + FLS for the running user. Use it unless the entry point is an explicitly `without sharing` service with a Custom Permission gate.

---

## 13. Testing — 200 Records Or It Didn't Happen

Every trigger context that runs in production needs a 200-record test. Single-record tests don't validate bulkification.

```apex
@isTest
static void testBulkInsert_200() {
   List<Case> cases = new List<Case>();
   for (Integer i = 0; i < 200; i++) {
      cases.add(new Case(Subject = 'T' + i, Status = 'New'));
   }
   Test.startTest();
   insert cases;
   Test.stopTest();
   System.assertEquals(200, [SELECT COUNT() FROM Case WHERE Subject LIKE 'T%']);
}

@isTest
static void testBulkUpdate_changeDetection_200() {
   List<Case> cases = new List<Case>();
   for (Integer i = 0; i < 200; i++) cases.add(new Case(Subject='C'+i, Priority='Medium', Status='New'));
   insert cases;

   for (Integer i = 0; i < 100; i++) cases[i].Priority = 'Critical';   // only half change
   Test.startTest();
   update cases;
   Test.stopTest();
   System.assertEquals(100, [SELECT COUNT() FROM Case_Escalation__c],
      'Only changed records should escalate');
}

@isTest
static void testRecursionGuard_noInfiniteLoop() {
   Case c = new Case(Subject = 'R', Status = 'New');
   insert c;
   Test.startTest();
   c.Status = 'In Progress';
   update c;
   Test.stopTest();
   System.assert(Limits.getQueries() < 50, 'Recursion guard limited SOQL');
}
```

For Plusgrade PlusGradeFullSB: **test classes are deferred until after sandbox functional testing** (see `CLAUDE.md` §3). Still write them — just don't gate the deploy on them.

---

## 14. Definition of Done

- [ ] Exactly one trigger exists for the object (confirmed via retrieve + audit query).
- [ ] Trigger body is a single dispatch call. No `if`, no SOQL, no DML, no `for`.
- [ ] Handler uses `switch on Trigger.operationType` **or** `new MetadataTriggerHandler().run()` (TAF).
- [ ] Recursion guard chosen and justified (boolean, `Set<Id>`, or field-value comparison).
- [ ] Static guard wrapped in `try { ... } finally { isRunning = false; }`.
- [ ] All declared contexts have handler branches; undeclared contexts removed from signature.
- [ ] Every `after update` filters by change detection — only changed records reach the service.
- [ ] All SOQL outside loops. All DML outside loops. `WITH USER_MODE` / `AccessLevel.USER_MODE`.
- [ ] Sharing keyword declared on handler + service. `with sharing` by default; `without sharing` only with Custom Permission gate.
- [ ] No hardcoded record Type Ids — use `Schema.SObjectType.<Sobj>.getRecordTypeInfosByDeveloperName()`.
- [ ] No HTTP callouts in trigger — enqueued via Queueable (`Database.AllowsCallouts`).
- [ ] No `@future` methods — project prohibits them. Use Queueable + `System.Finalizer`.
- [ ] Test class: bulk-200 per context + recursion + negative + change-detection scenarios.
- [ ] Check-only deploy passes with `--test-level RunLocalTests`.
- [ ] For Plusgrade: new flows deploy `status = Draft`; no manual deactivation of old triggers.

---

## 15. Naming

| Artifact | Pattern | Example |
|---|---|---|
| Trigger file | `{SObject}Trigger` | `CaseTrigger.trigger` |
| Custom handler | `{SObject}TriggerHandler` | `CaseTriggerHandler.cls` |
| TAF action | `TA_{SObject}_{Concern}` | `TA_Case_SetDefaults.cls` |
| Service | `{SObject}Service` | `CaseService.cls` |
| Selector | `{SObject}Selector` | `CaseSelector.cls` |
| Domain | `{SObject}Domain` | `CaseDomain.cls` |
| Test class | `{Service}Test` / `{Handler}Test` | `CaseServiceTest.cls` |

Class names PascalCase. Methods camelCase, verb-first (`onBeforeInsert`, `handleEscalation`). Maps `{value}By{key}` (`accountsById`). Sets `{noun}Ids` (`escalatedCaseIds`).

---

## 16. Validation Commands

```bash
# Audit existing triggers
sf data query \
   --query "SELECT Name, TableEnumOrId, Status FROM ApexTrigger ORDER BY TableEnumOrId" \
   --target-org PlusGradeFullSB --result-format human

# Retrieve current trigger + handler before modifying
sf project retrieve start \
   --metadata "ApexTrigger:CaseTrigger,ApexClass:CaseTriggerHandler" \
   --target-org PlusGradeFullSB

# Check-only deploy
sf project deploy start \
   --manifest manifest/package-case-flow-optimization.xml \
   --target-org PlusGradeFullSB \
   --dry-run --test-level RunLocalTests --wait 60

# Run a specific test class
sf apex run test \
   --class-names CaseServiceTest \
   --target-org PlusGradeFullSB \
   --result-format human --wait 10
```

---

## 17. Common AI Mistakes to Avoid

| # | Mistake | Correct approach |
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

## 18. Empirical Findings & Implementation Notes

When Salesforce's documented approach doesn't work in this org, the workaround goes here. Date-stamp every entry.

| # | Date | Documented approach | What actually works | Why / Context |
|---|---|---|---|---|

---

## 19. Official References

- [Apex Triggers — Developer Guide](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_triggers.htm)
- [Apex Trigger Best Practices](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_triggers_bp.htm)
- [Bulk Trigger Idioms](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_triggers_bulk_idioms.htm)
- [Trigger Context Variables](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_triggers_context_variables.htm)
- [Order of Execution (Triggers + Flows)](https://help.salesforce.com/s/articleView?id=sf.flow_concepts_trigger_order_of_execution.htm)
- [Apex Governor Limits](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_gov_limits.htm)
- [Apex Security and Sharing](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_security_sharing_understand.htm)
- [Queueable Apex](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_queueing_jobs.htm)
- [Mitch Spano — Apex Trigger Actions Framework](https://github.com/mitchspano/apex-trigger-actions-framework)
- [`forcedotcom/sf-skills` generating-apex](https://github.com/forcedotcom/sf-skills/tree/main/skills/generating-apex)
- [`trailheadapps/agent-script-recipes` APEX_RULES](https://github.com/trailheadapps/agent-script-recipes/blob/main/.airules/APEX_RULES.md)

---

*Apex Trigger Guidelines | v3.0 | Last verified 2026-05-16*
