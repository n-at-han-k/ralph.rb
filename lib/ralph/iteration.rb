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

  # Outcome wrapper returned by Iteration#run
  # Knows whether the iteration signifies completion (agent did NOT emit the
  # completion promise AND we are past min_iterations).
  IterationOutcome = Struct.new(
    :result,           # IterationResult
    :context_at_start, # Storage::Context snapshot taken before the iteration
    :state_iteration,  # Integer - which iteration number this was
    :min_iterations    # Integer - minimum iterations required by config
  ) do
    def complete?
      !result.completion_detected && state_iteration >= min_iterations
    end
  end

  class Iteration
    include ::Ralph::Helpers

    # Result of streaming/capturing a process
    StreamResult = Struct.new(:stdout_text, :stderr_text, :tool_counts, keyword_init: true)

    attr_reader :struggle_indicators

    def initialize(loop_context)
      @loop = loop_context
      @config = @loop.config
      @agent = @loop.agent
      @state = @loop.state
      @history = @loop.history
      @struggle_indicators = @loop.struggle_indicators

      # Streaming configuration
      @compact_tools = !@config.verbose_tools
      @tool_summary_interval_ms = 3000
      @heartbeat_interval_ms = 10_000

      @stream_tool_counts = Hash.new(0)
      @stream_stdout_text = +''
      @stream_stderr_text = +''
      @mutex = Mutex.new
      @last_printed_at = now_ms
      @last_activity_at = now_ms
      @last_tool_summary_at = 0
    end

    def iteration_start  = @_iteration_start ||= now_ms
    def context_at_start = @_context_at_start ||= Storage::Context.new
    def full_prompt      = @_full_promt ||= @loop.prompt.build_iteration(@state, @agent)

    # Runs a full iteration: builds prompt, executes agent, records history,
    # emits warnings, and returns an IterationOutcome.
    def run
      snapshot_before = Git::FileSnapshot.capture

      begin
        agent_result, exit_code = execute_agent(full_prompt, iteration_start)
      rescue StandardError => agent_error
        exit_code = -1
        agent_result = StreamResult.new(stdout_text: '', stderr_text: agent_error.to_s, tool_counts: {})
      end

      snapshot_after = Git::FileSnapshot.capture

      combined = "#{agent_result.stdout_text}\n#{agent_result.stderr_text}"
      tool_counts = agent_result.tool_counts.is_a?(Hash) ? agent_result.tool_counts : agent_result.tool_counts.to_h

      IterationResult.new(
        now_ms - iteration_start,
        exit_code,
        agent_result.stdout_text,
        agent_result.stderr_text,
        tool_counts,
        snapshot_before.modified_since(snapshot_after),
        check_completion(combined, @config.completion_promise),
        extract_errors(combined),
        exit_code == 0
      ).tap { |result| update_struggle_indicators(result) }.then do |result|
        Output::Iteration::Summary.call(@loop, result)

        @history.record(
          state_iteration: @state.iteration,
          iteration_start: iteration_start,
          result: result,
          struggle_indicators: @struggle_indicators
        )

        combined_output = "#{result.stdout_text}\n#{result.stderr_text}"


        warn_if_struggling(@state.iteration)
        detect_plugin_error!(combined_output)
        warn_nonzero_exit(result.exit_code)

        if task_completion_detected? && !result.completion_detected
          Output::TaskCompletion.call(config: @config, next_iteration: @start.iteration + 1)
        end

        IterationOutcome.new(result, context_at_start, @state.iteration, @config.min_iterations)
      end
    rescue StandardError => error
      handle_iteration_error(error, iteration_start || now_ms)
      nil
    end

    def task_completion_detected?
      if @config.tasks_mode
        check_completion(combined_output, @config.task_promise)
      else
        false
      end
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

    def warn_if_struggling(iteration_number)
      if iteration_number > 2 && struggling?
        Output::StruggleWarning.call(
          no_progress_iterations: @struggle_indicators['no_progress_iterations'],
          short_iterations: @struggle_indicators['short_iterations']
        )
      end
    end

    # ---------- Warnings and error detection ----------

    def detect_plugin_error!(combined_output)
      if @agent.type == :opencode && detect_placeholder_plugin_error(combined_output)
        Output::PluginError.call
        Storage::State.clear
        exit 1
      end
    end

    def warn_nonzero_exit(exit_code)
      unless exit_code == 0
        Output::NonzeroExitWarning.call(agent: @agent, exit_code: exit_code)
      end
    end

    def handle_iteration_error(error, iteration_start)
      if @config.current_pid
        begin
          Process.kill('TERM', @config.current_pid)
        rescue StandardError
          # process may have exited
        end
        @config.current_pid = nil
      end

      Output::Iteration::Error.call(@loop, error)

      @loop.history.record_error(
        state_iteration: @loop.state.iteration,
        iteration_start: iteration_start,
        error: error
      )

      @loop.advance_iteration
      sleep 2
    end

    # ---------- Agent execution ----------

    def execute_agent(prompt, iteration_start)
      command_args = @agent.build_args(prompt, @config.model,
                                              { allow_all_permissions: @config.allow_all_permissions })
      environment = @agent.build_env(
        filter_plugins: @config.disable_plugins,
        allow_all_permissions: @config.allow_all_permissions
      )
      command = [@agent.command] + command_args

      if @config.stream_output
        stream_agent(command: command, environment: environment, iteration_start: iteration_start)
      else
        capture_agent(command: command, environment: environment)
      end
    end

    def stream_agent(command:, environment:, iteration_start:)
      stdin, stdout, stderr, wait_thread = Open3.popen3(environment, *command)
      stdin.close

      heartbeat = heartbeat_thread(iteration_start)
      stdout_reader = stdout_reader_thread(stdout)
      stderr_reader = stderr_reader_thread(stderr)

      stdout_reader.join
      stderr_reader.join
      exit_status = wait_thread.value
      heartbeat.kill

      @mutex.synchronize { maybe_print_tool_summary(force: true) }

      StreamResult.new(
        stdout_text: @stream_stdout_text,
        stderr_text: @stream_stderr_text,
        tool_counts: @stream_tool_counts
      ).then { |stream_result| [stream_result, exit_status.exitstatus || 1] }
    end

    def maybe_print_tool_summary(force: false)
      if @compact_tools && @stream_tool_counts.any?
        now = now_ms
        if force || (now - @last_tool_summary_at >= @tool_summary_interval_ms)
          format_tool_summary(@stream_tool_counts).then do |summary|
            unless summary.empty?
              puts "| Tools    #{summary}"
              @last_printed_at = now_ms
              @last_tool_summary_at = now_ms
            end
          end
        end
      end
    end

    def handle_line(line, is_error)
      @mutex.synchronize { @last_activity_at = now_ms }
      tool = @agent.parse_tool_output(line)

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
        @mutex.synchronize { @last_printed_at = now_ms }
      end
    end

    def heartbeat_thread(iteration_start)
      Thread.new do
        loop do
          sleep(@heartbeat_interval_ms / 1000.0)
          now = now_ms
          last_printed = @mutex.synchronize { @last_printed_at }
          if now - last_printed >= @heartbeat_interval_ms
            elapsed = format_duration(now - iteration_start)
            last_activity = @mutex.synchronize { @last_activity_at }
            since_activity = format_duration(now - last_activity)
            puts "⏳ working... elapsed #{elapsed} · last activity #{since_activity} ago"
            @mutex.synchronize { @last_printed_at = now_ms }
          end
        end
      rescue StandardError
        # thread cleanup
      end
    end

    def stdout_reader_thread(stdout_io)
      Thread.new do
        buffer = +''
        while (chunk = stdout_io.read(4096))
          @stream_stdout_text << chunk
          buffer << chunk
          while (index = buffer.index("\n"))
            line = buffer.slice!(0, index + 1).chomp
            handle_line(line, false)
          end
        end
        handle_line(buffer, false) unless buffer.empty?
      rescue IOError
        # stream closed
      end
    end

    def stderr_reader_thread(stderr_io)
      Thread.new do
        buffer = +''
        while (chunk = stderr_io.read(4096))
          @stream_stderr_text << chunk
          buffer << chunk
          while (index = buffer.index("\n"))
            line = buffer.slice!(0, index + 1).chomp
            handle_line(line, true)
          end
        end
        handle_line(buffer, true) unless buffer.empty?
      rescue IOError
        # stream closed
      end
    end

    def capture_agent(command:, environment:)
      stdout, stderr, status = Open3.capture3(environment, *command, stdin_data: '')
      tool_counts = collect_tool_summary_from_text("#{stdout}\n#{stderr}", @agent)
      StreamResult.new(
        stdout_text: stdout,
        stderr_text: stderr,
        tool_counts: tool_counts
      ).tap do |stream_result|
        warn stream_result.stderr_text unless stream_result.stderr_text.empty?
        puts stream_result.stdout_text
      end.then { |stream_result| [stream_result, status.exitstatus || 1] }
    end
  end
end
