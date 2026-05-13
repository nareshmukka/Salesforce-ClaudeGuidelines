# Agentforce Builder Configuration Guidelines

**Version**: 2.0 (April 2026)
**Developer**: Naresh | Senior Salesforce Developer
**Purpose**: Guidelines for the metadata-level configuration of Agentforce agents using Agentforce Builder and Salesforce CLI. Covers Bot, GenAiPlannerBundle, GenAiPlugin, GenAiFunction, and their relationship to Flows and Apex invocables.

> **Critical**: Agentforce metadata API types and CLI capabilities change with each Salesforce release. Every item marked "verify in target org/release" MUST be confirmed before implementation. Do not assume metadata type names, CLI flags, or retrieval behaviors from training data alone.

---

## Table of Contents

1. [Required Agent Output Contract](#1-required-agent-output-contract)
2. [Metadata Type Hierarchy](#2-metadata-type-hierarchy)
3. [Bot Metadata](#3-bot-metadata)
4. [Topics / Subagents (GenAiPlugin)](#4-topics--subagents-genaiplugin)
5. [Actions (GenAiFunction)](#5-actions-genaifunction)
6. [GenAiPlannerBundle](#6-genaiplannerbundle)
7. [Flows / Actions Called by Agentforce](#7-flows--actions-called-by-agentforce)
8. [Apex Invocable Actions](#8-apex-invocable-actions)
9. [Variable Mapping](#9-variable-mapping)
10. [Strict Step Order in Instructions](#10-strict-step-order-in-instructions)
11. [Knowledge Fallback](#11-knowledge-fallback)
12. [Authentication / Verification Gating](#12-authentication--verification-gating)
13. [Detailed Example: Support Case Creation Agent](#13-detailed-example-support-case-creation-agent)
14. [Action Result Handling](#14-action-result-handling)
15. [No Hallucinated Action Outputs](#15-no-hallucinated-action-outputs)
16. [Test Conversations](#16-test-conversations)
17. [Deployment / Retrieval Caveats](#17-deployment--retrieval-caveats)
18. [Salesforce CLI Caveats](#18-salesforce-cli-caveats)
19. [Source Completeness Checklist](#19-source-completeness-checklist)
20. [Common AI Mistakes to Avoid](#20-common-ai-mistakes-to-avoid)
21. [Definition of Done (Agentforce Builder)](#21-definition-of-done-agentforce-builder)
22. [Official References](#22-official-references)

---

## 1. Required Agent Output Contract

Every Agentforce Builder configuration response MUST include all of the following. Do not provide a partial configuration — missing any of these sections creates deployment risk or runtime failures.

1. **Complete metadata inventory** — list every file required: Bot, BotVersion, PlannerBundle, Plugin(s), Function(s), with API names and file paths
2. **Action-to-flow/Apex mapping table** — for each GenAiFunction: the function API name, the invocation type (flow/apex), and the exact target API name
3. **Variable binding contract for every action** — all input variable names, all output variable names, types, required/optional flag, and which conversation variable each output maps to
4. **Orchestration sequence (numbered steps, gates)** — exact step order with gate conditions and failure paths, matching the instructions in the PlannerBundle
5. **Source control completeness checklist** — all files that must be committed together as an atomic set
6. **CLI retrieval and deployment commands** — specific commands with correct metadata type names (verify flags in current release before providing)
7. **Test conversation plan** — all 6+ scenarios listed with expected outcomes
8. **Rollback approach** — specific steps to deactivate new version and reactivate prior version

---

## 2. Metadata Type Hierarchy

### Visual Hierarchy

```
Bot (.bot-meta.xml)
└── Bot Version (.botVersion-meta.xml)
    └── References: GenAiPlannerBundle

GenAiPlannerBundle (.genAiPlannerBundle-meta.xml)
├── Agent-level instructions (natural language prompt)
├── Conversation variable definitions
├── Topic routing rules
└── GenAiPlugin references (one per topic/subagent)
    └── GenAiPlugin (.genAiPlugin-meta.xml) — one per topic
        ├── Topic-level instructions (natural language prompt)
        ├── Topic description (used by LLM for routing decisions)
        └── GenAiFunction references (one per action within topic)
            └── GenAiFunction (.genAiFunction-meta.xml) — one per action
                ├── Function description (used by LLM for action selection)
                ├── Input parameter definitions
                ├── Output parameter definitions
                └── Invocation target
                    ├── type: flow → targets an Autolaunched Flow by API name
                    └── type: apex → targets an @InvocableMethod class by method name
```

### Relationship Rules

| Relationship | Rule |
|---|---|
| Bot → PlannerBundle | Bot activates a specific version of a PlannerBundle |
| PlannerBundle → Plugins | PlannerBundle references which GenAiPlugins (topics) are available |
| Plugin → Functions | GenAiPlugin references which GenAiFunctions (actions) are available in that topic |
| Function → Flow/Apex | GenAiFunction references the exact API name of a deployed, active Flow or Apex invocable class |
| Function descriptions | The LLM reads function descriptions at runtime to decide which action to call — accuracy is critical |
| Plugin descriptions | The LLM reads topic descriptions at runtime to decide which topic matches the user's intent — precision is critical |

### Deployment Dependency Order

Because lower layers reference components that must already exist, always deploy in this order:

```
1. Apex invocable classes (must be deployed and active)
2. Autolaunched Flows (must be deployed and active version exists)
3. GenAiFunctions (reference Flows/Apex by API name — target must exist)
4. GenAiPlugins (reference GenAiFunctions — functions must exist)
5. GenAiPlannerBundle (references Plugins — plugins must exist)
6. Bot / BotVersion (references PlannerBundle — bundle must exist)
```

---

## 3. Bot Metadata

### Bot File Structure

> Verify XML structure and available elements against the current Salesforce Metadata API documentation for your API version.

```xml
<!-- SupportPortal_Agent.bot-meta.xml -->
<?xml version="1.0" encoding="UTF-8"?>
<Bot xmlns="http://soap.sforce.com/2006/04/metadata">
    <botVersions>
        <fullName>v2</fullName>
        <active>true</active>
    </botVersions>
    <contextVariables>
        <contextVariableMappings>
            <SObjectType>MessagingSession</SObjectType>
            <fieldName>RoutableId</fieldName>
            <messageType>InApp</messageType>
        </contextVariableMappings>
        <dataType>Id</dataType>
        <developerName>RoutableId</developerName>
        <label>Routable ID</label>
    </contextVariables>
    <label>Support Portal Agent</label>
    <logPrivateConversationData>false</logPrivateConversationData>
    <richContentEnabled>false</richContentEnabled>
    <sessionEndedChatLabel>Session Ended</sessionEndedChatLabel>
    <sessionEndedChatMessage>Your chat session has ended.</sessionEndedChatMessage>
</Bot>
```

### Bot Version File

```xml
<!-- v2.botVersion-meta.xml -->
<?xml version="1.0" encoding="UTF-8"?>
<BotVersion xmlns="http://soap.sforce.com/2006/04/metadata">
    <botDialogs>
        <!-- Legacy dialog structure if applicable — verify in current release -->
    </botDialogs>
    <fullName>v2</fullName>
    <label>Version 2</label>
    <mainMenuDialog>Welcome</mainMenuDialog>
</BotVersion>
```

### Bot Metadata Rules

- One Bot record per agent — do not create multiple bots for the same agent purpose
- Bot label must be meaningful and match the business purpose (visible to admins in Setup)
- Always retrieve the existing bot metadata before modifying: `sf project retrieve start --metadata "Bot:SupportPortalAgent"`
- The `active` flag on a BotVersion controls which version runs — only one version should be active at a time
- Set `logPrivateConversationData` to `false` unless audit logging is explicitly required and approved by your security/compliance team
- Verify all available Bot metadata elements in the current API release — the structure above may have evolved

---

## 4. Topics / Subagents (GenAiPlugin)

### GenAiPlugin Metadata Structure

> Verify element names and attributes in the current Salesforce Metadata API documentation.

```xml
<!-- CaseCreation.genAiPlugin-meta.xml -->
<?xml version="1.0" encoding="UTF-8"?>
<GenAiPlugin xmlns="http://soap.sforce.com/2006/04/metadata">
    <description>
        Handles end-to-end support case creation for authenticated customers.
        Use this topic when the customer wants to create a new support case,
        report an issue, submit a ticket, or log a problem.
        This topic handles identity verification, contact resolution, case
        classification, and case submission.
        Do NOT use this topic for general questions, FAQ, or account lookup.
    </description>
    <developerName>CaseCreation</developerName>
    <genAiFunctions>
        <genAiFunction>FLO_SendVerificationCode_v2</genAiFunction>
        <genAiFunction>FLO_VerifyContact_v2</genAiFunction>
        <genAiFunction>FLO_CreateContactRecord_v2</genAiFunction>
        <genAiFunction>FLO_GetCasePicklists_v2</genAiFunction>
        <genAiFunction>FLO_CreateCase_v2</genAiFunction>
    </genAiFunctions>
    <instructions>
        <!-- Natural language topic instructions go here — see agentforce_script_guidelines.md -->
        <!-- Instructions are placed in the PlannerBundle in some releases — verify location -->
    </instructions>
    <label>Case Creation</label>
    <pluginType>Topic</pluginType>
</GenAiPlugin>
```

```xml
<!-- GeneralFAQ.genAiPlugin-meta.xml -->
<?xml version="1.0" encoding="UTF-8"?>
<GenAiPlugin xmlns="http://soap.sforce.com/2006/04/metadata">
    <description>
        Answers general customer questions using the knowledge base.
        Use this topic when the customer asks informational questions about
        products, services, policies, billing processes, or general how-to questions.
        Do NOT use this topic for case creation or account-specific data retrieval.
    </description>
    <developerName>GeneralFAQ</developerName>
    <genAiFunctions>
        <genAiFunction>KnowledgeSearch</genAiFunction>
    </genAiFunctions>
    <label>General FAQ</label>
    <pluginType>Topic</pluginType>
</GenAiPlugin>
```

### Topic Design Rules

- Each topic must have a **single, narrow scope** — one business process domain per topic
- The `description` field is read by the LLM at runtime to decide routing — it must be:
  - Precise about what this topic handles
  - Explicit about what this topic does NOT handle
  - Free of ambiguity that could cause misrouting
- 3 to 7 GenAiFunctions per topic is a reasonable range (verify any platform limits in target org)
- Topic names (developerName) must follow Salesforce naming conventions: alphanumeric, no spaces, no special characters except underscore
- Always include negative examples in the description ("Do NOT use for...") to prevent misrouting

---

## 5. Actions (GenAiFunction)

### GenAiFunction Structure — Flow Invocation

```xml
<!-- FLO_SendVerificationCode_v2.genAiFunction-meta.xml -->
<?xml version="1.0" encoding="UTF-8"?>
<GenAiFunction xmlns="http://soap.sforce.com/2006/04/metadata">
    <description>
        Sends a verification code to the customer's email address to initiate
        identity verification. Call this as the very first action in any
        case creation conversation.
        Input: endUserEmail (String, required) — the customer's email address.
        Outputs: authenticationKey (String) — key used in subsequent verification step;
                 status (String) — 'SUCCESS' or 'ERROR';
                 outMessage (String) — human-readable result or error description.
    </description>
    <developerName>FLO_SendVerificationCode_v2</developerName>
    <genAiFunctionParameters>
        <genAiFunctionParameter>
            <description>The customer's email address. Required.</description>
            <developerName>endUserEmail</developerName>
            <dataType>String</dataType>
            <required>true</required>
        </genAiFunctionParameter>
    </genAiFunctionParameters>
    <invocationTarget>
        <type>flow</type>
        <targetApiName>SendVerificationCodeToEmail_v2</targetApiName>
    </invocationTarget>
    <label>Send Verification Code</label>
</GenAiFunction>
```

### GenAiFunction Structure — Apex Invocable Invocation

```xml
<!-- FLO_GetCasePicklists_v2.genAiFunction-meta.xml -->
<?xml version="1.0" encoding="UTF-8"?>
<GenAiFunction xmlns="http://soap.sforce.com/2006/04/metadata">
    <description>
        Retrieves the case classification picklist dependency matrix from
        Custom Metadata. Returns available categories and subcategories
        in JSON format for the agent to present to the customer.
        ONLY call after identity verification is complete (isVerified = true).
        Input: isVerified (Boolean, required) — must be true;
               requestKey (String, required) — use 'classification' for case categories.
        Outputs: matrixJson (String) — JSON string of category/subcategory pairs;
                 status (String) — 'SUCCESS' or 'ERROR';
                 outMessage (String) — error description if status = ERROR.
    </description>
    <developerName>FLO_GetCasePicklists_v2</developerName>
    <genAiFunctionParameters>
        <genAiFunctionParameter>
            <description>Must be true. Enforces that identity is verified before retrieving case options.</description>
            <developerName>isVerified</developerName>
            <dataType>Boolean</dataType>
            <required>true</required>
        </genAiFunctionParameter>
        <genAiFunctionParameter>
            <description>Lookup key for the type of matrix to retrieve. Use 'classification' for case categories.</description>
            <developerName>requestKey</developerName>
            <dataType>String</dataType>
            <required>true</required>
        </genAiFunctionParameter>
    </genAiFunctionParameters>
    <invocationTarget>
        <type>apexClass</type>
        <targetApiName>FLO_CasePicklistMatrixActionV2</targetApiName>
    </invocationTarget>
    <label>Get Case Picklist Matrix</label>
</GenAiFunction>
```

### GenAiFunction Design Rules

- The `description` field is the single most important element — the LLM uses it to decide when to call this function and what to pass to it
- Descriptions MUST accurately state:
  - What the function does (one sentence)
  - When to call it (preconditions)
  - All input variable names, types, and whether required or optional
  - All output variable names and types
- Input/output variable names in GenAiFunction MUST match the actual Flow variable API names or Apex invocable parameter field names **exactly** — they are case-sensitive
- Do not list outputs that the Flow/Apex does not actually produce — the LLM will attempt to read them and fail silently
- Mark optional inputs as optional in the description — the LLM needs to know whether to collect them
- `targetApiName` for flows must match the Flow's API name exactly (the name shown in Flow Builder's URL, not the flow label)
- `targetApiName` for Apex must match the Apex class name that contains the `@InvocableMethod` annotation

---

## 6. GenAiPlannerBundle

### What It Is

The GenAiPlannerBundle is the central metadata artifact that:
- Ties the agent's topics (plugins) together
- Defines conversation variables (variables that persist across steps within a session)
- Contains the full natural language instructions that govern the agent's behavior (in some releases — verify in target org)
- Defines variable bindings between action outputs and conversation variables

### PlannerBundle Structure

> Verify current XML schema in Metadata API documentation. This structure illustrates key elements — exact element names may vary by release.

```xml
<!-- SupportPortalAgent.genAiPlannerBundle-meta.xml -->
<?xml version="1.0" encoding="UTF-8"?>
<GenAiPlannerBundle xmlns="http://soap.sforce.com/2006/04/metadata">
    <description>
        Support Portal Agent — orchestrates identity verification, contact resolution,
        case classification, and case creation for authenticated customers.
    </description>
    <developerName>SupportPortalAgent</developerName>
    <label>Support Portal Agent</label>

    <!-- Agent-level instructions (verify where agent vs. topic instructions are stored in current release) -->
    <plannerType>Agent</plannerType>

    <!-- Conversation variable definitions -->
    <plannerVariables>
        <developerName>authKey</developerName>
        <dataType>String</dataType>
        <label>Authentication Key</label>
        <visibility>Internal</visibility>
    </plannerVariables>
    <plannerVariables>
        <developerName>var_IsVerified</developerName>
        <dataType>Boolean</dataType>
        <label>Is Customer Verified</label>
        <visibility>Internal</visibility>
    </plannerVariables>
    <plannerVariables>
        <developerName>var_ContactId</developerName>
        <dataType>Id</dataType>
        <label>Verified Contact ID</label>
        <visibility>Internal</visibility>
    </plannerVariables>
    <plannerVariables>
        <developerName>var_FinalContactId</developerName>
        <dataType>Id</dataType>
        <label>Final Contact ID</label>
        <visibility>Internal</visibility>
    </plannerVariables>
    <plannerVariables>
        <developerName>var_PicklistMatrix</developerName>
        <dataType>String</dataType>
        <label>Picklist Dependency Matrix JSON</label>
        <visibility>Internal</visibility>
    </plannerVariables>
    <plannerVariables>
        <developerName>var_CaseNumber</developerName>
        <dataType>String</dataType>
        <label>Created Case Number</label>
        <visibility>Internal</visibility>
    </plannerVariables>
    <plannerVariables>
        <developerName>draftConfirmed</developerName>
        <dataType>Boolean</dataType>
        <label>Customer Confirmed Draft</label>
        <visibility>Internal</visibility>
    </plannerVariables>

    <!-- Topic (Plugin) references -->
    <genAiPlugins>
        <genAiPlugin>CaseCreation</genAiPlugin>
        <genAiPlugin>GeneralFAQ</genAiPlugin>
    </genAiPlugins>
</GenAiPlannerBundle>
```

### PlannerBundle Rules

- Every conversation variable used by any action or referenced in instructions MUST be declared here
- Variable `developerName` values must match exactly how they are referenced in instructions and GenAiFunction mappings
- `visibility` = Internal means the variable is not surfaced to the end user; use this for all auth tokens, IDs, and intermediate state
- The PlannerBundle is retrieved as a single file but may contain complex nested elements — always retrieve before modifying
- In some org configurations, topic instructions are stored inside GenAiPlugin files rather than PlannerBundle — verify in your org

---

## 7. Flows / Actions Called by Agentforce

### Mandatory Flow Requirements

All Flows used as Agentforce actions MUST meet these requirements without exception:

**Flow type**: Must be an **Autolaunched Flow** (not a Screen Flow, not a Record-Triggered Flow)

**Input variables**: All inputs the agent needs to pass must be declared as Flow Variables with:
- `Available for Input` = true
- The correct data type (String, Boolean, Id, etc.)
- API names that exactly match what is declared in the GenAiFunction parameter definitions

**Output variables**: All outputs the agent needs to read must be declared as Flow Variables with:
- `Available for Output` = true
- The correct data type
- API names that exactly match what is declared in the GenAiFunction description

**Fault path**: Every Flow used by Agentforce MUST have a fault path on all DML and callout elements. The fault path MUST:
- Set `status` = 'ERROR'
- Set `outMessage` = a human-readable error description (optionally including `{!$Flow.FaultMessage}`)
- End the flow gracefully — do NOT let faults surface as unhandled exceptions to the agent

**Status output**: Every Flow MUST output a `status` variable with value 'SUCCESS' or 'ERROR'. The agent checks this before proceeding.

**outMessage output**: Every Flow MUST output an `outMessage` variable with a human-readable result or error message. The agent uses this in responses.

### Standard Flow Template

```
Flow: SendVerificationCodeToEmail_v2
Type: Autolaunched Flow
API Version: 62.0 (verify current)

Input Variables (Available for Input = true):
  - endUserEmail (Text)

Output Variables (Available for Output = true):
  - authenticationKey (Text)
  - status (Text)
  - outMessage (Text)

Flow Elements:
  [Start]
    → [Assignment: Set status = 'SUCCESS']
    → [Action: Send Email / Generate OTP]
         Fault → [Assignment: Set status = 'ERROR', outMessage = 'Failed to send code: ' + {!$Flow.FaultMessage}]
                   → [End]
    → [Assignment: Set authenticationKey = {generated key}]
    → [Assignment: Set outMessage = 'Verification code sent successfully.']
    → [End]
```

### Flow Activation

- Only active Flow versions are callable by Agentforce
- After updating a Flow, activate the new version and verify the GenAiFunction still points to the correct API name
- If the Flow API name changes, the GenAiFunction `targetApiName` must be updated to match

---

## 8. Apex Invocable Actions

### Mandatory Apex Requirements

All Apex invocable methods used by Agentforce MUST meet these requirements:

- Annotated with `@InvocableMethod(label='...' description='...')`
- Accept `List<Request>` parameter and return `List<Response>` (Salesforce invocable pattern)
- The `Request` inner class must have `@InvocableVariable` annotations on all fields used as inputs
- The `Response` inner class must have `@InvocableVariable` annotations on all fields used as outputs
- Must include `status` and `outMessage` in the Response class
- Must handle exceptions with try/catch — set `status = 'ERROR'` and `outMessage` = exception message
- Where `isVerified` is required: the method MUST check `isVerified == true` as its first gate and return an error response if false

### Full Apex Invocable Example: FLO_CasePicklistMatrixActionV2

```apex
/**
 * FLO_CasePicklistMatrixActionV2
 * Agentforce-callable invocable action.
 * Retrieves case classification picklist dependency matrix from Custom Metadata.
 *
 * Input:  isVerified (Boolean) — gate: must be true
 *         requestKey (String)  — e.g., 'classification'
 * Output: matrixJson (String)  — JSON representation of category/subcategory matrix
 *         status    (String)   — 'SUCCESS' or 'ERROR'
 *         outMessage (String)  — human-readable result or error
 *
 * @version 2.0
 */
public with sharing class FLO_CasePicklistMatrixActionV2 {

    @InvocableMethod(
        label='Get Case Picklist Matrix'
        description='Returns case category/subcategory dependency matrix as JSON. Requires isVerified = true.'
        category='Case Management'
    )
    public static List<Response> execute(List<Request> requests) {
        List<Response> responses = new List<Response>();

        for (Request req : requests) {
            Response res = new Response();

            // Gate: isVerified must be true
            if (req.isVerified == null || req.isVerified == false) {
                res.status = 'ERROR';
                res.outMessage = 'Identity verification is required before retrieving case options.';
                res.matrixJson = null;
                responses.add(res);
                continue;
            }

            // Gate: requestKey must be provided
            if (String.isBlank(req.requestKey)) {
                res.status = 'ERROR';
                res.outMessage = 'A requestKey is required. Use \'classification\' for case categories.';
                res.matrixJson = null;
                responses.add(res);
                continue;
            }

            try {
                // Query Custom Metadata for the picklist matrix
                // Replace Case_Picklist_Matrix__mdt with your actual Custom Metadata API name
                List<Case_Picklist_Matrix__mdt> matrixRecords = [
                    SELECT Category__c, Subcategory__c, DisplayOrder__c
                    FROM Case_Picklist_Matrix__mdt
                    WHERE RequestKey__c = :req.requestKey
                    AND IsActive__c = true
                    ORDER BY DisplayOrder__c ASC
                ];

                if (matrixRecords.isEmpty()) {
                    res.status = 'ERROR';
                    res.outMessage = 'No classification options found for key: ' + req.requestKey;
                    res.matrixJson = null;
                    responses.add(res);
                    continue;
                }

                // Build category → subcategory map
                Map<String, List<String>> categoryMap = new Map<String, List<String>>();
                for (Case_Picklist_Matrix__mdt record : matrixRecords) {
                    if (!categoryMap.containsKey(record.Category__c)) {
                        categoryMap.put(record.Category__c, new List<String>());
                    }
                    categoryMap.get(record.Category__c).add(record.Subcategory__c);
                }

                // Serialize to JSON
                res.matrixJson = JSON.serialize(categoryMap);
                res.status = 'SUCCESS';
                res.outMessage = 'Classification matrix retrieved successfully.';

            } catch (Exception ex) {
                res.status = 'ERROR';
                res.outMessage = 'An error occurred retrieving case options: ' + ex.getMessage();
                res.matrixJson = null;
            }

            responses.add(res);
        }

        return responses;
    }

    // =========================================================================
    // Request / Response Inner Classes
    // =========================================================================

    public class Request {
        @InvocableVariable(
            label='Is Verified'
            description='Must be true. Customer identity must be verified before calling this action.'
            required=true
        )
        public Boolean isVerified;

        @InvocableVariable(
            label='Request Key'
            description='Lookup key for the matrix type. Use classification for case categories.'
            required=true
        )
        public String requestKey;
    }

    public class Response {
        @InvocableVariable(
            label='Matrix JSON'
            description='JSON string of category to subcategory mappings.'
        )
        public String matrixJson;

        @InvocableVariable(
            label='Status'
            description='SUCCESS or ERROR.'
        )
        public String status;

        @InvocableVariable(
            label='Out Message'
            description='Human-readable result or error description.'
        )
        public String outMessage;
    }
}
```

### Test Class for FLO_CasePicklistMatrixActionV2

```apex
@IsTest
private class FLO_CasePicklistMatrixActionV2_Test {

    @IsTest
    static void testSuccessPath() {
        // Note: Custom Metadata records can be inserted in tests with Test.loadData()
        // or by mocking — verify your test data strategy for Custom Metadata
        FLO_CasePicklistMatrixActionV2.Request req = new FLO_CasePicklistMatrixActionV2.Request();
        req.isVerified = true;
        req.requestKey = 'classification';

        Test.startTest();
        List<FLO_CasePicklistMatrixActionV2.Response> responses =
            FLO_CasePicklistMatrixActionV2.execute(new List<FLO_CasePicklistMatrixActionV2.Request>{ req });
        Test.stopTest();

        System.assertNotEquals(null, responses, 'Response list should not be null');
        System.assertEquals(1, responses.size(), 'Should return exactly one response');
        // Status may be SUCCESS or ERROR depending on test data — assert on expected behavior
        System.assertNotEquals(null, responses[0].status, 'Status should be set');
        System.assertNotEquals(null, responses[0].outMessage, 'outMessage should be set');
    }

    @IsTest
    static void testVerificationGate() {
        FLO_CasePicklistMatrixActionV2.Request req = new FLO_CasePicklistMatrixActionV2.Request();
        req.isVerified = false;
        req.requestKey = 'classification';

        Test.startTest();
        List<FLO_CasePicklistMatrixActionV2.Response> responses =
            FLO_CasePicklistMatrixActionV2.execute(new List<FLO_CasePicklistMatrixActionV2.Request>{ req });
        Test.stopTest();

        System.assertEquals('ERROR', responses[0].status, 'Should return ERROR when isVerified = false');
        System.assert(
            responses[0].outMessage.containsIgnoreCase('verification'),
            'Error message should mention verification'
        );
        System.assertEquals(null, responses[0].matrixJson, 'matrixJson should be null on auth failure');
    }

    @IsTest
    static void testNullVerification() {
        FLO_CasePicklistMatrixActionV2.Request req = new FLO_CasePicklistMatrixActionV2.Request();
        req.isVerified = null;
        req.requestKey = 'classification';

        Test.startTest();
        List<FLO_CasePicklistMatrixActionV2.Response> responses =
            FLO_CasePicklistMatrixActionV2.execute(new List<FLO_CasePicklistMatrixActionV2.Request>{ req });
        Test.stopTest();

        System.assertEquals('ERROR', responses[0].status, 'Should return ERROR when isVerified = null');
    }

    @IsTest
    static void testMissingRequestKey() {
        FLO_CasePicklistMatrixActionV2.Request req = new FLO_CasePicklistMatrixActionV2.Request();
        req.isVerified = true;
        req.requestKey = '';

        Test.startTest();
        List<FLO_CasePicklistMatrixActionV2.Response> responses =
            FLO_CasePicklistMatrixActionV2.execute(new List<FLO_CasePicklistMatrixActionV2.Request>{ req });
        Test.stopTest();

        System.assertEquals('ERROR', responses[0].status, 'Should return ERROR when requestKey is blank');
    }
}
```

---

## 9. Variable Mapping

### Variable Binding Overview

Conversation variables are declared in the GenAiPlannerBundle. Action outputs are bound to these variables either:
- Via the `genAiFunctionParameters` output mappings in the GenAiFunction metadata
- Via explicit instructions that direct the LLM to "store output X into variable Y"
- Via platform-level variable bindings defined in the PlannerBundle (verify mechanism in current release)

### Context Variables

Context variables are automatically populated by the Agentforce platform from the conversation session:

| Context Variable | Source | Maps To |
|---|---|---|
| `endUserEmail` | MessagingSession / authenticated user | Used as input to FLO_SendVerificationCode and FLO_VerifyContact |
| `RoutableId` | MessagingSession.RoutableId | Maps to `input_messagingSessionID` in flows that need the session ID |
| `EndUserId` | Authenticated user ID (if applicable) | Can be used as additional identity signal |

### Complete Variable Mapping Table — Support Case Example

| Action (GenAiFunction) | Output Variable | Data Type | Maps To Conversation Variable | Gate Dependency |
|---|---|---|---|---|
| FLO_SendVerificationCode_v2 | `authenticationKey` | String | `authKey` | None (Step 1) |
| FLO_SendVerificationCode_v2 | `status` | String | `tempStatus` (evaluated, not stored long-term) | None |
| FLO_SendVerificationCode_v2 | `outMessage` | String | `tempMessage` (evaluated, not stored long-term) | None |
| FLO_VerifyContact_v2 | `isVerified` | Boolean | `var_IsVerified` | Requires `authKey` populated |
| FLO_VerifyContact_v2 | `verifiedContactId` | Id | `var_ContactId` | Requires `authKey` populated |
| FLO_VerifyContact_v2 | `status` | String | `tempStatus` | Requires `authKey` populated |
| FLO_CreateContactRecord_v2 | `contactId` | Id | `var_FinalContactId` | Only if `var_ContactId` is empty |
| FLO_CreateContactRecord_v2 | `status` | String | `tempStatus` | Requires `var_IsVerified` = true |
| FLO_GetCasePicklists_v2 | `matrixJson` | String | `var_PicklistMatrix` | Requires `var_IsVerified` = true |
| FLO_GetCasePicklists_v2 | `status` | String | `tempStatus` | Requires `var_IsVerified` = true |
| FLO_CreateCase_v2 | `caseId` | Id | `var_CaseId` | Requires `draftConfirmed` = true |
| FLO_CreateCase_v2 | `caseNumber` | String | `var_CaseNumber` | Requires `draftConfirmed` = true |
| FLO_CreateCase_v2 | `status` | String | `tempStatus` | Requires `draftConfirmed` = true |

### Variable Naming Convention

| Prefix | Meaning | Example |
|---|---|---|
| `input_` | Input to a Flow/Apex action | `input_endUserEmail` |
| `output_` | Output from a Flow/Apex action (before mapping to conversation var) | `output_contactId` |
| `var_` | Conversation variable persisted across steps | `var_IsVerified`, `var_ContactId` |
| `context_` | Platform-provided context variable | `context_RoutableId` |
| `temp` | Temporary evaluation variable, not needed downstream | `tempStatus`, `tempMessage` |

---

## 10. Strict Step Order in Instructions

### Why Instructions Must Be Explicit

The LLM orchestrating the agent is non-deterministic by nature. Without explicit, redundant constraints in the instructions, it will:
- Attempt to skip steps it considers unnecessary
- Reorder steps based on context
- Answer with fabricated values when actions fail
- Proceed past errors silently

### Instruction Structure Requirements for PlannerBundle

The instructions stored in the PlannerBundle (verify where instructions are stored in current release) must include:

**Opening declaration**:
```
You MUST follow the steps below in strictly sequential order.
Do not invoke any step before all preceding steps have completed successfully.
Do not skip any step. There are no exceptions to this sequence.
```

**Per-step gate statement**:
```
Step [N]: [Action Name]
  GATE: Only invoke this step if [variable] = [required value].
  If the gate condition is not met: [exact failure action — stop, retry, or escalate].
```

**No-fabrication statement** (repeat for emphasis):
```
Do not fabricate, guess, or infer any values. Only use values returned from action outputs.
If an output variable is empty after an action call, treat it as a failure.
```

**Single turn / single action rule**:
```
Do not invoke more than one action per conversational turn.
Present results to the customer between steps where user input or confirmation is needed.
```

**Completion constraint**:
```
The final response after successful case creation MUST use only {var_CaseNumber}
from the action output. Do not generate or guess a case number under any circumstances.
```

---

## 11. Knowledge Fallback

### GeneralFAQ Topic Configuration

The GeneralFAQ topic uses the standard `streamKnowledgeSearch` action (verify availability and API name in target org/release):

```xml
<!-- KnowledgeSearch.genAiFunction-meta.xml -->
<?xml version="1.0" encoding="UTF-8"?>
<GenAiFunction xmlns="http://soap.sforce.com/2006/04/metadata">
    <description>
        Search the Salesforce Knowledge base to answer customer questions about
        products, services, policies, and procedures. Use when the customer has
        an informational question that can be answered from published knowledge articles.
        Do not use this action for case creation or account-specific data retrieval.
        Input: searchQuery (String, required) — the customer's question.
        Output: knowledge article content relevant to the question.
    </description>
    <developerName>KnowledgeSearch</developerName>
    <genAiFunctionParameters>
        <genAiFunctionParameter>
            <description>The customer's question or search terms.</description>
            <developerName>searchQuery</developerName>
            <dataType>String</dataType>
            <required>true</required>
        </genAiFunctionParameter>
    </genAiFunctionParameters>
    <invocationTarget>
        <type>standardInvocable</type>
        <targetApiName>streamKnowledgeSearch</targetApiName>
        <!-- Verify this standard action name in target org/release -->
    </invocationTarget>
    <label>Knowledge Search</label>
</GenAiFunction>
```

### Knowledge Fallback Instructions

The GeneralFAQ topic instructions MUST include:

```
Answer all questions using the knowledge base only.
Do not answer questions from your own training knowledge or general AI knowledge.
Do not invent answers.

If the knowledge base returns no relevant results for a question:
  Respond: "I wasn't able to find specific information on that topic in our knowledge base.
  Would you like me to connect you with a support team member who can help?"

If the customer's question is outside the scope of General FAQ (e.g., they want to create
a case or look up account details):
  Respond: "I can help you with general questions about our products and services.
  For case creation or account assistance, I can route you to the appropriate option.
  Would you like to do that?"
```

---

## 12. Authentication / Verification Gating

### Layered Enforcement Strategy

Identity verification must be enforced at **two independent layers**:

**Layer 1: Instructions (LLM behavioral gate)**
- The LLM instructions in the PlannerBundle state: "Do not invoke any action beyond Step 2 unless var_IsVerified = true"
- This is a soft constraint — the LLM is directed not to skip it

**Layer 2: Apex/Flow enforcement (hard gate)**
- Each Apex invocable that processes sensitive data checks `isVerified == true` as its first line of logic
- If `isVerified != true`, the Apex returns `status = 'ERROR'` and `outMessage = 'Identity verification required'` without executing any business logic
- Flows that require verification check an `isVerified` input variable in a Decision element before any DML

This dual-layer approach ensures that even if the LLM instruction layer is bypassed, the action layer will reject the call.

### Verification Flow: Step-by-Step Binding

```
Platform Context (automatic):
  endUserEmail → from MessagingSession.EndUserEmail or authenticated user

Step 1 → FLO_SendVerificationCode_v2:
  Input:  endUserEmail (context variable)
  Output: authenticationKey → bound to var: authKey
          status → evaluate (SUCCESS = proceed, ERROR = stop)

User provides verificationCode → stored in temporary conversation variable

Step 2 → FLO_VerifyContact_v2:
  Input:  authenticationKey (from authKey)
          endUserEmail (from context)
          verificationCode (from user)
  Output: isVerified → bound to var: var_IsVerified
          verifiedContactId → bound to var: var_ContactId
          status → evaluate

GATE CHECKPOINT: var_IsVerified MUST = true before ANY step below this line.

All subsequent Flow/Apex actions check isVerified as their first input gate.
```

### Verification Gate in Flow (Decision Element)

```
Flow: VerifyEmailAndFindContact_v2

[Start]
→ [Decision: Is isVerified input = true?]
    YES → [Query Contact by email] → [Set outputs: isVerified=true, status='SUCCESS'] → [End]
    NO  → [Assignment: status='ERROR', outMessage='Verification required', isVerified=false] → [End]
```

---

## 13. Detailed Example: Support Case Creation Agent

This section provides a complete, step-by-step breakdown of every metadata component for the 7-step support case creation flow.

---

### Step 1: Send Verification Code

**GenAiFunction**: `FLO_SendVerificationCode_v2`
**Invocation**: Flow `SendVerificationCodeToEmail_v2`

**Variable Contract**:

| Direction | Variable Name | Type | Description |
|---|---|---|---|
| Input | `endUserEmail` | String | Required. Customer email from context. |
| Output | `authenticationKey` | String | Key for subsequent verification. |
| Output | `status` | String | 'SUCCESS' or 'ERROR' |
| Output | `outMessage` | String | Human-readable result or error. |

**Conversation Variable Binding**: `authenticationKey` → `authKey`

**Gate**: None — this is Step 1.

**Failure path**: `status = 'ERROR'` → surface `outMessage` → offer retry or live agent.

---

### Step 2: Verify Email and Find Contact

**GenAiFunction**: `FLO_VerifyContact_v2`
**Invocation**: Flow `VerifyEmailAndFindContact_v2`

**Variable Contract**:

| Direction | Variable Name | Type | Description |
|---|---|---|---|
| Input | `authenticationKey` | String | Required. From `authKey` var. |
| Input | `endUserEmail` | String | Required. From context. |
| Input | `verificationCode` | String | Required. Entered by customer. |
| Output | `isVerified` | Boolean | True if code matched and contact found. |
| Output | `verifiedContactId` | Id | Id of matched Contact record (may be empty). |
| Output | `status` | String | 'SUCCESS' or 'ERROR' |
| Output | `outMessage` | String | Result description. |

**Conversation Variable Bindings**:
- `isVerified` → `var_IsVerified`
- `verifiedContactId` → `var_ContactId`

**Gate**: `authKey` must be populated (from Step 1).

**Failure path**: `isVerified = false` → allow 1 retry. Second failure → escalate to live agent.

---

### Step 3: Create Contact if Needed

**GenAiFunction**: `FLO_CreateContactRecord_v2`
**Invocation**: Flow `CheckContactRecord_v2`

**Variable Contract**:

| Direction | Variable Name | Type | Description |
|---|---|---|---|
| Input | `customerName` | String | Required if creating new. |
| Input | `endUserEmail` | String | Required. From context. |
| Input | `existingContactId` | Id | Optional. From `var_ContactId` (may be empty). |
| Input | `isVerified` | Boolean | Required. Must be true. |
| Input | `phoneNumber` | String | Required if creating new. |
| Output | `contactId` | Id | The final contactId to use. |
| Output | `status` | String | 'SUCCESS' or 'ERROR' |
| Output | `outMessage` | String | Result description. |

**Conversation Variable Binding**: `contactId` → `var_FinalContactId`

**Gate**: `var_IsVerified` = true. Only invoke if `var_ContactId` is empty (no existing contact found).

**If `var_ContactId` is populated**: skip this step; set `var_FinalContactId = var_ContactId` directly.

**Failure path**: `status = 'ERROR'` → escalate to live agent.

---

### Step 4: Retrieve Case Picklist Dependency Matrix

**GenAiFunction**: `FLO_GetCasePicklists_v2`
**Invocation**: Apex `FLO_CasePicklistMatrixActionV2` (invocable method)

**Variable Contract**:

| Direction | Variable Name | Type | Description |
|---|---|---|---|
| Input | `isVerified` | Boolean | Required. Must be true. Apex enforces this. |
| Input | `requestKey` | String | Required. Value: 'classification' |
| Output | `matrixJson` | String | JSON of categories and subcategories. |
| Output | `status` | String | 'SUCCESS' or 'ERROR' |
| Output | `outMessage` | String | Result description. |

**Conversation Variable Binding**: `matrixJson` → `var_PicklistMatrix`

**Gate**: `var_IsVerified` = true. `var_FinalContactId` must be populated.

**Failure path**: `status = 'ERROR'` → escalate to live agent.

**Post-success**: Parse `var_PicklistMatrix` JSON. Present category options. Collect `caseCategory`. Present subcategory options for selected category. Collect `caseSubCategory`.

---

### Step 5: Draft Case Details and Confirm

**No action call in this step** — agent collects information from the user.

**Data collected**:
- `caseSubject` — ask: "Please provide a brief subject for your case."
- `caseDescription` — ask: "Please describe the issue in detail."

**Confirmation presentation**:
```
"Here are the details for your case:
  Category: {caseCategory}
  Subcategory: {caseSubCategory}
  Subject: {caseSubject}
  Description: {caseDescription}

Is this correct? Reply YES to proceed or NO to make changes."
```

**Gate**: `draftConfirmed` must be explicitly set to `true` based on customer responding YES.

**If NO**: ask which field to change → update → re-present summary → ask again.

**Failure path**: If customer abandons without confirming → do not create the case.

---

### Step 6: Create Case

**GenAiFunction**: `FLO_CreateCase_v2`
**Invocation**: Flow `CreateSupportCase_v2`

**Variable Contract**:

| Direction | Variable Name | Type | Description |
|---|---|---|---|
| Input | `contactId` | Id | Required. From `var_FinalContactId`. |
| Input | `caseCategory` | String | Required. Collected in Step 4. |
| Input | `caseSubCategory` | String | Required. Collected in Step 4. |
| Input | `caseSubject` | String | Required. Collected in Step 5. |
| Input | `caseDescription` | String | Required. Collected in Step 5. |
| Input | `draftConfirmed` | Boolean | Required. Must be true. |
| Input | `isVerified` | Boolean | Required. Must be true. |
| Input | `assetName` | String | Optional. |
| Input | `invoiceReference` | String | Optional. |
| Output | `caseId` | Id | Salesforce record ID of created case. |
| Output | `caseNumber` | String | Display case number (e.g., 00001234). |
| Output | `status` | String | 'SUCCESS' or 'ERROR' |
| Output | `outMessage` | String | Result description. |

**Conversation Variable Bindings**:
- `caseId` → `var_CaseId`
- `caseNumber` → `var_CaseNumber`

**Gate**: `draftConfirmed` = true. `var_IsVerified` = true. `var_FinalContactId` populated.

**Failure path**: `status = 'ERROR'` → surface `outMessage` → escalate to live agent with collected case detail summary.

---

### Step 7: Return Case Number Only After Success

**No action call** — agent composes final response from variables.

**Response rule**:
```
ONLY use {var_CaseNumber} from the action output.
Do not generate, guess, or pad the case number.
If var_CaseNumber is empty: treat as failure → escalate.
```

**Success response**:
```
"Your case {var_CaseNumber} has been created successfully.
Our support team will review your case and contact you at {endUserEmail}.
Is there anything else I can help you with today?"
```

**Error response** (if `var_CaseNumber` empty despite status = SUCCESS — unexpected state):
```
"Your case appears to have been submitted, but I was unable to retrieve a case number.
Please contact our support team directly to confirm your case status.
I apologize for the inconvenience."
```

---

## 14. Action Result Handling

### Universal Result Handling Pattern

Every action in every topic MUST follow this pattern:

```
1. Invoke action
2. Evaluate status output variable
3. If status = 'SUCCESS': continue to next step
4. If status = 'ERROR': surface outMessage to customer; do not continue to next step
5. If action failure offers retry: allow exactly one retry
6. After retry failure: escalate to live agent
```

### Never Swallow Failures

Instructions MUST NOT contain language like:
- "If the action fails, try the next step anyway" — PROHIBITED
- "Proceed regardless of status" — PROHIBITED
- "The case number will be available shortly" (when it wasn't returned) — PROHIBITED

### Status Evaluation in Instructions

```
After invoking [ActionName]:
  If status = 'SUCCESS': [specific action to take]
  If status = 'ERROR': Respond to the customer: "[outMessage]"
    [escalation path or retry instruction]
  If status is not set or empty: treat as ERROR.
    Respond: "I encountered an unexpected issue. Let me connect you with our team."
    Transfer to live agent.
```

---

## 15. No Hallucinated Action Outputs

### The Risk

The LLM may generate plausible-sounding values (case numbers, IDs, status confirmations) when an action output is empty or an action fails. This is called hallucination and is particularly dangerous in business process automation.

### Mandatory Hallucination Prevention in Instructions

The following language MUST appear in instructions for any topic that creates or retrieves records:

```
CRITICAL: You are prohibited from generating, guessing, fabricating, or inferring
any of the following values:
  - Case numbers or reference numbers
  - Contact IDs, account IDs, or record IDs of any kind
  - SLA timeframes or estimated resolution times
  - Status values not returned by an action
  - Email addresses not provided by the authenticated session

You MUST use only the exact values returned in action output variables.

If an output variable is empty after an action completes:
  - Do not assume the action succeeded
  - Do not report success to the customer
  - Treat empty critical outputs as failures
  - Follow the failure path for that step
```

### Test to Verify

In test conversations, deliberately cause an action to fail and verify:
1. The agent does NOT fabricate a case number
2. The agent surfaces the error message
3. The agent offers escalation
4. The conversation ends cleanly without false confirmations

---

## 16. Test Conversations

### Required Test Scenarios

All 6 scenarios below MUST be executed before production deployment:

**Scenario 1: Happy Path — All Steps Succeed**
- All actions return `status = 'SUCCESS'`
- Customer confirms details with YES
- Expected: case number returned from action; confirmation message displayed; no fabricated values

**Scenario 2: Wrong Verification Code (Retry, Then Success)**
- First attempt: FLO_VerifyContact returns `isVerified = false`
- Agent allows retry
- Second attempt: `isVerified = true`
- Expected: flow continues from Step 3; no escalation

**Scenario 3: Wrong Verification Code (Retry, Then Failure)**
- Both attempts: FLO_VerifyContact returns `isVerified = false`
- Expected: agent escalates to live agent after second failure; does not proceed to Step 3; no case created

**Scenario 4: Contact Not Found — Create New Contact Path**
- FLO_VerifyContact returns `isVerified = true` but `verifiedContactId = null/empty`
- Expected: agent collects name and phone; calls FLO_CreateContactRecord; uses new contactId for rest of flow

**Scenario 5: Action Failure at Case Creation**
- Steps 1-5 succeed; FLO_CreateCase returns `status = 'ERROR'`
- Expected: agent displays error message; offers escalation; does NOT return a fabricated case number; does NOT return a blank case number with "your case has been created"

**Scenario 6: Out-of-Scope Question**
- Customer asks "What is your refund policy?" while in CaseCreation topic
- Expected: agent deflects to GeneralFAQ topic or states it cannot answer this in the current context; does not attempt to answer from general knowledge

### Additional Recommended Scenarios

**Scenario 7: User Declines Confirmation at Step 5**
- Customer responds NO to summary confirmation
- Expected: agent asks what to change; accepts updated value; re-presents summary; waits for YES before proceeding

**Scenario 8: User Abandons Mid-Flow**
- Customer goes silent or ends session after Step 3
- Expected: no case record created; no orphaned records; session ends cleanly

### Verification Checklist Per Test

For each scenario:
- [ ] Correct GenAiFunction invoked at each step
- [ ] Inputs passed to action match declared variable names
- [ ] Outputs from action correctly stored in conversation variables
- [ ] Gate conditions enforced correctly (steps blocked or allowed as expected)
- [ ] Error paths triggered correctly when actions fail
- [ ] No fabricated values in any response
- [ ] Final response uses only action output variables

---

## 17. Deployment / Retrieval Caveats

> **Verify all commands and metadata type names in your target org and current SF CLI version before use. This information may be out of date.**

### Retrieval Commands

```bash
# Retrieve the Bot and its versions
sf project retrieve start \
  --metadata "Bot:SupportPortalAgent" \
  --target-org <sandboxAlias>

# Retrieve the PlannerBundle
sf project retrieve start \
  --metadata "GenAiPlannerBundle:SupportPortalAgent" \
  --target-org <sandboxAlias>

# Retrieve all Plugins (topics)
sf project retrieve start \
  --metadata "GenAiPlugin:CaseCreation,GenAiPlugin:GeneralFAQ" \
  --target-org <sandboxAlias>

# Retrieve specific Functions
sf project retrieve start \
  --metadata "GenAiFunction:FLO_SendVerificationCode_v2,GenAiFunction:FLO_VerifyContact_v2" \
  --target-org <sandboxAlias>

# Retrieve all agent metadata together (verify if wildcard is supported)
sf project retrieve start \
  --metadata "Bot,GenAiPlannerBundle,GenAiPlugin,GenAiFunction" \
  --target-org <sandboxAlias>
```

### Deployment Commands

```bash
# Deploy in dependency order (see Section 2)

# Step 1: Deploy Apex
sf project deploy start \
  --metadata "ApexClass:FLO_CasePicklistMatrixActionV2" \
  --target-org <targetAlias>

# Step 2: Deploy Flows
sf project deploy start \
  --metadata "Flow:SendVerificationCodeToEmail_v2,Flow:VerifyEmailAndFindContact_v2" \
  --target-org <targetAlias>

# Step 3: Deploy Functions
sf project deploy start \
  --metadata "GenAiFunction:FLO_SendVerificationCode_v2" \
  --target-org <targetAlias>

# Step 4: Deploy Plugins
sf project deploy start \
  --metadata "GenAiPlugin:CaseCreation" \
  --target-org <targetAlias>

# Step 5: Deploy PlannerBundle
sf project deploy start \
  --metadata "GenAiPlannerBundle:SupportPortalAgent" \
  --target-org <targetAlias>

# Step 6: Deploy Bot
sf project deploy start \
  --metadata "Bot:SupportPortalAgent" \
  --target-org <targetAlias>
```

### Known Retrieval Limitations

> Verify these points in your target org/release:

- Not all GenAi metadata types may be fully source-trackable in all org types (Developer Edition, Trial, Scratch Orgs)
- Agentforce Builder UI may generate metadata files that are not fully retrievable via `sf project retrieve` — always check after UI changes
- Some metadata elements may be stored in the org's database layer and not exported in standard source format — confirm with Salesforce support if retrieval produces incomplete files
- Bot context variable mappings may not be retrieved correctly in all releases — verify the retrieved file matches your UI configuration

### Sandbox-First Policy

- Never deploy a new agent version directly to production
- Deploy to Full Sandbox (preferred) or Partial Sandbox
- Run full test suite (all 6+ scenarios) in sandbox
- Only after test suite passes: deploy to production

---

## 18. Salesforce CLI Caveats

> These caveats apply as of April 2026. CLI behavior changes with each plugin release. Always verify.

### Agent-Specific CLI Plugin

The `@salesforce/plugin-agent` plugin may be required for agent-specific commands (e.g., agent testing, conversation preview). Install it separately:

```bash
# Install the agent plugin (verify command in current SF CLI documentation)
sf plugins install @salesforce/plugin-agent

# Verify installation
sf plugins list
```

### Test Coverage for Agentforce

- Standard Apex test commands (`sf apex run test`) cover Apex invocable classes used by Agentforce
- Agentforce conversation flow testing (testing the LLM orchestration layer) uses different tooling — verify availability of `sf agent test` or equivalent in current CLI version
- Do not assume Apex test coverage percentages cover the LLM orchestration layer — they are separate

### Manifest vs. Metadata Flag

- When deploying agent metadata, prefer specifying metadata types explicitly (`--metadata` flag) over package.xml manifest files
- If using package.xml, verify that all GenAi metadata types are correctly listed — they may not be auto-detected

### API Version

- Ensure your `sfdx-project.json` specifies an API version that supports all GenAi metadata types being used
- Check minimum API version for each metadata type in the Metadata API documentation

---

## 19. Source Completeness Checklist

All files listed below MUST be committed to source control as an atomic set. Never commit partial agent changes.

**Bot Metadata**
- [ ] `force-app/main/default/bots/SupportPortalAgent/SupportPortalAgent.bot-meta.xml`
- [ ] `force-app/main/default/bots/SupportPortalAgent/v2.botVersion-meta.xml`

**PlannerBundle**
- [ ] `force-app/main/default/genAiPlannerBundles/SupportPortalAgent.genAiPlannerBundle-meta.xml`

**GenAiPlugins (one per topic)**
- [ ] `force-app/main/default/genAiPlugins/CaseCreation.genAiPlugin-meta.xml`
- [ ] `force-app/main/default/genAiPlugins/GeneralFAQ.genAiPlugin-meta.xml`

**GenAiFunctions (one per action)**
- [ ] `force-app/main/default/genAiFunctions/FLO_SendVerificationCode_v2/FLO_SendVerificationCode_v2.genAiFunction-meta.xml`
- [ ] `force-app/main/default/genAiFunctions/FLO_VerifyContact_v2/FLO_VerifyContact_v2.genAiFunction-meta.xml`
- [ ] `force-app/main/default/genAiFunctions/FLO_CreateContactRecord_v2/FLO_CreateContactRecord_v2.genAiFunction-meta.xml`
- [ ] `force-app/main/default/genAiFunctions/FLO_GetCasePicklists_v2/FLO_GetCasePicklists_v2.genAiFunction-meta.xml`
- [ ] `force-app/main/default/genAiFunctions/FLO_CreateCase_v2/FLO_CreateCase_v2.genAiFunction-meta.xml`
- [ ] `force-app/main/default/genAiFunctions/KnowledgeSearch/KnowledgeSearch.genAiFunction-meta.xml`

**Flows (all flows referenced by GenAiFunctions)**
- [ ] `force-app/main/default/flows/SendVerificationCodeToEmail_v2.flow-meta.xml`
- [ ] `force-app/main/default/flows/VerifyEmailAndFindContact_v2.flow-meta.xml`
- [ ] `force-app/main/default/flows/CheckContactRecord_v2.flow-meta.xml`
- [ ] `force-app/main/default/flows/CreateSupportCase_v2.flow-meta.xml`

**Apex Classes (all invocables referenced by GenAiFunctions)**
- [ ] `force-app/main/default/classes/FLO_CasePicklistMatrixActionV2.cls`
- [ ] `force-app/main/default/classes/FLO_CasePicklistMatrixActionV2.cls-meta.xml`
- [ ] `force-app/main/default/classes/FLO_CasePicklistMatrixActionV2_Test.cls`
- [ ] `force-app/main/default/classes/FLO_CasePicklistMatrixActionV2_Test.cls-meta.xml`

---

## 20. Common AI Mistakes to Avoid

These are mistakes made by AI assistants (including code generators and LLM-based development tools) when working with Agentforce configuration. Review this list before accepting any AI-generated Agentforce configuration.

| Mistake | Risk | How to Catch It |
|---|---|---|
| GenAiFunction descriptions don't match actual Flow variable names | LLM passes wrong variable names → action fails silently or receives null inputs | Cross-reference every variable name in the Function description against the actual Flow variable API names |
| Wrong variable names in mappings (case mismatch) | Null values passed to actions; downstream steps receive empty inputs | Variable names are case-sensitive — verify exact case against Flow/Apex source |
| Missing verification gate in instructions | Agent may attempt case creation without verifying identity | Check that isVerified = true gate appears before Step 3 onwards |
| No fault/error handling in instructions | Unhandled failures; agent silently proceeds with empty variables | Check that every step has an explicit "If status = ERROR" path |
| Deploying GenAiFunctions before Flows/Apex exist | Deployment failure: target not found | Always deploy Flows/Apex first — strict dependency order |
| Not retrieving existing metadata before modifying | Overwrites org config with stale local copy | Run retrieve command before opening any agent metadata file for editing |
| Fabricating metadata type names not in official docs | Invalid deployment package; wasted debugging time | Verify every metadata type name against official Salesforce Metadata API docs |
| Assuming CLI commands work without installing agent plugin | CLI command not found errors | Verify `@salesforce/plugin-agent` is installed; check `sf plugins list` |
| Topic descriptions too vague | LLM misroutes user intents; wrong actions invoked | Include explicit positive examples and negative examples in every topic description |
| Using Screen Flows as Agentforce actions | Flows with screens cannot be invoked by Agentforce | Always check Flow type = Autolaunched before referencing in GenAiFunction |
| Not testing empty output variables | Fabricated values accepted silently | Force action failures in test scenarios; verify agent behavior when output is empty |
| Committing agent metadata without referenced Flows/Apex | Incomplete source; broken deployment from clean checkout | Use Source Completeness Checklist in Section 19 |

---

## 21. Definition of Done (Agentforce Builder)

An Agentforce Builder configuration is NOT complete until every item below is checked.

**Metadata Completeness**
- [ ] All metadata files present in source: Bot, BotVersion, PlannerBundle, Plugins (one per topic), Functions (one per action)
- [ ] All referenced Flow API names exist as active Flows in the org
- [ ] All referenced Apex class names exist as deployed, active classes in the org
- [ ] All metadata committed to source control as a complete set (Section 19)

**Variable Accuracy**
- [ ] Every variable name in every GenAiFunction description matches exactly the Flow/Apex variable API name (case-sensitive verified)
- [ ] Every conversation variable declared in PlannerBundle is used by at least one action or referenced in instructions
- [ ] Variable mapping table (Section 9) is complete and accurate

**Security and Gating**
- [ ] Verification gate enforced in PlannerBundle/Plugin instructions AND in Apex/Flow action logic (dual enforcement)
- [ ] No action that processes account data can be invoked without isVerified = true (both instruction-level and code-level)
- [ ] `logPrivateConversationData` = false unless approved by security/compliance team

**Instructions Quality**
- [ ] Instructions explicitly state step order and gates
- [ ] Instructions contain no-fabrication prohibition
- [ ] Instructions contain escalation triggers for verification failure and action failure
- [ ] Instructions contain out-of-scope deflection

**Flows and Apex**
- [ ] All Flows are Autolaunched type
- [ ] All Flows have fault paths returning status = 'ERROR' and outMessage
- [ ] All Apex invocables check isVerified as first gate (where applicable)
- [ ] All Apex invocables have try/catch returning structured status and outMessage
- [ ] All Apex invocables have test classes with 75%+ coverage AND functional assertions

**Testing**
- [ ] All 6+ test conversation scenarios executed in sandbox (Section 16)
- [ ] All scenarios passed — including failure scenarios and edge cases
- [ ] Debug logs reviewed to confirm correct variable binding at each step
- [ ] No fabricated values found in any test scenario response

**Deployment**
- [ ] Deployment followed correct dependency order (Apex → Flows → Functions → Plugins → PlannerBundle → Bot)
- [ ] Agent activated in sandbox before production
- [ ] Prior version retained as inactive for rollback
- [ ] Agent activated in production
- [ ] Production smoke test (happy path) completed after activation

---

## 22. Official References

> All URLs verified accurate as of April 2026. Salesforce Help URLs change with each release — verify in your browser.

- Agentforce Builder Guide: https://help.salesforce.com/s/articleView?id=sf.ai_agent_build.htm (verify current URL)
- Agentforce Developer Guide (Einstein Generative AI): https://developer.salesforce.com/docs/einstein/genai/guide/ (verify current URL)
- Salesforce Metadata API Developer Guide — Bot: https://developer.salesforce.com/docs/atlas.en-us.api_meta.meta/api_meta/meta_bot.htm (verify)
- Salesforce Metadata API Developer Guide — GenAi Types: https://developer.salesforce.com/docs/atlas.en-us.api_meta.meta/api_meta/ (search for GenAi in current release)
- Salesforce CLI Reference and Plugin Registry: https://developer.salesforce.com/tools/salesforcecli
- Agentforce Trailhead: https://trailhead.salesforce.com/content/learn/trails/build-einstein-for-sales-and-service (verify current URL)
- Invocable Actions Developer Guide: https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_classes_annotation_InvocableMethod.htm (verify)

---

*End of Agentforce Builder Configuration Guidelines v2.0*
