module Ralph
  class Config
    attr_accessor(*%i[
      prompt
      min_iterations
      max_iterations
      completion_promise
      tasks_mode
      task_promise
      model
      agent_type
      auto_commit
      disable_plugins
      allow_all_permissions
      prompt_source
      stream_output
      verbose_tools
      prompt_file
    ])

    attr_reader(*%i[
      current_pid
      stopping
    ])

    # Returns a hash of options suitable for passing to Loop#call.
    # Excludes prompt_file (CLI-only) and runtime state (current_pid, stopping).
    def to_h
      %i[
        prompt
        min_iterations
        max_iterations
        completion_promise
        tasks_mode
        task_promise
        model
        agent_type
        auto_commit
        disable_plugins
        allow_all_permissions
        prompt_source
        stream_output
        verbose_tools
      ].map { |x| [x, send(x)] }.to_h
    end

    def initialize(
      prompt: "",
      min_iterations: 1,
      max_iterations: 0,
      completion_promise: "COMPLETE",
      tasks_mode: false,
      task_promise: "READY_FOR_NEXT_TASK",
      model: "",
      agent_type: "opencode",
      auto_commit: true,
      disable_plugins: false,
      allow_all_permissions: true,
      prompt_file: "",
      stream_output: true,
      verbose_tools: false,
      prompt_source: ""
    )
      @prompt                = prompt
      @min_iterations        = min_iterations
      @max_iterations        = max_iterations
      @completion_promise    = completion_promise
      @tasks_mode            = tasks_mode
      @task_promise          = task_promise
      @model                 = model
      @agent_type            = agent_type
      @auto_commit           = auto_commit
      @disable_plugins       = disable_plugins
      @allow_all_permissions = allow_all_permissions
      @prompt_file           = prompt_file
      @prompt_source         = prompt_source
      @stream_output         = stream_output
      @verbose_tools         = verbose_tools
      @current_pid           = nil
      @stopping              = false
    end
  end
end
