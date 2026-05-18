---
name: salesforce-lwc
description: Production Salesforce AI skill for Lightning Web Component implementation/review/testing.
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
- The task involves Lightning Web Component implementation/review/testing.
- The user asks for implementation, refactor, troubleshooting, review, or best-practice validation in this area.
- The assistant must produce Salesforce-safe code/metadata with explicit security/testing notes.

## DO NOT TRIGGER when
- The task is unrelated to this component.
- Another specialized skill is the primary owner and this area is only incidental.
- The user asks for operational execution (deploy/publish/activate/destructive change) without explicit approval.

## Cross-skill routing
- Always read `../salesforce-global-development/SKILL.md`.
- Also read: Global Development + Apex + Testing + Permissions.
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
Use folder triad: .html/.js/.js-meta.xml (+ optional .css). Prefer @wire for cacheable/read use-cases; imperative calls for user-triggered/mutations. Provide loading/empty/error states and accessible labels/ARIA.

## Upstream Salesforce Skill Patterns
- Choose data access deliberately: LDS or `getRecord` for single-record UI, base record form components for simple CRUD, Apex for complex server queries/actions, GraphQL for related graph data, and LMS for cross-DOM communication.
- Use `@wire` for reactive read-only data and imperative calls for explicit user actions, DML, or refresh-controlled workflows.
- Prefer platform base components and SLDS styling hooks over custom controls and hardcoded colors.
- Check accessibility as part of implementation: labels, keyboard flow, focus handling, semantic markup, and screen-reader state.
- Avoid rerender loops in `renderedCallback()`; debounce expensive work and keep component state minimal and explicit.
- Validate event contracts, Flow screen input/output properties, Experience Cloud/App Builder targets, and Jest coverage where behavior matters.

## Examples
### Good example patterns
1. Wire getRecord for reactive display and imperative Apex for save.
2. Dispatch semantic custom events with documented payload contracts.

### Bad examples / avoid
1. Call imperative Apex on every render cycle.
2. NavigationMixin with incorrect pageReference type/attributes.

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

## LWC-specific implementation rules
- File set: component.html, component.js, component.js-meta.xml (plus css/tests as needed).
- Use `@api` for public contract, reactive fields/getters for derived UI state, and avoid unnecessary `@track` in modern LWC unless needed for nested mutation tracking.
- NavigationMixin: validate `type`, `attributes`, and state keys; avoid hardcoded record/page IDs.
- Always implement loading, empty, and error states plus accessibility labels and keyboard support.
- Jest: test render states, events, and Apex interaction branches.


## Full Guidance

# Lightning Web Component (LWC) Guidelines

Authoritative reference for authoring, reviewing, and refactoring Lightning Web Components in this project. Other skill files reference this one for the LWC layer.

**Verified against:** [LWC Developer Guide](https://developer.salesforce.com/docs/component-library/documentation/en/lwc) - [LWC Platform Guide](https://developer.salesforce.com/docs/platform/lwc/guide/) - [Lightning Web Security](https://developer.salesforce.com/docs/platform/lightning-components-security/guide/intro-lws.html) - [trailheadapps/lwc-recipes](https://github.com/trailheadapps/lwc-recipes) - [forcedotcom/sf-skills `generating-lwc-components`](https://github.com/forcedotcom/sf-skills/tree/main/skills/generating-lwc-components). Last verified 2026-05-16.

---

## 1. Required Agent Output Contract

Every LWC implementation response MUST include:
1. **Architecture plan** -- smart/dumb split, parent/child relationships, where state lives, what events flow up.
2. **Files to create** -- every bundle file (`.html`, `.js`, `.js-meta.xml`, `.css`, `__tests__/`).
3. **Apex controllers** -- class name, method signatures, `cacheable=true` decision with reason, CRUD/FLS approach.
4. **Security notes** -- `with sharing` justification, FLS strategy, fields exposed, custom-permission gates.
5. **Jest test strategy** -- states asserted (loading/error/empty/success), events covered, mock approach.
6. **Validation commands** -- deploy + test commands for the bundle.

---

## 2. Component Architecture -- Smart/Dumb Split

| Layer | Responsibility | Suffix |
|---|---|---|
| **Smart / Container** | Fetches data (`@wire` or imperative), owns `isLoading`/`error`/`data`/`isEmpty`, handles mutations, listens to child events. Never renders individual items. | `<feature>Container` |
| **Dumb / Presentational** | Receives data via `@api`, renders, dispatches `CustomEvent` upward. No Apex calls, no `@wire`, no business logic. Reusable. | `caseCard`, `contactRow` |

Why: dumb components are unit-testable in isolation; data-fetching changes only touch the container; loading/error state lives in one place.

### Data-flow direction (one-way)

```
Parent  -> Child    via @api properties / @api methods
Child   -> Parent   via CustomEvent (this.dispatchEvent)
Sibling -> Sibling  via LMS, or via a common parent
```

A dumb component never imports Apex when its container already owns that data. Sibling-to-sibling without a common parent uses LMS only.

---

## 3. Reactive Properties -- `@api`, `@track`

LWC is reactive by default for primitive reassignment. `@track` is rarely needed in modern API levels.

### `@api` -- public, set by parent or App Builder
- Set by parent in HTML or by App Builder via `targetConfigs`.
- **MUST NOT be mutated inside the component** -- violates one-way binding; throws in strict mode.
- For derived values, expose a getter.

```js
import { LightningElement, api } from 'lwc';
export default class CaseCard extends LightningElement {
    @api caseRecord;                                  // do NOT mutate
    get displayStatus() {                             // derived via getter
        return this.caseRecord ? this.caseRecord.Status.toUpperCase() : '';
    }
    handleClick() {                                   // dispatch upward; let parent mutate
        this.dispatchEvent(new CustomEvent('closecase', {
            detail: { caseId: this.caseRecord.Id }
        }));
    }
}
```

Standard context `@api`: `@api recordId`, `@api objectApiName` (auto-set on record pages). For Flow Screens use `role="inputOnly"` / `role="outputOnly"` in `targetConfigs`.

### `@track` -- only for deep mutation of nested objects/arrays

```js
@track filterState = { status: 'New' };
handleChange(e) { this.filterState.status = e.detail.value; }   // @track needed for inner mutation

// Idiomatic alternative -- reassign, no @track:
this.filterState = { ...this.filterState, status: e.detail.value };
```

Primitives are always reactive -- never wrap them in `@track`.

---

## 4. `@wire` Service

Declaratively binds a wire adapter to a property or function. Reactive: when inputs change, the wire re-fetches. Results cached per user/method/parameter signature.

```js
import { LightningElement, wire, api } from 'lwc';
import getCases from '@salesforce/apex/CaseDashboardController.getCases';
import getCasesByAccount from '@salesforce/apex/CaseDashboardController.getCasesByAccount';

export default class CaseDashboardContainer extends LightningElement {
    @api recordId;

    // Property form
    @wire(getCases) wiredCases;
    get cases() { return this.wiredCases.data; }
    get error() { return this.wiredCases.error; }

    // Reactive parameter -- '$' marks reactive
    @wire(getCasesByAccount, { accountId: '$recordId' }) wiredByAccount;

    // Function form -- custom handling
    @wire(getCases)
    wiredCasesHandler({ data, error }) {
        this.isLoading = false;
        if (data)       { this.cases = data; this.error = undefined; }
        else if (error) { this.error = reduceErrors(error); this.cases = undefined; }
    }
}
```

UI API adapters (no Apex):
```js
import { getRecord } from 'lightning/uiRecordApi';
import CASE_STATUS  from '@salesforce/schema/Case.Status';
@wire(getRecord, { recordId: '$recordId', fields: [CASE_STATUS] }) wiredCase;
```

**Do NOT use `@wire` when:** the call is user-action driven; the method does DML; you need explicit spinner control; you need sequencing or retry.

---

## 5. Imperative Apex

Use when you need explicit control: button-triggered loads, DML, sequencing, custom error handling.

```js
import saveCase from '@salesforce/apex/CaseDashboardController.saveCase';

async handleSave() {
    this.isLoading = true; this.error = undefined;
    try {
        const result = await saveCase({ caseId: this.recordId, newStatus: this.selectedStatus });
        this.dispatchEvent(new CustomEvent('saved', { detail: { result } }));
    } catch (e) {
        this.error = reduceErrors(e);
    } finally {
        this.isLoading = false;
    }
}
```

### `@wire` vs imperative -- decision table

| Scenario | Use | Reason |
|---|---|---|
| Load record on render, reactive to record changes | `@wire` | Auto-reactive, cached |
| Related list reactive to `recordId` | `@wire` Apex | Cache + reactivity |
| Load on button click | imperative | User-triggered |
| Submit / save / delete | imperative | DML; cannot be cacheable |
| Sequence A then B then C | imperative | Wires fire independently |
| Explicit spinner toggle | imperative | Wire has no loading state |
| Custom retry on failure | imperative | Wire has no retry hook |
| Read-only detail panel | `@wire` | Simplest |

---

## 6. Lightning Data Service vs Custom Apex

LDS uses the UI API to read/write records with FLS, caching, and reactivity -- no Apex needed.

| Scenario | Use | Why |
|---|---|---|
| Read single record (standard fields) | `getRecord` | FLS, caching, reactivity built in |
| Picklist values | `getPicklistValues` | No Apex |
| Object info (label, fields) | `getObjectInfo` | Reactive |
| Create / update / delete | `createRecord` / `updateRecord` / `deleteRecord` | FLS enforced |
| Inline edit form | `lightning-record-edit-form` + `lightning-input-field` | Zero JS |
| Multi-object SOQL, aggregation, GROUP BY | Custom Apex | UI API doesn't support |
| Custom business logic on save | Custom Apex | LDS bypasses logic |
| Complex related-list filters | Custom Apex | More control |

```js
import { createRecord } from 'lightning/uiRecordApi';
import CASE_OBJECT  from '@salesforce/schema/Case';
import CASE_SUBJECT from '@salesforce/schema/Case.Subject';
import CASE_STATUS  from '@salesforce/schema/Case.Status';

async handleCreate() {
    const fields = {};
    fields[CASE_SUBJECT.fieldApiName] = this.subject;
    fields[CASE_STATUS.fieldApiName]  = 'New';
    const result = await createRecord({ apiName: CASE_OBJECT.objectApiName, fields });
    this.dispatchEvent(new CustomEvent('created', { detail: { id: result.id } }));
}
```

**Prefer base record components** (`lightning-record-form`, `lightning-record-edit-form`, `lightning-record-view-form`) when the requirement is "show/edit a record's fields with FLS." Drop to custom Apex only when business logic, multi-object joins, or aggregates are involved.

---

## 7. Apex Controller Requirements

1. `with sharing` -- always, unless explicitly justified.
2. `@AuraEnabled(cacheable=true)` ONLY on read-only methods. DML in a cacheable method throws at runtime.
3. CRUD/FLS enforced via `WITH USER_MODE` on SOQL and `as user` on DML.
4. `AuraHandledException` with a user-safe message. Raw exception messages MUST NOT reach the UI.
5. Custom permissions for method-level access control when role/profile is insufficient.

```apex
public with sharing class CaseDashboardController {

    @AuraEnabled(cacheable=true)
    public static List<Case> getCases() {
        if (!Schema.sObjectType.Case.isAccessible()) {
            throw new AuraHandledException('Insufficient access to Cases');
        }
        return [
            SELECT Id, Subject, Status, Priority, Account.Name, CreatedDate
            FROM Case WITH USER_MODE
            ORDER BY CreatedDate DESC LIMIT 50
        ];
    }

    @AuraEnabled
    public static void closeCase(Id caseId) {
        if (caseId == null) throw new AuraHandledException('caseId is required');
        if (!Schema.sObjectType.Case.isUpdateable()) {
            throw new AuraHandledException('Insufficient access to update Cases');
        }
        try {
            update as user new Case(Id = caseId, Status = 'Closed');
        } catch (DmlException e) {
            throw new AuraHandledException('Error closing case: ' + e.getDmlMessage(0));
        } catch (Exception e) {
            throw new AuraHandledException('Unexpected error: please contact support');
        }
    }
}
```

### Security enforcement matrix

| Mechanism | Enforces | When |
|---|---|---|
| `with sharing` keyword | Record sharing only -- NOT FLS | Always |
| `WITH USER_MODE` in SOQL | CRUD + FLS at query | All queries |
| `as user` on DML | CRUD + FLS at write | All DML |
| `WITHOUT USER_MODE` | Nothing | Admin jobs only; document justification |

---

## 8. Error Handling -- Four-State Template

Always handle both `data` and `error`. Never surface raw stacktraces. Friendly message in UI; `console.error` for technical detail.

```js
// c/errorUtils/errorUtils.js
export function reduceErrors(errors) {
    if (!Array.isArray(errors)) errors = [errors];
    return errors
        .filter(e => !!e)
        .map(e => {
            if (Array.isArray(e.body))                            return e.body.map(b => b.message);
            if (e.body && typeof e.body.message === 'string')     return e.body.message;
            if (typeof e.message === 'string')                    return e.message;
            return e.toString();
        })
        .reduce((p, c) => p.concat(c), [])
        .join(', ');
}
```

Toast:
```js
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
this.dispatchEvent(new ShowToastEvent({ title, message, variant })); // 'success' | 'error' | 'warning' | 'info'
```

---

## 9. Loading / Empty / Success / Error -- State Machine

Every container handles exactly four states.

| State | Trigger | UI |
|---|---|---|
| `isLoading` | wire/imperative in flight | `lightning-spinner` |
| `hasError`  | error returned | SLDS alert |
| `hasData`   | data returned, non-empty | Rendered content |
| `isEmpty`   | data returned, empty array | "No records found" |

```js
isLoading = true; error; cases;
get hasError() { return !!this.error; }
get hasData()  { return this.cases && this.cases.length > 0; }
get isEmpty()  { return this.cases && this.cases.length === 0; }
```

```html
<template>
    <lightning-card title="Cases" icon-name="standard:case">
        <div class="slds-var-p-around_medium">
            <template lwc:if={isLoading}>
                <lightning-spinner alternative-text="Loading cases..." size="medium"></lightning-spinner>
            </template>
            <template lwc:elseif={hasError}>
                <div class="slds-notify slds-notify_alert slds-alert_error" role="alert" data-id="error-message">
                    <p>{error}</p>
                </div>
            </template>
            <template lwc:elseif={hasData}>
                <template for:each={cases} for:item="c">
                    <c-case-card key={c.Id} case-record={c}
                                 oncaseselected={handleCaseSelected}
                                 onclosecase={handleCloseCase}></c-case-card>
                </template>
            </template>
            <template lwc:else>
                <p data-id="empty-message" class="slds-text-body_regular">No cases found.</p>
            </template>
        </div>
    </lightning-card>
</template>
```

Use `lwc:if` / `lwc:elseif` / `lwc:else` -- never `style="display:none"` for conditional rendering. The hidden element still mounts and causes accessibility/performance issues.

---

## 10. `refreshApex` -- Re-fetching after mutations

Invalidates a `@wire` cache so the next read fetches fresh. Imperative calls have no wire result -- re-call imperatively instead.

```js
import { refreshApex } from '@salesforce/apex';

wiredCasesResult;                                      // store the raw wire result
@wire(getCases)
wiredCasesHandler(result) {
    this.wiredCasesResult = result;
    const { data, error } = result;
    if (data) this.cases = data;
    else if (error) this.error = reduceErrors(error);
}

async handleCloseCase(event) {
    await closeCase({ caseId: event.detail.caseId });
    await refreshApex(this.wiredCasesResult);
}
```

If `refreshApex` returns stale data (rare -- usually CDN cache), switch to an imperative re-fetch in the mutation handler.

---

## 11. Custom Events -- Child to Parent

```js
// child
this.dispatchEvent(new CustomEvent('caseselected', {
    detail:   { caseId: this.caseRecord.Id },
    bubbles:  false,
    composed: false
}));
```

```html
<!-- parent -- event name 'caseselected' maps to attribute 'oncaseselected' (no camelCase) -->
<c-case-card key={c.Id} case-record={c} oncaseselected={handleCaseSelected}></c-case-card>
```

### Naming rules
- Lowercase, no camelCase: `caseselected`, `form-submitted`, `record-deleted`.
- Be specific: `caseselected` not `selected`.

### `bubbles` / `composed` matrix

| Setting | Behavior | When |
|---|---|---|
| `bubbles: false` (default) | Direct parent only | Standard parent-child |
| `bubbles: true` | Propagates up DOM tree | Grandparent listens |
| `composed: true` | Crosses shadow-DOM boundary | Escape shadow root |
| Both `true` | Everywhere | Rare -- prefer LMS |

---

## 12. Lightning Message Service (LMS)

For components without a parent-child relationship: different page regions, different App Builder sections, across Experience Cloud pages.

```xml
<!-- messageChannels/CaseSelected.messageChannel-meta.xml -->
<?xml version="1.0" encoding="UTF-8"?>
<LightningMessageChannel xmlns="http://soap.sforce.com/2006/04/metadata">
    <masterLabel>Case Selected</masterLabel>
    <isExposed>true</isExposed>
    <lightningMessageFields><fieldName>caseId</fieldName></lightningMessageFields>
    <lightningMessageFields><fieldName>caseSubject</fieldName></lightningMessageFields>
</LightningMessageChannel>
```

```js
import { MessageContext, publish, subscribe, unsubscribe } from 'lightning/messageService';
import CHANNEL from '@salesforce/messageChannel/CaseSelected__c';

@wire(MessageContext) messageContext;
subscription;

connectedCallback() {
    this.subscription = subscribe(this.messageContext, CHANNEL, (m) => this.handleMessage(m));
}
disconnectedCallback() {
    unsubscribe(this.subscription); this.subscription = null;    // critical -- leaked subs = ghost handlers
}
publishSelection(caseId, caseSubject) {
    publish(this.messageContext, CHANNEL, { caseId, caseSubject });
}
```

Don't use LMS for parent " child (use `@api` + `CustomEvent`), cross-app navigation (use `NavigationMixin`), or sibling pairs where a common parent is trivial.

---

## 13. Lightning Navigation Service

```js
import { NavigationMixin } from 'lightning/navigation';
export default class CaseActions extends NavigationMixin(LightningElement) {
    navigateToCase(caseId) {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: { recordId: caseId, actionName: 'view' }
        });
    }
}
```

### Common `PageReference` types

| `type` | Use |
|---|---|
| `standard__recordPage` | View/edit a record by Id |
| `standard__objectPage` | Object home, list view, new-record action |
| `standard__namedPage` | Named pages: `home`, `chatter`, `dashboard` |
| `standard__app` | Lightning app |
| `standard__component` | Stand-alone LWC route (rare) |
| `standard__webPage` | External URL |
| `comm__namedPage` | Experience Cloud named page |

`[NavigationMixin.Navigate](ref)` navigates now; `[NavigationMixin.GenerateUrl](ref)` returns the URL string asynchronously -- use for `href` bindings, copy-to-clipboard, share buttons. Never hardcode URLs -- they break in Experience Cloud, console apps, and the mobile app.

---

## 14. Component Lifecycle Hooks

| Hook | When | Allowed / Required |
|---|---|---|
| `constructor()` | Instance created | `super()` first. No `this.template`, no `@api` reads (not set yet). |
| `connectedCallback()` | Inserted into DOM | `@api` is set; `this.template` available. Subscribe to LMS; one-shot imperative loads. |
| `renderedCallback()` | After every render | DOM-dependent JS init. Guard with `isInitialized` to avoid loops. |
| `disconnectedCallback()` | Removed from DOM | Unsubscribe LMS, clear intervals, remove listeners. |
| `errorCallback(err, stack)` | Child threw | Capture for fallback UI; log technical detail. |

```js
isInitialized = false;
renderedCallback() {
    if (this.isInitialized) return;          // critical -- prevents render loop
    this.isInitialized = true;
}
disconnectedCallback() {
    unsubscribe(this.subscription); this.subscription = null;
    clearInterval(this.pollingInterval);
}
```

---

## 15. Security -- Server-side is the only real check

UI security is UX. Server-side enforcement in Apex is security. Hiding a button behind `lwc:if={canEdit}` is for users -- the Apex behind it MUST independently enforce permissions; otherwise any user can invoke it through the API.

```js
import HAS_CASE_EDIT from '@salesforce/customPermission/Case_Edit_Permission';
get canEditCase() { return HAS_CASE_EDIT; }
```
```html
<template lwc:if={canEditCase}>
    <lightning-button label="Edit" onclick={handleEdit}></lightning-button>
</template>
```

Apex MUST still enforce CRUD/FLS independently:
```apex
if (!Schema.sObjectType.Case.isUpdateable()) {
    throw new AuraHandledException('Insufficient access to update Cases');
}
```

Any authenticated user with access to the Apex class can invoke any `@AuraEnabled` method on it. Restrict with permission sets, custom permissions, or explicit CRUD/FLS checks inside the method. Never rely on UI hiding as the security boundary. Don't surface sensitive fields (SSN, payment data, secrets) through `@AuraEnabled` unless explicitly required and FLS-gated.

---

## 16. Lightning Web Security (LWS)

LWS is the JavaScript test environment that replaces Locker Service in modern orgs. Implications:

- Each component runs in its own JavaScript realm. DOM and JS objects do not leak across components.
- Cannot access `window.parent`, `document.body` outside the component, or another component's DOM.
- Cannot reach into a sibling LWC's shadow DOM.
- Third-party libraries must be LWS-compatible -- libraries that monkey-patch globals, use cross-realm prototype chains, or rely on `eval` / `Function` constructors often fail.
- LWS applies surgical distortions to `window` / `document` / `Element`; some library code that touches these APIs needs adjustments or polyfills.
- Static resources loaded with `loadScript` / `loadStyle` (from `lightning/platformResourceLoader`) run inside the test environment.

When LWS blocks a 3rd-party lib: replace the lib, wrap it in a custom LWC exposing only the needed surface, or check the vendor for an LWS-compatible build.

---

## 17. Performance

- `@wire` + `cacheable=true` caches per user Ã-- method Ã-- parameter signature. Call `refreshApex` after mutations to avoid stale reads.
- Avoid expensive getters -- they run on every render. Move heavy work to the wire handler:
  ```js
  // WRONG -- runs every render
  get filteredCases() { return this.cases.filter(c => /* heavy */); }
  // RIGHT -- compute when data changes
  @wire(getCases) wiredHandler({ data }) { if (data) this.filteredCases = data.filter(c => /* heavy */); }
  ```
- Combine Apex calls into one wrapper method when the page needs multiple datasets.
- `lwc:if` removes element from DOM; `style="display:none"` keeps it mounted -- only use when DOM presence is intentional.
- Use `for:each` for standard lists; `iterator:it` when you need first/last detection.
- ALWAYS set `key={item.Id}` on `for:each` root elements -- without it LWC warns and may re-render incorrectly.

---

## 18. Accessibility

1. **Icon-only buttons** -- `aria-label`. `<lightning-button-icon icon-name="utility:edit" aria-label="Edit Case">`.
2. **Form inputs** -- use `lightning-input` / `lightning-combobox` (built-in labels).
3. **Icons** -- `alternative-text` on `lightning-icon`.
4. **Keyboard** -- every interactive element reachable by Tab; activatable by Enter/Space.
5. **ARIA live** -- `role="status" aria-live="polite"` for dynamic announcements.
6. **Color is never the only signal** -- pair with icon/text.
7. **Focus management** -- move focus into opened modals; return focus to trigger on close.

Test with NVDA + Chrome (Windows) and VoiceOver + Safari (macOS). Verify dynamic content changes are announced.

---

## 19. CSS, SLDS, and Design Tokens

- **SLDS first** -- `slds-var-p-around_medium`, `slds-text-heading_medium`, `slds-grid`, `slds-col`. Custom CSS only when SLDS is insufficient.
- **Scoped CSS** -- `<bundle>.css` is automatically scoped to the component. You CANNOT style internals of standard `lightning-*` components directly; use CSS custom properties / SLDS 2 styling hooks instead.
- **Design tokens:**
  ```css
  .case-card {
      background-color: var(--lwc-colorBackground, #f3f3f3);
      border-radius:    var(--lwc-borderRadiusMedium, 4px);
      padding:          var(--lwc-spacingSmall, 8px);
  }
  ```
- Don't use IDs for styling (LWC transforms them). Don't use `!important` -- re-architect the selector or override via a CSS custom property. Don't hardcode colors when an SLDS token exists.

---

## 20. Jest Testing

Every container component has Jest tests covering: loading, error, success, empty states, every dispatched event, and key user interactions.

```
force-app/main/default/lwc/caseDashboardContainer/
  __tests__/
    caseDashboardContainer.test.js
    data/getCasesData.json
```

```js
import { createElement } from 'lwc';
import CaseDashboardContainer from 'c/caseDashboardContainer';
import getCases from '@salesforce/apex/CaseDashboardController.getCases';
import { registerApexTestWireAdapter } from '@salesforce/sfdx-lwc-jest';

const getCasesAdapter = registerApexTestWireAdapter(getCases);
const MOCK = [
    { Id: '5001000000AAAA1', Subject: 'Test 1', Status: 'New',    Priority: 'High' },
    { Id: '5001000000AAAA2', Subject: 'Test 2', Status: 'Closed', Priority: 'Low'  }
];

describe('c-case-dashboard-container', () => {
    afterEach(() => {
        while (document.body.firstChild) document.body.removeChild(document.body.firstChild);
        jest.clearAllMocks();
    });

    it('shows spinner before wire resolves', () => {
        const el = createElement('c-case-dashboard-container', { is: CaseDashboardContainer });
        document.body.appendChild(el);
        expect(el.shadowRoot.querySelector('lightning-spinner')).not.toBeNull();
    });

    it('renders cards when data resolves', async () => {
        const el = createElement('c-case-dashboard-container', { is: CaseDashboardContainer });
        document.body.appendChild(el);
        getCasesAdapter.emit({ data: MOCK, error: undefined });
        await Promise.resolve();
        expect(el.shadowRoot.querySelectorAll('c-case-card').length).toBe(MOCK.length);
    });

    it('shows error on wire error', async () => {
        const el = createElement('c-case-dashboard-container', { is: CaseDashboardContainer });
        document.body.appendChild(el);
        getCasesAdapter.emit({ data: undefined, error: { body: { message: 'Insufficient access' } } });
        await Promise.resolve();
        expect(el.shadowRoot.querySelector('[data-id="error-message"]').textContent).toContain('Insufficient access');
    });

    it('shows empty state on empty array', async () => {
        const el = createElement('c-case-dashboard-container', { is: CaseDashboardContainer });
        document.body.appendChild(el);
        getCasesAdapter.emit({ data: [], error: undefined });
        await Promise.resolve();
        expect(el.shadowRoot.querySelector('[data-id="empty-message"]')).not.toBeNull();
    });
});
```

Mocking imperative Apex:
```js
jest.mock('@salesforce/apex/CaseDashboardController.closeCase',
    () => ({ default: jest.fn() }), { virtual: true });
```

LWC re-renders are async -- always `await Promise.resolve()` (or chain multiple) after emitting/setting before asserting on the DOM. Keep large fixtures in `__tests__/data/*.json`. Use realistic 18-character Salesforce IDs.

---

## 21. Metadata XML Targets

Common `<target>` values:

| Target | Use |
|---|---|
| `lightning__RecordPage` | Object record pages |
| `lightning__AppPage` | App pages |
| `lightning__HomePage` | Home page |
| `lightning__FlowScreen` | Inside Screen Flows |
| `lightning__UtilityBar` | Utility bar |
| `lightning__Tab` | Lightning tab |
| `lightningCommunity__Page` | Experience Cloud page |

```xml
<?xml version="1.0" encoding="UTF-8"?>
<LightningComponentBundle xmlns="http://soap.sforce.com/2006/04/metadata">
    <apiVersion>66.0</apiVersion>
    <isExposed>true</isExposed>
    <targets>
        <target>lightning__RecordPage</target>
        <target>lightning__AppPage</target>
    </targets>
    <targetConfigs>
        <targetConfig targets="lightning__RecordPage">
            <property name="recordId" type="String" label="Record Id"
                      description="Auto-populated on record pages."/>
        </targetConfig>
        <targetConfig targets="lightning__FlowScreen">
            <property name="caseId"    type="String"  role="inputOnly"  label="Case Id"/>
            <property name="isSuccess" type="Boolean" role="outputOnly" label="Is Success"/>
        </targetConfig>
    </targetConfigs>
</LightningComponentBundle>
```

For utility/internal-only bundles: `<isExposed>false</isExposed>` and omit `<targets>`.

---

## 22. File Structure and Naming

```
force-app/main/default/lwc/
""" caseDashboardContainer/
"‚   """ caseDashboardContainer.html
"‚   """ caseDashboardContainer.js
"‚   """ caseDashboardContainer.js-meta.xml
"‚   """ caseDashboardContainer.css            (optional)
"‚   """" __tests__/
"‚       """ caseDashboardContainer.test.js
"‚       """" data/getCasesData.json
""" caseCard/ ...
"""" errorUtils/ ...
```

| Element | Convention | Example |
|---|---|---|
| Bundle folder | camelCase, starts lowercase | `caseDashboardContainer` |
| File names | match folder name | `caseDashboardContainer.html` |
| Tag name | `c-` + kebab-case | `<c-case-dashboard-container>` |
| Apex controller | PascalCase | `CaseDashboardController` |
| Custom event names | lowercase, no camelCase | `caseselected`, `form-submitted` |
| Message channel | PascalCase + `__c` | `CaseSelected__c` |

Rejected: `CaseDashboardContainer/` (uppercase first), `case-dashboard-container/` (hyphens), `case_dashboard_container/` (underscores).

---

## 23. Definition of Done (LWC-specific)

- [ ] Smart/dumb split documented; container owns state
- [ ] All four states: loading, error, data, empty
- [ ] `isLoading = true` initial; toggled in wire/imperative handler
- [ ] Wire result stored for `refreshApex`; `refreshApex` called after every mutation
- [ ] No hardcoded record IDs or org-specific values
- [ ] `@api` properties validated; never mutated
- [ ] Event names lowercase, no camelCase
- [ ] `lwc:if` for conditional rendering (not `display:none`)
- [ ] `key` set on every `for:each` root element
- [ ] Apex: `with sharing`, `cacheable=true` only on reads, `WITH USER_MODE` + `as user`, `AuraHandledException`
- [ ] Server-side CRUD/FLS independent of UI gating; no sensitive fields exposed
- [ ] Interactive elements have label or `aria-label`; icons have `alternative-text`; keyboard navigation works
- [ ] Jest tests in `__tests__/` cover loading, error, success, empty, interactions, events
- [ ] `npm run test:unit` passes; coverage >=85%
- [ ] `.js-meta.xml` has correct `apiVersion`, `isExposed`, and `targets`
- [ ] Deploys clean; no browser console errors

---

## 24. Validation Commands

```bash
# Jest
npm run test:unit
npm run test:unit -- --coverage
npm run test:unit -- --testPathPattern caseDashboard

# Deploy bundle + controller (check-only)
sf project deploy start \
   --metadata "LightningComponentBundle:caseDashboardContainer,ApexClass:CaseDashboardController" \
   --target-org <target-env-alias> --check-only --wait 60

# Retrieve from org
sf project retrieve start \
   --metadata "LightningComponentBundle:caseDashboardContainer" \
   --target-org <target-env-alias>

# Run Apex tests for the controller
sf apex run test --class-names CaseDashboardControllerTest \
   --target-org <target-env-alias> --wait 10 --result-format human
```

---

## 25. Common AI Mistakes to Avoid

| # | Mistake | Impact | Correct Approach |
|---|---|---|---|
| 1 | Missing error state in template | Users see blank component when Apex fails | Implement all four states: loading, error, data, empty |
| 2 | Missing loading spinner | Users see flash of empty state before data loads | Set `isLoading = true` initially; set false in wire handler |
| 3 | Business logic in presentational component | Not reusable, untestable | Keep Apex calls and state in container; dumb component only renders |
| 4 | `@AuraEnabled(cacheable=true)` on DML method | DML exception at runtime | Use `@AuraEnabled` (no cacheable) for any mutation |
| 5 | Apex class without `with sharing` | Users can read/write records they shouldn't | Always use `with sharing` unless justified and documented |
| 6 | Exposing raw exception message to user | Poor UX; may expose internal details | Use `AuraHandledException` with user-safe message in Apex |
| 7 | Missing Jest tests | Bugs go undetected; regressions introduced | Write tests for all four states and all user interactions |
| 8 | Not calling `refreshApex` after mutations | Stale data shown after save/delete | Store wire result; call `refreshApex(this.wiredResult)` |
| 9 | Hardcoded record IDs or org-specific values | Breaks in different orgs/test environmentes | Use `@api recordId`, Custom Labels, or Custom Metadata |
| 10 | Missing `aria-label` on icon-only buttons | Inaccessible to screen reader users | Always set `aria-label` on interactive elements without text |
| 11 | Mutating `@api` property inside component | Runtime LWC error in strict mode | Copy to internal variable; dispatch event to parent for mutations |
| 12 | SOQL in Apex without `WITH USER_MODE` | FLS not enforced; users see unauthorized data | Use `WITH USER_MODE` on all queries |
| 13 | Not defining `isExposed` correctly in meta XML | Component appears or doesn't appear in App Builder unexpectedly | Set `isExposed: false` for utility/internal components |
| 14 | Using `window.location` for navigation | Breaks in Experience Cloud; bypasses navigation stack | Use `NavigationMixin.Navigate` always |
| 15 | No LMS unsubscribe in `disconnectedCallback` | Memory leak; ghost event handlers | Always `unsubscribe(this.subscription)` in disconnectedCallback |
| 16 | Expensive computation in getter | Performance degradation on every render | Move computation to wire handler or connectedCallback |
| 17 | DML method marked `cacheable=true` | Exception: DML not allowed in cacheable context | Remove cacheable from any method with insert/update/delete |
| 18 | Missing `super()` in constructor | Component fails to render | Always call `super()` first in constructor |
| 19 | Using `style="display:none"` for conditional rendering | Element remains in DOM; accessibility issues | Use `lwc:if` for true conditional rendering |
| 20 | No `key` attribute on `for:each` items | LWC warning; incorrect re-rendering on list changes | Always set `key={item.Id}` on `for:each` root elements |

---

## 26. Empirical Findings & Implementation Notes

When Salesforce's documented approach doesn't work in the target environment / version / feature combination, the workaround goes here. Date-stamp every entry.

| # | Date | Documented approach | What actually works | Why / Context |
|---|---|---|---|---|

*(No entries yet -- append a row the first time a documented pattern fails to behave as expected in the target environment.)*

---

## 27. Official References

- [LWC Developer Guide](https://developer.salesforce.com/docs/component-library/documentation/en/lwc)
- [LWC Platform Guide](https://developer.salesforce.com/docs/platform/lwc/guide/)
- [Component Library -- Reference](https://developer.salesforce.com/docs/component-library/overview/components)
- [@api / Public Properties](https://developer.salesforce.com/docs/component-library/documentation/en/lwc/lwc.js_props_public)
- [@wire -- Wire Service](https://developer.salesforce.com/docs/component-library/documentation/en/lwc/lwc.use_wire_service)
- [Lightning Data Service -- UI Record API](https://developer.salesforce.com/docs/component-library/documentation/en/lwc/lwc.reference_lightning_ui_api_record)
- [Composition / Events](https://developer.salesforce.com/docs/component-library/documentation/en/lwc/lwc.events)
- [Lightning Navigation](https://developer.salesforce.com/docs/component-library/documentation/en/lwc/lwc.use_navigate)
- [Lightning Message Service](https://developer.salesforce.com/docs/component-library/documentation/en/lwc/lwc.use_message_channel)
- [Lightning Web Security](https://developer.salesforce.com/docs/platform/lightning-components-security/guide/intro-lws.html)
- [Jest Testing for LWC](https://developer.salesforce.com/docs/component-library/documentation/en/lwc/lwc.unit_testing_using_jest_introduction)
- [@AuraEnabled Annotation](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_classes_annotation_AuraEnabled.htm)
- [WITH USER_MODE in SOQL/DML](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_classes_with_security_enforced.htm)
- [SLDS Utilities](https://www.lightningdesignsystem.com/utilities/)
- [trailheadapps/lwc-recipes](https://github.com/trailheadapps/lwc-recipes)
- [forcedotcom/sf-skills `generating-lwc-components`](https://github.com/forcedotcom/sf-skills/tree/main/skills/generating-lwc-components)

---

*LWC Guidelines | v3.0 | Last verified 2026-05-16*

