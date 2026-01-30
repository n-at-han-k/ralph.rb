# Plan: Convert Ralph Wiggum from TypeScript/Bun to Ruby

## Overview

Convert the single-file TypeScript/Bun CLI application (`ralph.ts`, 1707 lines) into an idiomatic multi-file Ruby project. No gem packaging. Shell install/uninstall scripts will be removed.

## Target File Structure

```
ralph.rb                    # Entry point script (#!/usr/bin/env ruby)
lib/
  ralph/
    version.rb              # VERSION constant
    types.rb                # Data classes (AgentConfig, Task, IterationHistory, etc.)
    agents.rb               # Agent configs (opencode, claude-code, codex)
    cli.rb                  # Argument parsing and command dispatch
    state.rb                # State persistence (load/save/clear state, history, context)
    tasks.rb                # Task parsing, display, and management
    prompt_builder.rb       # Prompt construction (buildPrompt, getTasksModeSection)
    stream_processor.rb     # Streaming subprocess output with tool counting + heartbeat
    helpers.rb              # Utility functions (formatDuration, stripAnsi, escapeRegex, etc.)
    loop.rb                 # Main runRalphLoop logic
```

## Key Mapping Decisions

| TypeScript/Bun | Ruby |
|---|---|
| `Bun.spawn` + stream readers | `Open3.popen3` + `Thread.new` for concurrent stdout/stderr |
| `` $`git ...`.text() `` (Bun shell) | Backticks or `Open3.capture2` |
| `Bun.which(cmd)` | Custom `which` using `ENV['PATH']` or shelling out to `which` |
| `ReadableStream` + `TextDecoder` | `IO#gets` / `IO#read_nonblock` in threads |
| `interface` / `type` | Plain Ruby classes or `Struct`/`Data` |
| `Map<string, number>` | `Hash` |
| `process.argv` | `ARGV` |
| `process.exit` | `exit` |
| `process.on("SIGINT")` | `Signal.trap("INT")` |
| `existsSync` / `readFileSync` / `writeFileSync` | `File.exist?` / `File.read` / `File.write` |
| `mkdirSync(path, { recursive: true })` | `FileUtils.mkdir_p` |
| `JSON.parse` / `JSON.stringify` | `JSON.parse` / `JSON.generate` |
| `setTimeout` / `setInterval` | `sleep` / `Thread` with loop |
| `async/await` | Synchronous Ruby (threads where needed for I/O) |
| RegExp literals | Ruby `/regex/` |

## Implementation Steps

1. Create `lib/ralph/` directory structure
2. Convert types/data structures (`types.rb`)
3. Convert utility helpers (`helpers.rb`)
4. Convert agent configurations (`agents.rb`)
5. Convert state management (`state.rb`)
6. Convert task parsing/management (`tasks.rb`)
7. Convert prompt builder (`prompt_builder.rb`)
8. Convert stream processor (`stream_processor.rb`)
9. Convert CLI argument parsing + command dispatch (`cli.rb`)
10. Convert main loop (`loop.rb`)
11. Create entry point `ralph.rb`
12. Delete TypeScript files (`ralph.ts`, `bin/ralph.js`, `package.json`, `bun.lock`, install/uninstall scripts)

## Subprocess I/O Strategy

Use `Open3.popen3` to spawn agent processes. Read stdout and stderr concurrently using two `Thread.new` blocks, each reading line-by-line with `IO#gets`. A third thread handles the heartbeat timer (periodic "still working..." messages when no output has been printed recently). Tool counting, compact summaries, and ANSI stripping all happen in the stdout/stderr reader threads via synchronized access to shared state (a `Mutex`-protected `Hash` for tool counts).

## Things to Preserve

- All CLI flags and behavior
- State file format (JSON) - stays compatible
- Git integration (auto-commit, file snapshots)
- ANSI stripping, tool parsing regexes
- Heartbeat timer, compact tool summaries
- SIGINT handling with graceful shutdown
- All emoji/box-drawing output formatting

## Files to Delete After Conversion

- `ralph.ts`
- `bin/ralph.js`
- `package.json`
- `bun.lock`
- `install.sh`
- `install.ps1`
- `uninstall.sh`
- `uninstall.ps1`
