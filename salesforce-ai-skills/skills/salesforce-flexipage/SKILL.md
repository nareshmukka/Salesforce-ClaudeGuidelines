---
name: salesforce-flexipage
description: Production Salesforce AI skill for Lightning Record/App/Home page composition and activation.
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
- The task involves Lightning Record/App/Home page composition and activation.
- The user asks for implementation, refactor, troubleshooting, review, or best-practice validation in this area.
- The assistant must produce Salesforce-safe code/metadata with explicit security/testing notes.

## DO NOT TRIGGER when
- The task is unrelated to this component.
- Another specialized skill is the primary owner and this area is only incidental.
- The user asks for operational execution (deploy/publish/activate/destructive change) without explicit approval.

## Cross-skill routing
- Always read `../salesforce-global-development/SKILL.md`.
- Also read: Global Development + LWC + Permissions + Metadata.
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
Design page regions for performance and role-based utility. Use Dynamic Forms/Actions intentionally; keep visibility rules simple and testable. Plan activation per app/record type/profile with rollback path.

## Examples
### Good example patterns
1. Record page uses Dynamic Forms sections per persona.
2. Visibility filter checks explicit field states instead of complex formulas.

### Bad examples / avoid
1. Single overloaded page for all personas with heavy components.
2. Activating page globally without sandbox UX validation.

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

# FlexiPage (Lightning Page) -- Canonical Reference

Authoritative guide for FlexiPage metadata in this project. Covers Record Pages, App Pages, Home Pages, and the Email Application Pane; region/facet structure; Dynamic Forms; component visibility; LWC and Flow placement; record-page assignment; deployment ordering.

**Verified against:** [FlexiPage Metadata API](https://developer.salesforce.com/docs/atlas.en-us.api_meta.meta/api_meta/meta_flexipage.htm) - [LWC Configuration Tags Reference](https://developer.salesforce.com/docs/platform/lwc/guide/reference-configuration-tags.html) - [Lightning App Builder Help](https://help.salesforce.com/s/articleView?id=sf.lightning_app_builder_overview.htm) - [Dynamic Forms Help](https://help.salesforce.com/s/articleView?id=sf.dynamic_forms_overview.htm) - [forcedotcom/sf-skills `generating-flexipage`](https://github.com/forcedotcom/sf-skills/tree/main/skills/generating-flexipage). Last verified 2026-05-16.

---

## 1. File Layout

```
force-app/main/default/flexipages/<PageName>.flexipage-meta.xml
```

The directory `flexipages/` is fixed by the Salesforce DX source format. The file's `<masterLabel>` is the display name; the filename (minus `.flexipage-meta.xml`) is the API name.

**Critical:** Never put a `__c` suffix in the page name. `Volunteer_Record_Page`, not `Volunteer__c_Record_Page`. The platform rejects namespace-style suffixes in FlexiPage API names.

---

## 2. Top-Level Element Order

The FlexiPage root element accepts these children. Order is enforced by the schema.

```xml
<?xml version="1.0" encoding="UTF-8"?>
<FlexiPage xmlns="http://soap.sforce.com/2006/04/metadata">
   <description>...</description>             <!-- optional but always include -->
   <events>...</events>                       <!-- optional, advanced -->
   <flexiPageRegions>...</flexiPageRegions>   <!-- one per region/facet -->
   <masterLabel>...</masterLabel>             <!-- REQUIRED -->
   <parentFlexiPage>...</parentFlexiPage>     <!-- optional, page-override chains -->
   <platformActionList>...</platformActionList> <!-- optional, Dynamic Actions list -->
   <quickActionList>...</quickActionList>     <!-- optional -->
   <sobjectType>Case</sobjectType>            <!-- REQUIRED for RecordPage -->
   <template>...</template>                   <!-- REQUIRED -->
   <type>RecordPage</type>                    <!-- REQUIRED -->
</FlexiPage>
```

---

## 3. `type` Enum -- Supported Page Types

| Type value | Purpose | Requires `sobjectType` |
|---|---|:-:|
| `RecordPage` | Custom layout for a specific sObject record | Yes |
| `AppPage` | Homepage-style page for a Lightning App | No |
| `HomePage` | Default home tab experience | No |
| `EmailChrome` | Email Application Pane (Outlook / Gmail integration) | No |
| `CommAppPage` | Experience Cloud App Page | No |
| `CommHomePage` | Experience Cloud Home Page | No |
| `CommObjectPage` | Experience Cloud Record Page | Yes |
| `CommLoginPage` | Experience Cloud Login Page | No |
| `ServiceCommunityForumLayout` | Service Cloud community forum | No |
| `EmbeddedServiceMinimizedPage` | Embedded service chat minimized state | No |
| `UtilityBar` | App utility bar | No |

### Type-feature matrix

| Feature | RecordPage | AppPage | HomePage | EmailChrome |
|---|:-:|:-:|:-:|:-:|
| Dynamic Forms (FieldInstance / FieldSection) | Yes | No | No | No |
| Dynamic Actions | Yes | No | No | No |
| Component visibility rules | Yes | Yes (limited) | Yes (limited) | Yes |
| `@api recordId` auto-injected to LWCs | Yes | No | No | No (limited) |
| Activation by Record Type | Yes | No | No | No |
| Form-factor activation | Desktop + Phone | Desktop + Phone | Desktop + Phone | Desktop |
| LWC target tag | `lightning__RecordPage` | `lightning__AppPage` | `lightning__HomePage` | `lightning__Inbox` |
| Flow runtime component supported | Yes | Yes | No | No |

---

## 4. `template:` -- Region Layouts

The template defines the geometry. Components are placed inside the named regions the template exposes.

```xml
<template>
   <name>flexipage:recordHomeTemplateDesktop</name>
</template>
```

| Template name | Regions exposed | Typical use |
|---|---|---|
| `flexipage:recordHomeTemplateDesktop` | `header`, `main`, `sidebar` | Record Page, desktop |
| `flexipage:recordHomePhoneTemplate` | `header`, `main` | Record Page, phone |
| `flexipage:appHomeTemplateDesktop` | header, columns | App Page |
| `flexipage:homePageTemplateDesktop` | header, columns | Home Page |
| `flexipage:oneRegion` | single `Region` | Simple single-column |
| `flexipage:twoColumnLayout` | left, right | 50/50 split |
| `flexipage:twoColumn7030` | main (70%), sidebar (30%) | Common record page |
| `flexipage:threeColumnLayout` | left, center, right | Dashboard style |
| `runtime_service_fieldservice:...` | `header`, `main`, `footer` | Field service consoles |

**Region names are template-dependent -- never hardcode.** Parse the template's named regions from the existing file before adding components.

---

## 5. `flexiPageRegions` -- Regions vs Facets

Every placed component lives inside a `<flexiPageRegions>` block. The `<type>` distinguishes two roles:

| `<type>` | Meaning | Where the name comes from |
|---|---|---|
| `Region` | A named slot exposed by the page template (e.g. `header`, `main`, `sidebar`) | The template definition |
| `Facet` | An internal slot owned by a container component (tabs, accordions, field sections) | Referenced by a component property |

```xml
<!-- Template-level Region -->
<flexiPageRegions>
   <itemInstances>
      <componentInstance>...</componentInstance>
   </itemInstances>
   <name>main</name>
   <type>Region</type>
</flexiPageRegions>

<!-- Facet -- sibling of Region at the same level, NOT nested -->
<flexiPageRegions>
   <itemInstances>
      <componentInstance>...</componentInstance>
   </itemInstances>
   <name>tab1_content</name>
   <type>Facet</type>
</flexiPageRegions>
```

**Critical structural rules:**
- Facet regions are **siblings** of template regions, not nested children.
- Every `<name>` value (Region or Facet) must be **unique** across the entire FlexiPage file. Two `<flexiPageRegions>` with the same `<name>` = deployment failure.
- If two components belong to the same tab/section, put both `<itemInstances>` inside ONE region -- do NOT create two regions with the same name.

**Region/Facet selection rule of thumb**

```
Is this a slot the template advertised? -> Region
Is this an internal slot of a container component? -> Facet
```

---

## 6. `componentInstance` and `itemInstances`

Each component placed on the page is one `<componentInstance>` wrapped in its own `<itemInstances>`:

```xml
<itemInstances>
   <componentInstance>
      <componentName>flexipage:richText</componentName>
      <identifier>flexipage_richText_1</identifier>
      <componentInstanceProperties>
         <name>richTextValue</name>
         <value>&lt;b&gt;Welcome&lt;/b&gt;</value>
      </componentInstanceProperties>
   </componentInstance>
</itemInstances>
```

**Identifier rules:**
- Every `<identifier>` must be unique across the entire file.
- Convention: `{componentType}_{context}_{sequence}` -- e.g. `relatedList_contacts_1`, `richText_header_1`, `fieldSection_details_1`.
- For internal anonymous slots (field-section columns, nested containers), use UUID facets: `Facet-66d5a4b3-bf14-4665-ba75-1ceaa71b2cde`.

**Property value encoding** -- values containing `<`, `>`, `&`, `"`, `'` MUST be XML-encoded **in this order** (encoding `&` last causes double-encoding):

```
1. & -> &amp;     (FIRST)
2. < -> &lt;
3. > -> &gt;
4. " -> &quot;
5. ' -> &apos;
```

Search every `<value>` tag -- raw `<` or `>` characters inside one is always a bug.

---

## 7. Dynamic Forms -- `FieldInstance` and `FieldSection`

Dynamic Forms replace the legacy `flexipage:recordForm` (which renders the page-layout assigned to the record type) with individually-placed fields and field sections, each capable of its own visibility rule. Available on Record Pages only.

### Field reference rule

Always `Record.{FieldApiName}`. **Never** `Account.Name` / `Case.Subject`.

```xml
<!-- CORRECT -->
<fieldItem>Record.Subject</fieldItem>

<!-- WRONG -->
<fieldItem>Case.Subject</fieldItem>
```

### FieldInstance structure

Every `<fieldInstance>` requires `fieldInstanceProperties` with a `uiBehavior` value of `none`, `readonly`, or `required`. Each `<fieldInstance>` lives in its own `<itemInstances>` wrapper -- multiple fieldInstances in a single wrapper is a deployment error.

```xml
<itemInstances>
   <fieldInstance>
      <fieldInstanceProperties>
         <name>uiBehavior</name>
         <value>none</value>
      </fieldInstanceProperties>
      <fieldItem>Record.Status</fieldItem>
      <identifier>RecordStatusField</identifier>
      <visibilityRule>
         <booleanFilter>1</booleanFilter>
         <criteria>
            <leftValue>{!Record.RecordType.DeveloperName}</leftValue>
            <operator>EQUAL</operator>
            <rightValue>Support_Case</rightValue>
         </criteria>
      </visibilityRule>
   </fieldInstance>
</itemInstances>
```

### FieldSection -- grouping fields

FieldSection is a container component whose columns are facets. Three-level nesting:

```
Region (template region: main)
  """ componentInstance: flexipage:fieldSection
       """ columns property -> references Facet UUID
              """ Facet contains the fieldInstance entries
```

```xml
<componentInstanceProperties>
   <name>columns</name>
   <value>Facet-{uuid-of-column-1}</value>
</componentInstanceProperties>
```

### When to use Dynamic Forms

- Different roles need different field subsets on the same record type.
- Field visibility must depend on field values (e.g. show `Escalation_Reason__c` only when `Status = Escalated`).
- Replacing many record-type-specific page layouts where the only delta is field visibility.

### When NOT to use Dynamic Forms

- The object doesn't support Dynamic Forms (verify in App Builder -- coverage expands per release).
- A standard page layout is acceptable and there is no visibility logic to express.

---

## 8. `visibilityRule` -- Conditional Rendering

`visibilityRule` is valid on `componentInstance`, `fieldInstance`, `actionInstance`, and on a `flexiPageRegions` block itself. Evaluated at runtime.

### Structure

```xml
<visibilityRule>
   <booleanFilter>1 AND (2 OR 3)</booleanFilter>
   <criteria>
      <leftValue>{!Record.Priority}</leftValue>
      <operator>EQUAL</operator>
      <rightValue>High</rightValue>
   </criteria>
   <criteria>
      <leftValue>{!$Permission.ViewInternalNotes}</leftValue>
      <operator>EQUAL</operator>
      <rightValue>true</rightValue>
   </criteria>
   <criteria>
      <leftValue>{!$User.ProfileId}</leftValue>
      <operator>EQUAL</operator>
      <rightValue>00e...</rightValue>
   </criteria>
</visibilityRule>
```

### Supported left-value sources

| Source | Example |
|---|---|
| Record field | `{!Record.Status}` |
| Custom Permission | `{!$Permission.EscalateCase}` |
| User field | `{!$User.ProfileId}`, `{!$User.UserRoleId}` |
| Form factor | `{!$Client.FormFactor}` (`Large`, `Medium`, `Small`) |
| Custom Label | `{!$Label.MyLabel}` |
| Permission Set | via `$Permission` custom permission proxy |

### Operators

`EQUAL`, `NE`, `LT`, `LE`, `GT`, `GE`, `CONTAINS`, `STARTS_WITH`, `INCLUDES`, `EXCLUDES`, `NULL`, `NOT_NULL`.

### Rules

- **Prefer Custom Permission over Profile-based visibility.** Profiles get renamed; permissions are explicit and survive reorgs.
- Use `{!$Client.FormFactor}` to hide heavy components on phone (`Small`).
- Test with multiple user types in sandbox before activating to production.
- Document every visibility rule in the page's `<description>` element.

---

## 9. Dynamic Actions -- `platformActionList`

Dynamic Actions replace the static page-layout button bar with an action bar whose entries can have individual visibility rules. Record Pages only.

```xml
<platformActionList>
   <platformActionListItems>
      <actionName>Case.Escalate_To_Tier2</actionName>
      <actionType>QuickAction</actionType>
      <sortOrder>0</sortOrder>
      <visibilityRule>
         <booleanFilter>1 AND 2</booleanFilter>
         <criteria>
            <leftValue>{!Record.Status}</leftValue>
            <operator>EQUAL</operator>
            <rightValue>Open</rightValue>
         </criteria>
         <criteria>
            <leftValue>{!$Permission.EscalateCase}</leftValue>
            <operator>EQUAL</operator>
            <rightValue>true</rightValue>
         </criteria>
      </visibilityRule>
   </platformActionListItems>
</platformActionList>
```

**`actionType` values:** `QuickAction`, `StandardButton`, `CustomButton`, `ProductivityAction`, `FlowAction`.

---

## 10. Record Page Assignment

Activation is what links a FlexiPage to actual user sessions. Assignment is layered -- Salesforce picks the most specific active page based on these dimensions:

1. **App + Profile + Record Type + Form Factor** (most specific)
2. App + Profile + Record Type
3. App + Profile
4. App + Record Type
5. App default
6. Org default (least specific)

**Form factor** splits into `Desktop` and `Phone`. Each combination can have its own assigned FlexiPage.

### Where assignment lives

For `RecordPage` and `HomePage`, the assignments are stored in a separate **`AppMenu`**, **`CustomApplication`**, or **`Profile`** metadata. The FlexiPage metadata XML itself does NOT contain the full assignment map -- it carries the page definition. Assignments are either:
- Set through App Builder UI (then captured by retrieve into Profile/CustomApplication metadata), or
- Authored in `CustomApplication`/`Profile` metadata directly.

### Activation rules

- Activate at the most specific level needed. Never default-activate at "Org Default" unless the page is genuinely for everyone.
- When two pages are activated at the same specificity, the most recently activated wins -- avoid ambiguous duplicates.
- Always inspect the App Builder "Activation" tab before production deploy.
- Document the intended assignment in the FlexiPage `<description>`.

---

## 11. LWC Placement on FlexiPages

### LWC `js-meta.xml` target declarations

A custom LWC is only available in App Builder when its `js-meta.xml` declares the matching target.

| FlexiPage type | Required LWC target |
|---|---|
| RecordPage | `lightning__RecordPage` |
| AppPage | `lightning__AppPage` |
| HomePage | `lightning__HomePage` |
| Email Application Pane | `lightning__Inbox` |
| Tab (utility / nav) | `lightning__Tab` |
| Quick Action on record | `lightning__RecordAction` |
| Flow screen embed | `lightning__FlowScreen` |

```xml
<?xml version="1.0" encoding="UTF-8"?>
<LightningComponentBundle xmlns="http://soap.sforce.com/2006/04/metadata">
   <apiVersion>66.0</apiVersion>
   <isExposed>true</isExposed>
   <targets>
      <target>lightning__RecordPage</target>
      <target>lightning__AppPage</target>
      <target>lightning__HomePage</target>
   </targets>
   <targetConfigs>
      <targetConfig targets="lightning__RecordPage">
         <property name="recordId" type="String" label="Record Id"
                   description="Auto-populated by the platform" />
         <property name="cardTitle" type="String" label="Card Title"
                   default="Case Timeline" />
         <supportedFormFactors>
            <supportedFormFactor type="Large" />
            <supportedFormFactor type="Small" />
         </supportedFormFactors>
      </targetConfig>
   </targetConfigs>
</LightningComponentBundle>
```

### What the platform auto-injects on a RecordPage

| `@api` property | Value injected |
|---|---|
| `recordId` | The 18-char Id of the record being viewed |
| `objectApiName` | The API name of the sObject |

LWC code:

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

### Placement in FlexiPage XML

```xml
<itemInstances>
   <componentInstance>
      <componentName>c:caseTimelineComponent</componentName>
      <identifier>caseTimeline_1</identifier>
      <componentInstanceProperties>
         <name>cardTitle</name>
         <value>Case Timeline</value>
      </componentInstanceProperties>
   </componentInstance>
</itemInstances>
```

Note: `recordId` is auto-injected -- do NOT pass it as a `componentInstanceProperty`. The platform binds it from the URL.

---

## 12. Flow Placement on FlexiPages

Embedded screen flows use the Flow runtime component.

```xml
<itemInstances>
   <componentInstance>
      <componentName>flowRuntime:flowRuntimeForFlexipage</componentName>
      <identifier>flow_escalation_1</identifier>
      <componentInstanceProperties>
         <name>flowApiName</name>
         <value>Case_Escalation_Screen_Flow</value>
      </componentInstanceProperties>
      <componentInstanceProperties>
         <name>inputVariables</name>
         <value>[{"name":"recordId","type":"String","value":"{!recordId}"}]</value>
      </componentInstanceProperties>
      <componentInstanceProperties>
         <name>flowLabel</name>
         <value>Escalate Case</value>
      </componentInstanceProperties>
   </componentInstance>
</itemInstances>
```

**Rules:**
- Only **Screen Flows** belong on a FlexiPage. Autolaunched and record-triggered flows must NOT be embedded.
- The flow must be **Active** before the FlexiPage is deployed -- referencing a Draft flow fails at runtime.
- Pass `recordId` via `inputVariables` for Record Pages.
- Verify the component name in your release -- `flowRuntime:flowRuntimeForFlexipage` is the current canonical name but has changed historically.

---

## 13. Placeholder vs Default Component

App Builder lets you mark a component as a **placeholder** (no runtime rendering -- design-time only) or as the **default** component for a region. In metadata, this surfaces via a `placeholder` property:

```xml
<componentInstanceProperties>
   <name>placeholder</name>
   <value>true</value>
</componentInstanceProperties>
```

Placeholders are useful when building a page incrementally -- they reserve layout space without forcing an early commitment to a specific component. Remove all placeholders before production deployment.

---

## 14. Mobile vs Desktop

Lightning Pages render on Desktop (browser, Salesforce Console) and Phone (Salesforce mobile app). Behavior differs:

| | Desktop | Phone |
|---|---|---|
| Columns | Multi-column | Single column (stacked) |
| Standard header | Full Highlights Panel | Compact |
| Heavy components (charts, dashboards) | Render | May not render |
| Form factor variable | `{!$Client.FormFactor} = 'Large'` | `{!$Client.FormFactor} = 'Small'` |

### Three approaches

| Approach | When to use |
|---|---|
| Single FlexiPage, responsive components | Components behave acceptably in both form factors |
| Single FlexiPage with form-factor visibility filters | A subset of components should hide on phone |
| Separate FlexiPage for Phone | Mobile experience differs structurally |

### Rules

- Always preview the phone form factor in App Builder before deployment.
- Use `<supportedFormFactor type="Small" />` in LWC `targetConfig` only when the component is mobile-safe.
- For heavy custom LWCs, apply a form-factor visibility rule that hides them on Small.

---

## 15. Email Application Pane (`EmailChrome`)

A specialized FlexiPage type used in Outlook / Gmail integration. Components must declare `lightning__Inbox` as a target. The pane renders inside the email client -- limited to compact UI patterns.

```xml
<type>EmailChrome</type>
<template>
   <name>flexipage:emailApplicationPaneOneRegion</name>
</template>
```

No `sobjectType` (the pane is contact/lead-context resolved at runtime, not bound to a single sObject).

---

## 16. Deployment Dependencies

FlexiPage deployment will fail if any referenced metadata isn't already present in the target org. Order is strict.

### Deploy order

```
1. Custom objects + fields referenced by Dynamic Forms
2. Custom Permissions referenced in visibility rules
3. LWC bundles referenced by componentName
4. Flows referenced by flowApiName (must be Active)
5. Quick Actions referenced in platformActionList
6. FlexiPage itself
7. CustomApplication / Profile metadata that assigns the page
```

### package.xml example

```xml
<types>
   <members>caseTimelineComponent</members>
   <members>caseSummaryPanel</members>
   <name>LightningComponentBundle</name>
</types>
<types>
   <members>Case_Escalation_Screen_Flow</members>
   <name>Flow</name>
</types>
<types>
   <members>Case_Record_Page_Support</members>
   <name>FlexiPage</name>
</types>
```

### Validation command

```bash
sf project deploy start \
  --metadata "FlexiPage:Case_Record_Page_Support" \
  --dry-run \
  --target-org <alias>

sf project retrieve start \
  --metadata "FlexiPage:Case_Record_Page_Support" \
  --target-org <alias>

sf data query \
  --query "SELECT Id, MasterLabel, Type, EntityDefinitionId FROM FlexiPage ORDER BY MasterLabel" \
  --target-org <alias>
```

---

## 17. Bootstrapping a New FlexiPage

When creating a NEW FlexiPage, bootstrap with the CLI template rather than hand-writing XML. The template enforces valid structure and prevents the most common deployment errors.

```bash
sf template generate flexipage \
  --name Case_Record_Page_Support \
  --template RecordPage \
  --sobject Case \
  --primary-field Subject \
  --secondary-fields Status,Priority,Owner.Name \
  --detail-fields Subject,Status,Priority,Description \
  --output-dir force-app/main/default/flexipages
```

If the command fails: `sf plugins install templates`, then retry. Do not proceed with manual XML authoring until the template succeeds.

---

## 18. Performance Guidelines

- **Component count:** each component adds wire-call and render overhead. Audit before production.
- **No duplicate `@wire` for the same record fields** across multiple LWCs on the same page -- extract a parent or use the Lightning Data Service cache.
- **Heavy data processing in Apex**, not in client-side JS. Page-load JS is the slowest place to do work.
- **Lazy-render with tabs** -- components inside non-active tabs only render on first activation.
- **Avoid nested Related Lists** -- combine into a single Related List component where possible.
- **No Platform Events or streaming on a Record Page** unless required -- they hold persistent connections per active page.

---

## 19. Anti-Patterns (Deploy or Runtime Failures)

| # | Anti-pattern | Why it fails |
|---|---|---|
| 1 | Two `<flexiPageRegions>` with the same `<name>` | Duplicate-name deployment error |
| 2 | Same `<identifier>` value reused | Duplicate-identifier deployment error |
| 3 | Multiple `<fieldInstance>` inside one `<itemInstances>` | "Element fieldInstance is duplicated" |
| 4 | `Object.Field` instead of `Record.Field` in fieldItem | "Invalid field reference" |
| 5 | Missing `fieldInstanceProperties.uiBehavior` on a fieldInstance | Deployment error |
| 6 | Raw `<`, `>`, `&` in a `<value>` element | XML parsing error |
| 7 | `__c` suffix in page name | "Cannot create component with namespace" |
| 8 | `<mode>` element inside a region | "Region specifies mode that parent doesn't support" |
| 9 | Facet defined but not referenced by any component property | "Unused Facet" |
| 10 | FlexiPage deployed before referenced LWC | "Component not found" |
| 11 | Referencing a Draft flow in `flowApiName` | Runtime error when user hits the page |
| 12 | Activating at Org Default unnecessarily | Overrides pages for users it shouldn't apply to |
| 13 | Profile-based visibility instead of Custom Permission | Brittle to profile rename / user reassignment |
| 14 | Passing `recordId` as a componentInstanceProperty to a Record Page LWC | Conflicts with platform auto-injection |
| 15 | Facets nested inside a Region block | Facets must be siblings, not children |

---

## 20. Definition of Done

- [ ] All referenced LWC bundles deployed and `isExposed=true` with correct target
- [ ] All referenced Flows are Active in the target org
- [ ] All referenced Custom Permissions deployed
- [ ] All referenced fields exist on the sObject
- [ ] `<description>` element documents owner, purpose, assignment context, deploy date
- [ ] Assignment rules defined (App / RecordType / Profile / FormFactor as appropriate)
- [ ] Assignment tested in sandbox with a user in each target profile
- [ ] Desktop layout validated in App Builder
- [ ] Phone layout validated -- either responsive or a separate phone FlexiPage authored
- [ ] Component visibility rules tested with multiple user contexts
- [ ] No duplicate `<identifier>` or duplicate region `<name>` values
- [ ] All `<value>` elements with HTML/XML correctly entity-encoded
- [ ] No placeholders left in the deployable XML
- [ ] Not activated at Org Default unless intentionally for everyone
- [ ] Dynamic Forms visibility conditions tested across all applicable record types

---

## 21. Common AI Mistakes to Avoid

| Mistake | Why It's Wrong | Correct approach |
|---|---|---|
| Deploying FlexiPage before LWC components | Deployment fails -- referenced components don't exist | Deploy all dependency components first |
| No activation rules configured | Wrong page shown to wrong users; or page is never activated | Define activation by App/RecordType/Profile combination; test before production |
| No mobile layout review | Mobile users see broken or unusable layout | Always check Phone form factor in App Builder |
| Placing @wire-heavy LWC directly without checking | Performance degradation on page load | Profile LWC performance; use lazy loading via tabs |
| Using Profile-based visibility instead of Custom Permission | Brittle; breaks when profiles are renamed or users change profiles | Use Custom Permission-based visibility |
| Referencing inactive or non-existent Flows | Runtime error when user encounters the embedded flow | Verify flow is active before deploying FlexiPage |
| Activating a page at Org Default unnecessarily | Overrides pages for all users, not just the intended audience | Activate at the most specific level needed |
| Missing component descriptions | Hard to maintain -- no context for future developers | Add description to every FlexiPage metadata file |

---

## 22. Empirical Findings & Implementation Notes

When Salesforce's documented approach doesn't work in this org, the workaround goes here. Date-stamp every entry.

| # | Date | Documented approach | What actually works | Why / Context |
|---|---|---|---|---|

---

## 23. Official References

- [FlexiPage Metadata API](https://developer.salesforce.com/docs/atlas.en-us.api_meta.meta/api_meta/meta_flexipage.htm)
- [Lightning App Builder Help](https://help.salesforce.com/s/articleView?id=sf.lightning_app_builder_overview.htm)
- [Dynamic Forms Help](https://help.salesforce.com/s/articleView?id=sf.dynamic_forms_overview.htm)
- [Dynamic Actions Help](https://help.salesforce.com/s/articleView?id=sf.dynamic_actions_overview.htm)
- [LWC Configuration Tags Reference](https://developer.salesforce.com/docs/platform/lwc/guide/reference-configuration-tags.html)
- [LWC: Configure Components for Lightning App Builder](https://developer.salesforce.com/docs/component-library/documentation/en/lwc/lwc.use_config_for_app_builder)
- [forcedotcom/sf-skills `generating-flexipage`](https://github.com/forcedotcom/sf-skills/tree/main/skills/generating-flexipage) -- canonical bootstrap recipes
- [Trailhead: Lightning App Builder](https://trailhead.salesforce.com/content/learn/modules/lightning_app_builder)
- [Well-Architected: User Experience](https://architect.salesforce.com/well-architected/adaptable/user-experience)

---

*FlexiPage Canonical Reference | v3.0 | Last verified 2026-05-16*

