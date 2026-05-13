# Prompt Builder Template Guidelines

**Version**: 2.0 (April 2026)
**Developer**: Naresh | Senior Salesforce Developer
**Purpose**: Guidelines for Salesforce Prompt Builder prompt templates. Attach when designing, creating, or reviewing Einstein Prompt Builder templates.

> Prompt Builder and Einstein generative AI features are evolving rapidly. Verify feature availability, merge field syntax, and grounding capabilities in your target org and release before implementing.

---

## Table of Contents

1. [Required Agent Output Contract](#1-required-agent-output-contract)
2. [What Prompt Builder Does](#2-what-prompt-builder-does)
3. [Template Types](#3-template-types)
4. [Grounding](#4-grounding)
5. [Merge Fields](#5-merge-fields)
6. [Flows / Apex for Prompt Inputs](#6-flows--apex-for-prompt-inputs)
7. [Logging Limitations](#7-logging-limitations)
8. [When Prompt Templates Are Not Enough vs Agentforce](#8-when-prompt-templates-are-not-enough-vs-agentforce)
9. [Safety](#9-safety)
10. [Deterministic Output Formatting](#10-deterministic-output-formatting)
11. [Testing / Evaluation](#11-testing--evaluation)
12. [Common AI Mistakes to Avoid](#12-common-ai-mistakes-to-avoid)
13. [Definition of Done](#13-definition-of-done)
14. [Official References](#14-official-references)

---

## 1. Required Agent Output Contract

When generating or modifying a Prompt Builder template, the AI agent MUST produce:

### 1.1 Template Type and Context

```
Template Type: Field Generation / Record Summary / Sales Email / Custom
Object Context: Case
Target Field (if Field Generation): Case.AI_Summary__c
Trigger/Use Context: Summarize Case on record load; triggered from Quick Action
```

### 1.2 Grounding Data Sources

List every data source being fed into the prompt:

```
Grounding Sources:
- Case.Subject (merge field)
- Case.Description (merge field)
- Case.Status (merge field)
- Case.Priority (merge field)
- Related: Last 5 Case Comments (related list grounding)
- Apex Invocable: GetRelatedKnowledgeArticles (returns matching KB article titles)
```

### 1.3 Merge Fields

List all merge fields used and their expected data:

```
{!$Record.Subject}          -> Case subject line
{!$Record.Description}      -> Full case description
{!$Record.Status}           -> Current status value
{!CaseCommentsSummary}      -> Retrieved via Apex invocable
```

### 1.4 Test Inputs / Outputs

Document test cases:

```
Test Case 1:
  Input: Case with Subject="Login Error", Status="Open", Description="User cannot log in after password reset."
  Expected Output: JSON with keys: summary, nextSteps, sentiment
  
Test Case 2:
  Input: Case with empty Description
  Expected Output: Graceful handling — summary field states "Insufficient information provided."
```

### 1.5 Safety Review

- [ ] Safety instructions included in template
- [ ] No PII-returning merge fields included in prompt (or confirmed PII handling is compliant)
- [ ] Output format validated — no free-form text where structured data is expected
- [ ] Hallucination test performed with edge-case record data

---

## 2. What Prompt Builder Does

Salesforce Prompt Builder is a declarative tool that allows admins and developers to create **reusable, grounded prompt templates** that are sent to an LLM (Einstein or third-party via Model Builder) and whose outputs can populate record fields, generate email drafts, summarize records, or drive other AI-powered workflows.

### Core Concepts

| Concept | Description |
|---|---|
| **Template** | A structured prompt definition with placeholders (merge fields) for dynamic data |
| **Merge Fields** | Placeholders in the template that are populated at runtime from Salesforce record data |
| **Grounding** | Feeding real, org-specific data into the prompt context so the LLM responds based on actual record data |
| **LLM / Model** | The AI model that processes the grounded prompt and generates output (Einstein, OpenAI, etc.) |
| **Output** | The text or structured data returned by the LLM; can write to a field, generate an email, etc. |

### What It Is NOT

- Not a conversational agent (no multi-turn conversation).
- Not capable of taking autonomous actions (no tool calls, no record updates — output must be applied by a Flow or user).
- Not a replacement for Agentforce for multi-step or decision-making workflows.

---

## 3. Template Types

> **Important**: Template types available in your org depend on your Salesforce edition, add-ons, and release. Always verify which template types are enabled in your target org before designing a template.

### 3.1 Field Generation

- **Purpose**: Generate content for a specific record field.
- **Example**: Generate a summary in `Case.AI_Summary__c` based on Case fields and related comments.
- **Output**: Typically a single text value written to a field via a Flow.

### 3.2 Record Summary

- **Purpose**: Generate a comprehensive summary of a record for display in the UI.
- **Example**: "Summarize this Account's recent activity and open opportunities."
- **Output**: Text displayed in the Einstein Copilot panel or a custom UI component.

### 3.3 Sales Email

- **Purpose**: Draft a personalized sales email based on Opportunity, Contact, and Account data.
- **Example**: Generate a follow-up email after a meeting logged in the Activity history.
- **Output**: Email draft pre-populated in the email composer.

### 3.4 Custom

- **Purpose**: Any use case not covered by the above types.
- **Example**: Generate a case deflection message, a risk assessment summary, a customer-facing FAQ answer.
- **Output**: Text, JSON, or structured data depending on prompt instructions.

### Template Type Summary Table

| Type | Use Case | Typical Output |
|---|---|---|
| Field Generation | Populate a field with AI-generated content | Text value for a field |
| Record Summary | Summarize a record for the user | Narrative text |
| Sales Email | Draft outbound emails | Email body text |
| Custom | Any other AI text generation | Text / JSON |

---

## 4. Grounding

### What Grounding Means

Grounding means including actual Salesforce data in the prompt context so the LLM generates responses based on real record information rather than hallucinating details. Without grounding, the LLM has no knowledge of your specific data.

### Grounding Mechanisms

| Mechanism | Description |
|---|---|
| **Merge Fields** | Pull values from record fields directly into the prompt text |
| **Related List Grounding** | Pull a list of child records (e.g., last N Case Comments) into the prompt |
| **Flow Inputs** | Compute and pass data that merge fields cannot fetch directly |
| **Apex Invocable Inputs** | Run Apex to retrieve complex or computed data and pass as a prompt variable |

### Example Grounded Prompt

```
You are a Salesforce support AI assistant. Your task is to summarize the following support case.

Case Subject: {!$Record.Subject}
Case Status: {!$Record.Status}
Case Priority: {!$Record.Priority}
Case Description:
{!$Record.Description}

Recent Case Comments:
{!RecentCaseComments}

Instructions:
- Summarize the issue in 2-3 sentences.
- List up to 3 suggested next steps.
- Do not include personal identifying information in the output.
- Only use information from the provided case data above.
- If the description is empty, state: "Insufficient case information provided."

Return your response as a JSON object with these exact keys:
{
  "summary": "<string>",
  "nextSteps": ["<string>", "<string>", "<string>"],
  "sentiment": "<Positive|Neutral|Negative>"
}
```

### Grounding Token Budget

Each model has a maximum context window (token limit). Grounding data consumes tokens. Rules:
- Only include fields that are relevant to the task.
- Truncate or summarize related list data — do not include all records if the list is large.
- Monitor token usage in template preview; Prompt Builder may warn when nearing limits.
- If data volume is too large, use an Apex invocable to pre-summarize before passing to the prompt.

---

## 5. Merge Fields

### Syntax

> **Important**: The exact merge field syntax may vary by Salesforce release and template type. Always verify in your target org's Prompt Builder UI and official documentation.

**General Pattern (verify in org)**:
```
{!$Record.FieldApiName}        -> Direct field on the current record
{!$Record.RelatedObject__r.FieldApiName}  -> Field via lookup relationship
```

### Examples

```
{!$Record.Subject}                          -> Case Subject
{!$Record.Status}                           -> Case Status
{!$Record.Account.Name}                     -> Account Name via lookup
{!$Record.OwnerId}                          -> Owner ID (consider using Owner.Name)
{!$Record.Owner.Name}                       -> Owner's name via relationship
{!$Record.Custom_Field__c}                  -> Custom field
```

### Rules

- Always test merge fields in the Prompt Builder preview to confirm they resolve correctly.
- Merge fields that resolve to null/empty should be handled in the prompt instructions (e.g., "If Description is empty, state...").
- Do not include merge fields for sensitive/PII data unless the use case explicitly requires it and data handling is compliant.
- Related list grounding may have a configurable record limit — document the limit in the template.

### Computed Field Grounding

For data that cannot be fetched via simple merge fields:
1. Create an Apex invocable or Flow element that queries or computes the data.
2. Pass the result as a prompt input variable.
3. Reference the input variable in the template.

---

## 6. Flows / Apex for Prompt Inputs

### When to Use

Use Apex invocables or Flow elements to provide prompt inputs when:
- The required data spans multiple objects that merge fields cannot traverse in one hop.
- The data requires aggregation or computation (e.g., "count of open cases this month").
- A related list needs preprocessing (truncation, summarization) before inclusion in the prompt.
- External system data needs to be fetched and passed into the prompt.

### Apex Invocable Example

```apex
/**
 * Description: Retrieves related Knowledge article titles for a Case.
 * Developer: Naresh
 * Title: Senior Salesforce Developer
 */
public with sharing class GetRelatedKnowledgeArticles {

    public class Request {
        @InvocableVariable(label='Case ID' required=true)
        public Id caseId;
    }

    public class Response {
        @InvocableVariable(label='Article Titles Summary')
        public String articleTitlesSummary;
    }

    @InvocableMethod(label='Get Related Knowledge Articles' description='Returns a summary of related KB article titles for a Case.')
    public static List<Response> getArticles(List<Request> requests) {
        List<Response> responses = new List<Response>();
        for (Request req : requests) {
            List<CaseArticle> articles = [
                SELECT KnowledgeArticle.Title
                FROM CaseArticle
                WHERE CaseId = :req.caseId
                WITH USER_MODE
                LIMIT 5
            ];
            List<String> titles = new List<String>();
            for (CaseArticle ca : articles) {
                titles.add(ca.KnowledgeArticle.Title);
            }
            Response res = new Response();
            res.articleTitlesSummary = titles.isEmpty()
                ? 'No related articles found.'
                : String.join(titles, '; ');
            responses.add(res);
        }
        return responses;
    }
}
```

### Using the Invocable in a Prompt Template

In the Prompt Builder template, configure the Apex invocable as an input:
1. Add a "Flow / Apex Input" in the template configuration.
2. Select the `GetRelatedKnowledgeArticles` invocable method.
3. Map the Case record ID to `caseId` input.
4. The output `articleTitlesSummary` becomes a variable in the template: `{!articleTitlesSummary}`.

---

## 7. Logging Limitations

### Known Limitation

Prompt Builder does not automatically log:
- The grounded prompt text sent to the LLM.
- The LLM's raw output.
- Which user triggered the prompt and when.

This is a significant gap for audit, compliance, and debugging.

### Recommended Approach

Implement custom logging:

1. Create a custom object `PromptLog__c` with fields:
   - `Template_Name__c` (Text)
   - `Record_Id__c` (Text)
   - `User__c` (Lookup to User)
   - `Timestamp__c` (DateTime)
   - `Input_Summary__c` (Long Text Area — store a hash or summary, NOT the full prompt if it contains PII)
   - `Output_Summary__c` (Long Text Area — store output or a hash)
   - `Status__c` (Picklist: Success / Error)

2. Trigger logging via the Flow that calls the prompt template — before and after the LLM call.

3. **Do NOT log PII** in prompt variables or outputs. If the prompt processes PII-containing fields, log only metadata (record ID, template name, timestamp, status) — not the field values.

### Compliance Note

If your org handles regulated data (GDPR, HIPAA, SOC2), consult your legal/compliance team on:
- Whether AI-generated outputs that reference regulated data must be logged.
- Data residency requirements for LLM API calls.
- Retention policy for any AI prompt logs.

---

## 8. When Prompt Templates Are Not Enough vs Agentforce

### Decision Table

| Use Case | Tool |
|---|---|
| Generate a summary for a single record field | Prompt Builder (Field Generation template) |
| Generate a draft email based on a record | Prompt Builder (Sales Email template) |
| Summarize a record on-screen for the user | Prompt Builder (Record Summary template) |
| Single-step text generation with record grounding | Prompt Builder |
| Multi-step workflow: query data, make decisions, take actions | Agentforce (Einstein Agent) |
| Conversational interaction where the user asks follow-up questions | Agentforce |
| Agent that can call multiple tools, APIs, and Salesforce actions in sequence | Agentforce |
| Autonomous monitoring and response (e.g., detect risk, send notification, update record) | Agentforce |
| Real-time chat interface embedded in Experience Cloud | Agentforce |

### Summary Rule

- **Prompt Builder** = static, single-step, grounded text generation. Input → LLM → Output.
- **Agentforce** = dynamic, multi-step, action-taking, conversational AI. Topic → Plan → Tool Calls → Response.

Do not use Prompt Builder templates to simulate a multi-step agent by chaining prompts in Flows. If you find yourself doing this, evaluate Agentforce instead.

---

## 9. Safety

### Required Safety Instructions

Every Prompt Builder template MUST include safety instructions within the prompt text itself. Do not assume the LLM will behave safely without explicit instructions.

### Mandatory Safety Block

Include this (or equivalent) in every template:

```
IMPORTANT INSTRUCTIONS:
- Do not include personal identifying information (names, email addresses, phone numbers, addresses) in your response.
- Only use information provided in the case data above. Do not invent or assume any details not present in the input.
- Do not generate harmful, offensive, or misleading content.
- If the input data is insufficient to generate a meaningful response, state clearly: "Insufficient information to generate a summary."
- Do not reference any systems, companies, or people not mentioned in the provided data.
```

### Hallucination Testing

Test each template with:
1. A fully populated record — verify output uses only provided data.
2. A sparse record (empty optional fields) — verify graceful handling.
3. A record with unusual or edge-case values — verify the LLM does not confabulate.
4. A record where a merge field returns null — verify the template handles null gracefully.

### PII / Data Privacy

- Audit every merge field in the template. If any field contains PII (name, email, SSN, DOB), confirm:
  - The use case requires it.
  - Data handling is compliant with your organization's privacy policy.
  - The output does not expose or repeat PII unnecessarily.
- When in doubt, exclude PII fields from the grounding data and use anonymized identifiers.

---

## 10. Deterministic Output Formatting

### Why It Matters

LLMs produce variable free-form text by default. If downstream code (a Flow, an Apex class, a UI component) needs to parse the output, free-form text is unreliable. Specify the exact output format in the template.

### Rules

- Always specify the output format in the template instructions.
- Prefer JSON for structured outputs — it is machine-parseable.
- Specify every field name, type, and acceptable values in the prompt.
- If the downstream system reads specific keys from the output, test that the LLM consistently returns those exact keys.

### Example: Structured JSON Output Instruction

```
Return your response as a valid JSON object with EXACTLY these keys and value types:
{
  "summary": "<string: 2-3 sentence summary of the case>",
  "nextSteps": ["<string>", "<string>", "<string>"],
  "sentiment": "<string: must be exactly one of: Positive, Neutral, Negative>",
  "urgencyScore": <integer: 1 to 5, where 5 is most urgent>
}

Do not include any text before or after the JSON object. Do not include markdown code fences.
```

### Parsing in Apex / Flow

```apex
// After receiving LLM output in Apex
String rawOutput = llmOutput; // from the prompt template result
Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(rawOutput);
String summary = (String) parsed.get('summary');
Integer urgencyScore = (Integer) parsed.get('urgencyScore');
```

If the LLM occasionally adds text around the JSON, use a regex or string parsing approach to extract the JSON block before deserializing.

---

## 11. Testing / Evaluation

### Test Process

1. **Open the template in Prompt Builder UI** — use the Preview panel with a real record.
2. **Verify all merge fields resolve**: Check that no field shows as null or unresolved. If a merge field fails to resolve, it will be blank or error in the output.
3. **Check output format**: Confirm the LLM returns the expected structure (JSON keys, value types).
4. **Review for hallucination**: Read the output critically — does it contain any information NOT present in the grounding data?
5. **Test edge cases**:
   - Empty Description field
   - Very long Description field (token limit)
   - Unusual characters or formatting in field values
   - Non-English content (if multilingual support is required)
6. **Test with multiple representative records**: One test is not enough — run against at least 5–10 diverse records.
7. **Validate receiving code**: Run the Flow or Apex that consumes the prompt output with the test outputs to confirm parsing succeeds.

### Evaluation Metrics

| Metric | Pass Criteria |
|---|---|
| Merge field resolution rate | 100% — all fields must resolve |
| Output format compliance | LLM returns expected JSON structure in all test cases |
| Hallucination rate | 0% — no invented details in output |
| Safety instruction compliance | No PII, no harmful content in output |
| Edge case handling | Graceful output for empty/null fields |

---

## 12. Common AI Mistakes to Avoid

| Mistake | Why It's Wrong | Correct Approach |
|---|---|---|
| Missing safety instructions | LLM may hallucinate or include PII in output | Add mandatory safety block to every template |
| No output format specification | Downstream code cannot reliably parse free-form text | Always specify JSON structure with exact keys |
| Grounding too much data | Exceeds token limits; LLM performance degrades | Include only relevant fields; pre-summarize large data with Apex |
| Using Prompt Builder for multi-step orchestration | Prompt Builder is single-step only | Use Agentforce for multi-step or agentic workflows |
| Not testing with edge-case records | Template fails silently with null/empty data | Test with empty fields and edge cases |
| Including PII fields without compliance review | Data privacy violation | Audit all merge fields; exclude PII unless explicitly required and approved |
| No logging implementation | Cannot audit or debug AI outputs | Implement custom logging (metadata only, not PII) |
| Assuming merge field syntax without verifying | Syntax varies by release; wrong syntax = unresolved fields | Always test merge fields in target org |

---

## 13. Definition of Done

A Prompt Builder template is considered complete when ALL of the following are true:

- [ ] Template type confirmed and appropriate for use case
- [ ] All merge fields tested and verified resolving in target org
- [ ] Grounding sources documented: which fields, related lists, Apex/Flow inputs
- [ ] Safety instructions included in template body
- [ ] Output format specified (JSON with explicit keys and types)
- [ ] Edge case tests performed (empty fields, null values, long text)
- [ ] No PII exposure — all merge fields reviewed for data privacy compliance
- [ ] Hallucination test passed — output uses only grounded data
- [ ] Downstream Flow/Apex that consumes the output tested with sample outputs
- [ ] Custom logging implemented for audit trail (if required by compliance policy)
- [ ] Template reviewed by a second developer before production deployment

---

## 14. Official References

- Salesforce Help: [Einstein Prompt Builder](https://help.salesforce.com/s/articleView?id=sf.prompt_builder_overview.htm)
- Salesforce Help: [Prompt Template Types](https://help.salesforce.com/s/articleView?id=sf.prompt_builder_template_types.htm)
- Salesforce Help: [Grounding with Merge Fields](https://help.salesforce.com/s/articleView?id=sf.prompt_builder_merge_fields.htm)
- Salesforce Help: [Agentforce Overview](https://help.salesforce.com/s/articleView?id=sf.agentforce_overview.htm)
- Salesforce Einstein Trust Layer: [Data Security](https://help.salesforce.com/s/articleView?id=sf.einstein_trust_layer.htm)
- Trailhead: [Get Started with Prompt Builder](https://trailhead.salesforce.com/content/learn/modules/prompt-builder)
- Salesforce Architect: [AI Design Considerations](https://architect.salesforce.com/decision-guides/ai)
