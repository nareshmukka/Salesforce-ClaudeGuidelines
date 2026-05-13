# Permission Set & Access Control Guidelines

**Version**: 2.0 (April 2026)
**Developer**: Naresh | Senior Salesforce Developer
**Purpose**: Standalone guidelines for Salesforce access control using Permission Sets, Permission Set Groups, and Custom Permissions. Attach when designing, creating, or reviewing access control metadata.

---

## Table of Contents

1. [Required Agent Output Contract](#1-required-agent-output-contract)
2. [Permission Sets vs Profiles](#2-permission-sets-vs-profiles)
3. [Permission Set Naming](#3-permission-set-naming)
4. [Permission Set Groups (PSG)](#4-permission-set-groups-psg)
5. [Muting Permission Sets](#5-muting-permission-sets)
6. [Custom Permissions](#6-custom-permissions)
7. [Object Permissions](#7-object-permissions)
8. [Field Permissions](#8-field-permissions)
9. [Apex Class Access](#9-apex-class-access)
10. [Flow Access](#10-flow-access)
11. [Tab / App Access](#11-tab--app-access)
12. [Least Privilege Principle](#12-least-privilege-principle)
13. [Avoiding Profile Changes](#13-avoiding-profile-changes)
14. [Packaging / Deployment](#14-packaging--deployment)
15. [Complete Example](#15-complete-example)
16. [Common AI Mistakes to Avoid](#16-common-ai-mistakes-to-avoid)
17. [Definition of Done](#17-definition-of-done)
18. [Validation Commands](#18-validation-commands)
19. [Official References](#19-official-references)

---

## 1. Required Agent Output Contract

When generating, modifying, or reviewing any Permission Set or access control metadata, the AI agent MUST produce the following as part of its output:

### 1.1 Permissions Created / Modified

List every permission set, permission set group, muting permission set, or custom permission being created or changed. Format:

```
- PS_SupportAgent (new): Object permissions for Case, Contact; Apex class CaseDashboardController
- PS_ReadOnly (existing, modified): Adding Field Read on Case.Description__c
- Custom Permission: BypassCaseValidation (new)
```

### 1.2 Security Justification

For every permission grant, provide a one-line business justification. Example:

```
- Case: Create/Read/Edit — Support agents must log and update cases throughout their lifecycle.
- Contact: Read — Agents need to see account contact information when resolving cases.
- Delete Case: NOT GRANTED — Deletion is reserved for System Administrators only.
```

### 1.3 Least-Privilege Check

Explicitly confirm:
- [ ] No Modify All granted unless explicitly required and justified
- [ ] No View All granted unless explicitly required and justified
- [ ] Delete not granted unless the role requires destruction of records
- [ ] No System Administrator-equivalent permissions embedded in user-facing PS

### 1.4 Test Plan

Describe how the permission set will be tested:
- Assign to test user in sandbox
- Verify each granted permission is accessible in UI
- Verify non-granted permissions are inaccessible
- Run Apex tests under test user profile (use `System.runAs`)

### 1.5 Deployment Order

State the correct deployment sequence:
```
1. Custom Objects and Fields (if new)
2. Custom Permissions
3. Apex Classes
4. Flows
5. Permission Sets (component PS first)
6. Permission Set Groups (after all component PS exist)
7. Muting Permission Sets (after PSG exists)
```

---

## 2. Permission Sets vs Profiles

### Core Rule

**ALWAYS prefer Permission Sets over Profiles for granting permissions.**

Profiles define the minimum baseline:
- Login hours
- Login IP ranges
- Default record type assignments
- Password policy (where applicable)
- Page layout assignments (being replaced by Dynamic Forms)

Everything else belongs in Permission Sets.

### Rationale Table

| Concern | Profile | Permission Set |
|---|---|---|
| Maintainability | Hard — one profile per user type, grows unmanageable | Easy — compose PS like building blocks |
| Reusability | None — permissions locked to one profile | High — one PS can be added to any profile/user |
| Auditability | Hard to see what a profile grants | Each PS has clear, documented scope |
| Least Privilege | Hard — profiles tend to accumulate permissions | Easy — grant only what the PS is designed for |
| Deployment | Profile metadata is large, merge-conflict-prone | Smaller, focused metadata files |
| Future-proofing | Salesforce moving away from profiles | PS and PSG are the Salesforce-recommended path |

### Rules

- **NEVER add object, field, Apex, or Flow permissions to a Profile if they can be moved to a Permission Set.**
- If a permission is currently in a Profile and it can be extracted, plan migration to PS.
- Profiles may retain: default record type assignments, page layouts (legacy), login hours/IP ranges.
- When Salesforce completes profile deprecation, permissions will only be in Permission Sets. Design accordingly today.

---

## 3. Permission Set Naming

### Convention

```
PS_<DomainOrRole>
```

### Rules

- `PS_` prefix is mandatory — identifies the metadata type at a glance.
- `<DomainOrRole>` is PascalCase describing the functional role or access scope.
- No spaces. No underscores within the domain portion (use PascalCase to separate words).
- No temporary names like `PS_Temp`, `PS_Test`, `PS_New` — names must be stable for deployment.
- The API name (DeveloperName) is permanent. Label can be more descriptive.

### Examples

| API Name | Label | Purpose |
|---|---|---|
| `PS_SupportAgent` | Support Agent Permissions | Core permissions for Level 1 support agents |
| `PS_SupportAgentSenior` | Senior Support Agent Permissions | Additional delete/escalation permissions for senior agents |
| `PS_ReadOnlyDashboard` | Read-Only Dashboard Access | Read-only access to reporting objects |
| `PS_CaseViewer` | Case Viewer | Read access to Case and related objects |
| `PS_IntegrationUser` | Integration User Permissions | API-only permissions for integration service account |
| `PS_AdminUtility` | Admin Utility Access | Extended admin-adjacent permissions for power users |
| `PS_FinanceRead` | Finance Object Read Access | Read-only access to finance-domain custom objects |

---

## 4. Permission Set Groups (PSG)

### Purpose

A Permission Set Group (PSG) bundles multiple Permission Sets into a single assignable unit. Assign the PSG to users instead of individual Permission Sets. This simplifies user management and makes the access model readable.

### Naming Convention

```
PSG_<DomainOrRole>
```

### Rules

- `PSG_` prefix is mandatory.
- PascalCase for the domain/role portion.
- A PSG must have documentation listing its component Permission Sets.
- Never assign individual component PS directly to users if a PSG exists for that role — use the PSG.

### Example: Support Agent Role

```
PSG_SupportAgent
  ├── PS_SupportAgent         (core case management permissions)
  ├── PS_ReadOnly             (read access to reference data)
  └── PS_CaseViewer           (case queue and list view access)
```

### Example XML Structure

```xml
<?xml version="1.0" encoding="UTF-8"?>
<PermissionSetGroup xmlns="http://soap.sforce.com/2006/04/metadata">
    <description>Permission Set Group for Level 1 Support Agents. Composes core support, read-only, and case viewer permissions.</description>
    <label>Support Agent Group</label>
    <mutingPermissionSets>
        <!-- Add muting PS name here if needed -->
    </mutingPermissionSets>
    <permissionSets>
        <permissionSet>PS_SupportAgent</permissionSet>
        <permissionSet>PS_ReadOnly</permissionSet>
        <permissionSet>PS_CaseViewer</permissionSet>
    </permissionSets>
    <status>Updated</status>
</PermissionSetGroup>
```

### File Location

```
force-app/main/default/permissionSetGroups/PSG_SupportAgent.permissionSetGroup-meta.xml
```

---

## 5. Muting Permission Sets

### Purpose

A Muting Permission Set is used **within a Permission Set Group** to remove (mute) specific permissions that would otherwise be granted by one of the component Permission Sets. This allows fine-grained control without modifying the source Permission Set.

### Key Rules

- Muting PS can only be used inside a PSG — they cannot be assigned directly to users.
- Use muting to resolve conflicts where two component PS grant overlapping permissions and you need to revoke one.
- Name muting PS with a `MPS_` prefix for clarity.

### Naming Convention

```
MPS_<PSGName>_<Intent>
```

Example: `MPS_SupportAgent_NoCaseDelete`

### Use Case Example

Scenario: `PS_SupportAgent` grants Case: Read, Create, Edit, Delete. But the PSG `PSG_SupportAgentReadOnly` should only grant Read. Create a muting PS to remove Create, Edit, Delete.

```xml
<?xml version="1.0" encoding="UTF-8"?>
<MutingPermissionSet xmlns="http://soap.sforce.com/2006/04/metadata">
    <description>Mutes Case create, edit, delete for the read-only support agent group.</description>
    <label>Mute Case Write for Read-Only Group</label>
    <objectPermissions>
        <allowCreate>false</allowCreate>
        <allowDelete>false</allowDelete>
        <allowEdit>false</allowEdit>
        <allowRead>false</allowRead>
        <modifyAllRecords>false</modifyAllRecords>
        <object>Case</object>
        <viewAllRecords>false</viewAllRecords>
    </objectPermissions>
</MutingPermissionSet>
```

Then reference it in the PSG:

```xml
<mutingPermissionSets>
    <mutingPermissionSet>MPS_SupportAgent_NoCaseDelete</mutingPermissionSet>
</mutingPermissionSets>
```

---

## 6. Custom Permissions

### Purpose

Custom Permissions are used for:
1. **Feature gating** — enable/disable a feature for a subset of users without code changes.
2. **Bypass logic** — allow trusted users to bypass validation rules, flows, or triggers.
3. **Conditional UI** — show/hide components based on user's permissions.

### Core Rules

- **NEVER hardcode profile names in bypass logic.** Profiles change, are renamed, and the pattern is fragile.
- **ALWAYS use Custom Permissions** for bypass logic in validation rules and flows.
- Custom Permissions are granted via Permission Sets, not profiles.
- Name Custom Permissions descriptively in PascalCase.

### Metadata XML Example

```xml
<?xml version="1.0" encoding="UTF-8"?>
<CustomPermission xmlns="http://soap.sforce.com/2006/04/metadata">
    <description>Allows the user to bypass the Case subject required validation rule. Assign only to support leads and administrators.</description>
    <label>Bypass Case Validation</label>
</CustomPermission>
```

File: `force-app/main/default/customPermissions/BypassCaseValidation.customPermission-meta.xml`

### Using in a Validation Rule

```
AND(
  ISBLANK(Subject),
  NOT($Permission.BypassCaseValidation)
)
```

### Using in a Flow Decision

In a Flow Decision element, add a condition:
- Resource: `$Permission.BypassCaseValidation`
- Operator: `Equals`
- Value: `{!$GlobalConstant.False}`

This means: proceed with validation only if the user does NOT have the bypass permission.

### Granting Custom Permission in a Permission Set (XML)

```xml
<customPermissions>
    <enabled>true</enabled>
    <name>BypassCaseValidation</name>
</customPermissions>
```

---

## 7. Object Permissions

### Permission Matrix

| Permission | When to Grant |
|---|---|
| **Read** | User needs to view records of this object |
| **Create** | User needs to create new records |
| **Edit** | User needs to modify existing records |
| **Delete** | User needs to delete records — grant sparingly, document justification |
| **View All** | User needs to see all records regardless of sharing rules — admin/reporting only |
| **Modify All** | User needs full CRUD + share on all records regardless of sharing — system/admin use only |

### Least Privilege Rules for Objects

1. Start with no permissions.
2. Grant Read if the user's role requires viewing records.
3. Add Create only if the user's role requires creating records.
4. Add Edit only if the user's role requires modifying records.
5. Add Delete only with explicit justification — document who approved it.
6. View All and Modify All are elevated permissions — require architect/admin review and explicit sign-off.
7. **Never grant Modify All as a shortcut to avoid sharing rule complexity.** Fix the sharing model instead.

### XML Example

```xml
<objectPermissions>
    <allowCreate>true</allowCreate>
    <allowDelete>false</allowDelete>
    <allowEdit>true</allowEdit>
    <allowRead>true</allowRead>
    <modifyAllRecords>false</modifyAllRecords>
    <object>Case</object>
    <viewAllRecords>false</viewAllRecords>
</objectPermissions>
```

---

## 8. Field Permissions

### Rules

- Grant field access explicitly — do not rely on object-level permissions to expose all fields.
- Never grant more field access than the role requires.
- Hidden/sensitive fields (SSN, salary, PII) should have no read or edit permission in user-facing PS.
- FLS (Field Level Security) MUST be enforced in Apex regardless of what the UI shows. Apex code should use `WITH USER_MODE` or explicitly check `Schema.sObjectType.Object__c.fields.Field__c.isAccessible()`.
- Field permissions are additive across all assigned Permission Sets.

### Field Permission XML Example

```xml
<fieldPermissions>
    <editable>true</editable>
    <field>Case.Description</field>
    <readable>true</readable>
</fieldPermissions>
<fieldPermissions>
    <editable>false</editable>
    <field>Case.Internal_Notes__c</field>
    <readable>false</readable>
</fieldPermissions>
```

### FLS Enforcement in Apex

```apex
// Always check before rendering or DML
if (Schema.sObjectType.Case.fields.Internal_Notes__c.isAccessible()) {
    // render field
}

// Or use WITH USER_MODE in SOQL (Salesforce enforces FLS automatically)
List<Case> cases = [SELECT Id, Subject, Description FROM Case WHERE Id = :caseId WITH USER_MODE];

// Or use stripInaccessible before DML
SObjectAccessDecision decision = Security.stripInaccessible(
    AccessType.READABLE,
    [SELECT Id, Subject, Internal_Notes__c FROM Case WHERE Id = :caseId]
);
List<Case> safeCases = decision.getRecords();
```

---

## 9. Apex Class Access

### Rule

Any Apex class called from a Lightning Web Component, Visualforce page, or public API requires explicit access granted in the Permission Set. Without this, the class call will throw an insufficient privileges error for non-admin users.

### When Required

- Classes called via `@AuraEnabled` methods from LWC
- Classes called via REST API
- Classes invoked from Flows (invocable methods) — these typically inherit running user context
- Test classes do NOT need to be in PS

### XML Example

```xml
<classAccesses>
    <apexClass>CaseDashboardController</apexClass>
    <enabled>true</enabled>
</classAccesses>
<classAccesses>
    <apexClass>CaseEscalationService</apexClass>
    <enabled>true</enabled>
</classAccesses>
```

### Deployment Note

Apex classes must exist in the org before the Permission Set referencing them is deployed.

---

## 10. Flow Access

### Rule

Screen Flows that are launched directly by users (from Quick Actions, App Builder buttons, or utility bars) require explicit permission to run, either through a Permission Set or Profile.

Autolaunched Flows (Record-Triggered, Scheduled) do not require user-level flow access.

### XML Example

```xml
<flowAccesses>
    <enabled>true</enabled>
    <flow>Case_Escalation_Screen_Flow</flow>
</flowAccesses>
```

### Deployment Note

The Flow must be active and deployed before the Permission Set is deployed. A PS referencing a non-existent or inactive flow may cause deployment issues.

---

## 11. Tab / App Access

### Rules

- Tab and App visibility are separate concerns from object permissions. A user can have object read access without seeing the tab, and vice versa.
- Grant tab access only to roles whose workflow involves navigating to that tab.
- App access controls which Lightning Apps appear in the App Launcher.
- Avoid giving all users access to all apps — this creates a confusing App Launcher experience.

### XML Example

```xml
<tabSettings>
    <tab>Case</tab>
    <visibility>Available</visibility>
</tabSettings>
<tabSettings>
    <tab>standard-report</tab>
    <visibility>Available</visibility>
</tabSettings>
<applicationVisibilities>
    <application>standard__ServiceConsole</application>
    <default>false</default>
    <visible>true</visible>
</applicationVisibilities>
```

### Tab Visibility Values

| Value | Meaning |
|---|---|
| `Hidden` | Tab not visible to user |
| `Available` | Tab available but not default; user can pin it |
| `DefaultOn` | Tab visible and pinned by default |

---

## 12. Least Privilege Principle

### Checklist

- [ ] Start with no permissions. Add only what the role explicitly requires.
- [ ] Document each permission grant with a business justification before merging.
- [ ] Review all Permission Sets quarterly — remove grants that are no longer required.
- [ ] Never grant Delete, View All, or Modify All as a convenience. These require escalated approval.
- [ ] Never grant permissions to unblock a developer — use a temporary test PS and remove after testing.
- [ ] Do not copy an existing PS and modify it without reviewing what the source PS grants.
- [ ] Sensitive objects (Financial, PII, HR data) require documented approval before any PS grants access.
- [ ] Custom Permissions used as bypass flags must be documented in a registry (e.g., a Custom Metadata record listing all bypass permissions and their justification).

### Quarterly Review Process

1. Pull list of all users and their assigned PS/PSG.
2. Compare against current role definitions.
3. Flag users who have PS assignments beyond their current role.
4. Remove excess permissions after manager confirmation.
5. Document the review date in the PS description field.

---

## 13. Avoiding Profile Changes

### Rule

If a task requires adding or modifying permissions and you are asked to edit a Profile, **STOP**. Instead:
1. Create a new Permission Set (or update an existing one) with the required permissions.
2. Assign the Permission Set to the users or to the Permission Set Group for that role.
3. Document why a Profile was not used.

### Documented Exceptions

The only acceptable reasons to modify a Profile:
- Changing login hours or IP restrictions (these cannot go in PS)
- Changing the default record type assignment (until full PS migration is available)
- Emergency hotfix where no PS exists and deployment is time-critical — must be followed by PS migration within one sprint

### When Asked to Edit a Profile

Respond:
> "Per our access control guidelines, permissions are managed via Permission Sets, not Profiles. I will create/update the relevant Permission Set instead. If you need to change login hours or IP ranges, I will update the Profile only for that specific setting."

---

## 14. Packaging / Deployment

### Deployment Rules

1. **Objects and Fields FIRST** — a PS referencing an object/field that doesn't exist will fail deployment.
2. **Custom Permissions** — deploy before Permission Sets that reference them.
3. **Apex Classes** — deploy before PS that grant Apex access.
4. **Flows** — activate before PS that grant Flow access.
5. **Component Permission Sets** — deploy before the PSG that composes them.
6. **Muting Permission Sets** — deploy before the PSG that references them.
7. **Permission Set Groups** — deploy last in the access control chain.

### Naming Stability

- API names (DeveloperName) are permanent — they cannot be changed after deployment without destructive metadata changes.
- Never use temporary or sequential names like `PS_V2`, `PS_New`, `PS_Temp`.
- Plan the name before first deployment.

### package.xml Examples

```xml
<!-- Permission Sets -->
<types>
    <members>PS_SupportAgent</members>
    <members>PS_ReadOnly</members>
    <members>PS_CaseViewer</members>
    <name>PermissionSet</name>
</types>

<!-- Permission Set Groups -->
<types>
    <members>PSG_SupportAgent</members>
    <name>PermissionSetGroup</name>
</types>

<!-- Muting Permission Sets -->
<types>
    <members>MPS_SupportAgent_NoCaseDelete</members>
    <name>MutingPermissionSet</name>
</types>

<!-- Custom Permissions -->
<types>
    <members>BypassCaseValidation</members>
    <name>CustomPermission</name>
</types>
```

---

## 15. Complete Example

### PS_SupportAgent — Full Permission Set XML

```xml
<?xml version="1.0" encoding="UTF-8"?>
<PermissionSet xmlns="http://soap.sforce.com/2006/04/metadata">
    <description>
        Core permissions for Level 1 Support Agents.
        Grants Case CRUD (no delete), Contact Read, AppLog__c Create,
        CaseDashboardController Apex access, and BypassCaseValidation custom permission.
        Owner: Support Team. Last reviewed: April 2026.
    </description>
    <hasActivationRequired>false</hasActivationRequired>
    <label>Support Agent Permissions</label>
    <license>Salesforce</license>

    <!-- Object Permissions -->
    <objectPermissions>
        <allowCreate>true</allowCreate>
        <allowDelete>false</allowDelete>
        <allowEdit>true</allowEdit>
        <allowRead>true</allowRead>
        <modifyAllRecords>false</modifyAllRecords>
        <object>Case</object>
        <viewAllRecords>false</viewAllRecords>
    </objectPermissions>

    <objectPermissions>
        <allowCreate>false</allowCreate>
        <allowDelete>false</allowDelete>
        <allowEdit>false</allowEdit>
        <allowRead>true</allowRead>
        <modifyAllRecords>false</modifyAllRecords>
        <object>Contact</object>
        <viewAllRecords>false</viewAllRecords>
    </objectPermissions>

    <objectPermissions>
        <allowCreate>true</allowCreate>
        <allowDelete>false</allowDelete>
        <allowEdit>false</allowEdit>
        <allowRead>true</allowRead>
        <modifyAllRecords>false</modifyAllRecords>
        <object>AppLog__c</object>
        <viewAllRecords>false</viewAllRecords>
    </objectPermissions>

    <!-- Field Permissions: Case -->
    <fieldPermissions>
        <editable>true</editable>
        <field>Case.Subject</field>
        <readable>true</readable>
    </fieldPermissions>
    <fieldPermissions>
        <editable>true</editable>
        <field>Case.Description</field>
        <readable>true</readable>
    </fieldPermissions>
    <fieldPermissions>
        <editable>true</editable>
        <field>Case.Status</field>
        <readable>true</readable>
    </fieldPermissions>
    <fieldPermissions>
        <editable>false</editable>
        <field>Case.Internal_Notes__c</field>
        <readable>false</readable>
    </fieldPermissions>

    <!-- Field Permissions: Contact -->
    <fieldPermissions>
        <editable>false</editable>
        <field>Contact.FirstName</field>
        <readable>true</readable>
    </fieldPermissions>
    <fieldPermissions>
        <editable>false</editable>
        <field>Contact.LastName</field>
        <readable>true</readable>
    </fieldPermissions>
    <fieldPermissions>
        <editable>false</editable>
        <field>Contact.Email</field>
        <readable>true</readable>
    </fieldPermissions>

    <!-- Apex Class Access -->
    <classAccesses>
        <apexClass>CaseDashboardController</apexClass>
        <enabled>true</enabled>
    </classAccesses>

    <!-- Custom Permission -->
    <customPermissions>
        <enabled>true</enabled>
        <name>BypassCaseValidation</name>
    </customPermissions>

    <!-- Tab Visibility -->
    <tabSettings>
        <tab>Case</tab>
        <visibility>Available</visibility>
    </tabSettings>

    <!-- App Visibility -->
    <applicationVisibilities>
        <application>standard__ServiceConsole</application>
        <default>false</default>
        <visible>true</visible>
    </applicationVisibilities>
</PermissionSet>
```

File: `force-app/main/default/permissionSets/PS_SupportAgent.permissionSet-meta.xml`

---

## 16. Common AI Mistakes to Avoid

| Mistake | Why It's Wrong | Correct Approach |
|---|---|---|
| Adding object/field permissions to a Profile | Profiles should only define baseline; permissions go in PS | Create or update a Permission Set |
| Granting Modify All as a shortcut | Over-privilege; bypasses sharing rules entirely | Fix the sharing model; grant View All only if needed with justification |
| No Custom Permission for bypass logic | Hardcoded profile checks break when profiles change | Use `$Permission.CustomPermissionName` in validation rules/flows |
| Deploying PS before the objects they reference | Deployment failure | Deploy objects/fields first, then PS |
| Inconsistent naming (e.g., `PS_support_agent`, `PermSetSupportAgent`) | Non-standard; hard to identify and manage | Always use `PS_PascalCase` convention |
| Granting Delete to all users by default | Over-privilege; data loss risk | Explicitly justify Delete; default to no Delete |
| Using temporary PS names (`PS_Temp`, `PS_V2`) | API name cannot change; will cause naming debt | Plan stable names before first deployment |
| Creating one giant PS for all permissions | Impossible to reuse or compose | Break into domain-scoped PS; compose with PSG |
| Assigning individual PS when a PSG exists | Creates assignment inconsistency | Always assign the PSG for role-based access |

---

## 17. Definition of Done

A Permission Set (or PSG) is considered complete and deployable when ALL of the following are true:

- [ ] API name follows `PS_<Domain>` convention and is stable (no temp names)
- [ ] Label and description are set; description includes owner, purpose, and last review date
- [ ] Every permission grant has a documented business justification
- [ ] Least privilege check passed: no Modify All, no unnecessary Delete, no View All without approval
- [ ] Custom Permissions used for any bypass logic (no hardcoded profile names anywhere)
- [ ] PSG composition is documented: which component PS are included and why
- [ ] Muting PS defined where component PS over-grant for a specific PSG
- [ ] Deployed after all dependency metadata (objects, fields, Apex, Flows) is in the org
- [ ] Tested in sandbox: test user assigned to PS/PSG, all granted permissions verified accessible, all withheld permissions verified inaccessible
- [ ] Quarterly review date documented in PS description

---

## 18. Validation Commands

### Deploy and Validate

```bash
# Deploy permission sets (check-only first)
sf project deploy start \
  --source-dir force-app/main/default/permissionSets \
  --dry-run \
  --target-org <alias>

# Deploy for real
sf project deploy start \
  --source-dir force-app/main/default/permissionSets \
  --target-org <alias>

# Deploy permission set groups
sf project deploy start \
  --source-dir force-app/main/default/permissionSetGroups \
  --target-org <alias>

# Deploy custom permissions
sf project deploy start \
  --source-dir force-app/main/default/customPermissions \
  --target-org <alias>
```

### Retrieve Existing Metadata

```bash
# Retrieve all permission sets
sf project retrieve start \
  --metadata "PermissionSet" \
  --target-org <alias>

# Retrieve a specific PS
sf project retrieve start \
  --metadata "PermissionSet:PS_SupportAgent" \
  --target-org <alias>
```

### Verify Permission Assignment via SOQL

```bash
# Check which users have a specific PS assigned
sf data query \
  --query "SELECT AssigneeId, Assignee.Name, PermissionSet.Name FROM PermissionSetAssignment WHERE PermissionSet.Name = 'PS_SupportAgent'" \
  --target-org <alias>

# Check which PS a specific user has
sf data query \
  --query "SELECT PermissionSet.Name, PermissionSet.Label FROM PermissionSetAssignment WHERE Assignee.Username = 'testuser@example.com'" \
  --target-org <alias>

# Verify a custom permission is enabled in a PS
sf data query \
  --query "SELECT Id, SetupEntityId FROM SetupEntityAccess WHERE SetupEntityType = 'CustomPermission' AND ParentId IN (SELECT Id FROM PermissionSet WHERE Name = 'PS_SupportAgent')" \
  --target-org <alias>
```

---

## 19. Official References

- Salesforce Help: [Permission Sets](https://help.salesforce.com/s/articleView?id=sf.perm_sets_overview.htm)
- Salesforce Help: [Permission Set Groups](https://help.salesforce.com/s/articleView?id=sf.perm_set_groups.htm)
- Salesforce Help: [Muting Permission Sets](https://help.salesforce.com/s/articleView?id=sf.perm_set_groups_muting.htm)
- Salesforce Help: [Custom Permissions](https://help.salesforce.com/s/articleView?id=sf.custom_perms_overview.htm)
- Salesforce Metadata API: [PermissionSet](https://developer.salesforce.com/docs/atlas.en-us.api_meta.meta/api_meta/meta_permissionset.htm)
- Salesforce Security Guide: [Field-Level Security](https://help.salesforce.com/s/articleView?id=sf.admin_fls.htm)
- Trailhead: [Data Security](https://trailhead.salesforce.com/content/learn/modules/data_security)
- Salesforce Well-Architected: [Security](https://architect.salesforce.com/well-architected/trusted/security)
