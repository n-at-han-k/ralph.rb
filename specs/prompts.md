# Prompts Specification

What does ralph say to the agent, and why?

## Intent

The human writes specs -- declarative descriptions of what the system should be. The human writes plans -- the tasks that need doing. The agent works through the plan, one task at a time, in a loop that gives it fresh context every iteration.

That's the core of it. The build loop consumes a plan. It doesn't care who wrote the plan -- human or agent. Most of the time, the human knows what needs building and writes the plan themselves. `ralph plan` exists as a convenience for when you'd rather have the agent figure out the gaps by comparing specs to code. It's optional, not required.

## How It Works In Practice

The human invokes whichever prompt they need, when they need it. They don't run together. They don't switch automatically. There is no orchestrator.

**1. The human writes specs.** Declarative descriptions of what the system is. These live in `specs/`.

**2. The human writes plans.** The tasks that need doing, prioritized, in `plans/`. These can be as detailed or as rough as the human likes. The build loop just needs items to pick from.

**3. Optionally, the human runs `ralph plan` instead of writing plans by hand.** The agent reads the specs, reads the code, figures out the gaps, and writes a prioritized task list into `plans/`. This might take one iteration or a few. Then the human stops it and reads what it produced. If the plan looks wrong -- maybe a spec needs clarifying, or the agent missed something -- the human adjusts the specs or deletes the plan and re-runs.

**4. The human runs `ralph build`.** The agent reads the specs and the plan, picks the most important task, implements it, runs tests, commits, and signals that the task is done. The loop ends that iteration and starts a fresh one. The next iteration reads the updated plan and picks the next task. The human lets this run -- maybe 10 iterations, maybe 50. They watch. When it goes off the rails, they stop it.

**5. Back to `ralph plan` when needed.** Plans get stale. The agent goes in circles. New specs get written. The human runs plan again to regenerate the task list from the current state of things. Or just edits the plan by hand. The plan is disposable -- regeneration is cheap compared to the agent going in circles.

This is what it means to sit _on_ the loop, not _in_ it. You're not picking tasks or writing code. But you are deciding when to plan and when to build, watching the output, and tuning the inputs when the agent needs better signs.

## Overview

The prompt is everything. It's the only thing the agent sees at the start of each iteration. A good prompt makes Ralph work. A bad one makes it spin. There are two prompts for two jobs: planning and building. Each is a self-contained instruction set -- no shared base, no inheritance, no clever abstractions. Just the words.

## Architecture

`Prompt::Plan` and `Prompt::Build` are objects that live under `Ralph::Prompt`. Each responds to `#to_s` which returns the complete prompt text for one iteration. The user can append additional context (via stdin or CLI args) which gets tacked onto the end.

```ruby
Prompt::Plan.new(goal: "user authentication system").to_s
Prompt::Build.new(
  task_done: "<task>DONE</task>",
  all_done: "<promise>COMPLETE</promise>"
).to_s

# With user context appended
Prompt::Build.new(
  task_done: "<task>DONE</task>",
  all_done: "<promise>COMPLETE</promise>",
  context: "Focus on the metrics module first"
).to_s
```

That's it. No configuration DSL, no template engine, no YAML. Heredocs in Ruby.

## Signals

The agent communicates back to the loop by emitting signal strings in its output. The loop watches for these strings and acts on them.

### Building: two signals

Building is task-oriented. One task per iteration. The agent needs two distinct signals:

- **task-done** -- "I finished this task." The loop ends the current iteration and starts a fresh one. The next iteration reads the updated plan and picks the next task. Default: `<task>DONE</task>`
- **all-done** -- "The plan is exhausted, there is nothing left to do." The loop stops entirely. Default: `<promise>COMPLETE</promise>`

The task-done signal is what makes the loop task-oriented. Without it, the agent would keep working in one context window until it either runs out of context or claims everything is done. With it, the agent does one focused task, commits, signals, and gets a fresh context for the next task.

### Planning: one signal

Planning is one big job. The agent studies everything and produces the plan. There's no per-task signal because there's only one task: produce the plan.

- **all-done** -- "The plan is complete." The loop stops. Default: `<promise>COMPLETE</promise>`

If the context fills up before planning is complete, the context guard cancels the iteration and the next one picks up where the plan left off -- because the partially-written plan is already on disk.

## Prompt::Plan

The planning prompt is a convenience. It instructs the agent to study everything, compare specs against code, and produce a prioritized task list in `plans/`. It does NOT implement anything. It does NOT commit anything.

The prompt text:

```
0a. Study `specs/*` to learn the application specifications.
0b. Study the plans in `plans/` (if present) to understand the plan so far.
0c. Study `lib/*` to understand the existing codebase and shared utilities.

1. Study the plans in `plans/` (if present; they may be incorrect) and study existing source code in `lib/*` and compare it against `specs/*`. Analyze findings, prioritize tasks, and create/update the plans in `plans/` as bullet point lists sorted in priority of items yet to be implemented. Think carefully. Consider searching for TODO, minimal implementations, placeholders, skipped/flaky tests, and inconsistent patterns. Study the plans to determine the starting point for research and keep them up to date with items considered complete/incomplete.

IMPORTANT: Plan only. Do NOT implement anything. Do NOT assume functionality is missing; confirm with code search first.

ULTIMATE GOAL: %{goal}

When you have completed the plan, output the exact completion string on its own line: %{all_done}
```

The `%{goal}` placeholder is filled from the user's context. If no context is provided, the line reads: `ULTIMATE GOAL: Consider missing elements and plan accordingly. If an element is missing, search first to confirm it doesn't exist, then if needed author the specification at specs/FILENAME.md.`

## Prompt::Build

The building prompt is the heart of ralph. It instructs the agent to study specs, read the plan, pick **one task**, implement it, validate against backpressure, update the plan, commit, and signal task-done. One task. Not two, not "as many as you can." One.

The prompt text:

```
0a. Study `specs/*` to learn the application specifications.
0b. Study the plans in `plans/`.
0c. For reference, the application source code is in `lib/*`.

1. Your task is to implement ONE item from the plans. Follow the plans in `plans/` and choose the most important item to address. Before making changes, search the codebase (don't assume not implemented).
2. After implementing functionality or resolving problems, run the tests and checks for that unit of code that was improved. If functionality is missing then it's your job to add it as per the application specifications. Think carefully.
3. When you discover issues, immediately update the plans in `plans/` with your findings. When resolved, update and remove the item.
4. When the tests pass, update the plans in `plans/`, then `git add -A` then `git commit` with a message describing the changes. After the commit, `git push`.
5. After committing, output the task-done signal on its own line: %{task_done}
6. If there are no remaining items in the plans, output the all-done signal instead: %{all_done}

99999. Important: When authoring documentation, capture the why -- tests and implementation importance.
999999. Important: Single sources of truth, no migrations/adapters. If tests unrelated to your work fail, resolve them as part of the increment.
9999999. As soon as there are no build or test errors create a git tag. If there are no git tags start at 0.0.0 and increment patch by 1 for example 0.0.1 if 0.0.0 does not exist.
99999999. You may add extra logging if required to debug issues.
999999999. Keep the plans in `plans/` current with learnings -- future work depends on this to avoid duplicating efforts. Update especially after finishing your turn.
9999999999. When you learn something new about how to run the application, update @AGENTS.md but keep it brief. For example if you run commands multiple times before learning the correct command then that file should be updated.
99999999999. For any bugs you notice, resolve them or document them in the plans even if it is unrelated to the current piece of work.
999999999999. Implement functionality completely. Placeholders and stubs waste efforts and time redoing the same work.
9999999999999. When plans become large periodically clean out the items that are completed.
99999999999999. If you find inconsistencies in the specs/* then carefully update the specs.
999999999999999. IMPORTANT: Keep @AGENTS.md operational only -- status updates and progress notes belong in the plans. A bloated AGENTS.md pollutes every future loop's context.
9999999999999999. IMPORTANT: Do ONE task per iteration. Pick it, do it, commit it, signal task-done. Do not continue to the next task -- the loop will start a fresh iteration for that.
```

## The Guardrail Numbers

The `99999...` numbering is deliberate and inherited from the original Ralph technique. Higher number = higher priority. The agent treats these as invariants that override normal instructions. Don't renumber them, don't reformat them into a neat list. The awkward numbering is a feature -- it signals escalating importance.

## Why Two Prompts, Not One

A planning prompt that also implements is a prompt that skips planning. A building prompt that also plans from scratch wastes context on gap analysis when the plan already exists. Separation keeps each iteration focused: plan iterations produce plans, build iterations produce commits. The user selects which prompt to use by running `ralph plan` or `ralph build`.

## Agent Agnosticism

These prompts do not reference specific model names, subagent counts, or provider-specific features. The underlying agent (opencode, claude, codex) decides how to parallelize, which models to use for subtasks, and how to structure its own work. Ralph's job is to say what needs doing, not how the agent's internals should work.
