# Ralph.rb CLI Implementation Plan

This plan outlines the phased implementation of the Ralph.rb command-line interface based on the CLI specification in `specs/cli.md`.

## Phase 1: Core CLI Infrastructure
- [ ] Create `exe/ralph` executable with proper shebang and permissions
- [ ] Set up basic argument parsing using Ruby's OptionParser or similar
- [ ] Implement standard Unix-style pipe support for stdin input
- [ ] Add basic help/version output functionality
- [ ] Set up project structure with lib/ directory and main.rb entry point

## Phase 2: Subcommand Routing
- [ ] Implement `build` subcommand as the default when no subcommand is given
- [ ] Implement `plan` subcommand for gap analysis and plan generation
- [ ] Route subcommand to the correct prompt class (`Prompt::Build` or `Prompt::Plan`)
- [ ] Handle bare `ralph` invocation as equivalent to `ralph build`
- [ ] Handle bare `ralph --max-iterations=10` as equivalent to `ralph build --max-iterations=10`

## Phase 3: Command Line Options Implementation
- [ ] Implement `--model=MODEL` option for model selection
- [ ] Add `--max-iterations=N` parameter with integer validation
- [ ] Implement `--duration=SECONDS` option with integer validation
- [ ] Add `--max-context=N` option with integer validation
- [ ] Implement `--completion=STRING` option for completion string override
- [ ] Add `-h, --help` and `-v, --version` flags
- [ ] Ensure all options work with both `build` and `plan` subcommands

## Phase 4: Input Processing and Validation
- [ ] Implement stdin reading with proper encoding handling
- [ ] Combine positional arguments as user context text
- [ ] Pass stdin/positional text as `context:` to `Prompt::Build` or `goal:` to `Prompt::Plan`
- [ ] Add error handling for malformed input or missing files
- [ ] Add debug mode for troubleshooting input processing

## Phase 5: Integration Preparation
- [ ] Instantiate the correct Prompt object based on subcommand and pass options
- [ ] Pass prompt object and CLI options to Loop for execution
- [ ] Create error handling and user-friendly error messages
- [ ] Implement parameter defaults and validation

## Phase 6: Testing and Validation
- [ ] Write unit tests for CLI argument parsing
- [ ] Test subcommand routing (build default, plan explicit)
- [ ] Test pipe functionality with various input sources (`cat file | ralph build`)
- [ ] Validate error handling for invalid inputs
- [ ] Test integration with Prompt and Loop components (mock versions)
- [ ] Add integration tests for complete CLI workflow

## Verification Criteria
- [ ] `ralph build` and `ralph` are equivalent
- [ ] `ralph plan "goal"` routes to `Prompt::Plan` with goal text
- [ ] CLI accepts all specified options with proper validation
- [ ] Unix pipe functionality works correctly (`cat file | ralph build`)
- [ ] Positional text and stdin are passed as user context to the prompt
- [ ] Error messages are clear and helpful
- [ ] All options pass parameters correctly to core system
- [ ] Help documentation is comprehensive and accurate
- [ ] No Ruby style violations (run `bin/rubocop`)
- [ ] All tests pass (run `bin/test`)

## Dependencies
- Requires Prompt component for `Prompt::Build` and `Prompt::Plan` classes
- Requires Loop, Agents, and Metrics components for execution
- Needs Ruby OptionParser or equivalent for argument handling
- Integration with opencode CLI for agent execution
