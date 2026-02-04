# Ralph.rb Core Loop Implementation Plan

This plan outlines the phased implementation of the core iteration loop based on the Loop specification in `specs/loop.md`.

## Phase 1: Basic Loop Architecture
- [ ] Create `Loop` class with basic initialization
- [ ] Implement main infinite loop structure with proper termination conditions
- [ ] Create `Iteration` class for individual execution cycles
- [ ] Set up iteration cancellation mechanism (context/time guards)
- [ ] Implement basic loop state management (iterations counter, timer)

## Phase 2: Iteration Management
- [ ] Implement iteration creation and execution workflow
- [ ] Add iteration cancellation based on context length monitoring
- [ ] Implement iteration cancellation based on duration limits
- [ ] Create iteration state tracking (running, completed, cancelled)
- [ ] Add iteration result collection and preservation

## Phase 3: Context and Guard Implementation
- [ ] Integrate with Metrics component for real-time context monitoring
- [ ] Implement context size threshold checking and iteration restart
- [ ] Add iteration duration monitoring and cancellation
- [ ] Create context preservation between iterations (task list continuity)
- [ ] Implement task list passing and reminder system

## Phase 4: Termination Conditions
- [ ] Implement completion string detection from agent output
- [ ] Add maximum iteration count enforcement
- [ ] Implement overall loop duration limits
- [ ] Create graceful termination and cleanup procedures
- [ ] Add termination reason reporting and statistics

## Phase 5: Agent Integration
- [ ] Create interface to Opencode agent execution
- [ ] Implement prompt construction with task list and instructions
- [ ] Add agent output processing and completion string detection
- [ ] Integrate with Agents component for configuration and execution
- [ ] Handle agent errors and communication failures

## Phase 6: Display and Monitoring
- [ ] Implement real-time iteration counter display
- [ ] Add current iteration status indicator
- [ ] Create duration display (current and total)
- [ ] Implement token consumption display (per iteration and total)
- [ ] Show agent output in real-time
- [ ] Display input prompt for reference

## Phase 7: Prompt Engineering
- [ ] Create base prompt template explaining completion requirements
- [ ] Add explicit instruction to avoid user interaction
- [ ] Implement task list integration into prompts
- [ ] Add context preservation instructions
- [ ] Create prompt variation for different iteration states

## Phase 8: Error Handling and Recovery
- [ ] Implement iteration failure recovery mechanisms
- [ ] Add context corruption detection and handling
- [ ] Create agent communication error recovery
- [ ] Implement graceful degradation on partial failures
- [ ] Add comprehensive logging for debugging

## Verification Criteria
- [ ] Loop runs continuously until completion conditions met
- [ ] Iterations cancel properly when context limits exceeded
- [ ] Task continuity maintained across iteration restarts
- [ ] Completion string detection works reliably
- [ ] All termination conditions function correctly
- [ ] Real-time monitoring displays accurate information
- [ ] Agent integration works seamlessly
- [ ] Error recovery prevents data loss
- [ ] No Ruby style violations (run `bin/rubocop`)
- [ ] All tests pass (run `bin/test`)

## Dependencies
- Requires Metrics component for context monitoring
- Requires Agents component for agent execution
- Requires prompt templates and task list system
- Depends on JSON stream parsing from Metrics