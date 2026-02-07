<p align="center">
  <h1 align="center">Ralph.rb</h1>
  <h3 align="center">Autonomous Agentic Loop for OpenCode</h3>
</p>

<p align="center">
  <img src="ralph.jpg" alt="Ralph Wiggum - Iterative AI coding loop for Opencode" />
</p>

<p align="center">
  <strong>Run any AI coding agent in a self-correcting loop until your task is done.</strong><br>
  <em>Works with <b>Claude Code</b>, <b>OpenAI Codex</b>, and <b>OpenCode</b> — switch agents with <code>--agent</code>.</em><br>
  <em>Based on the <a href="https://ghuntley.com/ralph/">Ralph Wiggum technique</a> by Geoffrey Huntley</em>
</p>


<p align="center">
  <a href="#supported-agents">Supported Agents</a> •
  <a href="#what-is-open-ralph-wiggum">What is Ralph?</a> •
  <a href="#installation">Installation</a> •
  <a href="#quick-start">Quick Start</a> •
  <a href="#commands">Commands</a>
</p>

<p align="center">
  <strong>Tired of agents breaking your local environment?</strong><br>
  <a href="https://github.com/Th0rgal/openagent">OpenAgent</a> gives each task an isolated Linux workspace. Self-hosted. Git-backed.
</p>

---

## Supported Agents

Open Ralph Wiggum works with multiple AI coding agents. Switch between them using the `--agent` flag:

| Agent | Flag | Description |
|-------|------|-------------|
| **Claude Code** | `--agent claude-code` | Anthropic's Claude Code CLI for autonomous coding |
| **Codex** | `--agent codex` | OpenAI's Codex CLI for AI-powered development |
| **OpenCode** | `--agent opencode` | Default agent, open-source AI coding assistant |

```bash
# Use Claude Code
ralph "Build a REST API" --agent claude-code --max-iterations 10

# Use OpenAI Codex
ralph "Create a CLI tool" --agent codex --max-iterations 10

# Use OpenCode (default)
ralph "Fix the failing tests" --max-iterations 10
```

---

## What is Open Ralph Wiggum?

Open Ralph Wiggum implements the **Ralph Wiggum technique** — an autonomous agentic loop where an AI coding agent (Claude Code, Codex, or OpenCode) receives the **same prompt repeatedly** until it completes a task. Each iteration, the AI sees its previous work in files and git history, enabling self-correction and incremental progress.

This is a **CLI tool** that wraps any supported AI coding agent in a persistent development loop. No plugins required — just install and run.

```bash
# The essence of the Ralph loop:
while true; do
  claude-code "Build feature X. Output <promise>DONE</promise> when complete."  # or codex, opencode
done
```

**Why this works:** The AI doesn't talk to itself between iterations. It sees the same prompt each time, but the codebase has changed from previous iterations. This creates a powerful feedback loop where the agent iteratively improves its work until all tests pass.

### Multi-Agent Flexibility

Switch between AI coding agents without changing your workflow:

- **Claude Code** (`--agent claude-code`) — Anthropic's powerful coding agent
- **Codex** (`--agent codex`) — OpenAI's code-specialized model
- **OpenCode** (`--agent opencode`) — Open-source default option

## Why Ralph? (Not Just a `while true` Loop)

At its core, the Ralph technique is a `while true` loop that calls an AI coding agent. So what does this tool actually add? A bare loop has no way to stop, no observability, no error recovery, no task management, and no way to intervene mid-run. Ralph wraps the loop with termination logic, state management, struggle detection, live monitoring, and mid-flight steering — turning a dumb retry loop into a supervised autonomous agent runner.

| Feature | Problem It Solves |
|---------|-------------------|
| **Completion Promise Detection** | A bare loop never knows when to stop. Ralph detects `<promise>COMPLETE</promise>` in agent output to terminate cleanly. |
| **Min/Max Iteration Bounds** | No safety net on cost or runaway loops. `--max-iterations` caps runs; `--min-iterations` prevents premature completion. |
| **Task Decomposition Mode** | Large projects overwhelm a single prompt. Ralph breaks work into a `.ralph/ralph-tasks.md` file, feeds one task at a time, and advances automatically. |
| **Task Management CLI** | Editing a markdown task file by hand is tedious. `--list-tasks`, `--add-task`, `--remove-task` manage it from the terminal. |
| **Mid-Loop Context Injection** | You see the agent going the wrong way but don't want to kill the loop. `--add-context "hint"` from another terminal steers the next iteration. |
| **Status Dashboard** (`--status`) | No visibility into a running loop. Shows iteration count, elapsed time, task progress, recent history, and struggle indicators from another terminal. |
| **Struggle Detection** | Agent silently spins doing nothing useful. Ralph tracks no-file-change streaks, short iterations (<30s), and repeated errors, then warns you. |
| **Git-Based File Change Tracking** | Can't tell if the agent actually did anything. Git snapshots before/after each iteration detect modifications. |
| **Streaming + Compact Tool Summaries** | Raw agent output is extremely noisy with tool invocations. Ralph suppresses tool lines and prints periodic compact summaries (e.g., `Bash 5 . Edit 3 . Read 2`). |
| **Heartbeat Indicator** | Long silent periods make you think the loop is hung. A background thread prints `working... elapsed X` every 10s. |
| **Multi-Agent Support** | Locked into one agent. Ralph supports OpenCode, Claude Code, and Codex behind a uniform interface. |
| **Auto-Approve Permissions** | Interactive permission prompts block an unattended loop. `--allow-all` passes the right flags per agent (`--dangerously-skip-permissions`, `--full-auto`, etc.). |
| **State Persistence** (`.ralph/`) | A killed loop loses all context. Ralph persists session state, iteration history, context, and tasks to disk for recovery and monitoring. |
| **Iteration History & Metrics** | No record of what happened. Each iteration records duration, tools used, files changed, errors, and exit code. |
| **Error Extraction** | Errors are buried in pages of output. Ralph scans output for error patterns and surfaces them in history/status. |
| **Active Loop Guard** | Two loops running simultaneously corrupt state. Ralph detects an existing active session and refuses to start a second. |
| **Graceful Signal Handling** | Ctrl+C leaves orphaned agent processes and corrupt state. Ralph sends TERM to the subprocess and cleans up state files. |
| **Nonzero Exit Resilience** | Agent crashes kill the loop. Ralph logs a warning and continues to the next iteration instead. |
| **Agent Binary Validation** | Cryptic errors if the agent CLI isn't installed. Ralph checks `$PATH` upfront and fails with a clear message. |
| **Plugin Filtering** | OpenCode's legacy `ralph-wiggum` plugin causes fatal errors. `--no-plugins` filters it out. |
| **Iteration-Aware Prompt Building** | Each iteration needs structured context (iteration number, task focus, completion instructions). Ralph constructs iteration-aware prompts automatically. |
| **Model Selection** | Each agent has different `--model` flag syntax. Ralph normalizes `--model MODEL` across all agents. |

## Installation

**Prerequisites:**
- [Bun](https://bun.sh) runtime
- At least one AI coding agent CLI:
  - [Claude Code](https://docs.anthropic.com/en/docs/claude-code) — Anthropic's Claude Code CLI
  - [Codex](https://github.com/openai/codex) — OpenAI's Codex CLI
  - [OpenCode](https://opencode.ai) — Open-source AI coding assistant

### npm (recommended)

```bash
npm install -g @th0rgal/ralph-wiggum
```

### Bun

```bash
bun add -g @th0rgal/ralph-wiggum
```

### From source

```bash
git clone https://github.com/Th0rgal/ralph-wiggum
cd ralph-wiggum
./install.sh
```

```powershell
git clone https://github.com/Th0rgal/ralph-wiggum
cd ralph-wiggum
.\install.ps1
```

This installs the `ralph` CLI command globally.

## Quick Start

```bash
# Simple task with iteration limit
ralph "Create a hello.txt file with 'Hello World'. Output <promise>DONE</promise> when complete." \
  --max-iterations 5

# Build something real
ralph "Build a REST API for todos with CRUD operations and tests. \
  Run tests after each change. Output <promise>COMPLETE</promise> when all tests pass." \
  --max-iterations 20

# Use Claude Code instead of OpenCode
ralph "Create a small CLI and document usage. Output <promise>COMPLETE</promise> when done." \
  --agent claude-code --model claude-sonnet-4 --max-iterations 5

# Use Codex instead of OpenCode
ralph "Create a small CLI and document usage. Output <promise>COMPLETE</promise> when done." \
  --agent codex --model gpt-5-codex --max-iterations 5

# Complex project with Tasks Mode
ralph "Build a full-stack web application with user auth and database" \
  --tasks --max-iterations 50
```

## Commands

### Running a Loop

```bash
ralph "<prompt>" [options]

Options:
  --agent AGENT            AI agent to use: opencode (default), claude-code, codex
  --min-iterations N       Minimum iterations before completion allowed (default: 1)
  --max-iterations N       Stop after N iterations (default: unlimited)
  --completion-promise T   Text that signals completion (default: COMPLETE)
  --tasks, -t              Enable Tasks Mode for structured task tracking
  --task-promise T         Text that signals task completion (default: READY_FOR_NEXT_TASK)
  --model MODEL            Model to use (agent-specific)
  --no-stream              Buffer agent output and print at the end
  --verbose-tools          Print every tool line (disable compact tool summary)
  --no-plugins             Disable non-auth OpenCode plugins for this run (opencode only)
  --no-commit              Don't auto-commit after iterations
  --allow-all              Auto-approve all tool permissions (default: on)
  --no-allow-all           Require interactive permission prompts
  --help                   Show help
```

### Tasks Mode

Tasks Mode allows you to break complex projects into smaller, manageable tasks. Ralph works on one task at a time and tracks progress in a markdown file.

```bash
# Enable Tasks Mode
ralph "Build a complete web application" --tasks --max-iterations 20

# Custom task completion signal
ralph "Multi-feature project" --tasks --task-promise "TASK_DONE"
```

#### Task Management Commands

```bash
# List current tasks
ralph --list-tasks

# Add a new task
ralph --add-task "Implement user authentication"

# Remove task by index
ralph --remove-task 3

# Show status (tasks shown automatically when tasks mode is active)
ralph --status
```

#### How Tasks Mode Works

1. **Task File**: Tasks are stored in `.ralph/ralph-tasks.md`
2. **One Task Per Iteration**: Ralph focuses on a single task to reduce confusion
3. **Automatic Progression**: When a task completes (`<promise>READY_FOR_NEXT_TASK</promise>`), Ralph moves to the next
4. **Persistent State**: Tasks survive loop restarts
5. **Focused Context**: Smaller contexts per iteration reduce costs and improve reliability

Task status indicators:
- `[ ]` - Not started
- `[/]` - In progress
- `[x]` - Complete

Example task file:
```markdown
# Ralph Tasks

- [ ] Set up project structure
- [x] Initialize git repository
- [/] Implement user authentication
  - [ ] Create login page
  - [ ] Add JWT handling
- [ ] Build dashboard UI
```

### Monitoring & Control

```bash
# Check status of active loop (run from another terminal)
ralph --status

# Add context/hints for the next iteration
ralph --add-context "Focus on fixing the auth module first"

# Clear pending context
ralph --clear-context
```

### Status Dashboard

The `--status` command shows:
- **Active loop info**: Current iteration, elapsed time, prompt
- **Pending context**: Any hints queued for next iteration
- **Current tasks**: Automatically shown when tasks mode is active (or use `--tasks`)
- **Iteration history**: Last 5 iterations with tools used, duration
- **Struggle indicators**: Warnings if agent is stuck (no progress, repeated errors)

```
╔══════════════════════════════════════════════════════════════════╗
║                    Ralph Wiggum Status                           ║
╚══════════════════════════════════════════════════════════════════╝

🔄 ACTIVE LOOP
   Iteration:    3 / 10
   Elapsed:      5m 23s
   Promise:      COMPLETE
   Prompt:       Build a REST API...

📊 HISTORY (3 iterations)
   Total time:   5m 23s

   Recent iterations:
   🔄 #1: 2m 10s | Bash:5 Write:3 Read:2
   🔄 #2: 1m 45s | Edit:4 Bash:3 Read:2
   🔄 #3: 1m 28s | Bash:2 Edit:1

⚠️  STRUGGLE INDICATORS:
   - No file changes in 3 iterations
   💡 Consider using: ralph --add-context "your hint here"
```

### Mid-Loop Context Injection

Guide a struggling agent without stopping the loop:

```bash
# In another terminal while loop is running
ralph --add-context "The bug is in utils/parser.ts line 42"
ralph --add-context "Try using the singleton pattern for config"
```

Context is automatically consumed after one iteration.

## Troubleshooting

### Plugin errors

This package is **CLI-only**. If OpenCode tries to load a `ralph-wiggum` or `open-ralph-wiggum` plugin,
remove it from your OpenCode `plugin` list (opencode.json), or run:

```bash
ralph "Your task" --no-plugins
```

### "bun: command not found"

Install Bun: https://bun.sh

## Writing Good Prompts

### Include Clear Success Criteria

❌ Bad:
```
Build a todo API
```

✅ Good:
```
Build a REST API for todos with:
- CRUD endpoints (GET, POST, PUT, DELETE)
- Input validation
- Tests for each endpoint

Run tests after changes. Output <promise>COMPLETE</promise> when all tests pass.
```

### Use Verifiable Conditions

❌ Bad:
```
Make the code better
```

✅ Good:
```
Refactor auth.ts to:
1. Extract validation into separate functions
2. Add error handling for network failures
3. Ensure all existing tests still pass

Output <promise>DONE</promise> when refactored and tests pass.
```

### Always Set Max Iterations

```bash
# Safety net for runaway loops
ralph "Your task" --max-iterations 20
```

## Recommended PRD Format

For best results, use a concise PRD with:

- **Goal**: one sentence summary of the desired outcome
- **Scope**: what is in/out
- **Requirements**: numbered, testable items
- **Constraints**: tech stack, performance, security, compatibility
- **Acceptance criteria**: explicit success checks
- **Completion promise**: include `<promise>COMPLETE</promise>` (or match your `--completion-promise`)

Example (Markdown):

```markdown
# PRD: Add Export Button

## Goal
Let users export reports as CSV from the dashboard.

## Scope
- In: export current report view
- Out: background exports, scheduling

## Requirements
1. Add "Export CSV" button to dashboard header.
2. CSV includes columns: date, revenue, sessions.
3. Works for reports up to 10k rows.

## Constraints
- Keep current UI styling.
- Use existing CSV utility in utils/csv.ts.

## Acceptance Criteria
- Clicking button downloads a valid CSV.
- CSV opens cleanly in Excel/Sheets.
- All existing tests pass.

## Completion Promise
<promise>COMPLETE</promise>
```

### JSON Feature List (Recommended for Complex Projects)

For larger projects, a structured JSON feature list works better than prose. Based on [Anthropic's research on effective agent harnesses](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents), JSON format reduces the chance of agents inappropriately modifying test definitions.

Create a `features.json` file:

```json
{
  "features": [
    {
      "category": "functional",
      "description": "Export button downloads CSV with current report data",
      "steps": [
        "Navigate to dashboard",
        "Click 'Export CSV' button",
        "Verify CSV file downloads",
        "Open CSV and verify columns: date, revenue, sessions",
        "Verify data matches displayed report"
      ],
      "passes": false
    },
    {
      "category": "functional",
      "description": "Export handles large reports up to 10k rows",
      "steps": [
        "Load report with 10,000 rows",
        "Click 'Export CSV' button",
        "Verify export completes without timeout",
        "Verify all rows present in CSV"
      ],
      "passes": false
    },
    {
      "category": "ui",
      "description": "Export button matches existing dashboard styling",
      "steps": [
        "Navigate to dashboard",
        "Verify button uses existing button component",
        "Verify button placement in header area"
      ],
      "passes": false
    }
  ]
}
```

Then reference it in your prompt:

```
Read features.json for the feature list. Work through each feature one at a time.
After verifying a feature works end-to-end, update its "passes" field to true.
Do NOT modify the description or steps - only change the passes boolean.
Output <promise>COMPLETE</promise> when all features pass.
```

**Why JSON?** Agents are less likely to inappropriately modify JSON test definitions compared to Markdown. The structured format keeps agents focused on implementation rather than redefining success criteria.

## When to Use Ralph

**Good for:**
- Tasks with automatic verification (tests, linters, type checking)
- Well-defined tasks with clear completion criteria
- Greenfield projects where you can walk away
- Iterative refinement (getting tests to pass)

**Not good for:**
- Tasks requiring human judgment
- One-shot operations
- Unclear success criteria
- Production debugging

## How It Works

```
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│   ┌──────────┐    same prompt    ┌──────────┐              │
│   │          │ ───────────────▶  │          │              │
│   │  ralph   │                   │ AI Agent │              │
│   │   CLI    │ ◀─────────────── │          │              │
│   │          │   output + files  │          │              │
│   └──────────┘                   └──────────┘              │
│        │                              │                     │
│        │ check for                    │ modify              │
│        │ <promise>                    │ files               │
│        ▼                              ▼                     │
│   ┌──────────┐                   ┌──────────┐              │
│   │ Complete │                   │   Git    │              │
│   │   or     │                   │  Repo    │              │
│   │  Retry   │                   │ (state)  │              │
│   └──────────┘                   └──────────┘              │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

1. Ralph sends your prompt to the selected agent
2. The agent works on the task, modifies files
3. Ralph checks output for completion promise
4. If not found, repeat with same prompt
5. AI sees previous work in files
6. Loop until success or max iterations

## Project Structure

```
ralph-wiggum/
├── exe/ralph.js                  # CLI entrypoint (npm wrapper)
├── ralph.ts                      # Main loop implementation
├── package.json                  # Package config
├── install.sh / install.ps1     # Installation scripts
└── uninstall.sh / uninstall.ps1 # Uninstallation scripts
```

### State Files (in `.ralph/`)

During operation, Ralph stores state in `.ralph/`. Here's what each file contains:

#### `ralph-loop.state.json` (gitignored)

Tracks the active loop session. Deleted when the loop ends.

```json
{
  "active": true,
  "iteration": 3,
  "minIterations": 1,
  "maxIterations": 10,
  "completionPromise": "COMPLETE",
  "tasksMode": true,
  "taskPromise": "READY_FOR_NEXT_TASK",
  "prompt": "Build a REST API for todos with CRUD operations and tests.",
  "startedAt": "2026-02-02T12:00:00Z",
  "model": "claude-sonnet-4",
  "agent": "claude-code"
}
```

#### `ralph-history.json`

Records every iteration -- timing, tools used, files changed, errors, and struggle indicators for detecting when the agent is stuck.

```json
{
  "iterations": [
    {
      "iteration": 1,
      "started_at": "2026-02-02T12:00:00Z",
      "ended_at": "2026-02-02T12:05:30Z",
      "duration_ms": 330000,
      "tools_used": { "Read": 5, "Edit": 3, "Bash": 2 },
      "files_modified": ["lib/auth.rb", "test/auth_test.rb"],
      "exit_code": 0,
      "completion_detected": false,
      "errors": []
    },
    {
      "iteration": 2,
      "started_at": "2026-02-02T12:05:31Z",
      "ended_at": "2026-02-02T12:07:15Z",
      "duration_ms": 104000,
      "tools_used": { "Edit": 4, "Bash": 3, "Read": 2 },
      "files_modified": ["lib/auth.rb"],
      "exit_code": 0,
      "completion_detected": false,
      "errors": []
    }
  ],
  "total_duration_ms": 434000,
  "struggle_indicators": {
    "repeated_errors": {},
    "no_progress_iterations": 0,
    "short_iterations": 0
  }
}
```

`struggle_indicators` tracks signs the agent is spinning its wheels:
- `repeated_errors` -- error messages that keep recurring (keyed by message, valued by count)
- `no_progress_iterations` -- consecutive iterations where no files were modified
- `short_iterations` -- consecutive iterations under 30 seconds (agent likely not doing real work)

#### `ralph-context.md`

Holds context injected via `--add-context` for the next iteration. The first write adds a header, subsequent appends concatenate directly. Content is included in the prompt sent to the agent.

```markdown
# Ralph Loop Context
The auth module uses JWT tokens and the test suite expects a running Redis instance.
Focus on fixing the login endpoint before moving to registration.
```

#### `ralph-tasks.md`

Task list for Tasks Mode (created when `--tasks` is used). Both machine-parsed and human-editable. See [Tasks Mode](#tasks-mode) for details on the checkbox syntax (`[ ]` todo, `[/]` in progress, `[x]` complete).

## Uninstall

```bash
npm uninstall -g @th0rgal/ralph-wiggum
```

```powershell
npm uninstall -g @th0rgal/ralph-wiggum
```

## Agent-Specific Notes

### Claude Code

[Claude Code](https://docs.anthropic.com/en/docs/claude-code) is Anthropic's official CLI for Claude. Use it with Open Ralph Wiggum for powerful autonomous coding:

```bash
ralph "Refactor the auth module and ensure tests pass" \
  --agent claude-code \
  --model claude-sonnet-4 \
  --max-iterations 15
```

### OpenAI Codex

[Codex](https://github.com/openai/codex) is OpenAI's code-specialized agent. Perfect for code generation and refactoring tasks:

```bash
ralph "Generate unit tests for all utility functions" \
  --agent codex \
  --model gpt-5-codex \
  --max-iterations 10
```

### OpenCode

[OpenCode](https://opencode.ai) is an open-source AI coding assistant. It's the default agent:

```bash
ralph "Fix all TypeScript errors" --max-iterations 10
```

## Learn More

- [Original Ralph Wiggum technique by Geoffrey Huntley](https://ghuntley.com/ralph/)
- [Ralph Orchestrator](https://github.com/mikeyobrien/ralph-orchestrator)

## See Also

Check out [OpenAgent](https://github.com/Th0rgal/openagent) — a dashboard for orchestrating AI agents with workspace management, real-time monitoring, and multi-agent workflows.

## License

MIT
