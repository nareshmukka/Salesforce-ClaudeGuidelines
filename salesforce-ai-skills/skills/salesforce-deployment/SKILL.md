---
name: salesforce-deployment
description: Production Salesforce AI skill for package.xml composition, validation, release planning.
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
- The task involves package.xml composition, validation, release planning.
- The user asks for implementation, refactor, troubleshooting, review, or best-practice validation in this area.
- The assistant must produce Salesforce-safe code/metadata with explicit security/testing notes.

## DO NOT TRIGGER when
- The task is unrelated to this component.
- Another specialized skill is the primary owner and this area is only incidental.
- The user asks for operational execution (deploy/publish/activate/destructive change) without explicit approval.

## Cross-skill routing
- Always read `../salesforce-global-development/SKILL.md`.
- Also read: Global Development + Metadata + Testing + Permissions.
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
Use smallest manifest for change scope. Validate in sandbox/UAT first, then prod gate. Treat destructive changes as separately reviewed artifacts. Quick deploy only from successful validation.

## Upstream Salesforce Skill Patterns
- Use `sf` CLI v2. Prefer `--json` output for any command the assistant must parse.
- Preflight before deploy: `sf --version`, `sf org list`, `sf org display --target-org <alias> --json`, and confirm `sfdx-project.json`.
- Deploy the smallest correct scope with `--source-dir`, `--metadata`, or `--manifest`; non-source-tracking orgs need explicit scope.
- Default safe order: custom objects/fields, permission sets, Apex, Flows as Draft, then activation/post-verify.
- Run dry-run validation first; only deploy after validation succeeds and the user approves the actual org-changing step.
- Triage common failures by category: missing dependency, validation rule/test data, trigger/flow side effect, wrong API name, or Flow version/activation conflict.
- Use Code Analyzer v5 (`sf code-analyzer`) for static analysis where available; do not refer to retired scanner workflows for new guidance.

## Examples
### Good example patterns
1. Check-only validation with RunLocalTests before release approval.
2. Rollback plan maps each changed metadata component to revert strategy.

### Bad examples / avoid
1. Deploying broad wildcard manifest without scope review.
2. Running destructive changes without explicit approval and backup plan.

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

# Deployment Guidelines -- Canonical Reference

Authoritative grammar and workflow for Salesforce metadata deployment in this project, using `sf` CLI v2. Other skill files (`../salesforce-apex/SKILL.md`, `../salesforce-flow/SKILL.md`, `../salesforce-lwc/SKILL.md`, `../salesforce-agentforce-authoring-bundle/SKILL.md`) reference this one for any `sf project deploy` invocation.

**Verified against:** [SFDX Dev Guide](https://developer.salesforce.com/docs/atlas.en-us.sfdx_dev.meta/sfdx_dev/) - [SF CLI command reference](https://developer.salesforce.com/docs/atlas.en-us.sfdx_cli_reference.meta/sfdx_cli_reference/) - [Metadata API Deploy](https://developer.salesforce.com/docs/atlas.en-us.api_meta.meta/api_meta/meta_deploy.htm) - [Quick Deploy](https://help.salesforce.com/s/articleView?id=sf.deploy_quick.htm) - `/tmp/sf-skills/skills/deploying-metadata/SKILL.md` (forcedotcom canonical skill, v1.1) - project `.claude/sf-config.json`. Last verified 2026-05-16.

> **Project rule (PlusGradeFullSB):** Flows deploy as `status = Draft`. Naresh activates them manually after sandbox validation. Old flows are NOT deactivated by AI agents. See Section 11 1. Project Constants (Read Before Composing Any Command)

These values live in `.claude/sf-config.json` -- the single source of truth. Never hardcode them in command templates; agents must read the config file.

| Key | Value | Where it appears |
|---|---|---|
| `orgAlias` | `PlusGradeFullSB` | `--target-org PlusGradeFullSB` |
| `manifest` | `manifest/package-case-flow-optimization.xml` | `--manifest manifest/...` |
| `currentApiVersion` | `66.0` (Spring '26) | `<version>66.0</version>` in package.xml + `*-meta.xml` |
| `flowDeployStatus` | `Draft` | Every flow's `<status>Draft</status>` |
| `doNotActivateNewFlows` | `True` | No `sf flow activate` commands; no `<status>Active</status>` |
| `doNotDeactivateOldFlows` | `True` | No edits to old flows' status |
| `expectedTestFailures` | `13 pre-existing Opportunity tests` | Treat as baseline, not as deployment blockers |
| `testsDefault` | `deferred` | New test classes are not part of the migration scope |

Bump `currentApiVersion` per release: Summer '26 = 67.0, Winter '27 = 68.0.

---

## 2. The Canonical Validation Command

This is the command Naresh runs after every significant change. It is the contract between agent output and reviewer.

```bash
sf project deploy start \
  --manifest manifest/package-case-flow-optimization.xml \
  --target-org PlusGradeFullSB \
  --dry-run \
  --test-level RunLocalTests \
  --wait 60
```

**Required pass criteria:**
- Zero component errors
- The 13 Opportunity test failures appear and are tagged as pre-existing -- ignore them
- No new Case-related test failures introduced
- All deployed components compile

Run this after any change to Apex, Flow, FlexiPage, Permission Set, or custom field metadata. Validation is cheap, debugging a failed real deploy is not.

---

## 3. `sf project deploy start` -- Flag Reference

`sf project deploy start` is the unified deploy command in CLI v2 (replaces `sfdx force:source:deploy` and `sfdx force:mdapi:deploy`).

| Category | Flag | Purpose |
|---|---|---|
| **Scope** (pick one) | `--manifest <path>` | Deploy components listed in a `package.xml` -- project default |
| | `--metadata <Type:Name>` | Targeted hotfix, single class/flow |
| | `--source-dir <path>` | Whole-folder push (e.g. `force-app/main/default/lwc`) |
| | `--metadata-dir <path>` | MDAPI-format directory (legacy) |
| **Validation** | `--dry-run` | Validate only -- no metadata written. **Replaces `--check-only` from sfdx.** Returns a job ID usable for quick deploy. |
| | `--ignore-conflicts` | Skip source-tracking conflict detection (source-tracked orgs only) |
| | `--ignore-warnings` | Warnings non-fatal; errors still fail |
| | `--ignore-errors` | Partial success on errors. **Never in production.** |
| **Tests** | `--test-level <level>` | See Section 6 for values |
| | `--tests <Class1,Class2>` | Required with `RunSpecifiedTests` |
| | `--coverage-formatters <fmt>` | `json`, `cobertura`, `html`, `lcovonly`, `text`, `text-summary`, `teamcity`, `clover` |
| | `--results-dir <path>` | Write coverage/test artifacts |
| **Timing** | `--wait <minutes>` | Block until done. `60` for full RunLocalTests; `15-30` for component-only |
| | `--async` | Submit + return; poll with `sf project deploy report` |
| **Destructive** | `--pre-destructive-changes <path>` | Delete BEFORE additive changes |
| | `--post-destructive-changes <path>` | Delete AFTER additive changes (more common) |
| | `--purge-on-delete` | Skip Recycle Bin (production tenant only) |
| **Output** | `--json` | Machine-readable. **Required in CI/CD.** |
| | `--verbose` | Component lists, test results, coverage |
| | `--concise` | Summary only |
| **Other** | `--target-org <alias>` | Required for every deploy |
| | `--single-package` | MDAPI-format single-package source |
| | `--api-version <N>` | Override -- avoid; let `sourceApiVersion` drive |

Without a scope flag on a non-source-tracking org, the command fails with `RequiresDeployFlagsOrSourceTrackedOrgError`. Always specify scope explicitly.

> **Naming note:** Older docs use `--check-only`. In CLI v2 the canonical flag is **`--dry-run`** (alias `--check-only` still accepted on some versions).

---

## 4. The Validation -> Quick Deploy Workflow

For production, never run a real deploy first. The workflow is:

```
"Œ"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
"‚  1. Validate (--dry-run) -> produces a job ID                 "‚
"‚  2. Review output -> confirm 0 new failures                   "‚
"‚  3. Quick deploy (--job-id) within 10 days                   "‚
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""˜
```

### Step 1 -- Validate (capture job ID)

```bash
JOB_ID=$(sf project deploy start \
  --manifest manifest/package-case-flow-optimization.xml \
  --target-org PlusGradeFullSB \
  --dry-run --test-level RunLocalTests --wait 60 --json | jq -r '.result.id')
```

### Step 2 -- Review

```bash
sf project deploy report --job-id $JOB_ID --target-org PlusGradeFullSB --verbose
```

Confirm `status: Succeeded`, test failures match the 13-Opportunity baseline (no new failures), all listed components are intentional.

### Step 3 -- Quick Deploy

```bash
sf project deploy quick --job-id $JOB_ID --target-org PlusGradeFullSB --wait 30
```

**Quick deploy rules:** validation must have used `RunLocalTests`/`RunSpecifiedTests`/`RunAllTestsInOrg` (NOT `NoTestRun`). The 10-day window starts at validation completion. If anything changed in the org or package since validation, re-validate.

---

## 5. `sf project deploy` Subcommands

| Subcommand | Purpose |
|---|---|
| `sf project deploy start` | Deploy (or validate with `--dry-run`) |
| `sf project deploy quick` | Quick-deploy a previously validated job |
| `sf project deploy validate` | Alias of `start --dry-run` (validate-only). Returns a deployable job ID. |
| `sf project deploy report` | Status of a current or past deploy. Use `--use-most-recent` to skip the job ID. |
| `sf project deploy resume` | Resume polling on a deploy you started async |
| `sf project deploy cancel` | Cancel an in-progress deploy (only works during in-flight phase) |
| `sf project deploy preview` | Preview which local changes would deploy (source-tracked orgs only) |

```bash
# Most recent deploy status
sf project deploy report --use-most-recent --target-org PlusGradeFullSB

# Resume polling on an async deploy
sf project deploy resume --job-id 0AfXXXXXXXXXXXX --target-org PlusGradeFullSB --wait 60

# Cancel an in-progress deploy
sf project deploy cancel --job-id 0AfXXXXXXXXXXXX --target-org PlusGradeFullSB
```

---

## 6. Test Levels

The test level controls which Apex tests run during deployment. Wrong choice = either a failed deploy (too strict) or a production incident (too lax).

| Level | Behavior | When to use |
|---|---|---|
| `NoTestRun` | Skip all tests | Developer sandbox only. **NEVER in production or UAT.** |
| `RunSpecifiedTests` | Run only the classes named in `--tests` | Targeted hotfix when you can prove the listed classes cover all deployed Apex (>=75%) |
| `RunLocalTests` | Run all tests in the org EXCEPT managed-package tests | **Default for this project.** Required for prod. |
| `RunAllTestsInOrg` | Run every test including managed-package tests | Use when you specifically need full org test confirmation |

**Production gate:** Use `RunLocalTests` or `RunAllTestsInOrg`. Anything else fails the platform's production deploy guard.

**`RunSpecifiedTests` gotcha:** The platform validates that the specified tests deliver >=75% Apex coverage for code being deployed. If they don't, the deploy fails with `InsufficientCoverage`. Document the coverage justification when using this level.

**Spring '26 -- `RunRelevantTests`:** Some recent CLI builds expose a `RunRelevantTests` level that auto-selects tests covering changed code. Treat as experimental -- not enabled by default. Confirm before relying on it for production.

---

## 7. `package.xml` Structure

The manifest declares everything the deploy will touch. `manifest/package-case-flow-optimization.xml` is the project's canonical manifest.

```xml
<?xml version="1.0" encoding="UTF-8"?>
<Package xmlns="http://soap.sforce.com/2006/04/metadata">
    <types>
        <members>CaseTrigger</members>
        <name>ApexTrigger</name>
    </types>
    <types>
        <members>CaseTriggerHandler</members>
        <members>CaseEscalationService</members>
        <name>ApexClass</name>
    </types>
    <types>
        <members>Case_BS_Normalize_Case</members>
        <members>Case_AS_Status_SLA</members>
        <members>Case_AS_Escalation</members>
        <members>Case_AS_Linked_Case</members>
        <members>Case_AS_Routing</members>
        <members>Case_AS_Notifications</members>
        <name>Flow</name>
    </types>
    <version>66.0</version>
</Package>
```

### Rules

- Every `<types>` block has exactly one `<name>` and one or more `<members>`.
- Member names are **API names**, case-sensitive, no display names. For nested metadata, use parent prefix: `Case.Resolution_Notes__c`, `Case.CustomerService` (record type), `Case-Case Layout` (layout, hyphen separator).
- `<version>` matches `currentApiVersion` from `.claude/sf-config.json` (66.0 for Spring '26).
- Avoid `<members>*</members>` in production manifests -- wildcards inflate the package and risk deploying unintended components.
- **Never mix additive and destructive components** in one `package.xml`. Destructive items belong in a separate `destructiveChanges.xml`.

### Verifying member names

```bash
# Single-component verify
sf project retrieve start --metadata "ApexClass:CaseTriggerHandler" --target-org PlusGradeFullSB --output-dir /tmp/verify/

# List all flows in the org
sf project retrieve start --metadata "Flow:*" --target-org PlusGradeFullSB --output-dir /tmp/flows/
```

---

## 8. Dependency Order -- Critical

Salesforce metadata has hard dependencies. Out-of-order deploys fail with `INVALID_CROSS_REFERENCE_KEY`, `Field does not exist`, or `Apex test compile failure`. Order within a single manifest is platform-determined; for multi-wave releases follow this sequence.

### Wave order (this project's profile)

```
"Œ"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
"‚  Wave 1  Custom Objects / Fields / Record Types              "‚
"‚         Layouts / Compact Layouts / Validation Rules         "‚
"‚  Wave 2  Custom Metadata Types (definition) -> Records        "‚
"‚  Wave 3  Apex Triggers + Classes (deploy together)           "‚
"‚  Wave 4  Flows -- deploy as DRAFT (LogError_Subflow first)    "‚
"‚  Wave 5  LWC bundles                                         "‚
"‚  Wave 6  Named Credentials / External Credentials            "‚
"‚  Wave 7  Permission Sets -> Permission Set Groups             "‚
"‚  Wave 8  FlexiPages -> Email Templates                        "‚
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""˜
```

### Why each step

- **Objects + fields first** -- everything else (RTs, layouts, flows, Apex, LWC, perm sets) references them.
- **Record types before page layouts** -- layouts assign RTs.
- **CMDT type before CMDT records** -- records can't deploy until the type is in the org.
- **Apex triggers + classes together** -- handlers reference services; deploy as one set to resolve cross-references.
- **Subflows before parent flows** -- `LogError_Subflow` and any reusable subflow must be in the org before its caller. This is the #1 flow deployment failure.
- **LWC before FlexiPages and Screen Flows** that embed them.
- **Permission Sets after Apex** -- they reference Apex classes for access grants. PermissionSetGroups after component PermissionSets.

For this project, all Case flow migration metadata is in a single manifest (`package-case-flow-optimization.xml`) -- multi-wave is reserved for larger releases.

---

## 9. `destructiveChanges.xml` -- Component Deletion

Use destructive changes ONLY when components must be permanently removed. Naresh approves all destructive deploys in this project.

### File format -- same structure as package.xml

```xml
<?xml version="1.0" encoding="UTF-8"?>
<Package xmlns="http://soap.sforce.com/2006/04/metadata">
    <types>
        <members>OldCaseService</members>
        <name>ApexClass</name>
    </types>
    <types>
        <members>Case_OldFlow_ToBeRetired</members>
        <name>Flow</name>
    </types>
    <version>66.0</version>
</Package>
```

### Pre vs Post destructive

- `--pre-destructive-changes` -- deletes BEFORE additive changes apply. Use when the old component blocks the new one (e.g., field renamed in place).
- `--post-destructive-changes` -- deletes AFTER additive changes apply. **More common.** Old code stays available until the new code is in place.

### Deploying destructive changes

```bash
# Stand-alone destructive deploy -- needs an empty package.xml with only <version>
sf project deploy start \
  --manifest manifest/empty_package.xml \
  --post-destructive-changes manifest/destructiveChanges.xml \
  --target-org PlusGradeFullSB \
  --wait 30

# Combined -- deploy new components AND delete old ones in one operation
sf project deploy start \
  --manifest manifest/package-case-flow-optimization.xml \
  --post-destructive-changes manifest/destructiveChanges.xml \
  --target-org PlusGradeFullSB \
  --test-level RunLocalTests \
  --wait 60
```

### Rules

- **NEVER delete a custom field that contains data** without a documented data migration plan. Field deletion is permanent.
- **NEVER delete a Flow that is active or has running interviews.** Deactivate first, drain interviews, then delete.
- **NEVER delete an Apex class that is referenced** by Flow `apex://` actions, other classes, Visualforce pages, or permission sets.
- Architect or Naresh signs off on every destructive deploy.
- Test destructive changes in `PlusGradeFullSB` before any other env.

---

## 10. Retrieve Strategy

Always retrieve current state BEFORE deploying changes that overlap with existing org content -- prevents overwriting in-org changes.

```bash
# Manifest-based retrieve (default backup pattern)
sf project retrieve start --manifest manifest/package-case-flow-optimization.xml \
  --target-org PlusGradeFullSB --output-dir force-app/main/default

# Single-component inspect
sf project retrieve start --metadata "Flow:Case_AS_Routing" \
  --target-org PlusGradeFullSB --output-dir /tmp/inspect/

# Pre-deploy timestamped backup (the immediate rollback source)
sf project retrieve start --manifest manifest/package-case-flow-optimization.xml \
  --target-org PlusGradeFullSB --output-dir backup/pre-deploy-$(date +%Y%m%d-%H%M)/

# Preview without acting
sf project retrieve preview --target-org PlusGradeFullSB
```

---

## 11. Flow Activation Policy -- Project-Specific Rule

Strict flow lifecycle policy that overrides default deploy behavior:

1. **New flows deploy as `<status>Draft</status>`.** Every new `.flow-meta.xml` MUST have `<status>Draft</status>`. AI agents do not emit `<status>Active</status>`.
2. **Naresh activates new flows manually** in Flow Builder UI after sandbox functional testing.
3. **Old flows are NOT deactivated by AI agents.** Migration runs old + new in parallel; Naresh deactivates old flows manually after production validation.
4. **No `sf flow activate` commands** in agent output.

**Why:** Sandbox validation needs old + new flows simultaneously to compare behavior. Activation is a human-gate decision. Draft flows can be safely removed; Active flows with running interviews cannot.

### Pre-deploy compliance check

```bash
grep -l "<status>Active</status>" force-app/main/default/flows/Case_*.flow-meta.xml   # expected: empty
grep -L "<status>Draft</status>"  force-app/main/default/flows/Case_BS_*.flow-meta.xml \
                                  force-app/main/default/flows/Case_AS_*.flow-meta.xml   # expected: empty
```

---

## 12. Expected Test Failure Baseline

`.claude/sf-config.json` documents: **13 pre-existing Opportunity test failures are expected and do not block Case deployment.** Every `RunLocalTests` validation surfaces them. They are NOT caused by Case flow migration changes.

### Health check on a validation report

- Count Opportunity-test failures:
  - Exactly 13 -> proceed.
  - More than 13 -> new regression -- stop and investigate (out of scope but may signal a disturbed shared dependency).
  - Fewer than 13 -> someone fixed something. Update the baseline in `.claude/sf-config.json` and proceed.

### What this baseline does NOT license

- **Case-related failures must still be zero.** New failures in `CaseTriggerHandlerTest`, `CaseEscalationServiceTest`, etc. block the deploy.
- Apex code coverage gate (>=75%) still applies.
- Production deploy must still complete with `Succeeded` status -- the platform tolerates the 13 documented failures because they're pre-existing on the production baseline as well.

---

## 13. Source Tracking

Source tracking auto-detects changes between local source and the org. Available in scratch orgs and source-tracked sandboxes; not in production. Confirm before relying on `preview`:

```bash
sf org display --target-org PlusGradeFullSB --json | jq '.result.tracksSource'
# false -> manifest-based deploys only (the project default)

# When source-tracking is enabled:
sf project deploy preview --target-org Scratch
sf project deploy start   --target-org Scratch                 # deploy only changed
sf project retrieve start --target-org Scratch                 # retrieve only changed
sf project deploy start   --ignore-conflicts --target-org Scratch   # force overwrite
```

---

## 14. Smoke Test After Deploy

Quick functional confirmations, not full regression. Run immediately after each significant deploy.

- [ ] Open a Case record -- page loads, FlexiPage renders, no console errors.
- [ ] Create a new Case -- `Case_BS_Normalize_Case` fires, normalized fields populated.
- [ ] Update Case status to `Resolved` -- `Case_AS_Status_SLA` sets SLA timestamps.
- [ ] Trigger escalation -- `CaseEscalationService` creates child case via `Case_AS_Escalation`.
- [ ] Duplicate-merge linkage -- `Linked_Case__c` populated via `Case_AS_Linked_Case`.
- [ ] Change Case Owner -- `Case_AS_Routing` sets owner follower, product lookup, PBU.
- [ ] (Once OV-14 unblocks) `Case_AS_Notifications` Nexus email alert fires.
- [ ] Query AppLog: `SELECT Id, Severity__c, Message__c FROM AppLog__c WHERE CreatedDate >= TODAY AND Severity__c IN ('ERROR','FATAL')` -- confirm no new entries from deploy window.

---

## 15. Rollback

Every deploy plan must include a rollback approach BEFORE execution.

| Component | Rollback pattern |
|---|---|
| Apex Class / Trigger | `git checkout <prev> -- force-app/main/default/classes/X.cls X.cls-meta.xml` then `sf project deploy start --metadata "ApexClass:X" --target-org PlusGradeFullSB` |
| Flow (Draft in this project) | Delete the Draft flow via destructive change OR redeploy prior version from git. Old flows remain ACTIVE during migration -> customers never lose coverage. |
| Permission Set | Redeploy prior `.permissionset-meta.xml` from git via `--metadata "PermissionSet:X"` |
| Custom Field | Fields with data cannot be cleanly removed -- prefer config-level mitigation (visibility, validation) over deletion |
| FlexiPage / Layout | Redeploy prior version from git -- UI changes have zero data impact |

**Execution:** confirm the issue is real -> retrieve current state for investigation -> deploy prior version -> run Section 14 smoke tests -> document the incident (add a Section 20 Empirical Findings row if a new pattern emerged).

---

## 16. CI/CD Patterns

For automated pipelines, scope commands narrowly and always emit JSON.

```bash
# Auth (JWT bearer flow)
sf org login jwt --client-id $SF_CLIENT_ID --jwt-key-file server.key \
  --username $SF_USERNAME --alias PlusGradeFullSB

# PR validation
sf project deploy start --manifest manifest/package-case-flow-optimization.xml \
  --target-org PlusGradeFullSB --dry-run --test-level RunLocalTests \
  --wait 60 --json | tee validation.json
JOB_ID=$(jq -r '.result.id' validation.json)

# Quick deploy after manual approval
sf project deploy quick --job-id $JOB_ID --target-org PlusGradeFullSB --wait 30 --json
```

**Branch strategy:** `feature/*` -> dry-run only on PlusGradeFullSB; `main` -> full validation + Naresh-approved quick deploy.

---

## 17. Required Agent Output Contract

Every deployment plan or command produced by an AI agent in this repo MUST include all of the following. If a section is N/A, state why explicitly.

1. **Scope** -- manifest path or explicit `--metadata` list.
2. **Dependency order review** -- list each component group and why this order works.
3. **Validation command** -- exact `sf project deploy start --dry-run` invocation with correct flags.
4. **Test level + justification** -- which level, why it was chosen, expected baseline failures called out.
5. **Quick deploy command** -- with a placeholder `$JOB_ID` for the validation output.
6. **Destructive changes** -- separate file referenced via `--pre-destructive-changes` or `--post-destructive-changes`; never mixed into the additive manifest.
7. **Flow status check** -- confirm every flow in the manifest has `<status>Draft</status>` (project rule Section 11 8. **Smoke test plan** -- specific checks matched to the deployed components.
9. **Rollback plan** -- concrete prior-version redeploy commands.

Failure to include any section is non-compliant.

---

## 18. Validation Commands Quick Reference

```bash
# Project-default validation
sf project deploy start --manifest manifest/package-case-flow-optimization.xml \
  --target-org PlusGradeFullSB --dry-run --test-level RunLocalTests --wait 60

# Quick deploy after validation
sf project deploy quick --job-id 0AfXXXXXXXXXXXX --target-org PlusGradeFullSB --wait 30

# Pre-deploy backup
sf project retrieve start --manifest manifest/package-case-flow-optimization.xml \
  --target-org PlusGradeFullSB --output-dir backup/prod-$(date +%Y%m%d)/

# Status + cancel
sf project deploy report --use-most-recent --target-org PlusGradeFullSB
sf project deploy cancel --job-id 0AfXXXXXXXXXXXX --target-org PlusGradeFullSB

# Targeted test validation
sf project deploy start --manifest manifest/package-case-flow-optimization.xml \
  --target-org PlusGradeFullSB --dry-run --test-level RunSpecifiedTests \
  --tests CaseTriggerHandlerTest,CaseEscalationServiceTest --wait 60

# Single-component hotfix
sf project deploy start --metadata "ApexClass:CaseEscalationService" \
  --target-org PlusGradeFullSB --test-level RunSpecifiedTests \
  --tests CaseEscalationServiceTest --wait 15
```

---

## 19. Common AI Mistakes to Avoid

The following are errors that AI agents frequently make when generating deployment plans. Every agent output MUST be checked against this list.

| # | Mistake | Correct Approach |
|---|---|---|
| 1 | Wrong dependency order -- Flow deployed before its custom fields; FlexiPage before its LWC; Permission Set before the Apex it grants access to | Resolve dependency order before building the manifest; deploy infrastructure metadata first |
| 2 | Using `NoTestRun` for production deployments | Always use `RunLocalTests` or higher for production; `NoTestRun` is sandbox-only |
| 3 | Mixing additive and destructive changes in one manifest | Isolate destructiveChanges.xml; deploy destructive changes separately and with explicit approval |
| 4 | Quick deploy without a prior check-only validation | Always run `--check-only` first; only quick-deploy after a successful validation within the 10-day window |
| 5 | No rollback plan documented | Every deployment plan must include a documented rollback procedure before execution |
| 6 | Deploying Named Credentials without verifying callout connectivity | Named Credentials may require manual secret/credential setup in the target org after metadata deployment -- verify connectivity post-deploy |
| 7 | Deploying Flows that reference inactive or missing subflows | LogError_Subflow and all called subflows must be active in the target org before the calling flow is deployed |
| 8 | Not retrieving the current production state before deploying | Always retrieve a backup and commit it to source control before modifying production |
| 9 | Incorrect member names -- display names instead of API names; wrong parent object prefix on fields | Use API names throughout; double-check field names include the object prefix (e.g. `Case.Status`) |
| 10 | Omitting test classes from package.xml | Test classes must be included in the manifest alongside the Apex code they test |
| 11 | Wrong `--target-org` alias | Always verify the alias before executing; use `sf org list` to confirm |
| 12 | Assuming quick deploy is always available | The 10-day validation window may have expired; re-run check-only if unsure |

---

## 20. Empirical Findings & Implementation Notes

When Salesforce's documented approach doesn't work in this org, the workaround goes here. Date-stamp every entry.

*(No entries yet -- add a row the first time a deployment surfaces a docs vs reality gap.)*

| # | Date | Documented approach | What actually works | Why / Context |
|---|---|---|---|---|

---

## 21. Official References

- [SFDX Developer Guide](https://developer.salesforce.com/docs/atlas.en-us.sfdx_dev.meta/sfdx_dev/)
- [Salesforce CLI Command Reference](https://developer.salesforce.com/docs/atlas.en-us.sfdx_cli_reference.meta/sfdx_cli_reference/)
- [Metadata API Deploy](https://developer.salesforce.com/docs/atlas.en-us.api_meta.meta/api_meta/meta_deploy.htm)
- [Quick Deploy Help](https://help.salesforce.com/s/articleView?id=sf.deploy_quick.htm)
- [Metadata Coverage Report](https://developer.salesforce.com/docs/metadata-coverage)
- [Salesforce CLI Release Notes (GitHub)](https://github.com/forcedotcom/cli/releases)
- `forcedotcom/sf-skills/deploying-metadata/SKILL.md` (v1.1, the canonical CLI v2 skill -- bundled at `/tmp/sf-skills/skills/deploying-metadata/`)
- Project config: `.claude/sf-config.json` (org alias, manifest, API version, expected test failures)
- Project policy: `CLAUDE.md` Section 3 Case flow migration rules -- Draft status, no AI activation, baseline test failures)

---

*Deployment Guidelines | v3.0 | Last verified 2026-05-16 | PlusGradeFullSB | API v66.0 (Spring '26)*

