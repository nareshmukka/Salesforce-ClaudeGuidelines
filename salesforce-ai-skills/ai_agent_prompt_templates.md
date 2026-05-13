# AI Agent Prompt Templates for Salesforce Development

**Version**: 2.0 (April 2026)
**Developer**: Naresh | Senior Salesforce Developer
**Purpose**: Ready-to-use prompt templates for common Salesforce development tasks. Copy, customize the [PLACEHOLDERS], and attach the referenced guideline file to your AI agent session.

**Usage**: Each prompt references a specific guideline file. Attach that file (or paste its contents) into your AI agent context before sending the prompt.

**Output Contract**: Every prompt enforces: Plan → Files → Implementation → Security → Testing → Validation → Rollback

---

## How to Use These Templates

1. **Find the task** you need in the table of contents below
2. **Identify the guideline file** listed at the top of the prompt — attach that file to your AI agent session before sending the prompt
3. **Copy the prompt** from the code block
4. **Replace all [PLACEHOLDERS]** with your specific details — do not leave any placeholder text in the prompt
5. **Send to your AI agent** — the agent will follow the output contract defined in the attached guideline

### Output Contract Enforced in Every Prompt

Every prompt in this library enforces the following seven-section output contract:

| Section | Purpose |
|---|---|
| **1. PLAN** | Architecture decisions, what will be created/modified, dependency analysis |
| **2. FILES** | Complete list of all file paths and class names |
| **3. IMPLEMENTATION** | Full working code and configuration |
| **4. SECURITY** | CRUD/FLS, sharing model, credentials, access control |
| **5. TESTING** | Test classes, test scenarios, coverage strategy |
| **6. VALIDATION** | sf CLI commands to deploy and verify |
| **7. ROLLBACK** | How to undo the change if it causes issues |

---

## Table of Contents

1. [Create Apex Class](#1-create-apex-class)
2. [Create Trigger](#2-create-trigger)
3. [Create Flow Design](#3-create-flow-design)
4. [Create LWC Component](#4-create-lwc-component)
5. [Create Agentforce Agent](#5-create-agentforce-agent)
6. [Review Existing Code](#6-review-existing-code)
7. [Create package.xml](#7-create-packagexml)
8. [Validate Deployment](#8-validate-deployment)
9. [Refactor Flow to Apex](#9-refactor-flow-to-apex)
10. [Refactor Apex](#10-refactor-apex)
11. [Create Permission Set](#11-create-permission-set)
12. [Create FlexiPage](#12-create-flexipage)
13. [Create Prompt Template](#13-create-prompt-template)
14. [Create Visualforce Page](#14-create-visualforce-page)
15. [Full Feature Implementation](#15-full-feature-implementation)
16. [Security / Standards Audit](#16-security--standards-audit)

---

## 1. Create Apex Class

Attach `salesforce-ai-skills/apex_guidelines.md` to your session before using this prompt. The agent will follow all Apex guidelines including sharing model, CRUD/FLS, bulk safety, Named Credentials, and test coverage standards.

```
Guideline file to attach: salesforce-ai-skills/apex_guidelines.md

You are a Senior Salesforce Developer. Follow ALL rules in the attached apex_guidelines.md.
Do not deviate from any rule in the guideline. If the guideline specifies a pattern, use that
pattern exactly.

Task: Create a new Apex service class for [DESCRIBE YOUR SERVICE — e.g., "processing inbound
case updates from an external support portal"].

Required output format:

1. PLAN
   - List all classes to create: service, selector, domain (if applicable), test class(es)
   - State sharing model decision (with sharing / without sharing / inherited sharing) and justification
   - Identify all objects and fields that will be queried or modified
   - Identify any external callouts required and the Named Credential that will be used
   - Identify any custom exceptions required

2. FILES
   - Exact file paths for all new files following Salesforce source format
   - Format: force-app/main/default/classes/<ClassName>.cls and <ClassName>.cls-meta.xml
   - List every class and its purpose

3. IMPLEMENTATION
   Full Apex code for each class with:
   - Developer header comment block:
       Developer: Naresh
       Title: Senior Salesforce Developer
       Description: [purpose of the class]
   - Explicit sharing declaration (with sharing / without sharing / inherited sharing)
   - CRUD/FLS checks at all entry points that accept user-sourced data
   - No SOQL inside loops — collect IDs, query once outside the loop
   - No DML inside loops — build collections, DML once outside the loop
   - Named Credentials for all HTTP callouts (no hardcoded endpoints)
   - Custom exception class for domain-specific errors
   - AppLogger calls: INFO at entry, INFO on success, ERROR with correlationId on failure
   - All public methods have descriptive Javadoc comments

4. SECURITY
   - State which classes use with sharing and which use without sharing, and why
   - List every CRUD check present and the object/field it covers
   - List every FLS check present and the field it covers
   - Confirm no hardcoded IDs, org-specific values, or endpoint URLs

5. TESTING
   Full test class with:
   - @IsTest annotation and developer header
   - @TestSetup method creating all required test data (no SeeAllData=true)
   - Happy path test: normal expected input, assert all expected side effects
   - Negative test: invalid input, assert exception thrown or graceful handling
   - Bulk test: 200 records, assert no governor limit exceptions
   - Async test (if applicable): Test.startTest() / Test.stopTest() around async calls
   - Mock callout test (if applicable): HttpCalloutMock implementation, assert correct handling for
     both success (200) and failure (400/500) responses
   - All assertions include a descriptive message as the third parameter

6. VALIDATION
   sf CLI commands:
   - Deploy command with --test-level RunLocalTests
   - Command to run specific test class only
   - Command to check deploy status

7. ROLLBACK
   - State which classes would need to be removed or reverted if this deployment fails
   - Identify any data side effects that cannot be automatically rolled back
   - Confirm all code is in source control before deploying

Do NOT modify any unrelated existing classes.
Do NOT create files outside the scope of this task.
Present the PLAN for confirmation before writing any code if this is a multi-class implementation.
```

---

## 2. Create Trigger

Attach `salesforce-ai-skills/trigger_guidelines.md` to your session before using this prompt. The agent will enforce the one-trigger-per-object rule, thin trigger pattern, handler class with recursion guard, and bulk safety.

```
Guideline file to attach: salesforce-ai-skills/trigger_guidelines.md

You are a Senior Salesforce Developer. Follow ALL rules in the attached trigger_guidelines.md.
Do not deviate from any rule in the guideline.

FIRST STEP — Check for existing trigger:
Before writing any code, state whether a trigger already exists for [OBJECT NAME].
If one exists: confirm you will add to the existing handler, NOT create a new trigger file.
If none exists: confirm you will create the trigger and handler from scratch.

Task: Create a trigger for [OBJECT NAME — e.g., "Case"] that handles
[DESCRIBE CONTEXT AND PURPOSE — e.g., "after insert and after update to create follow-up tasks
when Status changes to Closed"].

Required output format:

1. PLAN
   - Confirm: one and only one trigger exists (or will exist) for this object after this change
   - List the trigger contexts needed (before insert, after insert, before update, after update, etc.)
     and justify why each context is required
   - List all classes to create or modify: trigger file, handler class, service class, test class
   - Identify the recursion guard strategy
   - Identify all objects and fields affected

2. FILES
   - Thin trigger file: force-app/main/default/triggers/<ObjectName>Trigger.trigger
   - Handler class: force-app/main/default/classes/<ObjectName>TriggerHandler.cls
   - Service class (if new logic): force-app/main/default/classes/<ObjectName>Service.cls
   - Test class: force-app/main/default/classes/<ObjectName>TriggerTest.cls
   - All corresponding -meta.xml files

3. IMPLEMENTATION
   - Thin trigger file: contains ONLY the trigger declaration and a single call to the handler.
     No business logic in the trigger file.
   - Handler class:
     - Developer header on all classes
     - with sharing (or justify if not)
     - Static Boolean recursion guard: private static Boolean isRunning = false;
     - Switch statement on Trigger.operationType (TriggerOperation enum)
     - Separate private methods for each context: handleAfterInsert(), handleAfterUpdate(), etc.
     - Methods delegate to service class — no business logic in handler
   - Service class:
     - Developer header
     - with sharing
     - Business logic here
     - CRUD/FLS checks
     - No SOQL or DML inside loops
     - AppLogger calls at error paths

4. SECURITY
   - State sharing model on trigger handler and service class
   - Explain recursion guard: what it prevents and how it works
   - List CRUD/FLS enforcement locations

5. TESTING
   - @TestSetup method with all required test data
   - Bulk test: insert/update 200 records, verify no limits errors
   - Context tests: test each trigger context (insert, update, delete as applicable)
   - Change detection test: verify logic only fires when the expected field changes
     (e.g., Status changes TO 'Closed' — not on every update)
   - Negative test: verify logic does NOT fire when condition is not met
   - All assertions include messages

6. VALIDATION
   sf CLI commands:
   - Deploy command: --test-level RunSpecifiedTests --tests <TestClassName>
   - How to verify the trigger is active in the org after deploy

7. ROLLBACK
   - If the trigger causes issues: which class to revert and the git command
   - If this is an addition to an existing handler: how to remove just the new logic
   - Confirm all code is committed to source control before deploying to production

Do NOT create a second trigger file if one already exists for this object.
Do NOT put any business logic directly in the trigger file.
Do NOT add logic that bypasses the recursion guard without explicit justification.
```

---

## 3. Create Flow Design

Attach `salesforce-ai-skills/flow_guidelines.md` to your session before using this prompt. The agent will enforce flow type selection, bulk-safe collection patterns, fault paths on all DML elements, and LogError_Subflow usage.

```
Guideline file to attach: salesforce-ai-skills/flow_guidelines.md

You are a Senior Salesforce Developer. Follow ALL rules in the attached flow_guidelines.md.
Do not deviate from any rule in the guideline.

Task: Design a [FLOW TYPE — before-save / after-save / autolaunched / screen] record-triggered
flow for [OBJECT] that [DESCRIBE PURPOSE — e.g., "creates a follow-up Task when a Case is
Closed and no open Task already exists"].

Required output format:

1. PLAN
   Flow type decision:
   - State the flow type chosen (before-save or after-save) and the exact justification
   - Rule: before-save for same-record field updates (faster, no DML); after-save for related
     record creation, callouts, or cross-object updates
   - If after-save: confirm you are NOT using it to update the triggering record's fields

   Entry criteria:
   - Exact entry condition formula or field-changed criteria
   - Explain: when does this flow fire, and when does it intentionally NOT fire

   Element-by-element design (list in order):
   - Element name, Element type, What it does, What its fault path connects to
   - Example format:
       1. DecisionNode_CheckOpenTask | Decision | Checks if open Task exists | N/A
       2. CreateTaskCollection | Assignment | Adds Task to collection variable | N/A
       3. CreateTasks | Create Records | Inserts col_Tasks collection | Fault → LogError_Subflow
       4. LogError_Subflow | Subflow | Logs fault to AppLog__c | Fault → End (silent)

   Variable contract:
   - List all variables: name, type (Text/Record/Collection/Boolean), Input/Output/Internal
   - Follow naming convention: input_ for inputs, output_ for outputs, var_ for internal,
     col_ for collections, formula_ for formulas

2. FILES
   - Flow metadata file name: [FlowApiName].flow-meta.xml
   - Any referenced Apex invocable classes (file path + class name)
   - LogError_Subflow must already be deployed — list it as a dependency

3. IMPLEMENTATION
   Detailed element design including:

   Entry condition:
   - Use ISCHANGED({!$Record.Status}) or specific field-change check to prevent unnecessary runs
   - Example: {!$Record.Status} = 'Closed' AND ISCHANGED({!$Record.Status})

   Idempotency check (Decision element):
   - Get Records to check if outcome already exists (e.g., open Task already present)
   - Decision: if already exists → End (do nothing); if not → proceed

   Bulk-safe collection pattern:
   - Loop: collects records to create into a collection variable (col_RecordsToCreate)
   - Create Records: uses the COLLECTION — DML is OUTSIDE the loop
   - NEVER use Create Records or Update Records INSIDE a Loop element

   Fault paths:
   - EVERY Create Records element has a fault connector
   - EVERY Update Records element has a fault connector
   - EVERY Delete Records element has a fault connector
   - EVERY Apex Action element has a fault connector
   - All fault connectors point to a Subflow element calling LogError_Subflow
   - LogError_Subflow Subflow element itself has a fault path going to End (silent failure)

   Variable bindings for LogError_Subflow call:
   - input_FlowName = {!$Flow.CurrentFlowApiName}
   - input_RecordId = {!$Record.Id}
   - input_ElementName = [literal name of the element that faulted]
   - input_ErrorMessage = {!$Flow.FaultMessage}

4. SECURITY
   - Flow run context: System context with sharing or User context — state which and why
   - Data exposure considerations: does this flow surface data that the running user may not
     have access to? If running in system context, justify why.

5. TESTING
   - How to manually test the flow in sandbox (what record action triggers it)
   - What to verify after triggering (what records should be created/updated)
   - How to test the fault path (deliberate fault scenario)
   - Which Apex test class covers this flow path indirectly (if using an invocable action)

6. VALIDATION
   sf CLI commands:
   - Retrieve the flow from the org (to verify what is there before deploying)
   - Deploy the flow
   - Deploy LogError_Subflow (must be deployed first if not already in org)

7. ROLLBACK
   - Keep the prior inactive flow version in the org — do NOT delete it until the new version
     is confirmed stable in production
   - How to reactivate the prior version via Flow Builder UI
   - How to deploy a prior flow version from source control if needed

Do NOT put DML (Create Records, Update Records, Delete Records) inside a Loop element.
Do NOT skip fault paths on any DML or Action element.
Do NOT use after-save flow for updates to the same record that triggered the flow.
Do NOT use the flow for logic that requires complex SOQL, retry logic, or transaction control
— flag those as candidates for Apex invocable actions instead.
```

---

## 4. Create LWC Component

Attach `salesforce-ai-skills/lwc_guidelines.md` to your session before using this prompt. The agent will enforce the smart/presentational component split, four render states, server-side CRUD/FLS enforcement, and Jest testing standards.

```
Guideline file to attach: salesforce-ai-skills/lwc_guidelines.md

You are a Senior Salesforce Developer. Follow ALL rules in the attached lwc_guidelines.md.
Do not deviate from any rule in the guideline.

Task: Create a Lightning Web Component for [DESCRIBE PURPOSE — e.g., "a Case dashboard
that displays open cases for the current user with filter controls for Priority and Status"].

Required output format:

1. PLAN
   Component architecture:
   - Smart container component: handles data fetch, state management, error/loading/empty handling
   - Presentational component(s): receive @api data, emit events upward, no data fetching
   - Data source decision: @wire vs imperative call — state which and why
     (@wire for reactive data; imperative for conditional loads, parameters from user action)
   - List all Apex controller methods needed with their signatures
   - List all @api properties on presentational components

2. FILES
   Container component:
   - force-app/main/default/lwc/[componentName]/[componentName].html
   - force-app/main/default/lwc/[componentName]/[componentName].js
   - force-app/main/default/lwc/[componentName]/[componentName].js-meta.xml
   Presentational component(s) (if applicable):
   - force-app/main/default/lwc/[subComponentName]/ (same file set)
   Apex controller:
   - force-app/main/default/classes/[ComponentName]Controller.cls
   - force-app/main/default/classes/[ComponentName]Controller.cls-meta.xml
   Jest test:
   - force-app/main/default/lwc/[componentName]/__tests__/[componentName].test.js

3. IMPLEMENTATION
   HTML template (container):
   - Loading state: <template if:true={isLoading}><lightning-spinner></lightning-spinner></template>
   - Error state: <template if:true={hasError}><p class="error">{errorMessage}</p></template>
   - Data state: <template if:true={hasData}>... data display ...</template>
   - Empty state: <template if:true={isEmpty}><p>No records found.</p></template>
   - No hardcoded IDs, record type IDs, or org-specific values in HTML

   JavaScript (container):
   - @track or reactive properties for: isLoading, error, data
   - Computed getters for: hasError, hasData, isEmpty (derived from data/error state)
   - Error handling: catch block sets this.error = reduceErrors(error).join(', ') or similar
   - No hardcoded IDs in JS

   Apex controller:
   - Developer header: Developer: Naresh, Title: Senior Salesforce Developer
   - with sharing declared explicitly
   - @AuraEnabled(cacheable=true) for read-only methods, @AuraEnabled for DML methods
   - SOQL uses WITH USER_MODE (Salesforce API 57.0+) or explicit CRUD/FLS checks
   - AuraHandledException thrown on all catch blocks:
       throw new AuraHandledException(e.getMessage());
   - No hardcoded IDs

4. SECURITY
   - State sharing model on Apex controller and justify
   - List all CRUD/FLS enforcement mechanisms (WITH USER_MODE, Schema.sObjectType checks)
   - Confirm: UI visibility guards (if:true) are never used as the sole security mechanism
     — server-side enforcement must exist independently of UI guards

5. TESTING
   Jest test file covering:
   - Loading state: mock wire returns undefined, assert spinner is rendered
   - Error state: mock wire returns error, assert error message is rendered
   - Success state: mock wire returns data, assert correct records are rendered
   - Empty state: mock wire returns empty array, assert empty message is rendered
   - Event test: user action (button click, filter change) emits correct custom event
   - All @wire adapters mocked with @salesforce/apex mock
   - No real Apex calls in Jest tests

   Apex test class:
   - @TestSetup creates all required data
   - Happy path: normal user with correct permissions, assert correct records returned
   - CRUD/FLS test: user without access, assert AuraHandledException thrown
   - All assertions include messages

6. VALIDATION
   - npm run test:unit (Jest test command)
   - sf project deploy start command for the LWC and Apex controller
   - sf apex run test command for the Apex test class

7. ROLLBACK
   - Prior LWC version in source control — git checkout command to revert
   - Prior Apex controller version — git checkout command to revert
   - Note: LWC changes are immediate on deploy — no activation step

Do NOT skip error state handling in the HTML template.
Do NOT use SeeAllData=true in any test class.
Do NOT rely on UI guards (if:true conditions) as the only security enforcement.
Do NOT put data-fetching logic inside presentational components.
```

---

## 5. Create Agentforce Agent

Attach both `salesforce-ai-skills/agentforce_builder_guidelines.md` AND `salesforce-ai-skills/agentforce_script_guidelines.md` to your session before using this prompt.

```
Guideline files to attach:
  - salesforce-ai-skills/agentforce_builder_guidelines.md
  - salesforce-ai-skills/agentforce_script_guidelines.md

You are a Senior Salesforce Developer. Follow ALL rules in BOTH attached guideline files.
Do not deviate from any rule. Where guidelines overlap, apply the stricter rule.

Task: Design an Agentforce agent for [DESCRIBE PURPOSE — e.g., "a support portal agent
that handles case creation after verifying the customer's identity with a one-time code"].

Required output format:

1. PLAN
   Agent scope:
   - What the agent CAN do (explicit action inventory)
   - What the agent CANNOT do (explicit out-of-scope list — must be stated)
   - Topics/subtopics and their responsibilities
   - Action inventory: list every action, its type (Flow/Apex Invocable/External Service),
     and its inputs/outputs
   - Variable contract: all variables the agent uses, their types, and where they are set

2. FILES
   - Bot metadata file (verify exact metadata type in target org/release)
   - GenAiPlannerBundle (verify availability in target release)
   - GenAiPlugins for each action (verify metadata type)
   - GenAiFunctions (verify metadata type)
   - Referenced Flows (list each)
   - Referenced Apex invocable classes (list each)
   - Note: always mark Agentforce metadata type names as "verify in target org/release"
     because they change between Salesforce releases

3. IMPLEMENTATION
   Topic instructions (for each topic):
   - Step-by-step instructions with strict ordering
   - Gating condition before proceeding to sensitive actions
     Example: "Do not proceed to case creation until identity verification is confirmed
     with a verified = true response from the VerifyCustomerIdentity action."
   - Confirmation step before any record creation:
     "Confirm with the customer: 'I will create a case with subject [X]. Shall I proceed?'"
   - Error handling instruction for each action:
     "If the [action] returns an error, inform the customer that the request could not be
     completed and offer to connect them with a human agent."
   - Variable binding table:
     | Variable Name | Set By | Passed To | Purpose |
     |---|---|---|---|
     | verificationCode | Customer input | VerifyIdentity action | One-time code |
     | isVerified | VerifyIdentity action output | Gate condition | Identity confirmed |

4. SECURITY
   - Identity verification gate: state exactly where in the topic instructions the gate appears
     and what happens if verification fails
   - PII policy: what customer data the agent collects and does not log or store beyond the session
   - Hallucination prevention: state how the instructions constrain the agent to factual responses
     (e.g., "Only confirm information retrieved from Salesforce records. Do not infer or assume.")

5. TESTING
   Provide 5 test conversation scenarios:
   Scenario 1 — Happy path: customer provides correct code, case is created successfully
   Scenario 2 — Wrong verification code: customer provides wrong code, verify graceful failure message
   Scenario 3 — Record not found: customer provides ID that does not exist, verify not-found response
   Scenario 4 — Action failure: underlying action returns error, verify agent does not expose error details
   Scenario 5 — Out of scope: customer asks agent something outside defined scope, verify graceful deflection

6. VALIDATION
   - sf CLI commands to retrieve and deploy agent metadata (note: verify plugin availability)
   - How to test the agent in Agent Builder (Sandbox)
   - How to activate/deactivate the agent

7. ROLLBACK
   - Keep the prior inactive agent version — do NOT delete until new version confirmed stable
   - How to reactivate prior version in Agent Builder
   - How to deploy prior version from source control

Do NOT skip the identity verification gate for any action that creates, updates, or deletes records.
Do NOT fabricate Agentforce metadata type names — mark all type names as "verify in target org/release."
Do NOT design the agent to produce outputs that are not grounded in retrieved Salesforce data.
Mark any behavior that may differ across Salesforce releases as "verify in target org/release."
```

---

## 6. Review Existing Code

Attach `salesforce-ai-skills/global_ai_development_guidelines.md` AND the component file(s) being reviewed to your session before using this prompt.

```
Guideline files to attach:
  - salesforce-ai-skills/global_ai_development_guidelines.md
  - [The actual component file(s) to be reviewed]

You are a Senior Salesforce Developer. Follow ALL rules in the attached guidelines.

Task: Review the following [APEX CLASS / TRIGGER / FLOW / LWC] for compliance with
Salesforce best practices and the attached guidelines.

[PASTE CODE OR DESCRIBE THE COMPONENT HERE]

Required output format:

1. PLAN
   - Summarize what this component does based on your reading
   - List the compliance areas you will check (CRUD/FLS, sharing, bulk safety, etc.)
   - State what guideline rules are most relevant to this component type

2. FILES
   - List the file(s) reviewed

3. FINDINGS
   For each issue found, provide:
   - Severity: CRITICAL / HIGH / MEDIUM / LOW
     CRITICAL: Security vulnerability, data exposure, or production failure risk
     HIGH: Governor limit risk, incorrect behavior, missing required pattern
     MEDIUM: Code quality issue, missing logging, suboptimal pattern
     LOW: Style, naming convention, documentation gap

   - Location: [ClassName.methodName] or [FlowName > ElementName]
   - Rule Violated: which specific rule from the guideline this breaks
   - Issue: description of what is wrong
   - Fix: exact corrected code block or design change

   Example finding format:
   ---
   Severity: CRITICAL
   Location: CaseService.processUpdate (line ~45)
   Rule Violated: No SOQL inside loops (apex_guidelines.md §Bulk Safety)
   Issue: SOQL query [SELECT Id FROM Task WHERE WhatId = :c.Id] is inside a for loop
   Fix:
     // Before loop: collect all case IDs
     Set<Id> caseIds = new Map<Id, Case>(cases).keySet();
     Map<Id, Task> taskMap = new Map<Id, Task>(
         [SELECT Id, WhatId FROM Task WHERE WhatId IN :caseIds]
     );
     // Inside loop: use the map
     Task t = taskMap.get(c.Id);
   ---

4. SECURITY
   Specific findings for:
   - CRUD checks: present / missing at which entry points
   - FLS checks: present / missing for which fields
   - Sharing model: correct / incorrect / unjustified
   - Hardcoded values: IDs, endpoints, credentials found in code
   - Named Credentials: used / not used for callouts

5. TESTING
   - Which test scenarios are missing from the existing test class (or: no test class exists)
   - Specific test methods to add with their purpose

6. VALIDATION
   - Commands to run after applying the fixes
   - Specific test class to run to validate the fixes

7. DEFINITION OF DONE
   Checklist of every item that MUST be resolved before this component is mergeable:
   - [ ] [CRITICAL finding 1 description]
   - [ ] [CRITICAL finding 2 description]
   - [ ] [HIGH finding 1 description]
   - [ ] [Test coverage gap 1]
   - [ ] Code reviewed and approved by senior developer

Do NOT suggest changes outside the reviewed component's scope.
Do NOT rewrite the entire class — provide targeted fixes for each finding.
Do NOT approve a component that has CRITICAL findings.
```

---

## 7. Create package.xml

Attach `salesforce-ai-skills/deployment_guidelines.md` to your session before using this prompt.

```
Guideline file to attach: salesforce-ai-skills/deployment_guidelines.md

You are a Senior Salesforce Developer. Follow ALL rules in the attached deployment_guidelines.md.

Task: Create a package.xml manifest for deploying the following components:
[LIST YOUR COMPONENTS — e.g.:
  - ApexClass: CaseService, CaseTriggerHandler, CaseServiceTest
  - ApexTrigger: CaseTrigger
  - Flow: Case_AfterSave_RecordTriggered, LogError_Subflow
  - CustomField: Case.Case_Category__c, Case.Case_SubCategory__c
  - PermissionSet: PS_SupportAgent
  - FlexiPage: Case_Record_Page
  - LightningComponentBundle: caseDashboardContainer
]

Target org API version: [e.g., 62.0]

Required output format:

1. PLAN
   Dependency analysis:
   - List each component and what it depends on
   - Identify if multiple deployment waves are needed
   - Flag any components that depend on each other in a way that requires ordering
   - State whether this can be a single-manifest deploy or requires wave-based deployment

   Example dependency analysis format:
   | Component | Type | Depends On |
   |---|---|---|
   | Case.Case_Category__c | CustomField | Case (standard object — already in org) |
   | Case_AfterSave_RecordTriggered | Flow | Case.Case_Category__c, LogError_Subflow |
   | LogError_Subflow | Flow | AppLog__c (custom object — must already be in org) |
   | CaseTrigger | ApexTrigger | Case, CaseTriggerHandler |
   | PS_SupportAgent | PermissionSet | Case.Case_Category__c, CaseService |
   | Case_Record_Page | FlexiPage | caseDashboardContainer |

2. FILES
   Complete package.xml content:
   - Components in correct deployment dependency order (objects → fields → flows → apex → permissions → pages)
   - Correct API names (not display names)
   - Correct version number
   - XML comments explaining each group

3. IMPLEMENTATION
   Full package.xml XML:
   - Correct XML header: <?xml version="1.0" encoding="UTF-8"?>
   - Correct namespace: xmlns="http://soap.sforce.com/2006/04/metadata"
   - All types in deployment order:
     1. CustomObject (objects first)
     2. CustomField (fields before layouts and flows)
     3. RecordType (before layouts)
     4. Layout (before FlexiPage)
     5. ValidationRule
     6. CustomMetadata
     7. Flow (subflows before calling flows — LogError_Subflow listed first)
     8. ApexTrigger
     9. ApexClass (all classes including test classes)
     10. LightningComponentBundle
     11. NamedCredential
     12. PermissionSet
     13. PermissionSetGroup
     14. FlexiPage
     15. EmailTemplate
   - <version> element at the end

4. SECURITY
   Flag any sensitive metadata that requires manual verification in the target org:
   - Named Credentials (credentials/secrets may need manual configuration)
   - External Credentials (auth settings may need manual setup)
   - Permission Sets (review permissions before deploying to production)
   - Connected Apps (verify OAuth settings in target org)

5. TESTING
   - Specify test level: RunLocalTests (or RunSpecifiedTests with list of classes if scope is narrow)
   - List specific test classes to run and what they cover

6. VALIDATION
   Exact sf CLI commands:
   - Validation (check-only) command with correct flags
   - Quick deploy command (placeholder for job ID)
   - Post-deploy verify command

7. ROLLBACK
   - List which components to include in a rollback manifest if deployment needs to be reversed
   - Note any components that cannot be rolled back easily (new fields with data, etc.)

Do NOT include components outside the stated scope.
Do NOT use wildcard <members>*</members> in the deployment manifest — list components explicitly.
```

---

## 8. Validate Deployment

Attach `salesforce-ai-skills/deployment_guidelines.md` to your session before using this prompt.

```
Guideline file to attach: salesforce-ai-skills/deployment_guidelines.md

You are a Senior Salesforce Developer. Follow ALL rules in the attached deployment_guidelines.md.

Task: Generate the complete deployment validation and execution plan for:
  Target org:   [ORG ALIAS — e.g., UAT, PROD]
  Manifest:     [path to package.xml — e.g., manifest/package.xml]
  Test level:   [RunLocalTests / RunSpecifiedTests — if RunSpecifiedTests, list test classes]
  Release name: [e.g., "Case Management v2.3 — April 2026"]

Required output format:

1. PLAN
   Pre-deploy checklist:
   - [ ] package.xml dependency order confirmed correct
   - [ ] All referenced components exist in target org or are included in manifest
   - [ ] Test coverage confirmed >= 75% in most recent sandbox validation
   - [ ] Destructive changes (if any) are in a separate manifest, not in package.xml
   - [ ] Rollback plan documented and reviewed
   - [ ] Deployment window confirmed and stakeholders notified
   - [ ] Pre-deploy backup retrieved from target org and committed to source control

2. FILES
   Summary of package.xml:
   - Count of each metadata type included
   - Flag any component types that warrant extra attention (Flows, Permission Sets, Named Credentials)
   - Confirm the version number matches the target org API version

3. IMPLEMENTATION
   All CLI commands in sequence — copy-paste ready:

   Step 1: Pre-deploy backup (retrieve current state)
   [sf project retrieve command]

   Step 2: Validation (check-only) — REQUIRED before production
   [sf project deploy start --check-only command with all required flags]

   Step 3: Check validation result and capture job ID
   [sf project deploy report command]

   Step 4: Quick deploy (after validation succeeds — replace JOB_ID placeholder)
   [sf project deploy quick command]

   Step 5: Post-deploy verification
   [sf project deploy report --use-most-recent command]

   Step 6: Smoke test trigger (describe what user action to take to verify success)

4. SECURITY
   List any components requiring manual org verification after metadata deployment:
   - Named Credentials: which credentials need secrets set manually
   - External Credentials: any auth configuration needed
   - Permission Sets: confirm assignments are made to correct users after deploy

5. TESTING
   - Expected test pass count (if known from sandbox validation)
   - Coverage threshold: >= 75% required for production
   - Specific test classes being run and what they cover
   - How long the validation is expected to take (estimate from sandbox)

6. VALIDATION
   All commands with:
   - Correct --target-org flag
   - Correct --test-level flag
   - Correct --wait time
   - Notes on what output indicates success vs failure

7. ROLLBACK
   Exact rollback steps if deployment fails or causes issues:
   Step 1: [Identify failure — which component failed]
   Step 2: [git checkout command to retrieve prior version of the failed component]
   Step 3: [sf deploy command to redeploy prior version]
   Step 4: [Verification command to confirm rollback succeeded]
   Step 5: [Notify stakeholders of rollback]
   Notes: [Any components that cannot be automatically rolled back — data impact]

Do NOT execute any deployment without completing the pre-deploy checklist.
Do NOT skip the validation (check-only) step before production deployment.
Do NOT use NoTestRun for production or UAT deployments.
```

---

## 9. Refactor Flow to Apex

Attach both `salesforce-ai-skills/apex_guidelines.md` AND `salesforce-ai-skills/flow_guidelines.md` to your session before using this prompt.

```
Guideline files to attach:
  - salesforce-ai-skills/apex_guidelines.md
  - salesforce-ai-skills/flow_guidelines.md

You are a Senior Salesforce Developer. Follow ALL rules in BOTH attached guidelines.

Task: Refactor the following Flow to Apex service logic:
[DESCRIBE OR PASTE THE FLOW DESIGN — include: flow name, type, object, what it does,
 how many elements, what DML it performs, any external calls]

Reasons for refactoring:
[EXPLAIN WHY — choose all that apply:
  - Exceeds Flow element complexity limits (>500 elements)
  - Requires complex SOQL involving multiple related objects
  - Needs retry logic or exception handling beyond Flow capabilities
  - Requires transaction control (savepoints, partial rollback)
  - Flow is too slow due to many DML operations
  - Logic is too complex to maintain or test in Flow Builder
  - Requires dynamic query construction
]

Required output format:

1. PLAN
   Element mapping analysis:
   - List each significant Flow element and its Apex equivalent pattern
   Example:
   | Flow Element | Type | Apex Equivalent |
   |---|---|---|
   | GetOpenCases | Get Records | CaseSelector.getOpenCasesByAccountId(accountId) |
   | DecisionNode_HasCases | Decision | if (cases.isEmpty()) |
   | CreateTaskCollection | Assignment (loop) | tasks.add(new Task(...)) |
   | CreateTasks | Create Records | insert tasks; |
   | LogError_Subflow | Subflow | AppLogger.error(...) in catch block |

   What can remain declarative vs what moves to Apex:
   - Keep in Flow: [entry trigger, simple field updates that were before-save]
   - Move to Apex: [all logic listed above]

   If keeping a thin Flow wrapper: describe the pattern
   (Flow triggers → calls Apex Invocable action → Apex does all work)

2. FILES
   - New Apex service class: force-app/main/default/classes/[ServiceClass].cls
   - Invocable wrapper class (if called from Flow): force-app/main/default/classes/[ActionClass].cls
   - Test class: force-app/main/default/classes/[ServiceClass]Test.cls
   - Updated Flow file (if kept as thin wrapper): force-app/main/default/flows/[FlowName].flow-meta.xml
   - All corresponding -meta.xml files

3. IMPLEMENTATION
   Full Apex implementation with all apex_guidelines.md rules enforced:
   - Developer header on all classes
   - Explicit sharing declaration with justification
   - CRUD/FLS at entry point
   - No SOQL or DML in loops
   - Selector class for all SOQL
   - AppLogger for entry, success, and error
   - Custom exception class
   - If invocable wrapper: @InvocableMethod annotation with label, correct input/output inner classes

4. SECURITY
   Security change analysis — the Flow may have been running in System context:
   - Confirm CRUD/FLS enforcement now exists in Apex (it was implicit/absent in the Flow)
   - State the sharing model on the new Apex class
   - If the Flow ran in user context: confirm the Apex replacement also enforces user context (with sharing)
   - If the Flow ran in system context: justify whether the Apex equivalent should use
     without sharing or inherited sharing

5. TESTING
   - Service-level unit tests for each logical branch
   - Invocable wrapper test (if applicable)
   - Integration test: trigger the full path that replaced the Flow end-to-end
     (e.g., update a record that previously triggered the Flow and verify the Apex runs correctly)
   - Negative tests: exception paths that were previously handled by Flow fault paths

6. VALIDATION
   sf CLI commands:
   - Deploy Apex classes and updated Flow (if kept as wrapper)
   - Run test classes
   - Verify Flow is deactivated (if fully replaced) or updated (if kept as wrapper)

7. ROLLBACK
   - CRITICAL: Do NOT delete or deactivate the original Flow version until the Apex replacement
     is confirmed stable in production (minimum 1 week of production runtime)
   - Keep original Flow version as inactive version in the org
   - git command to revert to prior state if Apex replacement causes issues
   - How to reactivate the prior Flow version if rollback is needed

Do NOT remove the original Flow version until the Apex replacement is verified stable in production.
Do NOT introduce DML in loops in the refactored Apex.
Do NOT skip CRUD/FLS enforcement — the Flow may have had implicit system context.
```

---

## 10. Refactor Apex

Attach `salesforce-ai-skills/apex_guidelines.md` to your session before using this prompt.

```
Guideline file to attach: salesforce-ai-skills/apex_guidelines.md

You are a Senior Salesforce Developer. Follow ALL rules in the attached apex_guidelines.md.

Task: Refactor the following Apex class:
[PASTE THE APEX CLASS HERE]

Issues to address:
[DESCRIBE THE SPECIFIC ISSUES — choose all that apply:
  - SOQL in loop (line ~XX)
  - DML in loop (line ~XX)
  - Missing CRUD checks
  - Missing FLS checks
  - Business logic in trigger handler (should be in service class)
  - No test coverage / insufficient test coverage
  - Missing sharing declaration
  - Hardcoded IDs (line ~XX)
  - Hardcoded endpoint URLs (should use Named Credentials)
  - No error logging
  - Catch block swallowing exceptions silently
  - Method too long (exceeds single-responsibility principle)
  - Missing developer header
]

Required output format:

1. PLAN
   Issue inventory:
   For each issue:
   - Issue: [description]
   - Rule violated: [which rule in apex_guidelines.md this breaks]
   - Impact: [what could go wrong in production if this is not fixed]
   - Fix approach: [how you will correct it]

   Structural changes (if any):
   - Does the refactor require creating new classes (Selector, Service)?
   - Does it require splitting one large class into multiple smaller ones?
   - State the target structure after refactor

2. FILES
   Classes to modify:
   - [ClassName]: [what changes will be made]
   Classes to create (if needed):
   - [NewClassName]: [purpose]

3. IMPLEMENTATION
   Show ONLY the changed methods/blocks, not the full class unless a structural change is needed.
   Format each change as:

   Class: [ClassName]
   Method: [methodName]
   Change: [what changed and why]

   BEFORE:
   [original code block]

   AFTER:
   [corrected code block with inline comments explaining key changes]

   If the class structure changes (e.g., business logic extracted to service class):
   show the full refactored version of each class.

4. SECURITY
   For each security correction:
   - What CRUD check was added and where
   - What FLS check was added and where
   - What sharing model correction was made
   - What hardcoded value was replaced and with what

5. TESTING
   For each logical change made:
   - Which existing test method needs to be updated (and how)
   - Which new test method should be added
   Provide the full code for any new test methods.

6. VALIDATION
   - sf CLI deploy command for the modified classes
   - sf apex run test command for the test class
   - Specific test methods that validate the refactored logic

7. ROLLBACK
   - git command to revert to prior version if the refactor causes issues
   - Note which changes are behavior changes vs purely structural refactors
     (behavior changes carry more rollback risk)

Do NOT modify methods or logic that are not part of the stated issues.
Show targeted diffs where possible — do NOT rewrite the entire class unless structure changes require it.
Do NOT introduce new bugs while fixing the stated issues — only change what is necessary.
```

---

## 11. Create Permission Set

Attach `salesforce-ai-skills/permission_set_guidelines.md` to your session before using this prompt.

```
Guideline file to attach: salesforce-ai-skills/permission_set_guidelines.md

You are a Senior Salesforce Developer. Follow ALL rules in the attached permission_set_guidelines.md.

Task: Create a permission set for [ROLE/PERSONA — e.g., "Support Agent who needs to
read and create Cases, read Contacts, read Accounts, and access the caseDashboardContainer
LWC component and CaseService Apex class"].

Required output format:

1. PLAN
   Least-privilege analysis:
   For each permission being granted, state the business justification:

   | Permission | Object/Field/Class | Level | Justification |
   |---|---|---|---|
   | Case | Object | Read, Create | Agent must view and log cases |
   | Case.Case_Category__c | Field | Read, Edit | Agent must categorize cases |
   | Contact | Object | Read only | Agent must look up contact for case |
   | CaseService | Apex Class | Enabled | LWC controller requires this class |

   Profile edit assessment:
   - Confirm: this change should be done via Permission Set, NOT by editing a Profile
   - Justification: permission sets follow least-privilege; profiles should not be modified

   Custom Permission assessment:
   - Does any bypass logic (recursion guard, skip-validation logic) reference a Custom Permission?
   - If yes: which Custom Permission should be included in this set?

2. FILES
   Permission Set file:
   - force-app/main/default/permissionsets/PS_[DomainOrRole].permissionset-meta.xml
   Permission Set Group file (if applicable):
   - force-app/main/default/permissionsetgroups/PSG_[GroupName].permissionsetgroup-meta.xml

3. IMPLEMENTATION
   Complete permissionset-meta.xml with:
   - API Name: PS_[DomainOrRole] (e.g., PS_SupportAgent)
   - Label: descriptive human-readable label
   - Description: who this is for and what it enables
   - Object permissions (ONLY the objects listed in the plan — no extras):
     Read, Create, Edit, Delete, ViewAll, ModifyAll — grant minimum required
   - Field permissions (ONLY the fields the role needs):
     readable, editable — grant minimum required
   - Apex class access (ONLY classes called by the user's actions):
     enabled = true
   - Custom permission (if applicable)

   Example structure:
   <objectPermissions>
       <allowCreate>true</allowCreate>
       <allowDelete>false</allowDelete>
       <allowEdit>true</allowEdit>
       <allowRead>true</allowRead>
       <modifyAllRecords>false</modifyAllRecords>
       <object>Case</object>
       <viewAllRecords>false</viewAllRecords>
   </objectPermissions>

4. SECURITY
   - Confirm: no Modify All or View All granted unless explicitly justified in the plan
   - Confirm: no System Administrator level permissions included
   - Confirm: no Apex class access granted for classes not needed by this persona
   - If any Modify All / View All / Delete is granted: state the specific justification

5. TESTING
   Post-deploy verification steps:
   - Assign the permission set to a test user in sandbox
   - Log in as that test user
   - Verify: can access the objects and fields specified
   - Verify: LWC component loads in the specified page context
   - Verify: Apex controller executes without access errors
   - Verify: permissions NOT granted are not accessible (negative test)

6. VALIDATION
   sf CLI commands:
   - Note: Permission Sets must be deployed AFTER all objects, fields, and Apex classes
     they reference are already in the org
   - Deploy command for the permission set
   - Verify: sf org display to confirm correct target org before deploying

7. ROLLBACK
   - Remove permission set assignment from test users in case of issues
   - sf deploy command to redeploy prior version of the permission set from source control
   - If permission set is new: delete from org and remove from source control

Do NOT add permissions to Profiles.
Do NOT grant Modify All or View All without explicit business justification documented in this file.
Do NOT include permissions for objects, fields, or classes not listed in the plan.
```

---

## 12. Create FlexiPage

Attach `salesforce-ai-skills/flexipage_guidelines.md` to your session before using this prompt.

```
Guideline file to attach: salesforce-ai-skills/flexipage_guidelines.md

You are a Senior Salesforce Developer. Follow ALL rules in the attached flexipage_guidelines.md.

Task: Design a [RECORD PAGE / APP PAGE / HOME PAGE] FlexiPage for [OBJECT / APP — e.g.,
"Case Record Page for Support Agents showing Dynamic Form fields, Related Cases tab,
and the caseDashboardContainer LWC in a right-hand sidebar"].

Required output format:

1. PLAN
   Page type and purpose:
   - Page type: Record Page / App Page / Home Page
   - Target object (for Record Page): [e.g., Case]
   - Purpose: [what problem this page solves for the user]

   Component inventory:
   - List each component to be placed on the page, its region, and its purpose
   Example:
   | Component | Region | Purpose |
   |---|---|---|
   | Dynamic Form | Main Left | Case fields using conditional visibility |
   | caseDashboardContainer | Main Right | Related metrics for this case |
   | Related Cases | Tab Section | Quick view of related cases |
   | Highlights Panel | Top | Key fields at a glance |

   Activation rules decision:
   - NEVER activate globally without an activation rule
   - Activation scope: [specific Profile(s) + App(s) + Record Type(s)]
   - State which profile(s) and app(s) this page targets
   - State which record type(s) this page applies to (if applicable)

   Dynamic Forms vs Page Layout decision:
   - Use Dynamic Forms if: conditional field visibility is needed, or field grouping by
     section needs to be controlled per record type
   - Use Page Layout reference if: the existing page layout is sufficient and no dynamic
     visibility rules are needed

2. FILES
   - FlexiPage file: force-app/main/default/flexipages/[PageApiName].flexipage-meta.xml
   - Note: LWC components listed in this FlexiPage MUST already be deployed to the org
     before the FlexiPage is deployed

3. IMPLEMENTATION
   FlexiPage structure:
   - pageType element: RecordPage / AppPage / HomePage
   - sobjectType element (for Record Pages): the API name of the object
   - flexiPageRegions: define each region (main, sidebar, header, etc.)
   - componentInstances: one per component placed on the page
     - componentName: the API name of the LWC or standard component
     - componentInstanceProperties: any @api property values set on the component
   - componentVisibilityRules: conditions for showing/hiding components
     (e.g., hide caseDashboardContainer if current user does not have PS_SupportAgent)
   - targetConfigs / targets: which page surface this is built for
     (lightning__RecordPage, lightning__AppPage, etc.)
   - Mobile considerations: define separate regions or visibility rules for mobile if needed

4. SECURITY
   Component visibility rules to restrict sensitive components:
   - Example: caseDashboardContainer should only be visible to users with PS_SupportAgent
   - How to implement: componentVisibilityRules using Permission Set assignment check
   - Note: visibility rules are UI-only — server-side access control must exist in the Apex controller

5. TESTING
   - Deploy to sandbox and activate for your test user's profile/app
   - Log in as a test user with the correct permission set
   - Verify all components render without errors
   - Verify component visibility conditions work: log in as a user WITHOUT the required
     permission set and confirm restricted components are hidden
   - Test on mobile (if the page targets mobile)
   - Verify no JavaScript console errors on page load

6. VALIDATION
   sf CLI commands:
   - Confirm LWC components are deployed first (prerequisite)
   - Deploy the FlexiPage
   - How to activate the page in App Builder (or via Activation metadata)

7. ROLLBACK
   - Keep the prior active FlexiPage activation — note its job ID or prior version
   - git command to revert FlexiPage to prior version
   - How to re-activate the prior page in App Builder if the new page causes issues

Do NOT deploy the FlexiPage before its LWC components are deployed.
Do NOT activate the FlexiPage globally (without App + Profile activation rules).
Do NOT use FlexiPage visibility rules as the sole security enforcement — server-side controls
must also exist in the component's Apex controller.
```

---

## 13. Create Prompt Template

Attach `salesforce-ai-skills/prompt_template_guidelines.md` to your session before using this prompt.

```
Guideline file to attach: salesforce-ai-skills/prompt_template_guidelines.md

You are a Senior Salesforce Developer. Follow ALL rules in the attached prompt_template_guidelines.md.

Task: Design a Prompt Builder prompt template for [PURPOSE — e.g., "generating a case
resolution summary using the case subject, description, resolution notes, and related
contact name — to be surfaced to the support agent for review before sending to the customer"].

Required output format:

1. PLAN
   Template design:
   - Template type: [Field Generation / Record Summary / Sales Email / Custom — verify type
     availability in your target org and release]
   - Target object: [e.g., Case]
   - Grounding data sources: list each field and related object to be used as merge fields
   Example:
   | Data Source | Field | Merge Field Token | Purpose |
   |---|---|---|---|
   | Case | Subject | {!Case.Subject} | Summary title |
   | Case | Description | {!Case.Description} | Problem context |
   | Case.Contact | Name | {!Case.Contact.Name} | Customer name for personalization |
   - Expected output format: [e.g., "A 3-sentence paragraph in professional tone, no bullet points"]

2. FILES
   Note: Prompt Builder templates are created and managed in Setup UI (Setup > Einstein > Prompt Builder).
   They are NOT deployed via package.xml in all releases — verify deployment support in your target release.
   Document the template design here for implementation in Prompt Builder.

3. IMPLEMENTATION
   Full template text:

   System instruction (if applicable):
   You are a helpful support assistant. Generate a professional, empathetic case resolution
   summary for the agent to review.

   Prompt body:
   Use the following case information to generate a resolution summary.

   Case Subject: {!Case.Subject}
   Case Description: {!Case.Description}
   Resolution Notes: {!Case.Resolution_Notes__c}
   Customer Name: {!Case.Contact.Name}

   Safety instructions (REQUIRED — include in every template):
   - Do not include any information that is not present in the above case fields.
   - Do not make assumptions about the customer's situation beyond what is provided.
   - Do not include the customer's email address, phone number, or other contact details
     in the generated summary.
   - Do not include account numbers, payment details, or sensitive identifiers.

   Output format specification:
   Write a 2-3 sentence professional summary suitable for a customer-facing email.
   Start with an acknowledgment of the issue. End with confirmation that it has been resolved.
   Do not use bullet points. Do not use technical jargon.

   Example expected output:
   "We understand you experienced [issue description] with [product/service]. Our team has
   [resolution action taken] to resolve this matter. The case is now closed and we appreciate
   your patience throughout this process."

4. SECURITY
   PII policy for this template:
   - Confirm: the template does not instruct the model to include PII beyond what is in
     the specified merge fields
   - Confirm: generated outputs are NOT logged to AppLog__c without explicit audit justification
   - Confirm: the template safety instructions prevent the model from hallucinating
     customer data not present in the merge fields
   - Human review gate: is this output shown to an agent for review before being sent?
     (Recommended: yes, for all customer-facing outputs)

5. TESTING
   Test inputs and expected outputs:
   Test case 1 (complete data):
   - Input: [provide a sample case with all fields populated]
   - Expected output: [describe what a good output looks like]
   - Hallucination check: confirm the output contains ONLY information from the input fields

   Test case 2 (missing field):
   - Input: Case with Resolution_Notes__c empty
   - Expected output: graceful handling — should not hallucinate resolution notes

   Test case 3 (sensitive data in description):
   - Input: Case description contains a credit card number
   - Expected output: summary should NOT include the card number
     (this validates the safety instructions work)

   How to test: use Prompt Builder Preview in Setup with actual Case records from sandbox.

6. VALIDATION
   - Test in Prompt Builder Preview before activating
   - Test with at least 5 different case records covering different categories
   - Verify output format matches specification in all 5 tests
   - Have the output reviewed by a business stakeholder before activating for production use

7. ROLLBACK
   - Deactivate the template version in Prompt Builder
   - Reactivate the prior version (if one exists)

Verify merge field syntax and template type availability in your target org and release.
Verify which API version of Prompt Builder is available in your org before implementing.
```

---

## 14. Create Visualforce Page

Attach `salesforce-ai-skills/visualforce_guidelines.md` to your session before using this prompt. Note: always assess and document the LWC migration path even when building in Visualforce.

```
Guideline file to attach: salesforce-ai-skills/visualforce_guidelines.md

You are a Senior Salesforce Developer. Follow ALL rules in the attached visualforce_guidelines.md.

FIRST STEP — Justify the use of Visualforce:
Before any implementation, state the specific reason why this cannot be implemented in LWC.
Valid justifications:
  - PDF rendering (renderAs="pdf") — LWC does not support PDF rendering natively
  - Legacy integration point that explicitly requires a Visualforce page URL
  - Custom portal requirement predating LWC availability

If the justification is invalid, recommend LWC instead and stop.

Task: Create a Visualforce page for [PURPOSE — e.g., "rendering a Case record as a
branded PDF document for customer download, including case subject, description,
resolution notes, and company logo"].

Required output format:

1. PLAN
   Justification for Visualforce (must be stated first):
   [e.g., "PDF rendering via renderAs='pdf' is the only current way to produce
   server-rendered PDF documents in Salesforce without a third-party tool."]

   Controller type decision:
   - standardController with extension (for record-focused pages)
   - Custom controller (for complex multi-object pages)
   - State which and why

   Sharing model:
   - Controller must use with sharing unless there is an explicit documented reason for without sharing
   - State sharing decision and justification

   CRUD/FLS approach:
   - For standardController: relies on standard controller's built-in access check
   - For custom controller: explicit Schema checks in the controller

   PDF vs interactive:
   - renderAs="pdf" for PDF output
   - Standard for interactive pages

   LWC migration path (document even if not implementing now):
   - When could this be replaced by an LWC + Print CSS solution?
   - What would need to change in the org to enable that migration?

2. FILES
   - Page file: force-app/main/default/pages/[PageName].page
   - Page meta: force-app/main/default/pages/[PageName].page-meta.xml
   - Controller: force-app/main/default/classes/[PageName]Controller.cls (if custom controller)
   - Controller meta: force-app/main/default/classes/[PageName]Controller.cls-meta.xml
   - Test class: force-app/main/default/classes/[PageName]ControllerTest.cls

3. IMPLEMENTATION
   Visualforce page:
   - <apex:page> with renderAs="pdf" (if PDF), controller reference, with sharing implied
   - All output uses <apex:outputText> or <apex:outputField> — never raw {!value} expressions
     (XSS prevention — raw merge fields in Visualforce are NOT auto-escaped in all contexts)
   - No hardcoded IDs, org-specific values, or absolute URLs
   - Minimal view state: <apex:page> properties optimized for PDF if applicable

   Controller (if custom):
   - Developer header: Developer: Naresh, Title: Senior Salesforce Developer
   - with sharing declared
   - CRUD check at constructor using Schema.sObjectType.[Object].isAccessible()
   - FLS check for each field accessed using Schema.sObjectType.[Object].fields.[Field].isAccessible()
   - transient keyword on all properties that don't need view state
   - No SOQL in constructors beyond the initial record fetch
   - AuraHandledException or custom exception if record not found

4. SECURITY
   - with sharing on controller: confirmed
   - CRUD check location: [constructor method, line ~XX]
   - FLS check locations: [list each field and where it is checked]
   - XSS prevention: all output through <apex:outputText> / <apex:outputField>
   - No system mode (without sharing) unless justified
   - No hardcoded record IDs in code or page

5. TESTING
   Test class with:
   - @TestSetup creates required records
   - CRUD check test: run as user without object access, assert access denied
   - Happy path test: run as user with correct access, assert page renders data correctly
   - Negative path test: invalid record ID in URL parameter, assert graceful error handling
   - PDF rendering: note that PDF rendering cannot be fully unit-tested — test the controller logic
     independently of the renderAs attribute

6. VALIDATION
   sf CLI commands:
   - Deploy page, controller, and test class
   - Run test class
   - How to access the page in sandbox for manual verification

7. ROLLBACK
   - Deactivate the page (remove from permission sets / profiles granting access)
   - Redeploy prior version from source control
   - Note: Visualforce pages are immediately active on deploy — plan rollback before deploying

LWC migration path assessment (required even if not implementing now):
[State here: what would be needed to replace this Visualforce page with an LWC solution
and approximately when that migration would be feasible]

Do NOT use without sharing on the controller without explicit documented justification.
Do NOT use raw {!merge.field} expressions for output — always use apex:outputText or apex:outputField.
Do NOT skip the LWC migration path assessment.
```

---

## 15. Full Feature Implementation

Attach ALL guideline files to your session before using this prompt. This is the most comprehensive prompt — use it for new feature development that spans multiple metadata types.

```
Guideline files to attach:
  - salesforce-ai-skills/global_ai_development_guidelines.md
  - salesforce-ai-skills/apex_guidelines.md
  - salesforce-ai-skills/trigger_guidelines.md
  - salesforce-ai-skills/flow_guidelines.md
  - salesforce-ai-skills/lwc_guidelines.md
  - salesforce-ai-skills/deployment_guidelines.md
  - salesforce-ai-skills/observability_logging_guidelines.md

You are a Senior Salesforce Developer. Follow ALL rules in ALL attached guideline files.
Where guidelines overlap, apply the stricter rule.

Task: Implement the following Salesforce feature end-to-end:
[DESCRIBE THE FULL FEATURE — include:
  - Business problem being solved
  - Objects involved (new and existing)
  - User-facing components needed (pages, LWC, flows)
  - Backend logic needed (Apex, triggers, flows)
  - Integrations required (external systems, Named Credentials)
  - Access control requirements (which personas need access)
  - Any reporting or observability requirements
]

IMPORTANT: Present the PLAN section for confirmation before writing any code.
Do NOT proceed to FILES or IMPLEMENTATION until the plan is confirmed.

Required output format:

1. PLAN
   Architecture overview:
   - State the overall design in 3-5 sentences
   - Identify the primary metadata layers: schema, automation, Apex, UI, access

   Complete metadata inventory (all components to create or modify):
   | Component Name | Type | New or Modified | Depends On |
   |---|---|---|---|
   | [ComponentName] | [MetadataType] | New | [Dependencies] |

   Dependency map:
   - List deployment waves required
   - Wave 1: [schema — objects, fields]
   - Wave 2: [automation — flows, subflows]
   - Wave 3: [Apex — triggers, services, selectors]
   - Wave 4: [UI — LWC, FlexiPages]
   - Wave 5: [access — permission sets, groups]

   Risk assessment:
   - Data risks: any fields being deleted, required fields being added to objects with existing data
   - Performance risks: trigger on high-volume object, complex flow on frequent DML
   - Security risks: any system-context operations that need CRUD/FLS review
   - Rollback complexity: which components can be rolled back easily vs which require data migration

   — STOP HERE — Present this plan for confirmation before proceeding —

2. FILES
   Complete file list organized by metadata type:
   [List every file path]

3. IMPLEMENTATION
   All code and configuration organized by component:

   For each Apex class:
   - Developer header, sharing declaration, full implementation

   For each Flow:
   - Complete element-by-element design (flows are described, not shown as XML)
   - All fault paths confirmed

   For each LWC:
   - All four files (.html, .js, .js-meta.xml, test file)

   For each permission set:
   - Full permissionset-meta.xml

   For package.xml:
   - Complete manifest in dependency order

4. SECURITY
   Per-component security summary:
   | Component | Sharing Model | CRUD/FLS | Hardcoded Values | Notes |
   |---|---|---|---|---|
   | [ClassName] | with sharing | SObjectType check at entry | None | |

   Cross-cutting security concerns:
   - Which components run in system context and why
   - All Named Credentials used for callouts
   - No hardcoded IDs anywhere

5. TESTING
   Testing strategy per component type:

   Apex tests (full test class code for all service and selector classes):
   - @TestSetup, happy path, negative, bulk 200 records, async (if applicable), mock callout (if applicable)

   Flow coverage:
   - Which Apex test classes exercise the flows indirectly
   - How to manually test flows in sandbox

   Jest tests (for each LWC):
   - Loading state, error state, success state, empty state
   - All event contracts

   Integration tests (end-to-end scenario):
   - Test the full feature path from trigger to end result

6. VALIDATION
   Dependency-ordered deployment plan:
   Wave 1 command: [sf deploy wave1]
   Wave 2 command: [sf deploy wave2]
   ...
   Final validation command: [sf deploy --check-only --test-level RunLocalTests]
   Quick deploy command: [sf deploy quick --job-id PLACEHOLDER]

7. ROLLBACK
   Per-component rollback strategy:
   | Component | Rollback Method | Complexity |
   |---|---|---|
   | [ComponentName] | git revert + redeploy | Low |
   | [FlowName] | Reactivate prior version | Low |
   | [NewField] | Cannot delete if data exists | High — data impact |

   Rollback order (reverse of deployment order):
   1. Deactivate FlexiPage
   2. Remove permission set assignments
   3. Redeploy prior Apex
   4. Reactivate prior Flow version
   5. Assess field data before removing fields

Do NOT modify unrelated metadata.
Do NOT proceed past the PLAN without confirmation.
Do NOT skip any security or testing section.
Do NOT deploy directly to production — confirm staging environment validations first.
```

---

## 16. Security / Standards Audit

Attach `salesforce-ai-skills/global_ai_development_guidelines.md` to your session before using this prompt.

```
Guideline file to attach: salesforce-ai-skills/global_ai_development_guidelines.md

You are a Senior Salesforce Developer. Audit the following Salesforce components against
the attached global_ai_development_guidelines.md AND all applicable component-specific
standards (Apex, Flow, LWC as relevant to the components provided).

Components to audit:
[LIST COMPONENT NAMES — e.g.:
  - CaseService.cls (paste code below)
  - CaseTrigger.trigger (paste code below)
  - Case_AfterSave_RecordTriggered flow (describe or paste XML)
  - caseDashboardContainer LWC (paste code below)
]

[PASTE ALL COMPONENT CODE HERE]

Audit checklist — check every item for every applicable component:

SECURITY
- [ ] CRUD enforcement at every entry point that processes user-sourced data
- [ ] FLS enforcement for every field read or written in Apex
- [ ] sharing model explicit on every class (with sharing / without sharing / inherited sharing)
- [ ] No hardcoded record IDs anywhere in code
- [ ] No hardcoded API endpoints — Named Credentials used for all callouts
- [ ] No passwords, tokens, or secrets in code
- [ ] No PII in log messages

BULK SAFETY
- [ ] No SOQL inside for loops
- [ ] No DML inside for loops
- [ ] Trigger handler processes collections, not individual records

FLOW-SPECIFIC
- [ ] Fault path on every DML element (Create Records, Update Records, Delete Records)
- [ ] Fault path on every Apex Action element
- [ ] DML not inside a Loop element
- [ ] LogError_Subflow called on all fault paths
- [ ] Entry condition prevents unnecessary flow runs (ISCHANGED used where appropriate)

APEX QUALITY
- [ ] Developer header on every class
- [ ] No business logic directly in trigger file
- [ ] Recursion guard present in trigger handler
- [ ] Custom exceptions used instead of generic Exception
- [ ] AppLogger called at error paths
- [ ] No catch blocks that swallow exceptions silently (catch + log + rethrow)

TESTING
- [ ] Test coverage >= 75% confirmed
- [ ] @TestSetup method creates test data (no SeeAllData=true)
- [ ] Bulk test with 200 records present
- [ ] Negative test cases present
- [ ] All assertions include descriptive messages
- [ ] Mock callout used for any HTTP callout tests

DEPLOYMENT
- [ ] Developer header present
- [ ] Dependency order correct in package.xml (if provided)

Required output format:

AUDIT RESULTS TABLE
For each checklist item, for each applicable component:

| Checklist Item | Component | Result | Evidence / Location |
|---|---|---|---|
| CRUD enforcement | CaseService | FAIL | No CRUD check at processInbound() entry point |
| SOQL in loop | CaseService | PASS | All SOQL outside loops |
| Developer header | CaseTrigger | FAIL | No header comment |

Use: PASS / FAIL / NOT APPLICABLE

FINDINGS DETAIL
For each FAIL:
- Severity: CRITICAL / HIGH / MEDIUM / LOW
- Component: [ClassName or FlowName]
- Location: [method name, line reference, or element name]
- Checklist item violated: [exact item from checklist above]
- Issue: [description of what is wrong]
- Fix: [exact corrected code or specific action required]

SUMMARY
| Severity | Count |
|---|---|
| CRITICAL | [n] |
| HIGH | [n] |
| MEDIUM | [n] |
| LOW | [n] |
| TOTAL ISSUES | [n] |

Estimated remediation effort: [hours or story points]
Recommendation: APPROVE (0 CRITICAL, 0 HIGH) / APPROVE WITH CONDITIONS (only MEDIUM/LOW)
  / DO NOT MERGE (any CRITICAL or HIGH)

PRIORITY REMEDIATION LIST
Ordered list of items that MUST be fixed before this can be merged to production:
1. [CRITICAL finding — component — fix]
2. [CRITICAL finding — component — fix]
3. [HIGH finding — component — fix]
...

Do NOT approve components with CRITICAL or HIGH findings.
Do NOT suggest changes outside the reviewed component scope.
```

---

## Quick Reference: Guideline File → Prompt Mapping

| Task | Guideline File(s) to Attach |
|---|---|
| Create Apex Class | apex_guidelines.md |
| Create Trigger | trigger_guidelines.md |
| Create Flow | flow_guidelines.md |
| Create LWC | lwc_guidelines.md |
| Create Agentforce Agent | agentforce_builder_guidelines.md + agentforce_script_guidelines.md |
| Review Code | global_ai_development_guidelines.md |
| Create package.xml | deployment_guidelines.md |
| Validate Deployment | deployment_guidelines.md |
| Refactor Flow to Apex | apex_guidelines.md + flow_guidelines.md |
| Refactor Apex | apex_guidelines.md |
| Create Permission Set | permission_set_guidelines.md |
| Create FlexiPage | flexipage_guidelines.md |
| Create Prompt Template | prompt_template_guidelines.md |
| Create Visualforce Page | visualforce_guidelines.md |
| Full Feature Implementation | All guidelines |
| Security Audit | global_ai_development_guidelines.md |
| Add Logging | observability_logging_guidelines.md |
| Plan Production Deployment | deployment_guidelines.md |
