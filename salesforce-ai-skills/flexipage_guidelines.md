# FlexiPage (Lightning Page) Guidelines

**Version**: 2.0 (April 2026)
**Developer**: Naresh | Senior Salesforce Developer
**Purpose**: Guidelines for Lightning Record Pages, App Pages, and Home Pages. Attach when designing, building, or deploying FlexiPages.

---

## Table of Contents

1. [Required Agent Output Contract](#1-required-agent-output-contract)
2. [Page Types](#2-page-types)
3. [Dynamic Forms](#3-dynamic-forms)
4. [Dynamic Actions](#4-dynamic-actions)
5. [Component Visibility Rules](#5-component-visibility-rules)
6. [Activation Rules](#6-activation-rules)
7. [Form Factor Considerations](#7-form-factor-considerations)
8. [Performance](#8-performance)
9. [Metadata Deployment](#9-metadata-deployment)
10. [LWC Placement](#10-lwc-placement)
11. [Flow Placement](#11-flow-placement)
12. [Example](#12-example)
13. [Common AI Mistakes to Avoid](#13-common-ai-mistakes-to-avoid)
14. [Definition of Done](#14-definition-of-done)
15. [Validation Commands](#15-validation-commands)
16. [Official References](#16-official-references)

---

## 1. Required Agent Output Contract

When generating or modifying a FlexiPage, the AI agent MUST produce the following as part of its output:

### 1.1 Page Type and Context

```
Page Type: Record Page / App Page / Home Page
Object: Case (for Record Pages)
Page Name (API): Case_Record_Page_Support
Label: Case Record Page - Support View
```

### 1.2 Components Placed

List every component on the page with its region/column and any configuration properties:

```
Region: Header
  - Component: flexipage:recordHeader (standard)

Region: Main Column (left, 2/3 width)
  - Component: flexipage:dynamicForm (Dynamic Form - all case fields)
  - Component: c:caseTimelineComponent (LWC custom)
    - Property: recordId = {!recordId}

Region: Sidebar Column (right, 1/3 width)
  - Component: flexipage:relatedListSingle (Related List - Case Comments)
  - Component: flexipage:relatedListSingle (Related List - Attachments)
```

### 1.3 Activation Rules

Describe the activation context:
```
Activated For: App = Service Console, Record Type = Support_Case, Profile = Support_Agent
Form Factor: Desktop
Priority: Overrides default page for specified app/record type combination
```

### 1.4 Form Factor

- [ ] Desktop layout designed and documented
- [ ] Mobile layout reviewed — separate FlexiPage or responsive component confirmed

### 1.5 Deployment Plan

```
1. Deploy LWC components (c:caseTimelineComponent)
2. Deploy FlexiPage metadata (Case_Record_Page_Support)
3. Activate page in target org via SFDX or manually via App Builder
4. Verify activation for correct App/RecordType/Profile combination
```

---

## 2. Page Types

### 2.1 Record Page

- **Purpose**: Custom layout for a specific sObject record (Case, Account, Opportunity, etc.)
- **URL Pattern**: `/lightning/r/{ObjectName}/{recordId}/view`
- **Available Components**: Standard record header, Dynamic Forms, Dynamic Actions, Related Lists, LWC, Flow runtime, Highlights Panel, Activity Timeline, etc.
- **When to Use**: Replacing the standard page layout with a tailored experience per record type, app, or profile.
- **Key Features**: Supports Dynamic Forms, Dynamic Actions, component visibility filters.

### 2.2 App Page

- **Purpose**: A custom homepage-style page for a Lightning App, not tied to a specific record.
- **URL Pattern**: Accessed via Lightning App navigation tab.
- **Available Components**: Dashboards, Report Charts, LWC, List Views, Rich Text, HTML, etc.
- **When to Use**: Custom landing pages for apps, management dashboards, operational views.
- **Limitation**: Does NOT support Dynamic Forms (no record context).

### 2.3 Home Page

- **Purpose**: The default home tab experience.
- **URL Pattern**: `/lightning/page/home`
- **Available Components**: Recent Items, News, Assistant, LWC, Dashboards.
- **When to Use**: Personalizing the home tab experience per profile/app.
- **Limitation**: No record context; no Dynamic Forms.

### Page Type Summary Table

| Feature | Record Page | App Page | Home Page |
|---|---|---|---|
| Dynamic Forms | Yes | No | No |
| Dynamic Actions | Yes | No | No |
| Component Visibility | Yes | Yes (limited) | Yes (limited) |
| Record context (recordId) | Yes | No | No |
| LWC support | Yes | Yes | Yes |
| Flow support | Yes | Yes | No |
| Activation by Record Type | Yes | No | No |

---

## 3. Dynamic Forms

### What Are Dynamic Forms

Dynamic Forms replace the standard `flexipage:recordForm` / page layout field sections with individually-placed fields and field sections that can be configured with visibility conditions. Each field or section is placed independently in the page builder.

### When to Use Dynamic Forms

- When different user roles need to see different subsets of fields on the same object.
- When field visibility should depend on field values (e.g., show "Escalation Reason" only when Status = Escalated).
- When fields need to be conditionally required in the layout.
- When replacing legacy page layout sections with a more granular layout.

### When NOT to Use Dynamic Forms

- For simple pages with no conditional logic — standard page layout may suffice.
- When the object does not support Dynamic Forms (verify in target org — not all objects support it).

### Conditions Available for Dynamic Forms

| Condition Type | Example |
|---|---|
| Field Value | Show "Escalation Reason" when `Status` equals `Escalated` |
| Custom Permission | Show "Internal Notes" field when user has `ViewInternalNotes` custom permission |
| User Profile | Show "Cost" field only for Profile = Sales Manager |
| Record Type | Show section only for Record Type = Partner_Case |

### Benefits Over Standard Page Layouts

- No need for multiple page layouts per record type if the difference is field visibility.
- Field changes are declarative — no Apex or LWC code needed.
- Reducing the number of page layouts simplifies ongoing maintenance.
- Works with the Lightning App Builder drag-and-drop interface.

### Dynamic Forms XML Structure (simplified)

```xml
<fieldInstance>
    <componentName>force:outputField</componentName>
    <fieldName>Status</fieldName>
    <fieldSection>CaseDetails</fieldSection>
    <visibilityRule>
        <booleanFilter>1</booleanFilter>
        <criteria>
            <fieldName>RecordType.DeveloperName</fieldName>
            <operator>EqualTo</operator>
            <value><stringValue>Support_Case</stringValue></value>
        </criteria>
    </visibilityRule>
</fieldInstance>
```

---

## 4. Dynamic Actions

### What Are Dynamic Actions

Dynamic Actions replace the static button bar from page layouts with an action bar that can show or hide individual actions based on configurable conditions. Configured in the Lightning App Builder.

### Benefits

- Show/hide actions based on record field values (e.g., only show "Escalate" button when Status = Open).
- Show/hide based on user's custom permission (e.g., only show "Delete" for users with `DeleteCasePermission`).
- Eliminate clutter from irrelevant buttons on the page.
- No code changes needed for button visibility logic.

### Conditions Available

| Condition Type | Example |
|---|---|
| Record Field Value | Show "Close Case" when `Status` != `Closed` |
| Custom Permission | Show "Override SLA" when user has `OverrideSLA` custom permission |
| User Profile | Show "Reassign" only for Profile = Support Manager (use sparingly — prefer Custom Permission) |
| Device Form Factor | Hide certain actions on mobile |

### Example Dynamic Action Configuration

Action: "Escalate to Tier 2"
- Visibility Condition: `Status` equals `Open` AND user has Custom Permission `EscalateCase`
- Result: Button only appears for open cases, only for users with the escalation permission.

### XML Structure (simplified)

```xml
<actionInstance>
    <actionName>Case.Escalate_To_Tier2</actionName>
    <actionType>QuickAction</actionType>
    <visibilityRule>
        <booleanFilter>1 AND 2</booleanFilter>
        <criteria>
            <fieldName>Status</fieldName>
            <operator>EqualTo</operator>
            <value><stringValue>Open</stringValue></value>
        </criteria>
        <criteria>
            <fieldName>$Permission.EscalateCase</fieldName>
            <operator>EqualTo</operator>
            <value><booleanValue>true</booleanValue></value>
        </criteria>
    </visibilityRule>
</actionInstance>
```

---

## 5. Component Visibility Rules

### Overview

Every component placed on a FlexiPage can be configured with visibility rules that control whether it renders for a given user/record context. Visibility is evaluated at runtime.

### Filter Options Table

| Filter Type | Filter Options | Example Use Case |
|---|---|---|
| **Record Field Value** | Equals, Not Equals, Contains, Greater Than, etc. | Show a component only when `Priority` equals `High` |
| **User Permission** | Custom Permission enabled/disabled | Show audit log component only for users with `ViewAuditLog` permission |
| **Device Form Factor** | Desktop, Phone, Tablet | Hide a complex chart component on mobile |
| **Custom Permission** | Is enabled / Is not enabled | Show advanced configuration panel for power users |
| **User Profile** | Equals a specific profile | Restrict a component to specific profiles (use Custom Permission instead where possible) |
| **Record Type** | Equals a record type | Show a different component layout for Partner vs Customer cases |

### Rules

- Prefer Custom Permission over Profile-based visibility — profiles change; custom permissions are explicit.
- Combine multiple conditions with AND/OR logic.
- Test visibility rules with multiple user types in sandbox before production deployment.
- Document all visibility rules in the page design document.

---

## 6. Activation Rules

### What Is Activation

Activation controls which version of a FlexiPage is shown to a user. Multiple versions of a Record Page can exist; Salesforce picks the most specific active version based on:

1. App + Profile + Record Type (most specific — highest priority)
2. App + Profile
3. App + Record Type
4. App only
5. Profile + Record Type
6. Profile only
7. Record Type only
8. Org default (least specific — lowest priority)

### Rules

- Always activate pages at the most specific level needed — avoid activating at "Org Default" if the page is only relevant for a subset of users.
- Test activation in sandbox before activating in production.
- Document the activation context in the FlexiPage file header comment.
- When two pages are activated at the same specificity level, the most recently activated takes precedence — avoid conflicts.
- Always review the "Activation" tab in App Builder before deploying to understand what is currently active.

### Activation via Metadata

Activation state is captured in the FlexiPage metadata XML:

```xml
<flexipageRegions>
    <!-- component definitions -->
</flexipageRegions>
<sobjectType>Case</sobjectType>
<type>RecordPage</type>
<template>
    <name>AppPage2Column7030</name>
</template>
```

Note: Full activation assignments (which app, profile, record type) may need to be set via the UI in App Builder or via additional metadata depending on the Salesforce release. Verify behavior in your target org.

---

## 7. Form Factor Considerations

### Desktop vs Mobile

Lightning Pages render on Desktop (browser) and Phone (Salesforce mobile app). The layout experience differs significantly:
- Desktop: side-by-side columns, full component width.
- Phone: single column, stacked layout; some components may not render.

### Options

| Approach | When to Use |
|---|---|
| Single FlexiPage with responsive components | When components behave well in both form factors |
| Separate FlexiPage for Mobile | When mobile experience needs significant structural difference |
| Component Visibility: form factor filter | When some components should be hidden on mobile |

### Rules

- Always review the mobile rendering of a new FlexiPage in App Builder before deployment.
- Use the form factor filter on heavy components (e.g., complex charts, data-intensive LWC) to hide them on mobile.
- If the mobile experience is materially different, create a separate FlexiPage and activate for Phone form factor.
- LWC components must declare `phone` in their targets to appear on mobile pages.

### LWC Target Declaration for Mobile

```javascript
// In the component's JS-meta.xml
<targets>
    <target>lightning__RecordPage</target>
    <target>lightning__AppPage</target>
    <target>lightning__HomePage</target>
</targets>
<targetConfigs>
    <targetConfig targets="lightning__RecordPage">
        <property name="recordId" type="String" />
    </targetConfig>
</targetConfigs>
```

---

## 8. Performance

### Guidelines

- **Limit components per page**: Each component adds rendering and wire call overhead. Consult Salesforce performance documentation for current limits and recommendations — these may change by release.
- **Avoid multiple @wire calls fetching the same data**: If two LWC components on the same page independently wire the same record fields, consider extracting shared data to a parent component or a custom data service.
- **LWC components should be lightweight on the FlexiPage**: Heavy data processing should happen server-side in Apex, not in client-side JavaScript running on page load.
- **Lazy-load off-screen sections**: Use tab containers in App Builder to defer component rendering until the user clicks the tab.
- **Avoid nested Related Lists**: Multiple related lists each make server calls. Combine into a single Related List (all) component where possible.
- **Avoid platform events or streaming on a record page** unless required — these keep persistent connections open.

### Performance Checklist

- [ ] Component count is reasonable for the page purpose
- [ ] No duplicate @wire calls across components for the same data
- [ ] Heavy LWC components are behind a tab (lazy rendered)
- [ ] Mobile form factor reviewed — no high-overhead components on phone layout
- [ ] Page tested with realistic data volume in sandbox

---

## 9. Metadata Deployment

### FlexiPage Metadata Type

- Metadata type: `FlexiPage`
- File extension: `.flexipage-meta.xml`
- Location: `force-app/main/default/flexipages/`

### Deployment Rules

1. All LWC components referenced on the page must be deployed FIRST.
2. All Flow components referenced must be deployed and active FIRST.
3. Deploy the FlexiPage after all dependency components.
4. Activation state in metadata: verify if the page is activated as part of the deployment or requires manual activation in App Builder.

### package.xml Example

```xml
<!-- LWC components first -->
<types>
    <members>caseTimelineComponent</members>
    <name>LightningComponentBundle</name>
</types>

<!-- Then FlexiPage -->
<types>
    <members>Case_Record_Page_Support</members>
    <name>FlexiPage</name>
</types>
```

### Retrieve Existing FlexiPage

```bash
sf project retrieve start \
  --metadata "FlexiPage:Case_Record_Page_Support" \
  --target-org <alias>
```

---

## 10. LWC Placement on FlexiPages

### Rules

- The LWC component must declare `lightning__RecordPage` (for record pages) in its `targets` in the `.js-meta.xml` file.
- When placed on a Record Page, `@api recordId` is automatically populated with the current record's Id.
- `@api objectApiName` is automatically populated with the API name of the current object.
- Component properties exposed via `@api` can be configured in App Builder by the admin.

### LWC Meta XML for Record Page Target

```xml
<?xml version="1.0" encoding="UTF-8"?>
<LightningComponentBundle xmlns="http://soap.sforce.com/2006/04/metadata">
    <apiVersion>62.0</apiVersion>
    <isExposed>true</isExposed>
    <targets>
        <target>lightning__RecordPage</target>
    </targets>
    <targetConfigs>
        <targetConfig targets="lightning__RecordPage">
            <property
                name="recordId"
                type="String"
                label="Record ID"
                description="Auto-populated by the platform with the current record ID." />
            <property
                name="cardTitle"
                type="String"
                label="Card Title"
                default="Case Timeline"
                description="Title shown in the component header." />
            <supportedFormFactors>
                <supportedFormFactor type="Large" />
                <supportedFormFactor type="Small" />
            </supportedFormFactors>
        </targetConfig>
    </targetConfigs>
</LightningComponentBundle>
```

### Receiving recordId in LWC JavaScript

```javascript
import { LightningElement, api, wire } from 'lwc';
import { getRecord } from 'lightning/uiRecordApi';

export default class CaseTimelineComponent extends LightningElement {
    @api recordId;
    @api objectApiName;
    @api cardTitle;

    @wire(getRecord, { recordId: '$recordId', fields: ['Case.Subject', 'Case.Status'] })
    caseRecord;
}
```

---

## 11. Flow Placement on FlexiPages

### Component Name

Use the standard Salesforce Flow runtime component for embedding flows in FlexiPages. The exact component name to use in your FlexiPage metadata is `flowRuntime:flowRuntimeForFlexipage` — **verify this component name is available in your target org and release**, as component names can change between releases.

### Rules

- Always set the `flowApiName` property to the API name of the flow to embed.
- Always pass input variables to the flow where the flow requires record context.
- For record pages, pass `recordId` as an input variable to the flow.
- The flow must be active before the FlexiPage is deployed.
- Only Screen Flows should be embedded in FlexiPages — Autolaunched Flows are not appropriate for direct user-facing embedding.

### Flow Placement in FlexiPage XML

```xml
<componentInstance>
    <componentName>flowRuntime:flowRuntimeForFlexipage</componentName>
    <componentInstanceProperty>
        <name>flowApiName</name>
        <value>Case_Escalation_Screen_Flow</value>
    </componentInstanceProperty>
    <componentInstanceProperty>
        <name>inputVariables</name>
        <value>[{"name": "recordId", "type": "String", "value": "{!recordId}"}]</value>
    </componentInstanceProperty>
    <componentInstanceProperty>
        <name>flowLabel</name>
        <value>Escalate Case</value>
    </componentInstanceProperty>
</componentInstance>
```

---

## 12. Example: Case Record Page FlexiPage

### package.xml Entry

```xml
<types>
    <members>caseTimelineComponent</members>
    <members>caseSummaryPanel</members>
    <name>LightningComponentBundle</name>
</types>
<types>
    <members>Case_Record_Page_Support</members>
    <name>FlexiPage</name>
</types>
```

### FlexiPage Metadata Structure (Abbreviated)

```xml
<?xml version="1.0" encoding="UTF-8"?>
<FlexiPage xmlns="http://soap.sforce.com/2006/04/metadata">
    <description>
        Case Record Page for Support Agents.
        Includes Dynamic Form, Case Timeline LWC, Related Lists.
        Activated for: App=ServiceConsole, RecordType=Support_Case.
        Owner: Support Team. Deployed: April 2026.
    </description>
    <flexipageRegions>
        <!-- Header Region -->
        <name>header</name>
        <componentInstances>
            <componentInstance>
                <componentName>flexipage:header</componentName>
            </componentInstance>
        </componentInstances>
        <mode>append</mode>
        <type>Region</type>
    </flexipageRegions>

    <!-- Main Content Region (left 70%) -->
    <flexipageRegions>
        <name>main</name>
        <componentInstances>
            <!-- Dynamic Form for Case fields -->
            <componentInstance>
                <componentName>flexipage:dynamicForm</componentName>
                <!-- field sections defined within Dynamic Form config -->
            </componentInstance>
            <!-- Custom LWC Timeline -->
            <componentInstance>
                <componentName>c:caseTimelineComponent</componentName>
                <componentInstanceProperties>
                    <componentInstanceProperty>
                        <name>recordId</name>
                        <value>{!recordId}</value>
                    </componentInstanceProperty>
                    <componentInstanceProperty>
                        <name>cardTitle</name>
                        <value>Case Timeline</value>
                    </componentInstanceProperty>
                </componentInstanceProperties>
            </componentInstance>
        </componentInstances>
        <mode>append</mode>
        <type>Region</type>
    </flexipageRegions>

    <!-- Sidebar Region (right 30%) -->
    <flexipageRegions>
        <name>sidebar</name>
        <componentInstances>
            <!-- Related List: Case Comments -->
            <componentInstance>
                <componentName>flexipage:relatedListSingle</componentName>
                <componentInstanceProperties>
                    <componentInstanceProperty>
                        <name>relatedList</name>
                        <value>CaseComments</value>
                    </componentInstanceProperty>
                </componentInstanceProperties>
            </componentInstance>
            <!-- Related List: Attachments -->
            <componentInstance>
                <componentName>flexipage:relatedListSingle</componentName>
                <componentInstanceProperties>
                    <componentInstanceProperty>
                        <name>relatedList</name>
                        <value>CombinedAttachments</value>
                    </componentInstanceProperty>
                </componentInstanceProperties>
            </componentInstance>
        </componentInstances>
        <mode>append</mode>
        <type>Region</type>
    </flexipageRegions>

    <masterLabel>Case Record Page - Support</masterLabel>
    <sobjectType>Case</sobjectType>
    <template>
        <name>AppPage2Column7030</name>
    </template>
    <type>RecordPage</type>
</FlexiPage>
```

File: `force-app/main/default/flexipages/Case_Record_Page_Support.flexipage-meta.xml`

---

## 13. Common AI Mistakes to Avoid

| Mistake | Why It's Wrong | Correct Approach |
|---|---|---|
| Deploying FlexiPage before LWC components | Deployment fails — referenced components don't exist | Deploy all dependency components first |
| No activation rules configured | Wrong page shown to wrong users; or page is never activated | Define activation by App/RecordType/Profile combination; test before production |
| No mobile layout review | Mobile users see broken or unusable layout | Always check Phone form factor in App Builder |
| Placing @wire-heavy LWC directly without checking | Performance degradation on page load | Profile LWC performance; use lazy loading via tabs |
| Using Profile-based visibility instead of Custom Permission | Brittle; breaks when profiles are renamed or users change profiles | Use Custom Permission-based visibility |
| Referencing inactive or non-existent Flows | Runtime error when user encounters the embedded flow | Verify flow is active before deploying FlexiPage |
| Activating a page at Org Default unnecessarily | Overrides pages for all users, not just the intended audience | Activate at the most specific level needed |
| Missing component descriptions | Hard to maintain — no context for future developers | Add description to every FlexiPage metadata file |

---

## 14. Definition of Done

A FlexiPage is considered complete and ready for production when ALL of the following are true:

- [ ] All referenced LWC components are deployed to the target org
- [ ] All referenced Flows are active in the target org
- [ ] Page metadata has a description with owner, purpose, activation context, and deployment date
- [ ] Activation rules are defined for the correct App / RecordType / Profile combination
- [ ] Activation tested in sandbox with a test user in the target profile
- [ ] Desktop layout reviewed and validated
- [ ] Mobile (Phone) layout reviewed — either confirmed responsive or a separate phone layout is created
- [ ] Component visibility rules tested with multiple user types
- [ ] No duplicate @wire calls identified across page components
- [ ] Page is not activated at Org Default unless it is intended for all users
- [ ] Dynamic Forms visibility conditions tested for all applicable record types

---

## 15. Validation Commands

```bash
# Deploy FlexiPage (check-only first)
sf project deploy start \
  --metadata "FlexiPage:Case_Record_Page_Support" \
  --dry-run \
  --target-org <alias>

# Deploy for real
sf project deploy start \
  --metadata "FlexiPage:Case_Record_Page_Support" \
  --target-org <alias>

# Retrieve existing FlexiPage from org
sf project retrieve start \
  --metadata "FlexiPage:Case_Record_Page_Support" \
  --target-org <alias>

# Retrieve all FlexiPages
sf project retrieve start \
  --metadata "FlexiPage" \
  --target-org <alias>

# List FlexiPages via SOQL
sf data query \
  --query "SELECT Id, MasterLabel, Type, SobjectType FROM FlexiPage ORDER BY MasterLabel" \
  --target-org <alias>
```

---

## 16. Official References

- Salesforce Help: [Lightning App Builder](https://help.salesforce.com/s/articleView?id=sf.lightning_app_builder_overview.htm)
- Salesforce Help: [Dynamic Forms](https://help.salesforce.com/s/articleView?id=sf.dynamic_forms_overview.htm)
- Salesforce Help: [Dynamic Actions](https://help.salesforce.com/s/articleView?id=sf.dynamic_actions_overview.htm)
- Salesforce Metadata API: [FlexiPage](https://developer.salesforce.com/docs/atlas.en-us.api_meta.meta/api_meta/meta_flexipage.htm)
- Salesforce LWC Dev Guide: [Add Components to Lightning Pages](https://developer.salesforce.com/docs/component-library/documentation/en/lwc/lwc.use_config_for_app_builder)
- Trailhead: [Lightning App Builder](https://trailhead.salesforce.com/content/learn/modules/lightning_app_builder)
- Salesforce Well-Architected: [User Experience](https://architect.salesforce.com/well-architected/adaptable/user-experience)
