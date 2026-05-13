# Observability & Logging Guidelines

**Version**: 2.0 (April 2026)
**Developer**: Naresh | Senior Salesforce Developer
**Purpose**: Standalone guidelines for Salesforce observability, structured logging, error alerting, and operational visibility. Attach when implementing logging, error handling, or monitoring for any Salesforce component.

---

## Table of Contents

1. [Required Agent Output Contract](#required-agent-output-contract)
2. [Logging Principles](#logging-principles)
3. [Custom Log Object Design](#custom-log-object-design)
4. [AppLogger Apex Class](#applogger-apex-class)
5. [Platform Events for Log Distribution](#platform-events-for-log-distribution)
6. [Flow Fault Logging — LogError_Subflow](#flow-fault-logging--logerror_subflow)
7. [Integration Error Logging](#integration-error-logging)
8. [Correlation IDs](#correlation-ids)
9. [Async Job IDs](#async-job-ids)
10. [Safe Logging — What NOT to Log](#safe-logging--what-not-to-log)
11. [Logging in Async Contexts](#logging-in-async-contexts)
12. [Dashboards and Reports](#dashboards-and-reports)
13. [Alerting](#alerting)
14. [AppLog__c Retention and Archival](#applogc-retention-and-archival)
15. [Common AI Mistakes to Avoid](#common-ai-mistakes-to-avoid)
16. [Definition of Done (Observability)](#definition-of-done-observability)
17. [Official References](#official-references)

---

## Required Agent Output Contract

Every observability implementation produced by an AI agent MUST include all of the following. Do NOT omit any section.

1. **Log object design** — AppLog__c field list, OWD sharing model, and rationale
2. **AppLogger class implementation** — full working Apex class with `without sharing` and `Database.insert(log, false)`
3. **Correlation ID strategy** — how correlation IDs are generated and passed across components
4. **Flow fault logging (LogError_Subflow)** — full autolaunched flow design with input variables and fault path
5. **Integration error logging** — how integration HTTP errors are captured with status code, duration, and correlation ID
6. **Alert trigger definition** — what conditions trigger alerts and how alerts are delivered
7. **Dashboard/report plan** — which AppLog__c reports and dashboard components will be built

Failure to include all seven items is a non-compliant observability implementation.

---

## Logging Principles

These principles are non-negotiable. Every logging implementation MUST comply with all of them.

### Core Principles

**1. Logs MUST support diagnosis without exposing secrets or PII**
Logs exist to help engineers diagnose problems. They must contain enough context to understand what happened without containing sensitive user data, credentials, or personal information.

**2. Logging MUST NEVER block business logic**
Use `Database.insert(log, false)` (allOrNone = false) at all times. If the log insert fails for any reason (governor limits, validation errors, connectivity), the parent transaction must continue. A logging failure must never cause a business transaction to fail.

**3. Every critical operation MUST log: start, success, and failure**
For any operation that has business consequence (DML, callout, async job, complex decision), log at:
- Entry point (INFO): "Starting [operation] for record [id]"
- Success path (INFO): "Completed [operation] successfully for record [id]"
- Failure path (ERROR): "Failed [operation] for record [id]: [sanitized error message]"

**4. Errors MUST include: component name, operation, related record ID, error message, and timestamp**
All five elements are required for an error log to be actionable. An error log missing any of these requires an engineer to re-run the scenario to gather the missing context, which delays resolution.

**5. Logs MUST include a correlation ID to trace multi-step operations**
Any operation that spans multiple Apex executions, flows, or async jobs must use a shared correlation ID. Without it, tracing a failure across component boundaries requires matching timestamps, which is unreliable.

**6. Log levels MUST be used correctly**
- `DEBUG`: Fine-grained diagnostic information — not for production by default
- `INFO`: Normal operational events — significant milestones without errors
- `WARN`: An unexpected condition that was handled — may require investigation
- `ERROR`: A failure that was caught and handled — requires investigation
- `FATAL`: A critical failure that may have caused data corruption or unavailability — requires immediate response

**7. Logs must be queryable**
AppLog__c is a standard Salesforce custom object. Logs are written as records so they can be queried with SOQL, reported on, and used in dashboards. This is superior to System.debug() which is transient and not searchable.

---

## Custom Log Object Design

### AppLog__c Object Configuration

**Object API Name**: `AppLog__c`
**Object Label**: `App Log`
**Plural Label**: `App Logs`
**OWD (Organization-Wide Default)**: Private
**Reason for Private OWD**: Log records may contain error details, stack traces, and system operation context that should not be visible to regular users. Only system administrators and operations personnel should have access.
**Apex Logger**: writes using `without sharing` (system-level write, bypasses OWD for insert)

### Field Design

| Field API Name | Field Type | Length / Options | Purpose |
|---|---|---|---|
| `Level__c` | Picklist | DEBUG, INFO, WARN, ERROR, FATAL | Log severity level |
| `Component__c` | Text | 255 | Apex class.method name or Flow API name |
| `Operation__c` | Text | 255 | Human-readable description of what was attempted |
| `RelatedRecordId__c` | Text | 18 | Salesforce record ID of the primary record involved |
| `CorrelationId__c` | Text | 255 | Shared ID for tracing a multi-step operation |
| `AsyncJobId__c` | Text | 18 | Queueable or Batch Apex job ID |
| `Message__c` | LongTextArea | 131072 | Error message or informational description (sanitized) |
| `StackTrace__c` | LongTextArea | 131072 | Exception stack trace string |
| `IntegrationSystem__c` | Text | 255 | External system name for integration logs |
| `Direction__c` | Picklist | Inbound, Outbound | Integration traffic direction |
| `StatusCode__c` | Number | 3, 0 | HTTP response status code |
| `DurationMs__c` | Number | 10, 0 | Execution or callout duration in milliseconds |
| `UserId__c` | Text | 18 | Running user ID (populated automatically in AppLogger) |
| `TransactionId__c` | Text | 255 | Salesforce transaction ID for correlating with debug logs |

### Standard Fields to Enable

- **CreatedDate**: automatically set — the primary timestamp for all log queries
- **Name**: auto-number field (e.g., `LOG-{00000}`) for unique log identification
- Enable **Field History Tracking** on Level__c only (to detect if logs are being modified)
- Enable **Search Layout** so administrators can search logs from global search

### AppLog__c Metadata XML

```xml
<?xml version="1.0" encoding="UTF-8"?>
<CustomObject xmlns="http://soap.sforce.com/2006/04/metadata">
    <deploymentStatus>Deployed</deploymentStatus>
    <enableActivities>false</enableActivities>
    <enableBulkApi>true</enableBulkApi>
    <enableFeeds>false</enableFeeds>
    <enableHistory>false</enableHistory>
    <enableReports>true</enableReports>
    <enableSearch>true</enableSearch>
    <enableSharing>true</enableSharing>
    <label>App Log</label>
    <nameField>
        <displayFormat>LOG-{00000000}</displayFormat>
        <label>Log Number</label>
        <type>AutoNumber</type>
    </nameField>
    <pluralLabel>App Logs</pluralLabel>
    <sharingModel>Private</sharingModel>
</CustomObject>
```

---

## AppLogger Apex Class

### Design Requirements

- Class modifier: `public without sharing` — logging must work regardless of the running user's record access
- All insert operations: `Database.insert(log, false)` — allOrNone = false ensures log failure never blocks business logic
- PII sanitization in the `sanitize()` method — no raw user data in messages
- All public methods are static — no instantiation needed, call from anywhere
- Overloaded signatures for common call patterns — reduce boilerplate in calling code

### Full Implementation

```apex
/**
 * Description: Centralized logging helper for Apex, integrations, and async jobs.
 *              Writes structured log records to AppLog__c for diagnosis and monitoring.
 *              All inserts use allOrNone=false to never block business logic on log failure.
 * Developer: Naresh
 * Title: Senior Salesforce Developer
 * Version: 2.0 (April 2026)
 */
public without sharing class AppLogger {

    // =========================================================
    // PUBLIC API — INFO
    // =========================================================

    /**
     * Log an informational event (no error).
     * Use for significant operational milestones: start, completion, key decisions.
     */
    public static void info(String component, String operation, String message) {
        log('INFO', component, operation, null, null, null, message, null);
    }

    /**
     * Log an informational event with a related record ID.
     */
    public static void info(String component, String operation, Id relatedRecordId, String message) {
        log('INFO', component, operation, null, null, relatedRecordId, message, null);
    }

    /**
     * Log an informational event with correlation ID and related record ID.
     */
    public static void info(String component, String correlationId, String operation, Id relatedRecordId, String message) {
        log('INFO', component, operation, correlationId, null, relatedRecordId, message, null);
    }

    // =========================================================
    // PUBLIC API — WARN
    // =========================================================

    /**
     * Log a warning: an unexpected condition that was handled but may require investigation.
     */
    public static void warn(String component, String operation, String message) {
        log('WARN', component, operation, null, null, null, message, null);
    }

    /**
     * Log a warning with correlation ID.
     */
    public static void warn(String component, String correlationId, String operation, String message) {
        log('WARN', component, operation, correlationId, null, null, message, null);
    }

    // =========================================================
    // PUBLIC API — ERROR
    // =========================================================

    /**
     * Log an error with a plain message string.
     * Use when you have the error message but not an exception object.
     */
    public static void error(String component, String correlationId, String operation, String message) {
        log('ERROR', component, operation, correlationId, null, null, message, null);
    }

    /**
     * Log an error from a caught Exception object.
     * Captures both the message and stack trace automatically.
     */
    public static void error(String component, String correlationId, String operation, Exception e) {
        log('ERROR', component, operation, correlationId, null, null, e.getMessage(), e.getStackTraceString());
    }

    /**
     * Log an error from a caught Exception with a related record ID.
     */
    public static void error(String component, String correlationId, String operation, Id relatedRecordId, Exception e) {
        log('ERROR', component, operation, correlationId, null, relatedRecordId, e.getMessage(), e.getStackTraceString());
    }

    /**
     * Log an error with full context: correlation ID, related record ID, message.
     */
    public static void error(String component, String correlationId, String operation, Id relatedRecordId, String message) {
        log('ERROR', component, operation, correlationId, null, relatedRecordId, message, null);
    }

    // =========================================================
    // PUBLIC API — FATAL
    // =========================================================

    /**
     * Log a FATAL event: critical failure requiring immediate response.
     * Always generates an alert when alerting is configured.
     */
    public static void fatal(String component, String correlationId, String operation, Exception e) {
        log('FATAL', component, operation, correlationId, null, null, e.getMessage(), e.getStackTraceString());
    }

    // =========================================================
    // PUBLIC API — INTEGRATION
    // =========================================================

    /**
     * Log an integration callout result (inbound or outbound).
     * Automatically sets level to ERROR if statusCode >= 400.
     *
     * @param system           External system name (e.g., 'ExternalCaseAPI')
     * @param direction        'Inbound' or 'Outbound'
     * @param statusCode       HTTP status code (null if request never sent)
     * @param durationMs       Callout duration in milliseconds
     * @param correlationId    Correlation ID for trace
     * @param message          Success message or error detail
     */
    public static void integration(
        String system,
        String direction,
        Integer statusCode,
        Long durationMs,
        String correlationId,
        String message
    ) {
        String level = (statusCode != null && statusCode >= 400) ? 'ERROR' : 'INFO';

        AppLog__c logRecord = new AppLog__c(
            Level__c              = level,
            Component__c          = 'Integration.' + system,
            Operation__c          = system + ' ' + direction,
            IntegrationSystem__c  = system,
            Direction__c          = direction,
            StatusCode__c         = statusCode,
            DurationMs__c         = durationMs,
            CorrelationId__c      = correlationId,
            Message__c            = sanitize(message),
            UserId__c             = String.valueOf(UserInfo.getUserId()),
            TransactionId__c      = Request.getCurrent().getRequestId()
        );
        Database.insert(logRecord, false); // never block business logic
    }

    // =========================================================
    // PUBLIC API — ASYNC
    // =========================================================

    /**
     * Log an async job event (Queueable or Batch) with its job ID.
     */
    public static void async(String component, String operation, String asyncJobId, String correlationId, String message) {
        AppLog__c logRecord = new AppLog__c(
            Level__c         = 'INFO',
            Component__c     = component,
            Operation__c     = operation,
            AsyncJobId__c    = asyncJobId,
            CorrelationId__c = correlationId,
            Message__c       = sanitize(message),
            UserId__c        = String.valueOf(UserInfo.getUserId()),
            TransactionId__c = Request.getCurrent().getRequestId()
        );
        Database.insert(logRecord, false);
    }

    /**
     * Log an async job error with its job ID.
     */
    public static void asyncError(String component, String operation, String asyncJobId, String correlationId, Exception e) {
        AppLog__c logRecord = new AppLog__c(
            Level__c         = 'ERROR',
            Component__c     = component,
            Operation__c     = operation,
            AsyncJobId__c    = asyncJobId,
            CorrelationId__c = correlationId,
            Message__c       = sanitize(e.getMessage()),
            StackTrace__c    = e.getStackTraceString(),
            UserId__c        = String.valueOf(UserInfo.getUserId()),
            TransactionId__c = Request.getCurrent().getRequestId()
        );
        Database.insert(logRecord, false);
    }

    // =========================================================
    // PRIVATE CORE LOG METHOD
    // =========================================================

    private static void log(
        String level,
        String component,
        String operation,
        String correlationId,
        String asyncJobId,
        Id relatedRecordId,
        String message,
        String stackTrace
    ) {
        AppLog__c logRecord = new AppLog__c(
            Level__c             = level,
            Component__c         = component,
            Operation__c         = operation,
            CorrelationId__c     = correlationId,
            AsyncJobId__c        = asyncJobId,
            RelatedRecordId__c   = relatedRecordId != null ? String.valueOf(relatedRecordId) : null,
            Message__c           = sanitize(message),
            StackTrace__c        = stackTrace,
            UserId__c            = String.valueOf(UserInfo.getUserId()),
            TransactionId__c     = Request.getCurrent().getRequestId()
        );
        Database.insert(logRecord, false); // allOrNone=false: logging NEVER fails the transaction
    }

    // =========================================================
    // CORRELATION ID GENERATOR
    // =========================================================

    /**
     * Generate a correlation ID for tracing a multi-step operation.
     * Call at the entry point of an operation and pass to all subsequent calls.
     * Format: <userId-prefix>-<timestamp-millis>
     */
    public static String generateCorrelationId() {
        String userPrefix = String.valueOf(UserInfo.getUserId()).substring(0, 15);
        return userPrefix + '-' + String.valueOf(System.currentTimeMillis());
    }

    // =========================================================
    // PII SANITIZATION
    // =========================================================

    /**
     * Remove known PII patterns from log message strings.
     * Extend this method per your organization's data classification policy.
     * IMPORTANT: This is a baseline — review and extend for your data model.
     */
    private static String sanitize(String input) {
        if (input == null) return null;
        if (input.length() > 32000) {
            // Truncate to prevent LongTextArea overflow
            input = input.substring(0, 32000) + '... [TRUNCATED]';
        }
        return input
            // Credit card numbers (16 digits, with or without spaces/dashes)
            .replaceAll('[0-9]{4}[- ]?[0-9]{4}[- ]?[0-9]{4}[- ]?[0-9]{4}', '[CARD_REDACTED]')
            // Email addresses
            .replaceAll('[\\w._%+\\-]+@[\\w.\\-]+\\.[a-zA-Z]{2,}', '[EMAIL_REDACTED]')
            // Social Security Numbers (US: XXX-XX-XXXX)
            .replaceAll('[0-9]{3}-[0-9]{2}-[0-9]{4}', '[SSN_REDACTED]')
            // Bearer tokens
            .replaceAll('Bearer\\s+[A-Za-z0-9._\\-]+', 'Bearer [TOKEN_REDACTED]')
            // Basic auth patterns
            .replaceAll('password["\']?\\s*[=:]\\s*["\']?[^\\s"\'&,]+', 'password=[REDACTED]');
    }
}
```

### AppLogger Usage Examples

```apex
// In a service class
public with sharing class CaseService {

    public static void processInboundCase(Case c) {
        String correlationId = AppLogger.generateCorrelationId();
        AppLogger.info('CaseService.processInboundCase', 'ProcessInbound', c.Id, 'Processing inbound case update');

        try {
            // business logic here
            update c;
            AppLogger.info('CaseService.processInboundCase', correlationId, 'ProcessInbound', c.Id, 'Case updated successfully');
        } catch (Exception e) {
            AppLogger.error('CaseService.processInboundCase', correlationId, 'ProcessInbound', c.Id, e);
            throw e; // re-throw after logging — don't swallow exceptions silently
        }
    }
}
```

---

## Platform Events for Log Distribution

Use a Platform Event (`AppLogEvent__e`) when logs need to be consumed externally or in near-real-time. Platform Events allow external systems (Splunk, Datadog, SIEM tools) to subscribe via Streaming API.

### When to Use Platform Events for Logging

- High-volume logging that would stress AppLog__c record limits
- Real-time log streaming to an external SIEM or log aggregation tool
- Cross-org logging (e.g., multiple sandboxes feeding a central log store)
- When logs need to trigger external alerting without polling

### AppLogEvent__e Design

Create a Platform Event with the same fields as AppLog__c:

| Field API Name | Type | Purpose |
|---|---|---|
| `Level__c` | Text(20) | Log severity |
| `Component__c` | Text(255) | Source component |
| `Operation__c` | Text(255) | Operation attempted |
| `CorrelationId__c` | Text(255) | Trace correlation ID |
| `Message__c` | LongTextArea | Log message |
| `StatusCode__c` | Number(3,0) | HTTP status (integrations) |

### Publishing a Platform Event Log

```apex
// Publish instead of insert for external distribution
EventBus.publish(new AppLogEvent__e(
    Level__c         = 'ERROR',
    Component__c     = 'CaseService.processInbound',
    Operation__c     = 'ProcessInbound',
    CorrelationId__c = correlationId,
    Message__c       = sanitizedMessage
));
```

### Subscribing to Log Events

External systems subscribe via:
- **Salesforce Streaming API** (CometD protocol)
- **Change Data Capture** (if using the object approach)
- **External integrations**: Splunk, Datadog, Elastic, AWS CloudWatch — connect via Streaming API or MuleSoft

### Hybrid Approach

For most orgs, use both:
1. `AppLog__c` records for operational visibility (reports, dashboards, SOQL queries)
2. `AppLogEvent__e` platform events for external streaming (only when external SIEM is available)

---

## Flow Fault Logging — LogError_Subflow

Every Flow that performs DML or calls an Apex action MUST have fault paths. All fault paths should route to `LogError_Subflow` — a shared, reusable autolaunched flow that writes an AppLog__c record.

### LogError_Subflow Design

**Flow Type**: Autolaunched Flow (no trigger, called as a subflow)
**API Name**: `LogError_Subflow`
**Description**: Reusable fault logging subflow. Called from fault paths in all record-triggered and autolaunched flows.

### Input Variables

| Variable API Name | Type | Required | Description |
|---|---|---|---|
| `input_FlowName` | Text | Yes | API name of the calling flow |
| `input_RecordId` | Text | No | Related record ID (pass the triggering record ID) |
| `input_ElementName` | Text | No | Name of the flow element that faulted |
| `input_ErrorMessage` | Text | No | Fault message from the faulted element ({!$Flow.FaultMessage}) |

### Flow Elements

**Element 1: Create AppLog__c Record**
- Element Type: Create Records
- Object: AppLog__c
- Field mappings:
  - `Level__c` = `ERROR` (literal value)
  - `Component__c` = `{!input_FlowName}` (Flow Name)
  - `Operation__c` = `{!input_ElementName}` (Element that faulted)
  - `RelatedRecordId__c` = `{!input_RecordId}` (Related record)
  - `Message__c` = `{!input_ErrorMessage}` (Fault message)
- **Fault path on this element**: connects to End (do NOT re-throw — logging failure must be silent)

**Element 2: End**
- The subflow ends — the calling flow's fault path is satisfied

### Connecting LogError_Subflow in a Calling Flow

In every calling flow element that has a fault path:
1. Add a Subflow element pointing to `LogError_Subflow`
2. Map input variables:
   - `input_FlowName` = `{!$Flow.CurrentFlowApiName}` (system variable)
   - `input_RecordId` = `{!$Record.Id}` (for record-triggered flows)
   - `input_ElementName` = literal text of the element name
   - `input_ErrorMessage` = `{!$Flow.FaultMessage}` (system variable)
3. Connect the fault connector of the DML/action element to this Subflow element
4. Connect the Subflow's connector to an End element (not a re-throw)

### LogError_Subflow Metadata Pattern

```xml
<!-- Simplified representation — actual flow XML generated by Flow Builder -->
<!-- Key fields: all DML elements have fault connectors to LogError_Subflow call -->
<!-- LogError_Subflow itself has a fault path on its Create Records that goes to End -->
```

### Testing LogError_Subflow

- Deploy LogError_Subflow to sandbox
- Trigger a test flow that deliberately causes a fault (e.g., attempt to create a record that fails a required field validation)
- Verify AppLog__c record is created with Level__c = 'ERROR' and the fault message populated
- Verify the calling transaction completed (fault was handled, not re-thrown)

---

## Integration Error Logging

Every integration callout MUST be logged. Capture: system name, direction, status code, duration, correlation ID, and a sanitized message.

### Integration Logging Pattern

```apex
/**
 * Integration callout with full observability.
 * Developer: Naresh | Senior Salesforce Developer
 */
public with sharing class ExternalCaseApiClient {

    private static final String SYSTEM_NAME = 'ExternalCaseAPI';

    public static ExternalCaseApiResponse createCase(CasePayload payload) {
        String correlationId = AppLogger.generateCorrelationId();
        Long startTime       = System.currentTimeMillis();

        AppLogger.info(
            'ExternalCaseApiClient.createCase',
            correlationId,
            'CreateCase',
            'Starting outbound case creation request'
        );

        try {
            HttpRequest req = buildRequest(payload);
            HttpResponse res = new Http().send(req);
            Long duration    = System.currentTimeMillis() - startTime;

            AppLogger.integration(
                SYSTEM_NAME,
                'Outbound',
                res.getStatusCode(),
                duration,
                correlationId,
                res.getStatusCode() < 400
                    ? 'Case created successfully'
                    : 'Case creation failed: ' + res.getBody().abbreviate(500)
            );

            if (res.getStatusCode() >= 400) {
                throw new IntegrationException(
                    SYSTEM_NAME + ' returned ' + res.getStatusCode() + ': ' + res.getBody()
                );
            }

            return parseResponse(res);

        } catch (IntegrationException e) {
            throw e; // already logged above, re-throw for caller

        } catch (Exception e) {
            Long duration = System.currentTimeMillis() - startTime;
            AppLogger.integration(SYSTEM_NAME, 'Outbound', null, duration, correlationId, e.getMessage());
            throw new IntegrationException('Unexpected error calling ' + SYSTEM_NAME + ': ' + e.getMessage(), e);
        }
    }

    private static HttpRequest buildRequest(CasePayload payload) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:ExternalCaseAPI/cases');  // Named Credential — never hardcode endpoints
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('Accept', 'application/json');
        req.setBody(JSON.serialize(payload));
        req.setTimeout(30000);
        return req;
    }

    private static ExternalCaseApiResponse parseResponse(HttpResponse res) {
        return (ExternalCaseApiResponse) JSON.deserialize(res.getBody(), ExternalCaseApiResponse.class);
    }

    public class ExternalCaseApiResponse {
        public Boolean success;
        public String  caseId;
        public String  errorMessage;
    }
}
```

### Inbound Integration Logging

For REST/SOAP services exposed to external callers:

```apex
@RestResource(urlMapping='/api/v1/cases/*')
global with sharing class CaseInboundRestService {

    @HttpPost
    global static void handlePost() {
        String correlationId = AppLogger.generateCorrelationId();
        Long startTime = System.currentTimeMillis();

        try {
            AppLogger.info('CaseInboundRestService', correlationId, 'HandlePost', 'Received inbound case request');

            // Extract and validate payload
            String requestBody = RestContext.request.requestBody.toString();
            // process...

            Long duration = System.currentTimeMillis() - startTime;
            AppLogger.integration('ExternalPortal', 'Inbound', 200, duration, correlationId, 'Inbound request processed');

            RestContext.response.statusCode = 200;

        } catch (Exception e) {
            Long duration = System.currentTimeMillis() - startTime;
            AppLogger.integration('ExternalPortal', 'Inbound', 500, duration, correlationId, e.getMessage());
            RestContext.response.statusCode = 500;
        }
    }
}
```

### Integration Log Checklist

For every integration implementation:
- [ ] Correlation ID generated at entry point and passed through all log calls
- [ ] Start logged at INFO before the callout
- [ ] Duration captured using `System.currentTimeMillis()` before and after
- [ ] HTTP status code logged on every response
- [ ] Error logged with status code and sanitized response body on failure
- [ ] Named Credential used — endpoint URL never hardcoded in Apex
- [ ] Log message for error cases does not include full response body (may contain tokens/PII) — truncate to 500 characters

---

## Correlation IDs

### What Is a Correlation ID

A correlation ID is a unique string token assigned at the entry point of a multi-step operation. It is passed to every subsequent step and included in every log entry for that operation. This enables an engineer to query all log records for a single operation across multiple component boundaries using a single SOQL filter.

### Without Correlation IDs

Without correlation IDs, tracing a failure requires:
- Matching log timestamps (unreliable in async contexts)
- Searching by record ID (only works if one record is involved)
- Guessing which log entries belong to the same operation

### With Correlation IDs

With correlation IDs, a single query returns the full picture:

```apex
// Query all logs for one correlation ID to see the full operation trace
List<AppLog__c> trace = [
    SELECT Level__c, Component__c, Operation__c, Message__c, CreatedDate
    FROM AppLog__c
    WHERE CorrelationId__c = '005Xx000001gXXX-1714320000000'
    ORDER BY CreatedDate ASC
];
```

### Correlation ID Format

```apex
// Standard format: userId-prefix + timestamp in milliseconds
public static String generateCorrelationId() {
    String userPrefix = String.valueOf(UserInfo.getUserId()).substring(0, 15);
    return userPrefix + '-' + String.valueOf(System.currentTimeMillis());
}

// Alternative: UUID format (if you have a UUID utility)
// '550e8400-e29b-41d4-a716-446655440000'
```

### Passing Correlation IDs Across Boundaries

**Apex to Apex (same transaction)**
```apex
String correlationId = AppLogger.generateCorrelationId();
CaseService.process(caseId, correlationId); // pass as parameter
```

**Apex to Queueable**
```apex
// Include correlationId in Queueable constructor
public class CaseProcessingJob implements Queueable {
    private String correlationId;
    public CaseProcessingJob(String correlationId) {
        this.correlationId = correlationId;
    }
    public void execute(QueueableContext ctx) {
        AppLogger.async('CaseProcessingJob', 'Execute', String.valueOf(ctx.getJobId()), correlationId, 'Job executing');
        // business logic...
    }
}
```

**Apex to External System (HTTP)**
```apex
// Pass correlation ID as a request header for end-to-end trace
req.setHeader('X-Correlation-Id', correlationId);
```

**Flow to Apex (via Invocable)**
```apex
// Invocable method accepts correlationId as input parameter
public class CreateTaskAction {
    public class Input {
        @InvocableVariable public String correlationId;
        @InvocableVariable public Id caseId;
    }
    @InvocableMethod(label='Create Follow-up Task')
    public static void execute(List<Input> inputs) {
        for (Input i : inputs) {
            AppLogger.info('CreateTaskAction', i.correlationId, 'CreateTask', i.caseId, 'Creating task');
            // ...
        }
    }
}
```

---

## Async Job IDs

Batch and Queueable jobs run in separate transactions. The job ID is the primary link between the async execution context and the log records it generates.

### Capturing Async Job IDs

```apex
// Queueable: capture job ID at enqueue time
String jobId = String.valueOf(System.enqueueJob(new CaseProcessingJob(correlationId)));
AppLogger.async('CaseService', 'EnqueueJob', jobId, correlationId, 'Queueable enqueued: ' + jobId);

// Batch: capture job ID at execute time
String batchJobId = String.valueOf(Database.executeBatch(new CaseCleanupBatch(), 200));
AppLogger.async('CaseService', 'ExecuteBatch', batchJobId, correlationId, 'Batch started: ' + batchJobId);
```

### Logging Inside Batch Apex

```apex
public class CaseCleanupBatch implements Database.Batchable<SObject> {
    private String correlationId;

    public CaseCleanupBatch() {
        this.correlationId = AppLogger.generateCorrelationId();
    }

    public Database.QueryLocator start(Database.BatchableContext ctx) {
        AppLogger.async('CaseCleanupBatch', 'Start', String.valueOf(ctx.getJobId()), correlationId, 'Batch started');
        return Database.getQueryLocator([SELECT Id FROM Case WHERE Status = 'Closed' AND CloseDate < LAST_N_DAYS:90]);
    }

    public void execute(Database.BatchableContext ctx, List<Case> scope) {
        try {
            // processing...
        } catch (Exception e) {
            AppLogger.asyncError('CaseCleanupBatch', 'Execute', String.valueOf(ctx.getJobId()), correlationId, e);
        }
    }

    public void finish(Database.BatchableContext ctx) {
        AppLogger.async('CaseCleanupBatch', 'Finish', String.valueOf(ctx.getJobId()), correlationId, 'Batch completed');
    }
}
```

---

## Safe Logging — What NOT to Log

### NEVER Log

| Category | Examples | Risk |
|---|---|---|
| Authentication credentials | Passwords, API keys, OAuth tokens, JWT secrets | Credential exposure |
| Payment card data | Full credit card numbers, CVV codes | PCI-DSS violation |
| Government identifiers | SSN, passport numbers, national IDs | Privacy regulation violation |
| Full request/response bodies | HTTP bodies that may contain the above | Unknown PII exposure |
| Session tokens | JSESSIONID, Salesforce session IDs | Session hijacking |
| Personal medical information | Diagnoses, medications, test results | HIPAA violation |

### ALWAYS Log (Safe to Include)

| Category | Examples |
|---|---|
| Salesforce record IDs | 005Xx000001gXXX (user/record IDs are OK) |
| Operation names | 'CreateCase', 'UpdateStatus', 'ProcessInbound' |
| Component names | 'CaseService.processInbound' |
| Sanitized error messages | After running through AppLogger.sanitize() |
| HTTP status codes | 200, 400, 401, 500 |
| Duration values | 1423 ms |
| Correlation IDs | Your generated ID format |
| Job IDs | Salesforce async job IDs |
| Timestamps | CreatedDate auto-populated on the record |

### Sanitization Rules

The `sanitize()` method in AppLogger is a baseline. Extend it based on your org's data:

```apex
// Extend sanitize() for your organization's specific data patterns
// Example additions:
.replaceAll('[A-Z]{2}[0-9]{6}[A-Z]', '[PASSPORT_REDACTED]')     // Passport numbers
.replaceAll('[0-9]{10,11}', '[PHONE_REDACTED]')                  // Phone numbers (be careful — may match IDs)
.replaceAll('client_secret[=:][^&\\s]+', 'client_secret=[REDACTED]')  // OAuth client secrets
```

---

## Logging in Async Contexts

### Queueable Apex

Log at three points in every Queueable:
1. When the job is enqueued (from the calling context)
2. At the start of `execute()` with the job ID
3. On success and on each caught exception

### Batch Apex

Log at three points in every Batch:
1. In `start()` with the batch job ID
2. In `finish()` with the batch job ID and a summary
3. In `execute()` on any exception (not on every record — that would create too many logs)

### Scheduled Apex

```apex
public class CaseEscalationScheduler implements Schedulable {
    public void execute(SchedulableContext ctx) {
        String correlationId = AppLogger.generateCorrelationId();
        AppLogger.info('CaseEscalationScheduler', correlationId, 'Execute', 'Scheduled job started');
        try {
            String jobId = String.valueOf(Database.executeBatch(new CaseEscalationBatch(correlationId), 200));
            AppLogger.async('CaseEscalationScheduler', 'BatchEnqueued', jobId, correlationId, 'Batch enqueued: ' + jobId);
        } catch (Exception e) {
            AppLogger.error('CaseEscalationScheduler', correlationId, 'Execute', e);
        }
    }
}
```

### Platform Event Triggers

Log in Platform Event-triggered flows using LogError_Subflow on fault paths. For Apex triggers on Platform Events, use AppLogger as in standard triggers.

---

## Dashboards and Reports

### Standard Reports to Build

Build these reports on AppLog__c immediately after deployment. They provide baseline visibility into org health.

**Report 1: Error Hotspots (Last 7 Days)**
- Report Type: AppLog__c
- Filters: Level__c IN ('ERROR', 'FATAL'), CreatedDate = LAST_7_DAYS
- Group By: Component__c
- Summary: Count of log records
- Sort: Descending by count
- Purpose: Identifies the most error-prone components

**Report 2: Integration Health (Last 24 Hours)**
- Report Type: AppLog__c
- Filters: IntegrationSystem__c != null, CreatedDate = TODAY
- Group By: IntegrationSystem__c, StatusCode__c
- Summary: Count, Average DurationMs__c
- Purpose: Monitors all external system dependencies

**Report 3: Flow Fault Trend (Last 30 Days)**
- Report Type: AppLog__c
- Filters: Component__c CONTAINS 'Flow' OR Component__c CONTAINS 'flow', Level__c = 'ERROR'
- Group By: Component__c, CreatedDate (group by Day)
- Chart: Line chart by day
- Purpose: Identifies unstable flows and trends

**Report 4: High-Severity Log Trend**
- Report Type: AppLog__c
- Filters: Level__c IN ('ERROR', 'FATAL'), CreatedDate = LAST_30_DAYS
- Group By: Level__c, CreatedDate (by Day)
- Chart: Stacked bar by day
- Purpose: Tracks overall error rate over time

**Report 5: Async Job Failures**
- Report Type: AppLog__c
- Filters: AsyncJobId__c != null, Level__c = 'ERROR', CreatedDate = LAST_7_DAYS
- Group By: Component__c, AsyncJobId__c
- Purpose: Identifies failing batch/queueable jobs

### Standard Dashboard Components

Build a single dashboard: **"Org Operational Health"** with these components:

| Component | Type | Source Report |
|---|---|---|
| Error Rate Gauge | Gauge | ERRORs / total logs today |
| Integration Error Count | Metric per system | Report 2 |
| Flow Fault Trend | Line Chart | Report 3 |
| Error Hotspot Table | Table | Report 1 |
| FATAL Logs Today | Metric | Filtered Report 4 |
| Async Job Failures | Table | Report 5 |

### Dashboard Scheduling

- Refresh the Org Operational Health dashboard daily at the start of business
- Subscribe operations team members to email refresh notifications for high-severity spikes
- Pin the dashboard to the Operations or IT admin app home page

---

## Alerting

Alerting closes the loop between logging and human response. Logs that are never seen provide no value.

### Alert Conditions

| Condition | Threshold | Urgency | Channel |
|---|---|---|---|
| FATAL log created | Any single FATAL | Immediate | Slack + Email |
| ERROR logs from same Component | 3+ in 5 minutes | High | Slack |
| Integration status code 401 or 403 | Any occurrence | Immediate | Slack + Email (auth failure = credential problem) |
| Integration status code 500+ | 3+ in 10 minutes | High | Slack |
| Batch Apex failure | Any FATAL in Batch context | Immediate | Email to operations team |
| Async job error rate | >10% of batch chunks failing | High | Slack |

### Alert Implementation Options

**Option 1: Flow-Based Alerting (via Platform Events)**
1. Publish `AppLogEvent__e` when creating FATAL or high-frequency ERROR logs
2. Subscribe with a Platform Event-triggered flow
3. Flow sends a Slack notification (custom action) or email alert

**Option 2: Custom Alert Flow on AppLog__c (Record-Triggered)**
1. Create a record-triggered flow on AppLog__c — After Save — Entry criteria: `Level__c = 'FATAL'`
2. Flow action: Call a Notification action (Bell notification, email, or Slack via custom action)
3. Limit: record-triggered flows on AppLog__c can create performance issues at high log volume — use Platform Events for high-volume scenarios

**Option 3: AppExchange Tools**
- Verify available options in your target org (Splunk for Salesforce, Datadog connector, custom webhook tools)
- These tools subscribe to Platform Events or query AppLog__c via scheduled jobs

### Alert Message Format

Every alert must include:
- Severity level
- Component name
- Operation name
- Correlation ID (for immediate log lookup)
- Timestamp
- Direct link to AppLog__c record or filtered report

---

## AppLog__c Retention and Archival

### Retention Policy

Log records accumulate quickly in production. Define a retention policy before going live:

| Level | Recommended Retention | Rationale |
|---|---|---|
| DEBUG | 7 days | Short-lived diagnostic data |
| INFO | 30 days | Operational history for one month |
| WARN | 90 days | Warning trend analysis |
| ERROR | 180 days | Root cause investigation window |
| FATAL | 365 days | Compliance and post-incident review |

### Archival Implementation

```apex
// Scheduled Apex to delete old logs
public class AppLogCleanupBatch implements Database.Batchable<SObject> {

    public Database.QueryLocator start(Database.BatchableContext ctx) {
        // Delete DEBUG and INFO logs older than 30 days
        Date cutoff = Date.today().addDays(-30);
        return Database.getQueryLocator([
            SELECT Id FROM AppLog__c
            WHERE Level__c IN ('DEBUG', 'INFO')
            AND CreatedDate < :cutoff
        ]);
    }

    public void execute(Database.BatchableContext ctx, List<SObject> scope) {
        Database.delete(scope, false); // allOrNone=false — skip records that fail (e.g., locked)
    }

    public void finish(Database.BatchableContext ctx) {
        AppLogger.info('AppLogCleanupBatch', 'Finish', 'Log cleanup batch completed');
    }
}
```

Schedule this batch to run weekly during off-peak hours.

---

## Common AI Mistakes to Avoid

1. **Using System.debug() as a production logging strategy** — debug logs are transient, not stored as records, not searchable, and not available to operations teams. They provide no operational observability.

2. **Logging PII or secrets** — raw email addresses, credit card numbers, API tokens, or full HTTP response bodies in log messages. Always run messages through `sanitize()`.

3. **Using `insert log;` instead of `Database.insert(log, false)`** — if the log insert fails (governor limit hit, field validation error), the business transaction will also fail. This is the single most dangerous logging mistake.

4. **No correlation ID in multi-step operations** — without a correlation ID, tracing a failure across trigger → service → queueable → integration is not reliably possible.

5. **No logging in integration HTTP client** — integration errors are the most common source of production incidents. Every callout must log its start, status code, duration, and any error.

6. **No LogError_Subflow on flow fault paths** — flows fail silently without fault logging, and users may not report failures immediately. All DML and action fault paths must connect to LogError_Subflow.

7. **Building dashboards before the log object is in production** — the report and dashboard depend on AppLog__c existing with all fields. Always deploy the object first.

8. **Not truncating long messages** — LongTextArea has limits. Logs from large HTTP responses or stack traces can exceed field limits. Always truncate input before inserting.

9. **Logging inside a loop** — do NOT call `AppLogger.info()` or `AppLogger.error()` inside a `for` loop that processes many records. Collect errors and log a summary after the loop, or log at the operation level.

10. **Not including component name in the log** — "ERROR: null" in the Message__c field with no Component__c value is completely unactionable.

11. **Referencing `AppLogger` when it is not deployed in the target org** — `AppLogger` is a project standard pattern but is not a managed package or native Salesforce class. If it does not exist as a deployed Apex class in the org, every class that references it will fail to compile. Before using `AppLogger` in any service class, verify it exists in the org. If it does not, fall back to `System.debug(LoggingLevel.ERROR, context + message)` and add a TODO comment to migrate once `AppLogger` is deployed. Never assume `AppLogger` is present just because the guidelines recommend it.

---

## Definition of Done (Observability)

An observability implementation is not complete until ALL items on this checklist are confirmed.

### Object and Infrastructure

- [ ] AppLog__c object deployed with all required fields (Level__c, Component__c, Operation__c, RelatedRecordId__c, CorrelationId__c, AsyncJobId__c, Message__c, StackTrace__c, IntegrationSystem__c, Direction__c, StatusCode__c, DurationMs__c)
- [ ] AppLog__c OWD set to Private
- [ ] AppLogger Apex class deployed (`without sharing`, `Database.insert(log, false)`, sanitize() method present)
- [ ] LogError_Subflow deployed and tested in sandbox

### Apex Logging

- [ ] All critical Apex service methods log: entry (INFO), success (INFO), error (ERROR with exception)
- [ ] All integration HTTP clients log: pre-callout INFO, post-callout with status code and duration
- [ ] Correlation IDs generated at entry points and passed through all downstream calls
- [ ] All async jobs (Queueable, Batch) log job IDs and use correlation IDs

### Flow Logging

- [ ] LogError_Subflow connected on fault paths of all DML elements
- [ ] LogError_Subflow connected on fault paths of all Apex action elements
- [ ] LogError_Subflow tested — fault is caught, AppLog__c created, transaction not re-failed

### Safety

- [ ] No PII or secrets in any log message (sanitize() covers all code paths)
- [ ] No `insert log;` pattern anywhere — only `Database.insert(log, false)`
- [ ] No logging inside loops

### Visibility

- [ ] AppLog__c report for ERROR hotspots created and shared
- [ ] AppLog__c integration health report created
- [ ] Org Operational Health dashboard created
- [ ] Alert configured for FATAL level logs
- [ ] Alert configured for integration 401/403 status codes

---

## Official References

- Salesforce Platform Events: https://developer.salesforce.com/docs/atlas.en-us.platform_events.meta/platform_events/
- Database Class (allOrNone parameter): https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_methods_system_database.htm
- Salesforce Reports and Dashboards: https://help.salesforce.com/s/articleView?id=sf.customize_cdbstdbdashboards.htm
- Apex Governor Limits: https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_gov_limits.htm
- Apex Exception Class: https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_classes_exception_methods.htm
- Flow Fault Paths: https://help.salesforce.com/s/articleView?id=sf.flow_ref_elements_fault.htm
