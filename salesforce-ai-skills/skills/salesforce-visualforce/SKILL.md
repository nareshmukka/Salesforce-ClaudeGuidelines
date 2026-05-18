---
name: salesforce-visualforce
description: Production Salesforce AI skill for Visualforce page/controller maintenance or migration.
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
- The task involves Visualforce page/controller maintenance or migration.
- The user asks for implementation, refactor, troubleshooting, review, or best-practice validation in this area.
- The assistant must produce Salesforce-safe code/metadata with explicit security/testing notes.

## DO NOT TRIGGER when
- The task is unrelated to this component.
- Another specialized skill is the primary owner and this area is only incidental.
- The user asks for operational execution (deploy/publish/activate/destructive change) without explicit approval.

## Cross-skill routing
- Always read `../salesforce-global-development/SKILL.md`.
- Also read: Global Development + Apex + Permissions + Testing.
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
Controllers enforce sharing and CRUD/FLS. Minimize view state, paginate large datasets, and avoid heavy component trees. Treat JS remoting/remote actions with strict input validation and auth checks.

## Examples
### Good example patterns
1. Controller marked with sharing and strips inaccessible fields before render.
2. PDF page uses dedicated lightweight controller and bounded data set.

### Bad examples / avoid
1. StandardController extension performs unrestricted SOQL with no checks.
2. Large transient state objects causing view state bloat/timeouts.

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

# Visualforce Guidelines -- Legacy Surface Reference

Authoritative reference for `ApexPage` work in this project. Visualforce is **legacy** -- this file exists for the narrow set of cases where VF is still the right tool, and for maintaining what already ships.

**Verified against:** [Visualforce Developer Guide](https://developer.salesforce.com/docs/atlas.en-us.pages.meta/pages/) - [Standard Component Reference](https://developer.salesforce.com/docs/atlas.en-us.pages.meta/pages/pages_compref.htm) - [PDF Rendering](https://developer.salesforce.com/docs/atlas.en-us.pages.meta/pages/pages_pdf_rendering.htm) - [View State Best Practices](https://developer.salesforce.com/docs/atlas.en-us.pages.meta/pages/pages_best_practices_view_state.htm) - [Security Tips](https://developer.salesforce.com/docs/atlas.en-us.pages.meta/pages/pages_security_tips.htm) - [Visualforce Email Templates](https://developer.salesforce.com/docs/atlas.en-us.pages.meta/pages/pages_email_templates.htm). Last verified 2026-05-16.

> **Default rule:** any new UI work uses LWC. Open this file only for the carve-outs in Section 1 1. When to STILL Use Visualforce

| Use case | Use VF? | Why |
|---|:-:|---|
| PDF generation (`<apex:page renderAs="pdf">`) | YES | No native LWC equivalent. Flying Saucer renderer is VF-only. |
| Visualforce email templates (`<messaging:emailTemplate>`) | YES | Lightning Email Templates can't iterate over related lists with Apex-backed merge logic. |
| Legacy page hardcoded into an external integration URL | YES | Migrate only when the integration partner can change the URL. |
| S-Control migration target | YES | S-Controls are EOL; the Salesforce-prescribed replacement is VF, then LWC. |
| Standard record view/edit | NO | LWC + FlexiPage + Dynamic Forms. |
| Quick Action modal | NO | Screen Flow or LWC. |
| Anything embeddable in Lightning Experience as a new page | NO | LWC. VF-in-Lightning runs in an iframe with CSP/CSRF caveats. |
| Custom REST endpoint | NO | Apex REST. |

If the requirement can be met by LWC + Flow + FlexiPage, **do not write Visualforce**.

---

## 2. Required Output Contract

When generating or modifying a VF page + controller, the agent MUST produce:

```
Page: CasePdfPage
Purpose: Render Case as PDF for customer download
Controller: CasePdfController (extension on StandardController)
Sharing: with sharing
Security: Schema.sObjectType.Case.isAccessible() before query; WITH USER_MODE on SOQL
RenderAs: pdf
JavaScript: none (not executed during PDF render)
Migration path: Keep until LWC supports native PDF rendering.
```

Every controller class needs a header comment with description, developer, title, created date, and migration assessment.

---

## 3. Controller Type Decision

| Controller | When | Owns |
|---|---|---|
| `standardController="Case"` | Single-record standard CRUD view, mostly `<apex:detail/>` or `<apex:outputField>` | Platform handles fetch, save, delete, sharing |
| Custom controller (`controller="X"`) | No standard record context, multi-object dashboards, fully custom logic | Developer owns CRUD, FLS, sharing, errors |
| Extension (`standardController="Case" extensions="X"`) | Standard record context PLUS custom methods (most common for PDF + custom logic) | Platform handles base CRUD; extension adds methods |

```apex
public with sharing class CasePdfExtension {
   private final ApexPages.StandardController stdController;

   public CasePdfExtension(ApexPages.StandardController std) {
      this.stdController = std;
   }

   public String getFormattedNumber() {
      return 'CASE-' + ((Case) stdController.getRecord()).CaseNumber;
   }
}
```

Prefer extension over custom controller whenever a standard object is involved -- you inherit free sharing and CRUD behavior.

---

## 4. Controller Class Rules

- **`with sharing` is mandatory** for user-facing pages. `without sharing` requires architect approval and a header-comment justification. `inherited sharing` is fine for shared utility classes.
- **CRUD check before every SOQL.** `Schema.sObjectType.X.isAccessible()` / `isCreateable()` / `isUpdateable()`.
- **`WITH USER_MODE` on every SOQL** -- delegates FLS + sharing to the platform.
- **`Security.stripInaccessible(AccessType.UPSERTABLE, ...)` before DML** if any user-writable field could be unwritable for the running user.
- **Header comment** with description, developer, title, created date, and migration assessment.

```apex
/**
 * Description: Renders Case data as a downloadable PDF.
 * Developer: the release owner | Salesforce Developer
 * Created: 2026-04
 * Migration: blocked by lack of native LWC PDF rendering. Review Q4 2026.
 */
public with sharing class CasePdfController {
   public Case caseRecord { get; private set; }

   public CasePdfController(ApexPages.StandardController std) {
      if (!Schema.sObjectType.Case.isAccessible()) {
         ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Access denied.'));
         return;
      }
      this.caseRecord = [
         SELECT Id, CaseNumber, Subject, Status, Priority, Description, Account.Name
         FROM Case WHERE Id = :std.getId() WITH USER_MODE LIMIT 1
      ];
   }
}
```

---

## 5. View State -- the 135 KB Wall

Visualforce serializes controller state into a hidden form field on every postback. The hard ceiling is **135 KB**. Exceeding it throws `ViewStateException` and degrades UX long before that.

**What consumes view state:**
- Every non-`transient` controller property.
- Every `<apex:form>` value binding.
- Component state inside the page (selection lists, expanded panels).

**Rules:**
- Mark anything not needed across postbacks `transient`.
- Never bind a thousand-row collection to a property. Page with `ApexPages.StandardSetController`.
- Lazy-load via action methods, not the constructor.
- Inspect view state size with the Developer Console view-state inspector during testing.
- Set **`USE_ENCRYPTION_FOR_VIEWSTATE`** (org-level Security Controls -> Session Settings) so the serialized state is encrypted at rest in the browser. Required when the page handles regulated data.

```apex
public with sharing class CaseListController {
   public String selectedId { get; set; }                 // persisted across postbacks
   transient public List<Case> recentCases { get; set; }  // recomputed each request

   public ApexPages.StandardSetController setCon { get; private set; }

   public CaseListController() {
      setCon = new ApexPages.StandardSetController(Database.getQueryLocator([
         SELECT Id, CaseNumber, Subject, Status FROM Case
         WITH USER_MODE ORDER BY CreatedDate DESC
      ]));
      setCon.setPageSize(25);
   }

   public List<Case> getPagedCases() { return (List<Case>) setCon.getRecords(); }
}
```

---

## 6. Key Tags -- When to Reach for Each

| Tag | Use for | Notes |
|---|---|---|
| `<apex:detail>` | Render the standard detail page for a record inside a custom VF page | Free -- inherits page layout, related lists, inline edit. First choice when wrapping standard UI. |
| `<apex:outputField>` | Display a single field with native styling + FLS | Auto-respects FLS -- preferred over `<apex:outputText value="{!record.field}">` for record fields. |
| `<apex:inputField>` | Edit a single field with native styling + FLS | Same FLS auto-respect. Always wrap in `<apex:form>`. |
| `<apex:repeat>` | Lightweight iteration with no table chrome | Use when you control the markup (PDF tables, custom layouts). No selection / no pagination. |
| `<apex:dataTable>` | Iterate with HTML table semantics | Old-school styling. Prefer `<apex:repeat>` over `<table>` for PDF; reach for `dataTable` only when matching legacy patterns. |
| `<apex:pageBlockTable>` | Iterate with Classic-style table chrome | Avoid in new work. Looks out of place in Lightning. |
| `<apex:outputText>` | Free-form text or formatted output | Auto-escapes HTML. **Never** set `escape="false"` on user-provided data. |
| `<apex:form>` | Container for postback-driven elements | Includes CSRF token automatically. Required for `<apex:inputField>`, `<apex:commandButton>`, `<apex:actionFunction>`. |

`<apex:detail>` is the lowest-effort migration target for an S-Control: drop a VF page with `standardController="X"` and a single `<apex:detail/>` and you've replaced the S-Control with a supported equivalent.

---

## 7. PDF Rendering (`renderAs="pdf"`)

The single most common reason VF still exists in 2026.

**Rules:**
- **No JavaScript.** The Flying Saucer renderer does not execute JS. Strip every `<script>` and inline handler.
- **CSS `@page` rules** for size and margins. `@page { size: A4; margin: 20mm; }`.
- **Absolute static-resource URLs** for images. Relative paths often don't resolve.
- **Tables for layout.** CSS grid/flex render unreliably; HTML tables are the safe choice.
- **Test at real data volume.** Page-break issues only surface with long content.
- **No dynamic mutations after render starts** -- the page renders once.

```xml
<apex:page standardController="Case" extensions="CasePdfController"
           renderAs="pdf" showHeader="false" sidebar="false"
           applyBodyTag="false" applyHtmlTag="false" docType="html-5.0">
<html><head><style>
   @page { size: A4; margin: 20mm 15mm; }
   body { font-family: Arial, sans-serif; font-size: 11px; }
   .pb   { page-break-before: always; }
   table.d { width: 100%; border-collapse: collapse; }
   table.d td { padding: 6px 8px; border: 1px solid #ddd; }
</style></head><body>
   <h1>Case <apex:outputText value="{!caseRecord.CaseNumber}"/></h1>
   <table class="d">
      <apex:repeat value="{!caseRecord}" var="c">
         <tr><td>Subject</td><td><apex:outputText value="{!c.Subject}"/></td></tr>
         <tr><td>Status</td><td><apex:outputText value="{!c.Status}"/></td></tr>
      </apex:repeat>
   </table>
</body></html>
</apex:page>
```

---

## 8. Security Essentials

| Concern | What to do |
|---|---|
| XSS | Use `<apex:outputText>` / `<apex:outputField>` -- both auto-escape. Never set `escape="false"` on user-controlled content. |
| CSRF | Always use `<apex:form>` for state-changing actions -- it injects the CSRF token. `@RemoteAction` includes its own CSRF protection. Never bypass with raw `fetch`/`XMLHttpRequest`. |
| Sharing | `with sharing` on every user-facing controller. |
| FLS | `WITH USER_MODE` on SOQL; `Security.stripInaccessible` before DML. |
| View state tampering | Enable **`USE_ENCRYPTION_FOR_VIEWSTATE`** at the org level. |
| CSP in Lightning | VF in Lightning runs in an iframe. Avoid inline `onclick="..."`; use `<apex:actionFunction>` or attached JS. |

JavaScript Remoting (`@RemoteAction`) is supported for legacy pages but **not for new development** -- if you reach for it, use LWC instead.

---

## 9. Definition of Done

- [ ] Justification for VF over LWC is documented in the file header.
- [ ] Controller uses `with sharing` (or `without sharing` with documented justification).
- [ ] CRUD check (`isAccessible` / `isCreateable` / `isUpdateable`) before every DML path.
- [ ] `WITH USER_MODE` on every SOQL; `stripInaccessible` before DML if any field could be unwritable.
- [ ] No `escape="false"` on user-provided data.
- [ ] View state under 135 KB at peak (verified via Developer Console).
- [ ] `transient` on properties not needed across postbacks; `StandardSetController` for large lists.
- [ ] PDF pages: no `<script>`, `@page` rules defined, images use absolute URLs, tested at real content length.
- [ ] Header comment: description, developer, title, created date, migration assessment.

---

## 10. Validation Commands

```bash
# Validate (dry-run) -- manifest-driven
sf project deploy start --manifest manifest/package.xml \
   --target-org <target-env-alias> --dry-run --test-level RunLocalTests --wait 60

# Deploy a specific page + controller
sf project deploy start --metadata ApexPage:CasePdfPage --metadata ApexClass:CasePdfController \
   --target-org <target-env-alias>

# Retrieve all VF pages
sf project retrieve start --metadata ApexPage --target-org <target-env-alias>

# List VF pages via Tooling API
sf data query --query "SELECT Id, Name, ControllerType FROM ApexPage ORDER BY Name" --target-org <target-env-alias>
```

---

## 11. Common AI Mistakes to Avoid

| Mistake | Why It's Wrong | Correct Approach |
|---|---|---|
| Missing `with sharing` on controller | Exposes records the user should not see | Always use `with sharing`; document exceptions |
| No CRUD check before query | Security gap -- user may not have object read permission | Check `isAccessible()` before SOQL |
| Using `apex:inputField` without checking FLS | User can submit fields they shouldn't edit | Validate FLS in controller before DML; use `WITH USER_MODE` |
| Large view state (storing full collections) | `ViewStateException` at 135 KB | Use `transient`, pagination, and lazy loading |
| JavaScript in a PDF page | JS is not executed during PDF render | Remove all JS from `renderAs="pdf"` pages |
| Using `escape="false"` on user-provided data | XSS vulnerability | Use `<apex:outputText>` (auto-escapes); only use `escape="false"` on fully sanitized content |
| Mixing JavaScript Remoting with new development | Creates maintenance burden; not LWC-compatible | Use LWC for new development; maintain remoting only in legacy pages |
| No migration assessment | VF technical debt accumulates | Always document migration path in file header |
| No class header comment | Code unattributed and undocumented | Every controller class needs author, description, date |

---

## 12. Empirical Findings & Implementation Notes

When Salesforce's documented approach doesn't work in the target environment, the workaround goes here. Date-stamp every entry.

| # | Date | Documented approach | What actually works | Why / Context |
|---|---|---|---|---|

---

## 13. Official References

- [Visualforce Developer Guide](https://developer.salesforce.com/docs/atlas.en-us.pages.meta/pages/)
- [Standard Component Reference](https://developer.salesforce.com/docs/atlas.en-us.pages.meta/pages/pages_compref.htm)
- [PDF Rendering](https://developer.salesforce.com/docs/atlas.en-us.pages.meta/pages/pages_pdf_rendering.htm)
- [View State Best Practices](https://developer.salesforce.com/docs/atlas.en-us.pages.meta/pages/pages_best_practices_view_state.htm)
- [Security Tips](https://developer.salesforce.com/docs/atlas.en-us.pages.meta/pages/pages_security_tips.htm)
- [Visualforce Email Templates](https://developer.salesforce.com/docs/atlas.en-us.pages.meta/pages/pages_email_templates.htm)
- [JavaScript Remoting](https://developer.salesforce.com/docs/atlas.en-us.pages.meta/pages/pages_js_remoting.htm)
- [Metadata API -- ApexPage](https://developer.salesforce.com/docs/atlas.en-us.api_meta.meta/api_meta/meta_visualforcepage.htm)
- [LWC Migration Guide](https://developer.salesforce.com/docs/component-library/documentation/en/lwc/lwc.migrate_visualforce)

---

*Visualforce Guidelines | Reusable Salesforce Agent Guidelines | Last verified 2026-05-16*

