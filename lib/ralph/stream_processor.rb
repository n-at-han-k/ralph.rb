# frozen_string_literal: true

module Ralph
  module StreamProcessor
    extend ::Ralph::Helpers

    module_function

    # Result of streaming a process
    StreamResult = Struct.new(:stdout_text, :stderr_text, :tool_counts, keyword_init: true)

    # Stream process output with tool counting, compact summaries, and heartbeat
    #
    # @param cmd [Array<String>] command + args
    # @param env [Hash] environment variables
    # @param compact_tools [Boolean] use compact tool summary mode
    # @param tool_summary_interval_ms [Integer] ms between compact tool summary prints
    # @param heartbeat_interval_ms [Integer] ms between heartbeat prints
    # @param iteration_start [Integer] epoch ms when iteration started
    # @param agent [AgentConfig] agent config for tool parsing
    # @return [Array(StreamResult, Integer)] result and exit code
    def stream(cmd:, env:, compact_tools:, tool_summary_interval_ms:,
               heartbeat_interval_ms:, iteration_start:, agent:)
      tool_counts = Hash.new(0)
      stdout_text = +""
      stderr_text = +""
      mutex = Mutex.new
      last_printed_at = now_ms
      last_activity_at = now_ms
      last_tool_summary_at = 0

      maybe_print_tool_summary = lambda { |force|
        return unless compact_tools
        return if tool_counts.empty?
        now = now_ms
        return if !force && (now - last_tool_summary_at < tool_summary_interval_ms)
        summary = format_tool_summary(tool_counts)
        unless summary.empty?
          puts "| Tools    #{summary}"
          last_printed_at = now_ms
          last_tool_summary_at = now_ms
        end
      }

      line = lambda { |line, is_error|
        mutex.synchronize { last_activity_at = now_ms }
        tool = agent.parse_tool_output(line)
        if tool
          mutex.synchronize { tool_counts[tool] += 1 }
          if compact_tools
            mutex.synchronize { maybe_print_tool_summary.call(false) }
            next
          end
        end

        if line.empty?
          puts ""
          mutex.synchronize { last_printed_at = now_ms }
          next
        end

        if is_error
          $stderr.puts line
        else
          puts line
        end
        mutex.synchronize { last_printed_at = now_ms }
      }

      stdin, stdout, stderr, wait_thr = Open3.popen3(env, *cmd)
      stdin.close

      # Heartbeat thread
      heartbeat_thread = Thread.new do
        loop do
          sleep(heartbeat_interval_ms / 1000.0)
          now = now_ms
          lp = mutex.synchronize { last_printed_at }
          if now - lp >= heartbeat_interval_ms
            elapsed = format_duration(now - iteration_start)
            la = mutex.synchronize { last_activity_at }
            since_activity = format_duration(now - la)
            puts "⏳ working... elapsed #{elapsed} · last activity #{since_activity} ago"
            mutex.synchronize { last_printed_at = now_ms }
          end
        end
      rescue StandardError
        # thread cleanup
      end

      # Stdout reader thread
      stdout_thread = Thread.new do
        buffer = +""
        while (chunk = stdout.read(4096))
          stdout_text << chunk
          buffer << chunk
          while (idx = buffer.index("\n"))
            line = buffer.slice!(0, idx + 1).chomp
            line.call(line, false)
          end
        end
        # Flush remaining buffer
        line.call(buffer, false) unless buffer.empty?
      rescue IOError
        # stream closed
      end

      # Stderr reader thread
      stderr_thread = Thread.new do
        buffer = +""
        while (chunk = stderr.read(4096))
          stderr_text << chunk
          buffer << chunk
          while (idx = buffer.index("\n"))
            line = buffer.slice!(0, idx + 1).chomp
            line.call(line, true)
          end
        end
        line.call(buffer, true) unless buffer.empty?
      rescue IOError
        # stream closed
      end

      stdout_thread.join
      stderr_thread.join
      exit_status = wait_thr.value
      heartbeat_thread.kill

      mutex.synchronize { maybe_print_tool_summary.call(true) }

      result = StreamResult.new(
        stdout_text: stdout_text,
        stderr_text: stderr_text,
        tool_counts: tool_counts
      )
      [result, exit_status.exitstatus || 1]
    end

    # Non-streaming: run process and capture output
    def capture(cmd:, env:, agent:)
      stdout, stderr, status = Open3.capture3(env, *cmd, stdin_data: "")
      tool_counts = collect_tool_summary_from_text("#{stdout}\n#{stderr}", agent)
      result = StreamResult.new(
        stdout_text: stdout,
        stderr_text: stderr,
        tool_counts: tool_counts
      )
      [result, status.exitstatus || 1]
    end
  end
end
