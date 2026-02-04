# Loop Specification

What is a ralph loop, and how do we implement one?

## Overview

The essence of a ralph loop is an infinite loop will certain guards to prevent context becoming tainted. If the context becomes too large then then the iteration is cancelled and started again. The work done is not lost, it just means that a fresh context will carry on the work.

This whole technique relies on a way of constantly reminding the agent what it's working on and what it's done. This is simply ensured by a task list. It will be passed the task list as a prompt, and will work until it thinkgs it has completed the task, or it is cancelled by the loop.

## Architecture

A main loop simply runs contonuously to read data from opencode, and check whether the iteration needs cancelling.

An iteration object is created which run the agent, and can be cancelled whenever we like.

In order for the loop to stop once complete, we must instruct the agent to pass back a certain string that we will detect when it thinks it has completed.

### What ends the loop iteration
- iteration context length
- iteration duration

### What ends the main loop
- complete string received
- max iteration reached
- loop duration

## Prompts
Only prompt needed is to explain to return the string once completed, or perhaps to follow the items on the list. The rest can be passed in by the user.

**important** WE MUST INSTRUCT the agent NOT to interact with the user. All questions must be aswered by reading the spec.

## Display Output

We want to see the following:
- number of iterations
- current iteration
- duration
- tokens consumed
- over all and per iteration data
- the output of the agent
- the input prompt
