---
name: salesforce-prompt-template
description: Production Salesforce AI skill for Prompt Builder templates, AI output contracts, grounding controls.
license: Apache-2.0
compatibility:
  - Claude Code
  - Claude Agents
  - Codex / ChatGPT
  - GitHub Copilot
metadata:
  version: 2.0.0
  last_updated: 2026-05-16
  owner: Reusable Salesforce AI Skills Library
---

## TRIGGER when
- The task involves Prompt Builder templates, AI output contracts, grounding controls.
- The user asks for implementation, refactor, troubleshooting, review, or best-practice validation in this area.
- The assistant must produce Salesforce-safe code/metadata with explicit security/testing notes.

## DO NOT TRIGGER when
- The task is unrelated to this component.
- Another specialized skill is the primary owner and this area is only incidental.
- The user asks for operational execution (deploy/publish/activate/destructive change) without explicit approval.

## Cross-skill routing
- Always read `../salesforce-global-development/SKILL.md`.
- Also read: Global Development + Agentforce Script + AI Prompt Templates.
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
Define grounding source, merge fields, and strict output schema. Separate draft generation from send/commit actions. Add hallucination guardrails: cite source context or state uncertainty.

## Examples
### Good example patterns
1. Template requests JSON with fixed keys and fallback value rules.
2. Prompt instructs model to ask clarifying question when required inputs missing.

### Bad examples / avoid
1. Open-ended prompt with no output contract.
2. Prompt that instructs model to fabricate unavailable CRM facts.

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


## Full Guidance

# Prompt Builder Template Guidelines

Authoritative reference for `GenAiPromptTemplate` metadata, Prompt Builder authoring, and Agentforce consumption of prompt templates in this project. Companion to `../salesforce-agentforce-script/SKILL.md` (which is the source of truth for how `.agent` files invoke prompt templates).

**Verified against:** Salesforce Metadata API `GenAiPromptTemplate` element (`force-app/main/default/genAiPromptTemplates/*.genAiPromptTemplate-meta.xml`), Einstein Trust Layer audit log, Prompt Builder UI in Spring '26 (API v66.0), and the Agent Script convention for prompt-backed actions documented in `../salesforce-agentforce-script/SKILL.md` Section 9 Last verified 2026-05-16.

> **Direct doc fetch limitation (Empirical Finding #5 in `../salesforce-agentforce-script/SKILL.md`):** `help.salesforce.com` renders via JavaScript and returns CSS errors to WebFetch; many `developer.salesforce.com/docs/einstein/genai/guide/*` paths have shifted between releases and currently 404. Ground truth for the metadata schema lives in retrieved `.genAiPromptTemplate-meta.xml` files under `force-app/main/default/genAiPromptTemplates/` and in the canonical Agent Script reference (Section 9 Prompt-template actions are different").

---

## 1. File Layout

A prompt template is a single metadata file under:

```
force-app/main/default/genAiPromptTemplates/<Template_API_Name>.genAiPromptTemplate-meta.xml
```

There is no `.cls` or sibling -- the entire template (prompt body, inputs, capabilities, type, masking, versions) lives in the one XML file. Apex capabilities the template depends on live separately under `force-app/main/default/classes/` and **must deploy before** the template that references them.

**Critical:** The filename, the `developerName`/API name shown in Prompt Builder, and any agent action target `prompt://<Template_API_Name>` must match exactly (case-sensitive).

---

## 2. `GenAiPromptTemplate` Metadata -- Required Top-Level Order

| Element | Required | Purpose |
|---|---|---|
| `<activeVersionIdentifier>` | Required (post-publish) | API name of the currently active version (e.g. `v3`). Drives which version Prompt Builder serves at runtime. |
| `<description>` | Optional but strongly recommended | Human-readable purpose. Surfaces in Prompt Builder list view. |
| `<masterLabel>` | Required | Display label in Prompt Builder UI. |
| `<relatedEntity>` | Required for `flex`/`sales_email`/`field_generation`/`record_summary` | sObject API name the template is bound to (e.g. `Case`, `Opportunity`). |
| `<templateVersions>` | One or more required | Each version is a self-contained snapshot: prompt body, inputs, capabilities, model. Adding a new version is how you iterate. |
| `<type>` | Required | One of `einstein_gpt__sales_email`, `einstein_gpt__field_generation`, `einstein_gpt__record_summary`, `einstein_gpt__flex`. |
| `<visibility>` | Required | `Global` or `Local`. `Global` makes the template invocable from Flow/Apex/Agentforce; `Local` restricts it to the Prompt Builder editor. |

Minimal valid skeleton:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<GenAiPromptTemplate xmlns="http://soap.sforce.com/2006/04/metadata">
    <activeVersionIdentifier>v1</activeVersionIdentifier>
    <description>Generate a JSON case summary for the LWC parser</description>
    <masterLabel>Case Summary Generator</masterLabel>
    <relatedEntity>Case</relatedEntity>
    <type>einstein_gpt__flex</type>
    <visibility>Global</visibility>
    <templateVersions>
        <!-- one or more <GenAiPromptTemplateVersion> child blocks -->
    </templateVersions>
</GenAiPromptTemplate>
```

---

## 3. Template Types -- What Each One Means

| `<type>` value | Use when | Output shape | Agent-callable? |
|---|---|---|---|
| `einstein_gpt__flex` | Generic, agent-callable text generation. Default choice for Agentforce action targets. | Free-form string (you constrain shape via prompt instructions). | Yes -- `prompt://` target. |
| `einstein_gpt__field_generation` | Populating a single field on a record (Quick Action, Flow). | Single string for one field. | Indirectly (via Flow that writes the field). |
| `einstein_gpt__record_summary` | "Summarize this record" Lightning component on a record page. | Narrative string. | No -- Lightning panel only. |
| `einstein_gpt__sales_email` | Drafting emails from the email composer on Opportunity/Lead/Contact. | Email subject + body. | Indirectly. |

> **Agent target choice:** When an Agentforce agent calls a prompt template (`prompt://Template_API_Name`), it must be `einstein_gpt__flex` with `<visibility>Global</visibility>`. The other three types are surface-bound (composer, record page, Quick Action) and cannot be invoked as agent actions.

---

## 4. `<templateVersions>` -- The Versioned Payload

Every prompt template has one or more `<GenAiPromptTemplateVersion>` children. The version listed in `<activeVersionIdentifier>` is what runs at runtime; other versions are dormant snapshots. **You never edit an active version in place -- clone it, bump the identifier, edit, then flip `<activeVersionIdentifier>` to the new one.** This pattern is how Prompt Builder gives you safe iteration with rollback.

```xml
<templateVersions>
    <content>You are a Salesforce support assistant...
{!$Input:caseRecord.Subject}
{!$Input:caseRecord.Description}
Return JSON only.</content>
    <inputs>
        <apiName>caseRecord</apiName>
        <definition>SOBJECT://Case</definition>
        <description>The Case record to summarize</description>
        <masterLabel>Case</masterLabel>
        <referenceName>Input:caseRecord</referenceName>
        <required>true</required>
    </inputs>
    <primaryModel>sfdc_ai__DefaultGPT4Omni</primaryModel>
    <status>Published</status>
    <versionIdentifier>v1</versionIdentifier>
</templateVersions>
```

**Version block required children:**

| Element | Purpose |
|---|---|
| `<content>` | The prompt body. Merge-field syntax `{!$Input:name.Path}` for inputs, `{!$Input:name}` for scalar inputs. |
| `<inputs>` | Zero or more -- each defines one input variable (see Section 5 `<primaryModel>` | Model API name. Common values: `sfdc_ai__DefaultGPT4Omni`, `sfdc_ai__DefaultGPT4OmniMini`, `sfdc_ai__DefaultAnthropicClaude4Sonnet`, `sfdc_ai__DefaultOpenAIGPT5`. Models gated by org entitlement. |
| `<status>` | `Draft` or `Published`. Only `Published` versions can be activated. |
| `<versionIdentifier>` | Stable string (e.g. `v1`, `v2`). Referenced by `<activeVersionIdentifier>`. |

Optional children of a version: `<secondaryModel>` (fallback), `<temperature>` (decimal), `<maxTokens>` (integer), `<frequencyPenalty>`, `<presencePenalty>`, `<groundingDataSources>` (capabilities -- see Section 6 5. `<inputs>` -- Defining Template Variables

Every dynamic value you reference in `<content>` must be declared as an `<inputs>` block. The **`<referenceName>` is the merge-field identifier inside the prompt body and the wire-name when the template is called from Apex, Flow, or Agentforce.**

```xml
<inputs>
    <apiName>caseRecord</apiName>
    <definition>SOBJECT://Case</definition>
    <description>The Case to summarize</description>
    <masterLabel>Case</masterLabel>
    <referenceName>Input:caseRecord</referenceName>
    <required>true</required>
</inputs>
<inputs>
    <apiName>maxLines</apiName>
    <definition>primitive://Integer</definition>
    <description>Max number of bullet points</description>
    <masterLabel>Max Lines</masterLabel>
    <referenceName>Input:maxLines</referenceName>
    <required>false</required>
</inputs>
```

| Element | Required | Notes |
|---|---|---|
| `<apiName>` | Yes | Internal slug -- must be unique within the version. |
| `<definition>` | Yes | One of `SOBJECT://<APIName>`, `primitive://String`, `primitive://Integer`, `primitive://Decimal`, `primitive://Boolean`, `primitive://Date`, `primitive://DateTime`, or `apex://<ClassName>` for a custom Apex DTO. |
| `<masterLabel>` | Yes | Display name in Prompt Builder. |
| `<referenceName>` | Yes | **Must begin with `Input:`** -- this is the prefix consumers use. `{!$Input:caseRecord.Subject}` in `<content>`; `"Input:caseRecord"` in an agent action `with` clause. |
| `<required>` | Yes | `true`/`false`. Required inputs make the template fail-fast when missing. |
| `<description>` | Optional | Surfaces to Prompt Builder authors and (for `Global` templates) to Agentforce planners. |

**Reference syntax inside `<content>`:**

| Reference | Resolves to |
|---|---|
| `{!$Input:foo}` | Scalar primitive input named `foo` |
| `{!$Input:caseRecord.Subject}` | Field on an sObject input |
| `{!$Input:caseRecord.Account.Name}` | Field via one parent-relationship hop |
| `{!$Input:caseRecord.Account.Owner.Email}` | Two relationship hops (depth-limited; verify in target environment) |
| `{!$Context.UserId}` | Running-user Id from the Trust Layer context |
| `{!$Context.UserLocale}` | Running-user locale |

Related-list traversal in pure merge syntax is limited -- use a grounding capability (Section 6 when you need child-record aggregation, computed counts, or cross-object joins.

---

## 6. Grounding via Capabilities -- Apex and Flow

Capabilities provide **server-side data** to the template at runtime: things merge fields can't fetch (multi-hop SOQL, aggregations, external API data). The template declares a `<groundingDataSources>` entry that names the capability; at runtime Prompt Builder executes the capability, takes its output, and merges it into the prompt body via the capability's reference name.

### 6.1 Apex Capability -- Invocable

An Apex grounding capability is just an `@InvocableMethod`-decorated class with a defined input request and response.

```apex
/**
 * Description: Provides recent Case comments for a Case grounding capability.
 * Developer: the release owner
 * Title: Salesforce Developer
 */
public with sharing class CaseRecentCommentsCapability {

    public class Request {
        @InvocableVariable(label='Case Id' required=true)
        public Id caseId;
    }

    public class Response {
        @InvocableVariable(label='Recent Comments Block')
        public String recentCommentsBlock;
    }

    @InvocableMethod(
        label='Case Recent Comments'
        description='Returns up to 5 recent comments as a single block for prompt grounding.'
        callout=false)
    public static List<Response> exec(List<Request> reqs) {
        List<Response> out = new List<Response>();
        for (Request r : reqs) {
            List<CaseComment> cs = [
                SELECT CommentBody, CreatedDate
                FROM CaseComment
                WHERE ParentId = :r.caseId
                WITH USER_MODE
                ORDER BY CreatedDate DESC
                LIMIT 5
            ];
            List<String> lines = new List<String>();
            for (CaseComment c : cs) {
                lines.add('- ' + c.CreatedDate.format() + ': ' + c.CommentBody);
            }
            Response resp = new Response();
            resp.recentCommentsBlock = lines.isEmpty()
                ? 'No prior comments.'
                : String.join(lines, '\n');
            out.add(resp);
        }
        return out;
    }
}
```

Bind it inside the template version:

```xml
<groundingDataSources>
    <apiName>recentComments</apiName>
    <capabilityReferenceName>CaseRecentCommentsCapability</capabilityReferenceName>
    <description>Recent Case comments block</description>
    <inputs>
        <referenceName>caseId</referenceName>
        <valueExpression>{!$Input:caseRecord.Id}</valueExpression>
    </inputs>
    <type>Apex</type>
</groundingDataSources>
```

Reference the capability output in `<content>`:

```
Recent comments:
{!$Capability:recentComments.recentCommentsBlock}
```

### 6.2 Flow Capability

An autolaunched Flow with input + output variables can serve as a capability. Same `<groundingDataSources>` shape, with `<type>Flow</type>` and `<capabilityReferenceName>` pointing to the Flow API name.

### 6.3 Apex parameter name match

Capability `<inputs>.<referenceName>` MUST match the `@InvocableVariable` field name case-sensitively. Same rule as Agent Script action inputs (`../salesforce-agentforce-script/SKILL.md` Section 9 7. Output Contract -- `promptResponse`

A prompt template always returns a single string -- the model's response. When an Agentforce agent invokes the template as an action, the output is exposed as a single output named **`promptResponse`** of type string. This is the canonical Agent Script convention (see `../salesforce-agentforce-script/SKILL.md` Section 9 ```
# In the .agent file:
actions:
   Summarize_Case:
      target: "prompt://Case_Summary_Generator"
      inputs:
         "Input:caseRecord": object
            description: "Case record to summarize"
            complex_data_type_name: "lightning__recordInfoType"
            is_required: True
      outputs:
         promptResponse: string
            description: "JSON summary block"

reasoning:
   actions:
      summarize: @actions.Summarize_Case
         with "Input:caseRecord" = @variables.case_record
         set @variables.summary_json = @outputs.promptResponse
```

**Three locked-in conventions:**
1. The input parameter names in the agent action MUST be quoted with the `Input:` prefix: `"Input:caseRecord"`, NOT `caseRecord`.
2. The output is ALWAYS `promptResponse` (singular, lowercase first letter, camelCase). Never rename.
3. Long-form target `generatePromptResponse://Template_API_Name` is equivalent to `prompt://Template_API_Name` -- both compile; standardize on short form.

Downstream parsing of `promptResponse` into JSON happens in the agent's subagent reasoning, in the consuming Apex, or in the LWC -- not inside the template.

---

## 8. Deterministic Output Formatting Inside `<content>`

Constrain the model's output shape inside the prompt body, because `promptResponse` is just a string and consumers (LWC, Apex, agent subagents) want structured data.

```
Return EXACTLY this JSON object, no markdown fence, no prose:
{
  "summary": "<string: 2 sentences>",
  "nextSteps": ["<string>"],
  "sentiment": "<Positive|Neutral|Negative>",
  "confidence": <decimal 0.0 to 1.0>
}
```

Rules:
- Spell out every key, value type, and acceptable enum literal.
- "No markdown fence, no prose" instructions reduce the rate of ```json wrapping (still happens sometimes -- the consumer should strip-and-deserialize defensively).
- Test with five-plus representative records before publishing the version. LLM output for the same prompt varies by model and by temperature.

---

## 9. Einstein Trust Layer -- Audit, Masking, and Where to Debug

Every prompt template invocation routes through the Einstein Trust Layer. This is non-negotiable and is the single richest source of debugging information.

| Trust Layer feature | Where it surfaces | What you do with it |
|---|---|---|
| **Prompt audit log** | Setup -> Einstein -> Audit Trail (also queryable via `EinsteinPromptAuditTrail` Tooling API). Captures the rendered prompt, masked prompt, model response, user, timestamp, template version. | Primary debugging tool -- when a template "returns garbage," pull the audit row and look at the actual rendered prompt the model saw. |
| **Data masking** | Configured at the org level (Setup -> Einstein -> Data Masking). PII patterns (email, phone, name, address, SSN, etc.) are replaced with tokens before the prompt leaves Salesforce; tokens are reversed in the response. | Verify your template's masking policy matches the org-level config. If `Account.Name` is masked and your template instructs the model to "address the customer by name," the model sees `[NAME_TOKEN_1]` -- design around it. |
| **Zero-retention contract** | Enforced by the Trust Layer for external models (OpenAI, Anthropic, etc.). Prompts/responses are not used for training. | Compliance documentation only -- not something you toggle per template. |
| **Toxicity / safety scoring** | Each response is scored; high-toxicity responses are flagged in the audit log. | Surface in QA -- escalate any flagged response. |

**Debugging recipe** when a template's output looks wrong:

1. Query the audit trail for the failing invocation (template name + timestamp + user).
2. Compare **rendered prompt** vs **masked prompt** -- if masking is hiding the data you care about, that's the cause.
3. Compare the **active version identifier** with what you think is deployed (`<activeVersionIdentifier>`) -- version drift accounts for a meaningful share of "but it worked yesterday" reports.
4. Check the **model field** -- if `<primaryModel>` differs across versions, model-specific behavior may be the cause.

---

## 10. Deployment Order and Dependencies

Prompt templates have hard dependencies on the Apex/Flow capabilities they ground in. Deploy bottom-up:

| Step | Component | Reason |
|---|---|---|
| 1 | Apex capability class(es) | Template references the class by name; deploy-time validation checks the class exists. |
| 2 | Flow capability(ies) | Same as Apex -- referenced by API name. |
| 3 | Permission sets exposing the Apex class | Running user (or `default_agent_user` for service agents) needs class access. |
| 4 | `GenAiPromptTemplate` metadata | References everything above. |
| 5 | Agentforce `AiAuthoringBundle` (if the agent calls the template) | Agent action target `prompt://...` validated at publish. |
| 6 | LWC / Quick Action / Flow that invokes the template (UI surface) | Last -- consumes the template. |

**Validate** with the same dry-run pattern used elsewhere:

```bash
sf project deploy start \
  --manifest manifest/<your-manifest>.xml \
  --target-org <target-env-alias> \
  --dry-run --test-level RunLocalTests --wait 60
```

Zero component errors on the prompt template + its capabilities required.

---

## 11. Versioning Workflow

Always create a new version block before editing live behavior. Editing the active version in place -- even in dev -- bypasses the audit trail's version provenance and makes regressions invisible.

1. Clone the active `<templateVersions>` block.
2. Bump `<versionIdentifier>` to a new value (`v2`, `v3`, ...).
3. Edit `<content>`, `<inputs>`, `<groundingDataSources>`, or `<primaryModel>` in the new block.
4. Set `<status>Draft</status>` on the new block while iterating.
5. Test in Prompt Builder Preview against five-plus representative records.
6. Flip `<status>` to `Published`.
7. Flip top-level `<activeVersionIdentifier>` to the new identifier.
8. Deploy.
9. Verify in audit trail that new invocations show the new version identifier.
10. Roll back by flipping `<activeVersionIdentifier>` back to the prior value -- zero re-deploy of `<content>` needed.

Keep at least the **previous published version** in the file. Pruning old versions removes the rollback path.

---

## 12. Usage From Agentforce Agents

The canonical `.agent` invocation is documented in full in `../salesforce-agentforce-script/SKILL.md` Section 9 Prompt-template actions are different"). Cross-reference summary:

```
# Action definition inside a subagent:
actions:
   draft_reply:
      target: "prompt://Email_Reply_Draft_Generator"   # template API name
      description: "Draft a reply email body for the open Case"
      inputs:
         "Input:caseRecord": object
            description: "The Case being replied to"
            complex_data_type_name: "lightning__recordInfoType"
            is_required: True
         "Input:tone": string
            description: "Tone: formal / friendly / apologetic"
            is_required: True
      outputs:
         promptResponse: string
            description: "Drafted email body"

# Invocation inside reasoning.actions:
reasoning:
   actions:
      draft: @actions.draft_reply
         with "Input:caseRecord" = @variables.case_record
         with "Input:tone" = @variables.reply_tone
         set @variables.draft_body = @outputs.promptResponse
```

Three things to verify when wiring a template into an agent:
- Template `<type>` is `einstein_gpt__flex`.
- Template `<visibility>` is `Global`.
- Every `<inputs>.<referenceName>` in the template matches an `"Input:..."` key in the agent action's `inputs:` block exactly.

---

## 13. Usage From Flow and Apex (non-agent surfaces)

**Flow:** Use the standard "Prompt Template" action element. Input keys are the bare `<apiName>` values (no `Input:` prefix in Flow). Output is `Prompt Response`.

**Apex:** Invoke via the `ConnectApi.EinsteinLLM.generateMessages*` / `ConnectApi.EinsteinPromptTemplate.generateMessagesForPromptTemplate` namespace (exact method name varies by API version -- verify in target environment). Pattern:

```apex
ConnectApi.EinsteinPromptTemplateGenerationsInput input =
    new ConnectApi.EinsteinPromptTemplateGenerationsInput();
input.inputParams = new Map<String, ConnectApi.WrappedValue>();
// inputs keyed by bare apiName for ConnectApi, NOT "Input:..." prefix
ConnectApi.WrappedValue caseVal = new ConnectApi.WrappedValue();
caseVal.value = caseRecord;
input.inputParams.put('caseRecord', caseVal);

ConnectApi.EinsteinPromptTemplateGenerationsRepresentation result =
    ConnectApi.EinsteinLLM.generateMessagesForPromptTemplate(
        'Case_Summary_Generator', input);
String response = result.generations[0].response;
```

Verify the exact namespace and method in your org's API version -- the ConnectApi surface for prompt templates has shifted across releases.

---

## 14. Safety Block Inside Every Template

LLM safety is template-author responsibility. Always include:

```
SAFETY:
- Do not include personal identifying information (names, email, phone, address, SSN) in the output.
- Only use information from the inputs and capability outputs provided above. Do not invent details.
- Do not generate harmful, offensive, or misleading content.
- If inputs are insufficient, return exactly: {"error": "Insufficient information"}.
- Do not reference systems, companies, or people not present in the provided data.
```

The Trust Layer's masking and toxicity scoring are a backstop, not a substitute for explicit safety instructions in the prompt body.

---

## 15. Validation Checklist

Before deploying a prompt template version:

- [ ] `<type>` is correct for the surface (`flex` for agent-callable, `field_generation`/`record_summary`/`sales_email` for fixed surfaces).
- [ ] `<visibility>` is `Global` if any non-Prompt-Builder consumer (Flow, Apex, agent) invokes it.
- [ ] `<activeVersionIdentifier>` matches a `<versionIdentifier>` with `<status>Published</status>`.
- [ ] Every `<inputs>.<referenceName>` starts with `Input:`.
- [ ] Every `{!$Input:...}` in `<content>` resolves to a declared input.
- [ ] Every `{!$Capability:...}` resolves to a declared `<groundingDataSources>` entry.
- [ ] Apex capability classes deployed before the template.
- [ ] Permission set granting class access deployed (and assigned to running user / `default_agent_user`).
- [ ] Output format spelled out in `<content>` -- JSON keys, value types, enum literals.
- [ ] Safety block present in `<content>`.
- [ ] Tested against 5+ representative records in Prompt Builder Preview.
- [ ] Edge cases tested: null inputs, empty rich text, very long descriptions.
- [ ] Audit trail row for a test invocation reviewed -- rendered prompt, masked prompt, model response inspected.
- [ ] If consumed by an agent: matching action definition in the `.agent` bundle uses `Input:`-prefixed input names and `promptResponse` output.

---

## 16. Common AI Mistakes to Avoid

| # | Mistake (brief) | Correct approach |
|---|---|---|
| 1 | Missing safety instructions | LLM may hallucinate or include PII in output. Add mandatory safety block to every template. |
| 2 | No output format specification | Downstream code cannot reliably parse free-form text -- always specify JSON structure with exact keys. |
| 3 | Grounding too much data | Exceeds token limits; LLM performance degrades. Include only relevant fields; pre-summarize large data with Apex. |
| 4 | Using Prompt Builder for multi-step orchestration | Prompt Builder is single-step only -- use Agentforce for multi-step or agentic workflows. |
| 5 | Not testing with edge-case records | Template fails silently with null/empty data -- test with empty fields and edge cases. |
| 6 | Including PII fields without compliance review | Data privacy violation -- audit all merge fields; exclude PII unless explicitly required and approved. |
| 7 | No logging implementation | Cannot audit or debug AI outputs -- implement custom logging (metadata only, not PII) or rely on Einstein Trust Layer audit trail. |
| 8 | Assuming merge field syntax without verifying | Syntax varies by release; wrong syntax = unresolved fields. Always test merge fields in target environment. |

---

## 17. Empirical Findings & Implementation Notes

When Salesforce's documented approach doesn't work in the target environment, the workaround goes here. Date-stamp every entry.

*(No empirical findings recorded yet. Add as Salesforce doc gaps are discovered. Format: `| # | YYYY-MM-DD | documented approach | what actually works | why / context |`.)*

---

## 18. Official References

- Salesforce Help: [Einstein Prompt Builder Overview](https://help.salesforce.com/s/articleView?id=sf.prompt_builder_overview.htm)
- Salesforce Help: [Prompt Template Types](https://help.salesforce.com/s/articleView?id=sf.prompt_builder_template_types.htm)
- Salesforce Help: [Grounding with Merge Fields](https://help.salesforce.com/s/articleView?id=sf.prompt_builder_merge_fields.htm)
- Salesforce Metadata API: [GenAiPromptTemplate](https://developer.salesforce.com/docs/atlas.en-us.api_meta.meta/api_meta/meta_genaipromptemplate.htm)
- Salesforce Developer: [Prompt Template Overview](https://developer.salesforce.com/docs/einstein/genai/guide/prompt-template-overview.html)
- Salesforce Einstein Trust Layer: [Data Security](https://help.salesforce.com/s/articleView?id=sf.einstein_trust_layer.htm)
- Trailhead: [Get Started with Prompt Builder](https://trailhead.salesforce.com/content/learn/modules/prompt-builder)
- Companion in this repo: `../salesforce-agentforce-script/SKILL.md` Section 9 Prompt-template actions from `.agent` files.

---

*Prompt Builder Template Guidelines | v3.0 | Last verified 2026-05-16*

