# Ralph.rb Metrics Calculation Implementation Plan

This plan outlines the phased implementation of context and token usage metrics based on the Metrics specification in `specs/metrics.md`.

## Phase 1: Event Parsing Infrastructure
- [ ] Create `Events` module with event class definitions
- [ ] Implement JSON stream parsing for opencode events
- [ ] Create `StepFinishEvent` class for token tracking
- [ ] Add `StepStartEvent` class for iteration tracking
- [ ] Implement `ToolUseEvent` class for tool execution tracking

## Phase 2: Token Calculation Logic
- [ ] Implement context calculation formula: `input + cache.read + cache.write`
- [ ] Create token aggregation methods for each step
- [ ] Add cumulative token tracking across iterations
- [ ] Implement per-iteration token difference calculation
- [ ] Create token rate calculation (tokens per second)

## Phase 3: Event Stream Processing
- [ ] Create `MetricsCollector` class for real-time processing
- [ ] Implement line-by-line JSON stream consumption
- [ ] Add event type detection and routing
- [ ] Create event state tracking (current step, session ID)
- [ ] Implement buffer management for partial JSON lines

## Phase 4: Context Monitoring
- [ ] Implement real-time context size tracking
- [ ] Create context threshold alerting system
- [ ] Add context growth trend analysis
- [ ] Implement context usage percentage calculation
- [ ] Create context projection for upcoming steps

## Phase 5: Metrics Storage and Retrieval
- [ ] Create metrics data structures for current and historical data
- [ ] Implement iteration-level metrics storage
- [ ] Add session-level metrics aggregation
- [ ] Create metrics history tracking
- [ ] Implement metrics export capabilities

## Phase 6: Real-time Monitoring Interface
- [ ] Create `current_context()` method for immediate access
- [ ] Implement `tokens_consumed()` aggregation method
- [ ] Add `iteration_metrics()` for per-iteration data
- [ ] Create `session_metrics()` for overall statistics
- [ ] Implement metrics update notifications

## Phase 7: Integration Points
- [ ] Create interface for Loop component context monitoring
- [ ] Implement threshold-based callback system
- [ ] Add metrics reporting for display components
- [ ] Create metrics persistence between iterations
- [ ] Implement metrics reset and cleanup procedures

## Phase 8: Advanced Analytics
- [ ] Implement token efficiency analysis
- [ ] Add cache hit rate calculation
- [ ] Create tool usage cost analysis
- [ ] Implement performance trend analysis
- [ ] Add predictive context growth modeling

## Phase 9: Error Handling and Validation
- [ ] Implement JSON parsing error recovery
- [ ] Add malformed event handling
- [ ] Create missing field validation
- [ ] Implement event sequence validation
- [ ] Add metrics corruption detection

## Verification Criteria
- [ ] JSON stream parsing handles all event types correctly
- [ ] Context calculation matches specification formula exactly
- [ ] Real-time monitoring provides accurate current state
- [ ] Token tracking works across multiple iterations
- [ ] Integration with Loop component works seamlessly
- [ ] Error handling is robust and comprehensive
- [ ] Performance is suitable for real-time monitoring
- [ ] No Ruby style violations (run `bin/rubocop`)
- [ ] All tests pass (run `bin/test`)

## Dependencies
- Requires Agents component for JSON stream input
- Requires Loop component for integration callbacks
- Depends on opencode JSON stream format consistency
- Needs proper time tracking for rate calculations

## Example Event Classes to Implement
```ruby
# Based on spec example - create classes for these events:
- step_start
- text 
- tool_use
- step_finish (critical for token tracking)
```

## Critical Implementation Details
- Context formula: `input + cache.read + cache.write`
- Cache pattern: `cache.read` ≈ previous step's `cache.read + cache.write`
- Must track `step_finish` events specifically for token data
- Need real-time access for loop cancellation decisions