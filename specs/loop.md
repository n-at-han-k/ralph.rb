# Loop Specification

What is a ralph loop, and how do we implement one?

## Overview

The essence of a ralph loop is an infinite loop with certain guards to prevent context becoming tainted. If the context becomes too large then the iteration is cancelled and started again. The work done is not lost, it just means that a fresh context will carry on the work.

This whole technique relies on a way of constantly reminding the agent what it's working on and what it's done. This is simply ensured by a task list. It will be passed the task list as a prompt, and will work until it thinks it has completed the task, or it is cancelled by the loop.

## Task-Oriented Iterations

One iteration = one task. This is the core discipline.

Each iteration the agent reads the plan, picks one task, does it, runs tests, commits, and signals that the task is done. The loop tears down that iteration, throws away the context, and starts a fresh one. The next iteration reads the updated plan and picks the next task.

The plan files on disk are the shared state between iterations. They are the only thing that survives the context wipe. The agent writes its progress into the plan before the iteration ends, so the next iteration knows what's been done and what's left.

This is why the loop works. Each iteration gets 100% of the context window for one focused task. No accumulated noise from previous tasks. No degraded reasoning from a bloated context. Fresh mind, every time.

### Building iterations

Building is many small tasks. The agent picks one, does it, commits, signals task-done. The loop starts the next iteration. This continues until the agent signals all-done (the plan is exhausted) or limits are hit.

Two signals:
- **task-done** -- "I finished this task, end the iteration." The loop starts a new iteration with fresh context.
- **all-done** -- "The plan is exhausted, there is nothing left to do." The loop stops entirely.

### Planning iterations

Planning is one big job: produce the plan. The agent studies specs, studies code, writes the plan. It typically completes in 1-2 iterations. If the codebase is large and the context fills up before the plan is complete, the context guard cancels the iteration and the next one picks up where the plan left off -- because the partially-written plan is already on disk.

One signal:
- **all-done** -- "The plan is complete." The loop stops.

## Architecture

A main loop simply runs continuously to read data from opencode, and check whether the iteration needs cancelling.

An iteration object is created which runs the agent, and can be cancelled whenever we like.

### What ends a build iteration (normal)
- agent signals task-done

### What ends a build iteration (abnormal)
- context limit exceeded -- iteration cancelled, next iteration starts fresh
- duration limit exceeded -- iteration cancelled

### What ends a plan iteration (normal)
- agent signals all-done

### What ends a plan iteration (abnormal)
- context limit exceeded -- iteration cancelled, next iteration continues the plan
- duration limit exceeded -- iteration cancelled

### What ends the main loop
- agent signals all-done
- max iterations reached
- loop duration exceeded

## Prompts

The loop receives a prompt object (see `specs/prompts.md`). The prompt object produces the complete instruction text for the iteration via `#to_s`. The loop does not construct prompts -- it just passes whatever the prompt object gives it to the agent.

**important** WE MUST INSTRUCT the agent NOT to interact with the user. All questions must be answered by reading the spec. This instruction lives in the prompt objects, not in the loop.

## Display Output

We want to see the following:
- number of iterations
- current iteration
- duration
- tokens consumed
- over all and per iteration data
- the output of the agent
- the input prompt
