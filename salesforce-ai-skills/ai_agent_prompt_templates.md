# AI Agent Prompt Templates — Plusgrade Agentforce

Copy-paste prompt scaffolds and code templates for the AI-agent tasks this project ships most often. The DSL grammar, lifecycle commands, and authoring conventions are owned elsewhere — this file is the **template-helper layer**.

**Pair with:** [agentforce-agent-script-reference.md](agentforce-agent-script-reference.md) · [agentforce_authoring_bundle_guide.md](agentforce_authoring_bundle_guide.md) · [agentforce_script_guidelines.md](agentforce_script_guidelines.md) · [agentforce_builder_guidelines.md](agentforce_builder_guidelines.md).

Last verified 2026-05-16.

---

## How to use this file

1. Pick the template matching your task from the table below.
2. Copy the block as-is.
3. Replace every `<PLACEHOLDER>` (angle-bracket tokens) — leaving one in causes silent failures.
4. Run the validate / publish commands from `agentforce_authoring_bundle_guide.md §4`.

| # | Template | When |
|---|---|---|
| 1 | New script-version agent skeleton | Bootstrapping a new `AiAuthoringBundle` from scratch |
| 2 | Constitution (`system.instructions`) | Writing the 7-section agent constitution |
| 3 | `variables:` block | State, mode flags, captured outputs |
| 4 | New subagent (description + reasoning + actions) | Adding a domain to an existing agent |
| 5 | Apex `@InvocableMethod` action class | Backing logic for an `apex://` action |
| 6 | Apex caller (`generateAiAgentResponse`) | Server-invoking an EmployeeAgent from Apex |
| 7 | JSON return-contract + Apex deserialization | Agent returns structured JSON for downstream parsing |
| 8 | LWC ↔ agent integration | Parsing colon-labeled summary lines in an LWC |
| 9 | Bot-meta override manifest | PII agents that must lock `logPrivateConversationData=false` |
| 10 | Test-invoker scaffold | `EmailResendAgentTestInvoker`-style smoke harness |

---

## 1. New Script-Version Agent Skeleton

A complete, valid `.agent` file with every required block. Drop into `force-app/main/default/aiAuthoringBundles/<Dev_Name>/<Dev_Name>.agent` after running `sf agent generate authoring-bundle --json --no-spec --name "<Label>" --api-name <Dev_Name>`.

```
system:
   instructions: |
      ROLE
      You are a <ROLE — e.g. server-invoked email-analysis specialist> for Plusgrade.

      GROUNDING
      Ground every output in action outputs. Never invent <DOMAIN_NOUNS — e.g.
      Case data, email content, customer history>.

      RETURN CONTRACT
      <MODE_A> → <FORMAT_A — e.g. only the prescribed JSON, no markdown fence>.
      <MODE_B> → <FORMAT_B — e.g. plain-text email body, no JSON, no sign-off>.

      DATA PRIVACY
      Treat the payload as PII. Do not echo PII unless explicitly requested.

      FABRICATION
      If a value is absent from action outputs, leave the field empty/null.
      Never guess.

      ERROR DEFAULT
      If <gating_action> returns errorMessage, return <SAFE_FALLBACK>.

      WHAT NOT TO DO
      Do not call the same action twice. Do not paraphrase. Do not round numbers.

   messages:
      welcome: "Ready."
      error: "Operation cancelled for safety."

config:
   developer_name: "<Dev_Name>"                       # must match dir + filename
   agent_label: "<Display Label>"
   description: "<one-paragraph what-and-why>"
   role: "<focused operator persona>"
   company: "Plusgrade — global airline/hotel loyalty programs operating across 30+ markets, partnering with major carriers and hotel groups."
   agent_type: "AgentforceEmployeeAgent"              # or AgentforceServiceAgent
   # default_agent_user: "<svc.user@plusgrade.com>"   # SERVICE AGENTS ONLY — delete this line for Employee
   enable_enhanced_event_logs: True
   user_locale: "en_US"

variables:
   case_id: mutable id = ""
      description: "Salesforce Case Id this conversation is anchored to"
   email_message_id: mutable id = ""
      description: "Source EmailMessage Id"
   mode: mutable string = "<DEFAULT_MODE>"
      description: "<MODE_A> or <MODE_B> — router sets at hand-off"
   context_loaded: mutable boolean = False

start_agent agent_router:
   label: "Agent Router"
   description: "Classify the inbound request and route to the correct subagent"

   reasoning:
      instructions: |
         You are a router only. Do NOT answer questions or draft replies.
         Pick exactly one transition action and route immediately.
         - If <CONDITION_A>, use go_<subagent_a>.
         - Otherwise use go_<subagent_b>.

      actions:
         go_<subagent_a>: @utils.transition to @subagent.<subagent_a>
            description: "<one-line trigger phrase the LLM uses to pick this>"

         go_<subagent_b>: @utils.transition to @subagent.<subagent_b>
            description: "<one-line trigger phrase the LLM uses to pick this>"

subagent <subagent_a>:
   label: "<Display Label>"
   description: "<scope statement — what's in, what's out>"

   actions:
      # subagent-level definitions (see §4 + §5)

   reasoning:
      instructions: ->
         if @variables.context_loaded == False:
            | Load the context via {!@actions.get_context}.

      actions:
         get_context: @actions.get_context
            with caseId = @variables.case_id
            with emailMessageId = @variables.email_message_id
            set @variables.context_loaded = True
```

After authoring, validate:

```bash
sf agent validate authoring-bundle --json --api-name <Dev_Name>
```

---

## 2. Constitution (`system.instructions`) — Prompt to Generate

```
Generate a system.instructions block for an Agentforce <EMPLOYEE | SERVICE> agent
named "<Dev_Name>" that does <PURPOSE>.

Required structure — 15–30 lines, plain text, exact section headers:
   ROLE
   GROUNDING
   RETURN CONTRACT
   DATA PRIVACY
   FABRICATION
   ERROR DEFAULT
   WHAT NOT TO DO

Constraints:
- Operational third-person (server-invoked agent has no live customer) OR
  second-person imperative (service agent with a live customer) — pick one and
  use it consistently.
- RETURN CONTRACT specifies the EXACT output format per mode. For JSON, write
  the literal JSON template. For email body, state "plain-text only, no JSON,
  no sign-off".
- WHAT NOT TO DO lists at least 3 concrete forbidden behaviors.
- No marketing language. No "be helpful" platitudes.

Mode list: <MODE_A>, <MODE_B>, ...
Backing actions available: <ACTION_LIST>
PII fields handled: <PII_LIST or "none">
Safe fallback for action failure: <FALLBACK_JSON or "..">

Output ONLY the system.instructions block. No surrounding YAML, no commentary.
```

---

## 3. `variables:` Block — Standard Shape

```
variables:
   # Identity (slot-filled from inbound message text)
   case_id: mutable id = ""
      description: "Case Id the conversation is anchored to"
   email_message_id: mutable id = ""
      description: "Source EmailMessage Id"

   # Mode flag — router sets at hand-off
   mode: mutable string = "<DEFAULT_MODE>"
      description: "<MODE_A> | <MODE_B>"

   # State-machine gates (one per ground-once action)
   context_loaded: mutable boolean = False
   <feature>_loaded: mutable boolean = False

   # Captured action outputs (re-read across turns)
   case_subject: mutable string = ""
   email_body: mutable string = ""

   # Error-message captures (deterministic guardrails)
   <action>_error_message: mutable string = ""
      description: "Populated by <action> when it fails. Empty on success."

   # Linked from session (read-only, no default)
   session_id: linked string
      source: @session.sessionID
      description: "Runtime-injected session ID"
```

**Rules** (from `agentforce-agent-script-reference.md §6`):
- Every `mutable` must have a default value (`= ""`, `= False`, `= []`, etc.).
- Every `linked` must have a `source:` and NO default.
- `linked` cannot wrap `list[T]` or `object`.
- `True` / `False` only — lowercase fails compile.

---

## 4. New Subagent — Description + Reasoning Scaffold

```
subagent <subagent_id>:
   label: "<Display Label>"
   description: |
      Used when <CLASSIFICATION — what user intent or condition activates this>.
      Scope: <IN-SCOPE behaviors and outputs>.
      Out of scope: <OUT-OF-SCOPE — list other subagents' domains>.

   # Optional — override system.instructions for this subagent only
   system:
      instructions: |
         <Domain-specific persona override, if needed>

   # ACTION DEFINITIONS — what exists
   actions:
      get_context:
         description: "<one-line operator-facing summary>"
         label: "<Display Label>"
         include_in_progress_indicator: True
         progress_indicator_message: "Loading..."
         inputs:
            caseId: id
               description: "Salesforce Case Id"
               is_required: True
         outputs:
            caseSubject: string
               description: "Case Subject"
            errorMessage: string
               description: "Populated on failure. Empty on success."
               filter_from_agent: True
         target: "apex://<InvocableClassName>"

   # REASONING — condition-based steps
   reasoning:
      instructions: ->
         # STEP 1 — Ground context
         if @variables.context_loaded == False:
            | Load the case context via {!@actions.get_context}.

         # STEP 2 — Domain work (only after ground)
         if @variables.context_loaded == True and @variables.<gate_var> == "":
            | <Operator-facing instruction line>.
              Save the captured value via {!@actions.<setter_action>}.

         # STEP 3 — Error-message guardrail
         if @variables.<action>_error_message != "":
            | The action failed: {!@variables.<action>_error_message}.
              Return <SAFE_FALLBACK>.

         # STEP 4 — Return contract
         if @variables.<done_gate> == True:
            | GUARDRAILS:
              - Do not invent fields.
              - Do not paraphrase action outputs.
              - Do not call the same action twice.

      # ACTION INVOCATIONS — when and how
      actions:
         get_context: @actions.get_context
            with caseId = @variables.case_id
            set @variables.case_subject = @outputs.caseSubject
            set @variables.<action>_error_message = @outputs.errorMessage
            set @variables.context_loaded = True

         <setter_action>: @utils.setVariables
            description: "<what the LLM is saving>"
            with <variable_name> = ...
```

**Rules** (from `agentforce_script_guidelines.md §7-8`):
- Subagent-level `actions:` declares definitions. `reasoning.actions:` declares invocations. Keep the split.
- Every action that fails-and-changes-behavior MUST declare `errorMessage: string` in `outputs:`.
- Every action definition needs an `outputs:` block (Issue #15 — publish fails otherwise).
- Reasoning uses `instructions: ->` (procedural) with `if @variables.X:` gates — never paragraph prose.

---

## 5. Apex `@InvocableMethod` Action Class

Standard backing class for an `apex://` target. Try/catch wraps every call; `errorMessage` populated instead of throwing; correlation ID for `AppLog__c` join.

```apex
/**
 *  Developer: Naresh
 *  Title:     Senior Salesforce Developer
 *  Purpose:   Backing logic for Agentforce action <action_name>.
 *             Wired to subagent action with target "apex://<ClassName>".
 */
public with sharing class <ClassName> {

   @InvocableMethod(
      label='<Display Label>'
      description='<One-line operator-facing description>'
      category='Agentforce')
   public static List<Response> invoke(List<Request> requests) {
      List<Response> results = new List<Response>();
      for (Request req : requests) {
         String correlationId = String.valueOf(System.currentTimeMillis())
                              + '-' + EncodingUtil.convertToHex(Crypto.generateAesKey(64)).substring(0, 8);
         Response res = new Response();
         try {
            AppLogger.info('<ClassName>.invoke', 'entry', correlationId,
                           new Map<String, Object>{ 'caseId' => req.caseId });

            // 1. Validate inputs
            if (String.isBlank(req.caseId)) {
               throw new <ClassName>Exception('caseId is required');
            }

            // 2. Query backing data (WITH USER_MODE — CRUD/FLS enforced)
            List<Case> cases = [
               SELECT Id, Subject, Description
               FROM Case
               WHERE Id = :req.caseId
               WITH USER_MODE
               LIMIT 1
            ];
            if (cases.isEmpty()) {
               throw new <ClassName>Exception('Case not found: ' + req.caseId);
            }
            Case c = cases[0];

            // 3. Populate response
            res.caseSubject  = c.Subject;
            res.errorMessage = '';

            AppLogger.info('<ClassName>.invoke', 'success', correlationId, null);
         } catch (Exception e) {
            // NEVER throw — populate errorMessage so the agent's guardrail fires
            res.errorMessage = e.getMessage();
            AppLogger.error('<ClassName>.invoke', e, correlationId);
         }
         results.add(res);
      }
      return results;
   }

   /**
    * Action input — field names must EXACTLY match subagent action inputs
    * (case-sensitive). Reserved names that fail compile: model, description, label.
    */
   public class Request {
      @InvocableVariable(required=true label='Case Id')
      public Id caseId;
      @InvocableVariable(required=true label='Email Message Id')
      public Id emailMessageId;
   }

   /**
    * Action output — every output field declared in the subagent's outputs:
    * block MUST exist here.  errorMessage is REQUIRED for the deterministic
    * guardrail pattern (agentforce_script_guidelines.md §8).
    */
   public class Response {
      @InvocableVariable(label='Case Subject')
      public String caseSubject;
      @InvocableVariable(label='Error Message')
      public String errorMessage;
   }

   public class <ClassName>Exception extends Exception {}
}
```

**Traps** (from `agentforce_authoring_bundle_guide.md §16`):
- Action input names must match `@InvocableVariable` names exactly (case-sensitive). Snake_case DSL with camelCase Apex won't bind.
- Reserved `@InvocableVariable` names: `model`, `description`, `label` — using any of these fails Agent Script compile.
- Never throw — always populate `errorMessage`. The DSL guardrail relies on the output being present.

---

## 6. Apex Caller — `generateAiAgentResponse` Boilerplate

Server-invokes an `AgentforceEmployeeAgent` from Apex. IDs are embedded in the message text (NOT `sessionVariables` — silently dropped per `agentforce_authoring_bundle_guide.md §13`).

```apex
public with sharing class <AgentName>Invoker {

   private static final String AGENT_API_NAME = '<Dev_Name>';

   /**
    * Server-invoke the agent and return the parsed structured payload.
    *
    * @param  caseId         Salesforce Case Id (embedded in message text)
    * @param  emailMessageId Source EmailMessage Id (embedded in message text)
    * @param  mode           Routing hint — e.g. STRUCTURED_ANALYSIS | EMAIL_TEMPLATE
    * @return                Parsed Map<String, Object> from the agent's JSON response
    */
   public static Map<String, Object> invoke(Id caseId, Id emailMessageId, String mode) {
      String correlationId = String.valueOf(System.currentTimeMillis());
      try {
         // Embed IDs in the user message — sessionVariables JSON is dropped
         String message = String.format(
            'Mode: {0}. Analyze the email for Case {1} and EmailMessage {2}.',
            new List<String>{ mode, caseId, emailMessageId }
         );

         Agent.GenerateAiAgentResponseInput input = new Agent.GenerateAiAgentResponseInput();
         input.agentApiName = AGENT_API_NAME;
         input.message      = message;

         AppLogger.info('<AgentName>Invoker.invoke', 'entry', correlationId,
                        new Map<String, Object>{ 'mode' => mode, 'caseId' => caseId });

         Agent.GenerateAiAgentResponseOutput out = Agent.generateAiAgentResponse(input);

         Map<String, Object> parsed = parseResponse(out);
         AppLogger.info('<AgentName>Invoker.invoke', 'success', correlationId, null);
         return parsed;
      } catch (Exception e) {
         AppLogger.error('<AgentName>Invoker.invoke', e, correlationId);
         throw new <AgentName>InvokerException(
            'Agent invocation failed (corrId=' + correlationId + '): ' + e.getMessage(), e);
      }
   }

   private static Map<String, Object> parseResponse(Agent.GenerateAiAgentResponseOutput out) {
      if (out == null || out.agentResponse == null) {
         throw new <AgentName>InvokerException('Empty agent response');
      }
      // Strip accidental ```json``` fence if the model added one
      String raw = out.agentResponse.trim();
      if (raw.startsWith('```')) {
         raw = raw.replaceFirst('(?s)^```(json)?', '').replaceFirst('(?s)```$', '').trim();
      }
      return (Map<String, Object>) JSON.deserializeUntyped(raw);
   }

   public class <AgentName>InvokerException extends Exception {}
}
```

**Traps**:
- `AgentforceServiceAgent` will not respond to `generateAiAgentResponse`. Must be `AgentforceEmployeeAgent`.
- If the agent emits free text (not JSON), `invokeAgent()` returns a `{"type":"Text","value":"..."}` envelope — strip via `invokeAgentForText` or unwrap manually.
- Always include a correlation ID — joins `AppLog__c` to enhanced event logs.

---

## 7. JSON Return-Contract + Apex Deserialization

DSL side — embed the literal JSON shape in `reasoning.instructions:`:

```
# STEP N — Return contract
if @variables.<done_gate> == True:
   | Return EXACTLY this JSON, no markdown fence, no prose before or after:
     {"summary":"",
      "category":"<ENUM_A | ENUM_B | ENUM_C>",
      "intent":"<ENUM_X | ENUM_Y>",
      "confirmationNumber":"",
      "newEmailAddress":null,
      "confidence":0.0}
     Use action-output values verbatim. Do not paraphrase dates,
     do not round numbers, do not invent fields.
```

Apex side — deserialize with validation per key:

```apex
public class <AgentName>Response {
   public String  summary;
   public String  category;
   public String  intent;
   public String  confirmationNumber;
   public String  newEmailAddress;
   public Decimal confidence;

   public static <AgentName>Response fromAgentOutput(String rawJson) {
      // Defence: strip markdown fence if present
      String body = rawJson == null ? '' : rawJson.trim();
      if (body.startsWith('```')) {
         body = body.replaceFirst('(?s)^```(json)?', '')
                    .replaceFirst('(?s)```$', '').trim();
      }
      // Type-safe deserialize. If keys are missing/extra, deserialize throws.
      <AgentName>Response r =
         (<AgentName>Response) JSON.deserialize(body, <AgentName>Response.class);

      // Validate required fields
      if (String.isBlank(r.category)) {
         throw new <AgentName>ResponseException('Missing required field: category');
      }
      if (r.confidence == null) {
         throw new <AgentName>ResponseException('Missing required field: confidence');
      }
      return r;
   }

   public class <AgentName>ResponseException extends Exception {}
}
```

**Rules**:
- The DSL prompt-text JSON template is the contract. Apex class fields must match exactly.
- If the LWC also parses a colon-labeled summary, the JSON's `summary` field and the colon-labeled summary text MUST agree — JSON drives automation, text drives humans (`agentforce_authoring_bundle_guide.md §16 row 8`).

---

## 8. LWC ↔ Agent Integration — Exact Colon-Labels

The LWC parses `context.summary` looking for **exact** colon-label strings. The DSL must emit them verbatim. The LWC must not fuzzy-match.

DSL side — in the prompt that produces the summary:

```
| Produce a summary with these EXACT lines, one per line, in this order,
  with the colon, casing, and spacing as written:
  Customer: <customer name from action output>
  Confirmation: <code from action output>
  Category: <category label>
  Resolution: <one-sentence proposed resolution>
```

LWC side — strict line-by-line parser:

```javascript
// force-app/main/default/lwc/<componentName>/<componentName>.js
const LABELS = {
   customer: 'Customer:',
   confirmation: 'Confirmation:',
   category: 'Category:',
   resolution: 'Resolution:',
};

function parseAgentSummary(summary) {
   const out = {};
   if (!summary) return out;
   const lines = summary.split(/\r?\n/);
   for (const line of lines) {
      const trimmed = line.trim();
      for (const [key, label] of Object.entries(LABELS)) {
         // STRICT match — no fuzzy / case-insensitive matching
         if (trimmed.startsWith(label)) {
            out[key] = trimmed.substring(label.length).trim();
         }
      }
   }
   return out;
}

export { parseAgentSummary };
```

**Rules** (from `agentforce_authoring_bundle_guide.md §16 row 7`):
- LWC parser is `startsWith` — no `.includes`, no regex, no case-insensitive.
- If a label changes, change BOTH the DSL prompt AND the LWC constants in the same commit. Mismatch silently drops fields.
- Always emit JSON in addition to the colon-labeled summary for any automation downstream.

---

## 9. Bot-Meta Override Manifest (PII Agents)

`sf agent publish authoring-bundle` overwrites `Bot.bot-meta.xml` with org defaults — including resetting `<logPrivateConversationData>` to `true`. For any agent processing PII, deploy this override **immediately after every publish**.

`manifest/package-<agent-slug>-bot-override.xml`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<Package xmlns="http://soap.sforce.com/2006/04/metadata">
   <types>
      <members><Dev_Name></members>
      <name>Bot</name>
   </types>
   <version>66.0</version>
</Package>
```

`force-app/main/default/bots/<Dev_Name>/<Dev_Name>.bot-meta.xml` — PII-safe values:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<Bot xmlns="http://soap.sforce.com/2006/04/metadata">
   <agentType>EinsteinServiceAgent</agentType>
   <agentTemplate>EmployeeCopilot__AgentforceEmployeeAgent</agentTemplate>
   <botMlDomain>
      <label><Display Label></label>
      <name><Dev_Name></name>
   </botMlDomain>
   <conversationDefinitionPlanners>
      <plannerName><Dev_Name></plannerName>
   </conversationDefinitionPlanners>
   <label><Display Label></label>
   <logPrivateConversationData>false</logPrivateConversationData>
   <richContentEnabled>false</richContentEnabled>
   <!-- Standard context variables — re-asserted because publish drops them -->
   <contextVariables>
      <contextVariableName>EndUserId</contextVariableName>
      <dataType>Text</dataType>
      <developerName>EndUserId</developerName>
      <label>End User ID</label>
   </contextVariables>
   <!-- Add the other 4 standard context variables here -->
</Bot>
```

Post-publish sequence:

```bash
# 1. Publish (overwrites bot-meta with org defaults)
sf agent publish authoring-bundle --json --api-name <Dev_Name>

# 2. Immediately re-deploy the override
sf project deploy start --json --manifest manifest/package-<agent-slug>-bot-override.xml --target-org <ORG_ALIAS>

# 3. Verify
sf project retrieve start --json --metadata Bot:<Dev_Name>
grep logPrivateConversationData force-app/main/default/bots/<Dev_Name>/<Dev_Name>.bot-meta.xml
# Expect: <logPrivateConversationData>false</logPrivateConversationData>
```

---

## 10. Test-Invoker Scaffold

`EmailResendAgentTestInvoker`-style smoke harness. Runs from anonymous Apex; populates `AppLog__c` for grep-friendly verification.

```apex
/**
 *  Developer: Naresh
 *  Title:     Senior Salesforce Developer
 *  Purpose:   Smoke-test harness for <AgentName>.  Runs from anonymous Apex.
 *             Logs every request + response to AppLog__c with correlationId
 *             for trace-side join.
 *
 *  Usage:
 *    <AgentName>TestInvoker.runAll();
 *    <AgentName>TestInvoker.runOne('T01_HappyPath', '500xx00000ABCDE', '02sxx00000FGHIJ');
 */
public with sharing class <AgentName>TestInvoker {

   public static void runAll() {
      runOne('T01_HappyPath',          '<TEST_CASE_ID_1>', '<TEST_EMAIL_MSG_ID_1>');
      runOne('T02_MissingConfirmation','<TEST_CASE_ID_2>', '<TEST_EMAIL_MSG_ID_2>');
      runOne('T03_ImageOcrFallback',   '<TEST_CASE_ID_3>', '<TEST_EMAIL_MSG_ID_3>');
      runOne('T04_ActionFailure',      '<TEST_CASE_ID_4>', '<TEST_EMAIL_MSG_ID_4>');
      runOne('T05_OutOfScope',         '<TEST_CASE_ID_5>', '<TEST_EMAIL_MSG_ID_5>');
   }

   public static void runOne(String scenario, Id caseId, Id emailMessageId) {
      String correlationId = scenario + '-' + String.valueOf(System.currentTimeMillis());
      try {
         AppLogger.info('<AgentName>TestInvoker.runOne', 'entry', correlationId,
                        new Map<String, Object>{
                           'scenario'      => scenario,
                           'caseId'        => caseId,
                           'emailMsgId'    => emailMessageId
                        });

         Map<String, Object> response =
            <AgentName>Invoker.invoke(caseId, emailMessageId, 'STRUCTURED_ANALYSIS');

         // Assert expectations per scenario
         assertScenario(scenario, response);

         AppLogger.info('<AgentName>TestInvoker.runOne', 'pass', correlationId,
                        new Map<String, Object>{ 'response' => response });
      } catch (Exception e) {
         AppLogger.error('<AgentName>TestInvoker.runOne (' + scenario + ')', e, correlationId);
      }
   }

   private static void assertScenario(String scenario, Map<String, Object> r) {
      // Soft assertions — log result, don't throw (so the whole suite runs)
      if (scenario == 'T01_HappyPath') {
         expect(r.get('category')         != null, scenario, 'category present');
         expect(r.get('confirmationNumber') != '',  scenario, 'confirmation extracted');
      } else if (scenario == 'T04_ActionFailure') {
         expect('FAILED'.equals(r.get('category')), scenario, 'category=FAILED on action error');
      }
      // Add scenario-specific expectations here
   }

   private static void expect(Boolean condition, String scenario, String message) {
      String result = condition ? 'PASS' : 'FAIL';
      AppLogger.info('<AgentName>TestInvoker.expect', result,
                     scenario, new Map<String, Object>{ 'check' => message });
   }
}
```

**How to run**:

```bash
# Anonymous Apex execution
sf apex run --target-org <ORG_ALIAS> --file scripts/apex/run-<agent>-tests.apex

# scripts/apex/run-<agent>-tests.apex contains one line:
#    <AgentName>TestInvoker.runAll();

# Read results
sf data query --target-org <ORG_ALIAS> --json \
  -q "SELECT Method__c, Result__c, CorrelationId__c, Details__c FROM AppLog__c WHERE Method__c LIKE '<AgentName>TestInvoker%' ORDER BY CreatedDate DESC LIMIT 50"
```

---

## Quick Reference — Template → Source-of-Truth Skill File

| Template | Authoritative skill file |
|---|---|
| 1. Agent skeleton | `agentforce-agent-script-reference.md §1-8` |
| 2. Constitution | `agentforce_script_guidelines.md §4` |
| 3. Variables | `agentforce-agent-script-reference.md §6` + `agentforce_script_guidelines.md §5,11` |
| 4. Subagent | `agentforce-agent-script-reference.md §8` + `agentforce_script_guidelines.md §7-8` |
| 5. Apex action | `agentforce_authoring_bundle_guide.md §13,16` + `apex_guidelines.md` |
| 6. Apex caller | `agentforce_authoring_bundle_guide.md §13` |
| 7. JSON contract | `agentforce_authoring_bundle_guide.md §14` |
| 8. LWC integration | `agentforce_authoring_bundle_guide.md §16 row 7-8` + `lwc_guidelines.md` |
| 9. Bot-meta override | `agentforce_authoring_bundle_guide.md §8` |
| 10. Test invoker | `agentforce_authoring_bundle_guide.md §12` + `observability_logging_guidelines.md` |

---

## Common AI Mistakes to Avoid

| # | Mistake | Correct approach |
|---|---|---|
| 1 | Pasting a template and leaving `<PLACEHOLDER>` tokens in the file | Grep for `<` after substitution. Any remaining angle-bracket token will silently mis-bind |
| 2 | Using template 5 without snake_case ↔ camelCase parity check | Action input names must EXACTLY match `@InvocableVariable` field names (case-sensitive) |
| 3 | Skipping template 9 on a PII agent | `logPrivateConversationData` flips to `true` after every publish — override every time or PII leaks to logs |
| 4 | Mixing template 7 JSON keys with template 8 colon labels | JSON drives automation, summary drives humans. State data in BOTH; never let them disagree |
| 5 | Reusing template 6 for `AgentforceServiceAgent` | `generateAiAgentResponse` requires `AgentforceEmployeeAgent`. Service agents respond via messaging channels only |

---

## Official References

- [agentforce-agent-script-reference.md](agentforce-agent-script-reference.md) — DSL grammar (canonical)
- [agentforce_authoring_bundle_guide.md](agentforce_authoring_bundle_guide.md) — lifecycle, deploy/publish, Bot-meta override, Apex caller
- [agentforce_script_guidelines.md](agentforce_script_guidelines.md) — authoring style, constitution, condition-based reasoning
- [agentforce_builder_guidelines.md](agentforce_builder_guidelines.md) — Builder UI ↔ DSL parity
- [apex_guidelines.md](apex_guidelines.md) — Apex action class standards
- [lwc_guidelines.md](lwc_guidelines.md) — LWC parser standards
- [observability_logging_guidelines.md](observability_logging_guidelines.md) — `AppLogger`, correlation IDs

---

*AI Agent Prompt Templates | v3.0 | Last verified 2026-05-16*
