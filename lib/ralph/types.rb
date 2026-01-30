# frozen_string_literal: true

module Ralph
  # Agent configuration
  AgentConfig = Struct.new(
    :type,             # Symbol - :opencode, :claude_code, :codex
    :command,          # String - CLI command name
    :build_args,       # Proc(prompt, model, options) -> Array<String>
    :build_env,        # Proc(options) -> Hash<String, String>
    :parse_tool_output,# Proc(line) -> String or nil
    :config_name,      # String - display name
    keyword_init: true
  )

  # Task from markdown task list
  Task = Struct.new(
    :text,           # String
    :status,         # Symbol - :todo, :in_progress, :complete
    :subtasks,       # Array<Task>
    :original_line,  # String
    keyword_init: true
  )

  # Single iteration record
  IterationHistory = Struct.new(
    :iteration,           # Integer
    :started_at,          # String (ISO 8601)
    :ended_at,            # String (ISO 8601)
    :duration_ms,         # Integer
    :tools_used,          # Hash<String, Integer>
    :files_modified,      # Array<String>
    :exit_code,           # Integer
    :completion_detected, # Boolean
    :errors,              # Array<String>
    keyword_init: true
  )

  # Struggle indicators
  StruggleIndicators = Struct.new(
    :repeated_errors,        # Hash<String, Integer>
    :no_progress_iterations, # Integer
    :short_iterations,       # Integer
    keyword_init: true
  ) do
    def self.empty
      new(repeated_errors: {}, no_progress_iterations: 0, short_iterations: 0)
    end
  end

  # Full history across iterations
  RalphHistory = Struct.new(
    :iterations,          # Array<IterationHistory>
    :total_duration_ms,   # Integer
    :struggle_indicators, # StruggleIndicators
    keyword_init: true
  ) do
    def self.empty
      new(
        iterations: [],
        total_duration_ms: 0,
        struggle_indicators: StruggleIndicators.empty
      )
    end
  end

  # Persistent loop state
  RalphState = Struct.new(
    :active,              # Boolean
    :iteration,           # Integer
    :min_iterations,      # Integer
    :max_iterations,      # Integer
    :completion_promise,  # String
    :tasks_mode,          # Boolean
    :task_promise,        # String
    :prompt,              # String
    :started_at,          # String (ISO 8601)
    :model,               # String
    :agent,               # String
    keyword_init: true
  )

  # File snapshot for change detection
  FileSnapshot = Struct.new(:files, keyword_init: true) # files: Hash<String, String>
end
