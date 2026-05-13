# Agentforce Agent Script / Instructions Guidelines

**Version**: 2.0 (April 2026)
**Developer**: Naresh | Senior Salesforce Developer
**Purpose**: Guidelines for designing and writing Agentforce agent instructions, topic configurations, and orchestration logic. Attach when building, reviewing, or modifying any Agentforce agent.

> **Important**: Agentforce metadata and capabilities evolve rapidly with each Salesforce release. Items marked "verify in target org/release" MUST be confirmed in your org before implementation.

---

## Table of Contents

1. [Required Agent Output Contract](#1-required-agent-output-contract)
2. [Agentforce Concepts Overview](#2-agentforce-concepts-overview)
3. [Instructions Design Principles](#3-instructions-design-principles)
4. [Action Gating](#4-action-gating)
5. [Variable Handling](#5-variable-handling)
6. [Grounding and Knowledge](#6-grounding-and-knowledge)
7. [When to Use Flows vs Apex Actions](#7-when-to-use-flows-vs-apex-actions)
8. [Verification Steps](#8-verification-steps)
9. [Deterministic Orchestration](#9-deterministic-orchestration)
10. [Safety Guardrails](#10-safety-guardrails)
11. [Conversation Behavior](#11-conversation-behavior)
12. [Testing Strategy](#12-testing-strategy)
13. [Deployment / Versioning Considerations](#13-deployment--versioning-considerations)
14. [Example: Service Support Agent for Case Creation](#14-example-service-support-agent-for-case-creation)
15. [Anti-Patterns](#15-anti-patterns)
16. [Definition of Done](#16-definition-of-done)
17. [Official References](#17-official-references)

---

## 1. Required Agent Output Contract

Every Agentforce agent design response MUST include all of the following sections. Do not deliver a partial agent design — incomplete designs will lead to broken orchestration, security gaps, or untestable agents.

1. **Agent purpose and scope definition** — what business problem the agent solves, what channels it operates on, what it is explicitly NOT allowed to do
2. **Topics/subagents list with responsibility boundaries** — each topic named, scoped, and bounded so the LLM routes correctly
3. **Action inventory (flows, Apex invocables, standard actions)** — every callable action with its API name, type (Flow / Apex / Standard), and one-line purpose
4. **Variable contract (input/output for each action)** — all input and output variable names, types, and whether required or optional
5. **Orchestration sequence with gates and guards** — numbered steps, each with its gating condition and what happens on failure
6. **Safety guardrails** — hallucination prevention, out-of-scope handling, PII policy, escalation triggers
7. **Test conversation examples** — at minimum happy path, wrong verification code, contact not found, action failure, out-of-scope
8. **Deployment/versioning notes** — metadata types, CLI commands, sandbox-first policy, version naming
9. **Rollback approach** — how to revert to the prior version if the new version fails in production

---

## 2. Agentforce Concepts Overview

> Verify naming conventions in the current Salesforce release. Terminology has shifted between releases (e.g., "Bot" vs "Agent", "topic" vs "subagent").

### Core Components

| Term | Description |
|---|---|
| **Agent (Bot)** | Top-level configuration entity. Associated with a channel (Messaging for In-App and Web, Experience Cloud, etc.). The bot configuration defines which topics are available and global behavior. |
| **Topic** (also called subagent) | A logical grouping of related capabilities and instructions for a specific task domain. Examples: `CaseCreation`, `GeneralFAQ`, `AccountLookup`. The LLM selects a topic based on the user's intent and the topic's description. |
| **Action** | A callable function the agent can invoke. Can be an Autolaunched Flow, an Apex invocable method, a standard platform action (e.g., knowledge search, send email), or a prompt template action. |
| **GenAiPlannerBundle** | Metadata type wrapping the agent's LLM orchestration configuration, topic assignments, conversation variable definitions, and binding rules. This is the "brain" configuration. |
| **GenAiPlugin** | Metadata type representing a single topic/subagent definition. Contains the topic's natural language instructions and references to its available actions (GenAiFunctions). |
| **GenAiFunction** | Metadata type representing a single action definition. Wraps a Flow or Apex invocable. Contains description (used by LLM for action selection), input/output parameter mappings. |

### Component Hierarchy

```
Bot (.bot-meta.xml)
└── Bot Version (.botVersion-meta.xml)

GenAiPlannerBundle (.genAiPlannerBundle-meta.xml)
├── References topics (GenAiPlugins)
├── Defines conversation variables
└── Contains agent-level and topic-level instructions

GenAiPlugin (.genAiPlugin-meta.xml) — one per topic/subagent
└── GenAiFunction (.genAiFunction-meta.xml) — one per action within the plugin
    └── Invocation Target: Flow OR Apex invocable
```

**Relationship summary**: Bot → GenAiPlannerBundle → GenAiPlugin(s) → GenAiFunction(s) → Flow/Apex

The Bot activates a specific version of the PlannerBundle. The PlannerBundle's instructions direct the LLM to route to topics (Plugins). Each Plugin has its own instructions and a set of Functions (actions). Functions invoke the actual business logic in Flows or Apex.

---

## 3. Instructions Design Principles

### Language Requirements

- Instructions MUST be written in clear, imperative natural language — the LLM reads these instructions at runtime
- Use second-person imperative: "Ask the customer...", "Use action FLO_X...", "Store output..."
- Use MUST / MUST NOT for hard requirements that are never negotiable
- Use "only proceed if [condition]" for gate checks
- Use "If [condition], then [action]" for conditional branching

### Scope and Focus

- **Agent-level instructions**: global behavior, tone, escalation rules, topics available, what is out of scope
- **Topic-level instructions**: specific ordered steps for that topic's task domain only
- Keep each topic focused on one domain — do not let a topic handle multiple unrelated business processes
- Instructions should make it impossible for the LLM to confuse two topics' responsibilities

### Structure

- Use numbered steps for ordered operations — "Step 1...", "Step 2...", etc.
- State the exact action name in instructions (matching the GenAiFunction name exactly)
- State what variables to store from each action's output
- State gating conditions explicitly before each step
- State what to do on failure after each step

### Clarity Over Brevity

- It is better to be explicit and verbose in instructions than to leave ambiguity the LLM could exploit
- Never rely on the LLM's general knowledge to fill gaps — state everything explicitly
- Repeat critical rules (e.g., "Do not fabricate a case number") more than once if needed

---

## 4. Action Gating

Gates are the primary mechanism for enforcing deterministic orchestration. Every gate must be explicit in the instructions.

### Gate Types

**Hard gates (sequential dependency)**
> "Do not proceed to Step N until Step N-1 output [variable] is confirmed as [expected value]."

Example:
> "GATE: Do not proceed to Step 3 until isVerified = true. If isVerified is false or not set, do not continue under any circumstances."

**Authentication gates**
> "Verify the customer's identity before taking any action on their account. Identity is verified when isVerified = true and verifiedContactId is populated."

**Confirmation gates (before irreversible actions)**
> "Present a summary of the case details to the user and wait for explicit confirmation (YES) before calling FLO_CreateCase. Do not create a case without this confirmation."

**Variable population gates**
> "GATE: Do not proceed to Step 4 without a valid contactId. If contactId is empty, re-attempt Step 3. If still empty after retry, escalate to a live agent."

### Failure Handling at Each Gate

Every gate must have a defined failure path:

```
GATE: isVerified must = true before this step.
- If isVerified = false: inform the customer that identity verification failed.
  Allow one retry of the verification step.
  If verification fails a second time: say "I'm unable to verify your identity.
  Let me connect you with a member of our team." and transfer to live agent.
- If isVerified is not set (action did not run): treat as verification failure.
```

---

## 5. Variable Handling

### Persistence

- Variables persist within a conversation session via **conversation variables** defined in the GenAiPlannerBundle
- Variables do NOT persist across sessions by default — each new conversation starts fresh
- If cross-session persistence is needed, it must be handled via org data (records), not conversation variables

### Mapping Rules

- Map action outputs to conversation variables **explicitly** — never assume a variable is auto-populated
- In instructions, use this pattern: "Store output: [outputVarName] → conversation variable [varName]"
- Critical variables (e.g., `isVerified`, `contactId`, `authenticationKey`) MUST be set before any step that depends on them
- Variable names in instructions MUST match the actual Flow/Apex variable names exactly (case-sensitive)

### Naming Conventions

| Variable Pattern | Usage |
|---|---|
| `input_[Name]` | Input variable passed into a Flow/Apex action |
| `output_[Name]` | Output variable returned from a Flow/Apex action |
| `var_[Name]` | Conversation-level variable stored across steps |
| `context_[Name]` | Context variables auto-populated by Agentforce (e.g., `RoutableId`, `endUserEmail`) |

### Critical Variable Checklist

Before any sensitive action, these variables must be confirmed populated:
- `isVerified` = true
- `contactId` or `verifiedContactId` (not empty)
- `authenticationKey` (for steps that use it downstream)
- `draftConfirmed` = true (before irreversible record creation)

---

## 6. Grounding and Knowledge

### Knowledge Base Actions

- Use the "Answer questions using the knowledge base" standard action for FAQ / informational topics
- Knowledge actions should be configured as the **primary action** for GeneralFAQ-type topics
- Do not mix knowledge-based responses with structured record actions in the same topic — keep them separate

### Knowledge-First Fallback Pattern

For topics that try structured actions first:
1. Attempt structured action (e.g., record lookup)
2. If action returns no results OR status = ERROR: fall back to knowledge base search
3. If knowledge base also returns no relevant results: escalate to live agent

### Grounding Rules

- Instructions MUST state: "Only respond with information from the knowledge base or confirmed action results."
- Instructions MUST state: "Do not invent, guess, or infer answers. If you cannot find the answer in the knowledge base or via a confirmed action result, say so and offer to connect the customer with a team member."
- For live org data (e.g., account details, case status): always use a Get Records action or Apex invocable to fetch current data before responding. Never use information from training data to answer account-specific questions.

### Anti-Hallucination Policies

The following MUST appear explicitly in topic instructions for any topic that retrieves or creates records:

```
IMPORTANT: Do not fabricate or guess any of the following:
- Case numbers
- Contact IDs or account IDs
- Record status values
- Dates, SLAs, or resolution times
Use ONLY the values returned by action outputs. If an output is empty, treat it as a failure.
```

---

## 7. When to Use Flows vs Apex Actions

| Scenario | Recommended Approach |
|---|---|
| Simple record lookup (single object) | Autolaunched Flow with Get Records element |
| Simple record create/update | Autolaunched Flow with Create Records / Update Records element |
| Complex data processing across multiple objects | Apex invocable method |
| Business logic with conditional branching and multiple decisions | Apex invocable (cleaner, testable) OR complex Flow (verify governor limits) |
| Callouts to external systems / APIs | Apex invocable with Named Credentials (Flows have callout limitations) |
| Picklist dependency matrix / configuration lookup from Custom Metadata | Apex invocable reading Custom Metadata Type records |
| Email / notification sending via platform | Autolaunched Flow using Send Email element or platform actions |
| Verification code generation and validation | Autolaunched Flow (simple) or Apex (if custom hashing logic required) |
| Knowledge base search | Standard Agentforce action (streamKnowledgeSearch — verify availability in target org) |
| Returning structured JSON for the LLM to parse | Apex invocable (flows have limited String manipulation for JSON construction) |

### Decision Principle

> If the logic can be reliably built and maintained in a Flow without exceeding governor limits or requiring complex string/JSON manipulation, use a Flow. Use Apex for complexity, callouts, and performance-sensitive operations.

---

## 8. Verification Steps

### Identity Verification Is Mandatory

Identity verification MUST be a prerequisite gate for all account-sensitive actions, including:
- Case creation
- Account or contact data retrieval
- Account modification
- Billing or invoice lookup
- Any action that reads or writes customer-specific data

### Standard Verification Pattern

The following pattern MUST be implemented in this exact order:

```
Step 1: Send verification code
  → Action: FLO_SendVerificationCode
  → Input: endUserEmail (from conversation context)
  → Outputs: authenticationKey, status, outMessage
  → On ERROR: surface outMessage, offer live agent

Step 2: User submits verification code
  → Ask: "Please enter the verification code sent to your email."
  → Collect: verificationCode (user input)

Step 3: Verify code and find contact
  → Action: FLO_VerifyContact
  → Inputs: authenticationKey, endUserEmail, verificationCode
  → Outputs: isVerified (Boolean), verifiedContactId, status, outMessage
  → On isVerified = false: allow 1 retry
  → On 2nd failure: transfer to live agent

Step 4 onward: All steps GATED on isVerified = true
```

### Retry Policy

- Allow exactly **one retry** on a failed verification code
- After two consecutive failures: do not allow further attempts in the same session
- Transfer to live agent with message: "I was unable to verify your identity. Let me connect you with a member of our support team."

### Never Skip Verification

Instructions MUST state explicitly:
> "Under no circumstances proceed past Step 2 without isVerified = true. This gate is absolute and cannot be bypassed by any user input."

---

## 9. Deterministic Orchestration

### The Problem

The LLM is inherently non-deterministic. Without explicit instructions, it may:
- Skip steps it judges as unnecessary
- Reorder steps based on conversational context
- Attempt to answer questions using fabricated data rather than calling actions
- Proceed past failures silently

### The Solution: Explicit Step Locks

Instructions must make reordering or skipping impossible by stating consequences:

```
You MUST follow these steps in exactly the order listed. Do not skip any step.
Do not proceed to a later step until the conditions for that step's gate are met.
If any gate condition is not met, stop and follow the failure path for that step.
There are no exceptions to this sequence.
```

### Enforcement Techniques

**Number every step**: "Step 1", "Step 2", etc. — makes the sequence unambiguous.

**Explicit "only after" language**:
> "Step 3 may only be invoked after Step 2 has returned isVerified = true."

**Explicit "never if" language**:
> "Never invoke FLO_CreateCase if draftConfirmed is not explicitly true. If you are uncertain whether the customer confirmed, ask again rather than proceeding."

**Consequence statements**:
> "If you create a case without the customer's explicit confirmation, you will have created an unwanted record that cannot be easily undone. Do not do this."

### One Action Per Turn

- The agent MUST NOT invoke multiple actions in a single turn without user input between them (unless explicitly designed as a silent background chain — verify this pattern in current release)
- Present results to the user between significant steps
- Ask the user for confirmation or input before proceeding to the next step when required

---

## 10. Safety Guardrails

### Out-of-Scope Handling

Instructions MUST include an explicit out-of-scope policy:

```
If the user asks about any topic outside the scope of [TopicName], respond:
"I can help you with [in-scope description]. For other questions, I can connect you
with our support team. Would you like me to do that?"
Do not attempt to answer out-of-scope questions, even if you believe you know the answer.
```

### No Hallucination Policy

The following prohibitions MUST appear in every topic that creates or retrieves records:

```
Do NOT:
- Fabricate case numbers, reference numbers, or ticket IDs
- Guess contact IDs, account IDs, or record IDs
- Invent SLA timeframes, dates, or resolution windows
- Make up status values for cases or accounts
- Assume an action succeeded if you did not receive its output

If you do not have the value from an action output, you do not have the value. Period.
```

### Sensitive Data Policy

```
Do not repeat back to the user:
- Verification codes or OTPs
- Passwords or authentication tokens
- Full credit card numbers or payment details
- Full government ID numbers (e.g., Social Insurance Number, SSN)
- Full date of birth (partial masking acceptable if required for verification)
```

### Escalation Triggers

The agent MUST offer escalation to a live agent in the following scenarios:

| Trigger | Escalation Message |
|---|---|
| Verification fails twice | "I was unable to verify your identity. Let me connect you with a support team member." |
| Any action returns status = ERROR twice | "I'm experiencing a technical issue completing this for you. Let me connect you with our team." |
| User expresses frustration or urgency | "I understand this is urgent. Let me connect you right away with a team member who can help." |
| Out-of-scope after 2 attempts to redirect | "Let me connect you with someone who can better assist with your question." |
| Any step fails and retry also fails | Escalate with context summary if possible |

### PII Policy

```
Do not log, store, or pass through variables any of the following
beyond what is needed for the current transaction:
- Full government identification numbers
- Payment card numbers
- Passwords or authentication secrets
- Medical information

Clear sensitive variables (e.g., verificationCode) from conversation state
after the verification step is complete. (Verify variable clearing capability in target org/release.)
```

---

## 11. Conversation Behavior

### Tone

- Professional, concise, and empathetic
- Acknowledge the customer's issue or question before diving into process steps
- Use the customer's name if available from the verified contact record
- Never be dismissive or robotic — show awareness that the customer has a real problem

### One Question / One Action Per Turn

- Ask only one question at a time — do not ask for multiple pieces of information in one message
- If collecting multiple inputs (e.g., case details), collect them one at a time or in a structured, clearly labeled list
- Do not invoke more than one action per conversational turn unless the actions are invisible background operations with no user-facing outputs to present

### Confirmation Before Irreversible Actions

Before any action that creates, updates, or deletes a record:

```
Present a clear summary:
"I'm about to create the following case on your behalf:
  - Category: [category]
  - Subcategory: [subcategory]
  - Subject: [subject]
  - Description: [description]

Is this correct? Please reply YES to confirm or NO to make changes."

Do not proceed until the customer explicitly confirms.
```

### Completion Messages

- Always provide a case number, reference number, or confirmation ID at the end of successful transactions
- Use only the value from the action output — never fabricate
- Provide clear next steps: "Our support team will contact you within [SLA — verify from org data, do not guess]."
- End with a closing offer: "Is there anything else I can help you with today?"

### Recovery Messages

If a step fails and the agent must stop:

```
"I'm sorry, I wasn't able to complete your request due to a technical issue.
Your reference for this interaction is [sessionId if available].
Would you like me to connect you with a support team member who can assist further?"
```

---

## 12. Testing Strategy

### Required Test Scenarios

Every Agentforce agent MUST have test conversations covering all of the following:

| Scenario | What to Verify |
|---|---|
| **Happy path** | All 7 steps execute in order; correct case number returned; correct variables populated at each step |
| **Wrong verification code (first attempt)** | Agent allows retry; appropriate message shown |
| **Wrong verification code (second attempt)** | Agent escalates to live agent; does NOT allow a third attempt |
| **Contact not found after verification** | Agent collects new contact details and creates contact before proceeding |
| **Action failure at case creation** | Error message shown; escalation offered; no fabricated case number returned |
| **Out-of-scope question** | Agent deflects correctly; does NOT attempt to answer; offers escalation |
| **User declines confirmation at Step 5** | Agent gracefully accepts "NO", asks what the user wants to change, and loops back |
| **User abandons mid-flow** | Agent handles graceful timeout or session end without leaving orphaned records |

### Testing Tools

> Verify availability in target org and release:

- **Agentforce Agent Testing** — in-org testing tool for agent conversations (verify in Setup)
- **Manual test conversations** via the deployed channel (Messaging for In-App and Web, Experience Cloud preview, etc.)
- **Debug logs** — ensure debug logging is enabled during testing to trace Flow/Apex execution

### Verification Points Per Test

For each test scenario, verify:
1. The correct action fired at the correct step
2. Input variables were passed to the action correctly (check Flow/Apex debug logs)
3. Output variables were stored in the correct conversation variables
4. The gate conditions prevented (or allowed) progression to the next step
5. The response message shown to the user was accurate and did not contain fabricated data
6. The fault/error path triggered correctly when expected

### Regression Testing

After any change to:
- Agent instructions (any topic)
- Any Flow or Apex action used by the agent
- Variable mappings in the PlannerBundle
- Topic scope or topic descriptions

Run the full test suite (all scenarios above) before re-deploying to production.

---

## 13. Deployment / Versioning Considerations

> **Verify in target org/release**: Agentforce metadata deployment via SF CLI may have limitations depending on org type (Developer Edition, Scratch Org, Sandbox, Production) and API version. Confirm all CLI commands in your environment before use.

### Source Control Requirements

All agent metadata MUST be in source control. The following files must be committed together as a set:

```
force-app/main/default/
├── bots/
│   └── SupportPortalAgent/
│       ├── SupportPortalAgent.bot-meta.xml
│       └── v2.botVersion-meta.xml
├── genAiPlannerBundles/
│   └── SupportPortalAgent.genAiPlannerBundle-meta.xml
├── genAiPlugins/
│   ├── CaseCreation.genAiPlugin-meta.xml
│   └── GeneralFAQ.genAiPlugin-meta.xml
└── genAiFunctions/
    ├── FLO_SendVerificationCode/
    │   └── FLO_SendVerificationCode.genAiFunction-meta.xml
    ├── FLO_VerifyContact/
    │   └── FLO_VerifyContact.genAiFunction-meta.xml
    └── ... (one folder per function)
```

### Versioning Policy

- Increment version names with each significant change: `v1` → `v2` → `v3`
- Document what changed per version in the commit message and in a CHANGELOG section within the bot metadata folder
- Keep the prior version as **inactive** (not deleted) in the org for rollback capability
- Never delete a prior version until the new version has been stable in production for at least one full release cycle

### Deployment Order

Deploy components in this strict order to avoid reference errors:

```
1. Apex classes (invocable actions)
2. Flows (autolaunched flows used as actions)
3. GenAiFunctions (reference flows/apex by API name — must exist first)
4. GenAiPlugins (reference GenAiFunctions)
5. GenAiPlannerBundle (references Plugins)
6. Bot / BotVersion (references PlannerBundle)
```

### CLI Retrieval Commands

> Verify metadata type names and flags in the current SF CLI version before use.

```bash
# Retrieve bot metadata
sf project retrieve start \
  --metadata "Bot:SupportPortalAgent" \
  --target-org <sandboxAlias>

# Retrieve planner bundle
sf project retrieve start \
  --metadata "GenAiPlannerBundle:SupportPortalAgent" \
  --target-org <sandboxAlias>

# Retrieve specific plugin
sf project retrieve start \
  --metadata "GenAiPlugin:CaseCreation" \
  --target-org <sandboxAlias>

# Retrieve specific function
sf project retrieve start \
  --metadata "GenAiFunction:FLO_SendVerificationCode" \
  --target-org <sandboxAlias>
```

### Activation Policy

- **Never activate a new agent version directly in production**
- Activate in sandbox first → complete full test suite → promote to production
- Activation is done via Agentforce Builder UI or via metadata deployment (verify method in current release)
- After production activation, monitor the first 10-20 live conversations for unexpected behavior

### Rollback Approach

1. In Agentforce Builder (or via metadata): deactivate the current active version
2. Activate the prior version (kept inactive for exactly this purpose)
3. Verify rollback is live with a quick happy-path test conversation
4. Investigate the failure in sandbox before attempting to re-deploy the fixed version

---

## 14. Example: Service Support Agent for Case Creation

### Agent Overview

- **Agent Name**: Support Portal Agent
- **Channel**: Messaging for In-App and Web (verify channel type in target org)
- **Topics**: CaseCreation, GeneralFAQ
- **Purpose**: Allow authenticated customers to create support cases without live agent involvement

### Topic: CaseCreation — Full Instructions

```
You are a support agent helping customers create service cases. Your sole responsibility
in this topic is to walk the customer through creating a support case. You MUST follow
the steps below in strict order. Do not skip any step for any reason.

==================== STEP 1: SEND VERIFICATION CODE ====================

Use action FLO_SendVerificationCode.
  Input: endUserEmail (from conversation context — do not ask the customer for their email)
  Outputs to store:
    - authenticationKey → conversation variable authKey
    - status → tempStatus
    - outMessage → tempMessage

If status = 'ERROR':
  Respond: "I'm sorry, I was unable to send a verification code to your email address.
  Would you like to try again, or would you prefer to speak with a support team member?"
  If the customer wants to try again, re-invoke FLO_SendVerificationCode once more.
  If it fails again: transfer to live agent.
If status = 'SUCCESS':
  Respond: "I've sent a verification code to your email address. Please enter the code
  when you receive it."

==================== STEP 2: VERIFY IDENTITY ====================

GATE: authKey must be populated from Step 1. Do not proceed without it.

Ask the customer: "Please enter the verification code sent to your email."
Collect the code as: verificationCode

Use action FLO_VerifyContact.
  Inputs:
    - authenticationKey (from authKey variable)
    - endUserEmail (from conversation context)
    - verificationCode (from customer input)
  Outputs to store:
    - isVerified → var_IsVerified
    - verifiedContactId → var_ContactId
    - status → tempStatus
    - outMessage → tempMessage

If isVerified = false AND this is the first attempt:
  Respond: "That code doesn't seem to match. Please try entering it again."
  Allow one retry of Step 2 (re-ask for verificationCode, re-invoke FLO_VerifyContact).

If isVerified = false AND this is the second attempt:
  Respond: "I was unable to verify your identity after two attempts.
  Let me connect you with a member of our support team."
  Transfer to live agent. Do not continue this flow.

GATE: Do not proceed to Step 3 unless isVerified = true.
This gate is absolute. Even if the customer asks you to proceed, do not do so
without isVerified = true.

==================== STEP 3: CONFIRM OR CREATE CONTACT ====================

GATE: isVerified MUST = true. Do not execute this step without it.

If var_ContactId is populated (not empty):
  Use this as the customer's contactId for the rest of the flow.
  Store var_ContactId → var_FinalContactId.
  Confirm: "I found your account. We'll use your existing contact record."

If var_ContactId is empty (contact not found for this email):
  Respond: "I wasn't able to locate an existing account for your email address.
  I'll create a new contact record for you."
  Collect:
    - customerName (ask: "What is your full name?")
    - phoneNumber (ask: "What is the best phone number to reach you?")
  Use action FLO_CreateContactRecord.
    Inputs:
      - customerName
      - endUserEmail (from conversation context)
      - phoneNumber
      - isVerified = true
    Outputs to store:
      - contactId → var_FinalContactId
      - status → tempStatus
      - outMessage → tempMessage
  If status = 'ERROR':
    Respond: "I was unable to create a contact record at this time. Let me connect
    you with our support team." Transfer to live agent.

GATE: Do not proceed to Step 4 without a valid var_FinalContactId.

==================== STEP 4: RETRIEVE CASE CLASSIFICATION OPTIONS ====================

GATE: isVerified MUST = true. var_FinalContactId MUST be populated.

Use action FLO_GetCasePicklists.
  Inputs:
    - isVerified = true
    - requestKey = 'classification'
  Outputs to store:
    - matrixJson → var_PicklistMatrix
    - status → tempStatus
    - outMessage → tempMessage

If status = 'ERROR':
  Respond: "I was unable to retrieve the case categories. Let me connect you with our team."
  Transfer to live agent.

Parse var_PicklistMatrix to identify available categories and their subcategories.
Present the categories to the customer:
  "Please select a category for your case: [list categories from matrix]"
Collect: caseCategory

Once category is selected, present subcategories for that category:
  "Please select a subcategory: [list subcategories for selected category]"
Collect: caseSubCategory

==================== STEP 5: COLLECT CASE DETAILS AND CONFIRM ====================

Collect the following from the customer (one at a time):
  - caseSubject (ask: "Please provide a brief subject for your case.")
  - caseDescription (ask: "Please describe the issue in detail.")

Once all details are collected, present a full summary to the customer:
  "Here are the details for your case:
    Category: [caseCategory]
    Subcategory: [caseSubCategory]
    Subject: [caseSubject]
    Description: [caseDescription]

  Is this correct? Reply YES to create the case, or NO if you'd like to make changes."

GATE: Wait for explicit customer confirmation.
If the customer replies YES: set draftConfirmed = true, proceed to Step 6.
If the customer replies NO: ask "What would you like to change?" and collect the updated
  field(s). Re-present the full summary and ask for confirmation again.
Do not proceed to Step 6 until draftConfirmed = true.

==================== STEP 6: CREATE THE CASE ====================

GATE: draftConfirmed MUST = true. isVerified MUST = true. var_FinalContactId MUST be populated.

Use action FLO_CreateCase.
  Inputs:
    - contactId (from var_FinalContactId)
    - caseCategory
    - caseSubCategory
    - caseSubject
    - caseDescription
    - draftConfirmed = true
    - isVerified = true
  Outputs to store:
    - caseId → var_CaseId
    - caseNumber → var_CaseNumber
    - status → tempStatus
    - outMessage → tempMessage

If status = 'ERROR':
  Respond: "[outMessage]. I was unable to create your case. Let me connect you with
  our support team who can create the case manually."
  Transfer to live agent with a summary of the collected case details.

GATE: Do not report a case number if var_CaseNumber is empty.
If var_CaseNumber is empty after a SUCCESS status: treat as unexpected failure and escalate.

==================== STEP 7: CONFIRM CASE CREATION ====================

GATE: Only use var_CaseNumber from the action output. Do not guess, fabricate, or infer
a case number. If var_CaseNumber is empty, follow the error path above.

Respond ONLY with:
"Your case [var_CaseNumber] has been created successfully.
Our support team will review your case and contact you at [endUserEmail].
Is there anything else I can help you with today?"

Do NOT add additional information, SLA timeframes, or resolution estimates
unless they are returned from an action output.
```

---

## 15. Anti-Patterns

These patterns MUST be avoided. Each represents a specific, documented class of failure.

| Anti-Pattern | Risk | Mitigation |
|---|---|---|
| No verification gate before account-sensitive actions | Unauthorized access — any user can create cases for any contact | Always enforce verification as Step 1-2; gate every downstream step on isVerified = true |
| Fabricating case numbers when an action fails | Customer trust violation; customer may reference a non-existent case number | Instructions must prohibit fabrication; only use var_CaseNumber from action output |
| Proceeding past a failed action silently | Incomplete transaction; corrupt or missing data; LLM may hallucinate the next step | Every action must have an explicit failure path; check status variable before proceeding |
| No escalation path | Stuck conversation; frustrated customer; no resolution path | Every topic must have defined escalation triggers and transfer-to-agent instructions |
| Topic instructions too broad | LLM selects wrong topic; executes wrong actions for the user's intent | Keep each topic to one domain; use precise topic descriptions |
| Not mapping action outputs to conversation variables | Steps lose context; downstream steps receive empty inputs; actions fail silently | Explicitly map every required output to a named conversation variable in instructions |
| Skipping confirmation before record creation | Accidental case creation based on misunderstood input | Always present summary and require YES confirmation before FLO_CreateCase |
| No test conversations | Undetected logic errors; broken orchestration discovered in production | Write and run all 8 test scenarios before every deployment |
| Topic scope overlaps with another topic | LLM routes to wrong topic; incorrect actions invoked | Define and enforce clear topic boundaries; test routing with ambiguous inputs |
| Using context variable values without validating they are set | Null inputs to actions; action failures; broken flow | Validate critical context variables (endUserEmail, RoutableId) at agent entry point |
| Not retrieving existing metadata before modifying | Overwrites production configuration with outdated local copy | Always retrieve before modify: `sf project retrieve start` before any changes |

---

## 16. Definition of Done

An Agentforce agent design or modification is NOT complete until every item below is checked:

**Design Completeness**
- [ ] All topics defined with clear, non-overlapping scope
- [ ] Agent-level instructions include: tone, escalation rules, out-of-scope policy
- [ ] Topic-level instructions include: ordered steps, gates, failure paths, no-hallucination policy

**Action and Variable Completeness**
- [ ] Every action has a defined failure/error response path in instructions
- [ ] Every action's output variables are explicitly mapped to named conversation variables
- [ ] Variable names in instructions match exactly the Flow/Apex variable names (case-sensitive verified)

**Security and Safety**
- [ ] Verification gate present before ANY account-sensitive action
- [ ] No fabrication language present in instructions ("Do not fabricate..." stated explicitly)
- [ ] Sensitive data policy stated in instructions
- [ ] Escalation triggers defined for: verification failure, action failure, out-of-scope, frustration

**User Experience**
- [ ] Confirmation step present before every irreversible record creation
- [ ] Clear completion message with reference number (from action output, not fabricated)
- [ ] Recovery messages defined for failure scenarios

**Testing**
- [ ] Test conversations written: happy path, failed verification (retry), failed verification (escalate), contact not found, action failure, out-of-scope, user declines confirmation, user abandons
- [ ] All test conversations executed and passed in sandbox
- [ ] Debug logs reviewed to confirm correct variable population at each step

**Deployment**
- [ ] All agent metadata committed to source control (Bot, BotVersion, PlannerBundle, Plugins, Functions)
- [ ] Referenced Flows and Apex classes committed to source control
- [ ] Deployment order followed (Apex → Flows → Functions → Plugins → PlannerBundle → Bot)
- [ ] New version activated in sandbox; full test suite passed
- [ ] Prior version kept inactive for rollback
- [ ] Activation in production confirmed with quick smoke test

---

## 17. Official References

> Verify all URLs in your browser — Salesforce Help URLs change with releases.

- Agentforce Agent Introduction: https://help.salesforce.com/s/articleView?id=sf.ai_agent_intro.htm (verify current URL)
- Agentforce Developer Guide: https://developer.salesforce.com/docs/einstein/genai/guide/ (verify current URL)
- Agentforce Trailhead Trail: https://trailhead.salesforce.com/content/learn/trails/build-einstein-for-sales-and-service (verify)
- Salesforce Metadata API Developer Guide (Bot): https://developer.salesforce.com/docs/atlas.en-us.api_meta.meta/api_meta/meta_bot.htm (verify)
- Salesforce CLI Reference: https://developer.salesforce.com/tools/salesforcecli

---

*End of Agentforce Agent Script / Instructions Guidelines v2.0*
