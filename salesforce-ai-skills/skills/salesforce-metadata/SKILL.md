---
name: salesforce-metadata
description: Production Salesforce AI skill for Objects/fields/record types/validation/CMDT changes.
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
- The task involves Objects/fields/record types/validation/CMDT changes.
- The user asks for implementation, refactor, troubleshooting, review, or best-practice validation in this area.
- The assistant must produce Salesforce-safe code/metadata with explicit security/testing notes.

## DO NOT TRIGGER when
- The task is unrelated to this component.
- Another specialized skill is the primary owner and this area is only incidental.
- The user asks for operational execution (deploy/publish/activate/destructive change) without explicit approval.

## Cross-skill routing
- Always read `../salesforce-global-development/SKILL.md`.
- Also read: Global Development + Permissions + Deployment + Flow.
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
Use consistent API naming suffixes (__c, __mdt). Prefer DeveloperName references; never hardcoded IDs. Use CMDT for deployable config, Custom Settings only when justified legacy/runtime needs.

## Upstream Salesforce Skill Patterns
- Custom object XML gets its API name from the filename; do not add a root `<fullName>` tag in `.object-meta.xml`.
- Custom objects require label, plural label, sharing model, deployment status, name field, visibility, and a meaningful description.
- Use `ReadWrite` sharing by default, but use `ControlledByParent` when a master-detail relationship exists on the object.
- Choose name fields intentionally: Text for human-named entities, AutoNumber for logs, requests, invoices, tickets, and other transactional records.
- Keep optional object features lean: enable search, reports, activities, and history only when the object is user-facing.
- Validation rule names do not end with `__c`; object and field API names do.
- Avoid reserved words and more than two master-detail relationships on a single custom object.

## Examples
### Good example patterns
1. Record type logic branches on DeveloperName.
2. Validation rule has user-friendly error and targeted condition.

### Bad examples / avoid
1. Using record type IDs in formulas/Apex.
2. Creating unrestricted picklist dependencies without impact analysis.

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

# Metadata Design Guidelines

**Version:** 3.0 (May 2026)
**Developer:** Naresh | Senior Salesforce Developer
**Purpose:** Authoritative reference for designing and deploying Salesforce schema metadata -- custom objects, custom fields, validation rules, custom metadata types, record types, and the surrounding access/integration concerns. Attach when creating or modifying any `.object-meta.xml`, `.field-meta.xml`, `.validationRule-meta.xml`, `.tab-meta.xml`, or CMDT bundle.

**Verified against:** [Salesforce Skills -- generating-custom-object](https://github.com/forcedotcom/sf-skills/tree/main/skills/generating-custom-object/SKILL.md) - [generating-custom-field](https://github.com/forcedotcom/sf-skills/tree/main/skills/generating-custom-field/SKILL.md) - [generating-validation-rule](https://github.com/forcedotcom/sf-skills/tree/main/skills/generating-validation-rule/SKILL.md) - [generating-custom-tab](https://github.com/forcedotcom/sf-skills/tree/main/skills/generating-custom-tab/SKILL.md) - [generating-custom-lightning-type](https://github.com/forcedotcom/sf-skills/tree/main/skills/generating-custom-lightning-type/SKILL.md) - [CustomObject Metadata API](https://developer.salesforce.com/docs/atlas.en-us.api_meta.meta/api_meta/meta_customobject.htm) - [CustomField Metadata API](https://developer.salesforce.com/docs/atlas.en-us.api_meta.meta/api_meta/customobject.htm) - [Custom Metadata Types Apex Reference](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_class_custom_metadata.htm). Last verified 2026-05-16.

---

## 1. Required Agent Output Contract

Before producing any metadata, emit:

1. **Inventory** -- list every object, field, validation rule, record type, CMDT, and tab being created or modified.
2. **Dependency order** -- match Section 13 deployment order). Each item must follow what it references.
3. **Naming review** -- confirm every API name follows Section 12 conventions; flag any reserved keyword collisions.
4. **Security classification** -- declare data sensitivity (PII / Internal / Public) for every new field; call out fields requiring FLS restriction.
5. **Deployment plan** -- full `sf project deploy start` command(s) with `--dry-run` first, then real deploy.

A change is not done until all five sections exist in the working doc.

---

## 2. Custom Objects

### File and naming

- File: `force-app/main/default/objects/<API_Name>/<API_Name>.object-meta.xml`.
- API Name (`fullName`) is **derived from the filename** -- never include a `<fullName>` tag at the object root.
- Convention: `<Domain>__c`, PascalCase. Examples: `SupportTicket__c`, `AppLog__c`, `IntegrationConfig__c`.

### Required elements

| Element | Requirement | Notes |
|---|---|---|
| `<label>` | Required | Singular UI name |
| `<pluralLabel>` | Required | Plural form (do not just append "s" blindly) |
| `<nameField>` | Required | Needs `<label>` and `<type>` |
| `<sharingModel>` | Required | See sharing rules below |
| `<deploymentStatus>` | Required | Always `Deployed` |
| `<visibility>` | Required | Always `Public` |
| `<description>` | Mandatory in this project | Team owner, purpose, OWD rationale, created date |

### Sharing model

Default: `ReadWrite`. Two hard rules:

1. If the object contains **any** Master-Detail field -> `<sharingModel>` MUST be `ControlledByParent`. Using `ReadWrite` here produces the error: `Cannot set sharingModel to ReadWrite on a CustomObject with a MasterDetail relationship field`.
2. If a Master-Detail field is later added to an existing child, the existing object's `<sharingModel>` must also be updated to `ControlledByParent` in the same deployment.

Other valid values: `Private`, `Read`. Use `Private` for sensitive data objects (PII, financial, audit). Document the OWD choice in `<description>`.

### Name field -- Text vs AutoNumber

| Type | When | Required extras |
|---|---|---|
| `Text` | Human-named entities (Projects, Locations, Teams) | None |
| `AutoNumber` | Transactions, logs, tickets, requests | `<displayFormat>` (must include `{0}`), `<startingNumber>` |

```xml
<nameField>
    <label>Ticket Number</label>
    <type>AutoNumber</type>
    <displayFormat>TKT-{0000000}</displayFormat>
    <startingNumber>1</startingNumber>
</nameField>
```

### Feature enablement (clean XML)

Only emit a flag when deviating from the platform default of `false`. Group by scenario:

- **User-facing objects** (apps, trackers, business entities): set `<enableSearch>`, `<enableReports>`, `<enableActivities>`, `<enableHistory>` to `true`.
- **System objects** (junctions, background logs, integration buffers): omit those flags -- keep the UI clean and the XML lean.

### Junction objects

For many-to-many: name by combining both parent entities. `Position_Candidate__c`, `Job_Application__c`. Two Master-Detail fields. Junction objects enable Roll-up Summaries on each parent.

### Relationship cap

- Max **2 Master-Detail** relationships per object. Third+ relationship must be Lookup.
- Max **15 Lookup** relationships per object (soft platform limit; review before adding more).

### Object XML -- canonical example

```xml
<?xml version="1.0" encoding="UTF-8"?>
<CustomObject xmlns="http://soap.sforce.com/2006/04/metadata">
    <description>Support Ticket. Owner: Support Eng. Created 2026-05. OWD Private -- agents see only assigned tickets.</description>
    <deploymentStatus>Deployed</deploymentStatus>
    <enableActivities>true</enableActivities>
    <enableHistory>true</enableHistory>
    <enableReports>true</enableReports>
    <enableSearch>true</enableSearch>
    <label>Support Ticket</label>
    <nameField>
        <label>Ticket Number</label>
        <type>AutoNumber</type>
        <displayFormat>TKT-{0000000}</displayFormat>
        <startingNumber>1</startingNumber>
    </nameField>
    <pluralLabel>Support Tickets</pluralLabel>
    <sharingModel>Private</sharingModel>
    <visibility>Public</visibility>
</CustomObject>
```

### Reserved API names -- never use

`Select`, `From`, `Where`, `Limit`, `Order`, `Group`, `User`, `External`, `View`, `Type`, `Date`, `Number`. Rename to `Status_Order__c`, `Record_Group__c`, etc.

---

## 3. Custom Fields

### File and naming

- File: `force-app/main/default/objects/<Object>/fields/<Field_API>.field-meta.xml`.
- API Name ends with `__c`. PascalCase with underscores for word breaks: `Resolution_Notes__c`, `Escalation_Reason__c`. Never use `Temp__c`, `New__c`, `Field1__c` -- the API name is permanent.
- Derive `<fullName>` from `<label>`: capitalize each word, replace spaces with `_`, append `__c`. `Total Contract Value` -> `Total_Contract_Value__c`.

### Universal mandatory attributes

| Attribute | Requirement |
|---|---|
| `<fullName>` | Required; ends in `__c`; starts with a letter |
| `<label>` | Required; Title Case |
| `<description>` | Mandatory -- state the business "why" |
| `<inlineHelpText>` | Mandatory -- actionable, user-facing; must add value beyond the label |

`inlineHelpText` good: `"Enter the value in USD including tax."` Bad: `"The amount."`

### Field data types

| Data | `<type>` | Required extras |
|---|---|---|
| Auto Number | `AutoNumber` | `displayFormat` (must include `{0}`), `startingNumber` |
| Checkbox | `Checkbox` | `defaultValue` (`false` unless required) |
| Currency | `Currency` | Defaults: `precision=18`, `scale=2` |
| Date | `Date` | No precision |
| Date/Time | `DateTime` | No precision |
| Email | `Email` | Built-in format validation |
| Geolocation | `Location` | `scale`, `displayLocationInDecimal` |
| Lookup | `Lookup` | `referenceTo`, `relationshipName`, `deleteConstraint` |
| Master-Detail | `MasterDetail` | `referenceTo`, `relationshipName`, `relationshipOrder` |
| Number | `Number` | `precision`, `scale` |
| Percent | `Percent` | Defaults: `precision=5`, `scale=2` |
| Phone | `Phone` | Auto-formats |
| Picklist | `Picklist` | `valueSet` + `valueSetDefinition` + `restricted` |
| Multi-select Picklist | `MultiselectPicklist` | `valueSet`, `visibleLines` (default 4) |
| Text | `Text` | `length` (max 255) |
| Text Area | `TextArea` | `<length>255</length>` -- fixed, required |
| Text (Long) | `LongTextArea` | `length` (max 131072), `visibleLines` (default 3) |
| Text (Rich) | `Html` | `length` (max 131072), `visibleLines` (default 25) |
| Time | `Time` | Time only, no date |
| URL | `Url` | Validates protocol |
| Formula | result type (`Number`, `Text`, etc.) | `formula` (CDATA), `formulaTreatBlanksAs` |
| Roll-Up Summary | `Summary` | See Section 3 4 |

### Numeric precision and scale

- `precision` = total digits; `scale` = decimal digits.
- Rule: `precision <= 18` AND `scale <= precision`.
- Digits left of decimal = `precision - scale`.

### Picklist `restricted`

Default: `<restricted>true</restricted>` unless user explicitly requests an open/unrestricted set. Restricted picklists are capped at 1,000 total values (active + inactive).

```xml
<valueSet>
    <restricted>true</restricted>
    <valueSetDefinition>
        <sorted>false</sorted>
        <value>
            <fullName>Option_A</fullName>
            <default>false</default>
            <label>Option A</label>
        </value>
    </valueSetDefinition>
</valueSet>
```

### 3.1 Master-Detail vs Lookup (critical)

Master-Detail and Lookup are NOT interchangeable. Three attributes are **forbidden** on Master-Detail; including any one produces a deployment error.

| Attribute | Master-Detail | Lookup |
|---|---|---|
| `<required>` | FORBIDDEN -- always required | Optional |
| `<deleteConstraint>` | FORBIDDEN -- always cascades | Required (`SetNull`, `Restrict`, `Cascade`) |
| `<lookupFilter>` | FORBIDDEN -- Lookup only | Optional |
| `<relationshipOrder>` | Required (`0` or `1`) | N/A |
| `<reparentableMasterDetail>` | Optional | N/A |
| `<writeRequiresMasterRead>` | Optional | N/A |

Master-Detail field -- correct form:

```xml
<CustomField xmlns="http://soap.sforce.com/2006/04/metadata">
    <fullName>Account__c</fullName>
    <label>Account</label>
    <description>Links this record to its parent Account.</description>
    <inlineHelpText>Select the Account this record belongs to.</inlineHelpText>
    <type>MasterDetail</type>
    <referenceTo>Account</referenceTo>
    <relationshipName>ChildRecords</relationshipName>
    <relationshipOrder>0</relationshipOrder>
    <reparentableMasterDetail>false</reparentableMasterDetail>
    <writeRequiresMasterRead>false</writeRequiresMasterRead>
</CustomField>
```

Lookup field -- same shape, but `<type>Lookup</type>`, no `relationshipOrder`, add `<required>false</required>` and `<deleteConstraint>SetNull|Restrict|Cascade</deleteConstraint>`.

- `relationshipName` must be plural PascalCase: `Travel_Bookings`, `ChildRecords`.
- `relationshipOrder` on Master-Detail: first M-D field on the object = `0`, second = `1`.

### 3.2 Roll-Up Summary fields

Highest deployment failure rate of any field type. Strict rules:

| Element | Requirement |
|---|---|
| `<type>` | Always `Summary` |
| `<summaryOperation>` | Required: `count`, `sum`, `min`, or `max` |
| `<summaryForeignKey>` | Required; format `ChildObject__c.MasterDetailField__c` |
| `<summarizedField>` | Required for `sum`/`min`/`max`; **omitted** for `count`; format `ChildObject__c.FieldToSummarize__c` |

**Forbidden on Roll-Up Summary:** `<precision>`, `<scale>`, `<required>`, `<length>` -- Summary inherits from the summarized field.

The child object must have a Master-Detail field pointing to the parent. Summary fields can only live on the parent.

```xml
<CustomField xmlns="http://soap.sforce.com/2006/04/metadata">
    <fullName>Total_Amount__c</fullName>
    <label>Total Amount</label>
    <description>Sum of all line item amounts.</description>
    <inlineHelpText>Automatically calculated from child line items.</inlineHelpText>
    <type>Summary</type>
    <summaryOperation>sum</summaryOperation>
    <summarizedField>Order_Line_Item__c.Amount__c</summarizedField>
    <summaryForeignKey>Order_Line_Item__c.Order__c</summaryForeignKey>
</CustomField>
```

For `count`, omit `<summarizedField>` entirely. `min` / `max` use the same shape as `sum`.

### 3.3 Formula fields

- `<type>` is the **result data type** (`Number`, `Text`, `Date`, etc.) -- NOT `Formula`. `<type>Formula</type>` is invalid.
- `<returnType>` does not exist in the Metadata API. Never use it.
- `<formula>` content MUST be wrapped in `<![CDATA[ ... ]]>` to protect operators like `&`, `<`, `>`.
- `<formulaTreatBlanksAs>` rule:
  - Numeric (`Number`, `Currency`, `Percent`) -> `BlankAsZero`
  - Text / `Date` / `DateTime` -> `BlankAsBlank`

```xml
<CustomField xmlns="http://soap.sforce.com/2006/04/metadata">
    <fullName>Calculated_Value__c</fullName>
    <label>Calculated Value</label>
    <description>Sum of Field1 and Field2.</description>
    <type>Number</type>
    <precision>18</precision>
    <scale>2</scale>
    <formula><![CDATA[Field1__c + Field2__c]]></formula>
    <formulaTreatBlanksAs>BlankAsZero</formulaTreatBlanksAs>
</CustomField>
```

Function rules (apply to validation rules too):

| Function | Rule |
|---|---|
| `TEXT()` | Never wrap a Text field. Remove the wrapper. |
| `VALUE()` | Only on Text. If the argument is a Number, drop `VALUE()`. |
| `DAY()`, `MONTH()`, `YEAR()` | Date only. For DateTime, convert: `DAY(DATEVALUE(DT__c))`. |
| `DATEVALUE()` | DateTime -> Date. If the argument is already Date, drop it. |
| `ISPICKVAL()` | MUST be used for picklist equality. Never `==` on a picklist. |
| `ISCHANGED()` | Use directly; don't compare against `PRIORVALUE()` manually. |
| `CASE()` | Last argument is the default. Total argument count must be even. |

Formulas that reference other custom fields require those fields deployed first.

### 3.4 External IDs

External IDs mark a field as an integration matching key. Used for `upsert`, data migration, deduplication.

- Set `<externalId>true</externalId>`. Applicable on Text, Number, Email.
- Max **3 External ID fields per object** -- choose deliberately.
- External ID fields are **automatically indexed**.
- Add `<unique>true</unique>` if the value must uniquely identify a record.
- `<caseSensitive>` defaults to `false`; set to `true` only if external system distinguishes case.

```xml
<fields>
    <fullName>Integration_External_ID__c</fullName>
    <label>Integration External ID</label>
    <description>External ID for CRM record matching. Populated by sync; do not modify.</description>
    <inlineHelpText>Auto-populated by the integration. Do not edit.</inlineHelpText>
    <type>Text</type>
    <length>255</length>
    <externalId>true</externalId>
    <unique>true</unique>
    <caseSensitive>false</caseSensitive>
</fields>
```

Upsert pattern in Apex: `Database.upsert(record, MyObj__c.Integration_External_ID__c, false);`

### 3.5 Required vs optional

- Mark a field `<required>true</required>` only if the business rule unconditionally demands a value.
- Context-dependent requirements (required when Status = Closed) -> use a **Validation Rule**, not field-level required.
- Never use `required` to "clean up data" -- fix data with a migration, not by blocking saves.

---

## 4. Validation Rules

### Naming and structure

- File: validation rules nest inside the object's `.object-meta.xml` as `<validationRules>` blocks, or as separate `.validationRule-meta.xml` files in `force-app/main/default/objects/<Object>/validationRules/`.
- `<fullName>` MUST NOT end in `__c`. Validation rules follow different naming than custom fields.
- Max 40 characters, alphanumeric + underscores, must begin with a letter, no trailing underscore, no consecutive underscores.
- Project convention: `VR_<ObjectApiName>_<Intent>`. Examples: `VR_Case_SubjectRequired`, `VR_Opportunity_CloseDateFuture`, `VR_SupportTicket_ResolutionOnClose`.

### Required components

Every rule MUST have:

1. **Descriptive name** following the convention.
2. **`<active>true</active>`** unless intentionally disabled.
3. **`<description>`** explaining what it validates and why.
4. **User-friendly `<errorMessage>`** (max 255 chars) -- never a technical code.
5. **Custom Permission bypass** -- never check by profile.

### Bypass pattern

Every validation rule in this org wraps its condition in `NOT($Permission.<CustomPermission>)` so trusted users (support leads, integration users, admins) can override. The Custom Permission must be deployed **before** the validation rule.

```
AND(
    ISBLANK(Subject),
    NOT($Permission.BypassCaseValidation)
)
```

### Error message guidelines

| Bad | Good |
|---|---|
| `"Validation failed"` | `"Case Subject is required. Please enter a brief description of the issue."` |
| `"Field missing"` | `"Resolution Notes are required when closing a case. Please document the resolution before changing Status to Closed."` |
| `"Invalid date"` | `"Close Date must be today or in the future. Please correct the Close Date."` |

### Validation rule XML

```xml
<?xml version="1.0" encoding="UTF-8"?>
<ValidationRule xmlns="http://soap.sforce.com/2006/04/metadata">
    <fullName>VR_Case_SubjectRequired</fullName>
    <active>true</active>
    <description>Blocks save when Subject is blank. Bypass: BypassCaseValidation. Owner: Support.</description>
    <errorConditionFormula><![CDATA[AND(ISBLANK(Subject), NOT($Permission.BypassCaseValidation))]]></errorConditionFormula>
    <errorDisplayField>Subject</errorDisplayField>
    <errorMessage>Subject is required. Please enter a brief summary of the issue before saving.</errorMessage>
</ValidationRule>
```

Any formula containing `<`, `>`, or `&` MUST be wrapped in `<![CDATA[...]]>`.

### "Update the formula" -- replace vs append

When instructed to modify an existing rule's formula, distinguish:

- **"Update the formula to X"** -> replace the existing logic entirely.
- **"Update the formula to also X"** -> keep the existing logic and append, usually by wrapping in `AND()` or `OR()`.

---

## 5. Custom Metadata Types (CMDT)

### Purpose

CMDT is the **default mechanism** for configuration data in modern Salesforce orgs:

- Deployable via `package.xml` (data ships with metadata).
- Readable in Apex, Flow, Validation Rules, and Formula fields with no DML governor consumption.
- Version-controlled in source-tracked projects.
- Available immediately in every sandbox and production after deployment.

### When to use CMDT

- Configuration values (thresholds, limits, feature flags).
- Integration endpoint URLs (NEVER secrets -- use Named Credentials).
- Picklist matrices (valid Status values per Record Type).
- Mapping tables (country -> region, error code -> user message).
- Record Type DeveloperName lookups.
- Bypass permission name registry.

### When NOT to use CMDT

- **Secrets/credentials** -> Named Credentials or an external vault.
- **User- or profile-level overrides** -> Custom Settings (Hierarchy).
- **Large datasets (thousands of records)** -> CMDT has per-org row limits; use a custom object.

### Naming

- Object: `CMDT_<Domain>__mdt`. Examples: `CMDT_Integration__mdt`, `CMDT_FeatureFlag__mdt`, `CMDT_RecordTypeConfig__mdt`.
- Record `DeveloperName`: stable, descriptive -- never temp names. The DeveloperName is permanent.

### Querying CMDT -- Apex methods, NOT SOQL

**Use the typed getter methods, not SOQL**, for transactional reads. The methods are governor-free; SOQL consumes the SOQL-query limit and is slower.

```apex
// Single record by DeveloperName -- fastest, governor-free
CMDT_Integration__mdt cfg = CMDT_Integration__mdt.getInstance('CRM_Integration');
if (cfg != null && cfg.Is_Active__c) {
    String endpoint = cfg.Endpoint_URL__c;
    Integer timeoutSec = (Integer) cfg.Timeout_Seconds__c;
}

// All records -- Map<DeveloperName, record>
Map<String, CMDT_Integration__mdt> all = CMDT_Integration__mdt.getAll();
for (CMDT_Integration__mdt c : all.values()) { /* ... */ }

// SOQL only for setup/admin tooling, NOT runtime hot paths
List<CMDT_Integration__mdt> active =
    [SELECT DeveloperName, Endpoint_URL__c FROM CMDT_Integration__mdt WHERE Is_Active__c = true];
```

Rule of thumb: code that runs on every record save / API call / page load -> `getInstance()` or `getAll()`. SOQL on CMDT is for admin pages, validation tooling, or one-off batch setup.

CMDT record file (at `customMetadata/CMDT_Integration.CRM_Integration.md-meta.xml`):

```xml
<?xml version="1.0" encoding="UTF-8"?>
<CustomMetadata xmlns="http://soap.sforce.com/2006/04/metadata" xsi:type="CustomMetadata">
    <label>CRM Integration</label>
    <protected>false</protected>
    <values><field>Endpoint_URL__c</field><value xsi:type="xsd:string">https://api.external-crm.com/v2</value></values>
    <values><field>Is_Active__c</field><value xsi:type="xsd:boolean">true</value></values>
    <values><field>Timeout_Seconds__c</field><value xsi:type="xsd:double">30</value></values>
</CustomMetadata>
```

### package.xml for CMDT

```xml
<types>
    <members>CMDT_Integration__mdt</members>
    <name>CustomObject</name>
</types>
<types>
    <members>CMDT_Integration.CRM_Integration</members>
    <name>CustomMetadata</name>
</types>
```

### CMDT vs Custom Settings

| Concern | Custom Settings | CMDT |
|---|---|---|
| Deployable via `package.xml` | No (data only) | Yes |
| Version-controlled with code | No | Yes |
| Accessible in Formula fields | No | Yes |
| Available in Validation Rules | No | Yes |
| User/Profile-level overrides | Yes (Hierarchy) | No |
| Recommended for new development | No | **Yes** |

Use Custom Settings only for hierarchy-level overrides (user/profile/org). Everything else is CMDT.

---

## 6. Record Types

### Rule: justify before creating

Create a Record Type only when there are **materially different business processes** needing one of:

- Different picklist values for the same field.
- Different page-layout / Dynamic Form field sets.
- Different validation rules or flows scoped to one type but not another.

**Do not create** Record Types for: display-only differences (icons, colors), small picklist variations (use dependent picklists), or segmentation that a custom field + filter handles.

Each additional Record Type multiplies maintenance -- more layouts, more permission set assignments, more automation gates. Document the justification in the Record Type description.

### Naming

| Component | Convention | Example |
|---|---|---|
| `DeveloperName` (API) | PascalCase, snake-OK | `Support_Case` |
| `Label` | Human-readable | `Support Case` |

`DeveloperName` is permanent once deployed.

### Referencing Record Types in code -- NEVER hardcode IDs

Record Type IDs differ between sandbox and production. Hardcoding an ID guarantees breakage on deployment.

```apex
// CORRECT -- resolved by DeveloperName at runtime
Id supportCaseRtId = Schema.SObjectType.Case
    .getRecordTypeInfosByDeveloperName()
    .get('Support_Case')
    .getRecordTypeId();

// CORRECT -- centralize via CMDT for cross-class references
CMDT_RecordTypeConfig__mdt cfg =
    CMDT_RecordTypeConfig__mdt.getInstance('Case_Support');
String devName = cfg.RecordTypeDeveloperName__c;

// WRONG -- never do this
Id rtId = '0125e000000abcDEF'; // breaks between orgs
```

For Flow: use the `$RecordType` global or the DeveloperName lookup via Get Records. Never paste an ID into a Decision element.

---

## 7. Custom Tabs

### File and structure

- File: `force-app/main/default/tabs/<Tab_Name>.tab-meta.xml`.
- Object tabs: the filename is the object API name (`Support_Ticket__c.tab-meta.xml`).
- Web/Visualforce tabs: descriptive filename (`Knowledge_Base.tab-meta.xml`).
- Root element is `<CustomTab>` (not `<Tab>`).

### Strict element allowlist

Only these elements are valid per tab type. Anything else fails deployment.

| Tab Type | Allowed elements only |
|---|---|
| Object | `<customObject>true</customObject>`, `<motif>`, optional `<description>` |
| Web | `<customObject>false</customObject>`, `<label>`, `<motif>`, `<url>`, `<urlEncodingKey>UTF-8</urlEncodingKey>`, optional `<description>`, `<frameHeight>` |
| Visualforce | `<customObject>false</customObject>`, `<label>`, `<motif>`, `<page>`, optional `<description>` |

### Forbidden -- guaranteed deployment errors

`<sobjectName>`, `<name>`, `<fullName>`, `<apiVersion>`, `<isHidden>`, `<tabVisibility>`, `<type>`, `<mobileReady>`, `<urlFrameHeight>`, `<urlType>`, `<urlRedirect>`, `<encodingKey>`, `<height>`, `<auraComponent>`. Also `<label>` on object tabs (object tabs inherit label from the object). Also empty elements (`<page></page>`).

### Motif -- must be unique per tab

`<motif>` is the icon style. Never reuse the same motif across every tab. Pick a motif whose name semantically matches the tab's purpose: `Custom39: Telescope` for an observatory object, `Custom98: Truck` for logistics, etc.

```xml
<?xml version="1.0" encoding="UTF-8"?>
<CustomTab xmlns="http://soap.sforce.com/2006/04/metadata">
    <customObject>true</customObject>
    <motif>Custom39: Telescope</motif>
</CustomTab>
```

---

## 8. Page Layouts -- Defer to Lightning App Builder

**For new work, prefer FlexiPages (Lightning Record Pages) with Dynamic Forms over Page Layouts.** Dynamic Forms let one page handle conditional visibility, removing the need for multiple page layouts per record type. See `../salesforce-flexipage/SKILL.md` for the authoring rules.

Page layouts are still required for:

- Related List ordering (until Dynamic Related Lists fully replaces them).
- Quick Action configuration.
- Standard button layout (when not using Dynamic Actions).
- Compact Layouts (mobile, related-list cards, activity feed cards).

### Compact layouts

Define a compact layout on every custom object that appears in mobile views, as a related-list card, or in activity highlights. Include: record name + 3-5 most relevant fields. Never leave the system default (Id + Name only).

### Naming (when page layouts are needed)

```
<ObjectLabel> <RecordTypeLabel> Layout
```

Example: `Case Support Case Layout`, `Account Partner Account Layout`.

---

## 9. Field-Level Security, CRUD, and Access

### Where access is granted

Access to custom objects and fields lives in **Permission Sets** (and Permission Set Groups), never on Profiles. See `../salesforce-permissions/SKILL.md` for the authoring rules. The metadata side concerns:

- Every new custom object MUST have a corresponding Permission Set granting CRUD (or be intentionally invisible to all but the System Admin profile).
- Every new custom field that holds business data MUST have FLS Read/Edit declared on the relevant Permission Sets in the same deployment wave.

### FLS-sensitive fields

Mark FLS Edit = false on Permission Sets when the field is:

- System-populated (integration external ID, audit timestamps, computed roll-up surrogates).
- Customer-confidential and only visible to specific roles (financial data, credit info, internal notes).
- Owned by a separate team (e.g., a Finance custom field on Case -- Support can read, only Finance can edit).

### Apex and FLS enforcement

In production code, query with `WITH USER_MODE` (preferred for modern Apex) or `WITH SECURITY_ENFORCED` to honor FLS at the runtime layer. The metadata-side responsibility is making sure the FLS settings on Permission Sets reflect the business intent -- Apex respects what metadata declares.

---

## 10. External IDs and Integration Indexing

See Section 3 4 for the field-level rules. Integration-design concerns:

- Choose **one** External ID per object as the canonical integration key. If you need multiple sources (e.g., NetSuite ID + Stripe customer ID), use multiple External ID fields but document which one is the "primary" matching key for the upsert pipeline.
- External ID values must be stable in the source system. If the source rotates IDs (e.g., on customer merge), the integration breaks silently -- design the upsert to handle re-keying.
- For composite keys (e.g., `external_system + external_id`), concatenate into a single Text(255) External ID field. Salesforce External IDs are single-field.

### Cross-org migration

External IDs are the foundation of org-to-org data migration. When seeding a new sandbox: export records with the External ID, import via `upsert`, and references resolve automatically. Without External IDs, every Lookup field must be re-mapped manually.

---

## 11. Indexes and Selectivity

### Auto-indexed fields (no action needed)

Salesforce automatically indexes:

- `Id`, `Name`, `OwnerId`, `CreatedDate`, `LastModifiedDate`, `SystemModstamp`.
- All Lookup and Master-Detail fields.
- All External ID fields.
- All `Unique` fields.

### Custom index requests

For high-volume custom fields that are frequently filtered on:

1. Confirm the field is used in `WHERE` clauses on frequently-run queries.
2. Confirm the object has > 100K records.
3. Confirm the filter is **selective** (returns < ~10% of total records).
4. File a case with Salesforce Technical Support requesting the custom index.

Before requesting an index, prove the selectivity case with EXPLAIN-plan analysis (`/services/data/vXX.0/query/?explain=`).

### Selectivity rule

A filter is selective if it returns < approximately **10% of total object records** (for objects with > 100K records). Non-selective filters cause full table scans even with an index present.

### Anti-patterns

```apex
// GOOD -- selective, indexed filters first
[SELECT Id FROM Case
 WHERE OwnerId = :uId AND Status = 'Open' AND CreatedDate = LAST_N_DAYS:7
 WITH USER_MODE LIMIT 50];

// BAD -- != is not selective on a large object
[SELECT Id FROM Case WHERE Status != 'Closed'];

// BAD -- leading wildcard disables index use
[SELECT Id FROM Case WHERE Subject LIKE '%error%'];
```

Use SOSL (`FIND ... IN ALL FIELDS`) for substring searches across text.

---

## 12. Naming Summary

| Metadata Type | Convention | Example |
|---|---|---|
| Custom Object | `<Domain>__c` PascalCase | `SupportTicket__c` |
| Custom Field | `<DescriptiveName>__c` PascalCase | `Resolution_Notes__c` |
| Master-Detail / Lookup `relationshipName` | Plural PascalCase | `Travel_Bookings`, `ChildRecords` |
| Roll-Up Summary | Describes the metric | `Total_Amount__c`, `Line_Item_Count__c` |
| External ID | `<System>_External_ID__c` | `NetSuite_External_ID__c` |
| Validation Rule | `VR_<Object>_<Intent>` -- no `__c` suffix | `VR_Case_SubjectRequired` |
| Custom Permission (bypass) | PascalCase, no prefix | `BypassCaseValidation` |
| Record Type DeveloperName | PascalCase / snake | `Support_Case` |
| Page Layout | `<Object> <RecordType> Layout` | `Case Support Case Layout` |
| Compact Layout | `<Object> Compact` | `Support Ticket Compact` |
| Custom Metadata Type | `CMDT_<Domain>__mdt` | `CMDT_Integration__mdt` |
| Custom Metadata Record | Stable DeveloperName | `CRM_Integration` |
| Custom Settings (legacy) | `CS_<Domain>__c` | `CS_FeatureFlags__c` |
| Global Value Set | `<Description>_Values` | `Region_Values` |
| Custom Tab | Filename = object API or descriptive | `Support_Ticket__c.tab-meta.xml` |
| Permission Set | `PS_<DomainOrRole>` | `PS_SupportAgent` |
| Permission Set Group | `PSG_<DomainOrRole>` | `PSG_SupportAgent` |
| Muting Permission Set | `MPS_<PSG>_<Intent>` | `MPS_SupportAgent_NoCaseDelete` |
| Apex Class | `<Domain><Type>` PascalCase | `CaseDashboardController` |
| Apex Test Class | `<ClassName>Test` | `CaseDashboardControllerTest` |
| LWC | camelCase | `caseTimelineComponent` |
| Flow | `<Object>_<Trigger>_<Action>` | `Case_AfterUpdate_NotifyOwner` |
| Email Template | `<Object>_<Intent>` | `Case_Support_Acknowledgement` |
| FlexiPage | `<Object>_Record_Page_<Variant>` | `Case_Record_Page_Support` |
| Trigger / Handler | `<Object>Trigger`, `<Object>TriggerHandler` | `CaseTrigger`, `CaseTriggerHandler` |

---

## 13. Deployment Order

Deploy metadata in this order. Each row depends on the rows above it. Group into deployment waves.

| # | Metadata | Notes |
|---|---|---|
| 1 | Custom Objects | Base before fields |
| 2 | Global Value Sets | Before picklists that reference them |
| 3 | Custom Fields | All fields on standard + custom objects |
| 4 | Record Types | After picklist fields exist |
| 5 | Compact Layouts | After fields |
| 6 | Page Layouts | After record types |
| 7 | Custom Permissions | Before validation rules and permission sets that reference them |
| 8 | Validation Rules | After Custom Permissions |
| 9 | CMDT object definitions | Before CMDT records |
| 10 | CMDT records | After object definitions |
| 11 | Apex Classes | After objects/fields they reference |
| 12 | Apex Triggers | After handler classes |
| 13 | Flows | After fields, objects, Apex used in flows |
| 14 | Email Templates | After Email Folders |
| 15 | Permission Sets | After objects, fields, Apex, Flows |
| 16 | Permission Set Groups | After component Permission Sets |
| 17 | FlexiPages | After LWCs and Flows |
| 18 | Custom Tabs | After object definitions |
| 19 | Assignment / Auto-Response Rules | After filter fields |

### Wave practice

1. Sort the change list by this table.
2. Group into 2-4 logical waves.
3. Run `--dry-run` on each wave.
4. Deploy real only after zero component errors.

---

## 14. Descriptions and Help Text -- Non-Negotiable

Every metadata component this project produces MUST have:

- **`<description>`** -- technical notes for developers/auditors: purpose, owner, integration dependencies, bypass mechanisms, created date.
- **`<inlineHelpText>`** (fields only) -- user-facing tooltip; actionable; written for the end user, not the developer.

Undocumented metadata is toxic debt. Auditors read descriptions first during compliance reviews. Treat them as official documentation.

| Layer | Audience | Example |
|---|---|---|
| Object `<description>` | Developer + auditor | `"Support Ticket. Owner: Support Eng. Created 2026-05. OWD Private -- agents see only assigned tickets."` |
| Field `<description>` | Developer | `"Populated by CRM Sync job. Do not modify manually. Bypass via BypassCaseValidation."` |
| Field `<inlineHelpText>` | End user | `"Enter a brief summary of the issue the customer is reporting. Appears in the customer-facing acknowledgement email."` |
| Validation Rule `<description>` | Developer + admin | `"Blocks save when Subject is blank. Bypass: BypassCaseValidation. Owner: Support."` |

---

## 15. Validation Commands

```bash
# Retrieve one custom object
sf project retrieve start --metadata "CustomObject:SupportTicket__c" --target-org PlusGradeFullSB

# Retrieve CMDT object + records
sf project retrieve start --metadata "CustomObject:CMDT_Integration__mdt" --metadata "CustomMetadata" --target-org PlusGradeFullSB

# Dry-run deploy -- REQUIRED before real deploy
sf project deploy start --source-dir force-app/main/default/objects --dry-run --target-org PlusGradeFullSB

# Real deploy
sf project deploy start --source-dir force-app/main/default/objects --target-org PlusGradeFullSB

# Inventory custom objects
sf data query --query "SELECT QualifiedApiName, Label, Description FROM EntityDefinition WHERE IsCustomizable = true ORDER BY QualifiedApiName" --target-org PlusGradeFullSB

# Inventory fields on Case
sf data query --query "SELECT QualifiedApiName, Label, DataType, Description, InlineHelpText FROM FieldDefinition WHERE EntityDefinition.QualifiedApiName = 'Case' ORDER BY QualifiedApiName" --target-org PlusGradeFullSB

# List record types / validation rules
sf data query --query "SELECT Id, Name, DeveloperName, SobjectType, IsActive FROM RecordType ORDER BY SobjectType, DeveloperName" --target-org PlusGradeFullSB
sf data query --query "SELECT Id, ValidationName, Active, Description, EntityDefinition.QualifiedApiName FROM ValidationRule ORDER BY EntityDefinition.QualifiedApiName, ValidationName" --target-org PlusGradeFullSB
```

---

## 16. Definition of Done

Metadata work is complete when all of the following hold:

- [ ] Every custom object has `<label>`, `<pluralLabel>`, `<description>` with owner + date + OWD rationale, explicit `<sharingModel>`, `<deploymentStatus>Deployed</deploymentStatus>`, `<visibility>Public</visibility>`.
- [ ] Every custom field has `<label>` (Title Case), `<description>` (technical), `<inlineHelpText>` (user-facing), correct `<type>`.
- [ ] Master-Detail fields contain NO `<required>`, `<deleteConstraint>`, or `<lookupFilter>`; parent object's `<sharingModel>` is `ControlledByParent` if it holds an M-D.
- [ ] Roll-Up Summary fields contain NO `<precision>`, `<scale>`, `<required>`, `<length>`; `<summaryForeignKey>` and `<summarizedField>` use `Object__c.Field__c` format.
- [ ] Formula fields use the **result data type** as `<type>` (not `Formula`); `<formula>` wrapped in `<![CDATA[]]>`; `<formulaTreatBlanksAs>` set correctly.
- [ ] All field API names are PascalCase, no temp/abbreviation names, no reserved keywords.
- [ ] Validation Rules named `VR_<Object>_<Intent>` (no `__c` suffix); include `<![CDATA[]]>` around the formula; include Custom Permission bypass; deploy AFTER the Custom Permission.
- [ ] CMDT used for new configuration data; Apex reads via `getInstance()` / `getAll().values()`, not SOQL, in hot paths; no credentials in CMDT.
- [ ] Record Types created only when business processes genuinely differ; no hardcoded Record Type IDs anywhere; references go through `getRecordTypeInfosByDeveloperName()` or CMDT.
- [ ] Custom Tabs follow the strict element allowlist; motif is contextually unique per tab.
- [ ] Compact layouts defined for every user-facing custom object.
- [ ] External ID fields marked on integration keys; `<unique>true</unique>` where the value identifies a record.
- [ ] FLS settings declared on Permission Sets in the same deployment wave as the new field; no relying on Profile-level FLS.
- [ ] Deployment order follows Section 13 each wave passed `--dry-run` with zero component errors before real deploy.
- [ ] Every metadata file has a meaningful `<description>` -- no exceptions.

---

## 17. Common AI Mistakes to Avoid

| Mistake | Why It's Wrong | Correct Approach |
|---|---|---|
| Hardcoding Record Type IDs | IDs differ between sandbox and production -- code breaks on deployment | Always use `getRecordTypeInfosByDeveloperName()` or CMDT |
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

## 18. Empirical Findings & Implementation Notes

When Salesforce's documented approach doesn't work in this org, the workaround goes here. Date-stamp every entry.

*(No entries yet -- append as encountered.)*

| # | Date | Documented approach | What actually works | Why / Context |
|---|---|---|---|---|

---

## 19. Official References

- Salesforce Metadata API: [CustomObject](https://developer.salesforce.com/docs/atlas.en-us.api_meta.meta/api_meta/meta_customobject.htm)
- Salesforce Metadata API: [CustomField -- field types](https://developer.salesforce.com/docs/atlas.en-us.api_meta.meta/api_meta/meta_field_types.htm)
- Salesforce Metadata API: [ValidationRule](https://developer.salesforce.com/docs/atlas.en-us.api_meta.meta/api_meta/meta_validationformulas.htm)
- Salesforce Metadata API: [CustomTab](https://developer.salesforce.com/docs/atlas.en-us.api_meta.meta/api_meta/meta_customtab.htm)
- Salesforce Help: [Record Types](https://help.salesforce.com/s/articleView?id=sf.customize_recordtype.htm)
- Salesforce Help: [Custom Metadata Types](https://help.salesforce.com/s/articleView?id=sf.custommetadatatypes_overview.htm)
- Salesforce Apex Reference: [Custom Metadata Types in Apex](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_class_custom_metadata.htm)
- Salesforce Help: [Custom Settings](https://help.salesforce.com/s/articleView?id=sf.cs_about.htm)
- Salesforce Help: [Validation Rules](https://help.salesforce.com/s/articleView?id=sf.fields_about_field_validation.htm)
- Salesforce Help: [Global Value Sets](https://help.salesforce.com/s/articleView?id=sf.fields_global_picklists.htm)
- Salesforce Help: [External IDs](https://help.salesforce.com/s/articleView?id=sf.faq_import_general_what_is_an_external.htm)
- Salesforce Developer Docs: [Query and Search Optimization](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/langCon_apex_SOQL_VLSQ.htm)
- Salesforce Well-Architected: [Data Management](https://architect.salesforce.com/well-architected/adaptable/data)
- forcedotcom/sf-skills: [generating-custom-object](https://github.com/forcedotcom/sf-skills/tree/main/skills/generating-custom-object) - [generating-custom-field](https://github.com/forcedotcom/sf-skills/tree/main/skills/generating-custom-field) - [generating-validation-rule](https://github.com/forcedotcom/sf-skills/tree/main/skills/generating-validation-rule) - [generating-custom-tab](https://github.com/forcedotcom/sf-skills/tree/main/skills/generating-custom-tab) - [generating-custom-lightning-type](https://github.com/forcedotcom/sf-skills/tree/main/skills/generating-custom-lightning-type)
- Cross-references in this skill library: `../salesforce-flexipage/SKILL.md` (Lightning Record Pages / Dynamic Forms), `../salesforce-permissions/SKILL.md` (FLS + CRUD), `../salesforce-integration/SKILL.md` (Named Credentials, callouts), `../salesforce-apex/SKILL.md` (CMDT access patterns, FLS-aware SOQL)

---

*Metadata Design Guidelines | v3.0 | Last verified 2026-05-16*

