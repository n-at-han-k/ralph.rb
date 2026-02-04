# Ralph.rb Agents Integration Implementation Plan

This plan outlines the phased implementation of agent integration with opencode based on the Agents specification in `specs/agents.md`.

## Phase 1: Opencode Command Wrapper
- [ ] Create `Opencode` class for CLI interaction
- [ ] Implement basic command construction and execution
- [ ] Add subprocess management with proper error handling
- [ ] Implement JSON stream format specification (`--format json`)
- [ ] Create configuration management for opencode options

## Phase 2: Configuration and Options
- [ ] Implement `--model` option handling and validation
- [ ] Add `--agent` option support for agent selection
- [ ] Create prompt passing mechanism (`--prompt` or direct argument)
- [ ] Implement JSON stream format enforcement
- [ ] Add opencode command path resolution and validation

## Phase 3: Process Management
- [ ] Implement subprocess spawning with stdin/stdout handling
- [ ] Create process monitoring and timeout management
- [ ] Add signal handling for graceful termination
- [ ] Implement process cleanup and resource management
- [ ] Create error handling for opencode execution failures

## Phase 4: JSON Stream Processing
- [ ] Create JSON stream reader for opencode output
- [ ] Implement line-by-line JSON parsing with error recovery
- [ ] Add event filtering and routing to Metrics component
- [ ] Create buffer management for high-volume output
- [ ] Implement stream error detection and handling

## Phase 5: Event Integration
- [ ] Create event forwarding mechanism to Metrics component
- [ ] Implement event type mapping and transformation
- [ ] Add event timestamp and session ID handling
- [ ] Create event aggregation for step_finish events
- [ ] Implement real-time event processing capabilities

## Phase 6: Agent Lifecycle Management
- [ ] Implement agent startup and initialization procedures
- [ ] Add agent state tracking (running, completed, failed)
- [ ] Create agent termination and cleanup processes
- [ ] Implement agent restart capabilities for failed iterations
- [ ] Add agent configuration validation

## Phase 7: Communication Layer
- [ ] Create bidirectional communication interface
- [ ] Implement prompt delivery to agent process
- [ ] Add response collection and buffering
- [ ] Create interrupt mechanism for iteration cancellation
- [ ] Implement status reporting and health checks

## Phase 8: Error Handling and Diagnostics
- [ ] Implement opencode command not found handling
- [ ] Add authentication and configuration error detection
- [ ] Create network connectivity error handling
- [ ] Implement JSON parsing error recovery
- [ ] Add comprehensive logging and debugging capabilities

## Verification Criteria
- [ ] Opencode CLI commands execute correctly with all options
- [ ] JSON stream output is parsed reliably
- [ ] All required events are captured and forwarded
- [ ] Agent process management is robust
- [ ] Error handling covers all failure modes
- [ ] Communication with Metrics component works
- [ ] Agent lifecycle is managed properly
- [ ] No Ruby style violations (run `bin/rubocop`)
- [ ] All tests pass (run `bin/test`)

## Dependencies
- Requires Metrics component for event processing
- Requires Loop component for agent lifecycle management
- Requires opencode CLI to be installed and available
- Depends on proper JSON stream format from opencode