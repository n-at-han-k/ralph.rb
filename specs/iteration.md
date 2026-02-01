# Iteration Class Specification

## Purpose

The `Iteration` class is responsible for executing a single AI agent iteration and collecting metrics. It handles the low-level execution details while delegating business logic decisions to the caller.

## Location

`lib/ralph/iteration.rb`

## Dependencies

```ruby
require_relative "types"
require_relative "helpers"
require_relative "state"
```

## Class Interface

### Constructor

```ruby
def initialize(agent_config:, model:, options:)
```

**Parameters:**
- `agent_config` - `Ralph::Agents::Base` instance providing command, build_args, build_env, etc. (see [agents.md](./agents.md))
- `model` - String representing the model identifier to pass to the agent
- `options` - Hash containing execution options:
  - `allow_all_permissions` - Boolean for auto-approving tool permissions
  - `disable_plugins` - Boolean for filtering plugins (opencode only)
  - `stream_output` - Boolean for streaming vs buffered output
  - `verbose_tools` - Boolean for detailed tool output vs summaries

### Main Method

```ruby
def call(prompt, iteration_start:)
```

**Parameters:**
- `prompt` - String containing the prompt to send to the agent
- `iteration_start` - Integer timestamp (ms) when the iteration started

**Returns:**
- `IterationResult` struct with execution data

## Result Type

```ruby
IterationResult = Struct.new(
  :duration_ms,        # Integer - execution duration in milliseconds
  :exit_code,          # Integer - agent process exit code
  :stdout_text,        # String - agent stdout output
  :stderr_text,        # String - agent stderr output
  :tool_counts,        # Hash<String, Integer> - tool usage counts
  :files_modified,     # Array<String> - list of files changed during iteration
  :completion_detected, # Boolean - whether completion promise was found
  :errors,             # Array<String> - extracted errors from output
  :success             # Boolean - overall success (no crashes, exit_code == 0)
)
```

## Internal Responsibilities

### 1. Agent Execution
- Build agent command using `agent_config.build_args` and `agent_config.build_env`
- Execute agent (streaming or buffered based on options)
- Capture stdout, stderr, exit code, and tool usage data
- Handle agent process lifecycle

### 2. Metrics Collection
- Calculate execution duration from `iteration_start`
- Extract tool counts from agent output using `agent_config.parse_tool_output`
- Capture file snapshots before/after execution using `State.capture_file_snapshot`
- Detect files modified via `State.modified_files_since_snapshot`

### 3. Data Extraction
- Combine stdout/stderr for analysis
- Detect completion promise using `::Ralph::Helpers.check_completion`
- Extract errors from combined output using `::Ralph::Helpers.extract_errors`
- Determine overall success status

### 4. Result Packaging
- Assemble all collected data into `IterationResult`
- Return structured result to caller

## External Dependencies (Provided by Caller)

The class expects the caller to handle:
- **Prompt Building** - Creating the prompt text using `PromptBuilder`
- **Output Display** - Showing iteration summaries, warnings, etc.
- **History Management** - Recording iteration data in `RalphHistory`
- **State Updates** - Managing loop state, iteration counters
- **Completion Decisions** - Determining whether to continue or break loop
- **Error Handling** - Deciding how to respond to iteration errors
- **Post-Processing** - Auto-committing changes, consuming context

## Error Handling

The `Iteration` class handles:
- Process execution errors (captures in result)
- Stream processing errors (captures in result)
- File operation errors for snapshots (gracefully degrades)
- Agent process cleanup if errors occur

It does NOT:
- Display error messages (caller responsibility)
- Modify loop state (caller responsibility)
- Make retry decisions (caller responsibility)

## Usage Example

```ruby
# In Loop class
iteration = Iteration.new(
  agent_config: @agent_config,
  model: @model,
  options: {
    allow_all_permissions: @allow_all,
    disable_plugins: @disable_plugins,
    stream_output: @stream_output,
    verbose_tools: @verbose_tools
  }
)

result = iteration.call(full_prompt, iteration_start: start_time)

# Caller processes result
Output::IterationSummary.call(
  iteration: @state.iteration,
  elapsed_ms: result.duration_ms,
  tool_counts: result.tool_counts,
  exit_code: result.exit_code,
  completion_detected: result.completion_detected
)

# Caller updates history
record_iteration_in_history(result)

# Caller decides what to do next
if result.completion_detected && @state.iteration >= @min_iterations
  # Handle completion
end
```

## Implementation Notes

### Thread Safety
The class is stateless except for constructor parameters. Multiple instances can be used concurrently.

### Performance Considerations
- File snapshot operations should be efficient (git-based)
- Stream processing should handle large outputs without memory issues
- Tool counting should be done efficiently via line-by-line processing

### Extensibility
The `options` hash allows adding new execution parameters without breaking the interface.
The `IterationResult` struct can be extended with additional fields as needed.

## Testing Strategy

### Unit Tests
- Mock `Open3` to test agent execution logic
- Mock `State` methods to test file snapshot logic
- Test completion detection with various output formats
- Test error extraction from different types of output
- Test tool counting with different agent output formats

### Integration Tests
- Test with actual agent binaries (if available in test environment)
- Test file snapshot operations with git repositories
- Test streaming vs buffered output modes
- Test error scenarios (agent crashes, git operations fail)

## Migration Path

1. Create the new `Iteration` class with this interface
2. Update `Loop` class to use `Iteration` for agent execution
3. Move iteration-related private methods from `Loop` to `Iteration`
4. Update `Loop` to process `IterationResult` instead of handling execution directly
5. Remove redundant code from `Loop` class
6. Add tests for the new `Iteration` class

This refactoring will improve separation of concerns, testability, and maintainability of the iteration execution logic.