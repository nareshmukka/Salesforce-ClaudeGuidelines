# Agentforce Agent Authoring Bundle — Complete Development Guide
> Authoring Bundle (.agent script) approach | v1.0 — May 2026
> Generic reference — no org-specific names. Works in any org including brand-new orgs.

---

## 1. Authoring Bundle vs Older Approaches

| Feature | **Authoring Bundle (.agent)** | GenAiPlannerBundle (older) |
|---|---|---|
| File format | Single `.agent` DSL file | Multiple XML metadata files |
| Actions | Inline in `.agent` + separate GenAiFunction | GenAiFunction XML per action |
| Deployment | `sf agent publish authoring-bundle` | `package.xml` + `sf project deploy start` |
| Tooling | VS Code Agent Script extension, SF CLI | Metadata API, Workbench |
| Agent type support | ServiceAgent and EmployeeAgent | ServiceAgent only (typically) |
| Readability | Single readable file | Scattered across many XML files |

**Use the authoring bundle approach for all new agents.** The GenAiPlannerBundle approach is legacy; do not use it for new work.

---

## 2. When to Use Each Agent Type

| Type | API name | When to use |
|---|---|---|
| Employee / Internal | `AgentforceEmployeeAgent` | Invoked server-side from Apex inside org via `generateAiAgentResponse`. Internal tools, case management, back-office workflows. |
| Service / External | `AgentforceServiceAgent` | Customer-facing channels (chat, messaging). Requires `default_agent_user`. |

**Critical:** `generateAiAgentResponse` invocation from server-side Apex only works when `agent_type = AgentforceEmployeeAgent`.

---

## 3. Project Setup

### Prerequisites

```bash
# Verify CLI and plugin versions
sf --version
sf plugins --core

# Retrieve existing agent bundle (if editing an existing agent)
sf agent retrieve authoring-bundle --api-name Your_Agent_Api_Name --target-org your-alias

# Or scaffold a new agent (creates folder + .agent file)
sf agent create --name "Your Agent Name" --target-org your-alias
```

### Folder structure

```
force-app/main/default/
  aiAuthoringBundles/
    Your_Agent_Name/
      Your_Agent_Name.agent          ← Edit this
  classes/
    YourApexAction.cls               ← @InvocableMethod Apex
    YourApexActionTest.cls
  flows/
    Your_Flow_Action.flow-meta.xml   ← Autolaunched flows only
  promptTemplates/
    Your_Prompt_Template.promptTemplate-meta.xml
```

---

## 4. .agent File Structure

Complete skeleton with all blocks:

```yaml
system:
    instructions: "One or two sentences. Role, purpose, scope."
    messages:
        error: "Something went wrong. Try again."
        welcome: "Hi! I am [Agent Name]. [What it does and how to start]."

config:
    agent_name: "Your_Agent_Api_Name"
    agent_label: "Your Agent Display Name"
    agent_type: "AgentforceEmployeeAgent"   # or AgentforceServiceAgent
    enable_enhanced_event_logs: True

language:
    default_locale: "en_US"
    additional_locales: ""

start_agent Topic_Name:
    description: "Use this topic when [routing condition]. One sentence."
    reasoning:
        instructions: ->
            |STEP 0 — [FIRST STEP NAME]
             [Instructions here]
            |STEP 1 — [NEXT STEP NAME]
             [Instructions here]
            |GUARDRAILS
             [Failure handling here]
        actions:
            ActionName: @actions.ActionName
                with inputField = ...
    actions:
        ActionName:
            description: |
                [What this action does. When to call it. How to supply inputs.]
            label: "Action Display Label"
            require_user_confirmation: False
            include_in_progress_indicator: False
            source: "ActionName"              # Only needed for Apex-backed actions
            target: "apex://YourApexClassName"  # or flow://YourFlowApiName

            inputs:
                "fieldName": string
                    description: |
                      [How the LLM should populate this field]
                    label: "fieldName"
                    is_required: True
                    is_user_input: False     # False = extracted from context, not prompted

            outputs:
                "outputField": string
                    label: "outputField"
                    is_displayable: False
                    filter_from_agent: False
```

---

## 5. STEP-Based Reasoning Instructions

Write reasoning instructions as numbered STEPs. Each `|` block is sent to the LLM as a prompt section. All STEPs resolve top-to-bottom into a single resolved prompt before LLM execution.

```yaml
reasoning:
    instructions: ->
        |STEP 0 — MODE DETECTION
         Read the user message. Determine mode from message content.
         If message contains "keyword A", set mode = MODE_A.
         Otherwise, set mode = MODE_B.
        |STEP 1a — MODE_A PROCESSING
         [Instructions for MODE_A]
        |STEP 1b — MODE_B PROCESSING
         [Instructions for MODE_B]
        |GUARDRAILS
         If primary action fails, return error JSON and stop. Do not proceed.
         Secondary action failures are non-fatal: continue with null values.
         Do not fabricate data.
         Do not expose raw tool outputs.
```

**Rules:**
- One STEP block per logical phase
- GUARDRAILS block always last in reasoning instructions
- Use `|` (LLM) for complex reasoning; use `->` (deterministic) for variable assignment and branching
- Do NOT add `available when:` conditions to actions in the `.agent` DSL — causes parse error. Control action availability through the STEP instructions instead.

---

## 6. Record ID Injection — The Only Working Pattern

**RULE: Never use `sessionVariables` JSON parameter with `generateAiAgentResponse`.**

`sessionVariables` is accepted by the API without error but the agent cannot see the values at runtime. The agent script variables block remains at empty defaults.

**Correct approach:** Embed all record IDs in the user message text. The agent extracts them via LLM reasoning.

### Caller side (Apex)

```apex
String userMessage = 'caseId=' + caseId + ' and relatedRecordId=' + relatedRecordId
    + ' ' + humanReadableRequest;

ConnectApi.AgentMessageRepresentation msg = new ConnectApi.AgentMessageRepresentation();
msg.message = userMessage;
msg.type = ConnectApi.AgentMessageType.User;
```

### Agent side (reasoning instructions)

```yaml
|STEP 0 — ID EXTRACTION
 Read the user message. Extract caseId and relatedRecordId from the message
 (format: caseId=<value> and relatedRecordId=<value>).
 Call PrimaryAction with the extracted IDs before any further analysis.
```

### Action input description

```yaml
inputs:
    "caseId": string
        description: |
          Salesforce Case record Id. Extract from user message where the format
          is caseId=<value>. Do not ask the user.
        label: "caseId"
        is_required: True
        is_user_input: False
```

---

## 7. Action Targets

### 7.1 Apex-backed action

Requires:
1. An Apex class with `@InvocableMethod`
2. A `GenAiFunction` metadata record referencing the class (OR use `source:` + `apex://` direct target)

**Direct Apex target (preferred for authoring bundle):**

```yaml
ActionName:
    source: "ActionName"
    target: "apex://YourApexClassName"
```

**The Apex class must be deployed before the agent can call it.**

### 7.2 Direct Flow target

No GenAiFunction wrapper needed. Use `flow://` directly:

```yaml
ActionName:
    target: "flow://Your_Flow_Api_Name"
```

Flow must be `status: Active` and type `AutoLaunchedFlow`.

### 7.3 Summary of target formats

| Target | Format |
|---|---|
| Apex invocable | `"apex://ClassName"` |
| Flow | `"flow://Flow_Api_Name"` |
| Prompt template | `"prompt://Template_Developer_Name"` |

---

## 8. Apex @InvocableMethod — Required Pattern

```apex
public class YourApexAction {

    public class ActionRequest {
        @InvocableVariable(required=true) public String caseId;
        @InvocableVariable(required=true) public String relatedRecordId;
    }

    public class ActionResult {
        @InvocableVariable public String caseNumber;
        @InvocableVariable public String status;
        @InvocableVariable public String emailBody;
        @InvocableVariable public String errorMessage;
    }

    @InvocableMethod(label='Your Action Label' description='One sentence description.')
    public static List<ActionResult> execute(List<ActionRequest> requests) {
        List<ActionResult> results = new List<ActionResult>();
        for (ActionRequest req : requests) {
            results.add(processRequest(req));
        }
        return results;
    }

    private static ActionResult processRequest(ActionRequest req) {
        ActionResult res = new ActionResult();
        try {
            // Query and process
            Case c = [SELECT CaseNumber, Status FROM Case WHERE Id = :req.caseId WITH USER_MODE LIMIT 1];
            res.caseNumber = c.CaseNumber;
            res.status = c.Status;
        } catch (Exception e) {
            res.errorMessage = e.getMessage();
        }
        return res;
    }
}
```

**Required pattern rules:**
- `List<ActionRequest>` input, `List<ActionResult>` output — even for single-record operations
- `WITH USER_MODE` on all SOQL (CRUD/FLS enforcement)
- Populate `errorMessage` on exceptions — agent guardrails check it
- Never throw from `execute()` — catch and return error in result
- Bulk-safe loop even if agent only calls once (platform requirement)

---

## 9. Flow Integration — Critical Rules

### 9.1 Flow requirements for agent actions

- Type: `AutoLaunchedFlow` only (not Screen Flow, not Record-Triggered)
- Status: `Active` before agent is published
- Input variable: `isInput: true`, `isOutput: false`
- Output variables: `isInput: false`, `isOutput: true`

### 9.2 THE MOST COMMON FLOW BUG: Output variables stay null

**Problem:** After a `generatePromptResponse` action element in a Flow, declaring a variable as `isOutput: true` does NOT auto-populate it. The result of the prompt action lives only in `<actionName>.promptResponse`.

**Wrong approach (output variables stay null):**

```xml
<!-- Flow outputs extractedField but never assigns it -->
<variables>
    <name>extractedField</name>
    <isOutput>true</isOutput>
    <!-- Never assigned → always null when agent reads it -->
</variables>
```

**Correct approach — always assign promptResponse to an output variable:**

```xml
<assignments>
    <name>Set_Output_Values</name>
    <assignmentItems>
        <assignToReference>outMessage</assignToReference>
        <operator>Assign</operator>
        <value>
            <elementReference>Your_Prompt_Action.promptResponse</elementReference>
        </value>
    </assignmentItems>
</assignments>
```

**Rule:** After every `generatePromptResponse` action, always have an Assignment element that copies `<actionName>.promptResponse` into your output variable. Never rely on `isOutput: true` alone.

### 9.3 The outMessage pattern

When a flow's prompt template produces free text, pass it back as a single `outMessage` string output. Have the agent LLM parse it using its own reasoning — do not try to pre-structure it into multiple output variables.

```yaml
# In agent reasoning instructions:
|STEP 2 — PROCESS FLOW OUTPUT
 Read the outMessage output from FlowActionName. It contains free-text analysis.
 Parse outMessage to extract [specific data you need].
 If outMessage is blank or says no data found, proceed with null values.
```

### 9.4 Fault paths

Every Record Lookup and Action Call in a flow must have a `faultConnector`:

```xml
<faultConnector>
    <targetReference>Set_Fault_Message</targetReference>
</faultConnector>
```

The fault assignment should populate `outMessage` with `{!$Flow.FaultMessage}` so the agent can read the error.

---

## 10. Structured Output — JSON Contract

When the agent produces a structured analysis result, instruct it to return valid JSON and define the schema in the reasoning instructions.

```yaml
|STEP N — RETURN RESULT
 Return ONLY valid JSON — no markdown fences, no extra text before or after:
 {"field1":"","field2":"","field3":null,"confidence":0.0}
 Use null for missing fields. No placeholder text.
```

**Parsing in Apex:**

```apex
public class AgentAnalysisResult {
    public String field1;
    public String field2;
    public String field3;
    public Double confidence;
}

// Deserialize
AgentAnalysisResult parsed = (AgentAnalysisResult) JSON.deserialize(agentResponse, AgentAnalysisResult.class);
```

---

## 11. Invoking the Agent from Apex

### 11.1 invokeAgent — for JSON/structured response

```apex
ConnectApi.AgentJobRepresentation job = ConnectApi.AgentService.createAgentSession(agentApiName);
String sessionId = job.id;

ConnectApi.AgentMessageRepresentation msg = new ConnectApi.AgentMessageRepresentation();
msg.message = 'caseId=' + caseId + ' analyze this email';
msg.type = ConnectApi.AgentMessageType.User;

ConnectApi.AgentJobRepresentation response = ConnectApi.AgentService.sendAgentMessage(sessionId, msg);
// Parse response.message for JSON content
```

### 11.2 invokeAgentForText — for free-text response (email draft, etc.)

When the agent returns a plain-text response (not JSON), the response is wrapped in an Agentforce Text envelope:

```json
{"type":"Text","value":"<actual text content here>"}
```

**Unwrap in Apex:**

```apex
public String unwrapTextEnvelope(String agentRawResponse) {
    if (String.isBlank(agentRawResponse)) return '';
    try {
        Map<String, Object> envelope = (Map<String, Object>) JSON.deserializeUntyped(agentRawResponse);
        if ('Text'.equals(envelope.get('type'))) {
            return (String) envelope.get('value');
        }
    } catch (Exception e) { /* fall through */ }
    return agentRawResponse;
}
```

**Rule:** Use structured JSON mode for analysis/extraction. Use Text envelope mode for drafted content (emails, summaries, free-text replies).

---

## 12. LWC-Compatible Summary Format

When the agent produces a summary that will be displayed in an LWC, the summary text must contain exact colon-labeled sections that the LWC can parse.

**Agent instruction pattern:**

```yaml
|STEP N — COMPOSE SUMMARY
 Compose the summary as two parts joined together with no separator.
 Do NOT write "Part 1", "Part 2", or "summary" as headings — start directly.
 Part 1: Write 1-3 overview sentences summarising the situation.
         If key data was extracted (e.g. a confirmation number), explicitly state it here.
 Part 2: Write exactly these labeled lines immediately after Part 1, one per line,
         using the EXACT label text shown (colon included):
 Issue reported: <one sentence>
 Suspected cause: <one sentence>
 Current status: <one sentence>
 Customer sentiment: <one sentence>
 Key issues: <one sentence — if extracted data found, reference it here>
 Timeline of key issues: <date and event>
```

**LWC parsing pattern (JavaScript):**

```javascript
const summaryLabels = [
    'Issue reported:', 'Suspected cause:', 'Current status:',
    'Customer sentiment:', 'Key issues:', 'Timeline of key issues:'
];

get introSummary() {
    if (!this.summary) return '';
    const firstLabel = summaryLabels.find(l => this.summary.includes(l));
    return firstLabel ? this.summary.substring(0, this.summary.indexOf(firstLabel)).trim() : this.summary;
}

get sectionDetailsPlainText() {
    if (!this.summary) return '';
    const firstLabel = summaryLabels.find(l => this.summary.includes(l));
    return firstLabel ? this.summary.substring(this.summary.indexOf(firstLabel)).trim() : '';
}
```

**Critical:** If the summary text contains no matching colon-labels, the LWC shows the entire text as intro with no expandable sections. Always verify label strings match exactly.

---

## 13. Deployment

### 13.1 Agent script — publish command (NOT package.xml)

```bash
# Publish the authoring bundle to the org
sf agent publish authoring-bundle --api-name Your_Agent_Api_Name --target-org your-alias

# Correct flag: --api-name
# Wrong flag:   --agent-api-name  ← does not exist, silently fails
```

**The agent script (.agent file) is NOT deployed via `package.xml`. Use the publish command only.**

### 13.2 Supporting metadata — deploy via package.xml

Apex classes, flows, prompt templates, and GenAiFunctions ARE deployed via package.xml:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<Package xmlns="http://soap.sforce.com/2006/04/metadata">
    <types>
        <members>YourApexAction</members>
        <members>YourApexActionTest</members>
        <name>ApexClass</name>
    </types>
    <types>
        <members>Your_Flow_Action</members>
        <name>Flow</name>
    </types>
    <types>
        <members>Your_Prompt_Template</members>
        <name>GenAiPromptTemplate</name>
    </types>
    <types>
        <members>Your_GenAi_Function</members>
        <name>GenAiFunction</name>
    </types>
    <version>66.0</version>
</Package>
```

```bash
# Validate
sf project deploy start --manifest manifest/your-package.xml --target-org your-alias \
    --check-only --test-level RunLocalTests --wait 60

# Deploy
sf project deploy start --manifest manifest/your-package.xml --target-org your-alias \
    --test-level RunLocalTests --wait 60
```

### 13.3 Deploy order

1. Deploy Apex classes and test classes
2. Deploy flows (must be Active before agent can call them)
3. Deploy prompt templates
4. Deploy GenAiFunctions (if any)
5. Publish agent authoring bundle

---

## 14. Testing

### 14.1 Anonymous Apex invoker

```apex
// Test the agent end-to-end from Apex
String agentApiName = 'Your_Agent_Api_Name';
String caseId = '500XXXXXXXXXXXX';
String relatedId = '02SXXXXXXXXXXXX';

String userMessage = 'caseId=' + caseId + ' and relatedRecordId=' + relatedId
    + ' Please analyze this record.';

// Create session
ConnectApi.AgentJobRepresentation createResult =
    ConnectApi.AgentService.createAgentSession(agentApiName);
String sessionId = createResult.id;
System.debug('Session ID: ' + sessionId);

// Send message
ConnectApi.AgentMessageRepresentation msg = new ConnectApi.AgentMessageRepresentation();
msg.message = userMessage;
msg.type = ConnectApi.AgentMessageType.User;
ConnectApi.AgentJobRepresentation sendResult =
    ConnectApi.AgentService.sendAgentMessage(sessionId, msg);
System.debug('Response: ' + JSON.serializePretty(sendResult));

// End session
ConnectApi.AgentService.endAgentSession(sessionId);
```

### 14.2 Apex unit tests for @InvocableMethod

```apex
@IsTest
private class YourApexActionTest {

    @TestSetup
    static void makeData() {
        // Create minimal test data — no SeeAllData=true
        Account acc = new Account(Name='Test Account');
        insert acc;
        Case c = new Case(AccountId=acc.Id, Subject='Test Case', Status='New');
        insert c;
    }

    @IsTest
    static void testSuccessPath() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        YourApexAction.ActionRequest req = new YourApexAction.ActionRequest();
        req.caseId = c.Id;

        Test.startTest();
        List<YourApexAction.ActionResult> results = YourApexAction.execute(
            new List<YourApexAction.ActionRequest>{ req }
        );
        Test.stopTest();

        System.assertNotEquals(null, results, 'Results should not be null');
        System.assertEquals(1, results.size(), 'Should return one result');
        System.assertNotEquals(null, results[0].caseNumber, 'Case number should be populated');
        System.assertEquals(null, results[0].errorMessage, 'No error expected');
    }

    @IsTest
    static void testInvalidId() {
        YourApexAction.ActionRequest req = new YourApexAction.ActionRequest();
        req.caseId = 'INVALID_ID';

        Test.startTest();
        List<YourApexAction.ActionResult> results = YourApexAction.execute(
            new List<YourApexAction.ActionRequest>{ req }
        );
        Test.stopTest();

        System.assertNotEquals(null, results[0].errorMessage, 'Error message should be populated');
    }
}
```

---

## 15. Lessons Learned — Rules Every Agent Must Follow

These rules were learned from production debugging. Violating them causes silent failures.

### L1 — Never use sessionVariables

Do NOT pass record IDs via `sessionVariables` JSON parameter in `generateAiAgentResponse`. It is silently dropped. Embed IDs in the user message text instead.

### L2 — invokeAgent vs invokeAgentForText

Use `invokeAgent()` for structured JSON responses. Use `invokeAgentForText()` when the agent returns free text — the response comes wrapped in a `{"type":"Text","value":"..."}` envelope; unwrap it explicitly.

### L3 — Flow actions need no GenAiFunction wrapper

Use `target: "flow://FlowApiName"` directly. No `source:` GenAiFunction wrapper required for flow-backed actions in the authoring bundle approach.

### L4 — `available when:` is invalid in agent script actions

Do not add `available when:` to action definitions in the `.agent` DSL — it causes a parse error. Control action availability through the STEP reasoning instructions instead.

### L5 — AgentforceEmployeeAgent required for Apex invocation

Agent type must be `AgentforceEmployeeAgent` for server-side Apex to invoke it via `generateAiAgentResponse` inside the org.

### L6 — Publish command flag is `--api-name`

```bash
# Correct
sf agent publish authoring-bundle --api-name Your_Agent_Api_Name

# Wrong — silently fails or errors
sf agent publish authoring-bundle --agent-api-name Your_Agent_Api_Name
```

### L7 — Flow prompt template output variables stay null unless explicitly assigned

After `generatePromptResponse`, only `<actionName>.promptResponse` is populated. Any other declared `isOutput: true` variables remain null unless an Assignment element explicitly copies the value. Always add the Assignment element.

### L8 — Prompt extraction tasks must describe the actual data format

If extracting a confirmation number or structured code, describe the actual format in the prompt task: "groups of 3+ digits separated by hyphens, e.g. 123-456 or 456-789-012". Generic descriptions like "code with dashes" cause silent null results when the LLM cannot match the format.

### L9 — LWC summary labels must be exact strings

If an LWC parses `context.summary` for specific colon-label strings, the agent must output those exact strings (colon included, same casing, same spacing). The LWC does not fuzzy-match. Slash-separated concept lists, heading text, or paraphrased labels produce a UI where no sections are parsed — the user sees the entire raw text as a single block.

### L10 — Extracted data must appear in the summary text

JSON output fields (`confirmationNumber`, `newEmailAddress`) drive automation only. The `summary` text field is what humans read in the UI. If data is extracted, it must also be stated explicitly in the summary. Automation reading the JSON and a human reading the summary must never see contradictory information.

---

## 16. Deployment Checklist

Before publishing the agent bundle, verify every item:

- [ ] Agent type set correctly (`AgentforceEmployeeAgent` or `AgentforceServiceAgent`)
- [ ] All referenced Apex classes deployed and confirmed present in org
- [ ] All referenced flows deployed, Active, and of type AutoLaunchedFlow
- [ ] All referenced prompt templates deployed and Active
- [ ] All GenAiFunctions deployed (if any)
- [ ] All flow fault paths defined (no orphan fault connectors)
- [ ] All flow `generatePromptResponse` outputs assigned via Assignment elements
- [ ] Prompt extraction tasks describe actual data format (not generic description)
- [ ] Agent reasoning instructions use exact label strings matching any downstream UI parsers
- [ ] Record IDs injected via message text (not sessionVariables)
- [ ] JSON output format defined with schema in reasoning instructions
- [ ] Guardrails block present and covers all action failure cases
- [ ] `available when:` NOT used in action definitions (use STEP instructions instead)
- [ ] Publish command uses `--api-name` flag (not `--agent-api-name`)

```bash
# Final publish
sf agent publish authoring-bundle --api-name Your_Agent_Api_Name --target-org your-alias
```

---

*Agentforce Authoring Bundle Guide | Generic reference | v1.0 — May 2026*
