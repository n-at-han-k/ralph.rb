# frozen_string_literal: true

module Ralph
  class Iteration
    # Statuses:
    #   :completed  — completion promise detected, iteration succeeded
    #   :continuing — no completion detected, keep looping
    #   :failed     — non-zero exit code from the agent process
    #   :fatal      — fatal error detected in agent output (unrecoverable)
    #   :error      — iteration raised an exception
    class Result
      STATUSES = %i[completed continuing failed fatal error].freeze

      attr_reader :status, :agent_result, :duration_ms, :files_modified, :completion_detected, :errors

      def initialize(status:, agent_result:, duration_ms:, files_modified:, completion_detected:, errors:)
        @status = status
        @agent_result = agent_result
        @duration_ms = duration_ms
        @files_modified = files_modified
        @completion_detected = completion_detected
        @errors = errors
      end

      def exit_code       = agent_result&.exit_code
      def stdout_text     = agent_result&.stdout_text || ""
      def stderr_text     = agent_result&.stderr_text || ""
      def tool_counts     = agent_result&.tool_counts || {}
      def combined_output = agent_result&.combined_output || ""

      def completed?  = status == :completed
      def continuing? = status == :continuing
      def failed?     = status == :failed
      def fatal?      = status == :fatal
      def error?      = status == :error
    end

    include ::Ralph::Helpers

    attr_reader :struggle_indicators, :iteration_start

    def initialize(loop_context)
      @loop = loop_context
      @config = @loop.config
      @agent = @loop.agent
      @state = @loop.state
      @struggle_indicators = @loop.struggle_indicators

      # Streaming configuration
      @compact_tools = !@config.verbose_tools
      @tool_summary_interval_ms = 3000
      @heartbeat_interval_ms = 10_000

      @stream_tool_counts = Hash.new(0)
      @mutex = Mutex.new
      @timing = { last_printed_at: now_ms, last_activity_at: now_ms }
      @last_tool_summary_at = 0

      @iteration_start = now_ms
    end

    def context_at_start = @_context_at_start ||= @loop.context

    def run
      snapshot_before = Git::FileSnapshot.capture

      if @config.stream_output
        heartbeat = Threads::Heartbeat.new(iteration_start, @heartbeat_interval_ms, @timing, @mutex)
      end

      @agent.execute(
        @loop.prompt.build_iteration(@state, @agent),
        on_line:               method(:handle_line),
        model:                 @config.model,
        stream_output:         @config.stream_output,
        disable_plugins:       @config.disable_plugins,
        allow_all_permissions: @config.allow_all_permissions,

      ).then do |agent_result|

        heartbeat&.stop

        if @config.stream_output
          @mutex.synchronize { maybe_print_tool_summary(force: true) }
        end

        unless @config.stream_output
          if agent_result
            warn agent_result.stderr_text unless agent_result.stderr_text.empty?
            puts agent_result.stdout_text
          end
        end
      end

      snapshot_after = Git::FileSnapshot.capture

      combined_output = agent_result.combined_output
      completion_detected = check_completion(combined_output, @config.completion_promise)
      fatal_error = @agent.detect_fatal_error(combined_output)

      status = (
        if fatal_error
          :fatal
        elsif agent_result.exit_code != 0
          :failed
        elsif completion_detected
          :completed
        else
          :continuing
        end
      )

      Result.new(
        status: status,
        agent_result: agent_result,
        duration_ms: now_ms - iteration_start,
        files_modified: snapshot_before.modified_since(snapshot_after),
        completion_detected: completion_detected,
        errors: @agent.extract_errors(combined_output)
      ).tap do |result|
        update_struggle_indicators(result)
      end
    rescue StandardError => error
      if @config.current_pid
        begin
          Process.kill('TERM', @config.current_pid)
        rescue StandardError
          # process may have exited
        end
        @config.current_pid = nil
      end

      Output::Iteration::Error.call(@loop, error)

      sleep 2

      Result.new(
        status: :error,
        agent_result: nil,
        duration_ms: now_ms - (iteration_start || now_ms), # this is so fucking wrong
        files_modified: [],
        completion_detected: false,
        errors: [error.message]
      )
    end

    # ---------- Warnings and error detection ----------

    def handle_iteration_error(error, iteration_start)
    end

    # Returns true when the agent appears to be stuck.
    # Should only be called after iteration > 2 for meaningful results.
    def struggling?
      @struggle_indicators['no_progress_iterations'] >= 3 ||
        @struggle_indicators['short_iterations'] >= 3
    end

    private

    # ---------- Struggle tracking ----------

    def update_struggle_indicators(result)
      if result.files_modified.empty?
        @struggle_indicators['no_progress_iterations'] += 1
      else
        @struggle_indicators['no_progress_iterations'] = 0
      end

      if result.duration_ms < 30_000
        @struggle_indicators['short_iterations'] += 1
      else
        @struggle_indicators['short_iterations'] = 0
      end

      if result.errors.empty?
        @struggle_indicators['repeated_errors'] = {}
      else
        result.errors.each do |error|
          key = error[0, 100]
          @struggle_indicators['repeated_errors'][key] = (@struggle_indicators['repeated_errors'][key] || 0) + 1
        end
      end
    end

    # ---------- Agent execution ----------

    def maybe_print_tool_summary(force: false)
      if @compact_tools && @stream_tool_counts.any?
        now = now_ms
        if force || (now - @last_tool_summary_at >= @tool_summary_interval_ms)
          format_tool_summary(@stream_tool_counts).then do |summary|
            unless summary.empty?
              puts "| Tools    #{summary}"
              @timing[:last_printed_at] = now_ms
              @last_tool_summary_at = now_ms
            end
          end
        end
      end
    end

    def handle_line(line, is_error, tool)
      @mutex.synchronize { @timing[:last_activity_at] = now_ms }

      @mutex.synchronize { @stream_tool_counts[tool] += 1 } if tool

      if tool && @compact_tools
        @mutex.synchronize { maybe_print_tool_summary }
      else
        if line.empty?
          puts ''
        elsif is_error
          warn line
        else
          puts line
        end
        @mutex.synchronize { @timing[:last_printed_at] = now_ms }
      end
    end
  end
end
