---
name: salesforce-observability
description: Production Salesforce AI skill for Logging, telemetry, monitoring, incident triage, Agentforce session traces, STDM/Data Cloud observability, and production agent behavior analysis.
license: Apache-2.0
compatibility:
  - Claude Code
  - Claude Agents
  - Codex / ChatGPT
  - GitHub Copilot
metadata:
  version: 2.0.0
  last_updated: 2026-05-20
  owner: Reusable Salesforce AI Skills Library
---

## TRIGGER when
- The task involves Logging, telemetry, monitoring, incident triage, Agentforce production session analysis, STDM session trace data, Data Cloud trace records, agent quality metrics, or production agent regressions.
- The user asks for implementation, refactor, troubleshooting, review, or best-practice validation in this area.
- The assistant must produce Salesforce-safe code/metadata with explicit security/testing notes.

## DO NOT TRIGGER when
- The task is unrelated to this component.
- Another specialized skill is the primary owner and this area is only incidental.
- The user asks for operational execution (deploy/publish/activate/destructive change) without explicit approval.

## Cross-skill routing
- Always read `../salesforce-global-development/SKILL.md`.
- Also read: Global Development + Integration + Apex + Flow.
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
Generate/request correlation ID per transaction. Classify errors (validation/integration/platform/business). Keep logs PII-safe and redact sensitive values. Track retry attempts and final disposition.

## Agentforce ADLC observability
Use the Agentforce ADLC observe/reproduce/improve loop for published or production-like agents:

1. **Observe**: Query production session evidence from Data Cloud STDM when available; otherwise fall back to Testing Center runs plus local preview traces.
2. **Reproduce**: Convert each confirmed production issue into a preview scenario and run it repeatedly with local traces.
3. **Improve**: Apply minimal `.agent` edits, validate, test adjacent paths, and only publish/activate after explicit approval.

Gather these inputs before starting: org alias, agent display/API name, optional `.agent` file path, optional session IDs, and lookback window (default 7 days).

### Agent name resolution
Before STDM queries, resolve the user-provided name against the org:

```bash
sf data query --json --query "SELECT Id, MasterLabel, DeveloperName FROM GenAiPlannerDefinition WHERE MasterLabel LIKE '%<name>%' OR DeveloperName LIKE '%<name>%'" -o <org>
```

Use `MasterLabel` for STDM session filters. Use `DeveloperName` without a trailing `_vN` suffix for `sf agent` CLI commands.

### Data Space and STDM checks
- Discover active Data Cloud data spaces with `sf api request rest "/services/data/vXX.X/ssot/data-spaces" -o <org>`. This beta command may not accept `--json`; read the returned JSON-like payload directly.
- If exactly one active data space exists, use it and state the assumption. If multiple active spaces exist, ask the user which one to use.
- Check whether STDM DMOs are available before querying session traces. If STDM is absent, tell the user and switch to the fallback path: existing test suites plus `sf agent preview --authoring-bundle` local traces.

### Fallback path when STDM is unavailable
1. Run any existing test suite with `sf agent test run --json --api-name <Suite> --wait 10 --result-format json -o <org>`.
2. If no suite exists, derive utterances from subagents, actions, guardrails, safety probes, and multi-turn transitions.
3. Run preview with `--authoring-bundle` to create local traces under `.sfdx/agents/<BundleName>/sessions/<SessionId>/traces/`.
4. Diagnose from trace evidence, not preview text alone.

### Issue classification
Prioritize issues as:
- P1: action errors, wrong subagent routing, LOW adherence/safety, prompt leakage, injection compliance.
- P2: missing actions, variable capture bugs, knowledge gaps, permission blockers, grounding failures.
- P3: slow actions, abandoned sessions, dead subagents, noisy logs, minor response-quality drift.

Classify root causes as agent config, instructions, action contract, permissions, data/knowledge availability, backing logic, platform limitation, or test/data defect.

### Reproduce and improve
- Build one reproduction scenario per confirmed issue and run it three times. Mark `[CONFIRMED]` for 3/3 failures, `[INTERMITTENT]` for 1-2/3 failures, and `[NOT REPRODUCED]` for 0/3 failures.
- Only confirmed or intermittent issues should move to `.agent` edits.
- Before editing, establish baseline traces. After each edit, validate, preview the changed path, then test adjacent paths.
- Create or update Testing Center regression cases for confirmed production issues.
- Re-run safety review after behavior edits and block publish if the change introduces unsafe behavior.

## Examples
### Good example patterns
1. Structured log object includes correlationId, component, severity, errorCode.
2. Platform Event emits failure diagnostics without customer payload data.

### Bad examples / avoid
1. Logging full request payload with personal data.
2. Swallowing exceptions with no alertable trail.

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

# Observability & Logging Guidelines

Authoritative rules for logging, error tracing, and operational visibility across Apex, Flow, LWC, and integrations in the Reusable Salesforce Agent Guidelines org.

**Verified against:** the deployed `AppLogger.cls` and `AppLoggerTest.cls` in `force-app/main/default/classes/`, the `Agent_Activity_Log__c` schema in `force-app/main/default/objects/`, [forcedotcom/sf-skills `debugging-apex-logs`](https://github.com/forcedotcom/sf-skills/tree/main/skills/debugging-apex-logs), [Apex Developer Guide -- Debug Log](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_debugging_debug_log.htm), [System.Logger class](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Logger.htm), [Platform Events](https://developer.salesforce.com/docs/atlas.en-us.platform_events.meta/platform_events/), [Real-Time Event Monitoring](https://help.salesforce.com/s/articleView?id=sf.real_time_event_monitoring_overview.htm). Last verified 2026-05-16.

> **Project reality check (read this first).** The deployed `AppLogger` in the target environment is a **single-method shim** that writes to the existing `Agent_Activity_Log__c` custom object. It is NOT the multi-method `AppLog__c` design that earlier drafts of this file imagined. Match the deployed signature: `AppLogger.log(context, AppLogger.Severity, message, recordId)`. If a future task requires a richer logger, expand the shim -- do not invent calls (`AppLogger.info`, `AppLogger.error(... Exception)`, `AppLogger.generateCorrelationId`) that don't exist.

---

## 1. Core Principles

These are non-negotiable. Every logging implementation MUST comply.

1. **Logging never blocks business logic.** Every log insert uses `Database.insert(record, false)` (allOrNone = false). A logging failure must never bubble up. The deployed `AppLogger.log` additionally wraps the body in `try/catch` and sinks any logging-internal exception to `System.debug(LoggingLevel.ERROR, ...)`.
2. **Every critical operation logs entry, success, and failure.** For any DML, callout, async job, or business-consequential decision, emit:
   - **Entry** (INFO): "Starting `<operation>` for `<recordId>`"
   - **Success** (INFO): "Completed `<operation>` for `<recordId>`"
   - **Failure** (ERROR): "Failed `<operation>` for `<recordId>`: `<sanitized message>`"
3. **Errors carry actionable context.** Every ERROR row needs: component (`Class.method` or flow API name), operation, related record Id, sanitized message, and timestamp. Anything less forces a re-run to gather context.
4. **Logs are queryable records, not transient debug output.** `System.debug` is for local development. Production diagnosis needs SOQL-able rows so reports, dashboards, and alerts can find them.
5. **Correlation IDs trace multi-step operations.** Any operation that crosses an Apex -> Flow -> Queueable -> Batch -> callout boundary must propagate a shared correlation token. Without it, cross-component tracing relies on timestamp matching -- unreliable in async contexts.
6. **No PII, no secrets, ever.** Sanitize before insert. See Section 8 7. **Use the right level.** Misusing levels makes alerting noisy and reports useless. See Section 2 2. Log Levels -- Semantic Definitions

The deployed `AppLogger.Severity` enum exposes three values: `INFO`, `WARNING`, `ERROR`. The Apex `System.Logger` class and the Salesforce debug-log subsystem support a wider set (`DEBUG`, `INFO`, `WARN`, `ERROR`, `FATAL` plus the `FINE`/`FINER`/`FINEST` debug-log levels). Use the table below.

| Level | When to use | Persisted by `AppLogger` | Debug log only |
|---|---|:-:|:-:|
| `DEBUG` | Fine-grained diagnostic detail. Not for production logging. | | yes |
| `INFO` | Normal operational milestone -- start, completion, key decision | yes (`Status__c = Success`) | yes |
| `WARNING` / `WARN` | Unexpected condition that was handled; investigate later | yes (`Status__c = Success`) | yes |
| `ERROR` | A handled failure; populates `Error__c`; requires investigation | yes (`Status__c = Error`) | yes |
| `FATAL` | Critical failure with potential corruption or data loss. Currently maps to `ERROR` in the deployed shim until a `FATAL` severity is added. | maps to ERROR | yes |

`WARNING` and `INFO` both serialize to `Status__c = 'Success'` in the deployed schema. The severity prefix in `Agent_Comments__c` (`[WARNING] ...` vs `[INFO] ...`) is what reports filter on.

---

## 3. The Deployed Logger -- `AppLogger` Contract

**File:** `force-app/main/default/classes/AppLogger.cls`
**Sharing:** `without sharing` -- logging must succeed regardless of running-user record access.
**Failure mode:** internal `try/catch`; logging-internal errors are swallowed to `System.debug`.

### Public surface (the ONLY public method)

```apex
public static void log(String context, Severity sevLevel, String message, Id recordId);

public enum Severity { INFO, WARNING, ERROR }
```

| Parameter | Required | Purpose |
|---|---|---|
| `context` | recommended | `Class.method` form, e.g. `'GetCaseContextAction.execute'`. Null renders as `(no-context)` -- avoid. |
| `sevLevel` | recommended | `INFO`, `WARNING`, or `ERROR`. Null defaults to `INFO`. |
| `message` | yes | Sanitized message. Never raw PII or full HTTP body. |
| `recordId` | optional | If a Case Id, it is stamped on `Case__c` for relationship reporting. Non-Case Ids are accepted but do not populate `Case__c`. |

### Where logs land

`AppLogger.log` inserts a row into the existing `Agent_Activity_Log__c` object with these fixed picklist values:

| Field | Value |
|---|---|
| `Action_Name__c` | `Agent_Invocation` |
| `AI_Tool_Name__c` | `Agent Chat` |
| `Source__c` | `UI_Chat` |
| `Status__c` | `Error` if severity = ERROR, else `Success` |
| `Error__c` | message abbreviated to 5000 chars -- only set on ERROR |
| `Agent_Comments__c` | `[<SEVERITY>] <context> | <message>` abbreviated to 32000 chars |
| `Case__c` | lookup populated only when `recordId.getSobjectType() == Case.SObjectType` |

### Canonical usage

```apex
// Entry, success, failure for a critical action
public class GetCaseContextAction {
    @InvocableMethod(label='Get Case Context')
    public static List<Response> execute(List<Request> reqs) {
        Id caseId = reqs[0].caseId;
        AppLogger.log('GetCaseContextAction.execute', AppLogger.Severity.INFO,
            'Starting context load', caseId);
        try {
            // ... real work ...
            AppLogger.log('GetCaseContextAction.execute', AppLogger.Severity.INFO,
                'Context loaded successfully', caseId);
            return out;
        } catch (Exception e) {
            AppLogger.log('GetCaseContextAction.execute', AppLogger.Severity.ERROR,
                e.getMessage() + ' | ' + e.getStackTraceString(), caseId);
            // re-throw or return an error response per the action's contract
            throw e;
        }
    }
}
```

### What the deployed shim does NOT have

These are commonly imagined methods that **do not exist** in `AppLogger.cls`. Do not call them.

- `AppLogger.info(...)`, `AppLogger.warn(...)`, `AppLogger.error(...)`, `AppLogger.fatal(...)`
- `AppLogger.error(component, correlationId, operation, Exception e)` -- no overload accepts an `Exception` directly. Pass `e.getMessage() + ' | ' + e.getStackTraceString()` as the message.
- `AppLogger.integration(...)`, `AppLogger.async(...)`, `AppLogger.asyncError(...)`
- `AppLogger.generateCorrelationId()` -- generate inline (see Section 5 A `FATAL` severity -- currently absent. Use `ERROR` until the enum is extended.

If a feature genuinely needs one of these, add it to `AppLogger.cls` and update this section. Do not write code that assumes them.

### Fallback when `AppLogger` is not in the target environment

`AppLogger` is a project-internal class, not a managed package or native API. Before referencing it in any new class, verify it exists in the target environment (`sf project retrieve start --metadata ApexClass:AppLogger ...`). If absent, use Apex's built-in `System.debug` with explicit level and add a TODO:

```apex
// TODO: replace with AppLogger.log once it is deployed to the target environment
System.debug(LoggingLevel.ERROR, 'GetCaseContextAction.execute | ' + e.getMessage());
```

This is mistake #11 in the table at the bottom -- the most common deployment failure when porting code between orgs.

---

## 4. Built-in Apex Logging -- `System.debug` and `System.Logger`

### `System.debug`

`System.debug(LoggingLevel.ERROR, message)` writes to the transient **debug log** captured by an active trace flag for the running user. Debug logs are not records, are not queryable with SOQL, and disappear when the trace flag expires or the log is overwritten. Use `System.debug` for:

- Local development and ad-hoc diagnosis under an active trace flag.
- The `try/catch` fallback path inside logging code itself (see `AppLogger` self-failure handler).
- Pre-`AppLogger` code paths where the persistent logger isn't yet deployed.

**Always pass a `LoggingLevel`** so the message survives at the configured Apex Code debug level:

```apex
System.debug(LoggingLevel.ERROR, 'GetCaseContextAction: ' + e.getMessage());
System.debug(LoggingLevel.WARN,  'Unexpected response shape: ' + payload);
System.debug(LoggingLevel.INFO,  'Processing batch chunk size ' + scope.size());
```

Apex `LoggingLevel` enum (in order of severity, broadest to narrowest): `NONE`, `ERROR`, `WARN`, `INFO`, `DEBUG`, `FINE`, `FINER`, `FINEST`.

### `System.Logger` (Apex)

`System.Logger` is the platform's structured logger that integrates with Event Monitoring and the debug log. It exposes `debug(...)`, `info(...)`, `warn(...)`, `error(...)`, and `fatal(...)` methods. Useful for cross-org telemetry when Event Monitoring is licensed. **Not currently used in this project** -- `AppLogger` is the standard. Treat `System.Logger` as a future option, not an alternative for new code today.

### Debug log retention

| Setting | Default | Notes |
|---|---|---|
| Per-log max size | 20 MB | logs truncated at the head when exceeded |
| Org-wide log retention | 7 days | rolling -- older logs purged automatically |
| Per-user trace flag duration | up to 24 hours | renew via Setup > Debug Logs or `tooling/sobjects/TraceFlag` |

Because logs are transient and capped, **never rely on debug logs as the operational audit trail.** Persist to `Agent_Activity_Log__c` via `AppLogger`.

---

## 5. Correlation IDs

A correlation ID is a token assigned at the entry point of a multi-step operation and propagated to every subsequent step. With it, one SOQL filter retrieves the full trace.

### Format

```apex
// Inline -- no helper method on the deployed AppLogger
String correlationId = String.valueOf(UserInfo.getUserId()).substring(0, 15)
    + '-' + String.valueOf(System.currentTimeMillis());
// e.g. <user-id-prefix>-1747400000000
```

Use the same format consistently so reports can group by token prefix.

### Including the correlation ID in the log

The deployed `AppLogger` does not have a dedicated correlation-id column. Include the token in the `message` argument (it lands in `Agent_Comments__c`, which is searchable):

```apex
String cid = generateCorrelationId();
AppLogger.log('CaseService.process', AppLogger.Severity.INFO,
    'cid=' + cid + ' Starting case processing', caseId);
```

If correlation-id traceability becomes a frequent need, add a dedicated `Correlation_Id__c` text(255) field to `Agent_Activity_Log__c` and extend the shim -- document the change here.

### Propagating across boundaries

| Boundary | Mechanism |
|---|---|
| Apex -> Apex | pass `correlationId` as a method parameter |
| Apex -> Queueable | constructor argument; store as instance field |
| Apex -> Batch | constructor argument; capture `ctx.getJobId()` in `start`/`execute`/`finish` |
| Apex -> Flow (Invocable) | `@InvocableVariable String correlationId` on input class |
| Flow -> Apex | output the token from the parent flow, pass to invocable |
| Apex -> External HTTP | `req.setHeader('X-Correlation-Id', correlationId);` |
| Inbound REST | read `RestContext.request.headers.get('X-Correlation-Id')`; generate one if missing |

### Async job IDs

Capture the Salesforce async job ID where available -- it's the primary correlation handle for batch and queueable contexts:

```apex
Id qJobId = System.enqueueJob(new CaseProcessingJob(cid));
AppLogger.log('CaseService.enqueue', AppLogger.Severity.INFO,
    'cid=' + cid + ' queueable=' + qJobId, caseId);
```

Inside the job, log the `BatchableContext.getJobId()` / `QueueableContext.getJobId()` for the start and finish events.

---

## 6. Logging in Flows -- `LogError_Subflow`

Every record-triggered or autolaunched flow that performs DML or invokes an Apex action MUST have a fault path that routes to a shared `LogError_Subflow`.

### LogError_Subflow contract

- **Type:** Autolaunched Flow (no trigger)
- **API Name:** `LogError_Subflow`
- **Inputs:**
  - `input_FlowName` (Text, required) -- `{!$Flow.CurrentFlowApiName}`
  - `input_RecordId` (Text, optional) -- `{!$Record.Id}`
  - `input_ElementName` (Text, optional) -- literal name of faulted element
  - `input_ErrorMessage` (Text, optional) -- `{!$Flow.FaultMessage}`
- **Body:** one Create Records element targeting `Agent_Activity_Log__c` with:
  - `Action_Name__c = 'Agent_Invocation'`
  - `AI_Tool_Name__c = 'Agent Chat'`
  - `Source__c = 'UI_Chat'`
  - `Status__c = 'Error'`
  - `Error__c = {!input_ErrorMessage}`
  - `Agent_Comments__c = '[ERROR] ' + {!input_FlowName} + '.' + {!input_ElementName} + ' | ' + {!input_ErrorMessage}`
  - `Case__c = {!input_RecordId}` (only when the calling flow is on Case; gate with a Decision)
- **Fault path on the Create Records element:** routes to End. **Never re-throw from a logging subflow** -- a logging failure must be silent.

### Wiring in calling flows

For every DML element and every Apex action element:
1. Add a Subflow element pointing to `LogError_Subflow`.
2. Map inputs as above.
3. Connect the **fault connector** of the DML / action element to this Subflow element.
4. From the Subflow element, connect to an End element. Do not re-trigger the failed branch.

See `../salesforce-flow/SKILL.md` for the canonical fault-path pattern.

---

## 7. Integration Logging Pattern

Every outbound callout MUST log: start, status code, duration, and (on failure) a sanitized message snippet.

```apex
public with sharing class ExternalCaseApiClient {

    private static final String SYSTEM_NAME = 'ExternalCaseAPI';

    public static ExternalCaseResponse createCase(CasePayload payload, Id caseId) {
        String cid = String.valueOf(UserInfo.getUserId()).substring(0, 15)
            + '-' + String.valueOf(System.currentTimeMillis());
        Long t0 = System.currentTimeMillis();

        AppLogger.log('ExternalCaseApiClient.createCase', AppLogger.Severity.INFO,
            'cid=' + cid + ' starting outbound call to ' + SYSTEM_NAME, caseId);

        try {
            HttpRequest req = buildRequest(payload);
            req.setHeader('X-Correlation-Id', cid);
            HttpResponse res = new Http().send(req);
            Long ms = System.currentTimeMillis() - t0;

            if (res.getStatusCode() < 400) {
                AppLogger.log('ExternalCaseApiClient.createCase', AppLogger.Severity.INFO,
                    'cid=' + cid + ' status=' + res.getStatusCode() + ' duration=' + ms + 'ms', caseId);
                return parse(res);
            } else {
                AppLogger.log('ExternalCaseApiClient.createCase', AppLogger.Severity.ERROR,
                    'cid=' + cid + ' status=' + res.getStatusCode()
                    + ' duration=' + ms + 'ms body=' + res.getBody().abbreviate(500), caseId);
                throw new IntegrationException(SYSTEM_NAME + ' returned ' + res.getStatusCode());
            }
        } catch (CalloutException e) {
            Long ms = System.currentTimeMillis() - t0;
            AppLogger.log('ExternalCaseApiClient.createCase', AppLogger.Severity.ERROR,
                'cid=' + cid + ' callout-failed duration=' + ms + 'ms ' + e.getMessage(), caseId);
            throw e;
        }
    }
}
```

### Integration log checklist

- [ ] Correlation ID generated at entry, passed in `X-Correlation-Id` header AND inside the log message
- [ ] Start logged at INFO before the callout
- [ ] Duration captured via `System.currentTimeMillis()` before/after
- [ ] HTTP status code recorded on every response
- [ ] Response body abbreviated to 500 chars on error -- never log full bodies (may contain tokens or PII)
- [ ] Endpoint configured via Named Credential -- never hardcoded
- [ ] Exception path logs and re-throws; never swallow silently

---

## 8. Safe Logging -- PII and Secret Redaction

### Never log

| Category | Examples | Why |
|---|---|---|
| Authentication credentials | passwords, API keys, OAuth tokens, JWT secrets, basic-auth headers | credential exposure |
| Payment card data | full PAN, CVV | PCI-DSS violation |
| Government identifiers | SSN, passport, national ID | privacy regulation |
| Full HTTP request/response bodies | anything that may contain the above | unbounded PII risk |
| Session tokens | Salesforce session IDs, JSESSIONID | session hijacking |
| Medical / health data | diagnoses, prescriptions, test results | HIPAA |

### Safe to log

Salesforce record Ids, operation names, component names, sanitized error messages, HTTP status codes, durations, correlation IDs, async job IDs, timestamps (auto-populated via `CreatedDate`).

### Inline sanitization

The deployed `AppLogger` does NOT sanitize. Callers are responsible. Sanitize before passing into `AppLogger.log`. A baseline pattern:

```apex
private static String sanitize(String input) {
    if (input == null) return null;
    if (input.length() > 30000) {
        input = input.substring(0, 30000) + '... [TRUNCATED]';
    }
    return input
        .replaceAll('[0-9]{4}[- ]?[0-9]{4}[- ]?[0-9]{4}[- ]?[0-9]{4}', '[CARD_REDACTED]')
        .replaceAll('[\\w._%+\\-]+@[\\w.\\-]+\\.[a-zA-Z]{2,}',         '[EMAIL_REDACTED]')
        .replaceAll('[0-9]{3}-[0-9]{2}-[0-9]{4}',                       '[SSN_REDACTED]')
        .replaceAll('Bearer\\s+[A-Za-z0-9._\\-]+',                      'Bearer [TOKEN_REDACTED]')
        .replaceAll('password["\\\']?\\s*[=:]\\s*["\\\']?[^\\s"\\\'&,]+', 'password=[REDACTED]');
}
```

If sanitization needs to be centralized, add it to `AppLogger.cls` so every caller benefits -- and document the change here.

---

## 9. Structured vs Free-Text Messages

Free-text messages are searchable but slow to aggregate. Structured `key=value` fragments inside the message let reports filter precisely.

**Preferred -- structured key=value:**

```
cid=<user-id-prefix>-1747400000000 op=ProcessInbound caseId=<case-id> status=ok duration=145ms
```

**Avoid -- prose:**

```
Started processing the inbound case from the queue, then it worked fine after a bit
```

Structured tokens to standardize on:

| Token | Meaning |
|---|---|
| `cid=` | correlation ID |
| `op=` | operation name |
| `caseId=` / `recordId=` | related record (in addition to the `recordId` arg) |
| `status=` | HTTP status code or business outcome |
| `duration=` | milliseconds |
| `count=` | record count for bulk operations |
| `jobId=` | async job ID |

---

## 10. Logging in Async Contexts

### Queueable

```apex
public class CaseProcessingJob implements Queueable, Database.AllowsCallouts {
    private final String correlationId;
    private final Id caseId;

    public CaseProcessingJob(String cid, Id caseId) {
        this.correlationId = cid;
        this.caseId = caseId;
    }

    public void execute(QueueableContext ctx) {
        AppLogger.log('CaseProcessingJob.execute', AppLogger.Severity.INFO,
            'cid=' + correlationId + ' jobId=' + ctx.getJobId() + ' starting', caseId);
        try {
            // work
            AppLogger.log('CaseProcessingJob.execute', AppLogger.Severity.INFO,
                'cid=' + correlationId + ' jobId=' + ctx.getJobId() + ' success', caseId);
        } catch (Exception e) {
            AppLogger.log('CaseProcessingJob.execute', AppLogger.Severity.ERROR,
                'cid=' + correlationId + ' jobId=' + ctx.getJobId()
                + ' ' + e.getMessage() + ' | ' + e.getStackTraceString(), caseId);
            throw e;
        }
    }
}
```

### Batch Apex

Log at three points; **never log inside the per-record loop** (creates one row per source record, explodes governor limits):

- `start()` -- INFO with job ID and scope size
- `execute()` -- ERROR on any caught exception (summarized; not per-record)
- `finish()` -- INFO with job ID and a summary row count

### Scheduled Apex

Log entry in `execute(SchedulableContext)`; if the scheduled job hands off to a batch, log the batch enqueue.

### Platform Event Triggers

Log in the Apex Platform Event trigger using `AppLogger`. For platform-event-triggered flows, route fault paths to `LogError_Subflow` as in any other flow.

---

## 11. Platform Events for Cross-Org Logging

Use a Platform Event (`AppLogEvent__e`) only when logs must leave the org in near-real-time -- for example, fanning out to Splunk, Datadog, or a SIEM via the Streaming API.

| Use case | Mechanism |
|---|---|
| In-org operational visibility (reports, dashboards, alerts) | `Agent_Activity_Log__c` via `AppLogger.log` (current default) |
| External SIEM / log aggregator near real-time | `EventBus.publish(new AppLogEvent__e(...))` -- subscribed by external CometD client |
| Cross-test environment aggregation | Platform Event published to a central org's API |

A Platform Event is fire-and-forget; subscribers may miss events if Replay IDs fall behind. **Always pair Platform Event publishing with a persistent `Agent_Activity_Log__c` row** -- the platform event is the streaming projection, the record is the source of truth.

### Real-Time Event Monitoring

If the org has **Shield Event Monitoring** licensed, the platform emits standard events (`ApiEvent`, `LoginEvent`, `LogoutEvent`, `ReportEvent`, etc.) as Real-Time Event Monitoring events. These are a separate stream from the project's `AppLog` events and require no custom code; subscribe via CometD or stream to a SIEM. Use them for security and access-pattern monitoring -- they are not a substitute for application-level operational logging.

---

## 12. Reports, Dashboards, Alerts

### Standard reports to build on `Agent_Activity_Log__c`

| Report | Filter | Group by | Purpose |
|---|---|---|---|
| Error hotspots -- last 7 days | `Status__c = Error` AND `CreatedDate = LAST_7_DAYS` | `Agent_Comments__c` prefix or extracted component | top noisy components |
| Integration health -- today | `Agent_Comments__c contains 'ExternalCaseAPI'` AND `CreatedDate = TODAY` | status code in message | external dep monitoring |
| Flow fault trend -- 30 days | `Agent_Comments__c contains 'Flow'` AND `Status__c = Error` | day | unstable flow detection |
| Async job failures -- 7 days | `Agent_Comments__c contains 'jobId='` AND `Status__c = Error` | day | batch/queueable health |

Dashboard: **"Org Operational Health"** -- error-rate gauge, integration error count, flow fault line chart, error-hotspot table, async-failure table. Refresh daily; subscribe ops team.

### Alert conditions

| Condition | Threshold | Urgency | Channel |
|---|---|---|---|
| `Status__c = Error` with `Agent_Comments__c contains 'FATAL'` (once the FATAL severity exists) | any single | immediate | Slack + Email |
| Same component ERROR count | 3+ in 5 min | high | Slack |
| Integration 401/403 in message | any occurrence | immediate | Slack + Email |
| Integration 5xx in message | 3+ in 10 min | high | Slack |

Implement via record-triggered flow on `Agent_Activity_Log__c` calling a notification action, or via Platform Event subscription if alert volume is high.

---

## 13. Retention

| Severity | Retention | Rationale |
|---|---|---|
| INFO / Success rows | 30 days | operational history one month back |
| WARNING (Success status) | 90 days | warning-trend analysis |
| ERROR | 180 days | root-cause investigation window |
| FATAL (when introduced) | 365 days | compliance and post-incident review |

Implement with a weekly scheduled batch that deletes by `Status__c` + `CreatedDate` cutoff using `Database.delete(scope, false)`.

---

## 14. Common AI Mistakes to Avoid

| # | Mistake (brief) | Correct approach |
|---|---|---|
| 1 | Using `System.debug()` as production logging | persist via `AppLogger.log(...)` so logs are queryable, reportable, and survive trace-flag expiry |
| 2 | Logging raw PII / secrets / full HTTP bodies | sanitize before passing into `AppLogger.log`; abbreviate response bodies to 500 chars |
| 3 | `insert log;` instead of `Database.insert(log, false)` | always allOrNone=false -- logging failure must not fail the business transaction |
| 4 | No correlation ID across multi-step ops | generate `<userPrefix>-<millis>` at entry and propagate via parameter, header, or invocable input |
| 5 | No logging in integration HTTP client | log start, status, duration, and error on every callout -- integrations are the #1 incident source |
| 6 | No `LogError_Subflow` on flow fault paths | every DML / action element fault connector routes to `LogError_Subflow` |
| 7 | Building dashboards before the log object is in production | deploy `Agent_Activity_Log__c` (or the future `AppLog__c`) first, validate writes, then build reports |
| 8 | Not truncating long messages | abbreviate to 5000 chars for `Error__c` and 32000 for `Agent_Comments__c` -- `AppLogger` does this for you; do it yourself if calling other inserts |
| 9 | Logging inside a per-record loop | log a summary after the loop; per-record logging blows governor limits and dashboard counts |
| 10 | Missing component name in the log | always pass `Class.method` form as `context` -- `(no-context)` rows are unactionable |
| 11 | Referencing `AppLogger` when it is not deployed in the target environment | `AppLogger` is a project standard pattern but is not a managed package or native Salesforce class. If it does not exist as a deployed Apex class in the target environment, every class that references it will fail to compile. Before using `AppLogger` in any service class, verify it exists in the target environment. If it does not, fall back to `System.debug(LoggingLevel.ERROR, context + message)` and add a TODO comment to migrate once `AppLogger` is deployed. Never assume `AppLogger` is present just because the guidelines recommend it. |
| 12 | Calling imaginary `AppLogger` overloads (`AppLogger.info(...)`, `AppLogger.error(component, cid, op, Exception)`, `AppLogger.generateCorrelationId()`) | the deployed shim has exactly one method: `log(String, Severity, String, Id)`. Compose richer behavior inline or extend `AppLogger.cls` and update this doc |
| 13 | Passing a non-Case Id as `recordId` and expecting `Case__c` to populate | `AppLogger` only stamps `Case__c` when `recordId.getSobjectType() == Case.SObjectType`. Other record types are ignored on the Case lookup |
| 14 | Logging a `FATAL` severity literal in the message and expecting alerting | `Severity.FATAL` does not exist on the deployed enum. Use ERROR; if you need fatal semantics, extend the enum and add a `Severity` field to the object |

---

## 15. Empirical Findings & Implementation Notes

| # | Date | Documented approach | What actually works | Why / Context |
|---|---|---|---|---|
| 1 | 2026-05-16 | Earlier drafts of this guideline assumed an `AppLog__c` custom object with `Level__c`, `Component__c`, `CorrelationId__c`, etc. | The deployed `AppLogger` in <target-env-alias> writes to the pre-existing `Agent_Activity_Log__c` object using fixed picklist values (`Action_Name__c='Agent_Invocation'`, `AI_Tool_Name__c='Agent Chat'`, `Source__c='UI_Chat'`). Component + message + severity are concatenated into `Agent_Comments__c`. No `AppLog__c` exists. | Verified by reading `force-app/main/default/classes/AppLogger.cls` and the `Agent_Activity_Log__c` field directory on 2026-05-16. Future migrations to a dedicated `AppLog__c` need a deliberate refactor. |
| 2 | 2026-05-16 | `AppLogger.error(component, correlationId, operation, Exception e)` and similar typed overloads were prescribed by earlier drafts | The deployed shim has ONE public method: `log(String context, Severity sevLevel, String message, Id recordId)`. Exception details must be flattened into the `message` argument by the caller: `e.getMessage() + ' | ' + e.getStackTraceString()`. | Confirmed in `AppLogger.cls` and exercised by `AppLoggerTest.cls` test methods. |
| 3 | 2026-05-16 | `developer.salesforce.com` and `help.salesforce.com` doc pages as authoritative references for runtime details (System.Logger, RTEM, debug log levels) | WebFetch returns the page header only -- JS-rendered body is unavailable. The `forcedotcom/sf-skills` and project-internal Apex code are the ground truth used here. | Same root cause as `../salesforce-agentforce-script/SKILL.md` empirical finding #5. Cite official URLs as canonical pointers but verify against project code. |
| 4 | 2026-05-16 | A dedicated `Correlation_Id__c` column on the log object for first-class correlation queries | `Agent_Activity_Log__c` has no correlation-id field. Embed `cid=<token>` inside the message; query with `Agent_Comments__c LIKE '%cid=<token>%'`. Slower than an indexed lookup but works without schema changes. | Pragmatic shim until a real `AppLog__c` (or a new field on `Agent_Activity_Log__c`) is introduced. |

---

*Observability & Logging Guidelines | Reusable Salesforce Agent Guidelines | Last verified 2026-05-16*

## Official References

- [Apex Developer Guide -- Debug Log](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_debugging_debug_log.htm)
- [Apex Developer Guide -- Debug Log Levels](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_log_debug_levels.htm)
- [System.Logger class](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Logger.htm)
- [System.LoggingLevel enum](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_enum_System_LoggingLevel.htm)
- [Database class -- insert with allOrNone](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_database.htm)
- [Platform Events Developer Guide](https://developer.salesforce.com/docs/atlas.en-us.platform_events.meta/platform_events/)
- [Real-Time Event Monitoring overview](https://help.salesforce.com/s/articleView?id=sf.real_time_event_monitoring_overview.htm&type=5)
- [Flow Fault Paths](https://help.salesforce.com/s/articleView?id=sf.flow_ref_elements_fault.htm)
- [Apex Governor Limits](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_gov_limits.htm)
- [forcedotcom/sf-skills -- debugging-apex-logs](https://github.com/forcedotcom/sf-skills/tree/main/skills/debugging-apex-logs)

