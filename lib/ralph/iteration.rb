# frozen_string_literal: true

require_relative "helpers"
require_relative "stream_processor"
require_relative "state"

module Ralph
  # Result object for a single iteration execution
  IterationResult = Struct.new(
    :duration_ms,        # Integer - execution duration in milliseconds
    :exit_code,          # Integer - agent process exit code
    :stdout_text,        # String - agent stdout output
    :stderr_text,        # String - agent stderr output
    :tool_counts,        # Hash<String, Integer> - tool usage counts
    :files_modified,     # Array<String> - list of files changed during iteration
    :completion_detected, # Boolean - whether completion promise was found
    :errors,             # Array<String> - extracted errors from output
    :success             # Boolean - overall success (no crashes, exit_code == 0)
  )

  class Iteration
    def initialize(agent_config:, model:, options:)
      @agent_config = agent_config
      @model = model
      @options = options
    end

    def call(prompt, iteration_start:)
      snapshot_before = State.capture_file_snapshot

      result, exit_code = execute_agent(prompt, iteration_start)
      combined_output = "#{result.stdout_text}\n#{result.stderr_text}"
      iteration_duration = Helpers.now_ms - iteration_start

      snapshot_after = State.capture_file_snapshot
      files_modified = State.modified_files_since_snapshot(snapshot_before, snapshot_after)
      
      tool_counts = result.tool_counts.is_a?(Hash) ? result.tool_counts : result.tool_counts.to_h
      
      # Extract completion and error information
      completion_detected = Helpers.check_completion(combined_output, @options[:completion_promise])
      errors = Helpers.extract_errors(combined_output)
      
      # Determine overall success
      success = exit_code == 0

      IterationResult.new(
        duration_ms: iteration_duration,
        exit_code: exit_code,
        stdout_text: result.stdout_text,
        stderr_text: result.stderr_text,
        tool_counts: tool_counts,
        files_modified: files_modified,
        completion_detected: completion_detected,
        errors: errors,
        success: success
      )
    rescue StandardError => e
      # Return error result if something goes wrong
      iteration_duration = Helpers.now_ms - iteration_start
      IterationResult.new(
        duration_ms: iteration_duration,
        exit_code: -1,
        stdout_text: "",
        stderr_text: e.to_s,
        tool_counts: {},
        files_modified: [],
        completion_detected: false,
        errors: [e.to_s],
        success: false
      )
    end

    private

    def execute_agent(prompt, iteration_start)
      cmd_args = @agent_config.build_args.call(prompt, @model, { allow_all_permissions: @options[:allow_all_permissions] })
      env = @agent_config.build_env.call(
        filter_plugins: @options[:disable_plugins],
        allow_all_permissions: @options[:allow_all_permissions]
      )
      cmd = [@agent_config.command] + cmd_args

      if @options[:stream_output]
        StreamProcessor.stream(
          cmd: cmd,
          env: env,
          compact_tools: !@options[:verbose_tools],
          tool_summary_interval_ms: 3000,
          heartbeat_interval_ms: 10000,
          iteration_start: iteration_start,
          agent: @agent_config
        )
      else
        result, exit_code = StreamProcessor.capture(cmd: cmd, env: env, agent: @agent_config)
        $stderr.puts result.stderr_text unless result.stderr_text.empty?
        puts result.stdout_text
        [result, exit_code]
      end
    end
  end
end
