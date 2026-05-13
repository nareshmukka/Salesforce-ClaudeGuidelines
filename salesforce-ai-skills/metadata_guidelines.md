# Metadata Design Guidelines

**Version**: 2.0 (April 2026)
**Developer**: Naresh | Senior Salesforce Developer
**Purpose**: Guidelines for Salesforce metadata design including custom objects, fields, record types, validation rules, custom metadata, and naming. Attach when designing or modifying any Salesforce metadata.

---

## Table of Contents

1. [Required Agent Output Contract](#1-required-agent-output-contract)
2. [Custom Objects](#2-custom-objects)
3. [Custom Fields](#3-custom-fields)
4. [Record Types](#4-record-types)
5. [Page Layouts](#5-page-layouts)
6. [Validation Rules](#6-validation-rules)
7. [Custom Metadata Types (CMDT)](#7-custom-metadata-types-cmdt)
8. [Custom Settings (Use Sparingly)](#8-custom-settings-use-sparingly)
9. [External IDs](#9-external-ids)
10. [Indexes and Selectivity](#10-indexes-and-selectivity)
11. [Global Value Sets](#11-global-value-sets)
12. [Dependent Fields](#12-dependent-fields)
13. [Naming Summary Table](#13-naming-summary-table)
14. [Descriptions and Help Text](#14-descriptions-and-help-text)
15. [Deployment Order](#15-deployment-order)
16. [Common AI Mistakes to Avoid](#16-common-ai-mistakes-to-avoid)
17. [Definition of Done](#17-definition-of-done)
18. [Validation Commands](#18-validation-commands)
19. [Official References](#19-official-references)

---

## 1. Required Agent Output Contract

When designing or modifying any Salesforce metadata, the AI agent MUST produce:

### 1.1 Metadata Inventory

List every metadata item being created or modified:

```
New Objects:
  - SupportTicket__c (custom object)

New Fields:
  - Case.Resolution_Notes__c (Long Text Area, 32768)
  - Case.Escalation_Reason__c (Picklist)
  - SupportTicket__c.External_ID__c (Text 255, External ID, Unique)

Modified Metadata:
  - Validation Rule: VR_Case_SubjectRequired (adding bypass Custom Permission)

Record Types:
  - Case.Support_Case (new record type)
```

### 1.2 Dependency Order

```
1. SupportTicket__c object
2. SupportTicket__c fields
3. Case.Resolution_Notes__c field
4. Case.Escalation_Reason__c field (with picklist values)
5. Case.Support_Case record type
6. VR_Case_SubjectRequired validation rule (after BypassCaseValidation Custom Permission)
```

### 1.3 Naming Review

Confirm each item follows the naming conventions in Section 13.

### 1.4 Security Classification

```
SupportTicket__c: Internal — Support team only; no PII fields
Case.Resolution_Notes__c: Internal — visible to agents; not customer-facing
Case.Escalation_Reason__c: Internal
```

### 1.5 Deployment Plan

State the full deployment order with commands.

---

## 2. Custom Objects

### Naming Convention

```
<Domain>__c
```

Examples: `SupportTicket__c`, `AppLog__c`, `IntegrationConfig__c`, `FinancialTransaction__c`

### Required Attributes for Every Custom Object

Every custom object created MUST have:

| Attribute | Requirement |
|---|---|
| **Label** | Human-readable name |
| **Plural Label** | Correct plural form |
| **Description** | Team/owner, purpose, created date |
| **API Name (DeveloperName)** | Stable, descriptive, follows naming convention |
| **Sharing Model (OWD)** | Explicitly chosen — do NOT leave at default without conscious decision |
| **Reports enabled** | Yes unless there is a reason not to |
| **Activities enabled** | Yes if the object will have related activities |
| **History tracking** | Enable if auditability is required |

### Sharing Model Decision Guide

| Sharing Model | Use When |
|---|---|
| `Public Read/Write` | All users should be able to see and edit all records (low-sensitivity, collaborative objects) |
| `Public Read Only` | All users see all records; only owner/above can edit |
| `Private` | Users only see their own records; sharing must be explicitly opened via rules/teams |
| `Controlled by Parent` | Child object inherits parent's sharing (detail side of master-detail) |

**Default to Private for sensitive data objects.** Document the OWD choice in the object description.

### Object Metadata XML Example

```xml
<?xml version="1.0" encoding="UTF-8"?>
<CustomObject xmlns="http://soap.sforce.com/2006/04/metadata">
    <description>
        Support Ticket object for tracking customer support requests.
        Owner: Support Engineering team.
        Created: April 2026.
        OWD: Private — Support agents see only their assigned tickets.
    </description>
    <enableActivities>true</enableActivities>
    <enableBulkApi>true</enableBulkApi>
    <enableFeeds>false</enableFeeds>
    <enableHistory>true</enableHistory>
    <enableReports>true</enableReports>
    <enableSearch>true</enableSearch>
    <enableSharing>true</enableSharing>
    <enableStreamingApi>true</enableStreamingApi>
    <label>Support Ticket</label>
    <nameField>
        <label>Ticket Number</label>
        <type>AutoNumber</type>
        <displayFormat>TKT-{0000000}</displayFormat>
    </nameField>
    <pluralLabel>Support Tickets</pluralLabel>
    <sharingModel>Private</sharingModel>
</CustomObject>
```

---

## 3. Custom Fields

### Naming Convention

- Descriptive, not abbreviated, not prefixed with temp names.
- Use PascalCase for multi-word names.
- NEVER use: `Temp__c`, `New__c`, `Field1__c`, `Test__c`.

Examples:
- `Resolution_Notes__c` (not `Res_Nts__c`)
- `Escalation_Reason__c` (not `EscRsn__c`)
- `Integration_External_ID__c` (not `ExtID__c`)

### Required Attributes for Every Custom Field

| Attribute | Requirement |
|---|---|
| **Label** | Human-readable; matches the field's purpose |
| **Help Text** | What the user should enter in this field — visible in the UI tooltip |
| **Description** | Technical notes — field purpose, integration key, audit notes |
| **Data Type** | Correct type for the data (see type selection table below) |
| **Required** | Only if the business rule REQUIRES the value; not as a default |

### Data Type Selection Table

| Data | Recommended Type | Notes |
|---|---|---|
| Short single-line text (< 255 chars) | Text | Use for names, codes, identifiers |
| Long free-form text | Long Text Area | Up to 131,072 characters |
| Rich formatted text | Rich Text Area | HTML-formatted content |
| Whole numbers | Number (0 decimal places) | Not Currency; use for counts |
| Decimal numbers | Number (with decimals) | For non-financial decimals |
| Money / financial values | Currency | Respects org currency settings |
| Percentage values | Percent | Renders with % in UI |
| True/False flag | Checkbox | Default to false for new fields |
| Specific date (no time) | Date | Use for birthdays, deadlines |
| Date and time | DateTime | Use for timestamps, events |
| Controlled list of values | Picklist | Use Global Value Set for shared values |
| Multiple selectable values | Multi-Select Picklist | Use sparingly — reporting is more complex |
| Reference to another record | Lookup or Master-Detail | Choose based on required cascade behavior |
| Auto-incrementing ID | Auto Number | Use for display-friendly record numbers |
| URL | URL | Auto-renders as clickable link |
| Email | Email | Auto-validates format |
| Phone | Phone | Auto-formats phone numbers |

### Required vs Optional Fields

- Only mark a field as **required** at the object level if the business rule genuinely mandates it.
- Over-using required fields creates friction for users and integration imports.
- If the field is required only in certain contexts (e.g., when status = Closed), use a Validation Rule instead of making the field required.
- Never make fields required to "clean up data" — fix the data problem with a data migration, not a required field.

---

## 4. Record Types

### Rule: Only Create When Necessary

**Only create Record Types when there are materially different business processes** requiring:
- Different picklist values for the same field (e.g., Support Case has different Priority values than Partner Case).
- Different page layout requirements with different field sets.
- Different validation rules or flows applicable to one record type but not another.

### Do NOT Create Record Types For

- Display-only differences (e.g., showing a different icon or color).
- Slight variations in picklist values that could be handled by a dependent picklist.
- Segmentation that could be handled by a custom field and filters.

**Every additional record type increases maintenance overhead** — more page layouts to maintain, more PS assignments, more automation conditions. Justify clearly before creating.

### Naming Convention

| Component | Convention | Example |
|---|---|---|
| DeveloperName (API) | `PascalCase` | `Support_Case` |
| Label | Human-readable | `Support Case` |

The `DeveloperName` is permanent once deployed. Choose it carefully.

### Referencing Record Types in Code

**NEVER hardcode a Record Type ID** (e.g., `'0125e000000abcDEF'`) in Apex, Flow, or any other code. Record Type IDs differ between orgs (sandbox vs production).

**ALWAYS reference by DeveloperName**:

```apex
// Correct
Id supportCaseRTId = Schema.SObjectType.Case
    .getRecordTypeInfosByDeveloperName()
    .get('Support_Case')
    .getRecordTypeId();

// Also acceptable: use CMDT to store the DeveloperName value
// Wrong — NEVER do this:
Id rtId = '0125e000000abcDEF'; // Hardcoded ID — breaks between orgs
```

### Custom Metadata for Record Type References

If multiple places in code reference the same Record Type, centralize it in a Custom Metadata record:

```
CMDT: RecordTypeConfig__mdt
Fields: ObjectApiName__c, RecordTypeDeveloperName__c, RecordTypeLabel__c
```

---

## 5. Page Layouts

### Rules

- Assign page layouts to record types and profiles/apps via FlexiPage activation (Dynamic Forms).
- **Prefer Dynamic Forms over page layouts** for complex conditional field visibility — Dynamic Forms eliminate the need for multiple page layouts for the same record type.
- Page layouts are still needed for: Related List ordering, Quick Action configuration, Standard button layout (when not using Dynamic Actions).

### Compact Layouts

- Define a compact layout for every object that:
  - Appears in mobile views.
  - Appears as a card in Related Lists.
  - Appears in the Activity Feed or chatter highlights.
- Compact layout should include: the record name/number, 3-5 most relevant fields.
- Never leave compact layout at the system default (which shows ID and Name only).

### Page Layout Naming Convention

```
<ObjectLabel> <RecordTypeLabel> Layout
```

Example: `Case Support Case Layout`, `Account Partner Account Layout`

---

## 6. Validation Rules

### Naming Convention

```
VR_<ObjectApiName>_<Intent>
```

Examples:
- `VR_Case_SubjectRequired`
- `VR_Opportunity_CloseDateFuture`
- `VR_Contact_EmailFormat`
- `VR_SupportTicket__c_ResolutionNotesOnClose`

### Required Components

Every validation rule MUST have:

1. **Descriptive name** following the convention.
2. **Description** explaining what the rule validates and why.
3. **User-friendly, actionable error message** — not a technical error code.
4. **Bypass mechanism** via Custom Permission (not profile check).

### Bypass Pattern

**ALWAYS** add a Custom Permission bypass to validation rules. This allows trusted users (support leads, admins, integration users) to create records that would otherwise fail validation.

```
AND(
  <validation condition here>,
  NOT($Permission.Bypass_<ObjectName>_Validation)
)
```

Full example:

```
AND(
  ISBLANK(Subject),
  NOT($Permission.BypassCaseValidation)
)
```

Error message: `"Subject is required. Please enter a summary of the support issue before saving."`

### Error Message Guidelines

| Bad Error Message | Good Error Message |
|---|---|
| `"Validation failed"` | `"Case subject is required. Please enter a brief description of the issue."` |
| `"Field missing"` | `"Resolution Notes are required when closing a case. Please document the resolution before changing status to Closed."` |
| `"Invalid date"` | `"Close Date must be today or in the future. Please correct the Close Date."` |

### Validation Rule XML Example

```xml
<?xml version="1.0" encoding="UTF-8"?>
<ValidationRule xmlns="http://soap.sforce.com/2006/04/metadata">
    <fullName>VR_Case_SubjectRequired</fullName>
    <active>true</active>
    <description>
        Ensures the Case Subject field is populated before save.
        Bypass: Assign BypassCaseValidation custom permission to override.
        Owner: Support Team. Created: April 2026.
    </description>
    <errorConditionFormula>
        AND(
            ISBLANK(Subject),
            NOT($Permission.BypassCaseValidation)
        )
    </errorConditionFormula>
    <errorDisplayField>Subject</errorDisplayField>
    <errorMessage>Subject is required. Please enter a brief summary of the issue before saving.</errorMessage>
</ValidationRule>
```

---

## 7. Custom Metadata Types (CMDT)

### Purpose

Custom Metadata Types (CMDT) are the standard mechanism for storing configuration data in Salesforce. They are:
- Deployable via package.xml (unlike Custom Settings, which require data migration separately).
- Readable in Apex, Flow, Validation Rules, and Formulas without DML limits.
- Version-controllable in source-tracked projects.
- Accessible in all sandbox and production orgs once deployed.

### When to Use CMDT

- Configuration values (thresholds, limits, feature flags).
- Integration settings (endpoint URLs, credentials are NOT appropriate — use Named Credentials for secrets).
- Picklist matrices (what Status values are valid for a given Record Type).
- Mapping tables (country code → region, error code → user message).
- Record type DeveloperName references.
- Bypass permission names registry.

### When NOT to Use CMDT

- **Secrets / credentials** — use Named Credentials or an external secrets vault.
- **User- or profile-level overrides** — use Custom Settings (Hierarchy type) instead.
- **Large datasets** (thousands of records) — CMDT has a per-org record limit; use a custom object for large datasets.

### Naming Convention

```
CMDT_<Domain>__mdt
```

Examples: `CMDT_Integration__mdt`, `CMDT_FeatureFlag__mdt`, `CMDT_RecordTypeConfig__mdt`

Records within a CMDT use a `DeveloperName` that must be stable (no temp names).

### Example: Integration Config CMDT

```xml
<!-- Object definition -->
<?xml version="1.0" encoding="UTF-8"?>
<CustomObject xmlns="http://soap.sforce.com/2006/04/metadata">
    <description>
        Integration configuration for external system connections.
        Owner: Integration Team. Created: April 2026.
        NOTE: Do not store credentials here. Use Named Credentials for secrets.
    </description>
    <label>Integration Config</label>
    <pluralLabel>Integration Configs</pluralLabel>
    <fields>
        <fullName>Endpoint_URL__c</fullName>
        <label>Endpoint URL</label>
        <type>Url</type>
        <description>Base URL for the external system API endpoint.</description>
    </fields>
    <fields>
        <fullName>Is_Active__c</fullName>
        <label>Is Active</label>
        <type>Checkbox</type>
        <defaultValue>true</defaultValue>
        <description>When false, the integration is disabled without code changes.</description>
    </fields>
    <fields>
        <fullName>Timeout_Seconds__c</fullName>
        <label>Timeout (Seconds)</label>
        <type>Number</type>
        <precision>5</precision>
        <scale>0</scale>
        <description>HTTP request timeout in seconds. Default: 30.</description>
    </fields>
</CustomObject>
```

```xml
<!-- CMDT Record -->
<?xml version="1.0" encoding="UTF-8"?>
<CustomMetadata xmlns="http://soap.sforce.com/2006/04/metadata" xsi:type="CustomMetadata">
    <label>CRM Integration</label>
    <protected>false</protected>
    <values>
        <field>Endpoint_URL__c</field>
        <value xsi:type="xsd:string">https://api.external-crm.com/v2</value>
    </values>
    <values>
        <field>Is_Active__c</field>
        <value xsi:type="xsd:boolean">true</value>
    </values>
    <values>
        <field>Timeout_Seconds__c</field>
        <value xsi:type="xsd:double">30</value>
    </values>
</CustomMetadata>
```

### Accessing CMDT in Apex

```apex
// Query CMDT (no DML governor limit consumption)
CMDT_Integration__mdt config = CMDT_Integration__mdt.getInstance('CRM_Integration');
if (config != null && config.Is_Active__c) {
    String endpoint = config.Endpoint_URL__c;
    Integer timeout = (Integer) config.Timeout_Seconds__c;
    // proceed with integration call
}
```

### package.xml for CMDT

```xml
<!-- Object definition -->
<types>
    <members>CMDT_Integration__mdt</members>
    <name>CustomObject</name>
</types>

<!-- CMDT Records -->
<types>
    <members>CMDT_Integration__mdt.CRM_Integration</members>
    <name>CustomMetadata</name>
</types>
```

---

## 8. Custom Settings (Use Sparingly)

### When Custom Settings Are Still Appropriate

Custom Settings are appropriate when:
- You need **user- or profile-level data overrides** (Hierarchy Custom Settings).
- Legacy automations rely on Custom Settings and the cost of migration exceeds the benefit.

For all other cases, prefer CMDT.

### Custom Settings Types

| Type | Description | Use When |
|---|---|---|
| **List Custom Settings** | Org-wide named settings (no hierarchy) | Shared configuration accessible across the org |
| **Hierarchy Custom Settings** | Org / Profile / User level with override hierarchy | When individual users or profiles need different values |

### Hierarchy Custom Setting Behavior

Salesforce evaluates hierarchy settings in this order (most specific wins):
1. User-level setting (if set for the running user)
2. Profile-level setting (if set for the user's profile)
3. Org-level setting (default)

### Prefer CMDT Over Custom Settings

| Concern | Custom Settings | CMDT |
|---|---|---|
| Deployable via package.xml | No (data only) | Yes |
| Version controlled with code | No | Yes |
| Accessible in Formula fields | No | Yes |
| User/Profile-level override | Yes | No |
| Recommended for new development | No | Yes |

---

## 9. External IDs

### Purpose

External IDs mark a field as an integration key for external system record matching. Used for:
- `upsert` operations: find-and-update or insert based on external key.
- Data migration: matching source system IDs during import.
- Deduplication checks.

### Rules

- Mark integration key fields as External ID.
- External ID fields are automatically indexed.
- Maximum 3 External ID fields per object — choose wisely.
- External IDs should use the `Unique` constraint if records should be uniquely identified by this value.
- Field type: Text (max 255 characters) or Number — most external IDs are Text.

### XML Example

```xml
<fields>
    <fullName>Integration_External_ID__c</fullName>
    <description>
        External ID for CRM system record matching.
        Used for upsert operations during data sync.
        Do not modify or clear this field once populated.
    </description>
    <externalId>true</externalId>
    <label>Integration External ID</label>
    <length>255</length>
    <type>Text</type>
    <unique>true</unique>
    <caseSensitive>false</caseSensitive>
</fields>
```

### Upsert Using External ID in Apex

```apex
// Upsert using external ID field
Case__c incomingCase = new Case__c();
incomingCase.Integration_External_ID__c = externalKey;
incomingCase.Subject__c = 'Incoming Case';

Database.upsert(incomingCase, Case__c.Integration_External_ID__c, false);
```

---

## 10. Indexes and Selectivity

### Standard Indexed Fields (No Action Needed)

These fields are automatically indexed by Salesforce:
- `Id`
- `Name`
- `OwnerId`
- `CreatedDate`
- `LastModifiedDate`
- All Lookup and Master-Detail relationship fields
- All External ID fields
- `SystemModstamp`

### Custom Index Requests

For custom fields that are frequently used as query filters on high-volume objects (millions of records), request a custom index via Salesforce Support (case with Salesforce Technical Support).

**Before requesting a custom index**, confirm the field qualifies:
- It is used in a `WHERE` clause in frequently-run queries.
- The object has a large record volume (typically 100K+ records).
- The field itself is selective.

### Selectivity Rule

A query filter is **selective** if it reduces the result set to less than approximately **10% of total object records** (for objects with > 100K records). If the filter is not selective, Salesforce may perform a full table scan even if an index exists.

**Design queries with this in mind:**
- Filter on indexed, selective fields first.
- Combine multiple filters to achieve selectivity.
- Avoid `LIKE '%value%'` — leading wildcards disable index use.
- Avoid `WHERE Status != 'Closed'` on large objects — `!=` is generally not selective.

### Query Design Patterns

```apex
// GOOD — filters on selective, indexed fields first
List<Case> cases = [
    SELECT Id, Subject, Status
    FROM Case
    WHERE OwnerId = :userId          // indexed, highly selective
    AND Status = 'Open'              // reduces further
    AND CreatedDate = LAST_N_DAYS:7  // indexed
    WITH USER_MODE
    ORDER BY CreatedDate DESC
    LIMIT 50
];

// BAD — non-selective filter on large object
List<Case> cases = [
    SELECT Id, Subject
    FROM Case
    WHERE Status != 'Closed'  // NOT selective — most cases may be open
];
```

---

## 11. Global Value Sets

### Purpose

Global Value Sets are picklist value definitions shared across multiple fields on multiple objects. Instead of maintaining the same list of values separately on each field, maintain them once and reference them from multiple fields.

### When to Use

- When the same set of picklist values is used on multiple fields or objects (e.g., `Region` values used on Account, Contact, and Opportunity).
- When changes to picklist values should automatically propagate to all fields using the set.

### When NOT to Use

- When the values are unique to a single field — create a standard field-level picklist instead.
- When different fields need slightly different subsets of the same concept — the global value set is all-or-nothing.

### Rules

- Name global value sets descriptively: `Region_Values`, `Priority_Levels`, `Status_Codes`.
- **Changes to a Global Value Set affect ALL fields that use it** — review all dependent fields and automations before modifying a global value set.
- Document which fields and objects use each Global Value Set.

### Global Value Set XML

```xml
<?xml version="1.0" encoding="UTF-8"?>
<GlobalValueSet xmlns="http://soap.sforce.com/2006/04/metadata">
    <customValue>
        <fullName>North_America</fullName>
        <default>false</default>
        <label>North America</label>
    </customValue>
    <customValue>
        <fullName>Europe</fullName>
        <default>false</default>
        <label>Europe</label>
    </customValue>
    <customValue>
        <fullName>Asia_Pacific</fullName>
        <default>false</default>
        <label>Asia Pacific</label>
    </customValue>
    <description>
        Region values shared across Account, Contact, and Opportunity objects.
        Owner: RevOps Team. Changes here affect all fields using this value set.
        Approvals required before modifying. Created: April 2026.
    </description>
    <label>Region Values</label>
    <sorted>false</sorted>
</GlobalValueSet>
```

---

## 12. Dependent Fields

### Overview

A dependent field relationship links a **controlling field** (usually a picklist) to a **dependent field** (a picklist filtered by the controlling field's value). Only the values valid for the selected controlling value appear in the dependent field.

### Use Case Example

Controlling Field: `Product_Line__c` (values: Hardware, Software, Services)
Dependent Field: `Product_Category__c`
- When `Product_Line__c = Hardware`: show Desktop, Laptop, Server
- When `Product_Line__c = Software`: show CRM, ERP, Analytics
- When `Product_Line__c = Services`: show Implementation, Support, Training

### Rules

- Document the full dependency matrix (controlling value → allowed dependent values) before building.
- Store the matrix in a Custom Metadata record if code needs to validate the combinations programmatically.
- Test all controlling/dependent combinations after deployment.
- Dependent fields do not work with Multi-Select Picklists as the controlling field.

### package.xml for Global Value Sets

```xml
<types>
    <members>Region_Values</members>
    <name>GlobalValueSet</name>
</types>
```

---

## 13. Naming Summary Table

| Metadata Type | Naming Convention | Example |
|---|---|---|
| Custom Object | `<Domain>__c` (PascalCase) | `SupportTicket__c` |
| Custom Field | `<DescriptiveName>__c` (PascalCase) | `Resolution_Notes__c` |
| Record Type DeveloperName | `PascalCase` (no spaces) | `Support_Case` |
| Page Layout | `<Object> <RecordType> Layout` | `Case Support Case Layout` |
| Validation Rule | `VR_<Object>_<Intent>` | `VR_Case_SubjectRequired` |
| Custom Metadata Type | `CMDT_<Domain>__mdt` | `CMDT_Integration__mdt` |
| Custom Settings | `CS_<Domain>__c` | `CS_FeatureFlags__c` |
| Global Value Set | `<Description>_Values` | `Region_Values` |
| Permission Set | `PS_<DomainOrRole>` | `PS_SupportAgent` |
| Permission Set Group | `PSG_<DomainOrRole>` | `PSG_SupportAgent` |
| Muting Permission Set | `MPS_<PSGName>_<Intent>` | `MPS_SupportAgent_NoCaseDelete` |
| Custom Permission | `PascalCase` (no prefix) | `BypassCaseValidation` |
| Apex Class | `<Domain><Type>` (PascalCase) | `CaseDashboardController` |
| Apex Test Class | `<ClassName>Test` | `CaseDashboardControllerTest` |
| LWC Component | `camelCase` | `caseTimelineComponent` |
| Flow | `<Object>_<Action>_<Type>` | `Case_Escalation_Screen_Flow` |
| Flow (Record-triggered) | `<Object>_<Trigger>_<Action>` | `Case_AfterUpdate_NotifyOwner` |
| Email Template | `<Object>_<Intent>` | `Case_Support_Acknowledgement` |
| Email Folder | `<Team>_<Domain>_Templates` | `Support_Team_Templates` |
| FlexiPage | `<Object>_Record_Page_<Variant>` | `Case_Record_Page_Support` |
| Trigger | `<Object>Trigger` | `CaseTrigger` |
| Trigger Handler | `<Object>TriggerHandler` | `CaseTriggerHandler` |

---

## 14. Descriptions and Help Text

### Rule: All Metadata MUST Have Descriptions

This is non-negotiable for maintainable orgs. Undocumented metadata becomes toxic debt — future developers cannot understand purpose, owner, or safe modification scope.

### Object Description Requirements

Every custom object must have a description containing:
- **Team/owner**: Which team owns this object.
- **Purpose**: What this object stores and why.
- **Created date**: When it was introduced.
- **OWD explanation**: Why the sharing model was chosen.

```
Support Ticket object for tracking customer-reported issues.
Owner: Support Engineering team.
Created: April 2026.
OWD: Private — agents see only assigned tickets; sharing rules open access to team leads.
```

### Field Help Text Requirements

Help text is shown in the UI as a tooltip when the user hovers over the field info icon. Write it for the user, not the developer:

- Good: `"Enter a brief description of the issue the customer is reporting. This appears in the customer-facing acknowledgement email."`
- Bad: `"Subject field for case"`
- Bad: (empty)

### Field Description Requirements

The description is the technical note — write it for the developer:

- What the field is used for technically.
- Any integration dependencies (e.g., "Populated by the CRM Sync process — do not modify manually").
- Bypass notes (e.g., "Validation rule VR_Case_SubjectRequired enforces this field; bypass via BypassCaseValidation custom permission").

### Auditability

In Salesforce implementations, field descriptions and help texts are **auditable documentation**. During security reviews, compliance audits, or handovers, the metadata description is the first place an auditor looks. Treat it as official documentation.

---

## 15. Deployment Order

### Critical Deployment Order Table

Deploy metadata in this order to avoid dependency failures:

| Step | Metadata Type | Notes |
|---|---|---|
| 1 | Custom Objects | Base objects before fields |
| 2 | Custom Fields | On all objects (standard + custom) |
| 3 | Global Value Sets | Before picklist fields that reference them |
| 4 | Record Types | After fields (picklist fields must exist) |
| 5 | Page Layouts | After record types |
| 6 | Compact Layouts | After fields |
| 7 | Validation Rules | After Custom Permissions exist |
| 8 | Custom Permissions | Before permission sets that use them |
| 9 | Custom Metadata Types | Object definition before records |
| 10 | Custom Metadata Records | After CMDT object exists |
| 11 | Email Templates | After Email Folders |
| 12 | Flows | After fields, objects, Apex classes used in flows |
| 13 | Apex Classes | After objects/fields they reference |
| 14 | Apex Triggers | After handler classes |
| 15 | Permission Sets | After objects, fields, Apex, Flows |
| 16 | Permission Set Groups | After all component Permission Sets |
| 17 | FlexiPages | After LWC components and Flows |
| 18 | Assignment Rules / Auto Response Rules | After fields they filter on |

### Dependency Failure Prevention

Before deploying a batch of metadata:
1. Sort the items by the order table above.
2. Group into logical deployment waves.
3. Run `--dry-run` (check-only) on each wave before deploying for real.
4. Confirm no deployment errors before proceeding to the next wave.

---

## 16. Common AI Mistakes to Avoid

| Mistake | Why It's Wrong | Correct Approach |
|---|---|---|
| Hardcoding Record Type IDs | IDs differ between sandbox and production — code breaks on deployment | Always use `getRecordTypeInfosByDeveloperName()` or CMDT |
| Creating Record Types for display-only differences | Adds maintenance overhead; record types should reflect different business processes | Use a custom field + conditional formatting instead |
| No help text or description on fields | Metadata becomes undocumented and unmaintainable | Every field must have help text and description before merge |
| Using Custom Settings for new configuration | Not deployable via package.xml; not accessible in formulas | Use CMDT instead |
| Not checking existing indexes before query optimization | May recommend an index that already exists, or miss that a non-selective filter is the problem | Check `SELECT` on `FieldDefinition` or review query explain plan |
| Overly broad validation rules with no bypass | Blocks integration imports and admin operations | Always include Custom Permission bypass in validation rules |
| Using temp names for API names | API name cannot change; `Case_Temp__c` becomes permanent tech debt | Plan names before first deployment |
| Not setting OWD consciously on new objects | Default OWD may expose records to all users | Always choose OWD deliberately and document it |
| Deploying validation rules before Custom Permissions they reference | Deployment failure | Deploy Custom Permissions before validation rules |
| No compact layout defined | Mobile and related list card view shows only ID + Name | Define compact layout for every custom object |

---

## 17. Definition of Done

Metadata is considered complete and deployable when ALL of the following are true:

- [ ] All custom objects have: label, plural label, description with owner and created date, chosen OWD
- [ ] All custom fields have: label, help text (user-facing), description (technical notes), correct data type
- [ ] All field names follow PascalCase convention; no temp or abbreviation names
- [ ] Record Types created only where materially different business processes exist; DeveloperNames are stable
- [ ] All Validation Rules named `VR_<Object>_<Intent>`; include Custom Permission bypass; user-friendly error messages
- [ ] CMDT used for all configuration data; no credentials stored in CMDT
- [ ] No hardcoded Record Type IDs anywhere in code or flows; all references use DeveloperName
- [ ] Deployment order documented and follows the Section 15 table
- [ ] Compact layouts defined for all custom objects
- [ ] Global Value Sets documented with list of dependent fields
- [ ] External IDs marked on integration key fields; `Unique` constraint applied
- [ ] `--dry-run` (check-only) deploy passed before actual deployment

---

## 18. Validation Commands

```bash
# Retrieve custom object metadata
sf project retrieve start \
  --metadata "CustomObject:SupportTicket__c" \
  --target-org <alias>

# Retrieve all custom objects
sf project retrieve start \
  --metadata "CustomObject" \
  --target-org <alias>

# Retrieve validation rules for an object
sf project retrieve start \
  --metadata "ValidationRule" \
  --target-org <alias>

# Retrieve CMDT object and records
sf project retrieve start \
  --metadata "CustomObject:CMDT_Integration__mdt" \
  --metadata "CustomMetadata" \
  --target-org <alias>

# Deploy check-only (validate before real deploy)
sf project deploy start \
  --source-dir force-app/main/default/objects \
  --dry-run \
  --target-org <alias>

# Deploy real
sf project deploy start \
  --source-dir force-app/main/default/objects \
  --target-org <alias>

# Query custom objects in org
sf data query \
  --query "SELECT QualifiedApiName, Label, Description FROM EntityDefinition WHERE IsCustomizable = true ORDER BY QualifiedApiName" \
  --target-org <alias>

# Query fields on an object
sf data query \
  --query "SELECT QualifiedApiName, Label, DataType, Description, InlineHelpText FROM FieldDefinition WHERE EntityDefinition.QualifiedApiName = 'Case' ORDER BY QualifiedApiName" \
  --target-org <alias>

# Query record types
sf data query \
  --query "SELECT Id, Name, DeveloperName, SobjectType, IsActive FROM RecordType ORDER BY SobjectType, DeveloperName" \
  --target-org <alias>

# Query validation rules
sf data query \
  --query "SELECT Id, ValidationName, Active, Description, EntityDefinition.QualifiedApiName FROM ValidationRule ORDER BY EntityDefinition.QualifiedApiName, ValidationName" \
  --target-org <alias>
```

---

## 19. Official References

- Salesforce Metadata API: [CustomObject](https://developer.salesforce.com/docs/atlas.en-us.api_meta.meta/api_meta/meta_customobject.htm)
- Salesforce Metadata API: [CustomField](https://developer.salesforce.com/docs/atlas.en-us.api_meta.meta/api_meta/meta_field_types.htm)
- Salesforce Help: [Record Types](https://help.salesforce.com/s/articleView?id=sf.customize_recordtype.htm)
- Salesforce Help: [Custom Metadata Types](https://help.salesforce.com/s/articleView?id=sf.custommetadatatypes_overview.htm)
- Salesforce Help: [Custom Settings](https://help.salesforce.com/s/articleView?id=sf.cs_about.htm)
- Salesforce Help: [Validation Rules](https://help.salesforce.com/s/articleView?id=sf.fields_about_field_validation.htm)
- Salesforce Help: [Global Value Sets](https://help.salesforce.com/s/articleView?id=sf.fields_global_picklists.htm)
- Salesforce Help: [External IDs](https://help.salesforce.com/s/articleView?id=sf.faq_import_general_what_is_an_external.htm)
- Salesforce Developer Docs: [Query and Search Optimization](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/langCon_apex_SOQL_VLSQ.htm)
- Salesforce Well-Architected: [Data Management](https://architect.salesforce.com/well-architected/adaptable/data)
- Trailhead: [Data Modeling](https://trailhead.salesforce.com/content/learn/modules/data_modeling)
