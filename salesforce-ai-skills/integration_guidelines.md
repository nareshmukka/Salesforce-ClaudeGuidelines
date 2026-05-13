# Integration Development Guidelines

**Version**: 2.0 (April 2026)
**Developer**: Naresh | Senior Salesforce Developer
**Purpose**: Standalone guidelines for Salesforce integration development. Covers Named Credentials, External Credentials, Apex HTTP clients, Platform Events, Change Data Capture, and integration patterns. Attach when building or reviewing any Salesforce integration.

---

## Table of Contents

1. [Required Agent Output Contract](#required-agent-output-contract)
2. [Named Credentials](#named-credentials)
3. [External Credentials](#external-credentials)
4. [Callout Architecture](#callout-architecture)
5. [Apex HTTP Client Pattern](#apex-http-client-pattern)
6. [Middleware vs Direct Salesforce Integrations](#middleware-vs-direct-salesforce-integrations)
7. [Platform Events](#platform-events)
8. [Change Data Capture (CDC)](#change-data-capture-cdc)
9. [Outbound Messages (SOAP, Legacy)](#outbound-messages-soap-legacy)
10. [REST API Integration Patterns](#rest-api-integration-patterns)
11. [Idempotency Keys](#idempotency-keys)
12. [Retry Strategy](#retry-strategy)
13. [Error Handling](#error-handling)
14. [Observability](#observability)
15. [Secrets Management](#secrets-management)
16. [Test Mocks](#test-mocks)
17. [Common AI Mistakes to Avoid](#common-ai-mistakes-to-avoid)
18. [Definition of Done](#definition-of-done)
19. [Validation Commands](#validation-commands)
20. [Official References](#official-references)

---

## Required Agent Output Contract

Every integration implementation must include all of the following in its response. Incomplete responses are not acceptable for production use.

### 1. Integration Architecture Diagram/Description
Provide a clear description or ASCII diagram covering:
- Which external system(s) are involved
- Direction of data flow (inbound to Salesforce, outbound from Salesforce, or bidirectional)
- Protocol used (REST, SOAP, Streaming API, CometD, etc.)
- Authentication mechanism in use
- Trigger source (Flow, Apex Trigger, Batch, scheduled, external event)

### 2. Authentication Method
State explicitly which authentication method is used:
- Named Credential + External Credential (for OAuth 2.0, JWT Bearer, client credentials)
- Certificate-based authentication (uploaded via Setup > Certificate and Key Management)
- Basic authentication (via Named Credential, never hardcoded)
- No-authentication (for public APIs only; must be documented with justification)

### 3. Files to Create
List every file or metadata component required, including:
- Apex HTTP client class (one per external system)
- Named Credential metadata XML
- External Credential metadata XML (if applicable)
- Custom Metadata Type (CMDT) for runtime configuration values
- Platform Event object definition (if async publish/subscribe is involved)
- Apex service class(es) that orchestrate calls
- Test class with HttpCalloutMock implementation
- Permission Set update (if External Credential principal access is required)

### 4. Security Notes
Include explicit statements for every integration covering:
- Confirmation that no URLs, secrets, API keys, or tokens are hardcoded in Apex
- Where credentials are stored (Named Credential / External Credential)
- Certificate rotation procedure (if certificate-based)
- PII handling — confirm no personally identifiable information is logged in AppLog__c
- Data residency considerations (is data leaving the region?)

### 5. Idempotency Strategy
State how the integration handles duplicate operations:
- Which External ID field is used on the target Salesforce object for upsert
- How duplicate detection works on the external system side (if applicable)
- What happens if the same request is received twice (safe to re-run, or requires deduplication logic)

### 6. Error Handling and Retry Approach
Describe:
- Which HTTP status codes trigger a retry vs. a dead-letter (no retry)
- Maximum retry count and backoff strategy
- Where failed operations are logged and how operations teams are alerted
- Whether partial success is possible and how it is handled

### 7. Observability Plan
Describe:
- What is logged per integration call (system name, direction, status code, duration, correlation ID)
- Which AppLog__c fields are populated
- What alerts are configured (authentication failures, consecutive errors, high latency)
- How to query integration health (sample SOQL provided)

### 8. Test Mock Strategy
State:
- Which HttpCalloutMock class(es) are used per response scenario
- How MultiRequestMock is used if multiple endpoints are called in one transaction
- Which response codes are tested (success, 4xx, 5xx, timeout)
- How bulk (200-record) tests exercise the callout path

### 9. Deployment Steps and Rollback
Provide:
- Ordered deployment steps (metadata components first, then Apex, then permission set changes)
- Validation command (check-only deploy with RunLocalTests)
- Rollback procedure: what to do if deployment fails or integration errors spike post-deploy
- Named Credential update procedure (how to rotate credentials without code change)

---

## Named Credentials

### Core Rule
**ALWAYS use Named Credentials for all outbound callouts. Never hardcode URLs in Apex code, Custom Metadata, or Custom Settings.**

Named Credentials serve as the single authoritative source for:
- The endpoint base URL
- The authentication configuration (protocol, credentials)
- TLS/certificate settings

### What Named Credentials Store
- Endpoint URL (base URL for the external system)
- Authentication protocol: `NoAuthentication`, `Password` (Basic), `OAuth`, `Jwt`, `Certificate`
- Label and developer name for reference in Apex

### Usage in Apex
```apex
// Correct — always use Named Credential reference
req.setEndpoint('callout:MyNamedCred/api/path');

// WRONG — never hardcode URLs
req.setEndpoint('https://api.example.com/api/path'); // PROHIBITED
```

The format is: `callout:<Named_Credential_Name>/<path>`

### Named Credential Metadata XML Example

```xml
<?xml version="1.0" encoding="UTF-8"?>
<NamedCredential xmlns="http://soap.sforce.com/2006/04/metadata">
    <label>My Integration API</label>
    <name>MyIntegrationAPI</name>
    <endpoint>https://api.example.com</endpoint>
    <principalType>Anonymous</principalType>
    <protocol>NoAuthentication</protocol>
</NamedCredential>
```

### Named Credential with Basic Auth (Password Protocol)
```xml
<?xml version="1.0" encoding="UTF-8"?>
<NamedCredential xmlns="http://soap.sforce.com/2006/04/metadata">
    <label>Legacy System API</label>
    <name>LegacySystemAPI</name>
    <endpoint>https://legacy.example.com</endpoint>
    <principalType>NamedPrincipal</principalType>
    <protocol>Password</protocol>
    <username>service_account</username>
    <!-- Password is set via UI or External Credential — never stored in XML -->
</NamedCredential>
```

### Named Credential with External Credential Link (OAuth/JWT)
For OAuth 2.0 and JWT flows, the Named Credential links to an External Credential:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<NamedCredential xmlns="http://soap.sforce.com/2006/04/metadata">
    <label>External Case API OAuth</label>
    <name>ExternalCaseAPI</name>
    <endpoint>https://api.example.com</endpoint>
    <principalType>NamedPrincipal</principalType>
    <protocol>NoAuthentication</protocol>
    <!-- Authentication handled by linked External Credential -->
    <externalCredential>ExternalCaseOAuth</externalCredential>
</NamedCredential>
```

### Important Rules
- Named Credential owns the URL — do NOT duplicate the URL in Custom Metadata or Apex constants
- Update the Named Credential via Setup or metadata deployment to change the endpoint without any code change
- Each external system gets its own Named Credential (one per system)
- Use descriptive names: `ExternalCaseAPI`, `PaymentGatewayAPI`, `WarehouseSystemAPI`
- Never store the Named Credential developer name as a hardcoded string in multiple classes — define it as a constant in the HTTP client class only

---

## External Credentials

### Purpose
External Credentials manage authentication secrets and tokens per principal. They are required for any non-trivial authentication:
- OAuth 2.0 Client Credentials flow
- OAuth 2.0 Authorization Code flow
- JWT Bearer token flow
- Certificate-based authentication

### Principal Types
| Principal Type | Use Case |
|---|---|
| Named Principal | Org-wide credential — all users share the same authentication context |
| Per User | Each Salesforce user authenticates individually with the external system |
| Anonymous | No authentication (public APIs only) |

### Linking External Credential to Named Credential
1. Create the External Credential in Setup > Named Credentials > External Credentials
2. Define the principal (Named Principal or Per User)
3. Add authentication parameters (client ID, client secret via secure storage — not metadata XML)
4. Link the External Credential to the Named Credential in the Named Credential definition

### Permission Set Grant
Any user or integration principal that makes callouts through an External Credential must have access granted via Permission Set:
1. Create or edit the Permission Set used by integration users / automation users
2. Under External Credential Principal Access, grant access to the appropriate principal
3. Without this grant, callouts will fail with authentication errors

### OAuth 2.0 Client Credentials Example
Steps:
1. Create a Connected App on the external system for OAuth Client Credentials
2. In Salesforce, create an External Credential with Authentication Protocol = `OAuth 2.0`
3. Set token endpoint, client ID, client secret (stored securely, not in metadata XML)
4. Set scope as required
5. Link to Named Credential
6. Grant Permission Set access to the Named Principal

### JWT Bearer Token Example
Steps:
1. Generate a certificate in Setup > Certificate and Key Management
2. Register the certificate with the external system (upload the public key)
3. Create an External Credential with Authentication Protocol = `JWT`
4. Configure: issuer, subject, audience, signing certificate
5. Link to Named Credential
6. Grant Permission Set access

### Verification Checklist
- [ ] External Credential created and linked to Named Credential
- [ ] Authentication parameters set (not in metadata XML — set via UI or encrypted storage)
- [ ] Permission Set grants access to the External Credential principal
- [ ] Test callout succeeds in target sandbox before production deployment
- [ ] Token expiry and refresh behavior verified (OAuth tokens auto-refresh via External Credential)

---

## Callout Architecture

### Layer Diagram

```
Entry Point (Flow / Apex Trigger / LWC Controller / Scheduled Job / Inbound API)
   |
   v
Service Class
(Orchestration layer: coordinates calls, handles retry logic, owns domain error handling,
 logs correlation ID, invokes HTTP client)
   |
   v
HTTP Client Class  <-- One class per external system
(Builds HttpRequest, sets endpoint via Named Credential, sets headers/timeout,
 sends request, parses response, maps status codes to typed responses/exceptions)
   |
   v
Named Credential  <-- Owns endpoint URL and authentication
(callout:MyNamedCred/path)
   |
   v
External System
```

### Architectural Rules

**One HTTP client class per external system.**
- `ExternalCaseApiClient` — handles all calls to the external case management system
- `PaymentGatewayClient` — handles all calls to the payment gateway
- Never combine multiple external systems in one HTTP client class

**HTTP client class responsibilities:**
- Build and configure the `HttpRequest` object
- Set the endpoint using Named Credential reference
- Set required headers (`Content-Type`, `Accept`, custom auth headers if needed beyond Named Credential)
- Set timeout (ALWAYS — never omit)
- Send the request via `new Http().send(req)`
- Parse the `HttpResponse` into a typed response wrapper class
- Map HTTP status codes to typed response objects or domain exceptions
- Never perform DML inside the HTTP client class

**Service class responsibilities:**
- Orchestrate one or more HTTP client calls
- Implement retry logic (call HTTP client, catch transient exception, re-enqueue)
- Log integration calls to `AppLog__c` with correlation ID, duration, status
- Map HTTP client exceptions to domain-level exceptions
- Handle partial success scenarios

**Never put callout code in:**
- Apex triggers (triggers should call service classes)
- Flow elements directly (use Invocable Apex that calls the service class)
- LWC controllers (LWC calls Apex methods; Apex does the callout)
- Batch Apex `execute()` unless the batch explicitly implements `Database.AllowsCallouts`

### Separation of Concerns Summary

| Layer | Responsibility | Contains DML? | Contains Callout? |
|---|---|---|---|
| Trigger | Detect event, delegate to service | No | No |
| Service Class | Orchestration, retry, logging | Yes (post-callout) | No (delegates to client) |
| HTTP Client Class | Request/response, status mapping | No | Yes |
| Named Credential | URL + auth | N/A | N/A |

---

## Apex HTTP Client Pattern

### Design Principles
- Class is `public with sharing` — respect sharing rules
- Named Credential name is a `private static final String` constant at the top of the class
- Timeout is a `private static final Integer` constant — never magic number inline
- Response is a typed inner class (not `Map<String, Object>` or raw String)
- Exceptions are typed inner classes extending `Exception`
- All methods are `static` (stateless HTTP client)

### Complete Working Example

```apex
/**
 * Description: HTTP client for external case management API.
 * Handles all outbound callouts to the ExternalCaseAPI Named Credential endpoint.
 * Developer: Naresh
 * Title: Senior Salesforce Developer
 * Last Modified: April 2026
 */
public with sharing class ExternalCaseApiClient {

    private static final String NAMED_CREDENTIAL = 'ExternalCaseAPI';
    private static final Integer TIMEOUT_MS = 30000;
    private static final String API_VERSION = '/v1';

    // ─── Public Methods ────────────────────────────────────────────────────────

    /**
     * Description: Creates a case in the external system.
     * @param requestBody JSON request payload
     * @return ExternalCaseApiResponse Parsed response wrapper
     * @throws IntegrationException on callout failure
     */
    public static ExternalCaseApiResponse createCase(String requestBody) {
        HttpRequest req = buildRequest('POST', '/cases', requestBody);
        return sendAndParse(req);
    }

    /**
     * Description: Retrieves a case by external case ID.
     * @param externalCaseId The external system case identifier
     * @return ExternalCaseApiResponse Parsed response wrapper
     */
    public static ExternalCaseApiResponse getCase(String externalCaseId) {
        HttpRequest req = buildRequest('GET', '/cases/' + EncodingUtil.urlEncode(externalCaseId, 'UTF-8'), null);
        return sendAndParse(req);
    }

    /**
     * Description: Updates an existing case in the external system.
     * @param externalCaseId The external system case identifier
     * @param requestBody JSON request payload with fields to update
     * @return ExternalCaseApiResponse Parsed response wrapper
     */
    public static ExternalCaseApiResponse updateCase(String externalCaseId, String requestBody) {
        HttpRequest req = buildRequest('PATCH', '/cases/' + EncodingUtil.urlEncode(externalCaseId, 'UTF-8'), requestBody);
        return sendAndParse(req);
    }

    /**
     * Description: Closes a case in the external system.
     * @param externalCaseId The external system case identifier
     * @return ExternalCaseApiResponse Parsed response wrapper
     */
    public static ExternalCaseApiResponse closeCase(String externalCaseId) {
        HttpRequest req = buildRequest('POST', '/cases/' + EncodingUtil.urlEncode(externalCaseId, 'UTF-8') + '/close', null);
        return sendAndParse(req);
    }

    // ─── Private Helpers ───────────────────────────────────────────────────────

    private static HttpRequest buildRequest(String method, String path, String body) {
        HttpRequest req = new HttpRequest();
        req.setMethod(method);
        req.setEndpoint('callout:' + NAMED_CREDENTIAL + API_VERSION + path);
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('Accept', 'application/json');
        req.setTimeout(TIMEOUT_MS);
        if (String.isNotBlank(body)) {
            req.setBody(body);
        }
        return req;
    }

    private static ExternalCaseApiResponse sendAndParse(HttpRequest req) {
        HttpResponse res;
        try {
            res = new Http().send(req);
        } catch (CalloutException e) {
            throw new IntegrationException('Callout failed: ' + e.getMessage(), e);
        }
        return parseResponse(res);
    }

    private static ExternalCaseApiResponse parseResponse(HttpResponse res) {
        ExternalCaseApiResponse result = new ExternalCaseApiResponse();
        result.statusCode = res.getStatusCode();
        result.rawBody = res.getBody();

        if (res.getStatusCode() >= 200 && res.getStatusCode() < 300) {
            result.success = true;
            result.body = res.getBody();
        } else if (res.getStatusCode() == 401 || res.getStatusCode() == 403) {
            result.success = false;
            result.errorMessage = 'Authentication/authorization failure (HTTP ' + res.getStatusCode() + ')';
            result.isAuthFailure = true;
        } else if (res.getStatusCode() == 429) {
            result.success = false;
            result.errorMessage = 'Rate limited (HTTP 429)';
            result.isRetryable = true;
        } else if (res.getStatusCode() >= 500) {
            result.success = false;
            result.errorMessage = 'Server error (HTTP ' + res.getStatusCode() + ')';
            result.isRetryable = true;
        } else {
            result.success = false;
            result.errorMessage = 'Unexpected response (HTTP ' + res.getStatusCode() + ')';
        }
        return result;
    }

    // ─── Inner Classes ─────────────────────────────────────────────────────────

    /**
     * Description: Typed response wrapper for all ExternalCaseAPI responses.
     */
    public class ExternalCaseApiResponse {
        public Integer statusCode;
        public Boolean success;
        public String body;
        public String rawBody;
        public String errorMessage;
        public Boolean isRetryable = false;
        public Boolean isAuthFailure = false;
    }

    /**
     * Description: Domain exception for ExternalCaseAPI integration failures.
     */
    public class IntegrationException extends Exception {}
}
```

### Request Correlation ID Pattern
For end-to-end traceability, attach a correlation ID header to every outbound request:

```apex
private static HttpRequest buildRequest(String method, String path, String body) {
    HttpRequest req = new HttpRequest();
    req.setMethod(method);
    req.setEndpoint('callout:' + NAMED_CREDENTIAL + API_VERSION + path);
    req.setHeader('Content-Type', 'application/json');
    req.setHeader('Accept', 'application/json');
    req.setHeader('X-Correlation-ID', generateCorrelationId());
    req.setTimeout(TIMEOUT_MS);
    if (String.isNotBlank(body)) {
        req.setBody(body);
    }
    return req;
}

private static String generateCorrelationId() {
    return UserInfo.getOrganizationId() + '-' + String.valueOf(System.currentTimeMillis());
}
```

---

## Middleware vs Direct Salesforce Integrations

### Decision Table

| Pattern | Use When | Pros | Cons |
|---|---|---|---|
| Direct Salesforce callout | Simple API, low volume, low complexity, single-system target | Simple, fewer infrastructure components, lower cost | Subject to Apex callout limits (100 per transaction), retry complexity in Apex |
| Middleware (MuleSoft, AWS API Gateway, etc.) | Complex transformations, multi-system fan-out, high volume, guaranteed delivery needed | Decoupled, retry/routing logic in middleware, protocol translation | Additional infrastructure, licensing cost, operational overhead |
| Platform Events (async) | Fire-and-forget notifications, decoupled pub/sub, no immediate response needed | Async, decoupled, survives consumer downtime, supports replay | No immediate response, eventual consistency, limits apply |
| Change Data Capture (CDC) | External system needs to react to Salesforce record changes automatically | Automatic (no custom publish code), supports all standard/custom objects | Consumer must be external and subscribe via Streaming API/CometD |
| Outbound Messages | Simple legacy SOAP consumer, declarative field notification | Declarative (no Apex for publish), reliable delivery with acknowledgment | SOAP only, limited payload, legacy mechanism — not recommended for new builds |
| Bulk API 2.0 | Large-volume inbound/outbound data loads (thousands to millions of records) | Handles very large volumes, asynchronous, official bulk mechanism | Not for real-time, requires job polling, more complex error handling |

### Selection Guidance

Use **direct Salesforce callout** when:
- The integration is simple and involves one external system
- Volume is manageable within Apex governor limits
- Response must be immediate (synchronous)

Use **middleware** when:
- Multiple external systems need to receive the same data (fan-out)
- Complex transformation or routing logic would bloat Apex
- The external system has rate limits requiring request queuing/throttling

Use **Platform Events** when:
- The operation is fire-and-forget (no immediate response needed)
- The consumer may be temporarily offline (replay buffer provides durability)
- Decoupling publisher from consumer is architecturally important

Use **CDC** when:
- An external system needs to stay synchronized with Salesforce record changes
- You want zero custom publish code on the Salesforce side
- The external team owns the consumer (external CometD/Streaming API subscriber)

---

## Platform Events

### Overview
Platform Events are Salesforce's pub/sub mechanism for asynchronous, decoupled messaging. They are fire-and-forget from the publisher's perspective and support both internal Apex/Flow subscribers and external CometD subscribers.

### When to Use Platform Events
- Async notifications that do not require an immediate response
- Decoupling high-volume operations from synchronous DML transactions
- Notifying external systems of Salesforce-side events without tight coupling
- Audit-trail style event streaming

### Defining a Platform Event
Create via Setup > Platform Events or via metadata:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<CustomObject xmlns="http://soap.sforce.com/2006/04/metadata">
    <label>Case Status Changed</label>
    <pluralLabel>Case Status Changed Events</pluralLabel>
    <deploymentStatus>Deployed</deploymentStatus>
    <fields>
        <fullName>Case_Id__c</fullName>
        <label>Case Id</label>
        <type>Text</type>
        <length>18</length>
    </fields>
    <fields>
        <fullName>New_Status__c</fullName>
        <label>New Status</label>
        <type>Text</type>
        <length>255</length>
    </fields>
    <fields>
        <fullName>Correlation_Id__c</fullName>
        <label>Correlation Id</label>
        <type>Text</type>
        <length>255</length>
    </fields>
</CustomObject>
```

### Publishing a Platform Event in Apex

```apex
/**
 * Description: Publishes a Case Status Changed platform event.
 * Uses EventBus.publish for Publish After Commit behavior.
 */
public static void publishCaseStatusChanged(Id caseId, String newStatus, String correlationId) {
    Case_Status_Changed__e event = new Case_Status_Changed__e(
        Case_Id__c = caseId,
        New_Status__c = newStatus,
        Correlation_Id__c = correlationId
    );

    Database.SaveResult result = EventBus.publish(event);

    if (!result.isSuccess()) {
        for (Database.Error err : result.getErrors()) {
            AppLogger.error('PlatformEventPublisher', null,
                'Failed to publish Case_Status_Changed__e: ' + err.getMessage(), caseId);
        }
    }
}
```

### Publish Behavior
| Mode | Behavior | Use When |
|---|---|---|
| `Publish After Commit` (default via `EventBus.publish`) | Event is published only if the transaction commits successfully | Standard use — ensures event is published only on successful DML |
| `Publish Immediately` (via `EventBus.publish` in some contexts) | Event published regardless of transaction outcome | Rarely needed; use with caution as it can result in events for failed transactions |

### Subscribing in Apex Trigger
```apex
trigger CaseStatusChangedTrigger on Case_Status_Changed__e (after insert) {
    for (Case_Status_Changed__e event : Trigger.new) {
        // Process the event — no DML limits apply per transaction
        CaseStatusChangedHandler.handle(event.Case_Id__c, event.New_Status__c);
    }
}
```

### Subscribing from External System
External subscribers connect via CometD (Streaming API):
- Channel: `/event/Case_Status_Changed__e`
- Authentication: OAuth 2.0 access token
- Replay ID: store the last-processed replay ID to resume after disconnection

### Governor Limits
- Standard: 250,000 events per 24-hour period (verify in current Salesforce release notes — this limit changes)
- High Volume events have separate limits
- Apex triggers on Platform Events count toward per-transaction limits (SOQL, DML, CPU time)
- Always check current limits at: https://developer.salesforce.com/docs/atlas.en-us.platform_events.meta/platform_events/platform_events_limits.htm

---

## Change Data Capture (CDC)

### Overview
Change Data Capture automatically generates change events whenever a Salesforce record is created, updated, deleted, or undeleted. External systems subscribe to these events via the Salesforce Streaming API (CometD). No custom Apex publish code is required.

### Enabling CDC
1. Navigate to Setup > Integrations > Change Data Capture
2. Select the objects to enable (standard objects: Account, Contact, Case, Opportunity, etc.; custom objects supported)
3. Save — CDC events begin flowing immediately

### CDC Event Structure
Each CDC event includes:
```json
{
  "schema": "...",
  "payload": {
    "ChangeEventHeader": {
      "entityName": "Case",
      "changeType": "UPDATE",
      "changedFields": ["Status", "Priority"],
      "changeOrigin": "com/salesforce/api/rest/...",
      "transactionKey": "...",
      "sequenceNumber": 1,
      "commitTimestamp": 1714000000000,
      "recordIds": ["5000000000000AAA"]
    },
    "Status": "Closed",
    "Priority": "Low"
  }
}
```

### Change Types
| changeType | Description |
|---|---|
| `CREATE` | New record created |
| `UPDATE` | Existing record updated (changedFields lists only changed fields) |
| `DELETE` | Record deleted (hard delete) |
| `UNDELETE` | Record restored from recycle bin |

### External Consumer Pattern
External consumers (e.g., MuleSoft, Node.js, Java service):
1. Authenticate to Salesforce via OAuth 2.0
2. Subscribe to CometD channel: `/data/CaseChangeEvent`
3. Store last received replay ID durably
4. On reconnect, provide stored replay ID to receive missed events (up to 3-day retention)

### When to Use CDC vs Platform Events
| CDC | Platform Events |
|---|---|
| External system needs to know about ALL changes to a Salesforce object | Internal Salesforce system or external needs to know about specific business events |
| No custom publish code needed | Custom publish logic needed (conditional, enriched payload) |
| Automatic — works for standard and custom object changes | Manual — developer must publish explicitly |
| Payload is the changed record fields | Payload is whatever fields are defined on the Platform Event |

---

## Outbound Messages (SOAP, Legacy)

### Overview
Outbound Messages are a declarative mechanism to send SOAP notifications to an external endpoint when a Salesforce record field changes. They are configured via Setup > Process Automation > Workflow Rules (legacy) or Process Builder.

### Status
**Outbound Messages are a legacy pattern.** Use Platform Events for all new integration development.

### Appropriate Use Cases
- Existing legacy SOAP consumers that cannot be migrated to Platform Events
- Simple field-change notifications where the consumer is already a SOAP endpoint
- Maintenance of existing Outbound Message integrations

### How It Works
1. A Workflow Rule or Process Builder action triggers the Outbound Message
2. Salesforce sends a SOAP `notifications` request to the configured endpoint URL
3. The external endpoint must respond with `<Ack>true</Ack>` to confirm receipt
4. Salesforce retries delivery for up to 24 hours if acknowledgment is not received

### Limitations
- SOAP only (no REST, no JSON)
- Limited payload — only fields selected at configuration time
- Cannot include related object data without field update workarounds
- Configured via legacy tooling (Workflow Rules — being retired)
- Cannot conditionally include data or transform the payload

### Migration Path
If maintaining an Outbound Message integration, document a migration plan to Platform Events for the next major release cycle.

---

## REST API Integration Patterns

### Inbound REST Integration (External System Calls Salesforce)

**Pattern: Custom Apex REST Resource**
Use when:
- The external system needs to send data to Salesforce via a custom endpoint
- Standard Salesforce REST API (sObject API) does not cover the needed business logic

```apex
/**
 * Description: Custom REST endpoint for inbound case creation from external system.
 * Endpoint: /services/apexrest/cases/v1
 */
@RestResource(urlMapping='/cases/v1/*')
global with sharing class InboundCaseRestResource {

    @HttpPost
    global static CaseCreationResponse createCase() {
        RestRequest req = RestContext.request;
        String requestBody = req.requestBody.toString();

        // Parse and validate
        ExternalCaseRequest payload;
        try {
            payload = (ExternalCaseRequest) JSON.deserialize(requestBody, ExternalCaseRequest.class);
        } catch (JSONException e) {
            RestContext.response.statusCode = 400;
            return new CaseCreationResponse(false, null, 'Invalid JSON payload');
        }

        // Delegate to service layer
        try {
            Case newCase = CaseService.createFromExternalRequest(payload);
            RestContext.response.statusCode = 201;
            return new CaseCreationResponse(true, newCase.Id, null);
        } catch (CaseService.InvalidInputException e) {
            RestContext.response.statusCode = 400;
            return new CaseCreationResponse(false, null, e.getMessage());
        } catch (Exception e) {
            RestContext.response.statusCode = 500;
            AppLogger.error('InboundCaseRestResource', null, e.getMessage(), requestBody);
            return new CaseCreationResponse(false, null, 'Internal error — contact support');
        }
    }

    global class ExternalCaseRequest {
        global String externalId;
        global String subject;
        global String description;
        global String priority;
    }

    global class CaseCreationResponse {
        global Boolean success;
        global String salesforceCaseId;
        global String errorMessage;

        global CaseCreationResponse(Boolean success, String caseId, String error) {
            this.success = success;
            this.salesforceCaseId = caseId;
            this.errorMessage = error;
        }
    }
}
```

### Outbound REST Integration (Salesforce Calls External System)
See [Apex HTTP Client Pattern](#apex-http-client-pattern) section above.

### Bulk API 2.0
Use for high-volume data loads (typically 10,000+ records):
- Create a Bulk API 2.0 job via REST
- Upload CSV data in batches
- Poll job status until complete
- Download results (successful and failed records)

Best for: nightly syncs, large data migrations, batch ETL processes. Not suitable for real-time operations.

### Composite API
Use to perform multiple sObject operations in a single HTTP request (up to 25 sub-requests):
```json
{
  "compositeRequest": [
    {
      "method": "POST",
      "url": "/services/data/v60.0/sobjects/Account",
      "referenceId": "newAccount",
      "body": { "Name": "New Account" }
    },
    {
      "method": "POST",
      "url": "/services/data/v60.0/sobjects/Contact",
      "referenceId": "newContact",
      "body": {
        "LastName": "Smith",
        "AccountId": "@{newAccount.id}"
      }
    }
  ]
}
```

Use when: creating related records atomically, reducing HTTP round trips from external systems.

### Authentication for Inbound (External System to Salesforce)
- Always use OAuth 2.0 via a Connected App
- For server-to-server: OAuth 2.0 Client Credentials or JWT Bearer
- For user-initiated: OAuth 2.0 Authorization Code with PKCE
- Never share a Named User's credentials for integration purposes — use Integration User + Connected App
- Integration User should have minimal permissions (only what the integration needs)

---

## Idempotency Keys

### Why Idempotency Matters
Without idempotency, retried requests (due to network failures, timeout on the caller side, or retry logic) can create duplicate records or trigger duplicate side effects. Every inbound integration that creates or updates records must support idempotency.

### Implementation Pattern: External ID Upsert
```apex
// External ID field on Case: External_Id__c (type: Text, External ID = true, Unique = true)

public static void upsertCasesFromExternalPayload(List<ExternalCasePayload> payloads) {
    List<Case> casesToUpsert = new List<Case>();

    for (ExternalCasePayload payload : payloads) {
        casesToUpsert.add(new Case(
            External_Id__c = payload.externalId,   // Idempotency key = source system ID
            Subject = payload.subject,
            Description = payload.description,
            Status = 'New'
        ));
    }

    // Upsert by External_Id__c — safe to run multiple times with same payload
    List<Database.UpsertResult> results = Database.upsert(casesToUpsert, Case.External_Id__c, false);

    for (Integer i = 0; i < results.size(); i++) {
        if (!results.get(i).isSuccess()) {
            AppLogger.error('CaseUpsertService', null,
                'Upsert failed for External_Id__c=' + casesToUpsert[i].External_Id__c,
                JSON.serialize(results.get(i).getErrors()));
        }
    }
}
```

### Idempotency Key Rules
- The idempotency key is the **source system's unique identifier** for the record/operation — never a Salesforce ID
- The External ID field must be: `External ID = true`, `Unique = true` on the Salesforce object
- `Database.upsert` with the External ID field is inherently idempotent — if the record exists, it is updated; if not, it is created
- Log every upsert attempt with the idempotency key for audit purposes

### Outbound Idempotency
For outbound integrations, include an idempotency key header with every request to external systems that support it:
```apex
req.setHeader('Idempotency-Key', correlationId); // Use the operation's correlation ID
```

---

## Retry Strategy

### Failure Classification

| HTTP Status / Error | Classification | Action |
|---|---|---|
| `CalloutException` (timeout) | Transient | Retry with exponential backoff |
| 408 Request Timeout | Transient | Retry |
| 429 Too Many Requests | Transient | Retry with backoff (respect Retry-After header if present) |
| 500 Internal Server Error | Transient | Retry |
| 502 Bad Gateway | Transient | Retry |
| 503 Service Unavailable | Transient | Retry |
| 400 Bad Request | Permanent | Log error, do not retry, alert |
| 401 Unauthorized | Permanent (auth failure) | Log error, alert operations immediately, do not retry automatically |
| 403 Forbidden | Permanent (auth failure) | Log error, alert operations immediately |
| 404 Not Found | Permanent (data issue) | Log error, may indicate sync problem, do not retry |
| 409 Conflict | Context-dependent | Log, investigate — may be a data sync issue |
| 201/200 | Success | No retry needed |

### Retry with Queueable Apex

```apex
/**
 * Description: Retry queueable for transient ExternalCaseAPI integration failures.
 * Implements exponential backoff via re-enqueue (Salesforce does not support true sleep).
 * Developer: Naresh
 * Title: Senior Salesforce Developer
 */
public class IntegrationRetryQueueable implements Queueable, Database.AllowsCallouts {

    private final String payload;
    private final Integer attemptCount;
    private final String operationType;
    private static final Integer MAX_ATTEMPTS = 3;

    public IntegrationRetryQueueable(String payload, Integer attemptCount, String operationType) {
        this.payload = payload;
        this.attemptCount = attemptCount;
        this.operationType = operationType;
    }

    public void execute(QueueableContext ctx) {
        try {
            ExternalCaseApiClient.ExternalCaseApiResponse response;

            if (operationType == 'createCase') {
                response = ExternalCaseApiClient.createCase(payload);
            } else {
                AppLogger.error('IntegrationRetryQueueable', ctx.getJobId(),
                    'Unknown operationType: ' + operationType, payload);
                return;
            }

            if (!response.success && response.isRetryable && attemptCount < MAX_ATTEMPTS) {
                // Re-enqueue for next retry attempt
                System.enqueueJob(new IntegrationRetryQueueable(payload, attemptCount + 1, operationType));
                AppLogger.warn('IntegrationRetryQueueable', ctx.getJobId(),
                    'Retry attempt ' + (attemptCount + 1) + ' of ' + MAX_ATTEMPTS + ' enqueued', payload);

            } else if (!response.success) {
                // Max retries exceeded or non-retryable error
                AppLogger.error('IntegrationRetryQueueable', ctx.getJobId(),
                    'Max retries exceeded or non-retryable error after ' + attemptCount + ' attempts. '
                    + response.errorMessage, payload);
                // Insert dead-letter record or trigger alert
                IntegrationDeadLetterService.record(operationType, payload, response.errorMessage);

            } else {
                AppLogger.info('IntegrationRetryQueueable', ctx.getJobId(),
                    'Retry succeeded on attempt ' + attemptCount, null);
            }

        } catch (Exception e) {
            if (attemptCount < MAX_ATTEMPTS) {
                System.enqueueJob(new IntegrationRetryQueueable(payload, attemptCount + 1, operationType));
            } else {
                AppLogger.error('IntegrationRetryQueueable', ctx.getJobId(),
                    'Max retries exceeded with exception: ' + e.getMessage(), payload);
                IntegrationDeadLetterService.record(operationType, payload, e.getMessage());
            }
        }
    }
}
```

### Retry Configuration via Custom Metadata
Store retry configuration in a Custom Metadata Type rather than hardcoding:

```
Integration_Config__mdt
├── MaxRetryAttempts__c (Number)
├── TimeoutMs__c (Number)
├── IntegrationName__c (Text, Master Label)
└── IsActive__c (Checkbox)
```

Query at runtime:
```apex
Integration_Config__mdt config = Integration_Config__mdt.getInstance('ExternalCaseAPI');
Integer maxAttempts = (Integer) config.MaxRetryAttempts__c;
```

---

## Error Handling

### HTTP Status Code Mapping

| Status Code | Meaning | Salesforce Response |
|---|---|---|
| 200–299 | Success | Parse response, proceed |
| 400 | Bad request (invalid payload) | Log with payload summary (no PII), do not retry, alert dev team |
| 401 | Unauthorized (invalid token/credentials) | Log, alert operations immediately, do not retry — requires credential rotation |
| 403 | Forbidden (insufficient permissions) | Log, alert operations, investigate permissions on external system |
| 404 | Not found | Log — may indicate data sync issue between systems |
| 409 | Conflict | Log, investigate — may be duplicate or stale data |
| 429 | Rate limited | Retry with exponential backoff; respect `Retry-After` header |
| 500 | Internal server error | Retry (transient); if persists after retries, alert |
| 502/503/504 | Gateway/unavailable errors | Retry (transient) |
| Timeout (CalloutException) | Network/host unreachable | Retry (transient) |

### Exception Hierarchy Pattern

```apex
// Base integration exception
public class IntegrationException extends Exception {}

// Authentication failure — requires ops alert
public class IntegrationAuthException extends IntegrationException {}

// Transient failure — eligible for retry
public class IntegrationTransientException extends IntegrationException {}

// Permanent failure — do not retry
public class IntegrationPermanentException extends IntegrationException {}
```

### Error Message Safety
- NEVER surface raw HTTP error bodies to end users (may contain stack traces, internal system paths, or PII)
- Log the raw error body to `AppLog__c` for debugging (with PII redacted from logs)
- Show end users a generic message: "Integration is temporarily unavailable. Reference ID: {correlationId}"
- Include the correlation ID in the user-facing message so it can be traced in logs

---

## Observability

### AppLog__c Custom Object Schema

| Field | Type | Purpose |
|---|---|---|
| `IntegrationName__c` | Text(255) | Name of the integration (e.g., `ExternalCaseAPI`) |
| `Direction__c` | Picklist | `Inbound` or `Outbound` |
| `Status__c` | Picklist | `Success`, `Failure`, `Retry` |
| `StatusCode__c` | Number | HTTP status code |
| `DurationMs__c` | Number | Call duration in milliseconds |
| `CorrelationId__c` | Text(255) | Unique identifier for this operation (for cross-system tracing) |
| `RequestSummary__c` | LongTextArea | Summary of request (no PII, no secrets) |
| `ErrorMessage__c` | LongTextArea | Error description (no raw secrets or PII) |
| `CreatedDate` | DateTime | Automatic — timestamp of log entry |
| `RelatedRecordId__c` | Text(18) | Salesforce ID of the record being processed (for drill-down) |

### Logging Pattern

```apex
public class AppLogger {

    public static void logIntegration(
        String integrationName,
        String direction,
        Integer statusCode,
        Long durationMs,
        String correlationId,
        String requestSummary,
        String errorMessage
    ) {
        String status = (statusCode >= 200 && statusCode < 300) ? 'Success' : 'Failure';

        AppLog__c log = new AppLog__c(
            IntegrationName__c = integrationName,
            Direction__c = direction,
            Status__c = status,
            StatusCode__c = statusCode,
            DurationMs__c = durationMs,
            CorrelationId__c = correlationId,
            RequestSummary__c = requestSummary,
            ErrorMessage__c = errorMessage
        );

        // Use Database.insert(log, false) to avoid failing the main transaction on log failure
        Database.insert(log, false);
    }
}
```

### Usage in Service Class
```apex
Long startTime = System.currentTimeMillis();
ExternalCaseApiClient.ExternalCaseApiResponse response = ExternalCaseApiClient.createCase(payload);
Long duration = System.currentTimeMillis() - startTime;

AppLogger.logIntegration(
    'ExternalCaseAPI',
    'Outbound',
    response.statusCode,
    duration,
    correlationId,
    'Create case for Account: ' + accountId,   // No PII
    response.success ? null : response.errorMessage
);
```

### Alert Conditions
Configure Salesforce Flow or an external monitoring tool to alert on:
- **Authentication failure** (status 401 or 403): Alert immediately — credentials may be expired or rotated
- **Consecutive failures** (3+ failures within 5 minutes for the same integration): Alert operations — external system may be down
- **Sustained high latency** (DurationMs > 10,000 consistently): Alert — performance degradation

### Sample Health Query
```soql
SELECT IntegrationName__c, Direction__c, Status__c, COUNT(Id) LogCount
FROM AppLog__c
WHERE CreatedDate = LAST_N_MINUTES:60
GROUP BY IntegrationName__c, Direction__c, Status__c
ORDER BY IntegrationName__c, Status__c
```

---

## Secrets Management

### Absolute Rules
| Item | Allowed Storage | PROHIBITED Storage |
|---|---|---|
| API keys | Named Credential / External Credential | Apex code, Custom Metadata, Custom Settings, Hard-Coded |
| OAuth client secret | External Credential (secure parameter) | ANY code or metadata |
| OAuth access token | Managed by External Credential (auto-refresh) | Apex variables persisted to fields |
| Basic auth password | Named Credential (set via UI — not XML) | Apex code, Custom Metadata |
| Private keys / certificates | Setup > Certificate and Key Management | Code, metadata, files |
| Webhook secrets (inbound) | Custom Settings (encrypted) or Named Credential | Apex string literals |

### Named Credential Update for Secret Rotation
When an API key or client secret is rotated:
1. Go to Setup > Named Credentials (or External Credentials)
2. Edit the credential — update the secret value
3. Save — no code change, no deployment required
4. Verify the integration is working post-rotation via a test call

### Certificate Rotation Procedure
1. Generate a new certificate in Setup > Certificate and Key Management (or upload a new CSR-based certificate)
2. Register the new public key with the external system
3. Update the External Credential to reference the new certificate
4. Verify the integration works with the new certificate
5. Delete the old certificate after confirming the new one is working
6. Document the rotation in the integration runbook

---

## Test Mocks

### HttpCalloutMock Interface
Every Apex test that invokes code containing `new Http().send(req)` MUST use `Test.setMock` with an `HttpCalloutMock` implementation. Failing to do so will cause the test to throw a `System.CalloutException` (cannot make callouts in test context without a mock).

### Single Endpoint Mock

```apex
/**
 * Description: HttpCalloutMock for ExternalCaseAPI integration tests.
 * Developer: Naresh
 * Title: Senior Salesforce Developer
 */
@isTest
public class ExternalCaseApiMock implements HttpCalloutMock {

    private final Integer statusCode;
    private final String body;
    private final String contentType;

    public ExternalCaseApiMock(Integer statusCode, String body) {
        this.statusCode = statusCode;
        this.body = body;
        this.contentType = 'application/json';
    }

    public HTTPResponse respond(HTTPRequest req) {
        HttpResponse res = new HttpResponse();
        res.setStatusCode(statusCode);
        res.setBody(body);
        res.setHeader('Content-Type', contentType);
        return res;
    }
}
```

### Multi-Endpoint Mock (MultiRequestMock)

```apex
@isTest
public class MultiRequestMock implements HttpCalloutMock {

    private Map<String, HttpCalloutMock> mocksByEndpoint;

    public MultiRequestMock(Map<String, HttpCalloutMock> mocksByEndpoint) {
        this.mocksByEndpoint = mocksByEndpoint;
    }

    public HTTPResponse respond(HTTPRequest req) {
        String endpoint = req.getEndpoint();
        // Match by URL substring
        for (String key : mocksByEndpoint.keySet()) {
            if (endpoint.contains(key)) {
                return mocksByEndpoint.get(key).respond(req);
            }
        }
        // No match — return 404
        HttpResponse res = new HttpResponse();
        res.setStatusCode(404);
        res.setBody('{"error":"No mock configured for endpoint: ' + endpoint + '"}');
        return res;
    }
}
```

### Complete Test Class with Multiple Scenarios

```apex
@isTest
private class ExternalCaseApiClientTest {

    // Success scenario
    @isTest
    static void testCreateCase_Success() {
        // Arrange
        String successBody = '{"id":"EXT-001","status":"created"}';
        Test.setMock(HttpCalloutMock.class, new ExternalCaseApiMock(201, successBody));

        // Act
        Test.startTest();
        ExternalCaseApiClient.ExternalCaseApiResponse result =
            ExternalCaseApiClient.createCase('{"subject":"Test Case"}');
        Test.stopTest();

        // Assert
        System.assert(result.success, 'Expected success=true for HTTP 201');
        System.assertEquals(201, result.statusCode, 'Expected status code 201');
        System.assert(result.body.contains('EXT-001'), 'Expected external ID in response body');
    }

    // Server error — should set isRetryable
    @isTest
    static void testCreateCase_ServerError() {
        // Arrange
        Test.setMock(HttpCalloutMock.class, new ExternalCaseApiMock(500, '{"error":"Internal Server Error"}'));

        // Act
        Test.startTest();
        ExternalCaseApiClient.ExternalCaseApiResponse result =
            ExternalCaseApiClient.createCase('{"subject":"Test Case"}');
        Test.stopTest();

        // Assert
        System.assert(!result.success, 'Expected success=false for HTTP 500');
        System.assert(result.isRetryable, 'Expected isRetryable=true for HTTP 500');
        System.assertEquals(500, result.statusCode, 'Expected status code 500');
    }

    // Auth failure scenario
    @isTest
    static void testCreateCase_AuthFailure() {
        // Arrange
        Test.setMock(HttpCalloutMock.class, new ExternalCaseApiMock(401, '{"error":"Unauthorized"}'));

        // Act
        Test.startTest();
        ExternalCaseApiClient.ExternalCaseApiResponse result =
            ExternalCaseApiClient.createCase('{"subject":"Test Case"}');
        Test.stopTest();

        // Assert
        System.assert(!result.success, 'Expected success=false for HTTP 401');
        System.assert(result.isAuthFailure, 'Expected isAuthFailure=true for HTTP 401');
        System.assert(!result.isRetryable, 'Expected isRetryable=false for HTTP 401');
    }

    // Rate limited scenario
    @isTest
    static void testCreateCase_RateLimited() {
        // Arrange
        Test.setMock(HttpCalloutMock.class, new ExternalCaseApiMock(429, '{"error":"Too Many Requests"}'));

        // Act
        Test.startTest();
        ExternalCaseApiClient.ExternalCaseApiResponse result =
            ExternalCaseApiClient.createCase('{"subject":"Test Case"}');
        Test.stopTest();

        // Assert
        System.assert(!result.success, 'Expected success=false for HTTP 429');
        System.assert(result.isRetryable, 'Expected isRetryable=true for HTTP 429');
    }

    // Callout exception (network failure)
    @isTest
    static void testCreateCase_CalloutException() {
        // Arrange — no mock set; CalloutException will be thrown by the client
        // Use a mock that throws CalloutException
        Test.setMock(HttpCalloutMock.class, new CalloutExceptionMock());

        // Act + Assert
        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            ExternalCaseApiClient.createCase('{"subject":"Test Case"}');
        } catch (ExternalCaseApiClient.IntegrationException e) {
            exceptionThrown = true;
            System.assert(e.getMessage().contains('Callout failed'),
                'Expected IntegrationException with callout failed message');
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'Expected IntegrationException to be thrown on callout error');
    }

    // Helper: mock that simulates a network-level CalloutException
    private class CalloutExceptionMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            throw new CalloutException('Simulated network failure');
        }
    }
}
```

---

## Common AI Mistakes to Avoid

The following are frequent errors made by AI-generated integration code. Every code review must check for these.

| Mistake | Description | Correct Approach |
|---|---|---|
| Hardcoded endpoint URLs in Apex | `req.setEndpoint('https://api.example.com/...')` | Always use `callout:NamedCredentialName/path` |
| Secrets in Custom Metadata | Storing API keys in `Integration_Config__mdt.API_Key__c` | Use Named Credential / External Credential exclusively |
| Secrets in Custom Settings | Storing tokens in `Integration_Settings__c.Token__c` | Use Named Credential / External Credential exclusively |
| No idempotency for inbound data | Creating records without upsert by External ID | Always use `Database.upsert` with External ID field |
| DML inside callout code | Attempting `insert record` in the same method as `Http.send()` | Perform callout first, collect results, do DML after in the service layer |
| No timeout set on HttpRequest | Omitting `req.setTimeout(ms)` | Always set timeout; default can be very long and waste governor limits |
| No retry strategy | Failing silently or throwing an exception with no re-queue | Implement `IntegrationRetryQueueable` for transient failures |
| Swallowing exceptions | `} catch (Exception e) { /* do nothing */ }` | Always log to `AppLog__c`, re-throw or handle appropriately |
| Testing with real endpoints | Not using `Test.setMock` in test methods | Always implement `HttpCalloutMock` for every test of callout-containing code |
| Using Platform Events for synchronous response | Publishing a Platform Event and waiting for the response in the same transaction | Use direct callout (synchronous) when immediate response is required |
| Retry DML after partial success | Retrying a bulk DML operation without idempotency check | Use External ID upsert — safe to retry because it is idempotent |
| No correlation ID | Integration calls cannot be traced end-to-end | Generate and attach correlation ID to every integration call and log entry |
| Raw error messages to users | `throw new AuraHandledException(response.rawBody)` | Sanitize error messages; provide correlation ID; log raw error internally |

---

## Definition of Done

An integration is considered complete and ready for production only when ALL of the following are checked:

- [ ] Named Credential created and deployed — no hardcoded URL in Apex
- [ ] External Credential configured for authentication (if OAuth 2.0, JWT, or certificate-based)
- [ ] Permission Set grants access to External Credential principal (if applicable)
- [ ] HTTP client class created per external system with `req.setTimeout(TIMEOUT_MS)` always set
- [ ] Service class handles orchestration, retry enqueue, and domain error handling
- [ ] Idempotency strategy implemented — External ID upsert for all inbound data loads
- [ ] Error handling implemented — HTTP status code mapping, typed exceptions, no raw errors to users
- [ ] Retry strategy implemented — `IntegrationRetryQueueable` for transient failures, max attempts via CMDT
- [ ] Dead-letter mechanism implemented — failed operations after max retries are logged/recorded
- [ ] Logging implemented — correlation ID, duration, status, integration name per call in `AppLog__c`
- [ ] No PII or secrets in any log entry
- [ ] Alerts configured — authentication failures, consecutive failures (3+ in 5 min), high latency
- [ ] Test class created with `HttpCalloutMock` for: 200/201 success, 4xx error, 5xx error, timeout/CalloutException
- [ ] Bulk test for 200-record scenarios where applicable
- [ ] Test coverage ≥ 85% for all integration classes
- [ ] Deployment validated with `--check-only --test-level RunLocalTests` in target sandbox
- [ ] Integration runbook documented (rotation procedure, rollback steps, support contacts)

---

## Validation Commands

```bash
# Retrieve Named Credential and External Credential metadata from org
sf project retrieve start \
  --metadata "NamedCredential:ExternalCaseAPI,ExternalCredential:ExternalCaseOAuth" \
  --target-org <alias>

# Validate deployment (check-only, run all local tests)
sf project deploy start \
  --manifest manifest/package.xml \
  --target-org <alias> \
  --check-only \
  --test-level RunLocalTests \
  --wait 60

# Deploy integration components
sf project deploy start \
  --manifest manifest/package.xml \
  --target-org <alias> \
  --test-level RunLocalTests \
  --wait 60

# Run only integration-related tests
sf apex run test \
  --class-names ExternalCaseApiClientTest,IntegrationRetryQueueableTest \
  --target-org <alias> \
  --result-format human \
  --wait 10

# Check recent AppLog__c entries for a specific integration
sf data query \
  --query "SELECT Id, IntegrationName__c, Status__c, StatusCode__c, DurationMs__c, CorrelationId__c, ErrorMessage__c, CreatedDate FROM AppLog__c WHERE IntegrationName__c = 'ExternalCaseAPI' ORDER BY CreatedDate DESC LIMIT 20" \
  --target-org <alias>
```

---

## Official References

- Apex Callouts: https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_callouts.htm
- Streaming API (CometD/Platform Events): https://developer.salesforce.com/docs/atlas.en-us.api_streaming.meta/api_streaming/intro_stream.htm
- Change Data Capture: https://developer.salesforce.com/docs/atlas.en-us.change_data_capture.meta/change_data_capture/
- Named Credentials: https://help.salesforce.com/s/articleView?id=sf.named_credentials_about.htm
- Platform Events Developer Guide: https://developer.salesforce.com/docs/atlas.en-us.platform_events.meta/platform_events/
- External Credentials: https://help.salesforce.com/s/articleView?id=sf.external_credentials.htm
- Bulk API 2.0: https://developer.salesforce.com/docs/atlas.en-us.api_asynch.meta/api_asynch/
- Composite API: https://developer.salesforce.com/docs/atlas.en-us.api_rest.meta/api_rest/resources_composite_composite.htm
- Apex REST Resources: https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_rest_intro.htm
- Platform Event Limits: https://developer.salesforce.com/docs/atlas.en-us.platform_events.meta/platform_events/platform_events_limits.htm
