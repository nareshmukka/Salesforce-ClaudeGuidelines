---
name: salesforce-flow
description: Production Salesforce AI skill for Record-triggered/autolaunched/screen flow design or XML review.
license: Apache-2.0
compatibility:
  - Claude Code
  - Claude Agents
  - Codex / ChatGPT
  - GitHub Copilot
metadata:
  version: 2.0.0
  last_updated: 2026-05-16
  owner: Naresh Salesforce AI Skills Library
---

## TRIGGER when
- The task involves Record-triggered/autolaunched/screen flow design or XML review.
- The user asks for implementation, refactor, troubleshooting, review, or best-practice validation in this area.
- The assistant must produce Salesforce-safe code/metadata with explicit security/testing notes.

## DO NOT TRIGGER when
- The task is unrelated to this component.
- Another specialized skill is the primary owner and this area is only incidental.
- The user asks for operational execution (deploy/publish/activate/destructive change) without explicit approval.

## Cross-skill routing
- Always read `../salesforce-global-development/SKILL.md`.
- Also read: Global Development + Integration + Observability + Testing.
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
Before-save for same-record field updates; after-save for related records/actions. Add fault paths for DML/actions. Avoid DML inside loops; collect and perform bulk updates. Ensure idempotency with entry criteria/change checks.

## Upstream Salesforce Skill Patterns
- For net-new Flow generation in tools that provide Salesforce metadata actions, follow the grounded generation pipeline: fetch object metadata, select elements, then generate elements until complete.
- For manual Flow work in this repo, first scan local object/field metadata and document every input/output contract before editing XML.
- Split multi-flow requests into one focused flow design at a time; do not combine unrelated automations into a single prompt, file, or validation cycle.
- Keep schema context structured: object API name, field API name, field type, picklist values, and lookup target. Do not mix requirements text into schema context.
- Manual XML edits are acceptable only for targeted fixes, existing-flow maintenance, or deployment-error repair; preserve generated element structure unless the requested fix requires a change.
- Verify the final flow type, trigger order, entry criteria, fault paths, status, and activation plan before reporting.

## Examples
### Good example patterns
1. Before-save flow normalizes Case fields without extra DML.
2. After-save flow creates related record via collection + single create element.

### Bad examples / avoid
1. After-save flow updates triggering record repeatedly causing recursion.
2. No fault path on Create/Update/Action elements.

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

## Flow-specific implementation rules
- Decision tree: before-save for in-record updates, after-save for related writes/actions, autolaunched for reusable orchestration, screen flows for guided UX.
- Optimize Get Records filters and avoid unbounded queries.
- Use naming conventions by object/scope/purpose and maintain description fields.
- Add fault paths for each DML/action and route to logging/notification paths.
- Activation/deployment requires explicit approval gates; draft/validate first.


## Full Guidance

# Flow Guidelines -- Salesforce Flow Authoring Reference

Authoritative reference for record-triggered, autolaunched, screen, scheduled, and platform-event flows in this project. Single source of truth for flow XML structure, ordering rules, and Plusgrade-specific conventions.

**Verified against:** [Flow Metadata API](https://developer.salesforce.com/docs/atlas.en-us.api_meta.meta/api_meta/meta_visual_workflow.htm) - [Flow Order of Execution](https://help.salesforce.com/s/articleView?id=sf.flow_concepts_trigger_order_of_execution.htm) - [Record-Triggered Flow Best Practices](https://help.salesforce.com/s/articleView?id=sf.flow_concepts_rt_bestpractices.htm) - [Fault Paths](https://help.salesforce.com/s/articleView?id=sf.flow_build_fault_paths.htm) - `forcedotcom/sf-skills/skills/generating-flow/SKILL.md` - CLAUDE.md (Plusgrade PlusGradeFullSB). Last verified 2026-05-16.

> **Project policy (CLAUDE.md):** Deploy every flow as `status: Draft`. Naresh activates manually after sandbox validation. **Do NOT deactivate or delete old flows** -- Naresh handles cutover. Per-object trigger ordering uses the 10/20/30/40/50 convention (see Section 3 1. Flow Types -- Decision Matrix

| Type | When | DML allowed | Callouts | XML `start.triggerType` |
|---|---|---|---|---|
| **Before-Save Record-Triggered** | Set/derive fields on the same record | No DML on other records | No | `RecordBeforeSave` |
| **After-Save Record-Triggered** | Create/update related records, send email, invoke Apex, publish PE | Yes | Via Apex invocable | `RecordAfterSave` |
| **Scheduled-Triggered** | Recurring batch jobs | Yes | Via Apex invocable | `Scheduled` |
| **Platform Event-Triggered** | React to a PE message | Yes | Via Apex invocable | `PlatformEvent` |
| **Autolaunched (no trigger)** | Reusable subflow, called from Apex/REST/Flow | Yes | Via Apex invocable | omit `triggerType` |
| **Screen** | User-guided UI | Yes | Via Apex invocable | omit `triggerType` |

### Before-Save vs After-Save -- pick the right one

| Need | Use |
|---|---|
| Set a field on the saving record | **Before-Save** |
| Derive a value from the record's own fields | **Before-Save** |
| Create/update a related record | After-Save |
| Send an email, post to Chatter | After-Save |
| Invoke Apex for a callout or PE publish | After-Save |
| Update the triggering record itself | **Before-Save** (NEVER After-Save -- causes recursion) |

---

## 2. Order of Execution (record save)

```
1. System Validation (required fields, formats)
2. Apex BEFORE triggers
3. Before-Save Record-Triggered Flows         <- runs here
4. Duplicate / other system validations
5. Record committed to database
6. Apex AFTER triggers
7. After-Save Record-Triggered Flows          <- runs here
8. Assignment / Auto-response / Escalation rules
9. Workflow Rules (legacy), Processes (legacy)
10. Roll-up summary, criteria-based sharing, post-commit
```

Implications:
- Apex BEFORE triggers see the original value; Before-Save Flow sees whatever Apex BEFORE set.
- Apex AFTER triggers see the record committed; After-Save Flow sees whatever Apex AFTER created/updated.
- Never have both an Apex AFTER trigger and an After-Save Flow create the same related record -- duplicates.

---

## 3. `triggerOrder` -- Multiple Flows Per Object

Salesforce allows multiple record-triggered flows on the same object. Without `triggerOrder` they run in an undefined order. **This project uses a 10/20/30/40/50 spacing convention** (CLAUDE.md) so future flows can slot in (15, 25, 35) without renumbering.

| Flow | `triggerOrder` | Purpose |
|---|---|---|
| `Case_BS_Normalize_Case` | 10 (before-save) | Field normalization, defaulting |
| `Case_AS_Status_SLA` | 10 | Status log, SLA timestamps, RH SLA calcs |
| `Case_AS_Escalation` | 20 | Child case creation on escalation |
| `Case_AS_Linked_Case` | 30 | `Linked_Case__c` for duplicate/merge/split |
| `Case_AS_Routing` | 40 | Owner follower, product lookup, PBU |
| `Case_AS_Notifications` | 50 | Nexus email alerts |

XML:

```xml
<start>
   <locationX>0</locationX>
   <locationY>0</locationY>
   <connector><targetReference>Decision_Entry</targetReference></connector>
   <filterFormula>...</filterFormula>
   <object>Case</object>
   <recordTriggerType>Update</recordTriggerType>
   <triggerType>RecordAfterSave</triggerType>
</start>
<triggerOrder>20</triggerOrder>
```

`triggerOrder` is a sibling of `start`, not inside it. Range: 1--2000.

### File naming convention (Case domain)

| Prefix | Meaning | Example |
|---|---|---|
| `_BS_` | Before-Save Record-Triggered | `Case_BS_Normalize_Case` |
| `_AS_` | After-Save Record-Triggered | `Case_AS_Status_SLA` |
| `_SC_` | Scheduled | `Case_SC_Reminder_24h` |
| `_AL_` | Autolaunched | `Case_AL_Build_Description` |
| `_SF_` | Screen Flow | `Case_SF_Quick_Create` |
| `_SUB_` | Subflow (reusable) | `Util_SUB_Log_Error` |

---

## 4. Flow XML Skeleton

Every flow file lives at `force-app/main/default/flows/<API_Name>.flow-meta.xml`. The XML schema is positional -- **elements must appear in strict alphabetical order** (Common AI Mistakes #25); Flow Builder re-sorts on first open, producing noisy diffs if you don't.

```xml
<?xml version="1.0" encoding="UTF-8"?>
<Flow xmlns="http://soap.sforce.com/2006/04/metadata">
   <actionCalls>...</actionCalls>          <!-- 0+ -->
   <apiVersion>62.0</apiVersion>
   <areMetricsLoggedToDataCloud>false</areMetricsLoggedToDataCloud>
   <assignments>...</assignments>          <!-- 0+ -->
   <decisions>...</decisions>              <!-- 0+ -->
   <description>...</description>
   <environments>Default</environments>
   <formulas>...</formulas>                <!-- 0+ -->
   <interviewLabel>Case_AS_Status_SLA {!$Flow.CurrentDateTime}</interviewLabel>
   <label>Case AS Status SLA</label>
   <processMetadataValues>                 <!-- BuilderType -->
      <name>BuilderType</name>
      <value><stringValue>LightningFlowBuilder</stringValue></value>
   </processMetadataValues>
   <processMetadataValues>                 <!-- CanvasMode -->
      <name>CanvasMode</name>
      <value><stringValue>AUTO_LAYOUT_CANVAS</stringValue></value>
   </processMetadataValues>
   <processType>AutoLaunchedFlow</processType>
   <recordCreates>...</recordCreates>      <!-- 0+ -->
   <recordLookups>...</recordLookups>      <!-- 0+ -->
   <recordUpdates>...</recordUpdates>      <!-- 0+ -->
   <start>...</start>
   <status>Draft</status>
   <triggerOrder>10</triggerOrder>
   <variables>...</variables>              <!-- 0+ -->
</Flow>
```

**Critical:**
- Both `processMetadataValues` blocks (BuilderType + CanvasMode) are required -- without them, Flow shows as "built with Cloud Flow Designer" and cannot be edited (Mistakes #21).
- Every element uses `<locationX>0</locationX><locationY>0</locationY>` when `CanvasMode=AUTO_LAYOUT_CANVAS` (Mistakes #22).
- `<status>Draft</status>` -- never `Active` (project policy).
- No XML comments anywhere (Flow Builder strips them on save).

---

## 5. `start` Element -- Entry Criteria

```xml
<start>
   <locationX>0</locationX>
   <locationY>0</locationY>
   <connector><targetReference>Decision_RT_Gate</targetReference></connector>
   <filterFormula>ISCHANGED({!$Record.Status})
      &amp;&amp; ($Record.RecordType.DeveloperName = 'SBU_GC'
      || $Record.RecordType.DeveloperName = 'HRG_CS')</filterFormula>
   <object>Case</object>
   <recordTriggerType>CreateAndUpdate</recordTriggerType>
   <triggerType>RecordAfterSave</triggerType>
</start>
```

| Field | Required for | Notes |
|---|---|---|
| `object` | record-triggered | API name of triggering SObject |
| `recordTriggerType` | record-triggered | `Create`, `Update`, `CreateAndUpdate`, `Delete` |
| `triggerType` | record-triggered, scheduled, PE | `RecordBeforeSave`, `RecordAfterSave`, `Scheduled`, `PlatformEvent` |
| `filterFormula` | recommended | Formula expression; preferred over `filters` for OR/mixed logic |
| `filters` | alternative | Block-form AND-only filter; use `filterFormula` instead for project consistency |
| `schedule` | scheduled | Sub-block: `startDate`, `startTime`, `frequency` |

### Entry filter rules

| Rule | Why |
|---|---|
| Always define a filter -- never blank, never `Always` | Performance; avoid running on every save (Mistakes #5) |
| Use `ISCHANGED(field)` for "fires only when field changed" | Not `IsNull = false` -- that fires on every save (Mistakes #51) |
| For merge detection: `ISCHANGED(MasterRecordId) && NOT(ISBLANK(MasterRecordId))` | Without `ISCHANGED`, every later update re-fires (Mistakes #44) |
| Include RecordType gate in `filterFormula` when business logic is RT-specific | Don't rely on internal decisions alone (Mistakes #43) |
| Use `CreateAndUpdate` when the business process can originate on create | `Update` silently skips new records with pre-populated fields (Mistakes #42) |
| For "field changed FROM X" use prior-value check | `$Record__Prior.Field = 'X' AND $Record.Field != 'X'` (Mistakes #37) |

---

## 6. Element Types -- Reference

### Decision (`<decisions>`)

```xml
<decisions>
   <name>Decision_StatusOrNew</name>
   <label>Status change or new case?</label>
   <locationX>0</locationX>
   <locationY>0</locationY>
   <defaultConnector>
      <targetReference>End_NoOp</targetReference>
   </defaultConnector>
   <defaultConnectorLabel>No relevant change</defaultConnectorLabel>
   <rules>
      <name>StatusChangedToClosed</name>
      <conditionLogic>1 AND 2</conditionLogic>
      <conditions>
         <leftValueReference>$Record.Status</leftValueReference>
         <operator>EqualTo</operator>
         <rightValue><stringValue>Closed</stringValue></rightValue>
      </conditions>
      <conditions>
         <leftValueReference>$Record__Prior.Status</leftValueReference>
         <operator>NotEqualTo</operator>
         <rightValue><stringValue>Closed</stringValue></rightValue>
      </conditions>
      <connector><targetReference>RecordCreate_StatusLog</targetReference></connector>
      <label>Status changed to Closed</label>
   </rules>
</decisions>
```

| Rule | Detail |
|---|---|
| `defaultConnector` | **Required** for every non-terminal decision -- silent dead end if missing (Mistakes #26) |
| `conditionLogic` | `and`, `or`, or numeric expression `1 AND 2 AND (3 OR 4)` for mixed logic (Mistakes #29) |
| Rule naming | Positive statements: `IsEligibleForPromotion`, not `Yes`/`Branch1` |
| Don't repeat RT/IsNew checks inside an RT-gated branch | Rely on the upstream gate (Mistakes #34) |

### Assignment (`<assignments>`)

```xml
<assignments>
   <name>Assignment_StampSLA</name>
   <label>Stamp SLA start time</label>
   <locationX>0</locationX>
   <locationY>0</locationY>
   <assignmentItems>
      <assignToReference>$Record.SLA_Start__c</assignToReference>
      <operator>Assign</operator>
      <value><elementReference>$Flow.CurrentDateTime</elementReference></value>
   </assignmentItems>
   <connector><targetReference>Decision_Next</targetReference></connector>
</assignments>
```

Before-save flows: assign directly to `$Record.Field__c` -- no DML needed.
Terminal assignments must **omit** `<connector>` entirely -- leaving the connector pointed at downstream logic leaks early-exit cases into the main path (Mistakes #33).

### Record Lookup (`<recordLookups>`) -- Get Records

```xml
<recordLookups>
   <name>GetRecords_OpenStatusLog</name>
   <label>Get open status log</label>
   <locationX>0</locationX>
   <locationY>0</locationY>
   <assignNullValuesIfNoRecordsFound>true</assignNullValuesIfNoRecordsFound>
   <connector><targetReference>Decision_LogExists</targetReference></connector>
   <filterLogic>and</filterLogic>
   <filters>
      <field>Case__c</field>
      <operator>EqualTo</operator>
      <value><elementReference>$Record.Id</elementReference></value>
   </filters>
   <filters>
      <field>End_Time__c</field>
      <operator>IsNull</operator>
      <value><booleanValue>true</booleanValue></value>
   </filters>
   <getFirstRecordOnly>true</getFirstRecordOnly>
   <object>Status_Log__c</object>
   <queriedFields>Id</queriedFields>
   <storeOutputAutomatically>true</storeOutputAutomatically>
</recordLookups>
```

Best practice:
- Idempotency lookups must include `End_Time__c IS NULL` (or the equivalent "open record" indicator) -- otherwise a previously-closed record satisfies the filter (Mistakes #39).
- Add `<queriedFields>Id</queriedFields>` when only `Id` is used downstream -- avoid full-record SOQL transfer (Mistakes #41).
- Get Records does NOT throw -- no fault path needed.

### Record Create / Update / Delete

Every `recordCreates`, `recordUpdates`, `recordDeletes` MUST have a fault connector to `FaultEnd` (or `Util_SUB_Log_Error` subflow):

```xml
<recordCreates>
   <name>RecordCreate_StatusLog</name>
   <label>Create status log</label>
   <locationX>0</locationX>
   <locationY>0</locationY>
   <connector><targetReference>End_Success</targetReference></connector>
   <faultConnector><targetReference>FaultEnd</targetReference></faultConnector>
   <inputAssignments>
      <field>Case__c</field>
      <value><elementReference>$Record.Id</elementReference></value>
   </inputAssignments>
   <inputAssignments>
      <field>Status__c</field>
      <value><elementReference>$Record.Status</elementReference></value>
   </inputAssignments>
   <object>Status_Log__c</object>
</recordCreates>
```

Field references for `<inputAssignments>`:
- Literal: `<stringValue>X</stringValue>`, `<numberValue>5</numberValue>`, `<booleanValue>true</booleanValue>`
- Variable/formula: `<elementReference>name</elementReference>`
- Never hardcode IDs -- use Custom Label + formula resource (Mistakes #48).

### Action Call (`<actionCalls>`) -- Apex / Email / Submit-for-Approval

```xml
<actionCalls>
   <name>InvokeApex_EscalateCase</name>
   <label>Escalate case</label>
   <locationX>0</locationX>
   <locationY>0</locationY>
   <actionName>CaseEscalationService</actionName>
   <actionType>apex</actionType>
   <connector><targetReference>End_Success</targetReference></connector>
   <faultConnector><targetReference>FaultEnd</targetReference></faultConnector>
   <inputParameters>
      <name>caseIds</name>
      <value><elementReference>col_CaseIds</elementReference></value>
   </inputParameters>
</actionCalls>
```

| `actionType` | `actionName` |
|---|---|
| `apex` | Exact Apex class name (NOT method, NOT label -- Mistakes #30) |
| `emailAlert` | `<ObjectAPIName>.<EmailAlertAPIName>` |
| `submit` | Submit for Approval action |
| `flow` | Subflow invocation (use `<subflows>` instead, see below) |

**Every `actionCalls` block needs a `faultConnector` -- including `emailAlert` (Mistakes #52).**

### Subflow (`<subflows>`)

```xml
<subflows>
   <name>Subflow_LogError</name>
   <label>Log error</label>
   <locationX>0</locationX>
   <locationY>0</locationY>
   <connector><targetReference>End_Fault</targetReference></connector>
   <flowName>Util_SUB_Log_Error</flowName>
   <inputAssignments>
      <name>input_FlowName</name>
      <value><stringValue>Case_AS_Status_SLA</stringValue></value>
   </inputAssignments>
   <inputAssignments>
      <name>input_RecordId</name>
      <value><elementReference>$Record.Id</elementReference></value>
   </inputAssignments>
   <inputAssignments>
      <name>input_ErrorMessage</name>
      <value><elementReference>$Flow.FaultMessage</elementReference></value>
   </inputAssignments>
</subflows>
```

### Formula (`<formulas>`)

```xml
<formulas>
   <name>formula_IsSBUGC</name>
   <dataType>Boolean</dataType>
   <expression>{!$Record.RecordType.DeveloperName} = 'SBU_GC'</expression>
</formulas>
```

| Rule | Detail |
|---|---|
| After-save flows must use `PRIORVALUE({!$Record.Field})` -- NOT `$Record__Prior.Field` | Direct prior reference only works in before-save entry conditions (Mistakes #28) |
| Use Custom Labels for IDs | `LEFT(PRIORVALUE({!$Record.OwnerId}), 15) = {!$Label.Case_Routing_PSC_Queue_Id}` (Mistakes #48) |
| Reference RecordType by DeveloperName | `$Record.RecordType.DeveloperName = 'SBU_GC'` -- never hardcoded ID (Mistakes #35) |

### Variables (`<variables>`)

```xml
<variables>
   <name>col_CasesToUpdate</name>
   <dataType>SObject</dataType>
   <isCollection>true</isCollection>
   <isInput>false</isInput>
   <isOutput>false</isOutput>
   <objectType>Case</objectType>
</variables>
```

Naming standard (project):

| Type | Pattern | Example |
|---|---|---|
| Input | `input_<Name>` | `input_CaseId` |
| Output | `output_<Name>` | `output_Success` |
| Boolean | `var_Is<State>` | `var_IsVerified` |
| Record | `var_<Object>Record` | `var_CaseRecord` |
| Collection | `col_<Object>List` | `col_TaskList` |
| Formula | `formula_<Name>` | `formula_IsSBUGC` |
| Constant | `const_<Name>` | `const_MaxRetries` |
| Counter | `var_<Name>Count` | `var_RetryCount` |

---

## 7. Fault Paths -- Mandatory

| Element | Fault path required? |
|---|---|
| `recordCreates`, `recordUpdates`, `recordDeletes` | **YES** |
| `actionCalls` (apex, emailAlert, submit, customAction) | **YES** |
| `subflows` (if callee can throw) | **YES** |
| `assignments`, `decisions`, `formulas`, `recordLookups`, `loops`, `screens` | No |

Standard fault tail:

```xml
<assignments>
   <name>FaultEnd</name>
   <label>Capture fault message</label>
   <locationX>0</locationX>
   <locationY>0</locationY>
   <assignmentItems>
      <assignToReference>var_FaultMessage</assignToReference>
      <operator>Assign</operator>
      <value><elementReference>$Flow.FaultMessage</elementReference></value>
   </assignmentItems>
   <connector><targetReference>Subflow_LogError</targetReference></connector>
</assignments>
```

`FaultEnd` is **only** a target of `<faultConnector>` -- never of a Decision `<defaultConnector>` (Mistakes #27). `$Flow.FaultMessage` is null on non-fault paths, so a misrouted `FaultEnd` reads null and silently no-ops.

Capture `$Flow.FaultMessage` immediately -- it's overwritten by the next element.

---

## 8. Bulkification -- Loop Rules

```
INSIDE A LOOP -- allowed:        INSIDE A LOOP -- FORBIDDEN:
- Assignment                     - recordCreates / recordUpdates / recordDeletes
- Decision                       - actionCalls (any type)
- Formula reference              - recordLookups (SOQL in loop)
- Build collection (add)         - subflows (if they DML)
- Increment counters
```

Correct pattern:

```
Loop: ForEachCase
   "" Decision: NeedsUpdate?
   "‚     """ YES -> Assignment: AddToCollection (col_CasesToUpdate ADD var_LoopCase)
   """ Default -> continue
[End Loop]
Decision: AnyToUpdate? (col_CasesToUpdate size > 0)
   """ YES -> recordUpdates: BulkUpdate (collection: col_CasesToUpdate)
              """ [Fault] -> FaultEnd -> Subflow_LogError -> End
```

---

## 9. Before-Save Flow -- Constraints

| Allowed | Forbidden |
|---|---|
| `assignments` (to `$Record.Field__c`) | `recordUpdates` (Mistakes #31) |
| `decisions` | `actionCalls` (any type) |
| `formulas` | `recordCreates` on other objects (anti-pattern) |
| `recordLookups` (rare -- `$Record` already available) | `subflows` that DML |
| `loops` | callouts (impossible) |

Before-save flows assign directly to `$Record.FieldName__c` -- the platform persists the value as part of the save. No DML element needed and no recursion possible because the record isn't yet committed.

**Use `$Record__Prior.Field` directly** in before-save entry conditions and rule conditions. In after-save formula resources, use `PRIORVALUE({!$Record.Field})` instead (Mistakes #28).

---

## 10. After-Save Flow -- Recursion & Idempotency

### Recursion prevention

| Strategy | Implementation |
|---|---|
| Specific entry criteria | `ISCHANGED(Status)` + RecordType gate in `filterFormula` |
| Never update the triggering record in After-Save | Use Before-Save instead (Mistakes #4) |
| Idempotency lookup before Create | Get Records + Decision (see below) |
| Bypass flag | Custom field `By_Pass__c` set by an upstream flow; gate downstream flows with `By_Pass__c = false` (Mistakes #40) |

### Idempotency pattern (mandatory for any after-save Create Records)

```
1. recordLookups: GetExisting   WHERE Case__c = $Record.Id
                                  AND End_Time__c IS NULL    <- always include open-record clause
                                <queriedFields>Id</queriedFields>
                                getFirstRecordOnly: true
                                storeOutputAutomatically: true
2. decisions: AlreadyExists?
     - rule "Exists":  var.Id != null -> connect to End
     - default "DoesNotExist" -> continue to Create
3. recordCreates: CreateRecord  faultConnector -> FaultEnd
```

---

## 11. Logging -- `Util_SUB_Log_Error`

Every flow's fault path terminates at the shared logging subflow. AppLog__c custom object stores the audit row.

| Input | Type | Notes |
|---|---|---|
| `input_FlowName` | Text, required | API name of the calling flow |
| `input_RecordId` | Text, optional | Record being processed |
| `input_ElementName` | Text, required | Element that faulted |
| `input_ErrorMessage` | Text, required | `{!$Flow.FaultMessage}` from caller |

The subflow itself creates an `AppLog__c` row and routes its own `recordCreates` fault to End (fail silently -- logging must not cascade).

Deployment order: `AppLog__c` object -> `Util_SUB_Log_Error` flow -> all dependent flows.

---

## 12. Invocable Apex from Flow

Pattern (CLAUDE.md classes: `CaseEscalationService`, `CaseLinkedCaseService`):

```apex
public with sharing class CaseEscalationService {
   @InvocableMethod(label='Escalate Cases' description='Creates child escalation cases')
   public static List<Response> escalate(List<Request> reqs) {
      // bulkify -- reqs may contain many records
   }
   public class Request {
      @InvocableVariable(required=true) public Id caseId;
      @InvocableVariable public String reason;
   }
   public class Response {
      @InvocableVariable public Boolean success;
      @InvocableVariable public String errorMessage;
   }
}
```

Flow XML: `<actionCalls><actionType>apex</actionType><actionName>CaseEscalationService</actionName>`.

| Rule | Detail |
|---|---|
| `actionName` = exact class name | Not method, not label (Mistakes #30) |
| Always bulkified | Flow may pass many records per transaction |
| Apex enforces its own sharing | Flow run mode does NOT propagate into Apex |
| Apex handles recoverable errors | Return `success=false` + `errorMessage`; don't throw unless unrecoverable |

---

## 13. Status & Versioning

Project rule (CLAUDE.md): **deploy as `<status>Draft</status>`**. Naresh activates manually after sandbox validation.

```xml
<status>Draft</status>     <!-- this project -- required -->
<status>Active</status>    <!-- ONLY when Naresh activates in UI / org metadata -->
<status>Obsolete</status>  <!-- auto-set by Salesforce when superseded -->
```

Activation rules:
- Exactly one version of a flow is Active at a time. Activating version N auto-deactivates N-1.
- Keep N-1 in the org for one release cycle as rollback insurance.
- **Do NOT deactivate old flows** in this project -- Naresh handles cutover after sandbox validation (CLAUDE.md Section 3 14. Validation Command (project)

Run after every significant change. Zero component errors required.

```bash
sf project deploy start \
   --manifest manifest/package-case-flow-optimization.xml \
   --target-org PlusGradeFullSB \
   --dry-run --test-level RunLocalTests --wait 60
```

13 pre-existing Opportunity test failures are expected and do not block Case deployment (CLAUDE.md Section 4 15. Definition of Done

### Design
- [ ] Flow type chosen (before-save / after-save / scheduled / autolaunched / screen) and rationale documented
- [ ] `triggerOrder` chosen using 10/20/30/40/50 spacing
- [ ] Entry criteria defined (`filterFormula`, including RecordType gate when relevant)
- [ ] Element-by-element plan with fault paths

### Implementation
- [ ] XML elements in strict alphabetical order
- [ ] Both `processMetadataValues` (BuilderType + CanvasMode) present
- [ ] `<areMetricsLoggedToDataCloud>false</areMetricsLoggedToDataCloud>` present
- [ ] All `locationX`/`locationY` = 0
- [ ] No XML comments
- [ ] Every `recordCreates`/`recordUpdates`/`recordDeletes`/`actionCalls`/`subflows` has `faultConnector` -> `FaultEnd` -> `Subflow_LogError`
- [ ] Every non-terminal Decision has `defaultConnector`
- [ ] No DML / SOQL / actions inside `loops`
- [ ] Idempotency lookup includes "open record" clause (e.g. `End_Time__c IS NULL`)
- [ ] No hardcoded record IDs (Custom Label + formula instead)
- [ ] RecordType referenced by `DeveloperName`, never by Id
- [ ] No `$Record__Prior.X` in after-save formulas -- use `PRIORVALUE({!$Record.X})`
- [ ] After-save flow does not Update the triggering record
- [ ] `actionName` in apex action = exact class name

### Project
- [ ] `<status>Draft</status>` -- never `Active`
- [ ] Old flow NOT deactivated
- [ ] Dry-run deploy passes with zero component errors against `manifest/package-case-flow-optimization.xml`

---

## 16. Common AI Mistakes to Avoid

| # | Mistake | Correct approach |
|---|---|---|
| 1 | DML element inside Loop | Build collection in loop, single DML outside loop |
| 2 | Missing fault path on Create/Update/Delete Records | Add fault path to every DML element pointing to LogError_Subflow |
| 3 | Missing fault path on Action elements | Add fault path to every action element |
| 4 | Using After-Save to update the triggering record | Use Before-Save for same-record updates |
| 5 | No entry criteria defined | Define field-level change conditions |
| 6 | No idempotency check | Get Records + Decision before every Create Records |
| 7 | Hardcoded Record IDs | Use Custom Metadata Types or Custom Settings |
| 8 | Wrong flow type selected | Use Before-Save for same-record; After-Save for related |
| 9 | Get Records (SOQL) inside Loop | Query before loop; pass collection into loop |
| 10 | Fault path loops back to earlier element | Fault path must route to End or error screen |
| 11 | Not capturing {!$Flow.FaultMessage} | Capture FaultMessage immediately in fault path |
| 12 | Sensitive data stored in flow variables | Avoid storing tokens, passwords in flow variables |
| 13 | Activating without testing in sandbox | Always test in sandbox with representative data |
| 14 | Not keeping prior version | Keep N-1 version for at least one release cycle |
| 15 | No changed-field detection on update trigger | Use $Record__Prior in entry conditions |
| 16 | Deeply nested decisions without formulas | Extract complex conditions to Formula resources |
| 17 | No documentation of input/output contracts | Document inputs/outputs in flow Description field |
| 18 | Deploying LogError_Subflow after dependent flows | Deploy infrastructure flows first |
| 19 | Flow variable name conflicts with reserved names | Follow naming conventions; avoid Salesforce reserved names |
| 20 | Missing LogError_Subflow in org | Deploy AppLog__c and LogError_Subflow before any other flows |
| 21 | Missing `processMetadataValues` blocks (BuilderType + CanvasMode) | Flow shows as "built with Cloud Flow Designer"; cannot be opened or edited in Lightning Flow Builder. Every flow XML must include both `<processMetadataValues>` blocks before `<processType>`: `BuilderType=LightningFlowBuilder` and `CanvasMode=AUTO_LAYOUT_CANVAS` |
| 22 | Non-zero `locationX`/`locationY` values in AUTO_LAYOUT_CANVAS flow | Set ALL `<locationX>0</locationX>` and `<locationY>0</locationY>` on every element when using `AUTO_LAYOUT_CANVAS` |
| 23 | Missing `<areMetricsLoggedToDataCloud>false</areMetricsLoggedToDataCloud>` | Add immediately after `<apiVersion>` in every flow |
| 24 | XML comments (`<!-- ... -->`) inside flow files | Remove all XML comments; put notes in `<description>` or `<label>` instead |
| 25 | Flow XML elements not in alphabetical order | Write elements in strict alphabetical order: `actionCalls -> apiVersion -> areMetricsLoggedToDataCloud -> assignments -> decisions -> description -> environments -> formulas -> interviewLabel -> label -> processMetadataValues -> processType -> recordCreates -> recordLookups -> recordUpdates -> start -> status -> triggerOrder -> variables` |
| 26 | Decision `defaultConnector` missing -- default path silently ends the flow | Every non-terminal Decision MUST have an explicit `<defaultConnector>` pointing to the next element; trace every path after writing a Decision |
| 27 | `FaultEnd` assignment (reads `$Flow.FaultMessage`) used as a Decision `defaultConnector` target | `FaultEnd` assignments must only be targets of `<faultConnector>` on DML/action elements -- never of a Decision connector |
| 28 | Using `$Record__Prior.FieldName` inside after-save formula resources | In after-save flow formula resources always use `PRIORVALUE({!$Record.FieldName})` |
| 29 | Mixed AND/OR conditions using `<conditionLogic>and</conditionLogic>` for all rules | Use explicit numeric logic for mixed rules: `<conditionLogic>1 AND 2 AND (3 OR 4)</conditionLogic>` |
| 30 | `<actionName>` in `<actionCalls>` does not exactly match the Apex class name | `actionName` must be the exact Apex class name (not the method name, not a label) |
| 31 | Before-save flow contains `<recordUpdates>` or `<actionCalls>` elements | Before-save flows must use only Assignment and Decision elements; assign directly to `$Record` -- the platform writes the values as part of the save |
| 32 | Single linear decision chain mixes all record-type logic together | Use a master RT gate decision after any early exits; fan out to RT-specific sub-chains; converge all branches to a shared common tail |
| 33 | Early-exit actions (dupe/spam close, bypass flag on merged case) continue into downstream decisions via connector | Terminal assignments must have no `<connector>` -- omit the connector element entirely so the flow ends at that point |
| 34 | RT-specific decisions repeat `formula_IsRT` and `formula_IsNew` conditions already guaranteed by upstream gates | Once a record enters a branch via an RT gate, remove the RT formula and IsNew formula from all decisions inside that branch -- rely on the gate, not repeated conditions |
| 35 | Using hardcoded RecordType ID in formula variables | For detection/branching: use `$Record.RecordType.DeveloperName` directly. For assigning RecordTypeId: use `Get Records` filtered by `DeveloperName` and assign the queried `Id` |
| 36 | `NexusTaskToProject` decision placed only in the update branch | Place `Decision_NexusTaskToProject` in both the IsNew=true Nexus branch and the IsNew=false Nexus branch; `Decision_NexusClosedLost` (update-only, relies on `IsChanged`) stays in the update branch only |
| 37 | Using `$Record.Status = 'Reopened'` to detect a reopen when `'Reopened'` is not assigned to any record type's picklist | Use `$Record__Prior.Status = 'Closed' AND $Record.Status != 'Closed'` -- any transition OUT of Closed is a reopen |
| 38 | Running an unconditional action as the first element when the entry filter admits multiple unrelated triggers | Add a `Decision_StatusOrNew` gate as the first element using `conditionLogic: 1 OR 2`; route each entry-type to its own path |
| 39 | Idempotency `Get Records` for status log filtering only on `Case__c` and `Status__c` without `End_Time__c IS NULL` | Always include `End_Time__c IS NULL` (or equivalent open-record indicator) in any "find existing open record" idempotency lookup |
| 40 | Omitting a `By_Pass__c` check in the SBU_GC status log gate when a before-save flow sets `By_Pass__c = true` for merged+closed cases | Add `$Record.By_Pass__c = false` as an AND condition in the SBU_GC gate decision |
| 41 | `Get Records` for an idempotency null-check retrieves all fields when only `Id` is needed | Add `<queriedFields>Id</queriedFields>` to any Get Records whose only downstream use is `var.Id IsNull` |
| 42 | `recordTriggerType: Update` used when new cases can be created with the trigger field already populated | Set `recordTriggerType: CreateAndUpdate` whenever the business process can originate on create |
| 43 | Entry filter missing RecordType gate -- flow relies solely on field-change detection | Add RecordType DeveloperName filter directly in the `filterFormula` |
| 44 | `NOT(ISBLANK(MasterRecordId))` used in entry filter for merge detection without `ISCHANGED()` guard | Use `ISCHANGED(MasterRecordId) && NOT(ISBLANK(MasterRecordId))` -- fires only at the exact moment of merge |
| 45 | `Linked_Cases__c` and `Linked_Cases_SBUGC__c` field assignments reversed in `Linked_Case__c` records for DUPLICATE and MERGE paths | `Linked_Cases__c` = primary/original/master case; `Linked_Cases_SBUGC__c` = derived/secondary case (duplicate, loser, or split) |
| 46 | Coding re-parent logic against a field that does not exist on the target object | Always verify field existence from `force-app/main/default/objects/<Object>/fields/` before writing SOQL or field assignments |
| 47 | DUPLICATE path in linked-case flow fires for all record types when old flow restricted to SBU_GC only | Add RecordType DeveloperName gate to BOTH the entry `filterFormula` and the Decision rule for the DUPLICATE path |
| 48 | Hardcoded org IDs placed directly in flow formula expressions or `<inputAssignments>` | Create a Custom Label per ID; reference it in a formula resource as `{!$Label.Label_Name}`; then use `<elementReference>formula_name</elementReference>` in `<inputAssignments>` and decision `<rightValue>` elements |
| 49 | Old Before-Save flow (simple field assignments, no SOQL) pulled into an After-Save consolidated flow | Leave simple Before-Save flows as independent before-save flows; only consolidate into After-Save when the logic needs SOQL or related-record DML after commit |
| 50 | Parity gap: old flow assigned a field via hardcoded record ID; new flow omits the assignment entirely rather than replacing with a dynamic lookup | When an old flow set a field using a hardcoded record ID, flag it as VERIFY item: confirm whether the field is still used in business logic; if yes, implement dynamic lookup by name/DeveloperName; if the field is deprecated, document the intentional omission |
| 51 | Using `<operator>IsNull</operator><rightValue><booleanValue>false</booleanValue></rightValue>` on a Status (or any always-populated field) to detect a field change | Use `<operator>IsChanged</operator><rightValue><booleanValue>true</booleanValue></rightValue>` to detect that a field value changed during this transaction |
| 52 | Missing fault connectors on `emailAlert` action elements | `emailAlert` is an action element -- apply the same mandatory fault connector rule as `invocableApex`, `sendEmail`, and `customAction`; every `<actionCalls>` block with `<actionType>emailAlert</actionType>` requires `<faultConnector><targetReference>FaultEnd</targetReference></faultConnector>` |
| 53 | TODO placeholder Assignments that write to `var_FaultMessage` (a fault-tracking variable) used as stub nodes for unimplemented email or action logic | For stub/placeholder nodes, use a clearly-named no-op Assignment variable (e.g. `var_StubPlaceholder`) or omit the element entirely and block OV with a comment in the flow description until the API names are confirmed |

---

## 17. Empirical Findings & Implementation Notes

When Salesforce's documented approach doesn't work in this org, the workaround goes here. Date-stamp every entry.

| # | Date | Documented approach | What actually works | Why / Context |
|---|---|---|---|---|
| 1 | 2026-05-16 | `help.salesforce.com` Flow doc pages are the canonical authority for design best practices, order of execution, and metadata XML structure | The live Help pages are JS-rendered and return CSS-error stubs to non-browser fetchers. Ground flow authoring against `developer.salesforce.com/docs/atlas.en-us.api_meta.meta/api_meta/meta_visual_workflow.htm` (Metadata API), `forcedotcom/sf-skills/skills/generating-flow/SKILL.md`, and retrieved flow XML from prior versions in this org | Confirmed 2026-05-16 across `flow_concepts_design_best_practices.htm`, `flow_concepts_trigger_order_of_execution.htm`, and `flow_concepts_rt_bestpractices.htm` -- all returned CSS-loading shells via WebFetch |
| 2 | 2026-05-16 | Salesforce docs suggest using the block-form `<filters>` element for entry conditions on record-triggered flows | This project standardizes on `<filterFormula>` -- single expression supports OR/mixed boolean logic, RecordType gating, and `ISCHANGED()`/`PRIORVALUE()` calls in one place. Block-form `<filters>` is AND-only and forces decisions into the body of the flow for any OR logic | `<filterFormula>` consolidates entry logic, keeps it visible at the top of the flow, and matches the pattern used by `Case_AS_Status_SLA`, `Case_AS_Escalation`, and `Case_AS_Linked_Case` |
| 3 | 2026-05-16 | Many examples show `<status>Active</status>` for deployable flow XML | This project deploys every flow as `<status>Draft</status>` -- Naresh activates manually after sandbox validation. Cutover is human-gated; old flows are never deactivated by automation either | CLAUDE.md Section 3 project policy. Auto-activation has caused production incidents in prior migrations |

---

## 18. Official References

- [Flow Metadata API -- Visual Workflow](https://developer.salesforce.com/docs/atlas.en-us.api_meta.meta/api_meta/meta_visual_workflow.htm)
- [Flow Order of Execution](https://help.salesforce.com/s/articleView?id=sf.flow_concepts_trigger_order_of_execution.htm)
- [Record-Triggered Flow Best Practices](https://help.salesforce.com/s/articleView?id=sf.flow_concepts_rt_bestpractices.htm)
- [Fault Paths](https://help.salesforce.com/s/articleView?id=sf.flow_build_fault_paths.htm)
- [Flow Run Mode](https://help.salesforce.com/s/articleView?id=sf.flow_concepts_run_mode.htm)
- [`@InvocableMethod`](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_classes_annotation_InvocableMethod.htm)
- [`@InvocableVariable`](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_classes_annotation_InvocableVariable.htm)
- [Flow Limits and Considerations](https://help.salesforce.com/s/articleView?id=sf.flow_considerations.htm)
- [forcedotcom/sf-skills -- generating-flow SKILL.md](https://github.com/forcedotcom/sf-skills/tree/main/skills/generating-flow)
- CLAUDE.md (Plusgrade PlusGradeFullSB project contract)

---

*Flow Guidelines | Plusgrade PlusGradeFullSB | Naresh | Last verified 2026-05-16*

