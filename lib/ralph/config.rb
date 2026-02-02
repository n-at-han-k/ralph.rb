module Ralph
  class Config
    # Single source of truth for config option names and their defaults.
    # Use a lambda for mutable defaults to avoid shared state.
    OPTIONS = {
      prompt:                -> { PromptTemplate.new("") },
      min_iterations:        1,
      max_iterations:        0,
      completion_promise:    "COMPLETE",
      tasks_mode:            false,
      task_promise:          "READY_FOR_NEXT_TASK",
      model:                 "",
      agent_type:            "opencode",
      disable_plugins:       false,
      allow_all_permissions: true,
      stream_output:         true,
      verbose_tools:         false,
    }.freeze

    # Keys present as attr_accessors but excluded from to_h (CLI-only concerns).
    EXCLUDED_FROM_HASH = %i[prompt_file].freeze

    attr_accessor(*OPTIONS.keys, *EXCLUDED_FROM_HASH)

    # Runtime state (not constructor args, not in to_h).
    attr_accessor :current_pid, :stopping

    def initialize(**opts)
      OPTIONS.each do |key, default|
        value = opts.fetch(key) { default.respond_to?(:call) ? default.call : default }
        instance_variable_set(:"@#{key}", value)
      end
      @prompt_file = opts.fetch(:prompt_file, "")
      @current_pid = nil
      @stopping    = false
    end

    # Returns a hash of options suitable for passing to Loop#call.
    # Excludes prompt_file (CLI-only) and runtime state (current_pid, stopping).
    def to_h
      (OPTIONS.keys - EXCLUDED_FROM_HASH).map { |k| [k, send(k)] }.to_h
    end
  end
end
