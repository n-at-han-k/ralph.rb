# Task Management Specification

Task management lets Ralph break large projects into discrete units of work tracked in a markdown file. Instead of sending the entire project goal every iteration, Ralph focuses the agent on one task at a time, advancing through the list as each task is completed. This reduces per-iteration context size, improves agent focus, and lowers cost.

## File Format

Tasks are stored in `.ralph/ralph-tasks.md`. The file uses markdown checkbox syntax with three status characters.

### Status Characters

| Character | Symbol | Status | Meaning |
|-----------|--------|--------|---------|
| ` ` (space) | `[ ]` | `:todo` | Not started |
| `/` | `[/]` | `:in_progress` | Currently being worked on |
| `x` | `[x]` | `:complete` | Finished |

### Structure

```markdown
# Ralph Tasks

- [ ] First task description
- [/] Second task (in progress)
  - [ ] Subtask A
  - [x] Subtask B
- [x] Third task (complete)
```

**Rules:**

- Top-level tasks start at column 0 with `- [<status>] <text>`.
- Subtasks are indented with two spaces followed by the same `- [<status>] <text>` pattern.
- Subtasks are **single-level only** — no nesting subtasks under subtasks.
- The `# Ralph Tasks` header is written on save but not required for parsing.
- Lines that do not match the task pattern are ignored during parsing.

### Round-Trip Preservation

Each `Task` stores its `original_line` (the raw line from disk). This is used for diagnostics and debugging. On save, the canonical `- [<status>] <text>` format is always written, so whitespace and formatting are normalized.

## Data Models

### `Ralph::Storage::Task`

Represents a single task (top-level or subtask).

| Attribute | Type | Description |
|-----------|------|-------------|
| `text` | `String` | Task description text |
| `status` | `Symbol` | One of `:todo`, `:in_progress`, `:complete` |
| `subtasks` | `Array<Task>` | Child tasks (empty for subtasks themselves) |
| `original_line` | `String` or `nil` | Raw line from disk, for diagnostics |

**Status query methods:**

- `todo?` — true when status is `:todo`
- `in_progress?` — true when status is `:in_progress`
- `complete?` — true when status is `:complete`

**Status mutation methods:**

- `mark_todo!` — sets status to `:todo`
- `mark_in_progress!` — sets status to `:in_progress`
- `mark_complete!` — sets status to `:complete`
- `toggle_status` — cycles `:todo` → `:in_progress` → `:complete` → `:todo`

**Serialization:**

`to_s` returns the canonical line: `- [<status_char>] <text>`

### `Ralph::Storage::TasksCollection`

An `Enumerable` collection of top-level `Task` objects.

| Method | Signature | Description |
|--------|-----------|-------------|
| `each` | `(&block)` | Yields each top-level task |
| `empty?` | `-> Boolean` | True when collection has no tasks |
| `length` | `-> Integer` | Number of top-level tasks |
| `any?` | `-> Boolean` | True when collection has at least one task |
| `add` | `(Task) -> self` | Appends a task to the collection |
| `remove_at` | `(Integer) -> Task` | Removes task at 1-based index; raises `IndexError` if out of range |
| `current` | `-> Task or nil` | First task with `:in_progress` status |
| `next` | `-> Task or nil` | First task with `:todo` status |
| `all_complete?` | `-> Boolean` | True when non-empty and every task is `:complete` |

**Class methods:**

- `TasksCollection.parse(content)` — Parses a markdown string into a `TasksCollection`. Handles top-level tasks and single-level subtasks. Returns a new collection (empty if no tasks found).

**Display:**

- `display_with_indices` — Prints a numbered list of tasks with status icons to stdout. Used by the `--list-tasks` subcommand.

**Status icons** (for display only):

| Status | Icon |
|--------|------|
| `:complete` | `✅` |
| `:in_progress` | `🔄` |
| `:todo` | `⏸️` |

## Storage

### `Ralph::Storage::Tasks`

Manages the task file on disk. Always instantiate with `Tasks.new`.

| Method | Signature | Description |
|--------|-----------|-------------|
| `load_tasks` | `-> TasksCollection or nil` | Reads and parses `.ralph/ralph-tasks.md`. Returns `nil` if the file does not exist or cannot be parsed. |
| `save_tasks` | `(TasksCollection) -> void` | Writes the collection to `.ralph/ralph-tasks.md` with the `# Ralph Tasks` header. Writes top-level tasks and their subtasks. |
| `clear_tasks` | `-> void` | Deletes the tasks file if it exists. Silently ignores errors. |
| `tasks_exist?` | `-> Boolean` | True when `.ralph/ralph-tasks.md` exists on disk. |
| `add_task` | `(String) -> Task` | Loads existing tasks (or creates a new collection), appends a new `:todo` task, saves, and returns the new task. |
| `remove_task` | `(Integer) -> Task` | Removes the task at the given 1-based index. Raises `RuntimeError` if no tasks file exists. Raises `IndexError` if the index is out of range. |
| `initialize_tasks_file` | `-> String` | Creates a starter tasks file with a header and usage hint. Returns the file path. |

**Class methods:**

- `Tasks.dir` — Returns the `.ralph/` directory path (relative to `Dir.pwd`).
- `Tasks.path` — Returns the full path to `ralph-tasks.md`.

**Directory management:** The constructor creates `.ralph/` if it does not exist.

## Task Lifecycle in the Loop

When `--tasks` (or `-t`) is enabled, the loop coordinates task progression across iterations.

### Task Selection

Each iteration, the prompt builder determines the current focus:

1. **Find in-progress task:** Look for the first task with status `[/]` (`:in_progress`). If found, this is the current task.
2. **Find next todo task:** If no in-progress task, look for the first task with status `[ ]` (`:todo`). This becomes the next task to start.
3. **All complete:** If every task is `[x]` (`:complete`), instruct the agent to output the completion promise.
4. **No tasks:** If the collection is empty, instruct the agent to add tasks.

### Status Transitions

The agent is responsible for updating task statuses in `.ralph/ralph-tasks.md` directly. The prompt instructs the agent to follow this workflow:

```
[ ] todo  →  [/] in progress  →  [x] complete
```

1. Before starting work: mark the task as `[/]` in the file.
2. After verifying the task is done: mark it as `[x]` in the file.
3. Output `<promise>READY_FOR_NEXT_TASK</promise>` to signal task completion.

Ralph does not programmatically modify task statuses between iterations. The agent owns the file.

### Task Promise Detection

When the loop detects `<promise>READY_FOR_NEXT_TASK</promise>` (or the value of `--task-promise`) in agent output:

- The loop prints a task completion message via `Output::TaskCompletion`.
- The next iteration's prompt will pick up the updated task file, find the next `[ ]` task, and continue.

The task promise does **not** stop the loop. It is informational — the loop continues to the next iteration.

### Completion Promise in Tasks Mode

The completion promise (`<promise>COMPLETE</promise>` by default) is only accepted when the agent has signaled that all tasks are done. The prompt instructs the agent to only output the completion promise when every task in the file is `[x]`.

### Tasks File Creation

When `--tasks` is enabled and no tasks file exists:

- The prompt builder includes instructions telling the agent to create the file or use `ralph --add-task`.
- Alternatively, the user can pre-populate the file with `ralph --add-task "description"` before starting the loop.
- `initialize_tasks_file` creates a starter file with a header and usage hint.

## Prompt Integration

The `Prompt` class builds task-aware prompts when `state.tasks_mode` is true.

### Task-Mode Prompt Structure

```
# Ralph Wiggum Loop - Iteration N

You are in an iterative development loop working through a task list.

[Additional Context section, if present]

## TASKS MODE: Working through task list

Current tasks from .ralph/ralph-tasks.md:
```markdown
[full contents of ralph-tasks.md]
```

[Task instructions — one of four states]

### Task Workflow
1. Find any task marked [/] (in progress). If none, pick the first [ ] task.
2. Mark the task as [/] in ralph-tasks.md before starting.
3. Complete the task.
4. Mark as [x] when verified complete.
5. Output <promise>READY_FOR_NEXT_TASK</promise> to move to the next task.
6. Only output <promise>COMPLETE</promise> when ALL tasks are [x].

---

## Your Main Goal

[user's prompt text]

## Critical Rules

[rules about one task at a time, promise usage, honesty]

## Current Iteration: N / M (min: K)

Tasks Mode: ENABLED - Work on one task at a time from ralph-tasks.md
```

### Four Task Instruction States

The prompt builder selects one instruction block based on the current task state:

| State | Condition | Instruction |
|-------|-----------|-------------|
| Current task exists | `tasks.current` returns a task | Focus on completing the in-progress task. When done, mark as `[x]` and output the task promise. |
| Next task available | No in-progress task, `tasks.next` returns a task | Mark the next task as `[/]` before starting. When done, mark as `[x]` and output the task promise. |
| All tasks complete | `tasks.all_complete?` is true | All tasks done. Output the completion promise to finish. |
| No tasks found | Collection is empty | Add tasks to the file or use `ralph --add-task`. |

### Error State

If the tasks file cannot be read (parse error, permissions, etc.), the prompt builder falls back to a short error message:

```
## TASKS MODE: Error reading tasks file

Unable to read .ralph/ralph-tasks.md
```

## CLI Subcommands

These subcommands are fire-and-exit — they perform their action and exit without starting the loop. See also [cli.md](./cli.md) for the full CLI specification.

### `--list-tasks`

Loads and displays tasks from `.ralph/ralph-tasks.md` with numbered indices and status icons.

- If no tasks file exists, prints a message and exits.
- Uses `TasksCollection#display_with_indices`.

### `--add-task DESC`

Appends a new `- [ ] DESC` task to the file.

- Creates the file with a `# Ralph Tasks` header if it does not exist.
- Requires a non-empty description argument.

### `--remove-task N`

Removes the task at 1-based index N, including its subtasks.

- Requires an integer argument.
- Validates the index is in range `1..task_count`.
- Raises if no tasks file exists.

## Consumers

| Consumer | What it uses | How |
|----------|-------------|-----|
| `Loop#run` | `check_completion` with `task_promise` | Detects `<promise>READY_FOR_NEXT_TASK</promise>` in agent output and prints task completion message |
| `Prompt#task_mode_prompt` | `Storage::Tasks`, `TasksCollection.parse` | Reads task file, determines current/next task, builds task-aware prompt |
| `Prompt#build_tasks_section` | `TasksCollection#current`, `#next`, `#all_complete?` | Selects the appropriate task instruction block |
| `CLI` | `Storage::Tasks#add_task`, `#remove_task`, `#load_tasks` | Implements `--add-task`, `--remove-task`, `--list-tasks` subcommands |
| `Output::Status` | `Storage::Tasks#load_tasks` | Displays task progress in the `--status` dashboard |
| `Output::TaskCompletion` | — | Prints task completion message when task promise is detected |
| `Output::TasksFileCreated` | — | Prints confirmation when the tasks file is initialized |

## Testing Strategy

### Unit Tests

- **Parsing:** Test `TasksCollection.parse` with:
  - Empty string, header-only, single task, multiple tasks, subtasks, mixed statuses
  - Lines that do not match the task pattern (ignored)
  - Malformed status characters (treated as todo)
- **Models:** Test `Task` status queries, mutations, `toggle_status`, `to_s`
- **Collection:** Test `add`, `remove_at` (valid index, out of range), `current`, `next`, `all_complete?`, `empty?`
- **Storage:** Test `load_tasks`, `save_tasks` round-trip, `add_task`, `remove_task`, `clear_tasks`, `tasks_exist?`, `initialize_tasks_file`

### Integration Tests

- **Loop integration:** Test that task promise detection in agent output triggers `Output::TaskCompletion` and continues the loop
- **Prompt integration:** Test that the prompt builder includes the correct task instructions for each of the four task states
- **CLI subcommands:** Test `--list-tasks`, `--add-task`, `--remove-task` end-to-end with a real tasks file
- **File creation:** Test that `--tasks` mode works when no tasks file exists (agent or user creates it)
