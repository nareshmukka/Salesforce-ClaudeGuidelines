---
name: salesforce-email-template
description: Production Salesforce AI skill for Lightning/Classic email template creation/review.
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
- The task involves Lightning/Classic email template creation/review.
- The user asks for implementation, refactor, troubleshooting, review, or best-practice validation in this area.
- The assistant must produce Salesforce-safe code/metadata with explicit security/testing notes.

## DO NOT TRIGGER when
- The task is unrelated to this component.
- Another specialized skill is the primary owner and this area is only incidental.
- The user asks for operational execution (deploy/publish/activate/destructive change) without explicit approval.

## Cross-skill routing
- Always read `../salesforce-global-development/SKILL.md`.
- Also read: Global Development + Prompt Template + Permissions + Deployment.
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
Choose Lightning templates for modern use cases; maintain Classic only where required. Validate merge fields and default fallbacks. Treat customer send as approval-gated operation.

## Examples
### Good example patterns
1. Template uses safe fallback text when optional merge fields are null.
2. Pre-send checklist includes rendering test for multiple personas/locales.

### Bad examples / avoid
1. Template directly inserts unresolved merge syntax into customer text.
2. Auto-send instructions without user confirmation.

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

# Email Template Guidelines

Authoritative reference for `EmailTemplate` metadata in this project. Covers the metadata XML shape, the five template types, merge-field anatomy, folder placement, attachments, branding, Apex-side rendering (`Messaging.renderStoredEmailTemplate`), and the agent-side `GetEmailTemplateAction` pattern used by `Email_Template_Drafting` in the `Email_Analysis_Agent` bundle.

**Verified against:** [EmailTemplate Metadata API reference](https://developer.salesforce.com/docs/atlas.en-us.api_meta.meta/api_meta/meta_emailtemplate.htm) - [Messaging.SingleEmailMessage Apex reference](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Messaging_SingleEmailMessage.htm) - [Outbound Email from Apex](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_classes_email_outbound_messaging.htm). Last verified 2026-05-16.

---

## 1. File Layout

A deployable email template lives in two files under a folder:

```
force-app/main/default/email/
   <FolderDevName>/
      <FolderDevName>-meta.xml                    # EmailFolder metadata (deploy first)
      <TemplateDevName>.email                     # body content (HTML or text)
      <TemplateDevName>.email-meta.xml            # EmailTemplate metadata wrapper
```

**Critical:** the folder must exist in the org before the template can deploy into it. The `.email` filename, `name` attribute in the meta XML, and the `members` entry in `package.xml` (`<FolderDevName>/<TemplateDevName>`) must all align -- case-sensitive.

Visualforce email templates additionally need the linked controller class deployed; Lightning templates store their body in `EmailTemplate.HtmlValue` and don't require a `.email` companion file -- they ship as a `LightningEmailTemplate` (Content Builder) record retrieved as part of `EmailTemplate`.

---

## 2. The Five `TemplateType` Values

`type` is the discriminator on the `EmailTemplate` metadata element. Pick one per template.

| `type` | Where created | Body source | Use when |
|---|---|---|---|
| `text` | Classic Setup | `textOnly` field | Plain-text-only notifications, SMS-to-email bridges |
| `html` | Classic Setup | `.email` HTML body | Legacy automations that pre-date Lightning, classic email alerts |
| `custom` | Classic Setup with custom HTML, no letterhead | `.email` HTML body | Classic HTML without letterhead constraints |
| `visualforce` | Developer Console / VS Code | `.email` with `<messaging:emailTemplate>` markup | Iteration over child records, conditional rendering, dynamic PDF attachments |
| `lightning` | Lightning Email Templates app / Email tab | Stored in `HtmlValue`/`Body` on the runtime record | All new development |

**Default for new work:** `lightning`. Only fall back to `visualforce` when you need iteration, conditional content blocks the Lightning Builder can't express, or programmatic PDF generation. Only fall back to `text`/`html`/`custom` when migrating or when a legacy automation explicitly requires it.

---

## 3. EmailTemplate Metadata Structure

Authoritative field list (Metadata API). Required fields marked **req**.

| Field | Type | Notes |
|---|---|---|
| `apiVersion` | double | API version of the template. Optional. |
| `available` | boolean **req** | `true` to allow use in lists. Default `true`. |
| `attachments` | Attachment[] | Inline attachments -- `name`, `content` (base64), `contentType`. |
| `description` | string | Free-text. Every template MUST have one (governance). |
| `encodingKey` | enum **req** | `UTF-8` (preferred), `ISO-8859-1`, `Shift_JIS`, `ISO-2022-JP`, `EUC-JP`, `ks_c_5601-1987`, `Big5`, `GB2312`. |
| `letterhead` | string | API name of the Classic letterhead. Only for `type: html`. |
| `name` | string **req** | Display label. |
| `packageVersions` | PackageVersion[] | For managed-package dependencies. |
| `relatedEntityType` | string | The SObject the merge-field namespace is rooted at (e.g. `Case`, `Contact`, `Account`). Sets the `{!Case.Field}` scope. |
| `style` | enum | `none`, `freeForm`, `formalLetter`, `promotionRight`, `promotionLeft`, `newsletter`, `products`. |
| `subject` | string | Subject line. Supports merge fields. |
| `templateStyle` | enum | Lightning-only styling profile. |
| `textOnly` | string | Plain-text fallback body. Required for `type: text`; recommended for every type. |
| `type` | enum **req** | `text` / `html` / `custom` / `visualforce` / `lightning`. |
| `uiType` | enum | `Aloha` (Classic UI), `SFX` (Lightning UI), `SFX_SAMPLE`. Set to `SFX` for all new templates. |

### Minimal `lightning` template meta XML

```xml
<?xml version="1.0" encoding="UTF-8"?>
<EmailTemplate xmlns="http://soap.sforce.com/2006/04/metadata">
    <available>true</available>
    <description>Sent to customers when a new Case is created.</description>
    <encodingKey>UTF-8</encodingKey>
    <name>Case Support Acknowledgement</name>
    <relatedEntityType>Case</relatedEntityType>
    <style>none</style>
    <subject>Your Case {!Case.CaseNumber} has been received</subject>
    <textOnly>Plain text fallback for non-HTML clients.</textOnly>
    <type>lightning</type>
    <uiType>SFX</uiType>
</EmailTemplate>
```

### Visualforce template

```xml
<?xml version="1.0" encoding="UTF-8"?>
<EmailTemplate xmlns="http://soap.sforce.com/2006/04/metadata">
    <available>true</available>
    <description>Order confirmation with line-item table.</description>
    <encodingKey>UTF-8</encodingKey>
    <name>Order Confirmation</name>
    <relatedEntityType>Order</relatedEntityType>
    <style>none</style>
    <subject>Order {!relatedTo.OrderNumber} confirmed</subject>
    <type>visualforce</type>
    <uiType>Aloha</uiType>
</EmailTemplate>
```

The `.email` body uses `<messaging:emailTemplate recipientType="Contact" relatedToType="Order">` and may invoke an Apex controller via `<apex:component controller="...">`.

---

## 4. Merge Fields

### Syntax

```
{!ObjectApiName.FieldApiName}
{!ObjectApiName.LookupApiName.FieldApiName}
```

The leading `!` is mandatory -- `{Case.CaseNumber}` does not resolve.

### Namespace by template type

The accessible namespace is governed by `relatedEntityType` (Lightning, Classic) or the `recipientType` / `relatedToType` attributes (Visualforce):

- Lightning / Classic: `{!<relatedEntityType>.Field}` plus traversals via lookups (e.g. `{!Case.Contact.FirstName}`).
- Visualforce: `{!recipient.Field}` for the WhoId record, `{!relatedTo.Field}` for the WhatId record.

### Standard global namespaces

```
{!Organization.Name}              # the running Salesforce org
{!Organization.Phone}
{!Organization.Street}
{!User.FirstName}                 # the running user -- avoid for automated sends
{!Receiving_User.FirstName}       # the recipient if a Salesforce user
```

### Conditional content

Classic and Visualforce templates support the IF function:

```
{!IF(Case.Status = "Closed", "Your case is resolved.", "We are working on your case.")}
```

Lightning templates handle conditional content through Dynamic Content blocks in the Builder UI -- not via `{!IF(...)}` literals.

### Null-traversal trap

`{!Case.Contact.FirstName}` resolves only when `Case.ContactId` is populated. If the lookup is null, Lightning renders an empty string; Classic may render the literal `{!Case.Contact.FirstName}`. Always guard with a fallback (e.g. `"Hi {!IF(ISBLANK(Case.Contact.FirstName), "there", Case.Contact.FirstName)}"`) for customer-facing templates.

---

## 5. Target Object vs Related Object -- WhoId vs WhatId

The single most-confused concept in template sending. Salesforce splits the runtime context into two parameters:

| Concept | Apex setter | Holds | Merge-field root |
|---|---|---|---|
| **Target Object** (a.k.a. recipient, WhoId) | `setTargetObjectId(Id)` | Contact, Lead, or User Id -- the human who receives the email | `{!Contact.*}` or `{!Lead.*}` or `{!recipient.*}` |
| **Related Object** (WhatId) | `setWhatId(Id)` | Any SObject -- the business record the email is *about* | `{!<relatedEntityType>.*}` or `{!relatedTo.*}` |

**Rule:** `setTargetObjectId` MUST be a Contact, Lead, or User. Setting it to a Case Id, Account Id, or Custom Object Id raises `INVALID_ID_FIELD`. The related business record goes in `setWhatId`.

For a Case template that addresses `Case.Contact` about the Case itself:
- `setTargetObjectId(case.ContactId)` -- recipient
- `setWhatId(case.Id)` -- the related Case for `{!Case.*}` merge fields

If you need to email an Account contact about an Order, set `targetObjectId = contact.Id`, `whatId = order.Id`, and put `{!Order.*}` merge fields in the template.

---

## 6. Sending Templates from Apex

### Pattern A -- Send via `Messaging.sendEmail` (one-shot send)

```apex
Messaging.SingleEmailMessage msg = new Messaging.SingleEmailMessage();
msg.setTemplateId(templateId);                     // EmailTemplate.Id
msg.setTargetObjectId(contactId);                  // Contact / Lead / User
msg.setWhatId(caseId);                             // related business record
msg.setOrgWideEmailAddressId(orgWideAddressId);    // stable From
msg.setSaveAsActivity(true);                       // logs as Activity on Case
msg.setTreatTargetObjectAsRecipient(true);

Messaging.SendEmailResult[] results =
    Messaging.sendEmail(new Messaging.SingleEmailMessage[]{ msg }, false);

if (!results[0].isSuccess()) {
    AppLog.error('Email send failed', results[0].getErrors());
}
```

Note: `setTemplateId` with a `lightning` template requires `setTreatTargetObjectAsRecipient(true)` for the merge to resolve.

### Pattern B -- Render only, return the bound text (used by agents and previews)

```apex
Messaging.SingleEmailMessage rendered =
    Messaging.renderStoredEmailTemplate(templateId, whoId, whatId);

String subject = rendered.getSubject();            // merge fields resolved
String htmlBody = rendered.getHtmlBody();
String textBody = rendered.getPlainTextBody();
```

`renderStoredEmailTemplate` does NOT send. It resolves the merge fields and returns the rendered message for inspection, preview, or downstream handoff. This is what `GetEmailTemplateAction` uses (Section 8 Common send errors

| Error | Cause | Fix |
|---|---|---|
| `INVALID_ID_FIELD: target object id` | `setTargetObjectId` is not a Contact/Lead/User | Pass a `WhoId`-eligible record |
| `TEMPLATE_NOT_FOUND` | `templateId` is null, soft-deleted, or in a folder the running user can't access | Verify ID + folder share + active state |
| `TEMPLATE_NOT_ACTIVE` | Template is not in an active state | Activate the template in the source org |
| `NO_RECIPIENTS` | `setToAddresses` empty AND no `setTargetObjectId` | Provide at least one |
| `INVALID_EMAIL_ADDRESS` | Target Contact has null/invalid `Email` | Validate before send |
| `LIMIT_EXCEEDED` | Daily org email limit hit (5,000 external) | Throttle or batch |
| Empty body on send | `setTreatTargetObjectAsRecipient(false)` for a Lightning template | Set to `true` |

---

## 7. Folders, Sharing, Branding, Attachments

### Folders

Email templates live inside an `EmailFolder` (Classic, VF, custom, html, text templates) or in `Public/Private/Shared Folders` for Lightning templates. Folder access controls visibility.

```xml
<!-- Folder meta XML -->
<?xml version="1.0" encoding="UTF-8"?>
<EmailFolder xmlns="http://soap.sforce.com/2006/04/metadata">
    <accessType>Shared</accessType>
    <name>Support Team Templates</name>
    <publicFolderAccess>ReadWrite</publicFolderAccess>
</EmailFolder>
```

Naming convention: `<Team>_<Domain>_Templates` (e.g. `Support_Team_Templates`, `Sales_Outbound_Templates`).

### Branding sets

Lightning Experience supports **Branding Sets** (logo, colors, font) applied per Org or per Experience Cloud site. Branding Sets render only when the email is sent from inside the Experience Cloud / Salesforce context that owns them -- external sends fall back to the raw HTML. For Experience Cloud customer emails, verify the branding set is applied at the site level.

Classic templates use a `Letterhead` (`letterhead` field on the EmailTemplate). Letterheads are Classic-only.

### Attachments

Two mechanisms:

1. **Static attachments** declared in the EmailTemplate's `attachments` field -- base64-encoded blobs, deployed with the template. Suitable for unchanging documents (terms, brochures).
2. **Dynamic attachments** added at send time via `Messaging.SingleEmailMessage.setFileAttachments(...)` or by querying `ContentVersion` and converting to `Messaging.EmailFileAttachment`. Required for record-specific PDFs.

Visualforce templates can also generate a PDF attachment in-line using `<messaging:attachment renderAs="pdf">`.

### Encoding

Always `UTF-8` for new work -- supports the full Unicode range our customers use across 30+ markets. The legacy `ISO-8859-1` and `Shift_JIS` values exist for back-compat only.

---

## 8. Agent-Side Usage -- `GetEmailTemplateAction` Pattern

The `Email_Analysis_Agent` bundle (`Email_Template_Drafting` subagent) uses an Apex invocable that wraps `Messaging.renderStoredEmailTemplate` to return a fully-resolved draft to the LLM for refinement. This is the canonical pattern for any agent that drafts replies from templates.

### Apex invocable contract

```apex
public with sharing class GetEmailTemplateAction {

    public class Request {
        @InvocableVariable(required=true)
        public Id caseId;                  // WhatId

        @InvocableVariable(required=true)
        public String templateDeveloperName;   // resolves to EmailTemplate.Id
    }

    public class Response {
        @InvocableVariable public String subject;
        @InvocableVariable public String htmlBody;
        @InvocableVariable public String plainBody;
        @InvocableVariable public String errorMessage;
    }

    @InvocableMethod(label='Get Email Template'
                     description='Render a stored EmailTemplate for the case Contact + Case context')
    public static List<Response> run(List<Request> requests) {
        List<Response> out = new List<Response>();
        for (Request req : requests) {
            Response r = new Response();
            try {
                Case c = [SELECT Id, ContactId FROM Case WHERE Id = :req.caseId LIMIT 1];
                if (c.ContactId == null) {
                    r.errorMessage = 'Case has no Contact; cannot render Target Object.';
                    out.add(r); continue;
                }
                EmailTemplate t = [
                    SELECT Id FROM EmailTemplate
                    WHERE DeveloperName = :req.templateDeveloperName
                    AND IsActive = true LIMIT 1
                ];
                Messaging.SingleEmailMessage rendered =
                    Messaging.renderStoredEmailTemplate(t.Id, c.ContactId, c.Id);
                r.subject   = rendered.getSubject();
                r.htmlBody  = rendered.getHtmlBody();
                r.plainBody = rendered.getPlainTextBody();
            } catch (QueryException qe) {
                r.errorMessage = 'Template not found or inaccessible: ' + qe.getMessage();
            } catch (Exception ex) {
                r.errorMessage = 'Render failed: ' + ex.getMessage();
            }
            out.add(r);
        }
        return out;
    }
}
```

### Agent Script wiring

```
actions:
   get_template:
      description: "Render a stored EmailTemplate for the current Case + Contact."
      label: "Get Email Template"
      inputs:
         caseId: id
            description: "Case Id (WhatId)"
            is_required: True
         templateDeveloperName: string
            description: "EmailTemplate.DeveloperName"
            is_required: True
      outputs:
         subject: string
         htmlBody: string
         plainBody: string
         errorMessage: string
            filter_from_agent: True
      target: "apex://GetEmailTemplateAction"
```

### Error patterns observed in this org

- **Template-not-found:** the LLM asks for a friendly name; the action queries `DeveloperName` not `Name`. Always pass the API name. If the user gave a label, resolve label -> DeveloperName before invoking.
- **Recipient-without-Contact:** `Messaging.renderStoredEmailTemplate(templateId, null, caseId)` returns merge fields like `{!Contact.FirstName}` literally because the Who context is missing. Always check `Case.ContactId` first and short-circuit with a clear error to the agent (then `filter_from_agent: True` so the LLM doesn't echo it verbatim).
- **Lightning template renders blank:** when called with `treatTargetObjectAsRecipient = false` (the implicit default in some Apex paths). `renderStoredEmailTemplate` handles this internally, but `setTemplateId` + `sendEmail` does not -- set explicitly.

---

## 9. Validation Commands

```bash
# Retrieve a template by folder/name
sf project retrieve start \
  --metadata "EmailTemplate:Support_Team_Templates/Case_Support_Acknowledgement" \
  --target-org PlusGradeFullSB

# Deploy folder first, then the template
sf project deploy start \
  --metadata "EmailFolder:Support_Team_Templates" \
  --target-org PlusGradeFullSB

sf project deploy start \
  --metadata "EmailTemplate:Support_Team_Templates/Case_Support_Acknowledgement" \
  --target-org PlusGradeFullSB

# Inspect templates via SOQL
sf data query \
  --query "SELECT Id, Name, DeveloperName, FolderName, TemplateType, IsActive, UiType FROM EmailTemplate WHERE TemplateType IN ('lightning','html','custom','visualforce','text') ORDER BY FolderName, Name" \
  --target-org PlusGradeFullSB

# Confirm a folder exists
sf data query \
  --query "SELECT Id, Name, DeveloperName, Type FROM Folder WHERE Type = 'Email' ORDER BY Name" \
  --target-org PlusGradeFullSB
```

---

## 10. Definition of Done

- [ ] `type` chosen per Section 2 decision table; `uiType` = `SFX` for new templates
- [ ] `relatedEntityType` set to the correct SObject; all `{!Field}` merge fields resolve against it
- [ ] `description` populated (governance-required)
- [ ] `encodingKey` is `UTF-8`
- [ ] Both HTML body and `textOnly` plain-text body provided
- [ ] Folder deployed before template; folder sharing reviewed
- [ ] Test send from a real record -- every merge field resolves to a non-null value
- [ ] Null-lookup paths (e.g. `Case.Contact.*`) guarded with IF/fallback for customer-facing copy
- [ ] Org-Wide Email Address (not a personal user email) used as `From`
- [ ] No internal/confidential fields exposed in customer-facing templates
- [ ] Rendered and tested in Gmail, Outlook desktop, Apple Mail
- [ ] If invoked from Apex: `setTreatTargetObjectAsRecipient(true)` for Lightning templates; recipient is a Contact/Lead/User Id

---

## 11. Common AI Mistakes to Avoid

| Mistake | Why It's Wrong | Correct Approach |
|---|---|---|
| Wrong merge field syntax | `{Case.CaseNumber}` instead of `{!Case.CaseNumber}` -- field will not resolve | Always use `{!ObjectName.FieldName}` syntax |
| Using personal user From address | Personal address is unstable; changes when users leave | Always use Org-Wide Email Addresses for automated sends |
| Missing folder deployment | Template deployment fails if folder doesn't exist | Deploy `EmailFolder` before `EmailTemplate` |
| No test send with real record | Template preview may hide resolution failures | Always do a full test send from a real record |
| No plain-text fallback | Users with HTML disabled see a blank email | Always provide a text body |
| Including internal/sensitive data in customer-facing templates | Data exposure risk | Audit all merge fields; no internal fields in customer templates |
| No description on template | Impossible to manage at scale | Every template must have a description |
| Hardcoding the org/company name instead of using merge field | Breaks when org name changes | Use `{!Organization.Name}` |

---

## 12. Empirical Findings & Implementation Notes

When Salesforce's documented approach doesn't work in this org, the workaround goes here. Date-stamp every entry.

| # | Date | Documented approach | What actually works | Why / Context |
|---|---|---|---|---|

---

## 13. Official References

- [EmailTemplate Metadata API](https://developer.salesforce.com/docs/atlas.en-us.api_meta.meta/api_meta/meta_emailtemplate.htm)
- [Messaging.SingleEmailMessage Apex reference](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Messaging_SingleEmailMessage.htm)
- [Outbound Email from Apex](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_classes_email_outbound_messaging.htm)
- [Email Templates in Lightning Experience](https://help.salesforce.com/s/articleView?id=sf.email_create_a_template.htm)
- [Classic Email Templates](https://help.salesforce.com/s/articleView?id=sf.classic_email_templates.htm)
- [Org-Wide Email Addresses](https://help.salesforce.com/s/articleView?id=sf.email_orgwide_address.htm)
- [Merge Fields for Email Templates](https://help.salesforce.com/s/articleView?id=sf.merge_field_types.htm)
- [Trailhead -- Email Templates in Salesforce](https://trailhead.salesforce.com/content/learn/modules/lex_implementation_email)

---

*Email Template Guidelines | v3.0 | Last verified 2026-05-16*

