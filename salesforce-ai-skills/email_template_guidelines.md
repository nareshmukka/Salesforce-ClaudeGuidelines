# Email Template Guidelines

**Version**: 2.0 (April 2026)
**Developer**: Naresh | Senior Salesforce Developer
**Purpose**: Guidelines for Salesforce email template creation and management. Attach when creating, reviewing, or deploying email templates.

---

## Table of Contents

1. [Required Agent Output Contract](#1-required-agent-output-contract)
2. [Template Types](#2-template-types)
3. [Lightning Email Templates](#3-lightning-email-templates)
4. [Classic Email Templates](#4-classic-email-templates)
5. [Merge Fields](#5-merge-fields)
6. [Folder Access](#6-folder-access)
7. [Org-Wide Email Addresses](#7-org-wide-email-addresses)
8. [Experience Cloud / Customer Emails](#8-experience-cloud--customer-emails)
9. [Localization](#9-localization)
10. [Testing](#10-testing)
11. [Deployment](#11-deployment)
12. [Common AI Mistakes to Avoid](#12-common-ai-mistakes-to-avoid)
13. [Definition of Done](#13-definition-of-done)
14. [Validation Commands](#14-validation-commands)
15. [Official References](#15-official-references)

---

## 1. Required Agent Output Contract

When generating or modifying an email template, the AI agent MUST produce:

### 1.1 Template Type and Context

```
Template Type: Lightning HTML / Classic Text / Classic HTML / Visualforce
Object Context: Case (defines which merge fields are available)
Template Name (API): Case_Support_Acknowledgement
Label: Case Support Acknowledgement
Folder: Support_Team_Templates
```

### 1.2 Object Context and Merge Fields Used

List every merge field and confirm the field exists on the specified object:

```
Merge Fields:
- {!Case.CaseNumber}         -> Case number for customer reference
- {!Case.Subject}            -> Summary of the reported issue
- {!Case.Status}             -> Current case status
- {!Contact.FirstName}       -> Recipient's first name (via Case.Contact)
- {!Organization.Name}       -> Org name for signature
```

### 1.3 Folder

```
Folder: Support_Team_Templates (shared folder — visible to all support profiles)
Folder Access: Read for all Support users; Write for Support Lead and above
```

### 1.4 Test Plan

```
- Send test from Case record with real data
- Verify {!Case.CaseNumber} resolves correctly
- Verify {!Contact.FirstName} resolves when Case has a linked Contact
- Test fallback when Contact is null
- Verify rendering in Gmail, Outlook, Apple Mail
- Verify From address is org-wide email, not personal user email
```

---

## 2. Template Types

### 2.1 Lightning HTML Email Templates (Recommended)

- Created in Lightning Experience via the Email Templates tab or Setup.
- Supports enhanced letterhead, drag-and-drop builder, and HTML editing.
- Supports merge fields from related objects.
- Can be used in: Email alerts (Flow), Send Email action, Cadences (Sales Engagement).
- **Use for all new email template development.**

### 2.2 Classic Text Templates

- Plain text — no HTML formatting.
- Use only when the email channel does not support HTML (e.g., some SMS-to-email integrations).
- Merge field syntax same as HTML templates.

### 2.3 Classic HTML Templates

- HTML templates created in Classic Salesforce Setup.
- Supports basic HTML formatting but not the full Lightning HTML template builder.
- Use only when a legacy automation requires it or Lightning HTML is not supported by the workflow.
- Being gradually replaced by Lightning HTML templates.

### 2.4 Visualforce Email Templates

- Full Apex-controller power; can include dynamic content, iteration, conditional blocks.
- Required for: complex conditional content, iterating over child records, advanced formatting logic.
- Higher maintenance cost — requires developer to maintain.
- Use only when Lightning HTML templates cannot meet the requirements.
- See `visualforce_guidelines.md` for controller design rules.

### Template Type Decision Table

| Requirement | Recommended Type |
|---|---|
| Standard transactional email | Lightning HTML |
| Email with company letterhead/branding | Lightning HTML |
| Simple plain-text notification | Classic Text |
| Legacy automation that only accepts Classic | Classic HTML |
| Iterate over related records (e.g., list products on order) | Visualforce |
| Complex conditional formatting | Visualforce |
| PDF attachment generated dynamically | Visualforce |

---

## 3. Lightning Email Templates

### Structure

A Lightning HTML Email Template consists of:
- **Subject**: Can include merge fields.
- **HTML Body**: Full HTML content with merge fields and optional letterhead.
- **Text Body**: Plain-text fallback for email clients that do not render HTML.
- **Letterhead** (optional): Pre-defined header/footer branding.
- **Related Object**: Defines the namespace for merge fields.

### Example Template Structure

**Subject**: Your Case `{!Case.CaseNumber}` Has Been Received — `{!Case.Subject}`

**HTML Body**:
```html
<html>
<body>
<p>Dear {!Case.Contact.FirstName},</p>

<p>Thank you for contacting our support team. We have received your case and will be in touch shortly.</p>

<table>
  <tr><td><strong>Case Number:</strong></td><td>{!Case.CaseNumber}</td></tr>
  <tr><td><strong>Subject:</strong></td><td>{!Case.Subject}</td></tr>
  <tr><td><strong>Priority:</strong></td><td>{!Case.Priority}</td></tr>
  <tr><td><strong>Status:</strong></td><td>{!Case.Status}</td></tr>
</table>

<p>If you have additional information to add, please reply to this email.</p>

<p>Best regards,<br/>
{!Organization.Name} Support Team</p>
</body>
</html>
```

**Text Body**:
```
Dear {!Case.Contact.FirstName},

Thank you for contacting support. Your case has been received.

Case Number: {!Case.CaseNumber}
Subject: {!Case.Subject}
Priority: {!Case.Priority}
Status: {!Case.Status}

Best regards,
{!Organization.Name} Support Team
```

### Rules

- Always provide both HTML body and plain-text body.
- HTML must be well-formed — unclosed tags can break rendering.
- Inline CSS is more reliable than external stylesheets in email clients.
- Test in multiple email clients (Gmail, Outlook, Apple Mail) — CSS support varies significantly.

---

## 4. Classic Email Templates

### When Still Appropriate

- Legacy automations (Workflow Rules, classic Process Builder) that were built before Lightning templates were available.
- When a third-party integration explicitly requires the Classic template format.
- When migrating an existing Classic template and there is no time/budget to rebuild in Lightning HTML.

### Migration Path

If you are creating a new Classic template because an existing process uses it:
- Document the template as "Classic — legacy. Planned migration to Lightning HTML by [target date]."
- Flag it in the project backlog for migration when the automation is next touched.

### Classic Template Example

```
Subject: Case {!Case.CaseNumber} - Update

Dear {!Case.Contact.FirstName},

Your case {!Case.CaseNumber} regarding "{!Case.Subject}" has been updated.
Current status: {!Case.Status}

Please contact us if you have questions.

{!Organization.Name} Support Team
```

---

## 5. Merge Fields

### Syntax

```
{!ObjectApiName.FieldApiName}
```

### Available Namespace by Template Type

The merge field namespace depends on the **Related Object** set on the template:
- A Case template can access `{!Case.FieldName}` and related objects via relationships.
- A Contact template can access `{!Contact.FieldName}`.

### Common Merge Field Examples

```
{!Case.CaseNumber}              -> Unique case number
{!Case.Subject}                 -> Case subject
{!Case.Status}                  -> Current status
{!Case.Priority}                -> Priority level
{!Case.Description}             -> Case description (be careful with length)
{!Case.Contact.FirstName}       -> Contact first name via lookup
{!Case.Contact.LastName}        -> Contact last name
{!Case.Contact.Email}           -> Contact email
{!Case.Account.Name}            -> Account name via lookup
{!Case.Owner.Name}              -> Case owner name
{!Case.Owner.Email}             -> Case owner email
{!Organization.Name}            -> Org name
{!Organization.Phone}           -> Org phone
{!Receiving_User.FirstName}     -> Recipient's first name (contextual)
```

### Conditional Content with IF Function

For conditional content in Classic and some Visualforce templates:

```
{!IF(Case.Status = "Closed", "Your case has been resolved.", "We are working on your case.")}
```

In Lightning HTML templates, conditional content is handled via dynamic content sections in the builder.

### Rules

- Always test merge fields with real records — fields that look correct in the template may fail to resolve if the relationship is not populated.
- If a related field can be null (e.g., `Case.Contact` may not always be linked), handle the null case in the template text.
- Never reference fields that contain sensitive/confidential internal data (e.g., internal notes, cost fields) in customer-facing templates.
- Merge fields in the Subject line are processed the same as in the body — they can also fail to resolve.

---

## 6. Folder Access

### Overview

Email templates are stored in folders. Folder access controls who can view and use the templates. This is a critical aspect of template governance — a support template should not be accessible to the entire org, and vice versa.

### Folder Types

| Folder Type | Description |
|---|---|
| Public (unfiled) | Accessible to all users — avoid for role-specific templates |
| Shared Public Folder | Created and shared with specific groups/roles |
| Private Folder | Accessible only to the owner |

### Rules

- Never store email templates in the "Unfiled Public Classic Email Templates" folder unless they are genuinely org-wide.
- Create role- or team-specific folders for role-specific templates.
- Set folder sharing: Read access for users who send the template; Write/Manage access for the template owners.
- Document folder structure in the email template naming convention.

### Folder Naming Convention

```
<Team>_<Domain>_Templates
```

Examples:
- `Support_Team_Templates`
- `Sales_Outbound_Templates`
- `Finance_Billing_Templates`

### Deployment Consideration

EmailTemplate folders are a separate metadata type. The folder must be deployed before the templates inside it. See Section 11 for deployment details.

---

## 7. Org-Wide Email Addresses

### Rules

- All automated emails must use an **Org-Wide Email Address** as the From address, not a personal user email.
- Personal email addresses change when staff leave; org-wide addresses are stable.
- Org-Wide Email Addresses are configured in Setup > Email > Organization-Wide Addresses.
- When setting up an email alert or Flow that sends email via a template, explicitly configure the From address to use the appropriate org-wide address.

### Common Org-Wide Addresses to Define

| Address | Purpose |
|---|---|
| `support@company.com` | Customer support email notifications |
| `noreply@company.com` | System notifications that do not expect replies |
| `billing@company.com` | Billing-related automated emails |
| `sales@company.com` | Sales outreach templates |

### Setting From Address in Flow Send Email Action

In a Flow Send Email action:
- **From Address Type**: Org-Wide Email Address
- **From Address**: Select `support@company.com` (or appropriate org-wide address)

### Never Use

- Personal user email addresses (`{!$User.Email}`) as the From address for automated emails.
- Default user email for system-triggered emails.

---

## 8. Experience Cloud / Customer Emails

### Compatibility

Not all email templates are compatible with all Salesforce channels. Verify:
- Lightning HTML templates work with Experience Cloud email actions — check in your target org.
- Some Experience Cloud email actions may require specific template types.
- Community-specific branding (logo, colors) may need to be applied via the template letterhead or inline CSS.

### Community-Specific Considerations

- If your Experience Cloud site has a distinct brand from the main Salesforce org, create separate templates with community branding.
- Do not reuse internal support email templates for customer-facing Experience Cloud emails — the tone, branding, and content should differ.
- Verify reply-to address for Experience Cloud emails — replies from customers should route to the correct queue or inbox.

### Testing in Experience Cloud Context

- Send a test email from within the Experience Cloud context (not just from the internal org) to verify rendering.
- Confirm merge fields resolve correctly in the Experience Cloud user context.

---

## 9. Localization

### Multi-Language Email Templates

When your org serves customers in multiple languages:

#### Option 1: Separate Template per Language

- Create one template per language: `Case_Support_Acknowledgement_EN`, `Case_Support_Acknowledgement_FR`, etc.
- Use Flow logic to select the correct template based on the Case Contact's preferred language or Account locale.
- Pros: Full control over content per language. Cons: Maintenance overhead — updates require changing every language template.

#### Option 2: Translation Workbench (Verify Support)

- Salesforce Translation Workbench may support translating template content.
- **Verify in your target org** — Translation Workbench support for email templates varies by template type and Salesforce release.

#### Option 3: Dynamic Merge Fields for Language

- Store translated strings in Custom Metadata (one record per language key).
- Use a Flow or Apex to retrieve the translated string and pass it as a template variable.
- This works when only key phrases need translation, not the full template.

### Rules

- Always confirm the customer's preferred language before sending a localized email.
- Document which languages are supported and which template is used for each.
- Test localized templates with native speaker review — do not rely solely on machine translation.

---

## 10. Testing

### Test Checklist

- [ ] Send a test email from a real Case record (not just the template preview).
- [ ] Verify all merge fields resolve to correct values.
- [ ] Verify merge fields that can be null are handled gracefully (no `{!Case.Contact.FirstName}` appearing literally in the email).
- [ ] Verify the From address is the correct org-wide email address.
- [ ] Verify the Reply-To address is correct.
- [ ] Test rendering in at least 3 email clients: Gmail, Outlook (desktop), Apple Mail.
- [ ] Check the plain-text fallback for clients that do not render HTML.
- [ ] Verify subject line merge fields resolve correctly.
- [ ] Test with a contact record that has special characters in name fields.
- [ ] If multi-language: test each language template with a record set to that locale.

### Email Client Rendering Tips

Email clients implement CSS support differently:
- Outlook (desktop) uses Word to render HTML — many CSS properties not supported.
- Use `<table>` layouts for consistent multi-column email layouts.
- Avoid `<div>` for layout in emails — use `<table>` instead.
- Use inline CSS (style attributes) not external stylesheets.
- Images: use absolute URLs; do not embed images as base64 (email clients often block these).
- Set explicit width on all table elements.

---

## 11. Deployment

### Metadata Type

- Type: `EmailTemplate`
- File extension: `.email-meta.xml` (for metadata) and `.email` (for HTML content)
- Location: `force-app/main/default/email/<FolderName>/`

### Folder as Metadata

Email template folders are deployed as `EmailFolder` metadata type. The folder must exist in the org before the template can be deployed into it.

### package.xml Example

```xml
<!-- Deploy folder first -->
<types>
    <members>Support_Team_Templates</members>
    <name>EmailFolder</name>
</types>

<!-- Then deploy templates -->
<types>
    <members>Support_Team_Templates/Case_Support_Acknowledgement</members>
    <members>Support_Team_Templates/Case_Resolution_Notice</members>
    <name>EmailTemplate</name>
</types>
```

### File Structure

```
force-app/
  main/
    default/
      email/
        Support_Team_Templates/
          Support_Team_Templates-meta.xml        (folder metadata)
          Case_Support_Acknowledgement.email      (HTML body)
          Case_Support_Acknowledgement.email-meta.xml  (template metadata)
```

### Template Metadata File Example

```xml
<?xml version="1.0" encoding="UTF-8"?>
<EmailTemplate xmlns="http://soap.sforce.com/2006/04/metadata">
    <available>true</available>
    <description>Sent to customers when a new Case is created. Provides case number and subject confirmation.</description>
    <encodingKey>UTF-8</encodingKey>
    <name>Case Support Acknowledgement</name>
    <relatedEntityType>Case</relatedEntityType>
    <style>none</style>
    <subject>Your Case {!Case.CaseNumber} Has Been Received</subject>
    <textOnly>Plain text fallback content here.</textOnly>
    <type>html</type>
    <uiType>SFX</uiType>
</EmailTemplate>
```

---

## 12. Common AI Mistakes to Avoid

| Mistake | Why It's Wrong | Correct Approach |
|---|---|---|
| Wrong merge field syntax | `{Case.CaseNumber}` instead of `{!Case.CaseNumber}` — field will not resolve | Always use `{!ObjectName.FieldName}` syntax |
| Using personal user From address | Personal address is unstable; changes when users leave | Always use Org-Wide Email Addresses for automated sends |
| Missing folder deployment | Template deployment fails if folder doesn't exist | Deploy `EmailFolder` before `EmailTemplate` |
| No test send with real record | Template preview may hide resolution failures | Always do a full test send from a real record |
| No plain-text fallback | Users with HTML disabled see a blank email | Always provide a text body |
| Including internal/sensitive data in customer-facing templates | Data exposure risk | Audit all merge fields; no internal fields in customer templates |
| No description on template | Impossible to manage at scale | Every template must have a description |
| Hardcoding the org/company name instead of using merge field | Breaks when org name changes | Use `{!Organization.Name}` |

---

## 13. Definition of Done

An Email Template is complete and deployable when ALL of the following are true:

- [ ] Template type is appropriate (Lightning HTML for new development)
- [ ] Template has a label, API name, and description
- [ ] All merge fields tested with real records — all fields resolve correctly
- [ ] Null/empty field cases handled gracefully in template content
- [ ] From address configured as Org-Wide Email Address (not personal email)
- [ ] Reply-To address confirmed and correct
- [ ] HTML body and plain-text fallback both provided
- [ ] Rendered and tested in at least 3 email clients
- [ ] Template stored in correct folder with appropriate folder sharing
- [ ] Folder deployed before template in deployment plan
- [ ] No sensitive/internal data in customer-facing templates
- [ ] Localization plan documented (if multi-language org)

---

## 14. Validation Commands

```bash
# Retrieve email templates from org
sf project retrieve start \
  --metadata "EmailTemplate" \
  --target-org <alias>

# Retrieve a specific template
sf project retrieve start \
  --metadata "EmailTemplate:Support_Team_Templates/Case_Support_Acknowledgement" \
  --target-org <alias>

# Deploy email folder first, then templates
sf project deploy start \
  --metadata "EmailFolder:Support_Team_Templates" \
  --target-org <alias>

sf project deploy start \
  --metadata "EmailTemplate:Support_Team_Templates/Case_Support_Acknowledgement" \
  --target-org <alias>

# List email templates via SOQL
sf data query \
  --query "SELECT Id, Name, DeveloperName, FolderId, TemplateType, IsActive FROM EmailTemplate ORDER BY Name" \
  --target-org <alias>

# Verify folder exists
sf data query \
  --query "SELECT Id, Name, DeveloperName, Type FROM Folder WHERE Type = 'Email' ORDER BY Name" \
  --target-org <alias>
```

---

## 15. Official References

- Salesforce Help: [Email Templates in Lightning Experience](https://help.salesforce.com/s/articleView?id=sf.email_create_a_template.htm)
- Salesforce Help: [Classic Email Templates](https://help.salesforce.com/s/articleView?id=sf.classic_email_templates.htm)
- Salesforce Help: [Org-Wide Email Addresses](https://help.salesforce.com/s/articleView?id=sf.email_orgwide_address.htm)
- Salesforce Help: [Merge Fields for Email Templates](https://help.salesforce.com/s/articleView?id=sf.merge_field_types.htm)
- Salesforce Metadata API: [EmailTemplate](https://developer.salesforce.com/docs/atlas.en-us.api_meta.meta/api_meta/meta_emailtemplate.htm)
- Trailhead: [Email Templates in Salesforce](https://trailhead.salesforce.com/content/learn/modules/lex_implementation_email)
- Salesforce Help: [Translation Workbench](https://help.salesforce.com/s/articleView?id=sf.workbench_overview.htm)
