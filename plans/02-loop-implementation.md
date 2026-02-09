# Ralph.rb Core Loop Implementation Plan

This plan outlines the phased implementation of the core iteration loop based on the Loop specification in `specs/loop.md`.

## Phase 1: Basic Loop Architecture
- [ ] Create `Loop` class with basic initialization accepting a prompt object and options
- [ ] Implement main loop structure that runs continuously until a termination condition is met
- [ ] Create `Iteration` class for individual execution cycles
- [ ] Set up loop state management (iterations counter, timer, termination reason)
- [ ] Implement the prompt object interface: call `prompt.to_s` and pass result to agent

## Phase 2: Signal Detection
- [ ] Read signal strings from the prompt object (task-done and all-done)
- [ ] Implement output scanning for signal strings in agent output
- [ ] Handle task-done signal: end current iteration, start a fresh one with clean context
- [ ] Handle all-done signal: stop the loop entirely
- [ ] Distinguish between build mode (two signals) and plan mode (all-done only)

## Phase 3: Build Iteration Lifecycle
- [ ] Implement one-task-per-iteration discipline: agent picks one task, does it, signals task-done
- [ ] On task-done signal, tear down iteration and discard context
- [ ] Start fresh iteration with full context window for the next task
- [ ] On all-done signal, stop the loop (plan is exhausted)
- [ ] Track iteration outcomes (completed via task-done, completed via all-done)

## Phase 4: Plan Iteration Lifecycle
- [ ] Implement plan iteration: agent studies specs/code, writes the plan, signals all-done
- [ ] On all-done signal, stop the loop (plan is complete)
- [ ] If context fills up before plan is complete, cancel iteration and start a new one
- [ ] The partially-written plan on disk carries state to the next iteration
- [ ] Plan mode has no task-done signal -- only all-done and context guard

## Phase 5: Context Guard Implementation
- [ ] Integrate with Metrics component for real-time context size monitoring
- [ ] Implement context threshold checking against `--max-context` option
- [ ] When context limit exceeded, cancel current iteration
- [ ] Start a fresh iteration after context cancellation (work is preserved on disk)
- [ ] Log context guard activations for visibility

## Phase 6: Termination Conditions
- [ ] Implement all-done signal detection as loop terminator
- [ ] Add maximum iteration count enforcement (`--max-iterations`)
- [ ] Implement overall loop duration limit (`--duration`)
- [ ] Create graceful termination and cleanup procedures
- [ ] Add termination reason reporting (all-done, max iterations, duration, manual stop)

## Phase 7: Display and Monitoring
- [ ] Implement real-time iteration counter display (current / max)
- [ ] Add duration display (current iteration and total loop time)
- [ ] Show token consumption per iteration and cumulative total
- [ ] Display agent output in real-time
- [ ] Display the input prompt for reference

## Phase 8: Error Handling and Recovery
- [ ] Implement iteration failure recovery (agent crash, timeout)
- [ ] Handle agent communication errors gracefully
- [ ] Create graceful degradation on partial failures
- [ ] Add comprehensive logging for debugging
- [ ] Ensure iteration cancellation cleans up agent processes properly

## Verification Criteria
- [ ] Build loop runs task-done/all-done cycle correctly: one task per iteration
- [ ] Plan loop runs all-done cycle correctly: one big job, stops when plan is complete
- [ ] Context guard cancels iteration and starts fresh when limit exceeded
- [ ] Task-done signal ends iteration, all-done signal ends loop
- [ ] Plan files on disk are the shared state between iterations
- [ ] All termination conditions function correctly (all-done, max iterations, duration)
- [ ] Real-time monitoring displays accurate information
- [ ] Agent integration works seamlessly via prompt object
- [ ] Error recovery prevents data loss
- [ ] No Ruby style violations (run `bin/rubocop`)
- [ ] All tests pass (run `bin/test`)

## Dependencies
- Requires Prompt component for prompt objects (`Prompt::Build`, `Prompt::Plan`)
- Requires Metrics component for context size monitoring
- Requires Agents component for agent execution
- Signal strings come from the prompt object, not hardcoded in the loop
