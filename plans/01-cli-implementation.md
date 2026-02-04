# Ralph.rb CLI Implementation Plan

This plan outlines the phased implementation of the Ralph.rb command-line interface based on the CLI specification in `specs/cli.md`.

## Phase 1: Core CLI Infrastructure
- [ ] Create `exe/ralph` executable with proper shebang and permissions
- [ ] Set up basic argument parsing using Ruby's OptionParser or similar
- [ ] Implement standard Unix-style pipe support for stdin input
- [ ] Add basic help/version output functionality
- [ ] Set up project structure with lib/ directory and main.rb entry point

## Phase 2: Command Line Options Implementation
- [ ] Implement `--model` option for model selection validation
- [ ] Add `--max-iterations` parameter with integer validation
- [ ] Implement `--duration` option with time parsing (seconds/minutes)
- [ ] Add `--max-context` option with integer validation
- [ ] Implement `--completion` option for completion string detection
- [ ] Add validation for required vs optional parameters

## Phase 3: Input Processing and Validation
- [ ] Implement stdin reading with proper encoding handling
- [ ] Create input validation for prompt files vs inline prompts
- [ ] Add error handling for malformed input or missing files
- [ ] Implement argument combination logic (stdin + args)
- [ ] Add debug mode for troubleshooting input processing

## Phase 4: Integration Preparation
- [ ] Create interface stubs for Loop, Agent, and Metrics components
- [ ] Implement parameter passing to core loop system
- [ ] Add configuration management and defaults
- [ ] Create error handling and user-friendly error messages
- [ ] Implement logging/verbosity levels if needed

## Phase 5: Testing and Validation
- [ ] Write unit tests for CLI argument parsing
- [ ] Test pipe functionality with various input sources
- [ ] Validate error handling for invalid inputs
- [ ] Test integration with other components (mock versions)
- [ ] Add integration tests for complete CLI workflow

## Verification Criteria
- [ ] CLI accepts all specified options with proper validation
- [ ] Unix pipe functionality works correctly (`cat file | ralph`)
- [ ] Error messages are clear and helpful
- [ ] All options pass parameters correctly to core system
- [ ] Help documentation is comprehensive and accurate
- [ ] No Ruby style violations (run `bin/rubocop`)
- [ ] All tests pass (run `bin/test`)

## Dependencies
- Requires Loop, Agents, and Metrics components to be implemented
- Needs Ruby OptionParser or equivalent for argument handling
- Integration with opencil CLI for agent execution