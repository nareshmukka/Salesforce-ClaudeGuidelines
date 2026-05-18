# Service Assistant on Case — Plusgrade Implementation Guide

> Org-specific reference for the **Agentforce Service Assistant on Case** pattern at Plusgrade and the two server-invoked Agentforce agents that feed the same Case UI (Email Resend / Email Analysis). Verified against the FullSB org, 2026-05-16.

This file documents what is **unique to this org**. For general Agentforce DSL syntax, lifecycle commands, builder/source parity, or bot-meta override, link to the canonical skill files — do not duplicate.

| Topic | Canonical file |
|---|---|
| Agent Script DSL grammar, action types, transitions, anti-patterns | [agentforce-agent-script-reference.md](agentforce-agent-script-reference.md) |
| Topic instruction authoring, sectioning, guardrails phrasing | [agentforce_script_guidelines.md](agentforce_script_guidelines.md) |
| Generate / Validate / Deploy / Publish / Activate lifecycle, publish-then-override | [agentforce_authoring_bundle_guide.md](agentforce_authoring_bundle_guide.md) |
| Builder UI ↔ DSL parity, ServicePlanner bot metadata, permission personas | [agentforce_builder_guidelines.md](agentforce_builder_guidelines.md) |

---

## 1. Two Distinct Things — Don't Conflate

This org has **two unrelated implementations** that both live "on the Case record":

| Pattern | What it is | Agent type | UI surface |
|---|---|---|---|
| **Service Assistant on Case** | Salesforce's `ServicePlanner` feature — generates Case summary + step-by-step service plan with inline Quick Action buttons | `agentType=ServicePlanner` (Builder-only, no `.agent` DSL) | Standard Service Assistant Lightning component |
| **Email Resend / Analysis** | Server-invoked `AgentforceEmployeeAgent` (Apex calls `generateAiAgentResponse`) — analyzes inbound emails, drafts reply emails, triggers SFMC callouts | `AgentforceEmployeeAgent` (script-version `.agent` DSL) | Custom LWC `caseResendEmailConfirmationTable` |

Both are scoped to the Case object. Both ship to FullSB. They share **no** Apex, **no** topics, and **no** bot. Always state which one before discussing.

---

## 2. Service Assistant on Case (ServicePlanner agent)

### 2.1 What it is and isn't

An assistive Agentforce agent embedded on the Case record page that generates a **case summary** and a **service plan** (numbered steps with inline Quick Action buttons) for the rep to execute manually.

**Is NOT:** customer-facing chat, autonomous executor, Field Service Work Plans, or buildable with the `.agent` DSL.

### 2.2 Mandatory agent metadata

| Property | Value |
|---|---|
| `agentType` | `ServicePlanner` |
| `agentTemplate` | `service_planner_agent__ServicePlanner` |
| `<type>` (legacy flag) | `InternalCopilot` |
| `agentDSLEnabled` | `false` — **Builder mode only; `.agent` script is not supported for ServicePlanner** |
| `plannerType` (in GenAiPlannerBundle) | `AiCopilot__ReAct` |
| API version | 66.0 or higher (`agentDSLEnabled` invalid in 62.0) |

### 2.3 ServicePlanner uses inline `<localTopics>`, not `<genAiPlugins>`

This is the single biggest divergence from EmployeeAgent metadata layout:

```
GenAiPlannerBundle (Agentforce_Service_Assistant)
├── plannerType = AiCopilot__ReAct
├── localActionLinks (Knowledge action)
├── localTopicLinks × N (one per subagent)
├── localTopics × N (INLINE subagent definitions)
│     └── localActions × M (inline GenAiFunction wrappers)
└── plannerActions (Knowledge standard action)

+ on disk: localActions/<Topic>/<Function>/{input,output}/schema.json
  files for EVERY inline action — missing files = generic
  "An unexpected error occurred" on deploy.
```

EmployeeAgent agents (e.g. `Email_Analysis_Agent`) use `<genAiPlugins>` references and live as `.agent` files. Do not copy that pattern into a ServicePlanner bundle.

Reference: `Inbound_Email_Analysis_Agent` planner bundle in this repo.

### 2.4 Permission personas — three users, three sets

| Persona | User License | Required PSes |
|---|---|---|
| **Admin (Naresh)** | Salesforce | `Service Planner Builder` + `Agentforce Default Admin` + `Customize Application` |
| **Service Rep (demo user)** | Salesforce | `Service Planner User` (gates component visibility) + `Access Agentforce Default Agent` + a custom PS for Case access (e.g. `PS_ServiceAssistantDemo`) |
| **ServicePlanner Bot User** | Einstein Agent | `Agentforce_<AgentName>_Permissions` (auto) + `Service Planner Agent User` (auto) + **`Data Cloud User`** (must be assigned manually) |

The bot user is a separate auto-created user (`agentforce_service_assistant@<orgid>.ext`). Plans run under **its** permissions, not the rep's.

**The single most common diagnosis miss:** the component shows "Service Assistant agent was deactivated" even when the bot is active. Cause is almost always a missing PS on the rep OR on the bot user. Verify PS assignments on **both** users before debugging activation.

### 2.5 Setup sequence (correct order)

1. Einstein Setup → Turn On Einstein (Generative AI)
2. Agentforce Agents → Turn On Agentforce
3. Agentforce Builder (legacy) → Create Agent → `Agentforce Service Assistant` template
4. Create at least one subagent with full instructions **before** activating (empty agents fail to activate)
5. Service AI Grounding → Object: Case + Required: Subject, Description + Additional: Status, Priority, Origin, Type, AccountId, ContactId
6. Build + activate the eligibility flow (see §2.6)
7. Service Assistant → Step 4 (Customize by Object) → Case tab → Add Eligibility Criteria + map `caseId`/`meetsEligibility`/`ineligibilityReason`
8. Service Assistant → Turn on Service Assistant for Cases = ON
9. Lightning App Builder → Case record page → drag in Service Assistant component → activate as Org Default + App Default
10. Quick Actions Manager → add each QA → bind to subagents → write one-line instruction per QA
11. Data Library → connect to Knowledge with filter + content fields
12. Activate the agent in the Builder. The "configuration error about permissions" warning is expected — click **Ignore and Activate**.
13. Assign permission sets to rep, bot user, admin (§2.4)

### 2.6 Eligibility flow contract

| Property | Value |
|---|---|
| `processType` | `AutoLaunchedFlow` |
| `runInMode` | `DefaultMode` |
| Inputs | `caseId` (Id, available for input) |
| Outputs | `meetsEligibility` (Boolean), `ineligibilityReason` (String) |
| Status | Must be `Active` (no service plan without it) |

Start from the Salesforce-provided `Check Service Plan Eligibility` template, or build a custom autolaunched flow with the same contract.

### 2.7 Service AI Grounding — the mandatory layer

Without Service AI Grounding configured, the agent has no Case context — plans will be generic or fail with "provide a summary" prompts.

- Setup → Service AI Grounding → ON → Object: **Case**
- **Required Fields:** Subject, Description
- **Additional Fields:** Status, Priority, Origin, Type, RecordType, AccountId, ContactId, OwnerId
- **Additional Object Grounding** (recommended): Case Emails, Case Comments, Case Feed

Limitations (per Salesforce docs):
- Only `String` / `Text Area` field types
- Encrypted fields not supported
- Only text content of emails/comments/feed (no PDFs or images)
- Only the active Case (no historical learning)
- Plans run under **bot-user permissions**, not the rep's

Don't duplicate Service AI Grounding with custom `Get_Record_Context` inline actions unless you need richer JSON (related records, opportunity context).

### 2.8 Subagent (topic) naming convention

April 2026 rename: "topics" are now called **subagents**. Metadata still uses `<localTopics>` / `<genAiPlugins>`.

| Field | Pattern | Example |
|---|---|---|
| Subagent developerName | `<Topic_Snake_Case>_<AgentSuffix>` (globally unique) | `Customer_Refund_Request_SrvAst` |
| localDeveloperName | short clean name without suffix | `Customer_Refund_Request` |
| masterLabel | human-friendly title case | `Customer Refund Request` |
| Inline localActions function | `<FunctionName>_<TopicAbbrev>_<AgentSuffix>` | `Get_Record_Context_CRR_SA` |
| `plannerActions.developerName` | **globally unique across the org** — suffix with `_SrvAst` | `Knowledge_Search_SrvAst` |

For instruction-authoring rules (one task per instruction, guardrails at `sortOrder=1`, utterance counts, etc.) see [agentforce_script_guidelines.md](agentforce_script_guidelines.md).

### 2.9 Quick Actions in plan steps — Plusgrade-specific bindings

Service plans render Quick Action buttons inline. Each QA needs five setup steps:

1. Must exist as a Case Quick Action (object metadata)
2. Must be on the Case page layout (Mobile & Lightning Actions)
3. Must be added to **Service Assistant Quick Actions Manager** (UI)
4. Must be **bound to one or more subagents** in the manager
5. Must have an **instructions text** explaining when to surface it

**Critical:** Quick Action Manager bindings reset when a subagent developerName changes. Plan to re-bind every QA after a rename.

**Use these existing org QAs — do not build custom `QA_*` flows:**

| QA | Type | Use case |
|---|---|---|
| `Send_Email_CSR` | SendEmail | Customer-facing email (CSR_Record cases) |
| `Send_Email_PSC` | SendEmail | Partner-facing email (PSC_Record cases) |
| `Email_AmexGBT` | SendEmail | AmexGBT-specific |
| `Move_to_Second_Line_Queue` | Update | Refunds team / partner reconciliation |
| `Move_to_Dev` | Update | Dev/engineering investigation |
| `Escalate` / `Escalate_to_Second_Line_of_Defense` | Update | General escalation / tier-2 |
| `Close_CSR_Case` / `Close_PSC_Case` / `Close_HRG_Case` / `Close_Refunds_Case` | Update | Record-type-specific closure |
| `Log_a_Call` | LogACall | Call documentation |
| `Remind_Me` | LightningWebComponent | Personal reminder |
| `NewChildCase` | Create | Spawn sub-cases for parallel workstreams |

Reference QAs in topic instructions by **display name** ("Send Email CSR") — never by API name ("`Case.Send_Email_CSR`"). API names leak into rep-facing plan text.

### 2.10 Data Library (Knowledge) — Plusgrade-specific config

Plusgrade Knowledge object is `Knowledge__kav`:

| Use | Field / Filter |
|---|---|
| Filter — published English only | `PublishStatus = 'Online'`, `Language = 'en_US'`, `IsLatestVersion = true` |
| Filter — exclude empty / DEMO | `Summary != null` AND `NOT Title LIKE 'DEMO:%'` |
| Identifying field | `Title` |
| Content field (lightweight) | `Summary` — backfill if null (see below) |
| Content field (thorough) | `Article_Body__c` (RichText, up to 131K chars) |

**Empirical org fact:** in this org, all 22 published `[SBU]` and `[GC]` articles had `Summary = null` initially. Backfilled via `scripts/apex/backfill-knowledge-summary.apex` (strip HTML from `Article_Body__c`, take first 500 chars, update Summary, republish). Articles with empty `Article_Body__c` (Delta Choice Code Inquiry, Gift Card Inquiry) were skipped.

### 2.11 Org-specific values — do not invent

**Case status values:**
`New`, `In Progress`, `New Email Received`, `Pending Internal`, `On Hold`, `Waiting - Partner/Customer`, `Waiting - Customer`, `Awaiting Customer Response`, `Escalated`, `Second Line Escalated`, `TKO Escalated`, `Supplier Escalated`, `Product Escalated`, `Resolved`, `Completed`, `Closed`, `Closed Lost`, `Reopened`, `Rejected`

**Case RecordTypes:**
`CSR_Record`, `PSC_Record`, `Refunds_Record`, `HRG_Record`, `HRG_CS_Record`, `HUBU_GC`, `SBU_GC`, `Solutions_Hospitality`, `Bug_Problem_Record`, `Monitoring_Alert_Record`, `Magento_Record`, `Nexus_Hub_Ticket`

**Partner origins:**
`PSC_Email`, `Delta_Phone`, `Delta_Email`, `United_Email`, `AIRMILES_Phone`, `Refunds_Email`, `PointsTravel_Email`, `Solutions Hospitality - Email`, `Chase_Support`, `PSC_Slack`, `PDC_Email`, `Experience Cloud Site`

**Deployed demo subagent map (FullSB):**

| Subagent | Real case patterns |
|---|---|
| `Customer_Refund_Request_SrvAst` | Miles/points refund (CSR — United, Delta, AIRMILES) |
| `Missing_Credit_Or_Posting_SrvAst` | Retro credit, miles not posted |
| `Partner_Transaction_Error_SrvAst` | Wyndham/Virgin/IAG/Delta transaction errors, MV failures |
| `Subscription_Or_Access_Issue_SrvAst` | Points.com password/login |
| `Production_Alert_Or_Monitoring_SrvAst` | Splunk alerts, IAG operational status |
| `General_Case_Triage_SrvAst` | Fallback |

### 2.12 Deployment notes

For full lifecycle commands (generate, validate, deploy, publish, activate, retrieve) see [agentforce_authoring_bundle_guide.md](agentforce_authoring_bundle_guide.md). ServicePlanner-specific deltas:

- **Deactivate before deploy.** Salesforce blocks Bot/BotVersion/GenAiPlannerBundle updates on active agents (`Cannot update record as Agent is Active`).
- **Iterate with minimal manifests.** Deploy only the file you changed (e.g. just `GenAiPlannerBundle:Agentforce_Service_Assistant`). Avoid `manifest/package-service-assistant.xml` when stale local files could overwrite live UI configurations.
- **localActions schema files are mandatory.** Every inline `<localActions>` block requires `localActions/<TopicName>/<FunctionName>/{input,output}/schema.json`. Missing files → generic `An unexpected error occurred` on deploy.
- **Bot version cleanup.** Deploys can leave inactive `v2` versions — delete in the Builder.

---

## 3. Email Resend / Analysis — Server-Invoked EmployeeAgents

A different pattern entirely. Apex calls `Invocable.Action.createCustomAction('generateAiAgentResponse', agentApiName)` from server-side code; the agent returns either structured JSON (trigger path) or plain-text email body (UI path). No Service Assistant component involved.

### 3.1 Current parallel-run state (2026-05-16)

| Agent | API Name | Type | Status | Caller |
|---|---|---|---|---|
| Email Resend Agent | `Email_Resend_Agent` | `AgentforceEmployeeAgent` | **Production** (v15 active) | Trigger path + LWC path via `ResendConfiguration.agentApiName` |
| Email Analysis Agent | `Email_Analysis_Agent` | `AgentforceEmployeeAgent` (script-version `.agent` DSL) | **Deployed dark** | Only `EmailResendAgentTestInvoker` with explicit override |

`Email_Analysis_Agent` is a clean rebuild of `Email_Resend_Agent` v15. Same functional contract; new internals (constitution-style `system.instructions`, thin router + two subagents, deterministic state-flag gating, strict-format Apex normalizer). It coexists with v15 — `ResendConfiguration.agentApiName = 'Email_Resend_Agent'` is **not flipped** in the deploy. Cutover is bundled with the 4-account CMDT gating (§3.7) in a later `/sf-lead` session.

**Parallel-run rule:** When rebuilding an Agentforce agent rather than fixing it in place, ship the new agent in parallel with the old one. Decouple the structural rebuild from the caller cutover. The caller cutover is then a one-line revertable commit. See L11 in [`docs/Email_Resend_Use_Case_Full_Requirement.md`](../docs/Email_Resend_Use_Case_Full_Requirement.md).

### 3.2 Two-mode contract (preserved across both agents)

Mode is detected from the user message text in STEP 0 — no `sessionVariables`, no external parameters.

| Mode | Detection | Output |
|---|---|---|
| **STRUCTURED_ANALYSIS** | Default | JSON: `summary`, `category`, `intent`, `confirmationNumber`, `newEmailAddress`, `confidence` |
| **EMAIL_TEMPLATE** | Message contains "Use the email template named" | Plain-text email body (no JSON wrapper) |

**ID injection contract:** `caseId` and `emailMessageId` are embedded in the user message text as `caseId=<value> and emailMessageId=<value>`. The agent extracts via LLM reasoning and slot-fills the action inputs.

> This is the only reliable mechanism. `generateAiAgentResponse` accepts a `sessionVariables` parameter but silently ignores it — see Lesson L1 in [`docs/Email_Resend_Use_Case_Full_Requirement.md`](../docs/Email_Resend_Use_Case_Full_Requirement.md).

### 3.3 Canonical confirmation-code format (2026-05-15)

| Item | Spec |
|---|---|
| Canonical form | `xxxx-xxxx-xxxx-xxxx-xxxx` — 5 groups of 4 uppercase alphanumeric, hyphen-separated |
| Accepted input variants | hyphenated, unhyphenated 20-char, space-separated |
| `ResendConfiguration.confirmationNumberRegex` | `(?i)(?:confirmation\s*(?:number\|#\|code)?\s*[:\-]?\s*)?([A-Z0-9]{4}(?:[\s-]?[A-Z0-9]{4}){4})\b` |
| `ResendIntentRulesEngine.normalizeConfirmationNumber()` | strip non-alphanumeric → uppercase → require length 20 → strict `[A-Z0-9]{20}` alphabet check → re-insert hyphens → return canonical form OR `null` |
| New decision code | `INVALID_CONFIRMATION_FORMAT` — emitted when a non-blank candidate fails normalization (distinct from `NEED_CONFIRMATION` which means nothing was found) |

### 3.4 Apex classes (deployed, this feature)

| Class | Role |
|---|---|
| `EmailMessageTriggerHandler` | Inbound filter, dedup guard, enqueues async |
| `InboundEmailProcessingQueueable` | Async wrapper allowing HTTP callouts |
| `InboundEmailOrchestrator` | End-to-end trigger-path orchestration (`without sharing`) |
| `AgentIntegrationService` | `invokeAgent()` for JSON path; `invokeAgentForText()` for Text-envelope path; `buildRequestJson()` for message-text ID injection; `@TestVisible` mock injection |
| `ResendConfiguration` | Centralized config — `agentApiName`, `supportedInboundAddressRegex`, `confirmationNumberRegex`, SFMC endpoints |
| `ResendIntentRulesEngine` | Deterministic decision logic — `decide()`, `normalizeConfirmationNumber()`, `parseConfirmationNumber()` |
| `SfmcResendService` | SFMC HTTP callouts (`with sharing`) |
| `SfmcCalloutQueueable` | Second async layer — separates DML from callout |
| `CaseEmailWorkspaceController` | LWC controller — `getResendContext`, `sendAll`, `draftConfirmationRequest`, `redraftBody`, `sendConfirmationRequest`, `submitFeedback`, `submitSuggestion` |
| `GetEmailResendContextAction` | Agent action target (Apex `@InvocableMethod`) — returns Case + EmailMessage + up to 10 history items in one call |
| `GetEmailTemplateAction` | Agent action target — retrieves template by DeveloperName, strips HTML, returns `body` + `subject` + `errorMessage` |
| `ResendUtils` | Shared utilities |
| `EmailResendAgentTestInvoker` | Anonymous Apex harness — `AGENT_API_NAME_ANALYSIS = 'Email_Analysis_Agent'` constant + `agentApiName` overloads on all public methods (default → `Email_Resend_Agent`) |

### 3.5 Agent action targets

| Action | Target | Purpose |
|---|---|---|
| `Get_Email_Resend_Context` | `apex://GetEmailResendContextAction` | Unified case + email + history (replaced two old actions) |
| `Get_Email_Template` | `apex://GetEmailTemplateAction` | EMAIL_TEMPLATE mode only |
| `Get_Image_Confirmation` | `flow://Get_Email_Image_Confirmation` | Multimodal OCR for image attachments — flow targeted directly, no GenAiFunction wrapper |

**Flow target rule:** `target: "flow://Flow_Api_Name"` works directly. No `<genAiPlugins>` wrapper required (L3 in `Email_Resend_Use_Case_Full_Requirement.md`).

### 3.6 Flow `Get_Email_Image_Confirmation` — known traps

This flow calls a Flex Prompt Template via `generatePromptResponse`. Two traps documented as lessons in `Email_Resend_Use_Case_Full_Requirement.md`:

- **L7:** Output variables `extractedConfirmationNumber` / `extractedEmailAddress` are declared `isOutput: true` but the `Set_Extracted_Values` Assignment only writes `outMessage`. **Fix:** parsing was moved out of the flow — the agent LLM parses `outMessage` directly and the dead outputs are not declared on the new agent.
- **L8:** The `Set_Prompt_Input` text must describe the actual format. The current (2026-05-15) text describes the canonical `xxxx-xxxx-xxxx-xxxx-xxxx` form. A wrong format description causes silent null results with no error.

### 3.7 4-account CMDT gating (PENDING — bundled with cutover)

Deferred to a later `/sf-lead` session per `email-analysis-agent-state.md`. Scope when it lands:

- New CMDT: `Resend_Feature_Account__mdt` (4 pilot account rows)
- New Apex: `ResendFeatureGate.cls`
- `SfmcResendService` last-line gate that short-circuits non-pilot accounts
- LWC button gating on `caseResendEmailConfirmationTable`
- LWC tooltip differentiation for `INVALID_CONFIRMATION_FORMAT` vs `NEED_CONFIRMATION`
- **Same delivery flips** `ResendConfiguration.agentApiName` from `'Email_Resend_Agent'` to `'Email_Analysis_Agent'` (the cutover)

Do **not** flip `agentApiName` proactively in any session. Wait for Naresh to explicitly approve the cutover. Rollback before cutover = revert that single commit.

---

## 4. LWC `caseResendEmailConfirmationTable`

| Item | Value |
|---|---|
| Folder | `force-app/main/default/lwc/caseResendEmailConfirmationTable/` |
| Target | `lightning__RecordPage` → Case object |
| API version | 66.0 |
| Apex controller | `CaseEmailWorkspaceController` (see §3.4) |

### 4.1 Two tabs (Agent Chat tab removed)

| Tab | Purpose |
|---|---|
| **Case Summary** | Displays AI-generated summary with expandable sections — Issue reported / Suspected cause / Current status / Customer sentiment / Key issues / Timeline of key issues |
| **Email Resend Agent** | Action buttons for resend operations and confirmation-request drafting |

The previously planned Agent Chat tab (`invokeAgentChat`) was removed and is not part of the deployed UI.

### 4.2 Email Resend Agent tab — buttons

| Button | Action | Enable condition |
|---|---|---|
| Request Confirmation Code | Modal → Agent drafts via EMAIL_TEMPLATE mode → rep reviews/edits → sends | NO confirmation code on Case |
| Launch Email Resend Agent | Opens SFMC CloudPage in iframe modal | CloudPage URL AND confirmation code both exist |
| Resend Confirmation Email | `sendAll()` → SFMC `POST /GCEmailSends` | Confirmation code exists, not in cooldown |
| Send to New Address | Checkbox + email input → `sendAll()` → SFMC `POST /GCEmailSends-To-Newemail` | Confirmation code + valid new email |

### 4.3 Six-label summary parser contract

The LWC parses `context.summary` by looking for these exact strings (colon included, case-sensitive): `Issue reported:`, `Suspected cause:`, `Current status:`, `Customer sentiment:`, `Key issues:`, `Timeline of key issues:`.

Everything before the first label is shown as the intro paragraph; everything after is shown as expandable sections.

**This is the single biggest hidden coupling in the system.** Any change to either agent's STEP 4 (Compose Summary) instruction MUST keep these six labels verbatim. Slash-separated or comma-separated label lists in the instruction get interpreted as concepts, not literal output — L9 in `Email_Resend_Use_Case_Full_Requirement.md`.

### 4.4 Cooldown

15-minute cooldown per action type, tracked via `Agent_Activity_Log__c` records where `Action_Name__c IN ('Resend_Default', 'Resend_New_Email')` AND `Status__c = 'Success'`. Timer refreshes every 30 seconds in the UI.

### 4.5 Confirmation-request modal flow

1. Rep clicks "Request Confirmation Code"
2. Modal opens with loading animation ("Agentforce is drafting your email")
3. `draftConfirmationRequest()` builds the prompt: `caseId=<id> and emailMessageId=<id>` + `"Use the email template named Resend_Confirmation_Request"`
4. Calls `AgentIntegrationService.invokeAgentForText(agentApiName, prompt)` (Text-envelope path)
5. Agent calls `Get_Email_Resend_Context` → `Get_Email_Template` → analyses sentiment → returns plain-text body
6. `unwrapTextEnvelope()` strips the `{"type":"Text","value":"..."}` Agentforce envelope
7. Editable draft with To/CC/BCC pre-populated from all case email addresses
8. Rep edits, clicks Send → `sendConfirmationRequest()` → `Messaging.SingleEmailMessage`

`redraftBody()` follows the same `invokeAgentForText` path. **Do not** call `invokeAgent()` + `result.summary` for the email body — that was the v15 coincidental path (L2 in `Email_Resend_Use_Case_Full_Requirement.md`).

---

## 5. Bot-Meta Override Pattern (PII Safety)

`Email_Analysis_Agent` processes customer email PII. The Apex `WITH USER_MODE` gap (deferred Blocker #1/#2) is partially compensated by **`logPrivateConversationData=false`** on the Bot.

### 5.1 The trap

`sf agent publish authoring-bundle` retrieves the org's Bot state back into the local repo, **overwriting** the locally-authored `Bot.bot-meta.xml`. Three security-critical fields are stripped on every publish:

- `<logPrivateConversationData>false</logPrivateConversationData>` flipped to `true`
- `<agentTemplate>EmployeeCopilot__AgentforceEmployeeAgent</agentTemplate>` dropped
- The 5 standard `<contextVariables>` dropped

### 5.2 The pattern (publish-then-override)

For full mechanics see [agentforce_authoring_bundle_guide.md §8 / Empirical Finding #7](agentforce_authoring_bundle_guide.md). Plusgrade-specific manifest:

- **Override manifest:** `manifest/package-email-analysis-bot-override.xml` — single-type `Bot` manifest with member `Email_Analysis_Agent`
- **Order of operations after every publish:**
  1. `sf agent publish authoring-bundle --json --api-name Email_Analysis_Agent`
  2. `sf project retrieve start --metadata Bot:Email_Analysis_Agent` (to get planner-bundle ID populated)
  3. Edit `Email_Analysis_Agent.bot-meta.xml` to restore the three security fields
  4. `sf project deploy start --manifest manifest/package-email-analysis-bot-override.xml`
  5. Verify: `grep logPrivateConversationData force-app/main/default/bots/Email_Analysis_Agent/Email_Analysis_Agent.bot-meta.xml`

### 5.3 Three-control PII alignment

For any EmployeeAgent processing PII, all three must align (anti-pattern #9 in `agentforce_authoring_bundle_guide.md`):

1. `<logPrivateConversationData>false</logPrivateConversationData>` re-asserted via override manifest after every publish
2. Every backing-logic SOQL uses `WITH USER_MODE` (gap: deferred Blocker #1/#2 on `GetEmailResendContextAction` + `GetEmailTemplateAction`)
3. `system.instructions` includes an explicit PII redaction policy (✓ present in `Email_Analysis_Agent.agent` — DATA PRIVACY section)

---

## 6. End-to-End Trigger Path Summary

For the full reference see [`docs/Email_Resend_Use_Case_Full_Requirement.md`](../docs/Email_Resend_Use_Case_Full_Requirement.md). One-line summary of each scenario:

| Scenario | Decision Code | SFMC call |
|---|---|---|
| Customer email WITH confirmation number | `RESEND_STANDARD` | GET `/GCViewProcess` + UI POST `/GCEmailSends` |
| Customer email WITHOUT confirmation number | `NEED_CONFIRMATION` | none — `draftConfirmationRequest` modal |
| Resend to different email | `RESEND_NEW_EMAIL` | GET `/GCViewProcess` + UI POST `/GCEmailSends-To-Newemail` |
| Not a resend request | `NOT_RESEND` | none — summary only |
| Refund request | `REFUND_REQUEST` | none — manual review |
| Thanks / closing email | `NO_ACTION_CLOSED` | none — case auto-closed when confidence ≥ 0.7 AND inbound email count == 1 |
| Confirmation candidate present but malformed | `INVALID_CONFIRMATION_FORMAT` | none — surfaces in `Agent_Activity_Log__c.Decision_Code__c`; LWC tooltip pending (§3.7) |

All paths insert `Agent_Activity_Log__c` rows for invocation + callout outcomes. Inserts use `Database.insert(log, false)` (partial success — logging never blocks business logic).

---

## 7. Common AI Mistakes to Avoid

| # | Mistake (brief) | Correct approach |
|---|---|---|
| 1 | Mixing Service Assistant ServicePlanner and EmployeeAgent metadata patterns in the same bundle | ServicePlanner uses inline `<localTopics>`; EmployeeAgent uses `<genAiPlugins>` references and `.agent` DSL. Never copy one into the other. |
| 2 | Building Service Assistant with the `.agent` DSL | ServicePlanner agents are Builder-only. `agentDSLEnabled=false`. Use the legacy Agentforce Builder. |
| 3 | Service Assistant component shows "agent was deactivated" — assuming the agent is the problem | Almost always a permission set on rep or bot user. Verify `Service Planner User` on rep, `Data Cloud User` on bot user before touching the agent. |
| 4 | Deploying a ServicePlanner bundle without `localActions/<Topic>/<Function>/{input,output}/schema.json` files | Every inline `<localActions>` block requires schema files. Missing → generic "An unexpected error occurred". |
| 5 | Referencing Quick Actions by API name in topic instructions (`Case.Send_Email_CSR`) | Use display name only ("Send Email CSR"). API names leak into rep-facing plan text. |
| 6 | Writing instruction lines like "Use the Get Record Context action" | Service Assistant invokes grounding actions automatically. Such phrasing leaks into rep text — describe the WORK, not the back-end mechanic. |
| 7 | Passing `caseId` / `emailMessageId` via `generateAiAgentResponse`'s `sessionVariables` parameter | `sessionVariables` is silently ignored. Embed in user message text as `caseId=<value> and emailMessageId=<value>` (L1). |
| 8 | Using `invokeAgent()` + `result.summary` for EMAIL_TEMPLATE mode | Use `invokeAgentForText(agentApiName, prompt)` — the Text-envelope path is the designed one; the `result.summary` path is a coincidence (L2). |
| 9 | Changing the agent's STEP 4 summary instruction to use slash- or comma-separated labels | LWC `caseResendEmailConfirmationTable` parses six exact strings with colons. Slash lists are interpreted as concepts, not literal labels (L9). |
| 10 | Wrapping the `Get_Email_Image_Confirmation` flow in a GenAiFunction | Use `target: "flow://Get_Email_Image_Confirmation"` directly. No wrapper needed (L3). |
| 11 | Flipping `ResendConfiguration.agentApiName` to `Email_Analysis_Agent` proactively | The cutover is bundled with the 4-account CMDT gating in a later /sf-lead session. Wait for Naresh to explicitly approve. |
| 12 | Skipping the bot-meta override deploy after `sf agent publish` | Publish strips `logPrivateConversationData=false` + agentTemplate + contextVariables. Always run `manifest/package-email-analysis-bot-override.xml` after publish. |
| 13 | Renaming a subagent and assuming Quick Action bindings survive | Quick Action Manager bindings reset on developerName change. Plan to re-bind every QA after a rename. |
| 14 | Quoting policy commitments / refund timelines / fix timelines in plan steps unless they appear on the Case or in approved Knowledge | Service Assistant must ground every commitment in available data; ungrounded policy claims must not appear in plan text. |
| 15 | Assuming `plannerActions.developerName` only needs to be unique per bundle | Every `<plannerActions>` `developerName` must be **globally unique across the org**. Suffix with `_SrvAst` to disambiguate. |

---

## 8. Empirical Findings & Implementation Notes

Project-specific notes where Salesforce's documented approach was incomplete or wrong for this org/version/feature combination. Date-stamp every entry.

| # | Date | Documented approach | What actually works | Why / Context |
|---|---|---|---|---|
| 1 | 2026-05-08 | License-by-name in `PermissionSet.license` is required for Einstein/Agentforce PSes | Use `<license>Einstein Agent</license>` exactly (space included). Even more reliable: omit `<license>` entirely — license-agnostic PS is the safest default. Wrong API name fails deploy with `License doesn't exist`. | FullSB org, Spring '26 |
| 2 | 2026-05-08 | `Summary` field on `Knowledge__kav` is populated automatically when articles are created | In this org, all 22 published `[SBU]` and `[GC]` articles had `Summary = null` initially. Data Library "no citations" symptom is a `Summary IS NULL` filter mismatch, not a Knowledge grounding bug. Backfill from `Article_Body__c` (strip HTML, first 500 chars) and republish via `scripts/apex/backfill-knowledge-summary.apex` | FullSB org, Spring '26 |
| 3 | 2026-05-08 | `Case.Reason` is a free-text field that can receive any string | `Case.Reason` is a restricted picklist — writing free text fails with `INVALID_OR_NULL_FOR_RESTRICTED_PICKLIST`. Use `Case.Description` or create a `CaseComment` for free-text agent output | Observed when wiring a Quick Action update from a service plan |
| 4 | 2026-05-15 | `sf agent publish authoring-bundle` uses the locally-authored `Bot.bot-meta.xml` as source of truth | Publish IGNORES local bot-meta and creates the Bot from org-template defaults, then auto-retrieves org state OVERWRITING the local file. Three security-critical fields stripped on every publish: `<logPrivateConversationData>false</logPrivateConversationData>` → `true`; `<agentTemplate>EmployeeCopilot__AgentforceEmployeeAgent</agentTemplate>` dropped; the 5 standard `<contextVariables>` dropped. Workaround: deploy `manifest/package-email-analysis-bot-override.xml` IMMEDIATELY after every publish. See §5.2 | CRITICAL for PII-handling agents — org default `logPrivateConversationData=true` re-introduces logging risk |
| 5 | 2026-05-15 | `sf project deploy start --metadata Bot:<Name>` is the standard way to bootstrap a brand-new agent | Brand-new script-version agents cannot be bootstrapped via `sf project deploy` alone — `BotVersion.PlannerId` is required but the GenAiPlannerBundle doesn't exist until publish runs. Order for a NEW agent is REVERSED from updates: (1) `sf agent publish authoring-bundle` first to create Bot + v1 BotVersion + GenAiPlannerBundle atomically, (2) `sf project retrieve start --metadata Bot:<Name>` to pull the populated XML back into the repo, (3) for existing agents the standard deploy-then-publish order applies | Trying to deploy first fails with `Required fields are missing: [PlannerId]` then `Bot needs at least one Bot version` on retry |
| 6 | 2026-05-15 | `generateAiAgentResponse`'s `sessionVariables` parameter seeds agent script `variables:` block values | `sessionVariables` is silently ignored by the platform. Agent script `variables:` block stays at default empty values. When a deterministic `run` step binds an empty string to a `lightning__recordIdType` input, the runtime substitutes the literal string `<id>` causing `Invalid id: <id>`. Workaround: embed IDs in user message text as `caseId=<value> and emailMessageId=<value>` (L1 in `Email_Resend_Use_Case_Full_Requirement.md`) | Discovered when rebuilding `Email_Resend_Agent` v15 |
| 7 | 2026-05-15 | Flow `<isOutput>true</isOutput>` variables propagate the result of a `generatePromptResponse` element automatically | Output variables stay null unless an Assignment element explicitly writes them. `Get_Email_Image_Confirmation`'s `extractedConfirmationNumber` / `extractedEmailAddress` were declared `isOutput=true` but `Set_Extracted_Values` only set `outMessage` — silent null result with no error. Workaround: declare only `outMessage` on the agent and let the LLM parse it (L7) | Spring '26, FullSB |

---

## 9. References

### Internal — read these first
- [agentforce-agent-script-reference.md](agentforce-agent-script-reference.md) — DSL grammar (the only place to look up syntax)
- [agentforce_script_guidelines.md](agentforce_script_guidelines.md) — topic-instruction authoring rules
- [agentforce_authoring_bundle_guide.md](agentforce_authoring_bundle_guide.md) — lifecycle, publish-then-override, bot-meta gotchas
- [agentforce_builder_guidelines.md](agentforce_builder_guidelines.md) — Builder UI ↔ source parity, ServicePlanner bot metadata
- [`docs/Email_Resend_Use_Case_Full_Requirement.md`](../docs/Email_Resend_Use_Case_Full_Requirement.md) — full v15 spec + Lessons L1-L11
- [`docs/email-analysis-agent-script.md`](../docs/email-analysis-agent-script.md) — the new agent's requirement doc + deviations
- Reference agents in this repo: `Inbound_Email_Analysis_Agent` (ServicePlanner pattern), `Global_Care_Service_Agent_Script` (constitution-style EmployeeAgent pattern)

### Salesforce Help — Service Assistant
- Set Up Service Assistant (`sp_start_setup`)
- Service Assistant Component Overview (`sp_comps`)
- Grounding Service Assistant with Subagents (`sp_topics_start`)
- Best Practices for Subagents (`sp_topics_pb`)
- Service Plan Eligibility Criteria (`sp_eligibility_reference`)
- Permissions and Licensing for Service Assistant (`sp_permissions`)

---

*Last verified: 2026-05-16 against PlusGradeFullSB org (Spring '26 / API v66.0). Maintained by Naresh.*
