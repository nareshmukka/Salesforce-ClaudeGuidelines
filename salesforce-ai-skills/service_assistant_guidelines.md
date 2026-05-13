# Salesforce Agentforce Service Assistant — Implementation Guidelines

> Plusgrade-specific reference for building, deploying, and operating an Agentforce Service Assistant agent on Case records.
> Based on real implementation of `Agentforce_Service_Assistant` (ServicePlanner agent type, Builder mode) in the FullSB org, May 2026.
> Companion to: agentforce_builder_guidelines.md, flow_guidelines.md, permission_set_guidelines.md.

---

## 1. What Service Assistant Is and Isn't

**Service Assistant** is an assistive Agentforce agent embedded on the Case record page. It generates a **case summary** and a **service plan** (step-by-step guidance) for the service rep to execute manually.

**Service Assistant is NOT:**
- A customer-facing agent (use `AgentforceServiceAgent` for chat / messaging)
- An autonomous executor — it does not update Cases, send emails, or close cases by itself
- The same as "Field Service Work Plans" (different feature, different metadata)
- Buildable in the new Agentforce Builder — **only the legacy Agentforce Builder is supported**

**Mandatory characteristics of the agent:**
| Property | Value |
|---|---|
| `agentType` | `ServicePlanner` |
| `agentTemplate` | `service_planner_agent__ServicePlanner` |
| `<type>` (legacy flag) | `InternalCopilot` |
| `agentDSLEnabled` | `false` (Builder mode — Script/.agent DSL is **not supported**) |
| `plannerType` (in GenAiPlannerBundle) | `AiCopilot__ReAct` |

---

## 2. Architecture — How the Pieces Fit

```
┌────────────────────────────────────────────────────────────────────┐
│  Case Record Page                                                  │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │  Service Assistant Lightning Component                       │  │
│  │  • Summary State → Plan State → Redraft State                │  │
│  │  • Renders QA buttons inside plan steps                      │  │
│  └──────────────────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────────────────┘
        │
        ▼ checks
┌────────────────────────────────────────────────────────────────────┐
│  Service Assistant Setup (Setup → Service Assistant)               │
│  • Eligibility Flow (autolaunched)                                 │
│  • Service AI Grounding (mandatory) — Case fields                  │
│  • Quick Actions Manager — binds QAs to subagents/topics           │
│  • Data Library — Knowledge grounding                              │
└────────────────────────────────────────────────────────────────────┘
        │
        ▼ runs the
┌────────────────────────────────────────────────────────────────────┐
│  Bot (Agentforce_Service_Assistant)                                │
│  └── BotVersion v1 (Active)                                        │
│       └── conversationDefinitionPlanners → genAiPlannerName        │
└────────────────────────────────────────────────────────────────────┘
        │
        ▼ uses
┌────────────────────────────────────────────────────────────────────┐
│  GenAiPlannerBundle (Agentforce_Service_Assistant)                 │
│  ├── plannerType = AiCopilot__ReAct                                │
│  ├── localActionLinks (Knowledge action)                           │
│  ├── localTopicLinks × N (one per subagent)                        │
│  ├── localTopics × N (INLINE subagent definitions)                 │
│  │     └── localActions × M (inline GenAiFunction wrappers)        │
│  └── plannerActions (Knowledge standard action)                    │
│                                                                    │
│  + on disk: localActions/<Topic>/<Function>/{input,output}/        │
│             schema.json files for every inline action              │
└────────────────────────────────────────────────────────────────────┘
```

**Key insight: ServicePlanner uses `<localTopics>` INLINE in the planner bundle.** It does NOT use `<genAiPlugins>` references the way `AgentforceEmployeeAgent` agents do. Reference: `Inbound_Email_Analysis_Agent` planner bundle.

---

## 3. Required Licenses

| License | Required for | Notes |
|---|---|---|
| **Einstein for Service** OR **Agentforce for Service Add-on** | Org-wide enablement | Provisioned by Salesforce |
| **Service Planner Add-on license** | Service Assistant feature | Org-wide enablement |
| **Einstein Agent** PSL | The bot user | One PSL per bot |

Min Salesforce edition: Service Cloud Agentforce 1, Performance, Unlimited, or Enterprise (with Agentforce for Service Add-on).
Available in **Lightning Experience only**.

---

## 4. Permission Sets — Three Personas

| Persona | User License | Required PSes |
|---|---|---|
| **Admin (Naresh)** | Salesforce | `Service Planner Builder` + `Agentforce Default Admin` + `Customize Application` |
| **Service Rep (demo user)** | Salesforce | **`Service Planner User`** ← gates component visibility + **`Access Agentforce Default Agent`** + any custom PS for Case object/field access (e.g., `PS_ServiceAssistantDemo`) |
| **ServicePlanner User (bot user)** | Einstein Agent | `Agentforce_<AgentName>_Permissions` (auto-assigned) + `Service Planner Agent User` (auto-assigned) + **`Data Cloud User`** (MANUAL — must be assigned by admin) |

**The bot user is NOT the rep.** It's a separate auto-created user (`agentforce_service_assistant@<orgid>.ext`). Service plans are generated under its permissions, not the rep's.

**Common gotcha**: A missing PS on the rep or bot user causes the Service Assistant component to display "Service Assistant agent was deactivated" — even when the bot is actually active. Always verify PS assignments on BOTH users before debugging activation.

---

## 5. Setup Sequence (correct order)

1. **Setup → Einstein Setup** → Turn On Einstein (Generative AI)
2. **Setup → Agentforce Agents** → Turn On Agentforce
3. **Agentforce Builder (legacy) → Create Agent** → select `Agentforce Service Assistant` template
4. **Create at least one subagent** in the Builder (Topics tab → New Topic) with full instructions before activating. Empty agents fail to activate.
5. **Setup → Service AI Grounding** → Turn On + Object: Case + Required: Subject, Description + Additional: Status, Priority, Origin, Type, AccountId, ContactId + (recommended) Case Emails / Comments / Feed
6. **Build the eligibility flow** (autolaunched, see §7) → activate it
7. **Setup → Service Assistant** → Step 4 (Customize by Object) → Case tab → Add Eligibility Criteria: select the flow, map `caseId` input + `meetsEligibility` output + `ineligibilityReason` output
8. **Setup → Service Assistant** → toggle **Turn on Service Assistant for Cases** = ON
9. **Lightning App Builder** → Case record page → drag in the **Service Assistant** component → Save → Activate as Org Default + App Default
10. **Quick Actions Manager** (within Service Assistant Setup) → add each Quick Action you want surfaced + bind to subagents + write a one-line instruction per QA
11. **Data Library** (within Service Assistant Setup) → connect to Knowledge with filter + content fields (Title + Summary)
12. **Activate the agent** (in the Builder header). A "configuration error about permissions" warning is expected — click **Ignore and Activate**.
13. **Assign permission sets** to rep, bot user, admin (see §4)

---

## 6. Subagent (Topic) Design

In Service Assistant, "topics" are now called **subagents** (renamed April 2026; metadata still uses `<localTopics>` and `<genAiPlugins>`).

**Each subagent has:**
- **Label** — human-readable name (e.g., "Customer Refund Request")
- **DeveloperName** — must be globally unique; suffix with the agent identifier (e.g., `Customer_Refund_Request_SrvAst`)
- **Description** — 1-2 sentences saying when to use this subagent
- **Scope** — what the subagent handles + does NOT handle
- **Utterances** — 6-10 sample phrases reps might say to trigger this subagent
- **Instructions** — multiple `<genAiPluginInstructions>` blocks. Article best practice: 5-8 distinct instructions, each describing ONE task. Don't combine multiple steps into one instruction.
- **Guardrails** — separate instruction block at `sortOrder=1` listing what the agent must NOT do

**Naming convention:**
- Subagent developerName: `<Topic_Snake_Case>_<AgentSuffix>` (e.g., `Customer_Refund_Request_SrvAst`)
- localDeveloperName: short clean name without suffix (e.g., `Customer_Refund_Request`)
- masterLabel: human-friendly title case (e.g., `Customer Refund Request`)
- Inline localActions function name: `<FunctionName>_<TopicAbbrev>_<AgentSuffix>` for global uniqueness (e.g., `Get_Record_Context_CRR_SA`)

---

## 7. Eligibility Flow

**Mandatory.** No service plan generates without an active eligibility flow.

| Property | Value |
|---|---|
| `processType` | `AutoLaunchedFlow` |
| `runInMode` | `DefaultMode` |
| Inputs | `caseId` (Id, available for input) |
| Outputs | `meetsEligibility` (Boolean), `ineligibilityReason` (String) |
| Logic | Get Case → Decision (filter conditions) → Assign true/false outputs → End |
| Status | Must be `Active` |

**Salesforce-provided template**: `Check Service Plan Eligibility` (in Setup → Flows → All Flows). Customize the Decision element conditions (e.g., `Status != 'Closed' AND (Subject != null OR Description != null)`).

**Custom flow alternative**: any autolaunched flow with the same input/output contract works.

---

## 8. Service AI Grounding (the Mandatory Layer)

Without Service AI Grounding configured, the agent has no Case data context — plans will be generic or fail with "provide a summary" prompts.

**Configure:**
- Setup → Service AI Grounding → ON
- Object: **Case** → Grounding with Cases ON
- **Required Fields**: Subject, Description
- **Additional Fields**: Status, Priority, Origin, Type, RecordType, AccountId, ContactId, OwnerId
- **Additional Object Grounding** (recommended for richer plans): turn on Case Emails, Case Comments, Case Feed

**Limitations** (from Salesforce docs):
- Only `String` and `Text Area` field types supported
- **Encrypted fields not supported**
- Only **text content** of emails/comments/feed — no PDFs or images
- Only the **active Case** — no historical learning
- Plans run under **ServicePlanner User permissions**, not the rep's

**Don't duplicate Service AI Grounding with custom Get_Record_Context inline actions unless you need richer JSON** (e.g., related records, opportunity context). For most demos, Service AI Grounding alone is enough.

---

## 9. Quick Actions in Service Plans

Service plans render Quick Action buttons inline within plan steps.

**Quick Actions supported:**
- Standard Case QA types: `SendEmail`, `Update`, `LogACall`, `Create`, `LightningWebComponent` (screen actions only), `Flow`, `Visualforce`
- The Service Assistant component renders the QA in the step → rep clicks → Salesforce opens the standard QA UI → rep completes

**Setup steps for each QA:**
1. **QA must exist as a Case object Quick Action** (object metadata)
2. **QA must be on the Case page layout** in Mobile & Lightning Actions
3. **QA must be added to Service Assistant Quick Actions Manager** (UI step)
4. **QA must be bound to one or more subagents** in the manager
5. **QA must have an instructions text** explaining when the agent should surface it

**Plusgrade naming**: prefer existing org QAs (`Send_Email_CSR`, `Move_to_Dev`, etc.) over custom `QA_*` flows. Existing org QAs are battle-tested and use built-in types (SendEmail, Update) that don't require custom flows.

**Critical warning**: Quick Action Manager bindings reset when the subagent (topic) developerName changes. If you rename a subagent in metadata, you'll need to re-bind all its QAs in the UI.

---

## 10. Data Library / Knowledge Grounding

The Data Library lets the agent cite Knowledge articles in plan steps.

**For Plusgrade Knowledge (`Knowledge__kav` object):**
| Use | Field |
|---|---|
| Filter — only published English articles | `PublishStatus = 'Online'`, `Language = 'en_US'`, `IsLatestVersion = true` |
| Filter — exclude empty articles | `Summary != null` (or `Article_Body__c != null`) |
| Filter — exclude DEMO articles | `(NOT Title LIKE 'DEMO:%')` |
| Identifying field for the LLM | `Title` |
| Content field for matching | `Summary` (lightweight) — populate via backfill if null |
| Content field for full grounding | `Article_Body__c` (RichText, up to 131K chars; expensive but thorough) |

**Important**: in this org, all 22 published `[SBU]` and `[GC]` articles had `Summary = null` initially. We backfilled via `scripts/apex/backfill-knowledge-summary.apex` (strip HTML from `Article_Body__c`, take first 500 chars, update Summary, republish). Articles with empty `Article_Body__c` (Delta Choice Code Inquiry, Gift Card Inquiry) were skipped.

---

## 11. Topic Instructions — Best Practices

**DO:**
- Tell the agent how to handle the case TYPE
- Reference Quick Actions by **display name** (e.g., "Send Email CSR")
- Use real org status values (New, In Progress, Pending Internal, Waiting - Partner/Customer, Escalated, Second Line Escalated, TKO Escalated, Supplier Escalated, Product Escalated, Resolved, Completed, Closed, Reopened)
- Add a grounding directive: *"Ground every plan step in the available Case data: subject, description, status, priority, origin, type, account, contact, related records, recent emails, recent comments. Reference specific Case data points directly in plan steps. Do not ask the rep to provide a case summary or context — the data is already available."*
- Split into multiple distinct instructions (one task per instruction, per article §5)

**DO NOT:**
- Write **agent-function instructions** like "Use the Get Record Context action" or "Summarize the case" or "Draft a service plan" — these leak into rep-facing plan text. Service Assistant performs these automatically.
- Reference QAs by API name (e.g., `Case.Move_to_Second_Line_Queue`) — agent will leak the API name. Use display name only.
- Tell the agent to "produce four short sections" — the component lays out 4 fixed sections automatically (Gather Information / Work the Issue / Resolve the Issue / Wrap Up).
- Combine multiple steps into one instruction.
- Include policy commitments, refund timelines, fix timelines unless they're on the Case data or in approved Knowledge.

**Required guardrails (rules 13 and 14 added based on this build):**
- Rule 13: When referencing Quick Actions in plan text, always use the display name. Never use API name format like `Case.Move_to_Second_Line_Queue`.
- Rule 14: Never instruct the rep to use, run, or invoke a GenAiFunction or back-end action. Grounding actions are invoked automatically by the platform.

---

## 12. Deployment Notes

**API Version**: Use `66.0` or higher in package.xml. ServicePlanner metadata properties (e.g., `agentDSLEnabled`) are not valid in API 62.0.

**Bot must be DEACTIVATED** before metadata deploy of Bot, BotVersion, or GenAiPlannerBundle. Salesforce blocks updates to active agents with: `Cannot update record as Agent is Active` / `Can't edit an active bot version`.

**Sequence:**
1. Deactivate agent in Builder
2. `sf project deploy start --manifest <pkg> --target-org <alias> --test-level NoTestRun --wait 30 --ignore-conflicts`
3. Reactivate agent
4. Hard-refresh Case page to test

**Minimal manifests**: when iterating, deploy only the file you changed (e.g., just `GenAiPlannerBundle:Agentforce_Service_Assistant`). Avoid the full manifest when stale local files could overwrite live UI configurations.

**Bot version cleanup**: deploys can leave inactive `v2` versions. Delete them in the Builder to avoid component confusion.

**plannerAction developerName uniqueness**: every `<plannerActions>` `developerName` must be GLOBALLY unique across the org (not per-bundle). Suffix with the agent identifier (e.g., `_SrvAst`).

**localActions schema files mandatory**: every inline `<localActions>` block requires a directory `localActions/<TopicName>/<FunctionName>/{input,output}/schema.json`. Without these files, the deploy fails with a generic "An unexpected error occurred" message.

---

## 13. Common Errors and Diagnoses

| Symptom | Likely cause | Fix |
|---|---|---|
| "Service plans aren't available because the Service Assistant agent was deactivated" on Case page | Rep user missing `Service Planner User` PS, OR bot user missing `Data Cloud User` PS | Verify PS assignments on both users (§4). Hard refresh after fixing. |
| "Something went wrong while creating a plan" | Data Library config issue OR Service AI Grounding off | Setup → Service AI Grounding ON; verify Data Library filter and content fields |
| "There's not enough information to draft a service plan summary" | Case Subject/Description thin OR Service AI Grounding fields too narrow | Improve Case content; expand Service AI Grounding additional fields |
| "We couldn't draft a service plan because no relevant topics exist" | Subagent labels/descriptions too generic | Make subagents distinct and specific to a case category |
| Plan generates but with "Use the Get Record Context action" leaking into rep text | Topic instruction has agent-function phrasing | Remove "Use the X action" language; use platform grounding (§11) |
| Plan generates but Quick Action API names appear (`Case.Send_Email_CSR`) | Topic instructions or QA Manager use API names instead of display labels | Always use display labels in topic instruction text |
| Builder Test works but Case page component fails | Different auth/grounding paths — Builder bypasses rep PS gate | Check rep user has `Service Planner User` + `Access Agentforce Default Agent` PS |
| Deploy fails: `Property X not valid in version 62.0` | API version too old | Bump manifest to 66.0+ |
| Deploy fails: `Cannot update record as Agent is Active` | Bot not deactivated | Deactivate in Builder, redeploy, reactivate |
| Deploy fails: `An action with developer name 'X' already exists in the org` | plannerAction developerName collision | Suffix the developerName with a unique tag like `_SrvAst` |
| Deploy fails: `An unexpected error occurred. ErrorId: ...` on GenAiPlannerBundle | Missing `localActions/<topic>/<function>/{input,output}/schema.json` files | Create the schema files (copy from referenced GenAiFunction's schema files) |
| Flow shows as "Built with: Cloud Flow Designer" | Missing `<processMetadataValues>` blocks | Add `BuilderType=LightningFlowBuilder`, `CanvasMode=AUTO_LAYOUT_CANVAS`, `OriginBuilderType=LightningFlowBuilder` before `<processType>` |
| Flow XML deploy: `Element X is duplicated at this location` | Element types not contiguous | Group all `<screens>` together, all `<decisions>` together, etc. (per Flow XSD) |
| Flow runtime: `INVALID_OR_NULL_FOR_RESTRICTED_PICKLIST` writing to Case.Reason | Writing free text to a picklist field | Use `Case.Description` or create a `CaseComment` for free text |
| `emailSimple` action sends instead of drafting | Wrong action for "draft" semantics | Use a display-only screen with prefilled body for rep to copy/paste, or create EmailMessage with Status='Draft' |
| Manifest deploy succeeds but Salesforce regenerates `v2` | Bot is auto-versioning on deploy | Delete `v2` after each deploy if you only want one version |
| `<license>X</license>` deploy fails: `License doesn't exist` | Wrong license API name | Use the actual API name (e.g., `Einstein Agent` with space). License-agnostic (no `<license>` element) is the safest default. |
| PermissionSet description deploy fails: `data value too large` | Description over 255 chars | Trim to ≤255 chars |
| Setting up Knowledge grounding but agent doesn't cite articles | `Summary` field is null on real articles | Backfill `Summary` from `Article_Body__c` (script: `scripts/apex/backfill-knowledge-summary.apex`) |

---

## 14. Plusgrade-Specific Reference (this org)

### Real org Case status values (do not invent new ones)
`New`, `In Progress`, `New Email Received`, `Pending Internal`, `On Hold`, `Waiting - Partner/Customer`, `Waiting - Customer`, `Awaiting Customer Response`, `Escalated`, `Second Line Escalated`, `TKO Escalated`, `Supplier Escalated`, `Product Escalated`, `Resolved`, `Completed`, `Closed`, `Closed Lost`, `Reopened`, `Rejected`

### Real org Case Quick Actions (re-use these; don't build custom)
| QA | Type | Use case |
|---|---|---|
| `Send_Email_CSR` | SendEmail | Customer-facing email (CSR_Record cases) |
| `Send_Email_PSC` | SendEmail | Partner-facing email (PSC_Record cases) |
| `Email_AmexGBT` | SendEmail | AmexGBT-specific |
| `Move_to_Second_Line_Queue` | Update | Refunds team / partner reconciliation |
| `Move_to_Dev` | Update | Dev/engineering investigation |
| `Escalate` | Update | General escalation |
| `Escalate_to_Second_Line_of_Defense` | Update | Tier-2 specialist review |
| `Close_CSR_Case` / `Close_PSC_Case` / `Close_HRG_Case` / `Close_Refunds_Case` | Update | Record-type-specific closure |
| `Log_a_Call` | LogACall | Call documentation |
| `Remind_Me` | LightningWebComponent | Personal reminder |
| `NewChildCase` | Create | Spawn sub-cases for parallel workstreams |

### Real Case RecordTypes
`CSR_Record` (customer-facing), `PSC_Record` (partner ops), `Refunds_Record`, `HRG_Record`, `HRG_CS_Record`, `HUBU_GC`, `SBU_GC`, `Solutions_Hospitality`, `Bug_Problem_Record`, `Monitoring_Alert_Record`, `Magento_Record`, `Nexus_Hub_Ticket`

### Real partner Origins
`PSC_Email`, `Delta_Phone`, `Delta_Email`, `United_Email`, `AIRMILES_Phone`, `Refunds_Email`, `PointsTravel_Email`, `Solutions Hospitality - Email`, `Chase_Support`, `PSC_Slack`, `PDC_Email`, `Experience Cloud Site`

### Demo subagent map (Plusgrade business-aligned, deployed to FullSB)
| Subagent | Real case patterns |
|---|---|
| `Customer_Refund_Request_SrvAst` | Miles/points refund (CSR — United, Delta, AIRMILES) |
| `Missing_Credit_Or_Posting_SrvAst` | Retro credit, miles not posted |
| `Partner_Transaction_Error_SrvAst` | Wyndham/Virgin/IAG/Delta transaction error reports, MV failures |
| `Subscription_Or_Access_Issue_SrvAst` | Points.com password/login |
| `Production_Alert_Or_Monitoring_SrvAst` | Splunk alerts, IAG operational status |
| `General_Case_Triage_SrvAst` | Fallback |

### Demo test cases (one per subagent, grounded in real Knowledge keywords)
- `01325902` Paysafe declined miles purchase → `[SBU] Paysafe Payments: Credit card decline codes`
- `01325903` Miles not posted to wallet → `[SBU] How Do I find RS/RQ logs` + `[SBU] UPG troubleshooting`
- `01325904` FZ Staging 503 → `[SBU] Recent Updates`
- `01325905` Partner cannot log in → `[SBU] Partner Tool Guide` + `[SBU] Activation Templates`
- `01325906` EY checkEligibility errors → `[SBU] Splunk Queries (in progress)`
- `01325907` New PBU ticket → `[GC] Case Management Hub`

---

## 15. Maintenance Playbook

### To add a new subagent
1. Deactivate agent in Builder
2. Add `<localTopicLinks>` and `<localTopics>` block in planner bundle XML (or via UI in Builder Topics tab)
3. Create `localActions/<NewTopic>/<Function>/{input,output}/schema.json` (12 files for Get_Record_Context — copy from existing topic)
4. Deploy
5. Reactivate
6. Bind QAs to the new subagent in Quick Actions Manager

### To rename a subagent
1. Salesforce treats rename as delete + create — Quick Action bindings in the manager will be lost
2. Plan to re-bind all QAs in the UI after the rename
3. Deactivate → rename in metadata → deploy → reactivate → re-bind QAs in Manager

### To update topic instructions only
1. Deactivate agent in Builder
2. Either edit in Builder UI (faster, auto-saves) or edit metadata XML
3. If UI edit: retrieve metadata after to keep source in sync
4. Reactivate
5. On Case page: edit Subject (add `.`) → Save → click Redraft Plan to refresh

### To add a new Quick Action
1. Create the QA on the Case object (or use existing org QA)
2. Add to Case page layout (Mobile & Lightning Actions)
3. Add to Quick Actions Manager in Service Assistant Setup
4. Bind to relevant subagents
5. Write the QA's instructions text

### To improve Knowledge grounding
1. Verify all relevant articles have `Summary` populated (run `scripts/apex/backfill-knowledge-summary.apex` if needed)
2. Update Data Library filter (e.g., add new categories or refine Title pattern)
3. Verify Service AI Grounding includes Case Emails / Comments / Feed if conversational context matters

---

## 16. References

- Salesforce Help: Set Up Service Assistant (`sp_start_setup`)
- Salesforce Help: Service Assistant Component Overview (`sp_comps`)
- Salesforce Help: Grounding Service Assistant with Subagents (`sp_topics_start`)
- Salesforce Help: Best Practices for Subagents (`sp_topics_pb`)
- Salesforce Help: Service Plan Eligibility Criteria (`sp_eligibility_reference`)
- Salesforce Help: Permissions and Licensing for Service Assistant (`sp_permissions`)
- Internal: `salesforce-ai-skills/agentforce_builder_guidelines.md`
- Internal: `salesforce-ai-skills/flow_guidelines.md`
- Internal: `salesforce-ai-skills/permission_set_guidelines.md`
- Reference agent in this org: `Inbound_Email_Analysis_Agent` (Builder mode, `<localTopics>` pattern reference)

---

*Last updated: 2026-05-08. Built and validated against Plusgrade FullSB org.*
