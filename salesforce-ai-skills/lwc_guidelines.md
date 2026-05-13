# Lightning Web Component (LWC) Guidelines

**Version**: 2.0 (April 2026)
**Developer**: Naresh | Senior Salesforce Developer
**Purpose**: Standalone guidelines for LWC development. Attach this file when writing, reviewing, or refactoring any Lightning Web Component.

---

## Table of Contents

1. [Required Agent Output Contract](#required-agent-output-contract)
2. [Component Architecture](#component-architecture)
3. [@api Properties](#api-properties)
4. [@track and Reactive Properties](#track-and-reactive-properties)
5. [@wire Usage](#wire-usage)
6. [@wire vs Imperative Apex Decision Table](#wire-vs-imperative-apex-decision-table)
7. [LDS / UI API vs Apex Decision Table](#lds--ui-api-vs-apex-decision-table)
8. [Apex Controller Requirements](#apex-controller-requirements)
9. [Error Handling](#error-handling)
10. [Loading / Empty / Success / Error States](#loading--empty--success--error-states)
11. [refreshApex](#refreshapex)
12. [Custom Events and Communication](#custom-events-and-communication)
13. [Lightning Navigation](#lightning-navigation)
14. [Lightning Message Service (LMS)](#lightning-message-service-lms)
15. [Component Lifecycle Hooks](#component-lifecycle-hooks)
16. [Security](#security)
17. [Performance](#performance)
18. [Accessibility](#accessibility)
19. [CSS and Styling](#css-and-styling)
20. [Jest Testing](#jest-testing)
21. [Metadata XML Targets](#metadata-xml-targets)
22. [File Structure and Naming](#file-structure-and-naming)
23. [Common AI Mistakes to Avoid](#common-ai-mistakes-to-avoid)
24. [Definition of Done (LWC-specific)](#definition-of-done-lwc-specific)
25. [Validation Commands](#validation-commands)
26. [Official References](#official-references)

---

## Required Agent Output Contract

Every LWC implementation response MUST include ALL of the following. If any section is missing, the response is incomplete and must not be used as a basis for implementation.

### 1. Component Architecture Plan
State explicitly:
- Which components will be created (smart/container vs presentational/dumb)
- Parent-child relationships and data flow direction
- Where state lives (which component owns loading/error/data state)
- What events flow upward (child to parent)

### 2. Files to Create
List every file for every component:
```
c/caseDashboardContainer
  ├── caseDashboardContainer.html
  ├── caseDashboardContainer.js
  ├── caseDashboardContainer.js-meta.xml
  └── caseDashboardContainer.css (if custom styling needed)

c/caseCard
  ├── caseCard.html
  ├── caseCard.js
  ├── caseCard.js-meta.xml
```

### 3. Apex Controller Classes Needed
For each Apex class:
- Class name
- Methods with signatures
- Whether cacheable or not (and why)
- CRUD/FLS enforcement approach

### 4. Security Notes
- Apex `with sharing` vs `without sharing` — with justification
- CRUD/FLS enforcement in Apex
- Which data fields are exposed to the UI and whether they need FLS protection
- Any `@AuraEnabled` methods accessible to all users (no profile guard)

### 5. Jest Test Strategy
- Which states to test (loading, error, empty, success)
- Which events to test
- Mock strategy for Apex and wire adapters
- Test file names

### 6. Validation Commands
Deployment and test commands for this specific component.

---

## Component Architecture

### The Smart/Dumb Split
**Every feature should be decomposed into at least two layers:**

**Smart Component (Container)**
- Handles data fetching (wire or imperative Apex calls)
- Manages state: `isLoading`, `error`, `data`, `isEmpty`
- Handles mutations (save, delete, update)
- Dispatches or handles events at the boundary with external systems
- Does NOT contain rendering of individual data items (delegates to dumb components)
- Named with `Container` suffix: `casesDashboardContainer`

**Dumb Component (Presentational)**
- Receives data via `@api` properties
- Renders the data
- Dispatches `CustomEvent` upward when user interacts
- Has NO Apex calls, NO wire adapters, NO business logic
- Is reusable — does not know which page or feature it is on
- Named by what it renders: `caseCard`, `contactRow`, `accountTile`

### Why This Split Matters
- Dumb components are unit-testable in complete isolation
- Changing data-fetching strategy only affects the container
- Dumb components are reusable across features
- Loading/error state is centralized — not scattered across child components

### Full Architecture Example: Case Dashboard

```
caseDashboardContainer (smart/container)
  Responsibilities:
    - @wire getCases → handles data/error/loading state
    - renders caseCard for each case in data
    - handles 'caseselected' event from caseCard
    - calls imperitive Apex for mutations (close case)
    - owns: isLoading, error, cases (array)

caseCard (dumb/presentational)
  Responsibilities:
    - @api caseRecord (input)
    - renders: Subject, Status, Priority, Account Name
    - dispatches: 'caseselected' CustomEvent with { detail: { caseId } }
    - dispatches: 'closecase' CustomEvent with { detail: { caseId } }

caseCloseModal (dumb/presentational)
  Responsibilities:
    - @api isOpen (Boolean)
    - @api caseId (Id)
    - renders: confirmation modal content
    - dispatches: 'confirm' CustomEvent
    - dispatches: 'cancel' CustomEvent
```

### Data Flow Direction
```
Parent → Child: via @api properties (one-way down)
Child → Parent: via CustomEvent (one-way up)
Sibling to Sibling: via LMS or common parent (never directly)
```

Never bypass this hierarchy. Child components should never import and call Apex directly if the parent container owns that data.

---

## @api Properties

### Purpose
`@api` exposes a property or method on a component so it can be set by a parent component or by the Lightning App Builder (in the case of design attributes).

### Rules
- `@api` properties must be **primitive types** (String, Number, Boolean, Array, Object) for LWC-to-LWC communication
- Never mutate an `@api` property inside the component — it violates one-way data binding and will throw a runtime error in strict mode
- If you need to modify incoming data, copy it to an internal variable in `connectedCallback` or a getter
- Validate `@api` inputs — never assume the parent set a required value

### Correct Pattern
```js
import { LightningElement, api } from 'lwc';

export default class CaseCard extends LightningElement {
    @api caseRecord; // received from parent — do NOT mutate

    // If you need a derived/modified version:
    get displayStatus() {
        return this.caseRecord ? this.caseRecord.Status.toUpperCase() : '';
    }
}
```

### Anti-Pattern
```js
// WRONG: mutating @api property
handleClick() {
    this.caseRecord.Status = 'Closed'; // throws error in strict mode
}

// CORRECT: dispatch event upward; let parent handle mutation
handleClick() {
    this.dispatchEvent(new CustomEvent('closecase', {
        detail: { caseId: this.caseRecord.Id }
    }));
}
```

### @api in Lightning App Builder
For properties configurable in App Builder, also add to `.js-meta.xml`:
```xml
<property name="recordId" type="String" label="Record Id" description="Id of the record to display"/>
```

### Design Attributes for Standard Context Variables
```js
@api recordId;   // automatically set when on Record Page
@api objectApiName; // automatically set when on Record Page
```

---

## @track and Reactive Properties

### When @track Is Needed
- In LWC, all properties are reactive by default for primitive reassignment
- `@track` is only needed when you have a nested object or array and you want LWC to detect mutations to properties **inside** that object/array (deep reactivity)
- In modern LWC (API version 39+), `@track` is rarely needed

### When to Use @track
```js
// Only needed if you mutate properties inside the object:
@track filterState = { status: 'New', priority: 'High' };

handleStatusChange(event) {
    this.filterState.status = event.detail.value; // @track detects this inner mutation
}
```

### When @track Is NOT Needed
```js
// Reassigning the whole object — @track not needed
this.filterState = { ...this.filterState, status: event.detail.value };
// OR for primitives:
this.isLoading = true; // always reactive without @track
```

---

## @wire Usage

### Purpose
`@wire` declaratively binds a wire service (Apex method or UI API adapter) to a component property or function. It is reactive: when inputs change, the wire re-fetches automatically.

### Wire to Apex Method
```js
import { LightningElement, wire } from 'lwc';
import getCases from '@salesforce/apex/CaseDashboardController.getCases';

export default class CaseDashboardContainer extends LightningElement {
    @wire(getCases)
    wiredCases;

    get cases() {
        return this.wiredCases.data;
    }

    get error() {
        return this.wiredCases.error;
    }
}
```

### Wire with Parameters (Reactive)
```js
import { LightningElement, api, wire } from 'lwc';
import getCasesByAccount from '@salesforce/apex/CaseDashboardController.getCasesByAccount';

export default class CaseDashboardContainer extends LightningElement {
    @api recordId; // when this changes, wire re-fetches

    @wire(getCasesByAccount, { accountId: '$recordId' }) // $ prefix = reactive
    wiredCases;
}
```

### Wire to Function (for Complex Handling)
```js
@wire(getCases)
wiredCasesHandler({ data, error }) {
    if (data) {
        this.cases = data;
        this.isEmpty = data.length === 0;
        this.error = undefined;
    } else if (error) {
        this.error = this.reduceErrors(error);
        this.cases = undefined;
    }
    this.isLoading = false;
}
```

### Wire with UI API Adapters
```js
import { getRecord } from 'lightning/uiRecordApi';
import CASE_STATUS from '@salesforce/schema/Case.Status';
import CASE_SUBJECT from '@salesforce/schema/Case.Subject';

@wire(getRecord, { recordId: '$recordId', fields: [CASE_STATUS, CASE_SUBJECT] })
wiredCase;
```

### When NOT to Use @wire
- When you need to call Apex conditionally (based on user action)
- When you need explicit control over loading state
- When the Apex method performs DML or side effects
- When you need to sequence multiple Apex calls

---

## @wire vs Imperative Apex Decision Table

| Scenario | Recommendation | Reason |
|---|---|---|
| Read record data on page load, reactive to record changes | @wire | Automatic reactivity, caching |
| Read list of related records, reactive to input | @wire Apex method | Cache + reactivity |
| Load data when user clicks a button | Imperative | User-triggered, not reactive |
| Submit a form / save data | Imperative | DML method; cannot be cached |
| Load data once with complex conditional logic | Imperative | More control over when/whether to call |
| Need explicit loading spinner control | Imperative | Wire has no loading state property |
| Sequential calls (call B only after A succeeds) | Imperative | Wire calls are independent |
| Need to handle errors with custom retry logic | Imperative | More control |
| Display data in read-only detail view | @wire | Simplest and most cache-efficient |
| Form save, delete, bulk action | Imperative | Side-effecting operations |

### Imperative Apex Pattern
```js
import { LightningElement } from 'lwc';
import saveCase from '@salesforce/apex/CaseDashboardController.saveCase';

export default class CaseSaveForm extends LightningElement {
    isLoading = false;
    error;

    async handleSave() {
        this.isLoading = true;
        this.error = undefined;
        try {
            const result = await saveCase({
                caseId: this.recordId,
                newStatus: this.selectedStatus
            });
            this.dispatchEvent(new CustomEvent('saved', { detail: { result } }));
        } catch (e) {
            this.error = this.reduceErrors(e);
        } finally {
            this.isLoading = false;
        }
    }

    reduceErrors(e) {
        if (typeof e === 'string') return e;
        if (e.body && e.body.message) return e.body.message;
        if (e.message) return e.message;
        return 'Unknown error';
    }
}
```

---

## LDS / UI API vs Apex Decision Table

| Scenario | Recommendation | Why |
|---|---|---|
| Read standard fields on a single record | UI API (`getRecord`) | Built-in FLS, caching, reactivity |
| Read picklist values for standard fields | UI API (`getPicklistValues`) | No custom Apex needed |
| Read object metadata (label, fields list) | UI API (`getObjectInfo`) | Built-in, reactive |
| Create a standard record (basic) | LDS (`createRecord`) | No Apex needed; handles FLS |
| Edit/update a standard record | LDS (`updateRecord`) | No Apex needed; handles FLS |
| Delete a record | LDS (`deleteRecord`) | No Apex needed; handles FLS |
| Read records with custom SOQL / multi-object | Custom Apex | UI API can't do complex SOQL |
| Custom business logic on save | Custom Apex | LDS bypasses custom logic |
| Access custom objects with FLS enforcement | Custom Apex with `WITH USER_MODE` | Explicit FLS enforcement |
| Aggregated query (GROUP BY, SUM, COUNT) | Custom Apex | UI API doesn't support aggregation |
| Read related list with complex filter | Custom Apex | More control than UI API |

### LDS createRecord Example
```js
import { createRecord } from 'lightning/uiRecordApi';
import CASE_OBJECT from '@salesforce/schema/Case';
import CASE_SUBJECT from '@salesforce/schema/Case.Subject';
import CASE_STATUS from '@salesforce/schema/Case.Status';

async handleCreate() {
    const fields = {};
    fields[CASE_SUBJECT.fieldApiName] = this.subject;
    fields[CASE_STATUS.fieldApiName] = 'New';
    const recordInput = { apiName: CASE_OBJECT.objectApiName, fields };
    try {
        const result = await createRecord(recordInput);
        this.dispatchEvent(new CustomEvent('created', { detail: { id: result.id } }));
    } catch (e) {
        this.error = this.reduceErrors(e);
    }
}
```

---

## Apex Controller Requirements

### Mandatory Rules
1. MUST use `with sharing` — always, unless you have explicit documented justification
2. MUST enforce CRUD/FLS explicitly — never assume LWC or the platform does it
3. MUST use `@AuraEnabled(cacheable=true)` ONLY for read-only methods (no DML)
4. MUST use `@AuraEnabled` (no cacheable) for methods that perform DML or have side effects
5. MUST throw `AuraHandledException` with a user-safe message for client-facing errors
6. MUST NOT expose internal exception messages directly to the client

### Class Header Template
```apex
/**
 * @description Apex controller for Case Dashboard LWC.
 *              Provides methods for reading and updating Case records.
 * @developer Naresh
 * @title Senior Salesforce Developer
 * @version 1.0 (April 2026)
 */
public with sharing class CaseDashboardController {
    // ... methods below
}
```

### Read Method (cacheable=true)
```apex
/**
 * @description Returns a list of Cases accessible to the current user.
 * @return List<Case>
 */
@AuraEnabled(cacheable=true)
public static List<Case> getCases() {
    if (!Schema.sObjectType.Case.isAccessible()) {
        throw new AuraHandledException('Insufficient access to Cases');
    }
    return [
        SELECT Id, Subject, Status, Priority, AccountId, Account.Name, CreatedDate
        FROM Case
        WITH USER_MODE
        ORDER BY CreatedDate DESC
        LIMIT 50
    ];
}
```

### Read Method with Parameter
```apex
@AuraEnabled(cacheable=true)
public static List<Case> getCasesByAccount(Id accountId) {
    if (accountId == null) {
        throw new AuraHandledException('accountId is required');
    }
    if (!Schema.sObjectType.Case.isAccessible()) {
        throw new AuraHandledException('Insufficient access to Cases');
    }
    return [
        SELECT Id, Subject, Status, Priority, CreatedDate
        FROM Case
        WHERE AccountId = :accountId
        WITH USER_MODE
        ORDER BY CreatedDate DESC
        LIMIT 100
    ];
}
```

### Mutation Method (no cacheable)
```apex
/**
 * @description Closes a Case by setting Status to Closed.
 * @param caseId Id of the Case to close
 */
@AuraEnabled
public static void closeCase(Id caseId) {
    if (caseId == null) {
        throw new AuraHandledException('caseId is required');
    }
    if (!Schema.sObjectType.Case.isUpdateable()) {
        throw new AuraHandledException('Insufficient access to update Cases');
    }
    try {
        Case c = new Case(Id = caseId, Status = 'Closed');
        update as user c;
    } catch (DmlException e) {
        throw new AuraHandledException('Error closing case: ' + e.getDmlMessage(0));
    } catch (Exception e) {
        throw new AuraHandledException('Unexpected error: please contact support');
    }
}
```

### WITH USER_MODE vs WITH SHARING
| Approach | CRUD/FLS Enforced? | When to Use |
|---|---|---|
| `WITH USER_MODE` in SOQL | Yes, per field | Recommended for all queries |
| `update as user` DML | Yes | Recommended for all DML |
| `with sharing` class keyword | Record sharing only, NOT FLS | Always use, but not sufficient alone |
| `WITHOUT USER_MODE` | No | System admin jobs only; document justification |

---

## Error Handling

### Principles
1. ALWAYS handle both `data` and `error` states from every wire or imperative call
2. Never expose raw Apex exception messages to users in production UI
3. Show user-friendly messages; log technical details separately
4. Provide actionable guidance when possible ("Please try again" or "Contact support")

### The reduceErrors Helper
Define this utility function in every container component (or extract to a shared utility module):
```js
reduceErrors(errors) {
    if (!Array.isArray(errors)) {
        errors = [errors];
    }
    return errors
        .filter(error => !!error)
        .map(error => {
            // UI API errors
            if (Array.isArray(error.body)) {
                return error.body.map(e => e.message);
            }
            // AuraHandledException
            if (error.body && typeof error.body.message === 'string') {
                return error.body.message;
            }
            // JS errors
            if (typeof error.message === 'string') {
                return error.message;
            }
            return error.toString();
        })
        .reduce((prev, curr) => prev.concat(curr), [])
        .join(', ');
}
```

Or import from a shared utility LWC:
```js
import { reduceErrors } from 'c/errorUtils';
```

### Wire Error Handling
```js
@wire(getCases)
wiredCasesHandler({ data, error }) {
    this.isLoading = false;
    if (data) {
        this.cases = data;
        this.isEmpty = data.length === 0;
        this.error = undefined;
    } else if (error) {
        this.error = this.reduceErrors(error);
        this.cases = undefined;
        console.error('getCases wire error:', JSON.stringify(error));
    }
}
```

### Imperative Error Handling
```js
async handleSave() {
    this.isLoading = true;
    this.error = undefined;
    try {
        await saveRecord({
            caseId: this.recordId,
            newStatus: this.selectedStatus
        });
        this.dispatchEvent(new CustomEvent('saved'));
        this.showToast('Success', 'Case saved successfully', 'success');
    } catch (e) {
        this.error = this.reduceErrors(e);
        console.error('saveRecord error:', JSON.stringify(e));
    } finally {
        this.isLoading = false;
    }
}
```

### Toast Notifications
```js
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

showToast(title, message, variant) {
    this.dispatchEvent(new ShowToastEvent({
        title,
        message,
        variant // 'success', 'error', 'warning', 'info'
    }));
}
```

---

## Loading / Empty / Success / Error States

### The State Machine
Every container component must handle exactly four states:

| State | When | What to Show |
|---|---|---|
| `isLoading` | Apex call in progress | `lightning-spinner` |
| `hasError` | Error returned from Apex | Error message component |
| `hasData` | Data returned and non-empty | The actual data content |
| `isEmpty` | Data returned but empty array | "No records found" message |

### JavaScript State Properties
```js
export default class CaseDashboardContainer extends LightningElement {
    isLoading = true; // start as true — data hasn't loaded yet
    error;
    cases;

    get hasError() { return !!this.error; }
    get hasData() { return this.cases && this.cases.length > 0; }
    get isEmpty() { return this.cases && this.cases.length === 0; }

    @wire(getCases)
    wiredCasesHandler({ data, error }) {
        this.isLoading = false;
        if (data) {
            this.cases = data;
            this.error = undefined;
        } else if (error) {
            this.error = this.reduceErrors(error);
            this.cases = undefined;
        }
    }
}
```

### HTML Template — Complete Four-State Pattern
```html
<template>
    <lightning-card title="Cases" icon-name="standard:case">
        <div class="slds-var-p-around_medium">

            <!-- Loading State -->
            <template lwc:if={isLoading}>
                <lightning-spinner
                    alternative-text="Loading cases..."
                    size="medium">
                </lightning-spinner>
            </template>

            <!-- Error State -->
            <template lwc:elseif={hasError}>
                <div class="slds-notify slds-notify_alert slds-alert_error" role="alert">
                    <span class="slds-assistive-text">error</span>
                    <p>{error}</p>
                </div>
            </template>

            <!-- Success / Data State -->
            <template lwc:elseif={hasData}>
                <template for:each={cases} for:item="caseRecord">
                    <c-case-card
                        key={caseRecord.Id}
                        case-record={caseRecord}
                        oncaseselected={handleCaseSelected}
                        onclosecase={handleCloseCase}>
                    </c-case-card>
                </template>
            </template>

            <!-- Empty State -->
            <template lwc:else>
                <div class="slds-illustration slds-illustration_small">
                    <p class="slds-text-body_regular">No cases found.</p>
                </div>
            </template>

        </div>
    </lightning-card>
</template>
```

### lwc:if vs Conditional CSS
- Use `lwc:if` / `lwc:elseif` / `lwc:else` for conditional rendering (removes element from DOM)
- Do NOT use `style="display:none"` to hide elements — the element still renders and may cause accessibility and performance issues
- Exception: CSS-driven show/hide for animations or transitions where DOM presence is needed

---

## refreshApex

### When to Use
Use `refreshApex` when a mutation (save, update, delete) has been made and you need the `@wire`-bound data to re-fetch from the server.

### Setup Pattern
You must store a reference to the wire result to pass to `refreshApex`:
```js
import { LightningElement, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import getCases from '@salesforce/apex/CaseDashboardController.getCases';

export default class CaseDashboardContainer extends LightningElement {
    wiredCasesResult; // store the raw wire result
    cases;

    @wire(getCases)
    wiredCasesHandler(result) {
        this.wiredCasesResult = result; // store for refreshApex
        const { data, error } = result;
        if (data) {
            this.cases = data;
        } else if (error) {
            this.error = this.reduceErrors(error);
        }
    }

    async handleCaseCloseSuccess() {
        await refreshApex(this.wiredCasesResult); // re-fetches getCases
    }
}
```

### What refreshApex Does NOT Do
- Does not work with imperative Apex calls (no wire result to refresh)
- Does not guarantee fresh data from the database if Salesforce's CDN cache hasn't expired
- Does not automatically re-render; re-render happens when wire result updates

### When to Use Imperative Re-fetch Instead
If `refreshApex` is consistently stale, switch to imperative Apex in the mutation handler:
```js
async handleCloseCase(event) {
    const { caseId } = event.detail;
    await closeCase({ caseId });
    // Then re-fetch imperatively
    const freshCases = await getCasesImperative();
    this.cases = freshCases;
}
```

---

## Custom Events and Communication

### Event Direction Rule
- Parent to child: `@api` properties or methods
- Child to parent: `CustomEvent` dispatched with `this.dispatchEvent()`
- Sibling to sibling (no common parent): Lightning Message Service

### Defining a Custom Event
```js
// In child component (caseCard.js):
handleViewCase() {
    this.dispatchEvent(new CustomEvent('caseselected', {
        detail: {
            caseId: this.caseRecord.Id,
            caseSubject: this.caseRecord.Subject
        },
        bubbles: false,  // only bubble if intentional
        composed: false  // only cross shadow DOM if intentional
    }));
}
```

### Listening in Parent
```html
<!-- caseDashboardContainer.html -->
<c-case-card
    key={caseRecord.Id}
    case-record={caseRecord}
    oncaseselected={handleCaseSelected}>
</c-case-card>
```
Note: `caseselected` event name maps to `oncaseselected` attribute (lowercase, no camelCase in HTML).

```js
// In caseDashboardContainer.js:
handleCaseSelected(event) {
    const { caseId, caseSubject } = event.detail;
    this.selectedCaseId = caseId;
}
```

### Event Naming Convention
- Use lowercase, hyphen-separated event names: `caseselected`, `form-submitted`, `record-deleted`
- Do NOT use camelCase in event names: ~~`caseSelected`~~ → use `caseselected`
- Be descriptive: `caseselected` not just `selected`

### bubbles and composed
| Setting | Behavior | When to Use |
|---|---|---|
| `bubbles: false` (default) | Only parent can hear | Standard parent-child (most cases) |
| `bubbles: true` | Propagates up the DOM | When you need grandparent to catch |
| `composed: true` | Crosses shadow DOM boundary | When event needs to escape LWC shadow |
| Both `bubbles: true, composed: true` | Propagates everywhere | Rare — use LMS instead |

---

## Lightning Navigation

### Import
```js
import { LightningElement } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';

export default class CaseDashboardContainer extends NavigationMixin(LightningElement) {
    navigateToCase(caseId) {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: caseId,
                actionName: 'view'
            }
        });
    }

    navigateToNewCase() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: {
                objectApiName: 'Case',
                actionName: 'new'
            }
        });
    }

    navigateToNamedPage(pageName) {
        this[NavigationMixin.Navigate]({
            type: 'standard__namedPage',
            attributes: {
                pageName: pageName // e.g., 'home'
            }
        });
    }
}
```

### NEVER Hardcode Navigation URLs
```js
// WRONG:
window.location.href = '/lightning/r/Case/001XXXXXXXXXX/view';

// CORRECT:
this[NavigationMixin.Navigate]({ type: 'standard__recordPage', ... });
```

### Generate URL (without navigating)
```js
async getRecordUrl(recordId) {
    const url = await this[NavigationMixin.GenerateUrl]({
        type: 'standard__recordPage',
        attributes: { recordId, actionName: 'view' }
    });
    return url;
}
```

---

## Lightning Message Service (LMS)

### When to Use LMS
- Communication between components that do NOT share a parent-child relationship
- Components in different regions of the page (e.g., header and body)
- Components in different Lightning App Builder sections
- Communication across Experience Cloud pages

### When NOT to Use LMS
- Parent-child communication (use `@api` and `CustomEvent`)
- Cross-app navigation (use `NavigationMixin`)
- Simple sibling communication where a common parent can be created

### MessageChannel Metadata File
```xml
<!-- force-app/main/default/messageChannels/CaseSelected.messageChannel-meta.xml -->
<?xml version="1.0" encoding="UTF-8"?>
<LightningMessageChannel xmlns="http://soap.sforce.com/2006/04/metadata">
    <masterLabel>Case Selected</masterLabel>
    <isExposed>true</isExposed>
    <description>Message channel for notifying components when a Case is selected.</description>
    <lightningMessageFields>
        <fieldName>caseId</fieldName>
        <description>Salesforce Id of the selected Case</description>
    </lightningMessageFields>
    <lightningMessageFields>
        <fieldName>caseSubject</fieldName>
        <description>Subject of the selected Case</description>
    </lightningMessageFields>
</LightningMessageChannel>
```

### Publishing (Sender Component)
```js
import { LightningElement, wire } from 'lwc';
import { MessageContext, publish } from 'lightning/messageService';
import CASE_SELECTED_CHANNEL from '@salesforce/messageChannel/CaseSelected__c';

export default class CaseSender extends LightningElement {
    @wire(MessageContext)
    messageContext;

    handleCaseClick(event) {
        const message = {
            caseId: event.currentTarget.dataset.id,
            caseSubject: event.currentTarget.dataset.subject
        };
        publish(this.messageContext, CASE_SELECTED_CHANNEL, message);
    }
}
```

### Subscribing (Receiver Component)
```js
import { LightningElement, wire } from 'lwc';
import { MessageContext, subscribe, unsubscribe } from 'lightning/messageService';
import CASE_SELECTED_CHANNEL from '@salesforce/messageChannel/CaseSelected__c';

export default class CaseReceiver extends LightningElement {
    @wire(MessageContext)
    messageContext;

    subscription;
    selectedCaseId;

    connectedCallback() {
        this.subscription = subscribe(
            this.messageContext,
            CASE_SELECTED_CHANNEL,
            (message) => this.handleMessage(message)
        );
    }

    disconnectedCallback() {
        unsubscribe(this.subscription);
        this.subscription = null;
    }

    handleMessage(message) {
        this.selectedCaseId = message.caseId;
    }
}
```

---

## Component Lifecycle Hooks

### Lifecycle Order
1. `constructor()` — component instance created
2. `connectedCallback()` — component inserted into DOM
3. `renderedCallback()` — component render/re-render complete
4. `disconnectedCallback()` — component removed from DOM
5. `errorCallback(error, stack)` — child component throws an error

### Rules for Each Hook

**constructor()**
- Call `super()` first always
- Do NOT access `this.template` (DOM not yet available)
- Do NOT access `@api` properties (not set yet)
- Only initialize internal variables
```js
constructor() {
    super();
    this.isLoading = true; // OK
}
```

**connectedCallback()**
- `@api` properties are set by the time this runs
- Access `this.template` is available
- Good for: LMS subscriptions, initializing state from `@api`, imperative Apex if needed on load
```js
connectedCallback() {
    this.subscribeToLMS();
    if (this.recordId) {
        this.loadData();
    }
}
```

**renderedCallback()**
- Runs after every render — be careful with side effects
- Use to initialize 3rd-party JS libraries that need DOM access
- Add a guard to prevent re-initialization:
```js
isInitialized = false;

renderedCallback() {
    if (this.isInitialized) return;
    this.isInitialized = true;
    // one-time DOM initialization
}
```

**disconnectedCallback()**
- Clean up all subscriptions, event listeners, timers
```js
disconnectedCallback() {
    unsubscribe(this.subscription);
    this.subscription = null;
    clearInterval(this.pollingInterval);
}
```

**errorCallback(error, stack)**
- Catches errors from child components
- Use to display a fallback UI
```js
errorCallback(error, stack) {
    this.error = error.message;
    console.error('Child component error:', stack);
}
```

---

## Security

### The Core Rule
**UI security checks are UX, not security. Server-side enforcement in Apex is security.**

A button hidden behind `lwc:if={canEdit}` is a UX improvement, but if the Apex controller does not also check permissions, any user can call the Apex method directly via the API.

### UI Permission Checks (UX Only)
```js
import HAS_CASE_EDIT from '@salesforce/customPermission/Case_Edit_Permission';
import { LightningElement } from 'lwc';

export default class CaseActions extends LightningElement {
    get canEditCase() {
        return HAS_CASE_EDIT;
    }
}
```
```html
<template lwc:if={canEditCase}>
    <lightning-button label="Edit" onclick={handleEdit}></lightning-button>
</template>
```

### Apex MUST Enforce CRUD/FLS
```apex
// Every Apex method must independently verify access
if (!Schema.sObjectType.Case.isUpdateable()) {
    throw new AuraHandledException('Insufficient access to update Cases');
}
```

### Never Expose Sensitive Data
- Do not return fields containing sensitive data (SSN, credit card, credentials) via `@AuraEnabled` methods unless specifically required
- Use field-level security in SOQL: `WITH USER_MODE` enforces FLS at query time
- Do not pass sensitive data to child components via `@api` if the child does not need it

### @AuraEnabled Method Access
- All `@AuraEnabled` methods are callable by any authenticated user who has access to the Apex class
- Use Custom Permissions, Permission Sets, or explicit CRUD/FLS checks inside the method to restrict access
- Never rely on the component being hidden in the UI as the security boundary

### Lightning Locker / LWS
- LWC runs in Lightning Web Security (LWS) in modern orgs
- Cannot access DOM outside the component's shadow
- Cannot directly call `window.parent` or manipulate other components' DOM
- Third-party libraries must be compatible with LWS — verify before importing

---

## Performance

### @wire and Caching
- `@wire` with `cacheable=true` Apex methods caches responses in the client
- Cache is per user, per Apex method, per input parameters
- Cache improves performance for read-heavy pages
- Cache can cause stale data — use `refreshApex` after mutations

### Avoid Expensive Getters
Getters run on every render. Avoid heavy computation:
```js
// WRONG — runs on every render:
get filteredCases() {
    return this.cases.filter(c => /* complex logic */); // runs every render
}

// CORRECT — compute once when data changes:
@wire(getCases)
wiredCasesHandler({ data }) {
    if (data) {
        this.filteredCases = data.filter(c => /* complex logic */); // computed once
    }
}
```

### Conditional Rendering
- Use `lwc:if` to conditionally render — removes elements from DOM when false
- Only add `style="display:none"` when you intentionally want the element in DOM (e.g., for ARIA or JS targeting)

### Minimize Apex Calls
- Do not make multiple sequential Apex calls on load if they can be combined into one
- Use a wrapper object/class in Apex to return multiple datasets in one call
```apex
@AuraEnabled(cacheable=true)
public static CaseDashboardData getDashboardData(Id accountId) {
    CaseDashboardData result = new CaseDashboardData();
    result.cases = [SELECT ... FROM Case WHERE AccountId = :accountId WITH USER_MODE];
    result.account = [SELECT Name, Type FROM Account WHERE Id = :accountId WITH USER_MODE];
    return result;
}

public class CaseDashboardData {
    @AuraEnabled public List<Case> cases;
    @AuraEnabled public Account account;
}
```

### for:each vs iterator
- Use `for:each` for standard list rendering
- Use `iterator:it` when you need first/last item detection for styling
```html
<template iterator:it={cases}>
    <li key={it.value.Id}
        class={it.first ? 'first-item' : ''}>
        {it.value.Subject}
    </li>
</template>
```

### Track Component Re-renders
- Use browser DevTools > Performance tab to check render frequency
- If a component re-renders more than expected, check getter logic and `@track` usage

---

## Accessibility

### Mandatory Requirements
Every interactive element must be accessible:

1. **Icon-only buttons**: must have `aria-label`
   ```html
   <lightning-button-icon
       icon-name="utility:edit"
       aria-label="Edit Case"
       onclick={handleEdit}>
   </lightning-button-icon>
   ```

2. **Form inputs**: use `lightning-input` and `lightning-combobox` which have built-in label support
   ```html
   <lightning-input
       label="Case Subject"
       value={subject}
       onchange={handleSubjectChange}
       required>
   </lightning-input>
   ```

3. **Images and icons**: always set `alternative-text`
   ```html
   <lightning-icon
       icon-name="standard:case"
       alternative-text="Case icon"
       size="small">
   </lightning-icon>
   ```

4. **Keyboard navigation**: all interactive elements must be reachable by Tab and activatable by Enter/Space

5. **ARIA roles**: use semantic HTML and ARIA roles where appropriate
   ```html
   <div role="status" aria-live="polite">{statusMessage}</div>
   ```

6. **Color contrast**: do not rely solely on color to convey information; pair with icons or text

7. **Focus management**: when a modal opens, move focus to the modal; when it closes, return focus to the triggering element

### Screen Reader Testing
Test with:
- NVDA + Chrome (Windows)
- VoiceOver + Safari (macOS/iOS)
- Verify that all dynamic content changes are announced

---

## CSS and Styling

### SLDS First
- Use Salesforce Lightning Design System (SLDS) utility classes before writing custom CSS
- SLDS classes: `slds-var-p-around_medium`, `slds-text-heading_medium`, `slds-grid`, `slds-col`
- Only write custom CSS when SLDS classes are insufficient

### Scoped CSS
- CSS in an LWC component is automatically scoped to that component
- Cannot inadvertently style other components (Shadow DOM)
- Cannot style standard `lightning-*` component internals directly (use CSS custom properties/design tokens instead)

### CSS Custom Properties (Design Tokens)
```css
/* caseDashboardContainer.css */
.case-card-wrapper {
    background-color: var(--lwc-colorBackground, #f3f3f3);
    border-radius: var(--lwc-borderRadiusMedium, 4px);
    padding: var(--lwc-spacingSmall, 8px);
}
```

### Do Not Use IDs for Styling
- IDs are not stable in LWC (they get transformed)
- Use class selectors only

### No !important
- Avoid `!important` — it makes CSS unmaintainable
- If you need to override SLDS, use more specific selectors or CSS custom properties

---

## Jest Testing

### Required Test Coverage
Every container component must have Jest tests covering:
1. Loading state — spinner shown while data is fetching
2. Error state — error message shown when Apex returns error
3. Success/data state — data rendered correctly when Apex returns data
4. Empty state — empty message shown when Apex returns empty array
5. User interaction — buttons, events dispatched
6. Event handling — parent handles child events correctly

### Test File Structure
```
force-app/main/default/lwc/caseDashboardContainer/
  __tests__/
    caseDashboardContainer.test.js
```

### Jest Test Template
```js
import { createElement } from 'lwc';
import CaseDashboardContainer from 'c/caseDashboardContainer';
import getCases from '@salesforce/apex/CaseDashboardController.getCases';
import { registerApexTestWireAdapter } from '@salesforce/sfdx-lwc-jest';

// Mock wire adapter for getCases
const getCasesAdapter = registerApexTestWireAdapter(getCases);

// Mock data
const MOCK_CASES = [
    { Id: '5001000000AAAA1', Subject: 'Test Case 1', Status: 'New', Priority: 'High' },
    { Id: '5001000000AAAA2', Subject: 'Test Case 2', Status: 'Closed', Priority: 'Low' }
];

describe('c-case-dashboard-container', () => {
    afterEach(() => {
        // Clean up DOM after each test
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.clearAllMocks();
    });

    // --- Loading State ---
    it('shows loading spinner before wire data resolves', () => {
        const element = createElement('c-case-dashboard-container', {
            is: CaseDashboardContainer
        });
        document.body.appendChild(element);

        const spinner = element.shadowRoot.querySelector('lightning-spinner');
        expect(spinner).not.toBeNull();
    });

    // --- Success/Data State ---
    it('renders case cards when data is returned', async () => {
        const element = createElement('c-case-dashboard-container', {
            is: CaseDashboardContainer
        });
        document.body.appendChild(element);

        getCasesAdapter.emit({ data: MOCK_CASES, error: undefined });
        await Promise.resolve(); // wait for re-render

        const caseCards = element.shadowRoot.querySelectorAll('c-case-card');
        expect(caseCards.length).toBe(MOCK_CASES.length);
    });

    // --- Error State ---
    it('shows error message when wire returns error', async () => {
        const element = createElement('c-case-dashboard-container', {
            is: CaseDashboardContainer
        });
        document.body.appendChild(element);

        const mockError = { body: { message: 'Insufficient access to Cases' } };
        getCasesAdapter.emit({ data: undefined, error: mockError });
        await Promise.resolve();

        const errorDiv = element.shadowRoot.querySelector('[data-id="error-message"]');
        expect(errorDiv).not.toBeNull();
        expect(errorDiv.textContent).toContain('Insufficient access');
    });

    // --- Empty State ---
    it('shows empty state when wire returns empty array', async () => {
        const element = createElement('c-case-dashboard-container', {
            is: CaseDashboardContainer
        });
        document.body.appendChild(element);

        getCasesAdapter.emit({ data: [], error: undefined });
        await Promise.resolve();

        const emptyMessage = element.shadowRoot.querySelector('[data-id="empty-message"]');
        expect(emptyMessage).not.toBeNull();
    });

    // --- Spinner Removed After Load ---
    it('removes loading spinner after data resolves', async () => {
        const element = createElement('c-case-dashboard-container', {
            is: CaseDashboardContainer
        });
        document.body.appendChild(element);

        getCasesAdapter.emit({ data: MOCK_CASES, error: undefined });
        await Promise.resolve();

        const spinner = element.shadowRoot.querySelector('lightning-spinner');
        expect(spinner).toBeNull();
    });

    // --- Event Handling ---
    it('handles caseselected event from child caseCard', async () => {
        const element = createElement('c-case-dashboard-container', {
            is: CaseDashboardContainer
        });
        document.body.appendChild(element);

        getCasesAdapter.emit({ data: MOCK_CASES, error: undefined });
        await Promise.resolve();

        const mockHandler = jest.fn();
        element.addEventListener('caseselected', mockHandler);

        const caseCard = element.shadowRoot.querySelector('c-case-card');
        caseCard.dispatchEvent(new CustomEvent('caseselected', {
            detail: { caseId: MOCK_CASES[0].Id },
            bubbles: true
        }));

        await Promise.resolve();
        expect(mockHandler).toHaveBeenCalled();
    });
});
```

### Mocking Imperative Apex
```js
import closeCase from '@salesforce/apex/CaseDashboardController.closeCase';

jest.mock(
    '@salesforce/apex/CaseDashboardController.closeCase',
    () => ({ default: jest.fn() }),
    { virtual: true }
);

it('calls closeCase Apex on confirm', async () => {
    const { default: closeCaseMock } = require('@salesforce/apex/CaseDashboardController.closeCase');
    closeCaseMock.mockResolvedValue(undefined); // simulate success

    // ... create element, trigger handler, assert
    expect(closeCaseMock).toHaveBeenCalledWith({ caseId: 'SOME_ID' });
});
```

### Test Data Best Practices
- Keep mock data in a `__tests__/data/` folder as JSON files
- Use realistic Salesforce IDs (18 characters) in mock data
- Test both the happy path and edge cases (null, empty, partial data)

---

## Metadata XML Targets

Every LWC component must have a `.js-meta.xml` file that correctly declares which contexts the component can be used in.

### Common Targets Reference
| Target | Usage |
|---|---|
| `lightning__RecordPage` | Show on a standard or custom object record page |
| `lightning__AppPage` | Show on a Lightning App page |
| `lightning__HomePage` | Show on the Home page |
| `lightning__FlowScreen` | Use inside a Screen Flow |
| `lightning__UtilityBar` | Show in a utility bar |
| `lightning__Tab` | Show as a Lightning tab |

### .js-meta.xml Template (Record Page Component)
```xml
<?xml version="1.0" encoding="UTF-8"?>
<LightningComponentBundle xmlns="http://soap.sforce.com/2006/04/metadata">
    <apiVersion>59.0</apiVersion>
    <isExposed>true</isExposed>
    <targets>
        <target>lightning__RecordPage</target>
        <target>lightning__AppPage</target>
    </targets>
    <targetConfigs>
        <targetConfig targets="lightning__RecordPage">
            <property
                name="recordId"
                type="String"
                label="Record Id"
                description="The Salesforce record Id. Set automatically on record pages."/>
        </targetConfig>
    </targetConfigs>
</LightningComponentBundle>
```

### .js-meta.xml Template (Utility/Internal Component — not exposed to App Builder)
```xml
<?xml version="1.0" encoding="UTF-8"?>
<LightningComponentBundle xmlns="http://soap.sforce.com/2006/04/metadata">
    <apiVersion>59.0</apiVersion>
    <isExposed>false</isExposed>
</LightningComponentBundle>
```

### .js-meta.xml Template (Flow Screen Component)
```xml
<?xml version="1.0" encoding="UTF-8"?>
<LightningComponentBundle xmlns="http://soap.sforce.com/2006/04/metadata">
    <apiVersion>59.0</apiVersion>
    <isExposed>true</isExposed>
    <targets>
        <target>lightning__FlowScreen</target>
    </targets>
    <targetConfigs>
        <targetConfig targets="lightning__FlowScreen">
            <property name="caseId" type="String" role="inputOnly" label="Case Id"/>
            <property name="isSuccess" type="Boolean" role="outputOnly" label="Is Success"/>
        </targetConfig>
    </targetConfigs>
</LightningComponentBundle>
```

---

## File Structure and Naming

### LWC Component File Structure
```
force-app/main/default/lwc/
├── caseDashboardContainer/
│   ├── caseDashboardContainer.html
│   ├── caseDashboardContainer.js
│   ├── caseDashboardContainer.js-meta.xml
│   ├── caseDashboardContainer.css          (optional)
│   └── __tests__/
│       ├── caseDashboardContainer.test.js
│       └── data/
│           └── getCasesData.json
├── caseCard/
│   ├── caseCard.html
│   ├── caseCard.js
│   ├── caseCard.js-meta.xml
│   └── __tests__/
│       └── caseCard.test.js
└── errorUtils/
    ├── errorUtils.js
    └── errorUtils.js-meta.xml
```

### Naming Conventions
| Element | Convention | Example |
|---|---|---|
| Component folder | camelCase | `caseDashboardContainer` |
| Component files | same as folder name | `caseDashboardContainer.html` |
| Component in HTML | kebab-case with `c-` prefix | `<c-case-dashboard-container>` |
| Apex controller | PascalCase, matches component | `CaseDashboardController` |
| Custom event names | lowercase, hyphenated | `caseselected`, `form-submitted` |
| MessageChannel | PascalCase + `__c` suffix | `CaseSelected__c` |

### Component Folder Anti-Patterns
- Incorrect: `CaseDashboardContainer/` (uppercase first letter — not allowed)
- Incorrect: `case-dashboard-container/` (hyphens not allowed in folder name)
- Incorrect: `case_dashboard_container/` (underscores not allowed)
- Correct: `caseDashboardContainer/`

---

## Common AI Mistakes to Avoid

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
| 9 | Hardcoded record IDs or org-specific values | Breaks in different orgs/sandboxes | Use `@api recordId`, Custom Labels, or Custom Metadata |
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

## Definition of Done (LWC-specific)

Use this checklist for every LWC component before marking it complete.

### Architecture
- [ ] Smart/dumb (container/presentational) split documented and followed
- [ ] Data flow direction documented (which component owns which state)
- [ ] Component architecture diagram or description included in PR description

### Component Implementation
- [ ] All four states implemented: loading, error, data, empty
- [ ] `isLoading = true` set initially (before wire resolves)
- [ ] Wire result stored for `refreshApex` calls
- [ ] `refreshApex` called after all mutations
- [ ] No hardcoded record IDs or org-specific values in JS
- [ ] All `@api` properties validated before use
- [ ] No `@api` property mutations inside the component
- [ ] Event names are lowercase and descriptive
- [ ] `lwc:if` used for conditional rendering (not `display:none`)
- [ ] `key` attribute set on all `for:each` root elements

### Apex Controller
- [ ] `with sharing` on Apex class
- [ ] `@AuraEnabled(cacheable=true)` ONLY on read-only methods
- [ ] `@AuraEnabled` (no cacheable) on all mutation methods
- [ ] CRUD/FLS enforced (Schema checks or `WITH USER_MODE`)
- [ ] `AuraHandledException` thrown with user-safe message for all errors
- [ ] Raw exception messages NOT exposed to client

### Security
- [ ] Server-side CRUD/FLS enforcement independent of UI guards
- [ ] No sensitive data fields unnecessarily exposed via `@AuraEnabled` methods
- [ ] Custom Permissions used if method access needs to be restricted by profile/permission set

### Accessibility
- [ ] All interactive elements have visible labels or `aria-label`
- [ ] `lightning-icon` elements have `alternative-text`
- [ ] Form inputs use `lightning-input` or `lightning-combobox` (built-in accessibility)
- [ ] Keyboard navigation tested (Tab, Enter, Space)

### Testing
- [ ] Jest test file exists in `__tests__/` folder
- [ ] Test covers: loading state, error state, success/data state, empty state
- [ ] Test covers: all user interactions (clicks, form changes)
- [ ] Test covers: custom events dispatched correctly
- [ ] All tests pass: `npm run test:unit`
- [ ] Code coverage acceptable (aim for 85%+)

### Metadata
- [ ] `.js-meta.xml` file present with correct `apiVersion`
- [ ] `isExposed` set correctly (false for utility components)
- [ ] `targets` declared for all intended deployment contexts
- [ ] `targetConfigs` added if component has configurable App Builder properties

### Deployment
- [ ] Deployed to sandbox successfully
- [ ] Rendered correctly in target context (Record Page, App Page, etc.)
- [ ] No console errors in browser
- [ ] Checked in multiple browsers (Chrome, Firefox, Safari)
- [ ] Check-only deployment to production passes validation

---

## Validation Commands

```bash
# Run all Jest unit tests
npm run test:unit

# Run with coverage report
npm run test:unit -- --coverage

# Run a single test file
npm run test:unit -- --testPathPattern caseDashboardContainer

# Watch mode (re-runs on file change during development)
npm run test:unit -- --watch

# Deploy a single LWC component (check-only)
sf project deploy start \
  --metadata "LightningComponentBundle:caseDashboardContainer" \
  --target-org <sandbox-alias> \
  --check-only \
  --wait 60

# Deploy LWC + Apex controller together (check-only)
sf project deploy start \
  --metadata "LightningComponentBundle:caseDashboardContainer,ApexClass:CaseDashboardController" \
  --target-org <sandbox-alias> \
  --check-only \
  --wait 60

# Deploy (actual)
sf project deploy start \
  --metadata "LightningComponentBundle:caseDashboardContainer,ApexClass:CaseDashboardController" \
  --target-org <production-alias> \
  --wait 60

# Retrieve component from org
sf project retrieve start \
  --metadata "LightningComponentBundle:caseDashboardContainer" \
  --target-org <alias>

# Run Apex tests for the controller
sf apex run test \
  --class-names CaseDashboardControllerTest \
  --target-org <sandbox-alias> \
  --wait 10 \
  --result-format human

# Lint check (if ESLint is configured)
npm run lint
```

---

## Official References

- **LWC Developer Guide**: https://developer.salesforce.com/docs/component-library/documentation/en/lwc
- **Lightning Web Security**: https://developer.salesforce.com/docs/component-library/documentation/en/lwc/lwc.security_locker_service_intro
- **@api Properties**: https://developer.salesforce.com/docs/component-library/documentation/en/lwc/lwc.js_props_public
- **Wire Service**: https://developer.salesforce.com/docs/component-library/documentation/en/lwc/lwc.use_wire_service
- **LWC Quick Start Trailhead**: https://trailhead.salesforce.com/content/learn/projects/quick-start-lightning-web-components
- **Lightning Navigation**: https://developer.salesforce.com/docs/component-library/documentation/en/lwc/lwc.use_navigate
- **Lightning Message Service**: https://developer.salesforce.com/docs/component-library/documentation/en/lwc/lwc.use_message_channel
- **LDS (createRecord, updateRecord)**: https://developer.salesforce.com/docs/component-library/documentation/en/lwc/lwc.reference_lightning_ui_api_record
- **SLDS Utilities**: https://www.lightningdesignsystem.com/utilities/
- **Jest Testing for LWC**: https://developer.salesforce.com/docs/component-library/documentation/en/lwc/lwc.unit_testing_using_jest_introduction
- **@AuraEnabled Annotation**: https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_classes_annotation_AuraEnabled.htm
- **WITH USER_MODE**: https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_classes_with_security_enforced.htm
