# Integration Guidelines — Canonical Reference

Authoritative rulebook for outbound and inbound Salesforce integrations in the Plusgrade org. Covers Named Credentials + External Credentials, Apex HTTP callouts, Platform Events, Change Data Capture, async patterns, idempotency, retry/circuit-breaker, observability, and AppExchange/MuleSoft considerations.

**Verified against:** [Apex Callouts](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_callouts.htm) · [Named Credentials](https://help.salesforce.com/s/articleView?id=sf.named_credentials_about.htm) · [External Credentials](https://help.salesforce.com/s/articleView?id=sf.external_credentials.htm) · [Platform Events Developer Guide](https://developer.salesforce.com/docs/atlas.en-us.platform_events.meta/platform_events/) · [Change Data Capture Developer Guide](https://developer.salesforce.com/docs/atlas.en-us.change_data_capture.meta/change_data_capture/) · [Continuation Class](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_continuation_overview.htm) · [Pub/Sub API](https://developer.salesforce.com/docs/platform/pub-sub-api/overview.html) · [Composite API](https://developer.salesforce.com/docs/atlas.en-us.api_rest.meta/api_rest/resources_composite_composite.htm) · [forcedotcom/sf-skills `building-sf-integrations`](https://github.com/forcedotcom/sf-skills/tree/main/skills/building-sf-integrations) · [forcedotcom/sf-skills `configuring-connected-apps`](https://github.com/forcedotcom/sf-skills/tree/main/skills/configuring-connected-apps). Last verified 2026-05-16.

---

## 1. Hard Rules — Non-Negotiable

| # | Rule | Why |
|---|---|---|
| 1 | Every outbound endpoint goes through a Named Credential. `req.setEndpoint('callout:Foo/path')` is the only allowed form. | Endpoint URL + auth must live in metadata, not Apex |
| 2 | No API key, OAuth client secret, JWT signing material, or basic-auth password ever appears in Apex, Custom Metadata, Custom Setting, or git | Secret rotation must be a one-click Setup change, not a deploy |
| 3 | Every `HttpRequest` calls `req.setTimeout(N)` with an explicit value (max 120000) | Default callout timeout is small; explicit is the only way to be predictable |
| 4 | No callout from inside a trigger or any DML transaction context. Use `Queueable` + `Database.AllowsCallouts` | Sync callouts in trigger context throw `CalloutException: You have uncommitted work pending` |
| 5 | Every inbound write path is idempotent via External Id upsert | Network retries and at-least-once delivery from publishers will duplicate otherwise |
| 6 | Every outbound call writes one `AppLog__c` row with a correlation ID, integration name, direction, status code, duration | Without correlation IDs, cross-system tracing is impossible |
| 7 | Every test that exercises `Http.send` uses `Test.setMock(HttpCalloutMock.class, ...)` | Real callouts in test context fail with `Callout from scheduled Apex not supported` |

Violations of rules 1, 2, 3, 5 block deployment. Violations of 4, 6, 7 are review-blocking.

---

## 2. Architecture Layers

Every integration follows the same three-layer separation. Mixing layers (callout in trigger, DML in HTTP client) is the most common root cause of bugs and governor-limit failures.

```
Entry point (Flow / Trigger / LWC controller / Scheduled / Inbound Apex REST)
   -> Service class           (orchestration, retry, logging, DML)
   -> HTTP Client class       (builds HttpRequest, sends, parses)
   -> Named Credential -> External Credential   (endpoint + auth)
   -> External system
```

| Layer | Owns | Must NOT do |
|---|---|---|
| Trigger | Detect event, gather IDs, enqueue Queueable | Callouts, mixing concerns from multiple objects |
| Service | Orchestration, retry decisions, AppLog writes, post-callout DML | Build `HttpRequest` directly, hardcode URLs |
| HTTP Client | Build/send `HttpRequest`, parse response into typed wrapper, map status codes | DML, business logic, multi-system fanout |
| Named Credential | Base URL + link to External Credential | (metadata only) |
| External Credential | Auth protocol + principal + secret storage | (metadata + secure storage) |

One HTTP Client class per external system. Naming: `<SystemName>ApiClient`.

---

## 3. Named Credentials — The Modern Pattern

As of API 61+ (Spring '23 and later), Salesforce uses a split model: a **Named Credential** owns the endpoint URL and references an **External Credential**, which owns the auth protocol and principal. Secrets live in `UserExternalCredential` (a secure data object) — never in metadata XML.

### 3.1 Named Credential metadata

```xml
<NamedCredential xmlns="http://soap.sforce.com/2006/04/metadata">
   <fullName>MuleSoft_Case_API</fullName>
   <label>MuleSoft Case API</label>
   <endpoint>https://mulesoft.plusgrade.com</endpoint>
   <externalCredential>MuleSoft_Case_API_EC</externalCredential>
   <generateAuthorizationHeader>true</generateAuthorizationHeader>
   <allowMergeFieldsInBody>false</allowMergeFieldsInBody>
   <allowMergeFieldsInHeader>false</allowMergeFieldsInHeader>
</NamedCredential>
```

Keep `allowMergeFieldsInBody=false` unless you're consciously templating `{!$Credential.Username}` into request bodies — setting it true loosens security review.

### 3.2 External Credential metadata — OAuth 2.0 Client Credentials

```xml
<ExternalCredential xmlns="http://soap.sforce.com/2006/04/metadata">
   <fullName>MuleSoft_Case_API_EC</fullName>
   <label>MuleSoft Case API EC</label>
   <authenticationProtocol>Oauth</authenticationProtocol>
   <authenticationProtocolVariant>OauthClientCredentials</authenticationProtocolVariant>
   <principals>
      <parameters><parameterName>AuthenticationProtocolVariant</parameterName>
         <parameterValue>OauthClientCredentials</parameterValue></parameters>
      <principalName>MuleSoft_Service_Principal</principalName>
      <principalType>NamedPrincipal</principalType>
      <sequenceNumber>1</sequenceNumber>
   </principals>
</ExternalCredential>
```

### 3.3 Principal types

| Principal type | Use case |
|---|---|
| `NamedPrincipal` | Org-wide service account — all users/automation share the same auth context. Default for server-to-server. |
| `PerUser` | Each Salesforce user authenticates individually with the external system. Required for user-attributed audit trails. |
| `Anonymous` | Public API, no auth. Document why. |

### 3.4 Permission Set grant — required

Without a Permission Set granting External Credential Principal Access, every callout will fail with HTTP 401 even with the credential configured.

```xml
<PermissionSet>
   <externalCredentialPrincipalAccesses>
      <externalCredential>MuleSoft_Case_API_EC</externalCredential>
      <principal>MuleSoft_Service_Principal</principal>
      <enabled>true</enabled>
   </externalCredentialPrincipalAccesses>
</PermissionSet>
```

### 3.5 Legacy single-record `<protocol>Password</protocol>` form — forbidden

The legacy NamedCredential-only form (no ExternalCredential) stores credentials inline on the metadata record. Deprecated. New work uses the split model only; existing legacy credentials must be migrated when touched.

---

## 4. Apex HTTP Client Pattern

```apex
public with sharing class MuleSoftCaseApiClient {
   private static final String NAMED_CREDENTIAL = 'MuleSoft_Case_API';
   private static final Integer TIMEOUT_MS = 30000;
   private static final String BASE_PATH = '/api/v1';

   public static ApiResponse createCase(String idempotencyKey, String jsonBody) {
      return sendAndParse(buildRequest('POST', '/cases', jsonBody, idempotencyKey));
   }
   public static ApiResponse getCase(String extId, String corrId) {
      String path = '/cases/' + EncodingUtil.urlEncode(extId, 'UTF-8');
      return sendAndParse(buildRequest('GET', path, null, corrId));
   }

   private static HttpRequest buildRequest(String method, String path,
                                           String body, String corrId) {
      HttpRequest req = new HttpRequest();
      req.setMethod(method);
      req.setEndpoint('callout:' + NAMED_CREDENTIAL + BASE_PATH + path);
      req.setHeader('Content-Type', 'application/json');
      req.setHeader('Accept', 'application/json');
      req.setHeader('X-Correlation-Id', corrId);
      req.setHeader('Idempotency-Key', corrId);   // safe to retry
      req.setTimeout(TIMEOUT_MS);
      if (String.isNotBlank(body)) req.setBody(body);
      return req;
   }

   private static ApiResponse sendAndParse(HttpRequest req) {
      Long startMs = System.currentTimeMillis();
      HttpResponse res;
      try { res = new Http().send(req); }
      catch (CalloutException e) {
         throw new IntegrationException('Callout failed: ' + e.getMessage(), e);
      }
      ApiResponse r = new ApiResponse();
      r.statusCode = res.getStatusCode(); r.body = res.getBody();
      r.durationMs = System.currentTimeMillis() - startMs;
      if (r.statusCode >= 200 && r.statusCode < 300) r.success = true;
      else if (r.statusCode == 401 || r.statusCode == 403) r.isAuthFailure = true;
      else if (r.statusCode == 429 || r.statusCode >= 500) r.isRetryable = true;
      return r;
   }

   public class ApiResponse {
      public Integer statusCode; public String body; public Long durationMs;
      public Boolean success = false; public Boolean isRetryable = false;
      public Boolean isAuthFailure = false; public String errorMessage;
   }
   public class IntegrationException extends Exception {}
}
```

**Conventions:** `NAMED_CREDENTIAL` + `TIMEOUT_MS` are private static final; response is a typed inner class (never `Map<String,Object>`); classification (auth-failure / retryable / permanent) lives in the client; client throws only for network/transport failures — HTTP status codes are returned as data.

---

## 5. Callout Governor Limits

| Limit | Value | Practical impact |
|---|---|---|
| Callouts per transaction | **100** | Bulk ops must batch server-side or split across Queueables |
| Max callout timeout (single) | **120000 ms** (120s) | Beyond this → Continuation API or async pattern |
| Max combined callout time / transaction | **120000 ms** | All callouts together |
| HTTP request/response heap | 6 MB sync / 12 MB async | Large response bodies blow heap before parsing |
| Concurrent long-running callouts (>5s) | 10 per org | Saturation stalls all subsequent callouts |

When work plausibly exceeds any of these, switch pattern (Queueable, Continuation, Platform Event, Bulk API, middleware).

---

## 6. Async Pattern — Queueable + Database.AllowsCallouts

Default pattern when the entry point is a trigger or DML context. The `Database.AllowsCallouts` marker interface is what makes the callout legal.

```apex
public class MuleSoftCaseSyncQueueable
      implements Queueable, Database.AllowsCallouts {

   private final List<Id> caseIds;
   private final Integer attempt;
   private final String correlationId;
   private static final Integer MAX_ATTEMPTS = 3;

   public MuleSoftCaseSyncQueueable(List<Id> ids, Integer n, String corr) {
      this.caseIds = ids; this.attempt = n; this.correlationId = corr;
   }

   public void execute(QueueableContext ctx) {
      for (Case c : [SELECT Id, Subject, Status FROM Case
                     WHERE Id IN :caseIds WITH USER_MODE]) {
         String body = JSON.serialize(new Map<String, Object>{
            'externalId'=>c.Id, 'subject'=>c.Subject, 'status'=>c.Status});
         MuleSoftCaseApiClient.ApiResponse r =
            MuleSoftCaseApiClient.createCase(c.Id + '-' + correlationId, body);
         AppLogger.logIntegration('MuleSoft_Case_API', 'Outbound',
            r.statusCode, r.durationMs, correlationId,
            'createCase Case=' + c.Id, r.errorMessage);
         if (!r.success && r.isRetryable && attempt < MAX_ATTEMPTS) {
            System.enqueueJob(new MuleSoftCaseSyncQueueable(
               new List<Id>{c.Id}, attempt + 1, correlationId));
         } else if (!r.success) {
            IntegrationDeadLetterService.record(
               'MuleSoft_Case_API.createCase', body, r.errorMessage);
         }
      }
   }
}
```

**Queueable depth limit:** chaining is allowed but each org has a max stack depth (5 in test, higher in production). For deeper retry chains, use Scheduled Apex with a `Last_Attempt__c` timestamp on a custom queue object.

---

## 7. Idempotency Keys

### 7.1 Inbound — External Id upsert

```apex
// External_Id__c on Case: type=Text(80), ExternalId=true, Unique=true
List<Case> cases = new List<Case>();
for (ExternalCasePayload p : payloads) {
   cases.add(new Case(External_Id__c = p.externalId,
      Subject = p.subject, Status = 'New'));
}
Database.upsert(cases, Case.External_Id__c, /*allOrNone*/ false);
```

Rules: the External Id field is `ExternalId=true, Unique=true`; the upsert always uses `Database.upsert(records, External_Id__c, allOrNone=false)` with partial-success semantics; never use a Salesforce-generated Id as the idempotency key.

### 7.2 Outbound — Idempotency-Key header

Every mutating outbound request sets an `Idempotency-Key` header. The value is the operation's correlation ID — same value on the original and every retry. Stripe, Square, and most modern REST APIs honor this pattern: `req.setHeader('Idempotency-Key', correlationId);`. For systems that don't honor the header, design a server-side dedup mechanism (e.g., an `external_request_id` field on the receiving record) and document why the header isn't sufficient.

---

## 8. Retry Strategy & Circuit Breaker

### 8.1 Failure classification

| HTTP / error | Class | Retry? |
|---|---|---|
| `CalloutException` (network/timeout) | Transient | Yes — exponential backoff |
| 408, 429, 500, 502, 503, 504 | Transient | Yes (honor `Retry-After` on 429) |
| 400 | Permanent | No — dead-letter, alert dev |
| 401 / 403 | Auth | No — alert ops immediately |
| 404 | Permanent | No — data sync issue, dead-letter |
| 409 Conflict | Depends | Inspect — duplicate (success) or stale data (fail) |

### 8.2 Backoff schedule

Apex has no `Thread.sleep`. Backoff is implemented by re-enqueuing a Queueable; the gap is whatever the system scheduler provides plus the work already in the flex queue. For tighter timing, use Scheduled Apex with a calculated `cron`. Suggested attempt schedule: attempts 1 → 2 → 3, then dead-letter. Don't retry past 3.

### 8.3 Circuit breaker pattern

When N consecutive failures occur in a window, suspend further calls to the integration until manual reset or cooldown elapses. Maintain a `Integration_Circuit__c` record per integration with `ConsecutiveFailures__c` and `BreakerOpenUntil__c`. In the service class, check `BreakerOpenUntil__c < System.now()` before calling the HTTP client; when the breaker is open, short-circuit and write a `BreakerOpen` log row without making the callout. The breaker reopens after a documented cooldown (e.g., 5 minutes) or by manual admin reset.

---

## 9. Platform Events

### 9.1 When to use

Fire-and-forget async messaging. **Use when** the publisher doesn't need an immediate response, the consumer may be temporarily offline (Salesforce buffers up to 72h), or multiple consumers need the same event (fan-out). **Don't use when** the caller needs a synchronous response, the payload exceeds 1 MB, or volume exhausts the High Volume allocation.

### 9.2 Event definition

```xml
<CustomObject xmlns="http://soap.sforce.com/2006/04/metadata">
   <deploymentStatus>Deployed</deploymentStatus>
   <eventType>HighVolume</eventType>
   <publishBehavior>PublishAfterCommit</publishBehavior>
   <label>Case Status Changed</label>
   <pluralLabel>Case Status Changed Events</pluralLabel>
   <fields><fullName>Case_Id__c</fullName><label>Case Id</label><type>Text</type><length>18</length></fields>
   <fields><fullName>New_Status__c</fullName><label>New Status</label><type>Text</type><length>255</length></fields>
   <fields><fullName>Correlation_Id__c</fullName><label>Correlation Id</label><type>Text</type><length>255</length></fields>
</CustomObject>
```

### 9.3 Publish behavior

| Value | Behavior | Use |
|---|---|---|
| `PublishAfterCommit` | Event fires only after the publishing transaction commits | **Default — almost always correct.** Subscribers won't see events for rolled-back work |
| `PublishImmediately` | Event fires when `EventBus.publish` is called, regardless of commit | Only when external observability needs to record the attempt even on rollback |

### 9.4 Publish + Subscribe

```apex
// Publish
Database.SaveResult sr = EventBus.publish(new Case_Status_Changed__e(
   Case_Id__c = c.Id, New_Status__c = c.Status, Correlation_Id__c = corrId));
if (!sr.isSuccess()) AppLogger.error('PEPublisher', null,
   sr.getErrors()[0].getMessage(), c.Id);

// Subscribe
trigger CaseStatusChangedTrigger on Case_Status_Changed__e (after insert) {
   String lastReplayId;
   for (Case_Status_Changed__e ev : Trigger.new) {
      try { CaseStatusChangedHandler.handle(ev); lastReplayId = ev.ReplayId; }
      catch (Exception e) {
         AppLogger.error('CaseStatusChangedTrigger', ev.ReplayId,
            e.getMessage(), ev.Case_Id__c);   // never throw — kills the batch
      }
   }
   if (lastReplayId != null) {
      EventBus.TriggerContext.currentContext().setResumeCheckpoint(lastReplayId);
   }
}
```

**Resume checkpoint is required.** Without `setResumeCheckpoint`, a trigger failure causes Salesforce to retry the entire batch from the beginning — possibly forever if the failure is deterministic.

### 9.5 Subscribe (external — Pub/Sub API or CometD)

Modern external subscribers use **Pub/Sub API** (gRPC) — Salesforce's recommended replacement for CometD. Topic: `/event/Case_Status_Changed__e`. Authenticate via OAuth 2.0 (Integration User + Connected App / ECA). Store last-received ReplayId durably; on reconnect, resume from stored value. CometD streaming remains supported for legacy consumers but new builds target Pub/Sub API.

### 9.6 Limits

| Limit | Value |
|---|---|
| Event size | 1 MB |
| Retention | 72 hours (High Volume) |
| Standard Volume publish allocation | ~2,000/hour (varies by edition) |
| High Volume publish allocation | Up to millions/day (edition-dependent) |

Always check the current release notes — these change each release.

---

## 10. Change Data Capture (CDC)

### 10.1 Concept

CDC publishes a change event whenever a record on an enabled object is created, updated, deleted, or undeleted. The publish is automatic — no Apex publish code. External or internal consumers subscribe. Enable via Setup → Integrations → Change Data Capture (custom objects supported; up to 100 objects per org).

**Event channels:** `/data/AccountChangeEvent`, `/data/CaseChangeEvent` (standard); `/data/My_Object__ChangeEvent` (custom).

### 10.2 ChangeEventHeader fields (from `EventBus.ChangeEventHeader`)

| Method | Returns |
|---|---|
| `getChangeType()` | `CREATE`, `UPDATE`, `DELETE`, `UNDELETE`, `GAP_*` |
| `getChangedFields()` | API names of fields whose values changed |
| `getRecordIds()` | IDs of affected records (may be many for batch DML) |
| `getEntityName()` | Object API name |
| `getCommitNumber()` / `getCommitTimestamp()` / `getTransactionKey()` | Ordering metadata |

### 10.3 Gap events and retention

`GAP_CREATE/UPDATE/DELETE/UNDELETE` indicate Salesforce dropped events (subscriber lag or system load). `GAP_OVERFLOW` indicates the gap is too large to enumerate. Handle by querying current state for affected `recordIds` and resyncing. Ignoring gap events causes silent Salesforce↔consumer divergence. CDC events retained **3 days (72h)**; subscribers store the last-processed ReplayId durably and resume from it. Beyond 3 days, full reconciliation sync.

### 10.4 CDC vs Platform Events — decision

| Use CDC when | Use Platform Events when |
|---|---|
| External system must mirror Salesforce record state | Custom business event (`Order_Cancelled`, `Tier_Upgraded`) |
| No custom publish logic needed | Publish payload is conditional or enriched |
| All record changes are interesting | Only specific business signals matter |

---

## 11. Continuation API — Long-Running Callouts

When a single callout reasonably exceeds 120s sync limit, or a single transaction needs multiple parallel callouts whose combined time exceeds 120s, use the `Continuation` class. Available from Visualforce and Lightning (LWC/Aura) controllers; **not** from triggers or Queueables.

```apex
public Continuation startCallout() {
   Continuation c = new Continuation(120);        // 120-second async limit
   c.continuationMethod = 'processResponse';
   HttpRequest req = new HttpRequest();
   req.setMethod('GET');
   req.setEndpoint('callout:Slow_Vendor_API/reports/generate');
   c.addHttpRequest(req);
   return c;
}
public Object processResponse(List<String> labels, Object state) {
   return Continuation.getResponse(labels[0]).getBody();
}
```

**Limits:** up to 3 parallel callouts per Continuation, 2 MB request size, 120s. Continuations don't count against the sync Apex CPU limit while waiting on the external system.

---

## 12. External Services / OpenAPI

External Services auto-generate Apex client classes from an OpenAPI (Swagger) 2.0/3.0 spec, exposing operations as type-safe Apex methods and Flow actions. Setup → External Services → New, select Named Credential, paste spec.

**Pros:** schema-typed wrappers, Flow callability, fast setup. **Cons:** limited support for complex schemas (oneOf, polymorphic responses), no streaming, no file uploads.

Use External Services when the API has a clean OpenAPI spec and Flow needs to invoke the operations. Use a hand-written client class when the response shape is complex, the API is critical, or you need fine-grained retry/error logic.

---

## 13. MuleSoft and Composite API Endpoints

### 13.1 MuleSoft (or any middleware)

When Plusgrade has MuleSoft (or AWS API Gateway, or another integration bus) between Salesforce and downstream systems, treat the middleware as the single external system from Salesforce's POV — one Named Credential, one HTTP client class. Fan-out, transformation, and per-downstream retry live in the middleware, not in Apex.

**Use middleware when:** more than one downstream system needs the same payload, complex transformation/routing exists, or the downstream system has rate limits requiring queueing.

### 13.2 Composite API — multi-resource in one HTTP request

Salesforce's REST `composite` endpoint accepts up to 25 sub-requests in one HTTP call and supports inter-request references via `referenceId` (e.g., `"@{acc.id}"`). For inbound bulk creates from middleware this dramatically reduces round-trips. For outbound (Salesforce → external), build an equivalent batch payload manually unless the receiving system has its own composite endpoint.

```json
{"compositeRequest":[
  {"method":"POST","url":"/services/data/v66.0/sobjects/Account",
   "referenceId":"acc","body":{"Name":"Acme"}},
  {"method":"POST","url":"/services/data/v66.0/sobjects/Contact",
   "referenceId":"con","body":{"LastName":"Smith","AccountId":"@{acc.id}"}}
]}
```

---

## 14. Inbound REST (External → Salesforce)

For inbound integrations where the external system calls Salesforce, prefer the standard sObject REST API (`/services/data/vXX.0/sobjects/...`) plus `composite` for atomic bulk operations. Custom `@RestResource` Apex endpoints are justified only when business logic must execute server-side.

```apex
@RestResource(urlMapping='/cases/v1/*')
global with sharing class InboundCaseResource {
   @HttpPost global static Response create() {
      try {
         Payload p = (Payload) JSON.deserialize(
            RestContext.request.requestBody.toString(), Payload.class);
         Case c = CaseService.createFromExternal(p);
         RestContext.response.statusCode = 201;
         return new Response(true, c.Id, null);
      } catch (JSONException e) {
         RestContext.response.statusCode = 400;
         return new Response(false, null, 'Invalid JSON');
      } catch (Exception e) {
         RestContext.response.statusCode = 500;
         AppLogger.error('InboundCaseResource', null, e.getMessage(), null);
         return new Response(false, null, 'Internal error');
      }
   }
   global class Payload { global String externalId; global String subject; }
   global class Response {
      global Boolean success; global Id caseId; global String error;
      global Response(Boolean s, Id i, String err) {
         this.success=s; this.caseId=i; this.error=err; }
   }
}
```

Authentication for inbound is always OAuth 2.0 via a Connected App / External Client App. Use an Integration User with minimal-privilege Permission Sets — never share named-user credentials.

---

## 15. Observability — AppLog__c

Every callout writes exactly one row to `AppLog__c`. Required fields: `IntegrationName__c`, `Direction__c` (Inbound/Outbound), `Status__c` (Success/Failure/Retry/BreakerOpen), `StatusCode__c`, `DurationMs__c`, `CorrelationId__c` (unique per logical op, same across retries), `RequestSummary__c` (non-PII), `ErrorMessage__c` (PII-scrubbed), `RelatedRecordId__c`. Insert with `Database.insert(log, /*allOrNone*/ false)` — never fail the main transaction on a log write.

**Alert thresholds (configure as Flows or Datadog/external monitor on AppLog__c):**

| Condition | Action |
|---|---|
| 1 × HTTP 401/403 in last 5 min | Page ops immediately — credential expired or revoked |
| ≥3 × Failure on same integration in 5 min | Page ops — external system likely down |
| Median `DurationMs__c` > 10000 over 15 min | Warn — latency degradation |
| `BreakerOpen` log written | Page ops — circuit tripped |

Sample health query: `SELECT IntegrationName__c, Status__c, COUNT(Id) qty FROM AppLog__c WHERE CreatedDate = LAST_N_MINUTES:60 GROUP BY IntegrationName__c, Status__c`.

---

## 16. Correlation IDs — End-to-End Tracing

A correlation ID is a UUID-like string generated once at the originating call site and propagated through every hop (Salesforce service → HTTP client → MuleSoft → downstream system → response → AppLog row). Without it, cross-system tracing is guesswork.

```apex
public static String newCorrelationId() {
   String hex = EncodingUtil.convertToHex(Crypto.generateAesKey(128));
   return 'pg-' + hex.substring(0, 24);
}
```

**Propagation rules:** set as `X-Correlation-Id` header on every outbound request; set as `Idempotency-Key` on every mutating outbound; include in every `AppLog__c` row; surface to the user on errors (`"Reference: pg-xxxx"`); carry through Platform Event payloads via a `Correlation_Id__c` field.

---

## 17. Test Mocks

Every test that exercises code calling `new Http().send(req)` must register a mock via `Test.setMock` — Apex blocks real callouts in test context.

```apex
@isTest
public class StaticCalloutMock implements HttpCalloutMock {
   private Integer code; private String body;
   public StaticCalloutMock(Integer c, String b) { this.code=c; this.body=b; }
   public HTTPResponse respond(HTTPRequest req) {
      HttpResponse r = new HttpResponse();
      r.setStatusCode(code); r.setBody(body);
      r.setHeader('Content-Type', 'application/json');
      return r;
   }
}

@isTest
public class MultiEndpointMock implements HttpCalloutMock {
   private Map<String, HttpCalloutMock> byPath;
   public MultiEndpointMock(Map<String, HttpCalloutMock> m) { this.byPath = m; }
   public HTTPResponse respond(HTTPRequest req) {
      for (String path : byPath.keySet()) {
         if (req.getEndpoint().contains(path)) return byPath.get(path).respond(req);
      }
      HttpResponse r = new HttpResponse();
      r.setStatusCode(404); r.setBody('{"error":"no mock"}'); return r;
   }
}
```

**Required scenarios per HTTP client method:** 200/201 success; 4xx permanent (400 + 401); 5xx transient (500 or 503); `CalloutException` (mock that throws); bulk path with 200 records.

---

## 18. AppExchange / Managed Package Considerations

If integration code may ship in a managed package: Named Credential references use the managed namespace prefix (`callout:ns__MyCred`); test classes that depend on org-specific Named Credentials use `@TestVisible` indirection (packageable tests can't bind to subscriber-org credentials); Apex REST resources are namespaced (`/services/apexrest/ns/cases/v1/`); CMDT records can ship preconfigured but customer-edited values follow post-install behavior — document defaults; Platform Event objects retain the `__e` suffix and adopt the package namespace; Connected Apps / External Client Apps can't be packaged in their entirety — ship consumer-facing config and require post-install OAuth setup.

---

## 19. Definition of Done

An integration is shippable only when all of the following are true:

- [ ] Named Credential + External Credential deployed; no endpoint URL or secret in Apex/CMDT/CS
- [ ] Permission Set grants External Credential Principal Access
- [ ] HTTP Client class per system; `setTimeout` explicit; typed response wrapper
- [ ] Service class owns retry, logging, DML; no callouts in triggers
- [ ] Idempotency: External Id upsert on inbound; `Idempotency-Key` header on mutating outbound
- [ ] Retry: classify 429/5xx/timeout as retryable; cap at 3 attempts; dead-letter beyond
- [ ] Circuit breaker considered (documented even if not implemented)
- [ ] AppLog__c row per call with correlation ID, status, duration, integration name
- [ ] Alerts configured for 401/403, consecutive failures, latency degradation
- [ ] Tests cover success, 4xx, 5xx, CalloutException, bulk (200 records); ≥85% coverage
- [ ] `Test.setMock` used in every callout-touching test
- [ ] `--check-only --test-level RunLocalTests` deploy passes
- [ ] Runbook documents rotation procedure, rollback, on-call paging targets

---

## 20. Validation Commands

```bash
# Retrieve current Named Credential + External Credential pair
sf project retrieve start --target-org <alias> \
   --metadata "NamedCredential:MuleSoft_Case_API,ExternalCredential:MuleSoft_Case_API_EC"

# Check-only deploy with full local tests
sf project deploy start --target-org <alias> \
   --manifest manifest/package.xml \
   --dry-run --test-level RunLocalTests --wait 60

# Run integration test classes
sf apex run test --target-org <alias> --result-format human --wait 10 \
   --class-names MuleSoftCaseApiClientTest,MuleSoftCaseSyncQueueableTest

# Inspect last hour of AppLog rows
sf data query --target-org <alias> --query "SELECT IntegrationName__c, Status__c, \
   StatusCode__c, DurationMs__c, CorrelationId__c, ErrorMessage__c, CreatedDate \
   FROM AppLog__c WHERE IntegrationName__c = 'MuleSoft_Case_API' \
   AND CreatedDate = LAST_N_HOURS:1 ORDER BY CreatedDate DESC LIMIT 50"
```

---

## 21. Common AI Mistakes to Avoid

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

## 22. Empirical Findings & Implementation Notes

When Salesforce's documented approach doesn't work in this org, the workaround goes here. Date-stamp every entry.

| # | Date | Documented approach | What actually works | Why / Context |
|---|---|---|---|---|

---

## 23. Official References

- [Apex Callouts](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_callouts.htm)
- [Named Credentials Overview](https://help.salesforce.com/s/articleView?id=sf.named_credentials_about.htm)
- [External Credentials](https://help.salesforce.com/s/articleView?id=sf.external_credentials.htm)
- [Platform Events Developer Guide](https://developer.salesforce.com/docs/atlas.en-us.platform_events.meta/platform_events/)
- [Platform Event Limits](https://developer.salesforce.com/docs/atlas.en-us.platform_events.meta/platform_events/platform_events_limits.htm)
- [Change Data Capture Developer Guide](https://developer.salesforce.com/docs/atlas.en-us.change_data_capture.meta/change_data_capture/)
- [Pub/Sub API](https://developer.salesforce.com/docs/platform/pub-sub-api/overview.html)
- [Streaming API (CometD)](https://developer.salesforce.com/docs/atlas.en-us.api_streaming.meta/api_streaming/intro_stream.htm)
- [Continuation Class](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_continuation_overview.htm)
- [Composite API](https://developer.salesforce.com/docs/atlas.en-us.api_rest.meta/api_rest/resources_composite_composite.htm)
- [Bulk API 2.0](https://developer.salesforce.com/docs/atlas.en-us.api_asynch.meta/api_asynch/)
- [Apex REST Resources](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_rest_intro.htm)
- [External Services](https://help.salesforce.com/s/articleView?id=sf.external_services.htm)
- [forcedotcom/sf-skills `building-sf-integrations`](https://github.com/forcedotcom/sf-skills/tree/main/skills/building-sf-integrations)
- [forcedotcom/sf-skills `configuring-connected-apps`](https://github.com/forcedotcom/sf-skills/tree/main/skills/configuring-connected-apps)

---

*Integration Guidelines | v3.0 | Last verified 2026-05-16*
