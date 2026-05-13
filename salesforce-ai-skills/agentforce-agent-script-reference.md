# Agentforce Agent Script — Complete Reference
> Compiled from developer.salesforce.com/docs/ai/agentforce — April 2026

---

## 1. What Is Agent Script?

Agent Script is Salesforce's compiled DSL for building Agentforce agents. It combines:

- **Deterministic logic** (`->`) — runs every time, unconditionally
- **LLM prompt instructions** (`|`) — natural language sent to the reasoning engine

The script compiles to lower-level metadata when you save. It's whitespace-sensitive (Python/YAML-style). You must pick spaces **or** tabs and be consistent — mixing causes parse errors.

---

## 2. Language Syntax Cheatsheet

| Symbol | Purpose | Example |
|--------|---------|---------|
| `#` | Comment | `# This is a comment` |
| `->` | Logic (deterministic) instruction block | `-> if @variables.verified:` |
| `\|` | Prompt instruction (LLM) | `\| Help the customer with their order.` |
| `{!expression}` | Resolve variable inside prompt text | `{!@variables.promotion_product}` |
| `@actions.name` | Reference action | `run @actions.get_order` |
| `@outputs.name` | Reference action output | `set @variables.status = @outputs.status` |
| `@subagent.name` | Reference subagent | `@utils.transition to @subagent.Order_Management` |
| `@variables.name` | Reference variable | `@variables.order_id` |
| `@system_variables.user_input` | Last customer utterance | Read-only system variable |
| `...` | Slot-fill token — tells LLM to set value | `with order_id = ...` |
| `==`, `!=`, `<`, `>` | Comparison operators | `@variables.count > 0` |
| `is None` / `is not None` | Null check | `if @variables.email is None:` |

---

## 3. Block Structure

Every Agent Script file is composed of top-level blocks:

```
system:         → Global instructions, welcome/error messages
config:         → Agent metadata (name, type, version)
variables:      → Global mutable/linked variables
language:       → Supported locales
connection:     → External connections (e.g. Enhanced Chat / Omni-Channel)
start_agent:    → Entry point — routing/classification (formerly "topic_selector")
subagent <name>: → One block per topic/subagent
```

> **Note (April 2026):** `topic` is deprecated — renamed to `subagent`. You may see both in existing scripts. Functionality is unchanged.

---

### 3.1 `system` Block

Required. Contains `welcome` and `error` messages. Use `{!@variables.name}` for dynamic injection.

```yaml
system:
  messages:
    welcome: |
      Hi {!@variables.userPreferredName}! I'm your personal shopping assistant.
    error: |
      Something went wrong. Please try again.
  instructions: |
    You are a helpful, professional assistant. Keep responses concise.
```

Override per-subagent with `system.instructions:` inside the subagent block.

---

### 3.2 `config` Block

| Parameter | Required | Notes |
|-----------|----------|-------|
| `developer_name` | Yes | API name, max 80 chars, unique per org |
| `agent_label` | No | UI display name |
| `description` | No | Agent purpose |
| `agent_type` | No | `AgentforceServiceAgent` (default) or `AgentforceEmployeeAgent` |
| `default_agent_user` | Conditional | Required for ServiceAgent, ignored for EmployeeAgent |
| `enable_enhanced_event_logs` | No | `True`/`False`. Default: `False` |
| `agent_version` | Auto | Set on save |
| `role` | No | e.g. "Help the customer select the perfect gift." |
| `company` | No | Company context for LLM |
| `user_locale` | No | Locale setting |

---

### 3.3 `variables` Block

All variables are global — accessible across all subagents.

#### Regular Variables

```yaml
variables:
  order_id: mutable string = ""
  is_verified: mutable boolean = False
  order_total: mutable number = 0
  flags: mutable list[boolean] = [True, False]
  order_line: mutable object = {"SKU": "abc123", "count": 1}
  start_date: mutable date = 2025-01-15
```

- `mutable` — required if the agent needs to change the value
- Omit `mutable` for constants
- `description:` — enables LLM slot-filling

#### Variable Types

| Type | Notes |
|------|-------|
| `string` | Alphanumeric, no special chars |
| `number` | IEEE 754 double — covers int and decimal |
| `boolean` | `True` / `False` (case-sensitive) |
| `object` | JSON `{"key": "value"}` |
| `date` | Any valid date format |
| `id` | Salesforce record ID |
| `list[type]` | e.g. `list[string]`, `list[number]` |

#### Linked Variables

Value tied to an action output. No default value. Read-only. No `object` or `list` types.

```yaml
variables:
  customer_tier: linked string
```

#### System Variables

Predefined, read-only. Not declared in `variables` block.

| Variable | Description |
|----------|-------------|
| `@system_variables.user_input` | Customer's most recent utterance only (not full history) |

---

### 3.4 `start_agent` Block (Topic Router)

Entry point on every customer utterance. Used for:
- Variable initialization
- Subagent classification / routing
- Filtering topics via `available when`

```yaml
start_agent agent_router:
  description: Routes customer requests to the correct subagent.
  reasoning:
    instructions:
      | Determine what the customer needs and route them to the right subagent.
    actions:
      go_to_order_management:
        description: Route to order management for order-related requests.
        @utils.transition to @subagent.order_management
      go_to_identity:
        description: Route to identity verification.
        @utils.transition to @subagent.identity
```

---

### 3.5 `subagent` Block

Core execution unit. Contains instructions, actions, and reasoning.

```yaml
subagent order_management:
  description: Allows customers to look up and manage their orders.

  system.instructions: |          # Optional: overrides global system instructions
    For this topic, be concise and data-focused.

  actions:
    get_order:
      description: Retrieves order details by order ID.
      inputs:
        order_id:
          type: string
          required: True
      target: "flow://Get_Order_Details"
      outputs:
        order_status:
          developer_name: order_status
          type: string
        delivery_date:
          developer_name: delivery_date
          type: date

  reasoning:
    instructions:
      ->
        run @actions.get_order
          with order_id = @variables.order_id
          set @variables.delivery_date = @outputs.delivery_date
        if @variables.is_verified == False:
          transition to @subagent.identity
      | Tell the customer their order {!@variables.order_id} status.
    actions:
      check_order_tool: @actions.get_order
```

---

## 4. Reasoning Instructions

Reasoning instructions are the core of each subagent. They're processed **top-to-bottom** before being sent to the LLM as a single resolved prompt.

### Dual-mode instructions

```yaml
reasoning:
  instructions:
    ->                              # Logic section — deterministic
      run @actions.check_hours
        set @variables.is_open = @outputs.is_open
      if @variables.is_open == False:
        | Sorry, we're currently closed. Our hours are 9am-5pm PST.
    | Help the customer with their request.   # LLM prompt section
```

### `before_reasoning` / `after_reasoning`

```yaml
after_reasoning:
  ->
    if @variables.num_turns > 3:
      transition to @subagent.wrap_up
```

`after_reasoning` runs **after** the LLM response exits. Useful for counters, cleanup, and conditional routing.

---

## 5. Actions

### Defining an Action

```yaml
actions:
  send_verification_code:
    description: Sends a 6-digit verification code to the customer's email.
    require_user_confirmation: False
    include_in_progress_indicator: True
    inputs:
      email:
        type: string
        required: True
    target: "flow://Send_Verification_Code"
    outputs:
      success:
        developer_name: success
        type: boolean
      error_code:
        developer_name: error_code
        type: string
        filter_from_agent: True     # Hidden from LLM context
```

### Action Targets

| Format | Type |
|--------|------|
| `"flow://Developer_Name"` | Salesforce Flow |
| `"apex://ClassName"` | Apex class |
| `"prompt://Template_Name"` | Prompt Template |

### Calling an Action (Deterministic)

```yaml
->
  run @actions.get_order
    with order_id = @variables.order_id
    set @variables.status = @outputs.order_status
    set @variables.date = @outputs.delivery_date
```

### Exposing Action as LLM Tool

```yaml
reasoning:
  actions:
    get_order_tool:
      description: Use this to retrieve order details when the customer asks about their order.
      @actions.get_order

      # Action chaining — run immediately after
      then: @actions.check_if_late
```

### Input Binding Modes

| Pattern | When to use |
|---------|-------------|
| `with field = @variables.x` | Bind from variable |
| `with field = ...` | Slot-fill — LLM infers from conversation |
| `with field = "literal"` | Hardcoded value |
| `with field = @outputs.x` | Bind from prior action output |

### Output `filter_from_agent`

Set `filter_from_agent: True` to exclude sensitive output from the LLM's context window. Useful for internal codes, tokens, raw IDs.

---

## 6. Tools (Reasoning Actions)

Tools are actions exposed to the LLM. The LLM decides whether to call them based on context.

```yaml
reasoning:
  actions:
    verify_email_tool:
      description: Use when the customer needs to verify their email address.
      available when: @variables.is_verified == False
      @actions.send_verification_code
```

### `available when`

Conditionally hide/show tools from the LLM:

```yaml
available when: @variables.is_member == True
```

### Referencing a Tool from Prompt

```yaml
| Use {!@actions.send_verification_code_tool} to send a code if the customer hasn't received one.
```

---

## 7. Utils

Built-in utility functions used as tools.

### `@utils.transition to`

One-way. Execution stops in current subagent. New subagent starts from the top.

```yaml
# From reasoning actions (LLM-controlled):
go_to_orders:
  description: Transition when the customer asks about their order.
  @utils.transition to @subagent.order_management

# From logic instructions (deterministic):
->
  if @variables.verified == True:
    transition to @subagent.order_management
```

### `@utils.setVariables`

Instructs LLM to populate variables via slot-filling:

```yaml
collect_email:
  description: Ask the customer for their email address.
  @utils.setVariables
    with email = ...
      description: The customer's email address.
```

### `@utils.escalate`

Hands off to human agent via Omni-Channel. Requires `connection messaging:` block.

```yaml
connection messaging:
  outbound_route_type: queue
  outbound_route_name: Support_Queue

# In subagent:
escalate_to_human:
  description: Escalate when the customer requests a human agent.
  @utils.escalate
```

---

## 8. Conditionals

```yaml
->
  if @variables.order_total > 100:
    | Offer the customer free shipping on their order.
  else:
    | Let the customer know shipping costs $9.99.

  if @variables.email is None:
    transition to @subagent.identity
```

Operators: `==`, `!=`, `>`, `<`, `>=`, `<=`, `is None`, `is not None`, `and`, `or`, `not`

---

## 9. Flow of Control

```
Customer utterance
      ↓
  start_agent (every turn)
      ↓
  LLM classifies → selects subagent
      ↓
  subagent reasoning instructions (top-to-bottom parse)
      ↓
  Resolved prompt sent to LLM
      ↓
  LLM calls tools (if any)
      ↓
  after_reasoning block
      ↓
  Response to customer
      ↓
  Wait for next utterance → back to start_agent
```

**Key rules:**
- Transitions are **one-way** — no return to calling subagent
- `transition to` inside `reasoning.instructions` halts current subagent immediately
- `transition to` in `reasoning.actions` executes after LLM decides to call it
- When transitioning back, the subagent restarts from the top — no resume point

---

## 10. Common Patterns

| Pattern | Mechanism |
|---------|-----------|
| **Action chaining** | `then: @actions.next_action` after tool definition |
| **Required workflow** | Deterministic `transition to` based on variable state |
| **Fetch before reasoning** | `run @actions.x` at top of `reasoning.instructions` before any `\|` prompt |
| **Topic filtering** | `available when` on tools in `reasoning.actions` |
| **Slot filling** | `@utils.setVariables` with `...` token |
| **System override** | `system.instructions:` inside subagent block |
| **Counter/turn tracking** | Increment variable in `reasoning.instructions`, check in `after_reasoning` |
| **Bidirectional nav** | Each subagent has a tool that transitions back to the other |
| **Error handling** | Check `@outputs.success == False` after action, branch with `if` |

---

## 11. Recipes Index (developer.salesforce.com/sample-apps/agent-script-recipes)

| Recipe | Category |
|--------|----------|
| HelloWorld | Language Essentials |
| TemplateExpressions | Language Essentials |
| VariableManagement | Language Essentials |
| LanguageSettings | Language Essentials |
| SystemInstructionOverrides | Language Essentials |
| ReasoningInstructions | Reasoning Mechanics |
| AfterReasoning | Reasoning Mechanics |
| ActionDefinitions | Action Configuration |
| ActionCallbacks | Action Configuration |
| AdvancedInputBindings | Action Configuration |
| ActionDescriptionOverrides | Action Configuration |
| InstructionActionReferences | Action Configuration |
| PromptTemplateActions | Action Configuration |
| SimpleQA | Architectural Patterns |
| MultiTopicNavigation | Architectural Patterns |
| MultiStepWorkflows | Architectural Patterns |
| BidirectionalNavigation | Architectural Patterns |
| ExternalAPIIntegration | Architectural Patterns |
| AdvancedReasoningPatterns | Architectural Patterns |
| ErrorHandling | Architectural Patterns |
| SafetyAndGuardrails | Architectural Patterns |

---

## 12. Agentforce DX (VS Code / CLI)

- Full Agent Script language support in VS Code Extension (syntax highlight, autocomplete, validation)
- Retrieve/deploy script files via SF CLI into SFDX project
- File-based workflow — edit `.agent` files locally, push to org

Docs: `developer.salesforce.com/docs/ai/agentforce/guide/agent-dx.html`

---

## 13. Key Gotchas

- `topic` keyword deprecated → use `subagent`
- `developer_name` must be unique per org — duplicate causes deploy failure
- Indentation must be consistent (spaces XOR tabs) — mixing = parse error
- Add a blank line or `#` comment at end of file if you see cryptic last-line errors in Builder
- `transition to` discards all prompt instructions accumulated before the transition
- `after_reasoning` still runs even when a transition was triggered from `reasoning.actions`
- `filter_from_agent: True` on outputs is critical for sensitive data — otherwise it lands in LLM context for the whole session
- Linked variables can't be `object` or `list` — use `mutable` variables + action output assignment instead
- `@system_variables.user_input` is last utterance only — LLM holds full history separately
