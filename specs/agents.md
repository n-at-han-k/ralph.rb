# Agents Specification

The `Ralph::Agents` module provides a polymorphic abstraction over the external AI coding CLIs that Ralph can invoke. Each supported agent is a subclass of `Ralph::Agents::Base`, encapsulating its CLI invocation details, output parsing, and validation.

## Namespace & File Layout

```
lib/ralph/agents/
  base.rb          # Ralph::Agents::Base (abstract), module-level resolve/valid_agent_names
  open_code.rb     # Ralph::Agents::OpenCode
  claude_code.rb   # Ralph::Agents::ClaudeCode
  codex.rb         # Ralph::Agents::Codex
```

Each file defines exactly one class inside `module Ralph; module Agents; ... end; end`, except `base.rb` which also defines the module-level lookup functions and the `AGENT_NAME_MAP` constant.

## Module Interface

The `Ralph::Agents` module exposes two module-level functions for agent discovery and resolution.

### `Agents.resolve(name_str) -> Base | nil`

Maps a CLI name string to a new agent instance.

- **Parameter:** `name_str` — String, one of the keys in `AGENT_NAME_MAP`
- **Returns:** A new instance of the matching agent subclass, or `nil` if the name is unknown
- **Consumers:** `Loop#resolve_agent!`, `Output::Status`

### `Agents.valid_agent_names -> Array<String>`

Returns the list of accepted CLI agent name strings for option parsing.

- **Returns:** `["opencode", "claude-code", "codex"]`
- **Consumer:** `CLI` (used in OptionParser `--agent` validation and help text)

### `AGENT_NAME_MAP`

Frozen hash mapping CLI strings to internal symbols used for subclass dispatch.

```ruby
AGENT_NAME_MAP = {
  "opencode"   => :opencode,
  "claude-code" => :claude_code,
  "codex"      => :codex
}.freeze
```

## Base Class

`Ralph::Agents::Base` is an abstract class that includes `Ralph::Helpers` and defines the interface every agent subclass must implement.

### Abstract Methods

Subclasses must override all of the following. The base implementations raise `NotImplementedError`.

| Method | Signature | Returns | Purpose |
|--------|-----------|---------|---------|
| `type` | `-> Symbol` | `:opencode`, `:claude_code`, or `:codex` | Internal identifier used for agent-specific branching |
| `command` | `-> String` | CLI binary name | The executable name looked up on `$PATH` |
| `config_name` | `-> String` | Human-readable name | Display name used in banners, warnings, status output |
| `build_args` | `(prompt, model, options) -> Array<String>` | CLI argument array | Constructs the argument list for the agent subprocess |
| `parse_tool_output` | `(line) -> String or nil` | Tool name or nil | Extracts a tool invocation name from a single output line |

### Concrete Methods

| Method | Signature | Returns | Purpose |
|--------|-----------|---------|---------|
| `build_env` | `(options) -> Hash<String, String>` | Environment hash | Returns `ENV.to_h.dup`. Subclasses may override to customise the subprocess environment |
| `validate!` | `-> void` | — | Checks that `command` is found on `$PATH` via `which`. Prints an error to `$stderr` and calls `exit 1` if missing |

### `build_args` Parameters

- `prompt` — String, the full prompt text to send to the agent
- `model` — String, model identifier (may be `nil` or empty to use the agent's default)
- `options` — Hash with execution options:
  - `:allow_all_permissions` — Boolean, whether to pass auto-approve flags

### `parse_tool_output` Behaviour

- Strips ANSI escape sequences from the line via `strip_ansi` (from `Ralph::Helpers`)
- Applies an agent-specific regex to extract a tool name
- Returns the tool name `String` if matched, `nil` otherwise
- **Consumers:** `Iteration#stream_agent` (real-time tool counting), `Helpers.collect_tool_summary_from_text` (post-hoc counting)

## Agent Subclasses

### `Ralph::Agents::OpenCode`

| Property | Value |
|----------|-------|
| `type` | `:opencode` |
| `command` | `"opencode"` |
| `config_name` | `"OpenCode"` |

**`build_args` behaviour:**
1. Starts with `["run"]`
2. Appends `["-m", model]` if model is non-empty
3. Appends the prompt as the final argument

**`parse_tool_output` regex:** `/^\|\s{2}([A-Za-z0-9_-]+)/`

Matches OpenCode's tool output format where tool names appear after a pipe and two spaces at the start of a line.

### `Ralph::Agents::ClaudeCode`

| Property | Value |
|----------|-------|
| `type` | `:claude_code` |
| `command` | `"claude"` |
| `config_name` | `"Claude Code"` |

**`build_args` behaviour:**
1. Starts with `["-p", prompt]`
2. Appends `["--model", model]` if model is non-empty
3. Appends `"--dangerously-skip-permissions"` if `options[:allow_all_permissions]` is truthy

**`parse_tool_output` regex:** `/(?:Using|Called|Tool:)\s+([A-Za-z0-9_-]+)/i`

Matches Claude Code's tool output format where tool names follow "Using", "Called", or "Tool:" prefixes (case-insensitive).

### `Ralph::Agents::Codex`

| Property | Value |
|----------|-------|
| `type` | `:codex` |
| `command` | `"codex"` |
| `config_name` | `"Codex"` |

**`build_args` behaviour:**
1. Starts with `["exec"]`
2. Appends `["--model", model]` if model is non-empty
3. Appends `"--full-auto"` if `options[:allow_all_permissions]` is truthy
4. Appends the prompt as the final argument

**`parse_tool_output` regex:** `/(?:Tool:|Using|Calling|Running)\s+([A-Za-z0-9_-]+)/i`

Matches Codex's tool output format where tool names follow "Tool:", "Using", "Calling", or "Running" prefixes (case-insensitive).

## Consumers

| Consumer | What it uses | How |
|----------|-------------|-----|
| `Loop#resolve_agent!` | `Agents.resolve`, `agent.validate!` | Resolves CLI name to instance, validates binary exists |
| `Loop#initialize` | `agent.type`, `agent.config_name` | Agent-specific branching (plugin warnings), display name for banner/warnings |
| `Iteration#execute_agent` | `agent.build_args`, `agent.build_env`, `agent.command` | Constructs and spawns the agent subprocess |
| `Iteration#stream_agent` | `agent.parse_tool_output` | Real-time tool counting during streaming output |
| `Helpers.collect_tool_summary_from_text` | `agent.parse_tool_output` | Post-hoc tool counting from buffered output |
| `Output::Status` | `Agents.resolve`, `agent.config_name` | Display name in `--status` dashboard |
| `CLI` | `Agents.valid_agent_names` | OptionParser validation and help text for `--agent` flag |

## Adding a New Agent

To add support for a new AI coding CLI:

1. Create `lib/ralph/agents/<name>.rb` with a class inheriting from `Base`
2. Implement all abstract methods: `type`, `command`, `config_name`, `build_args`, `parse_tool_output`
3. Override `build_env` if the agent requires custom environment variables
4. Add an entry to `AGENT_NAME_MAP` in `base.rb`
5. Add a constructor lambda to the dispatch hash in `Agents.resolve`

## Testing Strategy

### Unit Tests
- Verify each subclass returns correct `type`, `command`, and `config_name`
- Test `build_args` with combinations of: empty model, non-empty model, permissions on/off
- Test `parse_tool_output` with matching lines, non-matching lines, and lines containing ANSI escapes
- Test `Agents.resolve` returns correct class for each valid name, `nil` for unknown names
- Test `Agents.valid_agent_names` returns expected list

### Integration Tests
- Test `validate!` with a mocked `which` that returns nil (expect stderr output and `SystemExit`)
- Test `validate!` with a mocked `which` that returns a path (expect no error)
