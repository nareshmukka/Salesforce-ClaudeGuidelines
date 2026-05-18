# Permission Set & Access Control Guidelines

Authoritative grammar for `PermissionSet`, `PermissionSetGroup`, `MutingPermissionSet`, and `CustomPermission` metadata in this project. Other skill files reference this one for any access-control concern.

**Verified against:** [PermissionSet Metadata API](https://developer.salesforce.com/docs/atlas.en-us.api_meta.meta/api_meta/meta_permissionset.htm) · [Permission Set Groups Help](https://help.salesforce.com/s/articleView?id=sf.perm_sets_groups_overview.htm) · [Muting Permission Sets Help](https://help.salesforce.com/s/articleView?id=sf.perm_set_groups_muting.htm) · [Custom Permissions Help](https://help.salesforce.com/s/articleView?id=sf.custom_perms_overview.htm) · [forcedotcom/sf-skills `generating-permission-set`](https://github.com/forcedotcom/sf-skills/tree/main/skills/generating-permission-set). Last verified 2026-05-16.

> **Salesforce roadmap reminder:** profiles will continue to shrink. Treat profiles as identity defaults (login hours, IP ranges, default record type). All permissions belong in Permission Sets. Build for the perm-set-only future today.

---

## 1. File Layout

```
force-app/main/default/
   permissionSets/<DevName>.permissionSet-meta.xml
   permissionSetGroups/<DevName>.permissionSetGroup-meta.xml
   mutingPermissionSets/<DevName>.mutingPermissionSet-meta.xml
   customPermissions/<DevName>.customPermission-meta.xml
```

`<DevName>` (DeveloperName / API name) is permanent after first deploy. Rename = delete + recreate = lost assignments. Choose stable names before the first deploy.

---

## 2. Permission Sets vs Profiles — The Layering Model

```
Profile (baseline / identity — login hours, IP ranges, default RT, password policy)
   +
Permission Sets (capability layers — Object/Field/Apex/Flow/Tab/App/CustomPerm)
   +
Permission Set Group (role bundle = N component PS − Muting PS)
```

| Concern | Profile | Permission Set |
|---|---|---|
| Login hours, IP ranges, password policy | YES (only place) | NO |
| Default record type | YES (legacy) | Roadmap → PS |
| Object/Field/Apex/Flow/Tab/App/CustomPerm | NO | YES — always |
| Reusable, composable, low-conflict deploys | NO | YES |

**The rule:** if you are about to edit a Profile XML for anything other than login hours, IP ranges, or default record type, **STOP** and move it to a Permission Set.

---

## 3. Naming Conventions

| Metadata | Prefix | Example | Notes |
|---|---|---|---|
| Permission Set | `PS_` | `PS_SupportAgent`, `PS_Object_RW_Case`, `PS_Apex_CaseDashboard` | PascalCase domain/role |
| Permission Set Group | `PSG_` | `PSG_SupportAgent`, `PSG_FinanceReadOnly` | One PSG per business role |
| Muting Permission Set | `MPS_` | `MPS_SupportAgent_NoDelete` | Pattern: `MPS_<PSG>_<Intent>` |
| Custom Permission | none, PascalCase | `BypassCaseValidation`, `ViewInternalNotes` | Verb-style intent name |

**Naming hard rules**
- API names (`fullName`) are permanent. Never use `PS_Temp`, `PS_New`, `PS_V2`.
- No spaces, no hyphens. PascalCase only for the domain portion.
- One Permission Set, one purpose. If you cannot describe the PS in a single sentence, split it.

---

## 4. `PermissionSet` XML Reference

### 4.1 Top-level elements

| Element | Type | Required | Purpose |
|---|---|---|---|
| `label` | string | YES | UI display name |
| `description` | string | strongly recommended | Owner, purpose, last review date |
| `license` | string | optional | `Salesforce`, `Salesforce Platform`, `AnalyticsCloudIntegrationUser`, etc. Omit unless required — license-scoped PS cannot be assigned to users on a different license |
| `hasActivationRequired` | boolean | optional | `true` = session-activated PS (user must activate to use) |

### 4.2 `<applicationVisibilities>` — Lightning Apps

```xml
<applicationVisibilities>
   <application>standard__ServiceConsole</application>
   <default>false</default>
   <visible>true</visible>
</applicationVisibilities>
```

- `application` — app API name. Standard apps use `standard__` prefix.
- `default` — sets this app as the user's default (rarely true).
- `visible` — gates App Launcher visibility.

### 4.3 `<classAccesses>` — Apex Class Permission

```xml
<classAccesses>
   <apexClass>CaseDashboardController</apexClass>
   <enabled>true</enabled>
</classAccesses>
```

Required for `@AuraEnabled` (LWC/Aura), `@RestResource`, Visualforce controllers, Connected App callers. Not required for test classes, trigger handlers, or `@InvocableMethod` called from autolaunched Flows in system context.

**Planner permission-check trap (Agentforce):** when a planner action targets `apex://X`, the running user must have `classAccesses` for `X`. **A single missing class permission causes the entire planner action surface to silently degrade** — the agent hallucinates instead of calling the action. When an Agentforce agent's actions are flaky, check `classAccesses` on `<AgentName>_Access` PS first.

### 4.4 `<flowAccesses>` — Flow Run Permission

```xml
<flowAccesses>
   <enabled>true</enabled>
   <flow>Case_Escalation_Screen_Flow</flow>
</flowAccesses>
```

Required for Screen Flows launched from buttons, quick actions, utility bars, App Pages, Experience pages. NOT required for Record-Triggered, Scheduled, or Autolaunched-from-Apex Flows. The Flow must be deployed (need not be Active) before the PS.

### 4.5 `<objectPermissions>` — CRUD per Object

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

All six boolean children are **required** when the block is present. `viewAllRecords` / `modifyAllRecords` bypass sharing — admin only, require justification. Avoid `viewAllFields`; use explicit `<fieldPermissions>`.

### 4.6 `<fieldPermissions>` — Field Level Security

```xml
<fieldPermissions>
   <editable>true</editable>
   <field>Case.Description</field>
   <readable>true</readable>
</fieldPermissions>
```

**Deployment-failing constraints**
- **Required fields MUST NOT appear in `<fieldPermissions>`.** A field is required when its metadata has `<required>true</required>`. Granting FLS on required fields fails deployment with no remediation other than removing the entry.
- **Master-detail fields are always required on the child** — omit them.
- **Formula fields cannot be `editable: true`** — formulas are read-only by definition.
- **Standard required fields** (`Account.Name`, `Contact.LastName`, `Case.Status`, etc.) — omit from FLS.
- Use `Object.Field` format. For custom fields: `Object__c.Field__c`.
- Setting `editable: true` implies `readable: true`. You still must declare both.

### 4.7 `<recordTypeVisibilities>` — Record Type Access

```xml
<recordTypeVisibilities>
   <recordType>Case.Internal_Support</recordType>
   <visible>true</visible>
   <default>false</default>
</recordTypeVisibilities>
```

- Format: `Object.RecordTypeDeveloperName`.
- `default` rarely belongs in a Permission Set — default record type usually stays on the Profile during the transition period.

### 4.8 `<tabSettings>` — Tab Visibility

```xml
<tabSettings>
   <tab>Case</tab>
   <visibility>Available</visibility>
</tabSettings>
```

**Tab naming rules (deployment-failing if wrong)**
- **Custom object tabs:** include `__c` — `MyObject__c`
- **Standard object tabs:** `standard-` prefix — `standard-Account`, `standard-Contact`, `standard-Report`
- **Visualforce tabs:** the tab API name (no prefix)
- **Web tabs / custom tabs:** the tab API name as defined

| `<visibility>` value | Behavior |
|---|---|
| `Visible` | Tab is in the app navigation and on All Tabs. User can re-pin. |
| `Available` | Tab is on All Tabs but not in the default app nav. User can add it. |
| `Hidden` / `None` | Not visible anywhere |

Note: older metadata used `DefaultOn` / `DefaultOff` / `Hidden`. Modern API uses `Visible` / `Available` / `None`. Both compile but stick to one form.

### 4.9 `<userPermissions>` — System Permissions

```xml
<userPermissions>
   <enabled>true</enabled>
   <name>ApiEnabled</name>
</userPermissions>
```

| Tier | Permissions | Notes |
|---|---|---|
| Safe | `ApiEnabled`, `RunReports`, `ManageReports`, `ViewSetup`, `ExportReport` | Grant as scope requires |
| Elevated — require architect sign-off | `ViewAllData`, `ModifyAllData`, `ManageUsers`, `AuthorApex`, `CustomizeApplication`, `ManageRoles`, `ManageSharing`, `ViewEncryptedData` | Auto QA fail if granted in user-facing PS without justification |

### 4.10 `<customPermissions>` — Grant a Custom Permission

```xml
<customPermissions>
   <enabled>true</enabled>
   <name>BypassCaseValidation</name>
</customPermissions>
```

### 4.11 `<pageAccesses>` — Visualforce Pages

```xml
<pageAccesses>
   <apexPage>CaseSnapshotPage</apexPage>
   <enabled>true</enabled>
</pageAccesses>
```

### 4.12 Other access blocks

```xml
<customMetadataTypeAccesses><enabled>true</enabled><name>FeatureFlag__mdt</name></customMetadataTypeAccesses>
<customSettingAccesses><enabled>true</enabled><name>BypassSettings__c</name></customSettingAccesses>
<externalDataSourceAccesses><enabled>true</enabled><externalDataSource>HubuREST</externalDataSource></externalDataSourceAccesses>
```

### 4.13 `<agentAccesses>` — Agentforce Employee Agent Access

```xml
<agentAccesses>
   <agentName>Sales_Assistant_Agent</agentName>
   <enabled>true</enabled>
</agentAccesses>
```

- Required to let a user invoke an `AgentforceEmployeeAgent`.
- `agentName` must exactly match the agent's `developer_name` (case-sensitive, see [agentforce-agent-script-reference.md](agentforce-agent-script-reference.md) §5).
- Service Agents (`AgentforceServiceAgent`) use a different access path — the system PS `AgentforceServiceAgentUser` plus channel routing. See §6 below.

---

## 5. Permission Set Groups (PSG)

### 5.1 What a PSG is

A PSG bundles N component PS into one assignable unit. Effective permissions = union(component PS) − muting PS. Salesforce caches the result and recalculates on status change. Assign the PSG to users; never assign components directly when a PSG exists for that role.

### 5.2 XML

```xml
<?xml version="1.0" encoding="UTF-8"?>
<PermissionSetGroup xmlns="http://soap.sforce.com/2006/04/metadata">
   <label>Support Agent Group</label>
   <description>Level 1 support — composes core Case CRUD, read-only reference data, and queue access.</description>
   <permissionSets>
      <permissionSet>PS_Object_RW_Case</permissionSet>
      <permissionSet>PS_Apex_CaseDashboard</permissionSet>
      <permissionSet>PS_Tabs_ServiceConsole</permissionSet>
   </permissionSets>
   <mutingPermissionSets>
      <mutingPermissionSet>MPS_SupportAgent_NoDelete</mutingPermissionSet>
   </mutingPermissionSets>
   <status>Updated</status>
</PermissionSetGroup>
```

**`<status>` values**
| Value | Meaning |
|---|---|
| `Updated` | Recalculation pending — Salesforce will recompute on next assignment / query |
| `Updating` | Recalculation in progress |
| `Outdated` | Component PS changed since last calculation |
| `Failed` | Recalculation failed — investigate |

Almost always deploy with `<status>Updated</status>`. Salesforce schedules the actual recalc.

### 5.3 PSG vs bare PS

| Use PSG when | Use bare PS when |
|---|---|
| Multiple PS compose a real business role | Single tightly-scoped capability |
| You want one assignment per user | Component is shared ad-hoc across roles |
| Muting is needed | No subtraction logic |

Every named business role (Support Agent, Finance Reader, Sales Manager) gets exactly one PSG.

### 5.4 Lifecycle traps

- Cannot delete a component PS while it's referenced by a PSG. Remove from PSG, deploy, then delete.
- Component PS changes don't apply until the PSG recalculates. If status is `Outdated`, touch the PSG.
- Adding a `MutingPermissionSet` requires re-deploying the PSG to link it — deploying the MPS alone is not enough.

---

## 6. Muting Permission Sets

### 6.1 What muting is

A `MutingPermissionSet` subtracts permissions from the calculated PSG total. It can ONLY be referenced from inside a PSG — never assigned to users directly, never used outside a group.

### 6.2 XML

```xml
<?xml version="1.0" encoding="UTF-8"?>
<MutingPermissionSet xmlns="http://soap.sforce.com/2006/04/metadata">
   <label>Mute Case Delete for Read-Only Group</label>
   <description>Removes Case.Delete for the read-only variant of the support agent group.</description>
   <objectPermissions>
      <allowCreate>false</allowCreate>
      <allowDelete>true</allowDelete>           <!-- TRUE here means "mute this permission" -->
      <allowEdit>false</allowEdit>
      <allowRead>false</allowRead>
      <modifyAllRecords>false</modifyAllRecords>
      <object>Case</object>
      <viewAllRecords>false</viewAllRecords>
   </objectPermissions>
   <userPermissions>
      <enabled>true</enabled>                    <!-- "enabled: true" in MPS = "mute this permission" -->
      <name>ViewAllData</name>
   </userPermissions>
</MutingPermissionSet>
```

**Inverted semantics:** in a Muting PS, `true` / `enabled=true` means **"remove this permission from the group's calculated total"**, not "grant it". This is the single biggest mistake AI agents make with muting.

### 6.3 Supported elements

`MutingPermissionSet` supports the subtractable children of `PermissionSet`: `objectPermissions`, `fieldPermissions`, `userPermissions`, `classAccesses`, `pageAccesses`, `customPermissions`, `applicationVisibilities`, `tabSettings`, `recordTypeVisibilities`. No `license` (PSG inherits from components).

### 6.4 When to use muting

Use muting only when (1) a component PS is shared across multiple PSGs and (2) one specific PSG must NOT receive a permission the component grants. Otherwise just don't include the permission in the component — don't grant-then-mute.

---

## 7. Custom Permissions — The Bypass / Feature-Gate Mechanism

### 7.1 Use cases

| Use | Pattern |
|---|---|
| Bypass a validation rule | `AND(<rule>, NOT($Permission.BypassCaseValidation))` |
| Bypass a Flow gate | Decision condition: `$Permission.BypassFlow == True` |
| Bypass `without sharing` enforcement in Apex | `if (!FeatureManagement.checkPermission('AllowUnsharedQuery')) { ... }` |
| Feature gate UI | LWC `@wire` against `@salesforce/customPermission/MyPerm` |

### 7.2 XML

```xml
<?xml version="1.0" encoding="UTF-8"?>
<CustomPermission xmlns="http://soap.sforce.com/2006/04/metadata">
   <description>Allows the user to bypass the Case Subject Required validation rule. Audit-logged. Assign only to support leads and admins.</description>
   <label>Bypass Case Validation</label>
</CustomPermission>
```

### 7.3 Apex usage

```apex
if (FeatureManagement.checkPermission('BypassCaseValidation')) { /* bypass */ }
```

### 7.4 `without sharing` gate pattern

Hardcoded `without sharing` is a security-review red flag. Gate it on a Custom Permission so the elevation is explicit and auditable:

```apex
public with sharing class CaseSearchService {
   public List<Case> search(String key) {
      if (FeatureManagement.checkPermission('AllowUnsharedCaseSearch')) {
         return new UnsharedQuery().run(key);
      }
      return [SELECT Id, Subject FROM Case WHERE Subject LIKE :('%' + key + '%') WITH USER_MODE];
   }
   private without sharing class UnsharedQuery {
      public List<Case> run(String key) {
         return [SELECT Id, Subject FROM Case WHERE Subject LIKE :('%' + key + '%')];
      }
   }
}
```

Grant the Custom Permission only via a narrow PS (e.g. `PS_SearchEscalation`).

### 7.5 Anti-patterns

| Wrong | Right |
|---|---|
| Hardcoded profile name check: `if (UserInfo.getProfileId() == '00e...')` | `FeatureManagement.checkPermission('X')` |
| Custom Setting flag `Bypass__c = true` checked against username | Custom Permission granted via PS |
| Multiple validation rules each checking `$Profile.Name = 'System Administrator'` | Single Custom Permission `BypassValidation`, referenced in every rule |

---

## 8. Agentforce Access Patterns

Two distinct agent types, two distinct access paths.

### 8.1 `AgentforceEmployeeAgent`

```
User → PSG_<AgentName>_User
         ├── <AgentName>_Access (custom PS — you author this)
         │     ├── agentAccesses for the agent itself
         │     ├── classAccesses for every apex:// action target
         │     ├── flowAccesses for every flow:// action target
         │     └── customPermissions used by the agent
         └── (optional) PS for data access the actions need
```

PS naming: `<AgentName>_Access` (e.g. `Email_Analysis_Agent_Access`). Mirror every `apex://`, `flow://`, `prompt://` target in the `.agent` file.

### 8.2 `AgentforceServiceAgent`

```
Bot User → AgentforceServiceAgentUser (system PS — DO NOT MODIFY)
         + <AgentName>_Access (custom PS — you author this)
```

The system PS `AgentforceServiceAgentUser` ships with Salesforce and provides Messaging/channel infrastructure. Your custom PS supplies the agent-specific class/flow/object grants. The bot user (`config.default_agent_user` per [agentforce-agent-script-reference.md](agentforce-agent-script-reference.md) §5) MUST have both PS assigned.

### 8.3 The planner permission-check trap

The agent planner evaluates **every action's permission requirements at planning time**, not invocation time. If the running user is missing class access for any single action in the bundle:

- The planner silently drops that action from the LLM's toolset.
- In some cases the planner short-circuits the entire action surface and the LLM falls back to free-text generation.
- No error surfaces in standard logs — only `enable_enhanced_event_logs: True` reveals the gap.

**Mitigation:** the `<AgentName>_Access` PS must mirror the agent's action manifest. On every `.agent` change, grep the PS for matching `classAccesses` / `flowAccesses` lines and add any missing entry before publish.

---

## 9. Complete Example — `PS_SupportAgent`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<PermissionSet xmlns="http://soap.sforce.com/2006/04/metadata">
   <label>Support Agent Permissions</label>
   <description>Level 1 Support — Case CRUD (no delete), Contact Read, dashboard Apex access. Owner: Support Engineering. Last reviewed: 2026-05-16.</description>
   <hasActivationRequired>false</hasActivationRequired>
   <license>Salesforce</license>

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

   <classAccesses>
      <apexClass>CaseDashboardController</apexClass>
      <enabled>true</enabled>
   </classAccesses>

   <flowAccesses>
      <enabled>true</enabled>
      <flow>Case_Escalation_Screen_Flow</flow>
   </flowAccesses>

   <customPermissions>
      <enabled>true</enabled>
      <name>BypassCaseValidation</name>
   </customPermissions>

   <tabSettings>
      <tab>Case</tab>
      <visibility>Available</visibility>
   </tabSettings>
   <applicationVisibilities>
      <application>standard__ServiceConsole</application>
      <default>false</default>
      <visible>true</visible>
   </applicationVisibilities>
   <userPermissions>
      <enabled>true</enabled>
      <name>RunReports</name>
   </userPermissions>
</PermissionSet>
```

---

## 10. Deployment Order

Deploy in this order. Reversing any step causes referenced-component-missing errors.

```
1. Custom Objects, Custom Fields           (foundation)
2. Custom Permissions                       (referenced by PS, validation rules)
3. Apex Classes                             (referenced by classAccesses)
4. Flows                                    (referenced by flowAccesses — must be deployed, not necessarily Active)
5. Apps, Tabs, Record Types                 (referenced by visibility blocks)
6. Permission Sets                          (component PS)
7. Muting Permission Sets                   (referenced by PSGs)
8. Permission Set Groups                    (composed last)
9. Permission Set Assignments               (manual, post-deploy, via UI or apex script)
```

The Case Flow Migration project's manifest (`manifest/package-case-flow-optimization.xml`) deploys PS metadata alongside Flows and Apex — no separate assignment step is included; Naresh handles assignment in sandbox after validation. See `CLAUDE.md` §4.

---

## 11. Validation Commands

```bash
# Dry-run a PS-only deploy
sf project deploy start \
   --source-dir force-app/main/default/permissionSets \
   --dry-run --test-level RunLocalTests \
   --target-org PlusGradeFullSB --wait 60

# Deploy PS + PSG + custom permissions together
sf project deploy start \
   --metadata "PermissionSet,PermissionSetGroup,MutingPermissionSet,CustomPermission" \
   --target-org PlusGradeFullSB

# Retrieve a single PS for review
sf project retrieve start \
   --metadata "PermissionSet:PS_SupportAgent" \
   --target-org PlusGradeFullSB

# Who has this PS today?
sf data query \
   --query "SELECT Assignee.Username, Assignee.Name FROM PermissionSetAssignment WHERE PermissionSet.Name = 'PS_SupportAgent'" \
   --target-org PlusGradeFullSB

# Verify a custom permission is granted on a PS
sf data query \
   --query "SELECT Id, SetupEntityType, SetupEntityId FROM SetupEntityAccess WHERE SetupEntityType = 'CustomPermission' AND ParentId IN (SELECT Id FROM PermissionSet WHERE Name = 'PS_SupportAgent')" \
   --target-org PlusGradeFullSB

# Which PSG references this component PS?
sf data query \
   --query "SELECT PermissionSetGroup.DeveloperName FROM PermissionSetGroupComponent WHERE PermissionSet.Name = 'PS_Object_RW_Case'" \
   --target-org PlusGradeFullSB
```

---

## 12. Definition of Done

A Permission Set / PSG / Muting PS is complete when:

- [ ] API name matches the `PS_` / `PSG_` / `MPS_` convention; no `_V2` / `_Temp` / `_New` suffixes
- [ ] `<label>` set and `<description>` includes owner, purpose, and `Last reviewed: YYYY-MM-DD`
- [ ] Every permission grant has a business justification (in PS description or accompanying doc)
- [ ] No `viewAllRecords` / `modifyAllRecords` / `ViewAllData` / `ModifyAllData` / `ManageUsers` without architect sign-off
- [ ] No required fields, no formula `editable=true` entries in `<fieldPermissions>`
- [ ] Standard tabs use `standard-` prefix; custom object tabs include `__c`
- [ ] Apex/Flow references match metadata that exists in the org
- [ ] For agent PS: `<agentAccesses>` plus a `<classAccesses>` entry for every action's `apex://` target
- [ ] If composed into a PSG: PSG `<status>` set to `Updated`
- [ ] If muting: muting semantics (true = remove) verified against component PS
- [ ] Dry-run deploy passes with zero component errors against `PlusGradeFullSB`

---

## 13. Common AI Mistakes to Avoid

| Mistake | Why It's Wrong | Correct approach |
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
| Including required fields in `<fieldPermissions>` | Deployment failure — Salesforce rejects FLS on required fields | Omit required fields entirely; they're accessible by default |
| Setting `editable=true` on a formula field | Deployment failure — formulas are read-only | Set `editable=false`, `readable=true` |
| Using bare standard tab name `Account` instead of `standard-Account` | Deployment failure on tab reference | Always prefix standard tabs with `standard-` |
| Treating `MutingPermissionSet` `true` as "grant" | Inverted semantics — muting removes, not adds | In MPS, `true`/`enabled=true` means "remove this permission from the PSG total" |
| Skipping `classAccesses` for an Agentforce action's apex target | Planner silently drops the action; agent hallucinates | Audit `<AgentName>_Access` PS against the agent's action manifest before publish |
| Assigning a component PS directly when a PSG exists for that role | Inconsistent access; PSG recalc skips direct assignments | Always assign the PSG, not the component |

---

## 14. Empirical Findings & Implementation Notes

When Salesforce's documented approach doesn't work in this org, the workaround goes here. Date-stamp every entry.

| # | Date | Documented approach | What actually works | Why / Context |
|---|---|---|---|---|

---

## 15. Official References

- [PermissionSet — Metadata API](https://developer.salesforce.com/docs/atlas.en-us.api_meta.meta/api_meta/meta_permissionset.htm)
- [PermissionSetGroup — Metadata API](https://developer.salesforce.com/docs/atlas.en-us.api_meta.meta/api_meta/meta_permissionsetgroup.htm)
- [MutingPermissionSet — Metadata API](https://developer.salesforce.com/docs/atlas.en-us.api_meta.meta/api_meta/meta_mutingpermissionset.htm)
- [CustomPermission — Metadata API](https://developer.salesforce.com/docs/atlas.en-us.api_meta.meta/api_meta/meta_custompermission.htm)
- [Permission Set Groups Overview — Salesforce Help](https://help.salesforce.com/s/articleView?id=sf.perm_sets_groups_overview.htm)
- [Muting Permission Sets — Salesforce Help](https://help.salesforce.com/s/articleView?id=sf.perm_set_groups_muting.htm)
- [Custom Permissions Overview — Salesforce Help](https://help.salesforce.com/s/articleView?id=sf.custom_perms_overview.htm)
- [Field-Level Security — Salesforce Help](https://help.salesforce.com/s/articleView?id=sf.admin_fls.htm)
- [FeatureManagement Class — Apex Reference](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_FeatureManagement.htm)
- [forcedotcom/sf-skills `generating-permission-set`](https://github.com/forcedotcom/sf-skills/tree/main/skills/generating-permission-set) — canonical XML reference
- [Salesforce Well-Architected: Trusted/Security](https://architect.salesforce.com/well-architected/trusted/security)

---

*Permission Set & Access Control Guidelines | v3.0 | Last verified 2026-05-16*
