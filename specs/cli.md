# CLI Specification

Ralph is invoked as a single binary with positional arguments, flags, and subcommands.

```
ralph "<prompt>" [options]
ralph --prompt-file <path> [options]
ralph <subcommand> [args]
```

## Prompt Input

The primary argument is a prompt string describing the task for the AI agent.

| Input method | Syntax | Notes |
|---|---|---|
| Inline string | `ralph "Build a REST API"` | One or more positional args joined with spaces |
| File (explicit) | `ralph --prompt-file path.md` | Aliases: `--file`, `-f` |
| File (implicit) | `ralph path.md` | Auto-detected when a single positional arg is an existing file |

### Prompt resolution order

1. If `--prompt-file` / `--file` / `-f` is set, read from that path.
2. Else if exactly one positional arg is provided and it is an existing file, read from that path.
3. Else join all positional args with spaces.
4. If the resolved prompt is empty, exit with an error.

### Prompt file validation

When reading a prompt file (explicit or implicit), the CLI must:

- Verify the path exists (error: `Prompt file not found`)
- Verify it is a regular file, not a directory (error: `Prompt path is not a file`)
- Verify it is non-empty after stripping whitespace (error: `Prompt file is empty`)
- Verify it is readable (error: `Unable to read prompt file`)

## Loop Options

These flags configure the main iteration loop.

### `--agent AGENT`

Select the AI agent to use.

- **Type:** String, restricted to valid agent names
- **Valid values:** `opencode`, `claude-code`, `codex`
- **Default:** `opencode`
- **Error on invalid value:** Yes (OptionParser rejects with `invalid argument`)

### `--min-iterations N`

Minimum number of iterations before a completion promise is accepted.

- **Type:** Integer
- **Default:** `1`
- **Behavior:** If the agent outputs the completion promise before this many iterations have run, the loop continues anyway.

### `--max-iterations N`

Maximum number of iterations before the loop stops automatically.

- **Type:** Integer
- **Default:** `0` (unlimited)
- **Behavior:** When the iteration counter exceeds this value, the loop stops and clears state.

### Validation

`--min-iterations` must not exceed `--max-iterations` (when max > 0). The CLI exits with an error if this constraint is violated.

### `--completion-promise TEXT`

The phrase the agent must output (wrapped in `<promise>...</promise>` tags) to signal task completion.

- **Type:** String
- **Default:** `COMPLETE`

### `--tasks`, `-t`

Enable Tasks Mode for structured task tracking.

- **Type:** Boolean flag
- **Default:** `false`
- **Behavior:** When enabled, the loop works through tasks defined in `.ralph/ralph-tasks.md` one at a time. The prompt builder includes task-specific instructions and workflow guidance.

### `--task-promise TEXT`

The phrase the agent outputs to signal an individual task is complete (tasks mode only).

- **Type:** String
- **Default:** `READY_FOR_NEXT_TASK`

### `--model MODEL`

Model identifier passed to the selected agent.

- **Type:** String
- **Default:** `""` (agent's default)
- **Agent-specific:** The value is passed directly to the agent CLI (e.g., `--model` for claude-code/codex, `-m` for opencode).

### `--prompt-file PATH` / `--file PATH` / `-f PATH`

Read the prompt from a file instead of inline arguments.

- **Type:** File path
- **Default:** `""` (unused)
- **Aliases:** `--prompt-file`, `--file`, `-f`

### `--[no-]stream`

Control whether agent output is streamed in real-time or buffered.

- **Type:** Boolean
- **Default:** `true` (streaming on)
- **`--stream`:** Stream stdout/stderr in real-time with tool counting and heartbeat.
- **`--no-stream`:** Buffer all output, print at end. Tool counts collected post-hoc.

### `--verbose-tools`

Print every tool invocation line instead of periodic compact summaries.

- **Type:** Boolean flag
- **Default:** `false`
- **Behavior:** When off (default), tool lines are suppressed and a compact summary is printed every 3 seconds. When on, every tool line is printed as-is.

### `--no-plugins`

Disable non-auth OpenCode plugins for the current run.

- **Type:** Boolean flag
- **Default:** `false`
- **Agent-specific:** Only affects `opencode`. Prints a warning if used with `claude-code` or `codex`.
- **Behavior:** Generates a filtered OpenCode config that only includes plugins matching `/auth/i`.

### `--[no-]commit`

Control automatic git commits after each iteration.

- **Type:** Boolean
- **Default:** `true` (auto-commit on)
- **`--commit`:** After each iteration, if `git status --porcelain` shows changes, run `git add -A && git commit -m "Ralph iteration N: work in progress"`.
- **`--no-commit`:** Skip auto-commits.

### `--[no-]allow-all`

Control automatic tool permission approval.

- **Type:** Boolean
- **Default:** `true` (auto-approve on)
- **`--allow-all`:** Pass permission flags to the agent (`--dangerously-skip-permissions` for claude-code, `--full-auto` for codex, permission config for opencode).
- **`--no-allow-all`:** Require interactive permission prompts from the agent.

## Subcommands

Subcommands are flag-style (prefixed with `--`) and cause the CLI to perform a specific action then exit. They do not start the main loop.

### `--version`, `-v`

Print `ralph <VERSION>` and exit 0.

### `--help`, `-h`

Print the full help text (generated by OptionParser) and exit 0.

### `--status`

Display the current loop status, pending context, and iteration history, then exit 0.

- **With `-t` or `--tasks`:** Also display the current task list from `.ralph/ralph-tasks.md`.
- **When an active loop has `tasks_mode` enabled:** Task list is shown automatically.
- **Output includes:**
  - Active/inactive status
  - Current iteration, start time, elapsed time
  - Completion promise, agent, model
  - Pending context (if any)
  - Task list with progress (if shown)
  - Last 5 iterations with duration and top tools
  - Struggle indicators (if detected)

### `--add-context TEXT`

Append context text to `.ralph/ralph-context.md` for the next iteration.

- **Requires:** A text argument (exits with error if missing)
- **Behavior:** Appends a timestamped section. Creates the file if it doesn't exist. The context is injected into the prompt on the next iteration, then cleared.

### `--clear-context`

Delete `.ralph/ralph-context.md` if it exists.

### `--list-tasks`

Parse and display tasks from `.ralph/ralph-tasks.md` with numbered indices and status icons.

- Exits with a message if no tasks file exists.

### `--add-task DESC`

Append a new `- [ ] DESC` line to `.ralph/ralph-tasks.md`.

- **Requires:** A description argument.
- Creates the file with a header if it doesn't exist.

### `--remove-task N`

Remove task at 1-based index N (including its subtasks) from `.ralph/ralph-tasks.md`.

- **Requires:** An integer argument.
- **Validation:** Index must be in range `1..task_count`.
- **Behavior:** Removes the top-level task line and any indented lines immediately following it (subtasks/notes).

## Error Handling

| Condition | Behavior |
|---|---|
| Unknown option | Exit 1, print message + `Run 'ralph --help'` |
| Invalid option value (bad agent, non-integer) | Exit 1, OptionParser error message + `Run 'ralph --help'` |
| No prompt provided | Exit 1, print usage hint |
| min-iterations > max-iterations | Exit 1, print constraint error |
| Agent CLI not found in PATH | Exit 1, print which agent is missing |
| Loop already active | Exit 1, print active loop info and state file path |
| Fatal error during loop | Exit 1, clear state, print error |

## Options Hash

After parsing, the CLI produces an options hash passed to `Ralph::Loop.run`:

```ruby
{
  prompt: String,              # resolved prompt text
  min_iterations: Integer,     # >= 1
  max_iterations: Integer,     # 0 = unlimited
  completion_promise: String,  # default "COMPLETE"
  tasks_mode: Boolean,         # default false
  task_promise: String,        # default "READY_FOR_NEXT_TASK"
  model: String,               # default ""
  agent_type: String,          # default "opencode"
  auto_commit: Boolean,        # default true
  disable_plugins: Boolean,    # default false
  allow_all_permissions: Boolean, # default true
  prompt_file: String,         # default ""
  stream_output: Boolean,      # default true
  verbose_tools: Boolean,      # default false
  prompt_source: String        # file path if prompt was read from file, else ""
}
```
