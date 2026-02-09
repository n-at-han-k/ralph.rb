# Ralph.rb Prompts Implementation Plan

This plan outlines the phased implementation of the prompt template system based on the Prompts specification in `specs/prompts.md`.

## Phase 1: Module and Class Structure
- [ ] Create `Ralph::Prompt` module namespace under `lib/ralph/prompt/`
- [ ] Create `Prompt::Build` class with initialization accepting `task_done:`, `all_done:`, and `context:` keyword arguments
- [ ] Create `Prompt::Plan` class with initialization accepting `goal:` and `all_done:` keyword arguments
- [ ] Define default signal strings: `<task>DONE</task>` for task-done, `<promise>COMPLETE</promise>` for all-done
- [ ] Implement `#to_s` on both classes returning the complete prompt text

## Phase 2: Prompt::Build Implementation
- [ ] Implement the build prompt heredoc with all numbered steps (1-5) and guardrail rules (99999+)
- [ ] Implement `%{task_done}` placeholder substitution in the prompt text
- [ ] Implement `%{all_done}` placeholder substitution in the prompt text
- [ ] Append user-supplied `context:` text to the end of the prompt when present
- [ ] Preserve the guardrail numbering exactly as specified (99999, 999999, etc.)

## Phase 3: Prompt::Plan Implementation
- [ ] Implement the plan prompt heredoc with study steps (0a-0c) and the main planning instruction
- [ ] Implement `%{goal}` placeholder substitution with user-supplied goal text
- [ ] Implement `%{all_done}` placeholder substitution in the prompt text
- [ ] Implement default goal text when no goal is provided: "Consider missing elements and plan accordingly..."
- [ ] Ensure plan prompt includes the IMPORTANT instruction to plan only, not implement

## Phase 4: Signal String Management
- [ ] Define signal constants for task-done and all-done defaults
- [ ] Allow signal strings to be overridden via constructor arguments
- [ ] Expose signal strings as readable attributes for Loop component consumption
- [ ] Ensure signal strings are embedded verbatim in prompt output for agent detection

## Phase 5: User Context Integration
- [ ] Implement context appending for `Prompt::Build` (stdin or CLI positional args)
- [ ] Implement goal injection for `Prompt::Plan` (stdin or CLI positional args)
- [ ] Handle nil/empty context gracefully (no trailing whitespace or blank sections)
- [ ] Ensure user context does not interfere with signal string placeholders

## Phase 6: Integration with Loop and CLI
- [ ] Ensure `#to_s` output is directly passable to the Opencode agent via Loop
- [ ] Verify CLI subcommand (`build`/`plan`) selects the correct prompt class
- [ ] Ensure Loop component can read signal strings from the prompt object for detection
- [ ] Test prompt output with actual Opencode `--prompt` flag formatting requirements

## Phase 7: Testing and Validation
- [ ] Write unit tests for `Prompt::Build#to_s` output correctness
- [ ] Write unit tests for `Prompt::Plan#to_s` output correctness
- [ ] Test default signal strings are used when not overridden
- [ ] Test custom signal strings are substituted correctly
- [ ] Test context/goal appending and nil handling
- [ ] Test that guardrail numbers appear in correct order in build prompt

## Verification Criteria
- [ ] `Prompt::Build.new.to_s` returns complete build prompt with default signals
- [ ] `Prompt::Plan.new.to_s` returns complete plan prompt with default goal
- [ ] Signal strings are configurable and exposed as attributes
- [ ] User context is appended without corrupting prompt structure
- [ ] Guardrail numbering (99999+) is preserved exactly as specified
- [ ] Prompt text matches the specification verbatim (no reordering or reformatting)
- [ ] No Ruby style violations (run `bin/rubocop`)
- [ ] All tests pass (run `bin/test`)

## Dependencies
- Requires CLI component for subcommand routing and user context collection
- Requires Loop component for prompt-to-agent delivery
- Requires Agents component for Opencode prompt flag compatibility
- Signal strings must be accessible to Loop for completion/task-done detection
