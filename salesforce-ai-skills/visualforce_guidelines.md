# Visualforce Development Guidelines

**Version**: 2.0 (April 2026)
**Developer**: Naresh | Senior Salesforce Developer
**Purpose**: Guidelines for Visualforce page development. Attach when writing, reviewing, or migrating Visualforce pages.

> Prefer LWC for new development. Use Visualforce only when justified (PDF rendering, legacy integration, specific API requirements). Always include migration path consideration.

---

## Table of Contents

1. [Required Agent Output Contract](#1-required-agent-output-contract)
2. [When Visualforce Is Still Appropriate](#2-when-visualforce-is-still-appropriate)
3. [Migration Consideration](#3-migration-consideration)
4. [standardController vs Custom Controller vs Extension](#4-standardcontroller-vs-custom-controller-vs-extension)
5. [Controller Class Design](#5-controller-class-design)
6. [View State Limits](#6-view-state-limits)
7. [CRUD / FLS](#7-crud--fls)
8. [Sharing](#8-sharing)
9. [PDF Rendering](#9-pdf-rendering)
10. [JavaScript Remoting](#10-javascript-remoting)
11. [Security Considerations](#11-security-considerations)
12. [Migration Considerations to LWC](#12-migration-considerations-to-lwc)
13. [Common AI Mistakes to Avoid](#13-common-ai-mistakes-to-avoid)
14. [Definition of Done](#14-definition-of-done)
15. [Validation Commands](#15-validation-commands)
16. [Official References](#16-official-references)

---

## 1. Required Agent Output Contract

When generating or modifying a Visualforce page and its controller, the AI agent MUST produce:

### 1.1 Page Purpose

```
Page: CasePdfPage
Purpose: Generate a PDF summary of a Case record for customer download or email attachment.
Controller: CasePdfController (Custom Controller with StandardController extension)
```

### 1.2 Controller Type

```
Controller Type: StandardController with Extension
Justification: PDF rendering requires standard controller record access; extension adds PDF-specific logic.
```

### 1.3 Security Model

```
Sharing Enforcement: with sharing (user context)
CRUD Check: Schema.sObjectType.Case.isAccessible() before query
FLS: WITH USER_MODE on SOQL query
Sensitive Fields: Internal_Notes__c excluded from PDF output
```

### 1.4 PDF Considerations

```
RenderAs: PDF
Page Size: A4 (via CSS @page)
CSS Print Layout: Included in <head>
JavaScript: None (not executed in PDF rendering)
Images: Absolute URL references only
```

### 1.5 Migration Path Assessment

```
Migration Path: This page is PDF-generation-only. LWC does not support native PDF rendering.
Decision: Keep as Visualforce until Salesforce provides a native PDF generation mechanism.
Review Date: Q4 2026 — revisit if Salesforce releases PDF LWC support.
```

---

## 2. When Visualforce Is Still Appropriate

### Decision Table

| Use Case | Use Visualforce? | Reason |
|---|---|---|
| PDF document generation | YES | Salesforce does not provide native PDF rendering in LWC |
| Complex email templates with iteration over related records | YES | Visualforce email templates support Apex-driven content |
| Legacy system integration that requires a specific VF page URL | YES | If the integration is hardcoded to a VF URL; plan migration |
| Custom PDF with dynamic page breaks, CSS print layout | YES | Only Visualforce supports `renderAs="pdf"` |
| Standard record page with form fields | NO — use LWC + FlexiPage | LWC + Dynamic Forms is the modern equivalent |
| Simple data display page | NO — use LWC | LWC is faster, more maintainable, mobile-ready |
| Quick Action modal | NO — use LWC Screen Flow or LWC | Modern alternative is available |
| Visualforce page embedded in Lightning | ASSESS — use LWC if possible | VF in Lightning requires an iframe wrapper; has known limitations |
| Page accessible only to API users | ASSESS | If purely API-driven, Apex REST may be better |

### Summary Rule

If the requirement can be met by LWC + Flows + FlexiPage, **do not use Visualforce**. Visualforce's legitimate remaining use cases are primarily:
1. PDF generation.
2. Complex Visualforce email templates.
3. Legacy integration compatibility requirements.

---

## 3. Migration Consideration

### Always Assess Before Writing Visualforce

Before writing any Visualforce page, document the answer to these questions:

1. **Can this be done in LWC?** If yes, why is VF being considered?
2. **Is PDF generation involved?** If yes, VF is the current standard approach.
3. **Is this a legacy page that cannot be changed?** If yes, document it as legacy and note the migration plan.
4. **What is the migration path?** Document this in the page's file header comment.

### Migration Notes Header Template

Every Visualforce page file should include this header comment:

```apex
/**
 * Page: CasePdfPage
 * Description: Renders Case data as a PDF document for customer download.
 * Developer: Naresh
 * Title: Senior Salesforce Developer
 * Created: April 2026
 *
 * Migration Assessment:
 *   Current Status: Active — PDF generation required; no LWC equivalent available.
 *   LWC Migration: Not possible until Salesforce supports native PDF generation in LWC.
 *   Review Date: Q4 2026
 *   Blocker: renderAs="pdf" has no LWC equivalent as of Spring '26.
 */
```

---

## 4. standardController vs Custom Controller vs Extension

### Overview Table

| Controller Type | When to Use | Salesforce Manages |
|---|---|---|
| `standardController` | Standard CRUD operations on a single standard/custom object record | Record fetch, save, delete, navigation |
| Custom Controller | Full custom logic; no standard record operations needed; complex workflows | Nothing — developer owns all logic |
| Extension (standardController + Extension) | Need standard controller operations PLUS additional custom methods | Record fetch via standardController; extension adds methods |

### Detailed Rules

#### standardController

```xml
<apex:page standardController="Case">
    <apex:detail />
</apex:page>
```

- Use when the page is primarily a standard record view with minor additions.
- The standard controller handles security automatically (respects sharing).
- Cannot add custom methods — only use for standard VF tags.

#### Custom Controller

```apex
public with sharing class CaseDashboardController {
    // All logic is custom
}
```

```xml
<apex:page controller="CaseDashboardController">
```

- Use when the page has no direct standard object record context.
- Or when the page involves complex multi-object queries.
- Developer is fully responsible for CRUD, FLS, sharing, error handling.

#### Extension

```apex
public with sharing class CasePdfExtension {
    private ApexPages.StandardController stdController;

    public CasePdfExtension(ApexPages.StandardController std) {
        this.stdController = std;
    }

    public String getFormattedCaseNumber() {
        Case c = (Case) std.getRecord();
        return 'CASE-' + c.CaseNumber;
    }
}
```

```xml
<apex:page standardController="Case" extensions="CasePdfExtension">
```

- Use when you need standard controller record operations PLUS custom methods.
- The extension receives the `ApexPages.StandardController` in its constructor.
- The standard controller still handles basic CRUD; extension adds behavior.
- Most VF pages with custom logic should use extension pattern over pure custom controller when a standard object is involved.

---

## 5. Controller Class Design

### Rules

- `with sharing` is REQUIRED for all controllers serving user-facing pages.
- `without sharing` requires explicit documented justification and architecture review.
- Class header comment is MANDATORY — include description, developer name, title.
- CRUD check BEFORE any SOQL query.
- Use `WITH USER_MODE` in SOQL to enforce FLS and sharing automatically.
- Use `stripInaccessible` before any DML involving fields that may not be accessible.

### Standard Controller Class Pattern

```apex
/**
 * Description: Controller for Case PDF generation.
 *   Renders Case record data as a PDF document for customer download.
 * Developer: Naresh
 * Title: Senior Salesforce Developer
 * Created: April 2026
 */
public with sharing class CasePdfController {

    public Case caseRecord { get; private set; }
    public Boolean hasError { get; private set; }
    public String errorMessage { get; private set; }

    public CasePdfController(ApexPages.StandardController std) {
        this.hasError = false;

        // CRUD check — verify user can read Case
        if (!Schema.sObjectType.Case.isAccessible()) {
            this.hasError = true;
            this.errorMessage = 'You do not have permission to view Case records.';
            ApexPages.addMessage(
                new ApexPages.Message(ApexPages.Severity.ERROR, this.errorMessage)
            );
            return;
        }

        // Query with USER_MODE to enforce FLS and sharing
        Id caseId = std.getId();
        try {
            this.caseRecord = [
                SELECT
                    Id,
                    CaseNumber,
                    Subject,
                    Status,
                    Priority,
                    Description,
                    CreatedDate,
                    Account.Name,
                    Contact.FirstName,
                    Contact.LastName,
                    Contact.Email
                FROM Case
                WHERE Id = :caseId
                WITH USER_MODE
                LIMIT 1
            ];
        } catch (QueryException e) {
            this.hasError = true;
            this.errorMessage = 'Unable to load the case record. Please try again or contact your administrator.';
            ApexPages.addMessage(
                new ApexPages.Message(ApexPages.Severity.ERROR, this.errorMessage)
            );
        }
    }
}
```

### Custom Controller (Non-Standard-Controller Pattern)

```apex
/**
 * Description: Dashboard controller for Support metrics display.
 * Developer: Naresh
 * Title: Senior Salesforce Developer
 * Created: April 2026
 */
public with sharing class SupportDashboardController {

    public List<CaseSummaryWrapper> caseSummaries { get; private set; }

    public SupportDashboardController() {
        loadCaseSummaries();
    }

    private void loadCaseSummaries() {
        // Object accessibility check
        if (!Schema.sObjectType.Case.isAccessible()) {
            ApexPages.addMessage(
                new ApexPages.Message(ApexPages.Severity.ERROR, 'Insufficient access to Case object.')
            );
            this.caseSummaries = new List<CaseSummaryWrapper>();
            return;
        }

        this.caseSummaries = new List<CaseSummaryWrapper>();
        for (Case c : [
            SELECT Id, CaseNumber, Subject, Status, Priority, CreatedDate
            FROM Case
            WHERE Status != 'Closed'
            WITH USER_MODE
            ORDER BY CreatedDate DESC
            LIMIT 50
        ]) {
            caseSummaries.add(new CaseSummaryWrapper(c));
        }
    }

    public class CaseSummaryWrapper {
        public Case caseRecord { get; private set; }
        public Boolean isHighPriority { get; private set; }

        public CaseSummaryWrapper(Case c) {
            this.caseRecord = c;
            this.isHighPriority = c.Priority == 'High' || c.Priority == 'Critical';
        }
    }
}
```

---

## 6. View State Limits

### Limit

Visualforce view state is limited to **135 KB**. Exceeding this limit causes a `ViewStateException` and a degraded user experience.

### What Consumes View State

- All non-transient properties in the controller.
- All `apex:form` data.
- All component state within the page.

### Rules

- Use the `transient` keyword on properties that do not need to persist across postbacks.
- Never store large collections (thousands of records) in controller properties.
- Use pagination (`StandardSetController`) for large record lists instead of loading all records at once.
- Lazy-load data via action methods rather than loading everything in the constructor.
- Monitor view state size using the Salesforce Developer Tools view state inspector.

### Example: Using transient

```apex
public with sharing class CaseDashboardController {

    // This is persisted in view state — only include if needed across postbacks
    public String selectedCaseId { get; set; }

    // This is NOT persisted in view state — computed on each request
    transient public List<Case> recentCases { get; private set; }

    public void loadRecentCases() {
        // Called via action method, not constructor
        this.recentCases = [
            SELECT Id, CaseNumber, Subject, Status
            FROM Case
            WITH USER_MODE
            ORDER BY CreatedDate DESC
            LIMIT 10
        ];
    }
}
```

### Pagination with StandardSetController

```apex
public with sharing class CaseListController {

    public ApexPages.StandardSetController setCon { get; private set; }
    private static final Integer PAGE_SIZE = 10;

    public CaseListController() {
        setCon = new ApexPages.StandardSetController(
            Database.getQueryLocator([
                SELECT Id, CaseNumber, Subject, Status
                FROM Case
                WITH USER_MODE
                ORDER BY CreatedDate DESC
            ])
        );
        setCon.setPageSize(PAGE_SIZE);
    }

    public List<Case> getCases() {
        return (List<Case>) setCon.getRecords();
    }
}
```

---

## 7. CRUD / FLS

### Rules

Visualforce controllers have the same CRUD/FLS enforcement requirements as any Apex code:

1. Check object accessibility (`isAccessible()`) before querying.
2. Check field accessibility before displaying or writing to a field.
3. Use `WITH USER_MODE` in SOQL to delegate FLS and sharing enforcement to the platform.
4. Use `stripInaccessible` before DML to remove fields the user cannot write.
5. Never display sensitive fields (salary, SSN, internal notes) without FLS validation.

### CRUD Check Example

```apex
// Before query
if (!Schema.sObjectType.Case.isAccessible()) {
    throw new AuraHandledException('Insufficient access to Case object.');
}

// Before create
if (!Schema.sObjectType.Case.isCreateable()) {
    throw new AuraHandledException('Insufficient access to create Case records.');
}

// Before update
if (!Schema.sObjectType.Case.isUpdateable()) {
    throw new AuraHandledException('Insufficient access to update Case records.');
}
```

### FLS via stripInaccessible

```apex
// Before DML — remove fields user cannot write
SObjectAccessDecision sanitized = Security.stripInaccessible(
    AccessType.UPSERTABLE,
    new List<Case>{ caseToUpdate }
);
update sanitized.getRecords();
```

---

## 8. Sharing

### Rules

- ALL Visualforce controllers must use `with sharing` unless there is a documented and architect-approved reason to use `without sharing` or `inherited sharing`.
- `without sharing` is reserved for: System-level jobs, integration services, or explicitly justified admin-only operations.
- `inherited sharing` can be used for utility classes called by both sharing contexts.
- Document the sharing choice in the class header comment.

### Example Header Comments

```apex
// CORRECT — standard user-facing page
public with sharing class CasePdfController {
```

```apex
// EXCEPTION — document the justification
/**
 * Runs in system mode to perform cross-user data consolidation.
 * Justification: This controller is only invoked by scheduled batch processes,
 * not directly by users. Architecture reviewed by: [Name], April 2026.
 */
public without sharing class CaseBatchSummaryController {
```

---

## 9. PDF Rendering

### Core Technique

Add `renderAs="pdf"` to the `<apex:page>` tag. Salesforce renders the page as a PDF using the Flying Saucer PDF library.

### Rules

- **No JavaScript** in PDF pages — JavaScript is not executed during PDF rendering. Remove all JS from PDF-rendered pages.
- **CSS print layout** — use CSS `@page` rules and print-specific styles for correct page size and margins.
- **Absolute image URLs** — relative image paths may not resolve during PDF rendering. Use static resource absolute URLs.
- **Tables for layout** — use `<table>` for multi-column PDF layouts; CSS grid/flex may not render correctly.
- **Test at actual content length** — a PDF that looks fine with short test data may have page break issues with real data.
- **Avoid dynamic content changes** in the controller when `renderAs="pdf"` is active — the page renders once.

### Example PDF Page Structure

```xml
<apex:page
    standardController="Case"
    extensions="CasePdfController"
    renderAs="pdf"
    showHeader="false"
    sidebar="false"
    applyBodyTag="false"
    applyHtmlTag="false"
    docType="html-5.0">

<html>
<head>
    <style>
        @page {
            size: A4;
            margin: 20mm 15mm 20mm 15mm;
        }
        body {
            font-family: Arial, sans-serif;
            font-size: 11px;
            color: #333;
        }
        .header {
            border-bottom: 2px solid #005A9C;
            padding-bottom: 10px;
            margin-bottom: 20px;
        }
        .section-title {
            font-size: 13px;
            font-weight: bold;
            color: #005A9C;
            margin-top: 15px;
            margin-bottom: 5px;
        }
        table.data-table {
            width: 100%;
            border-collapse: collapse;
        }
        table.data-table td {
            padding: 6px 8px;
            border: 1px solid #ddd;
        }
        table.data-table td:first-child {
            font-weight: bold;
            width: 30%;
            background-color: #f5f5f5;
        }
        .page-break {
            page-break-before: always;
        }
    </style>
</head>
<body>

    <apex:outputPanel rendered="{!hasError}">
        <p style="color: red;">Error: {!errorMessage}</p>
    </apex:outputPanel>

    <apex:outputPanel rendered="{!NOT(hasError)}">
        <div class="header">
            <h1 style="margin: 0; font-size: 18px; color: #005A9C;">Case Summary Report</h1>
            <p style="margin: 5px 0 0 0; font-size: 10px; color: #666;">
                Generated: <apex:outputText value="{!NOW()}" />
            </p>
        </div>

        <div class="section-title">Case Details</div>
        <table class="data-table">
            <tr>
                <td>Case Number</td>
                <td><apex:outputText value="{!caseRecord.CaseNumber}" /></td>
            </tr>
            <tr>
                <td>Subject</td>
                <td><apex:outputText value="{!caseRecord.Subject}" /></td>
            </tr>
            <tr>
                <td>Status</td>
                <td><apex:outputText value="{!caseRecord.Status}" /></td>
            </tr>
            <tr>
                <td>Priority</td>
                <td><apex:outputText value="{!caseRecord.Priority}" /></td>
            </tr>
            <tr>
                <td>Description</td>
                <td><apex:outputText value="{!caseRecord.Description}" /></td>
            </tr>
        </table>

        <div class="section-title">Contact Information</div>
        <table class="data-table">
            <tr>
                <td>Contact Name</td>
                <td>
                    <apex:outputText value="{!caseRecord.Contact.FirstName}" />
                    <apex:outputText value=" " />
                    <apex:outputText value="{!caseRecord.Contact.LastName}" />
                </td>
            </tr>
            <tr>
                <td>Email</td>
                <td><apex:outputText value="{!caseRecord.Contact.Email}" /></td>
            </tr>
        </table>
    </apex:outputPanel>

</body>
</html>
</apex:page>
```

### Page Break Technique

```html
<div class="page-break"></div>
```

CSS:
```css
.page-break {
    page-break-before: always;
}
```

---

## 10. JavaScript Remoting

### Overview

JavaScript Remoting allows VF page JavaScript to call Apex controller methods asynchronously using `@RemoteAction`.

### Rule

**Do NOT use JavaScript Remoting for new development.** If you need asynchronous server calls from a JavaScript context:
- Use LWC instead of Visualforce.
- If you must stay on VF, use `apex:actionFunction` or `apex:remoteObjects` for simpler cases.

### When It's Unavoidable (Legacy Pages)

If you are maintaining an existing VF page that uses `@RemoteAction`:

```apex
@RemoteAction
public static CaseData getCaseData(String caseId) {
    // CRUD check
    if (!Schema.sObjectType.Case.isAccessible()) {
        throw new AuraHandledException('Insufficient access');
    }
    Case c = [SELECT Id, Subject, Status FROM Case WHERE Id = :caseId WITH USER_MODE LIMIT 1];
    return new CaseData(c.Subject, c.Status);
}

public class CaseData {
    public String subject;
    public String status;
    public CaseData(String s, String st) {
        subject = s;
        status = st;
    }
}
```

```javascript
// In VF page JavaScript
Visualforce.remoting.Manager.invokeAction(
    '{!$RemoteAction.CaseDashboardController.getCaseData}',
    caseId,
    function(result, event) {
        if (event.status) {
            console.log(result.subject);
        }
    },
    { escape: true }
);
```

**CSRF protection is automatically handled** by the Visualforce remoting framework for `@RemoteAction` — do not disable it.

---

## 11. Security Considerations

### XSS Prevention

| Tag | Escaping Behavior | Use For |
|---|---|---|
| `<apex:outputText>` | Auto-escapes HTML — SAFE | All user-data output |
| `<apex:outputField>` | Uses Salesforce field renderer — SAFE for standard use | Standard field rendering |
| `value="{!variable}"` in output component | Auto-escaped — SAFE | Standard binding |
| `escape="false"` attribute | DISABLES escaping — DANGEROUS | Only for pre-sanitized HTML you control |

**Never** use `escape="false"` on user-provided data. If you need to render HTML content from a field, sanitize it in the controller before passing to the page.

### CSRF

- Standard `<apex:form>` and its action elements include CSRF protection automatically.
- Custom AJAX calls that bypass `<apex:form>` (direct `XMLHttpRequest` or `fetch`) do NOT have automatic CSRF protection — do not use these patterns. Use `@RemoteAction` (includes CSRF token) or migrate to LWC.

### Content Security Policy

- Salesforce enforces a Content Security Policy on Lightning pages. VF pages in Lightning experience may have different CSP behavior. Test CSP compliance when embedding VF in Lightning.
- Avoid inline event handlers (`onclick="..."` in HTML) — use `<apex:actionFunction>` or attached JavaScript functions instead.

---

## 12. Migration Considerations to LWC

### Migration Assessment Checklist

Run this checklist for every existing Visualforce page before deciding to keep or migrate:

- [ ] **Does the page generate PDF?** → VF still required; keep until Salesforce provides native LWC PDF support.
- [ ] **Is the page an email template?** → Assess whether Lightning Email Templates cover the use case.
- [ ] **Is the page a standard record view/edit?** → Migrate to LWC + FlexiPage + Dynamic Forms.
- [ ] **Does the page have complex JavaScript remoting?** → Migrate the data layer to Apex `@AuraEnabled` + LWC wire services.
- [ ] **Is the page embedded in a third-party integration by URL?** → Assess migration timeline with the integration team.
- [ ] **Does the page use Visualforce-specific rendering (custom renderer, `<apex:chart>`)** → Find LWC equivalent; these components are not available in LWC.

### Migration Blockers

| Blocker | Status |
|---|---|
| PDF rendering (`renderAs="pdf"`) | No LWC equivalent — VF required |
| `<apex:chart>` | No direct LWC equivalent — use third-party charting library in LWC |
| Complex Visualforce email templates with iteration | Partial VF replacement possible; assess per case |
| JavaScript Remoting with specific integration contracts | Plan API migration to Apex REST |

### Migration Approach

For pages that CAN be migrated:
1. Identify the VF page's data model and controller methods.
2. Create equivalent Apex `@AuraEnabled` methods (with `with sharing`, CRUD/FLS checks).
3. Build the LWC component(s) to replace the VF page layout.
4. Build a FlexiPage or Lightning App to host the LWC.
5. Test the LWC implementation against the VF page acceptance criteria.
6. Switch users to the LWC page; retain the VF page in `inactive` state for rollback.
7. Remove the VF page after a validation period.

---

## 13. Common AI Mistakes to Avoid

| Mistake | Why It's Wrong | Correct Approach |
|---|---|---|
| Missing `with sharing` on controller | Exposes records the user should not see | Always use `with sharing`; document exceptions |
| No CRUD check before query | Security gap — user may not have object read permission | Check `isAccessible()` before SOQL |
| Using `apex:inputField` without checking FLS | User can submit fields they shouldn't edit | Validate FLS in controller before DML; use `WITH USER_MODE` |
| Large view state (storing full collections) | `ViewStateException` at 135 KB | Use `transient`, pagination, and lazy loading |
| JavaScript in a PDF page | JS is not executed during PDF render | Remove all JS from `renderAs="pdf"` pages |
| Using `escape="false"` on user-provided data | XSS vulnerability | Use `<apex:outputText>` (auto-escapes); only use `escape="false"` on fully sanitized content |
| Mixing JavaScript Remoting with new development | Creates maintenance burden; not LWC-compatible | Use LWC for new development; maintain remoting only in legacy pages |
| No migration assessment | VF technical debt accumulates | Always document migration path in file header |
| No class header comment | Code unattributed and undocumented | Every controller class needs author, description, date |

---

## 14. Definition of Done

A Visualforce page is complete and deployable when ALL of the following are true:

- [ ] Justification for using VF over LWC is documented (PDF rendering, legacy requirement, etc.)
- [ ] Migration path assessment is documented in the file header comment
- [ ] Controller uses `with sharing` (or `without sharing` with documented justification)
- [ ] CRUD check is performed before all SOQL queries
- [ ] FLS is enforced via `WITH USER_MODE` or `stripInaccessible`
- [ ] No `escape="false"` on user-provided data
- [ ] View state is within 135 KB limit (verified with Developer Tools)
- [ ] For PDF pages: no JavaScript, CSS print layout defined, images use absolute URLs
- [ ] Page tested with test user in the correct profile/permission set
- [ ] Error handling: meaningful error messages displayed (not stack traces)
- [ ] Class header comment includes: description, developer, title, created date, migration assessment

---

## 15. Validation Commands

```bash
# Deploy Visualforce page and controller
sf project deploy start \
  --metadata "ApexClass:CasePdfController" \
  --metadata "ApexPage:CasePdfPage" \
  --target-org <alias>

# Deploy check-only (validation run)
sf project deploy start \
  --metadata "ApexClass:CasePdfController" \
  --metadata "ApexPage:CasePdfPage" \
  --dry-run \
  --target-org <alias>

# Retrieve existing Visualforce pages
sf project retrieve start \
  --metadata "ApexPage" \
  --target-org <alias>

# List all VF pages via SOQL
sf data query \
  --query "SELECT Id, Name, MasterLabel, ControllerType, IsAvailableInTouch FROM ApexPage ORDER BY Name" \
  --target-org <alias>

# Run Apex tests for the controller
sf apex run test \
  --class-names CasePdfControllerTest \
  --result-format human \
  --target-org <alias>
```

---

## 16. Official References

- Salesforce Developer Docs: [Visualforce Developer Guide](https://developer.salesforce.com/docs/atlas.en-us.pages.meta/pages/)
- Salesforce Developer Docs: [Visualforce PDF Rendering](https://developer.salesforce.com/docs/atlas.en-us.pages.meta/pages/pages_pdf_rendering.htm)
- Salesforce Developer Docs: [JavaScript Remoting](https://developer.salesforce.com/docs/atlas.en-us.pages.meta/pages/pages_js_remoting.htm)
- Salesforce Security Guide: [Visualforce Security](https://developer.salesforce.com/docs/atlas.en-us.pages.meta/pages/pages_security_tips.htm)
- Salesforce Metadata API: [ApexPage](https://developer.salesforce.com/docs/atlas.en-us.api_meta.meta/api_meta/meta_visualforcepage.htm)
- Trailhead: [Visualforce Basics](https://trailhead.salesforce.com/content/learn/modules/visualforce_fundamentals)
- Salesforce LWC Developer Guide: [LWC vs Visualforce Migration](https://developer.salesforce.com/docs/component-library/documentation/en/lwc/lwc.migrate_visualforce)
