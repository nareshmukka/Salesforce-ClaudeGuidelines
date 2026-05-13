# Deployment Guidelines

**Version**: 2.0 (April 2026)
**Developer**: Naresh | Senior Salesforce Developer
**Purpose**: Standalone guidelines for Salesforce metadata deployment using Salesforce CLI (sf). Covers package.xml, destructive changes, validation, quick deploy, dependency order, rollback, and CI/CD patterns. Attach when planning or executing any Salesforce deployment.

---

## Table of Contents

1. [Required Agent Output Contract](#required-agent-output-contract)
2. [Salesforce CLI (sf) Commands Reference](#salesforce-cli-sf-commands-reference)
3. [package.xml Structure](#packagexml-structure)
4. [Dependency Order — Critical](#dependency-order--critical)
5. [Validation Deployment (Required Before Production)](#validation-deployment-required-before-production)
6. [Quick Deploy](#quick-deploy)
7. [Retrieve Strategy](#retrieve-strategy)
8. [Source Tracking](#source-tracking)
9. [Sandbox → UAT → Production Flow](#sandbox--uat--production-flow)
10. [Rollback Strategy](#rollback-strategy)
11. [destructiveChanges.xml](#destructivechangesxml)
12. [Smoke Testing Post-Deploy](#smoke-testing-post-deploy)
13. [CI/CD Patterns](#cicd-patterns)
14. [Common AI Mistakes to Avoid](#common-ai-mistakes-to-avoid)
15. [Definition of Done (Deployment)](#definition-of-done-deployment)
16. [Validation Commands Quick Reference](#validation-commands-quick-reference)
17. [Official References](#official-references)

---

## Required Agent Output Contract

Every deployment plan produced by an AI agent MUST include all of the following sections. Do NOT omit any section. If a section is not applicable, state why explicitly.

1. **Complete package.xml** (or explicit components list with metadata types)
2. **Dependency order review** — list each component group and the order it must be deployed
3. **Validation command** (check-only) — exact sf CLI command with correct flags
4. **Test level selection and justification** — which test level and why it was chosen
5. **Quick deploy command** (after validation) — with placeholder for actual job ID
6. **Destructive changes manifest** (if any) — isolated in a separate destructiveChanges.xml, never mixed with additive changes
7. **Post-deploy smoke test plan** — specific steps matched to the deployed components
8. **Rollback plan** — specific steps to undo the deployment if it causes issues

Failure to include all eight items is a non-compliant deployment plan.

---

## Salesforce CLI (sf) Commands Reference

`sf` is the current Salesforce CLI (successor to `sfdx`). All commands below use the `sf` syntax. Always verify command syntax against the current SF CLI release notes, as flags and subcommands evolve between releases.

### Core Deployment Commands

| Command | Purpose |
|---|---|
| `sf project deploy start` | Deploy metadata to target org |
| `sf project deploy start --check-only` | Validate without deploying (check-only) |
| `sf project deploy quick` | Quick deploy using a previously validated job ID |
| `sf project deploy report` | Check status of a current or recent deploy |
| `sf project deploy cancel` | Cancel an in-progress deploy |
| `sf project retrieve start` | Retrieve metadata from an org |
| `sf project retrieve preview` | Preview what would be retrieved (no action taken) |
| `sf apex run test` | Run Apex tests in an org |
| `sf org list` | List all connected orgs |
| `sf org display` | Show connection details for a specific org |
| `sf org open` | Open an org in the browser |
| `sf plugins` | List installed CLI plugins |
| `sf update` | Update CLI to the latest version |

### Common Flags

| Flag | Purpose |
|---|---|
| `--target-org <alias>` | Target org alias (required for most commands) |
| `--manifest <path>` | Path to package.xml |
| `--metadata <MetadataType:ComponentName>` | Metadata component(s) to deploy |
| `--check-only` | Validate without deploying |
| `--test-level <level>` | Test execution level |
| `--tests <Class1,Class2>` | Specific test classes (used with RunSpecifiedTests) |
| `--wait <minutes>` | Minutes to wait for deploy to complete |
| `--job-id <id>` | Specific deployment job ID |
| `--use-most-recent` | Use the most recent deployment job |
| `--output-dir <path>` | Output directory for retrieved metadata |
| `--source-dir <path>` | Source directory to deploy from |

### Useful Shortcuts

```bash
# List all orgs with their aliases and status
sf org list

# Display connection info for an org
sf org display --target-org PROD

# Open target org in browser
sf org open --target-org UAT

# Get recent deploy status
sf project deploy report --use-most-recent --target-org PROD

# Cancel a stuck or failed deployment
sf project deploy cancel --job-id 0AfXXXXXXXXXXXX --target-org PROD
```

---

## package.xml Structure

The `package.xml` manifest file declares all metadata components to be deployed. Components must be listed by metadata type. Maintain the correct version number matching your org's API version.

### Complete package.xml Example

The following example covers the most common metadata types in a real-world release. It is organized in recommended deployment order with comments for clarity.

```xml
<?xml version="1.0" encoding="UTF-8"?>
<Package xmlns="http://soap.sforce.com/2006/04/metadata">

    <!-- ============================================================ -->
    <!-- WAVE 1: SCHEMA — Objects and Fields FIRST                    -->
    <!-- ============================================================ -->

    <!-- 1. Custom Objects — must exist before fields, record types, layouts -->
    <types>
        <members>Support_Case__c</members>
        <name>CustomObject</name>
    </types>

    <!-- 2. Custom Fields — must exist before record types, layouts, flows reference them -->
    <types>
        <members>Case.Case_Category__c</members>
        <members>Case.Case_SubCategory__c</members>
        <members>Case.External_Case_Id__c</members>
        <members>Case.Resolution_Notes__c</members>
        <name>CustomField</name>
    </types>

    <!-- 3. Record Types — must exist before layouts and flows reference them -->
    <types>
        <members>Case.CustomerService</members>
        <members>Case.TechnicalSupport</members>
        <name>RecordType</name>
    </types>

    <!-- ============================================================ -->
    <!-- WAVE 2: UI CONFIGURATION                                      -->
    <!-- ============================================================ -->

    <!-- 4. Page Layouts — must exist before FlexiPages reference them -->
    <types>
        <members>Case-Case Layout</members>
        <members>Case-Technical Support Layout</members>
        <name>Layout</name>
    </types>

    <!-- 5. Compact Layouts -->
    <types>
        <members>Case.CaseCompactLayout</members>
        <name>CompactLayout</name>
    </types>

    <!-- 6. Validation Rules — can deploy with layouts -->
    <types>
        <members>Case.VR_Case_SubjectRequired</members>
        <members>Case.VR_Category_Required_On_Close</members>
        <name>ValidationRule</name>
    </types>

    <!-- ============================================================ -->
    <!-- WAVE 3: CUSTOM METADATA                                       -->
    <!-- ============================================================ -->

    <!-- 7. Custom Metadata Types — deploy type before records -->
    <types>
        <members>CMDT_IntegrationConfig__mdt</members>
        <members>CMDT_FeatureFlag__mdt</members>
        <name>CustomObject</name>
    </types>

    <!-- 8. Custom Metadata Records — after type is deployed -->
    <types>
        <members>CMDT_IntegrationConfig__mdt.ExternalCaseAPI_Config</members>
        <members>CMDT_FeatureFlag__mdt.EnableCaseAutoClose</members>
        <name>CustomMetadata</name>
    </types>

    <!-- ============================================================ -->
    <!-- WAVE 4: AUTOMATION                                            -->
    <!-- ============================================================ -->

    <!-- 9. Flows — depend on objects, fields, record types; subflows before callers -->
    <types>
        <members>LogError_Subflow</members>
        <members>Case_AfterSave_RecordTriggered</members>
        <members>Case_ScreenFlow_EscalationProcess</members>
        <name>Flow</name>
    </types>

    <!-- ============================================================ -->
    <!-- WAVE 5: APEX                                                  -->
    <!-- ============================================================ -->

    <!-- 10. Apex Triggers — depend on objects and fields -->
    <types>
        <members>CaseTrigger</members>
        <name>ApexTrigger</name>
    </types>

    <!-- 11. Apex Classes — deploy all classes together to resolve references -->
    <types>
        <members>CaseTriggerHandler</members>
        <members>CaseService</members>
        <members>CaseSelector</members>
        <members>AppLogger</members>
        <members>ExternalCaseApiClient</members>
        <members>IntegrationException</members>
        <members>CaseServiceTest</members>
        <members>CaseSelectorTest</members>
        <members>AppLoggerTest</members>
        <name>ApexClass</name>
    </types>

    <!-- ============================================================ -->
    <!-- WAVE 6: UI COMPONENTS                                         -->
    <!-- ============================================================ -->

    <!-- 12. Lightning Web Components -->
    <types>
        <members>caseDashboardContainer</members>
        <members>caseListItem</members>
        <name>LightningComponentBundle</name>
    </types>

    <!-- ============================================================ -->
    <!-- WAVE 7: INTEGRATION CONFIGURATION                             -->
    <!-- ============================================================ -->

    <!-- 13. Named Credentials — must be in org before Apex callouts reference them -->
    <types>
        <members>ExternalCaseAPI</members>
        <name>NamedCredential</name>
    </types>

    <!-- 14. External Credentials (verify availability in target release) -->
    <!-- <types>
        <members>ExternalCaseAPIExternal</members>
        <name>ExternalCredential</name>
    </types> -->

    <!-- ============================================================ -->
    <!-- WAVE 8: ACCESS CONTROL                                        -->
    <!-- ============================================================ -->

    <!-- 15. Permission Sets — depend on objects, fields, Apex classes -->
    <types>
        <members>PS_SupportAgent</members>
        <members>PS_SupportSupervisor</members>
        <name>PermissionSet</name>
    </types>

    <!-- 16. Permission Set Groups — after component permission sets -->
    <types>
        <members>PSG_SupportTeam</members>
        <name>PermissionSetGroup</name>
    </types>

    <!-- ============================================================ -->
    <!-- WAVE 9: RECORD PAGES AND NAVIGATION                           -->
    <!-- ============================================================ -->

    <!-- 17. FlexiPages — depend on LWC components (must be deployed first) -->
    <types>
        <members>Case_Record_Page</members>
        <name>FlexiPage</name>
    </types>

    <!-- ============================================================ -->
    <!-- WAVE 10: COMMUNICATIONS                                       -->
    <!-- ============================================================ -->

    <!-- 18. Email Templates — depend on objects/fields for merge fields -->
    <types>
        <members>SupportTemplates/CaseClosedNotification</members>
        <name>EmailTemplate</name>
    </types>

    <!-- API Version — must match your org's current API version -->
    <version>62.0</version>

</Package>
```

### package.xml Rules

- Every `<types>` block must have exactly one `<name>` element identifying the metadata type
- Use `<members>*</members>` only when you intend to retrieve or deploy ALL components of that type — avoid in production manifests
- The `<version>` must match or be compatible with the org's current API version
- Member names are case-sensitive and must exactly match the API name in the org
- For nested metadata (fields, record types, layouts), use the parent object prefix: `Case.Case_Category__c`
- Do NOT mix additive and destructive components in the same package.xml — use a separate destructiveChanges.xml

### Checking API Names

```bash
# Retrieve a single component to verify its API name
sf project retrieve start \
  --metadata "ApexClass:CaseService" \
  --target-org DEV \
  --output-dir /tmp/verify/

# List all flows in org to find exact names
sf project retrieve start \
  --metadata "Flow:*" \
  --target-org DEV \
  --output-dir /tmp/flows/
```

---

## Dependency Order — Critical

Salesforce metadata has hard dependencies. Deploying components out of order causes deployment failures. Always deploy in the following order. Split into separate deployment waves if necessary — do not attempt to deploy everything in a single manifest when dependencies are complex.

### Deployment Wave Order

1. **Custom Objects**
   - Must exist before any fields, record types, layouts, flows, or Apex can reference them
   - If objects are new, deploy the object shell first before adding fields
   - Custom Metadata Type objects also go in this wave

2. **Custom Fields**
   - Must exist before record types, page layouts, flows, and Apex reference them
   - Standard object fields also deploy here
   - Required fields that have no default value need a default or null handling strategy before deploying to orgs with data

3. **Record Types**
   - Must exist before page layouts assign them
   - Must exist before flows branch on record type
   - Deploy before validation rules that reference record types

4. **Page Layouts**
   - Must exist before FlexiPages reference them
   - Deploy with or after record types
   - Assign fields that exist in the org — layout deployment fails if a referenced field is missing

5. **Validation Rules**
   - Can deploy in the same wave as page layouts
   - Ensure all referenced fields and record types are already deployed
   - Consider impact on existing data — a new required field validation will fire on save of existing records

6. **Custom Metadata Types** (the schema/object definition)
   - Deploy the type object before deploying records of that type
   - Types go in the CustomObject metadata type section

7. **Custom Metadata Records** (the actual data rows)
   - Deploy after the type definition is in the org
   - Records go in the CustomMetadata metadata type section

8. **Flows**
   - Depend on objects, fields, record types already being in the org
   - **Subflows must be deployed BEFORE the flows that call them** — this is the most common flow deployment failure
   - LogError_Subflow must always be deployed before any flow that uses it on a fault path
   - Screen Flows depend on the LWC components they embed — deploy LWC first or in the same wave
   - Record-triggered flows must match the API version of field and object names

9. **Apex Triggers and Classes**
   - Depend on objects and fields existing in the org
   - All classes that reference each other should be deployed together in one manifest
   - Test classes must compile — if test class references a class not in the manifest, that class must already be in the org

10. **Lightning Web Components (LWC)**
    - Can often be deployed in the same wave as Apex
    - Must be deployed BEFORE FlexiPages that include them
    - Must be deployed BEFORE Screen Flows that embed them

11. **Named Credentials and External Credentials**
    - Must be configured in the org before Apex that references them compiles correctly
    - Named Credentials are org-specific — they may need manual setup in production after metadata deployment
    - External Credentials require associated permission set assignments that cannot be fully automated

12. **Permission Sets**
    - Depend on objects, fields, Apex classes, and Visualforce pages they grant access to
    - All referenced components must exist in the org before the permission set deploys
    - Deploy after all objects, fields, Apex classes, and LWC components it references

13. **Permission Set Groups**
    - Depend on all component permission sets included in the group
    - Deploy after all referenced permission sets

14. **FlexiPages**
    - Depend on LWC components they reference
    - Depend on page layouts assigned in the page
    - Deploy last in the UI configuration wave
    - Activation rules reference profiles and apps — verify those exist in the target org

15. **Email Templates**
    - Depend on the object fields used as merge fields
    - Folder structure must exist before the template
    - Deploy after the objects and fields they reference

### Multi-Wave Deployment Example

For a complex release with new objects, flows, Apex, LWC, and permission sets:

```bash
# Wave 1: Schema
sf project deploy start --manifest manifest/wave1_schema.xml --target-org UAT --wait 30

# Wave 2: Automation
sf project deploy start --manifest manifest/wave2_flows.xml --target-org UAT --wait 30

# Wave 3: Apex and LWC
sf project deploy start --manifest manifest/wave3_apex_lwc.xml --target-org UAT --wait 60 --test-level RunLocalTests

# Wave 4: Access and Pages
sf project deploy start --manifest manifest/wave4_access_pages.xml --target-org UAT --wait 30
```

---

## Validation Deployment (Required Before Production)

A validation deployment runs the full deployment process — compiling Apex, running tests, validating metadata — but does NOT actually deploy the components to the org. It produces a job ID that can be used for a subsequent quick deploy.

### When Validation Is Required

- Before every production deployment — no exceptions
- Before UAT deployments when the package contains Apex
- When deploying flows or configuration that affects live business processes

### Validation Command

```bash
# Validate only — no metadata is deployed to the org
sf project deploy start \
  --manifest manifest/package.xml \
  --target-org UAT \
  --check-only \
  --test-level RunLocalTests \
  --wait 60

# Check result and get job ID for quick deploy
sf project deploy report --use-most-recent --target-org UAT
```

The job ID appears in the output as `Deploy ID: 0AfXXXXXXXXXXXX`. Save this for quick deploy.

### Test Level Selection

| Test Level | When to Use | Notes |
|---|---|---|
| `NoTestRun` | Dev sandbox only — NEVER production | No test execution, minimum validation |
| `RunSpecifiedTests --tests Class1,Class2` | Targeted validation for a known-scope change | You must prove the listed tests cover the deployed code |
| `RunLocalTests` | Standard validation for all sandbox and production | Runs all tests in the org except managed package tests |
| `RunAllTestsInOrg` | Maximum coverage validation | Runs all tests including managed package tests — use when you need full org test pass confirmation |

**Production rule**: Always use `RunLocalTests` or higher for production deployments. `NoTestRun` is prohibited in production.

**RunSpecifiedTests note**: When using `RunSpecifiedTests`, you must ensure the specified test classes provide at least 75% coverage for all deployed Apex. The platform validates this. Document the coverage justification in your deployment plan.

### Reading Validation Output

```bash
# Verbose output with test results
sf project deploy start \
  --manifest manifest/package.xml \
  --target-org PROD \
  --check-only \
  --test-level RunLocalTests \
  --wait 60 \
  --verbose

# If you need to check after command exits
sf project deploy report \
  --job-id 0AfXXXXXXXXXXXX \
  --target-org PROD
```

Validation success criteria:
- All components compiled without errors
- All specified tests passed
- Overall Apex code coverage >= 75%
- No test failures or compilation errors

---

## Quick Deploy

After a successful validation deployment with `RunLocalTests` or higher, you can execute a quick deploy. Quick deploy skips the test run and deploys immediately using the pre-validated job results.

### Quick Deploy Command

```bash
# Quick deploy using the validated job ID
sf project deploy quick \
  --job-id 0AfXXXXXXXXXXXX \
  --target-org PROD \
  --wait 30

# Monitor progress
sf project deploy report --use-most-recent --target-org PROD
```

### Quick Deploy Rules

- The validation job ID must be from a successful `RunLocalTests` or higher validation
- The quick deploy window is **10 days** from the validation timestamp — verify this in the current Salesforce release notes as it may change
- The same package.xml and components must be deployed — if any component changed after validation, re-validate
- Quick deploy is only available when the validation used `RunLocalTests`, `RunSpecifiedTests`, or `RunAllTestsInOrg`
- Quick deploy is NOT available for validations run with `NoTestRun`

### Finding the Validation Job ID

```bash
# The job ID is output when you run the validation
# Example output line: Deploy ID: 0Af5g000003CGXXCA4

# You can also retrieve recent deployment history from the org
sf project deploy report --use-most-recent --target-org PROD
```

---

## Retrieve Strategy

Retrieval pulls metadata from the org into your local source format. Always retrieve the current state of target org components BEFORE modifying and re-deploying — this prevents overwriting changes made directly in the org.

### Retrieve by Metadata Type

```bash
# Retrieve specific components by type and name
sf project retrieve start \
  --metadata "ApexClass:CaseService,ApexTrigger:CaseTrigger" \
  --target-org DEV \
  --output-dir force-app/main/default

# Retrieve all components of a type (use with caution)
sf project retrieve start \
  --metadata "Flow:*" \
  --target-org DEV \
  --output-dir force-app/main/default
```

### Retrieve by Manifest

```bash
# Retrieve exactly the components in package.xml
sf project retrieve start \
  --manifest manifest/package.xml \
  --target-org DEV \
  --output-dir force-app/main/default

# Retrieve to a backup directory before deploying
sf project retrieve start \
  --manifest manifest/package.xml \
  --target-org PROD \
  --output-dir backup/pre-deploy-$(date +%Y%m%d)/
```

### Retrieve for Backup Before Production Deploy

Always retrieve the current production state of the components you are deploying BEFORE the deployment. This backup is your immediate rollback source.

```bash
# Backup current production state
sf project retrieve start \
  --manifest manifest/package.xml \
  --target-org PROD \
  --output-dir backup/prod-backup-$(date +%Y%m%d-%H%M)/

# Commit the backup to source control for traceability
git add backup/
git commit -m "Pre-deploy backup: $(date +%Y%m%d)"
```

### Retrieve Preview

Before retrieving, preview what would be retrieved without executing:

```bash
sf project retrieve preview --target-org DEV
```

---

## Source Tracking

Source tracking is available in scratch orgs and sandboxes that have it enabled. It tracks changes made in the org and in your local source, enabling differential deploys.

### Source-Tracked Environments

```bash
# See what changed in the org since last sync
sf project deploy preview --target-org Scratch

# Deploy only changed components from local source
sf project deploy start --target-org Scratch

# Retrieve only changed components from the org
sf project retrieve start --target-org Scratch
```

### Source Tracking Rules

- Scratch orgs always have source tracking enabled
- Developer sandboxes can have source tracking enabled at creation
- Production and UAT sandboxes typically do NOT have source tracking — use manifest-based deployments there
- In source-tracked environments: always prefer source-format repo over unpackaged metadata
- Source tracking conflicts require manual resolution — `sf project deploy preview` shows conflicts before acting

### Checking Source Tracking Status

```bash
# View source tracking status (changed local files and org changes)
sf project deploy preview --target-org DEV

# Force overwrite org with local changes (use with caution)
sf project deploy start --ignore-conflicts --target-org DEV
```

---

## Sandbox to UAT to Production Flow

### Standard Pipeline

```
Developer Sandbox
      |
      | (develop + unit test locally)
      v
Integration Sandbox
      |
      | (integration testing, flow testing, end-to-end)
      v
UAT Sandbox
      |
      | (business validation, user acceptance testing)
      | (validation deployment with RunLocalTests)
      v
Production
      | (quick deploy from UAT validation job ID)
      v
Post-Deploy Smoke Test
```

### Pipeline Rules

- **Never deploy directly from a developer sandbox to production**
- UAT must replicate production data profile where possible — use sandbox refresh before UAT
- Production deployment must follow a successful UAT validation
- Use the **same package.xml** from UAT to production — do not modify between environments
- Production deployment window: schedule during low-traffic hours
- Notify stakeholders before production deployment begins
- Keep a rollback plan reviewed and ready before starting production deployment

### Environment-Specific Notes

| Environment | Test Level | Validation Required | Notes |
|---|---|---|---|
| Developer Sandbox | NoTestRun acceptable | No | Fast iteration, source tracking recommended |
| Integration Sandbox | RunLocalTests recommended | No | Catch cross-component issues |
| UAT Sandbox | RunLocalTests required | Yes | Mandatory check-only before production |
| Production | RunLocalTests minimum | Yes — always | Quick deploy from UAT validation job |

---

## Rollback Strategy

For every release, document the rollback plan BEFORE deploying. A rollback plan must exist at the time of deployment — it cannot be created after something goes wrong.

### Rollback Planning Checklist

Before any production deployment:
- [ ] Identify what can be rolled back declaratively (deactivate a flow, disable a validation rule)
- [ ] Identify what requires a reverse metadata deployment
- [ ] Retrieve and commit current production state to source control as a backup
- [ ] Document which Apex class versions to redeploy in case of rollback
- [ ] Identify any data changes that cannot be automatically reversed

### Component-Specific Rollback Patterns

**Apex Classes and Triggers**
```bash
# Roll back to a previous version from source control
git checkout <previous-commit-hash> -- force-app/main/default/classes/CaseService.cls
git checkout <previous-commit-hash> -- force-app/main/default/classes/CaseService.cls-meta.xml

sf project deploy start \
  --metadata "ApexClass:CaseService" \
  --target-org PROD \
  --wait 30
```

**Flows**
```bash
# Roll back by deploying prior flow version from source control
git checkout <previous-commit-hash> -- force-app/main/default/flows/Case_AfterSave_RecordTriggered.flow-meta.xml

sf project deploy start \
  --metadata "Flow:Case_AfterSave_RecordTriggered" \
  --target-org PROD \
  --wait 30

# Alternatively: reactivate a prior inactive flow version manually in Flow Builder UI
# (Go to Setup > Flows > find the flow > click the version dropdown > activate prior version)
```

**Validation Rules**
- Deactivate directly in Setup > Object Manager — no deployment needed for quick rollback
- Redeploy deactivated version from source control for formal rollback

**Custom Fields**
- Fields cannot be deleted if they contain data — no rollback to pre-field state without a data purge
- Document before deploying: will this field contain data within the deployment window?

**Page Layouts and FlexiPages**
```bash
# Redeploy previous layout/FlexiPage from source control
git checkout <previous-commit-hash> -- force-app/main/default/flexipages/Case_Record_Page.flexipage-meta.xml

sf project deploy start \
  --metadata "FlexiPage:Case_Record_Page" \
  --target-org PROD \
  --wait 30
```

**Permission Sets**
- Roll back by redeploying the prior permission set XML from source control
- If new permissions caused security issues, rollback the permission set immediately as the highest priority

### Rollback Execution Steps

1. Confirm the issue and agree rollback is necessary
2. Retrieve the current (post-deploy) state for investigation purposes
3. Deploy the rollback package (prior versions from source control)
4. Verify rollback success with smoke tests
5. Document the incident: what was deployed, what failed, what was rolled back

---

## destructiveChanges.xml

Use destructiveChanges.xml ONLY when components must be permanently deleted from the target org. Never include destructive changes in the same manifest as additive changes.

### destructiveChanges.xml Format

```xml
<!-- destructiveChanges.xml — for pre-deploy deletions (before additive changes) -->
<?xml version="1.0" encoding="UTF-8"?>
<Package xmlns="http://soap.sforce.com/2006/04/metadata">
    <types>
        <members>OldCaseService</members>
        <members>OldCaseServiceHelper</members>
        <name>ApexClass</name>
    </types>
    <types>
        <members>Case_OldFlow_ToBeRetired</members>
        <name>Flow</name>
    </types>
    <version>62.0</version>
</Package>
```

```xml
<!-- destructiveChangesPost.xml — for post-deploy deletions (after additive changes) -->
<?xml version="1.0" encoding="UTF-8"?>
<Package xmlns="http://soap.sforce.com/2006/04/metadata">
    <types>
        <members>OldCaseTriggerHelper</members>
        <name>ApexClass</name>
    </types>
    <version>62.0</version>
</Package>
```

### Deploying Destructive Changes

```bash
# Deploy destructive changes (component deletion) using empty package.xml + destructiveChanges.xml
# Create an empty_package.xml with only the version tag:
# <?xml version="1.0" encoding="UTF-8"?>
# <Package xmlns="http://soap.sforce.com/2006/04/metadata">
#   <version>62.0</version>
# </Package>

sf project deploy start \
  --manifest manifest/empty_package.xml \
  --pre-destructive-changes manifest/destructiveChanges.xml \
  --target-org UAT \
  --wait 30

# Post-deploy destructive changes
sf project deploy start \
  --manifest manifest/empty_package.xml \
  --post-destructive-changes manifest/destructiveChangesPost.xml \
  --target-org UAT \
  --wait 30
```

### Destructive Change Rules

- **NEVER delete a custom field that contains data without a data migration plan** — field deletion is permanent and data is unrecoverable
- **NEVER delete an Apex class that is still referenced** by flows, permission sets, Visualforce pages, or other Apex code
- **NEVER delete a Flow** that is actively being used — deactivate first, verify no running interviews, then delete
- Require architect or senior developer sign-off for all destructive deployments
- Test destructive changes in a sandbox that mirrors production data first
- Always deploy additive changes BEFORE destructive changes in multi-wave releases
- Document EVERY component being deleted and the reason for deletion
- Confirm the component to be deleted is NOT referenced anywhere else in the org before proceeding

### Pre-Deletion Checklist

Before deleting any component:
- [ ] Verify the component is not referenced in any other metadata (search org for references)
- [ ] Verify the component has no data dependencies (for fields: check field data, field history, reports, dashboards)
- [ ] Confirm the component is not used in any integration or external system
- [ ] Get architect sign-off
- [ ] Test deletion in a representative sandbox
- [ ] Document the deletion in the release notes

---

## Smoke Testing Post-Deploy

Smoke testing confirms the deployment succeeded and the system behaves correctly. These are quick functional checks, not full regression tests. They must be executed immediately after deployment.

### Standard Smoke Test Checklist

- [ ] Log in to the org as a test user who has the relevant permission set assigned
- [ ] Navigate to a record of the affected object — page loads without errors
- [ ] Open the record in the new/modified FlexiPage layout — all sections render
- [ ] Trigger the affected flow/automation (create, update, or status change as applicable) — verify the expected outcome
- [ ] Open the affected LWC component — loads data, no JavaScript console errors (check browser developer tools)
- [ ] Create a test record end-to-end — verify all fields, validation rules, and automations fire correctly
- [ ] Trigger any integration callout (if applicable) — verify success response logged in AppLog__c
- [ ] Check AppLog__c for any unexpected ERROR or FATAL entries from the deployment window
- [ ] Verify affected reports and dashboards still load and return data
- [ ] Verify email templates send correctly (if applicable)

### Smoke Test by Component Type

**Apex Class / Trigger Changes**
- Execute the trigger context (create/update/delete a record of the affected object)
- Verify the expected side effects occurred
- Check AppLog__c for any unexpected errors from the Apex execution

**Flow Changes**
- Execute the flow trigger manually or via the trigger condition
- Verify created/updated records match expected values
- Check for any unexpected fault log entries

**LWC Changes**
- Open the component in its host page
- Verify all render states work: data loaded, empty state, error state (if testable)
- Check browser console for JavaScript errors

**Permission Set Changes**
- Log in as a user with the modified permission set
- Verify access to objects, fields, tabs, and Apex classes is correct
- Verify removed permissions are no longer accessible

**FlexiPage Changes**
- Open the affected record type's record page
- Verify all components render
- Verify component visibility conditions work (show/hide based on field values)

---

## CI/CD Patterns

For automated pipelines, the following patterns are recommended. These are patterns — adapt to your specific CI/CD platform (GitHub Actions, Bitbucket Pipelines, Azure DevOps, etc.).

### Validation Pipeline (Pull Request)

```bash
# Step 1: Authorize to org (use stored credentials/JWT in CI)
sf org login jwt \
  --client-id $SF_CLIENT_ID \
  --jwt-key-file server.key \
  --username $SF_USERNAME \
  --alias CI_ORG

# Step 2: Run validation (check-only)
sf project deploy start \
  --manifest manifest/package.xml \
  --target-org CI_ORG \
  --check-only \
  --test-level RunLocalTests \
  --wait 60

# Step 3: Report results
sf project deploy report --use-most-recent --target-org CI_ORG
```

### Production Deployment Pipeline

```bash
# Step 1: Validate against production
VALIDATION_OUTPUT=$(sf project deploy start \
  --manifest manifest/package.xml \
  --target-org PROD \
  --check-only \
  --test-level RunLocalTests \
  --wait 60 \
  --json)

JOB_ID=$(echo $VALIDATION_OUTPUT | jq -r '.result.id')

# Step 2: Quick deploy (after approval gate in CI/CD)
sf project deploy quick \
  --job-id $JOB_ID \
  --target-org PROD \
  --wait 30

# Step 3: Post-deploy report
sf project deploy report --use-most-recent --target-org PROD
```

### Branch Strategy for Deployments

- `feature/*` branches: deploy to Developer sandbox for development
- `develop` branch: deploy to Integration sandbox after PR merge
- `release/*` branches: deploy to UAT for validation
- `main` branch: validated and quick-deployed to Production

---

## Common AI Mistakes to Avoid

The following are errors that AI agents frequently make when generating deployment plans. Every agent output MUST be checked against this list.

| # | Mistake | Correct Approach |
|---|---|---|
| 1 | Wrong dependency order — Flow deployed before its custom fields; FlexiPage before its LWC; Permission Set before the Apex it grants access to | Resolve dependency order before building the manifest; deploy infrastructure metadata first |
| 2 | Using `NoTestRun` for production deployments | Always use `RunLocalTests` or higher for production; `NoTestRun` is sandbox-only |
| 3 | Mixing additive and destructive changes in one manifest | Isolate destructiveChanges.xml; deploy destructive changes separately and with explicit approval |
| 4 | Quick deploy without a prior check-only validation | Always run `--check-only` first; only quick-deploy after a successful validation within the 10-day window |
| 5 | No rollback plan documented | Every deployment plan must include a documented rollback procedure before execution |
| 6 | Deploying Named Credentials without verifying callout connectivity | Named Credentials may require manual secret/credential setup in the target org after metadata deployment — verify connectivity post-deploy |
| 7 | Deploying Flows that reference inactive or missing subflows | LogError_Subflow and all called subflows must be active in the target org before the calling flow is deployed |
| 8 | Not retrieving the current production state before deploying | Always retrieve a backup and commit it to source control before modifying production |
| 9 | Incorrect member names — display names instead of API names; wrong parent object prefix on fields | Use API names throughout; double-check field names include the object prefix (e.g. `Case.Status`) |
| 10 | Omitting test classes from package.xml | Test classes must be included in the manifest alongside the Apex code they test |
| 11 | Wrong `--target-org` alias | Always verify the alias before executing; use `sf org list` to confirm |
| 12 | Assuming quick deploy is always available | The 10-day validation window may have expired; re-run check-only if unsure |

---

## Definition of Done (Deployment)

A deployment is not complete until ALL items on this checklist are confirmed.

### Pre-Deployment

- [ ] package.xml reviewed — only the intended release components are included, no extras
- [ ] Dependency order confirmed correct for all components in the manifest
- [ ] All referenced components already exist in the target org or are included in the manifest
- [ ] Validation deployment successful (`--check-only`) with `RunLocalTests` or higher
- [ ] Test coverage >= 75% confirmed in validation output
- [ ] Destructive changes isolated in separate destructiveChanges.xml and approved
- [ ] Rollback plan documented and reviewed
- [ ] Deployment window communicated to stakeholders and impacted users

### Deployment Execution

- [ ] Pre-deploy backup retrieved from production and committed to source control
- [ ] Quick deploy executed within the validation window (10 days)
- [ ] Deployment completed without errors
- [ ] Post-deploy `sf project deploy report` confirms success

### Post-Deployment

- [ ] Smoke tests executed and passed
- [ ] AppLog__c checked for unexpected errors
- [ ] Stakeholders notified of successful deployment
- [ ] Release documented in change log / JIRA

---

## Validation Commands Quick Reference

```bash
# Full validation (check-only) against UAT
sf project deploy start \
  --manifest manifest/package.xml \
  --target-org UAT \
  --check-only \
  --test-level RunLocalTests \
  --wait 60

# Full validation against PROD
sf project deploy start \
  --manifest manifest/package.xml \
  --target-org PROD \
  --check-only \
  --test-level RunLocalTests \
  --wait 60

# Quick deploy to PROD (replace job ID with actual value from validation output)
sf project deploy quick \
  --job-id 0AfXXXXXXXXXXXX \
  --target-org PROD \
  --wait 30

# Retrieve current state for backup before deploying
sf project retrieve start \
  --manifest manifest/package.xml \
  --target-org PROD \
  --output-dir backup/prod-$(date +%Y%m%d)/

# Check most recent deployment status
sf project deploy report --use-most-recent --target-org PROD

# Cancel in-progress deployment
sf project deploy cancel --job-id 0AfXXXXXXXXXXXX --target-org PROD

# Run specified tests only (when scope is well-defined)
sf project deploy start \
  --manifest manifest/package.xml \
  --target-org UAT \
  --check-only \
  --test-level RunSpecifiedTests \
  --tests CaseServiceTest,CaseSelectorTest \
  --wait 60
```

---

## Official References

- Salesforce CLI Reference: https://developer.salesforce.com/docs/atlas.en-us.sfdx_cli_reference.meta/sfdx_cli_reference/
- Metadata API Deploy: https://developer.salesforce.com/docs/atlas.en-us.api_meta.meta/api_meta/meta_deploy.htm
- Package Development Model: https://trailhead.salesforce.com/content/learn/modules/package-development-readiness
- Quick Deploy Help: https://help.salesforce.com/s/articleView?id=sf.deploy_quick.htm
- Metadata Coverage Report (which metadata types support source tracking, packaging, etc.): https://developer.salesforce.com/docs/metadata-coverage
- Salesforce CLI Release Notes: https://github.com/forcedotcom/cli/releases
