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

    # Result of streaming/capturing a process
    StreamResult = Struct.new(:stdout_text, :stderr_text, :tool_counts, keyword_init: true)

    attr_reader :struggle_indicators

    def initialize(agent_config:, model:, options:)
      @agent_config = agent_config
      @model = model
      @options = options
      @struggle_indicators = { 'repeated_errors' => {}, 'no_progress_iterations' => 0, 'short_iterations' => 0 }

      # used in #stream_agent()
      @compact_tools = !@options[:verbose_tools]
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

    def call(prompt, iteration_start:)
      snapshot_before = Git::FileSnapshot.capture
      result, exit_code = execute_agent(prompt, iteration_start)
      snapshot_after = Git::FileSnapshot.capture

      combined = "#{result.stdout_text}\n#{result.stderr_text}"
      tool_counts = result.tool_counts.is_a?(Hash) ? result.tool_counts : result.tool_counts.to_h

      IterationResult.new(
        duration_ms: now_ms - iteration_start,
        exit_code: exit_code,
        stdout_text: result.stdout_text,
        stderr_text: result.stderr_text,
        tool_counts: tool_counts,
        files_modified: snapshot_before.modified_since(snapshot_after),
        completion_detected: check_completion(combined, @options[:completion_promise]),
        errors: extract_errors(combined),
        success: exit_code == 0
      ).tap { |ir| update_struggle_indicators(ir) }

    rescue StandardError => e
      IterationResult.new(
        duration_ms: now_ms - iteration_start,
        exit_code: -1,
        stdout_text: '',
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
      @struggle_indicators['no_progress_iterations'] >= 3 ||
        @struggle_indicators['short_iterations'] >= 3
    end

    private

    def update_struggle_indicators(result)
      si = @struggle_indicators

      if result.files_modified.empty?
        si['no_progress_iterations'] += 1
      else
        si['no_progress_iterations'] = 0
      end

      if result.duration_ms < 30_000
        si['short_iterations'] += 1
      else
        si['short_iterations'] = 0
      end

      if result.errors.empty?
        si['repeated_errors'] = {}
      else
        result.errors.each do |error|
          key = error[0, 100]
          si['repeated_errors'][key] = (si['repeated_errors'][key] || 0) + 1
        end
      end
    end

    def execute_agent(prompt, iteration_start)
      cmd_args = @agent_config.build_args(prompt, @model, { allow_all_permissions: @options[:allow_all_permissions] })
      env = @agent_config.build_env(
        filter_plugins: @options[:disable_plugins],
        allow_all_permissions: @options[:allow_all_permissions]
      )
      cmd = [@agent_config.command] + cmd_args

      if @options[:stream_output]
        stream_agent(cmd: cmd, env: env, iteration_start: iteration_start)
      else
        capture_agent(cmd: cmd, env: env)
      end
    end

    def stream_agent(cmd:, env:, iteration_start:)
      stdin, stdout, stderr, wait_thr = Open3.popen3(env, *cmd)
      stdin.close

      ht = heartbeat_thread(iteration_start)
      out_t = stdout_reader_thread(stdout)
      err_t = stderr_reader_thread(stderr)

      out_t.join
      err_t.join
      exit_status = wait_thr.value
      ht.kill

      @mutex.synchronize { maybe_print_tool_summary(force: true) }

      StreamResult.new(
        stdout_text: @stream_stdout_text,
        stderr_text: @stream_stderr_text,
        tool_counts: @stream_tool_counts
      ).then { |result| [result, exit_status.exitstatus || 1] }
    end

    def maybe_print_tool_summary(force: false)
      return unless @compact_tools
      return if @stream_tool_counts.empty?

      now = now_ms
      return if !force && (now - @last_tool_summary_at < @tool_summary_interval_ms)

      summary = format_tool_summary(@stream_tool_counts)
      return if summary.empty?

      puts "| Tools    #{summary}"
      @last_printed_at = now_ms
      @last_tool_summary_at = now_ms
    end

    def handle_line(line, is_error)
      @mutex.synchronize { @last_activity_at = now_ms }
      tool = @agent_config.parse_tool_output(line)
      if tool
        @mutex.synchronize { @stream_tool_counts[tool] += 1 }
        if @compact_tools
          @mutex.synchronize { maybe_print_tool_summary }
          return
        end
      end

      if line.empty?
        puts ''
        @mutex.synchronize { @last_printed_at = now_ms }
        return
      end

      if is_error
        warn line
      else
        puts line
      end
      @mutex.synchronize { @last_printed_at = now_ms }
    end

    def heartbeat_thread(iteration_start)
      @__heartbeat_thread__ ||= Thread.new do
        loop do
          sleep(@heartbeat_interval_ms / 1000.0)
          now = now_ms
          lp = @mutex.synchronize { @last_printed_at }
          next unless now - lp >= @heartbeat_interval_ms

          elapsed = format_duration(now - iteration_start)
          la = @mutex.synchronize { @last_activity_at }
          since_activity = format_duration(now - la)
          puts "⏳ working... elapsed #{elapsed} · last activity #{since_activity} ago"
          @mutex.synchronize { @last_printed_at = now_ms }
        end
      rescue StandardError
        # thread cleanup
      end
    end

    def stdout_reader_thread(stdout_io)
      @__stdout_reader_thread__ ||= Thread.new do
        buffer = +''
        while (chunk = stdout_io.read(4096))
          @stream_stdout_text << chunk
          buffer << chunk
          while (idx = buffer.index("\n"))
            l = buffer.slice!(0, idx + 1).chomp
            handle_line(l, false)
          end
        end
        handle_line(buffer, false) unless buffer.empty?
      rescue IOError
        # stream closed
      end
    end

    def stderr_reader_thread(stderr_io)
      @__stderr_reader_thread__ ||= Thread.new do
        buffer = +''
        while (chunk = stderr_io.read(4096))
          @stream_stderr_text << chunk
          buffer << chunk
          while (idx = buffer.index("\n"))
            l = buffer.slice!(0, idx + 1).chomp
            handle_line(l, true)
          end
        end
        handle_line(buffer, true) unless buffer.empty?
      rescue IOError
        # stream closed
      end
    end

    def capture_agent(cmd:, env:)
      stdout, stderr, status = Open3.capture3(env, *cmd, stdin_data: '')
      tool_counts = collect_tool_summary_from_text("#{stdout}\n#{stderr}", @agent_config)
      result = StreamResult.new(
        stdout_text: stdout,
        stderr_text: stderr,
        tool_counts: tool_counts
      )
      warn result.stderr_text unless result.stderr_text.empty?
      puts result.stdout_text
      [result, status.exitstatus || 1]
    end
  end
end
