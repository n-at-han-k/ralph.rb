# frozen_string_literal: true

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
    include ::Ralph::Helpers

    attr_reader :struggle_indicators
    attr_reader :snapshot_before, :snapshot_after

    def initialize(agent_config:, model:, options:)
      @agent_config = agent_config
      @model = model
      @options = options
      @struggle_indicators = { "repeated_errors" => {}, "no_progress_iterations" => 0, "short_iterations" => 0 }
    end

    def files_modified
      Git::FileSnapshot.modified_since(snapshot_before, snapshot_after)
    end

    def completion_detected
      check_completion(combined_output, @options[:completion_promise])
    end

    def result
    end

    def success?
      @exit_code == 0
    end

    def total_counts
      tool_counts = (
        if @result.tool_counts.is_a?(Hash)
          @result.tool_counts
        else
          @result.tool_counts.to_h
        end
      )
    end

    def execution
      @__execution__ ||= (
        @snapshot_before = Git::FileSnapshot.capture
        execute_agent(prompt, iteration_start)
        @snapshot_after = Git::FileSnapshot.capture
      )
    end

    def result = execution[0]
    def exit_code = execution[1]
    def combined_output
      "#{result.stdout_text}\n#{result.stderr_text}"
    end

    def call(prompt, iteration_start:)

      IterationResult.new(
        duration_ms: now_ms - iteration_start,
        exit_code: exit_code,
        stdout_text: result.stdout_text,
        stderr_text: result.stderr_text,
        tool_counts: tool_counts,
        files_modified: files_modified,
        completion_detected: completion_detected,
        errors: extract_errors(combined_output),
        success: success?
      ).tap do |iteration_result|
        update_struggle_indicators(iteration_result)
      end
      
    rescue StandardError => e
      IterationResult.new(
        duration_ms: now_ms - iteration_start,
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

    # Returns true when the agent appears to be stuck.
    # Should only be called after iteration > 2 for meaningful results.
    def struggling?
      @struggle_indicators["no_progress_iterations"] >= 3 ||
        @struggle_indicators["short_iterations"] >= 3
    end

    private

      def update_struggle_indicators(result)
        si = @struggle_indicators

        if result.files_modified.empty?
          si["no_progress_iterations"] += 1
        else
          si["no_progress_iterations"] = 0
        end

        if result.duration_ms < 30_000
          si["short_iterations"] += 1
        else
          si["short_iterations"] = 0
        end

        if result.errors.empty?
          si["repeated_errors"] = {}
        else
          result.errors.each do |error|
            key = error[0, 100]
            si["repeated_errors"][key] = (si["repeated_errors"][key] || 0) + 1
          end
        end
      end

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
