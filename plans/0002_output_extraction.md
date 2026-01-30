# Plan: Extract Inline Output into `Ralph::Output` Classes

## Overview

`lib/ralph/loop.rb` contains 14 distinct terminal output concerns embedded as inline `puts`/`warn`/`$stderr.puts` calls. Each should be extracted into its own class under `Ralph::Output`, following the callable object pattern documented in `specs/output.md`.

## Extraction Targets

Each row is one inline output site in `loop.rb` that becomes its own `Output::` class.

| # | Current location | Method / line | Proposed class | Channel | Keyword args |
|---|---|---|---|---|---|
| 1 | `print_banner` | line 91 | `Output::Banner` | stdout | `agent_name:` |
| 2 | `print_config_summary` | line 132 | `Output::ConfigSummary` | stdout | `prompt:`, `prompt_source:`, `completion_promise:`, `tasks_mode:`, `task_promise:`, `min_iterations:`, `max_iterations:`, `agent_name:`, `model:`, `disable_plugins:`, `agent_type:`, `allow_all:` |
| 3 | `print_iteration_header` | line 206 | `Output::IterationHeader` | stdout | `iteration:`, `max_iterations:`, `min_iterations:` |
| 4 | `print_iteration_summary` | line 456 | `Output::IterationSummary` | stdout | `iteration:`, `elapsed_ms:`, `tool_counts:`, `exit_code:`, `completion_detected:` |
| 5 | `max_iterations_reached?` output | line 198 | `Output::MaxIterationsReached` | stdout | `max_iterations:`, `total_duration_ms:` |
| 6 | `handle_completion` box | line 389 | `Output::CompletionDetected` | stdout | `completion_promise:`, `iteration:`, `total_duration_ms:` |
| 7 | Min iterations not yet reached | line 384 | `Output::CompletionDeferred` | stdout | `min_iterations:`, `next_iteration:` |
| 8 | `warn_if_struggling` | line 346 | `Output::StruggleWarning` | stdout | `no_progress_iterations:`, `short_iterations:` |
| 9 | `warn_nonzero_exit` | line 370 | `Output::NonzeroExitWarning` | stderr | `agent_name:`, `exit_code:` |
| 10 | `detect_plugin_error!` | line 361 | `Output::PluginError` | stderr | (no args — fixed message) |
| 11 | `report_task_completion` | line 376 | `Output::TaskCompletion` | stdout | `task_promise:`, `next_iteration:` |
| 12 | `consume_context` | line 403 | `Output::ContextConsumed` | stdout | (no args) |
| 13 | `auto_commit_changes` | line 416 | `Output::AutoCommitNotice` | stdout | `iteration:` |
| 14 | Active loop error | line 49 | `Output::ActiveLoopError` | stderr | `iteration:`, `started_at:`, `state_path:` |
| 15 | `handle_iteration_error` | line 431 | `Output::IterationError` | stderr | `iteration:`, `error:` |
| 16 | Tasks file created | line 124 | `Output::TasksFileCreated` | stdout | `path:` |

Existing: `Output::NoPluginWarning` (line 57) — already extracted.

## Implementation Steps

### Step 1: Create the output files

For each class in the table above, create `lib/ralph/output/<snake_case>.rb` following the pattern:

```ruby
module Ralph
  module Output
    class ClassName
      def self.call(keyword:, args:)
        # output logic moved from loop.rb
      end
    end
  end
end
```

### Step 2: Add requires to `loop.rb`

At the top of `lib/ralph/loop.rb`, add a `require_relative` for each new output class:

```ruby
require_relative "output/banner"
require_relative "output/config_summary"
require_relative "output/iteration_header"
# ...etc
```

### Step 3: Replace inline output with calls

Replace each inline output block with a single `Output::ClassName.call(...)` invocation. For example, `print_banner` changes from:

```ruby
def print_banner
  puts <<~BANNER
    ...
  BANNER
end
```

To:

```ruby
def print_banner
  Output::Banner.call(agent_name: @agent_config.config_name)
end
```

Or remove the private method entirely and call `Output::Banner.call(...)` directly at the call site if the wrapper method adds no value.

### Step 4: Remove empty wrapper methods

After extraction, some private methods in `loop.rb` (like `print_banner`, `print_config_summary`, `print_iteration_header`, `print_iteration_summary`) become one-line delegations. These can either be kept as readable aliases or inlined at their call sites — use judgment per case.

### Step 5: Verify

Run the CLI manually to confirm all output renders identically:
- `ralph --help`
- `ralph --status`
- A short loop with `--max-iterations 2`
- A loop with `--no-plugins`

## Ordering

Extract in dependency order — start with simple, self-contained outputs (no formatting helpers needed), then move to those that use `Helpers.format_duration` etc.

Suggested order:
1. `ContextConsumed` (no args, one line)
2. `AutoCommitNotice` (one arg, one line)
3. `TasksFileCreated` (one arg, one line)
4. `PluginError` (no args, fixed message)
5. `ActiveLoopError` (three args, stderr)
6. `IterationError` (two args, stderr)
7. `NonzeroExitWarning` (two args, stderr)
8. `TaskCompletion` (two args, stdout)
9. `CompletionDeferred` (two args, stdout)
10. `StruggleWarning` (two args, conditional lines)
11. `IterationHeader` (three args, formatting)
12. `Banner` (one arg, box drawing)
13. `MaxIterationsReached` (two args, box drawing + duration formatting)
14. `CompletionDetected` (three args, box drawing + duration formatting)
15. `IterationSummary` (five args, multi-line + tool formatting)
16. `ConfigSummary` (many args, conditional lines)
