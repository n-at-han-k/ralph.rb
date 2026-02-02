# frozen_string_literal: true

require "open3"

module Ralph
  module Agents
    class Base
      include ::Ralph::Helpers

      # Result of executing an agent process
      ExecutionResult = Struct.new(:stdout_text, :stderr_text, :tool_counts, :exit_code, keyword_init: true) do
        def combined_output
          "#{stdout_text}\n#{stderr_text}"
        end
      end

      def type        = raise NotImplementedError
      def command     = raise NotImplementedError
      def config_name = raise NotImplementedError

      def parse_tool_output(_line) = raise NotImplementedError
      def build_args(_prompt, _model, _options) = raise NotImplementedError

      def build_env(_options) = ENV.to_h.dup

      def execute(prompt, options = {})
        command_args = build_args(prompt, options[:model],
                                  { allow_all_permissions: options[:allow_all_permissions] })
        environment = build_env(
          filter_plugins: options[:disable_plugins],
          allow_all_permissions: options[:allow_all_permissions]
        )
        full_command = [command] + command_args

        if options[:stream_output]
          execute_streaming(environment, full_command, options[:on_line])
        else
          execute_captured(environment, full_command)
        end
      rescue StandardError => agent_error
        Agents::Base::ExecutionResult.new(
          stdout_text: "", stderr_text: agent_error.to_s, tool_counts: {}, exit_code: -1
        )
      end

      # Collects tool usage counts from output text.
      # Delegates to parse_tool_output for each line.
      def collect_tool_counts(text)
        Hash.new(0).tap do |counts|
          text.each_line do |line|
            tool = parse_tool_output(line)
            counts[tool] += 1 if tool
          end
        end
      end

      # Returns a fatal error message if one is detected in the output,
      # or nil if no fatal error is found. Subclasses may override.
      def detect_fatal_error(_output) = nil

      # Extracts error patterns from agent output. Subclasses may override
      # for agent-specific error formats.
      def extract_errors(output)
        errors = []
        output.each_line do |line|
          lower = line.downcase
          if lower.include?("error:") ||
             lower.include?("failed:") ||
             lower.include?("exception:") ||
             lower.include?("typeerror") ||
             lower.include?("syntaxerror") ||
             lower.include?("referenceerror") ||
             (lower.include?("test") && lower.include?("fail"))
            cleaned = line.strip[0, 200]
            errors << cleaned if cleaned && !cleaned.empty? && !errors.include?(cleaned)
          end
        end
        errors.first(10)
      end

      def validate!
        path = which(command)
        unless path
          $stderr.puts "Error: #{config_name} CLI ('#{command}') not found."
          exit 1
        end
      end

      private

        def execute_streaming(environment, full_command, on_line)
          tool_counts = Hash.new(0)
          stdout_text = +""
          stderr_text = +""
          mutex = Mutex.new

          stdin, stdout, stderr, wait_thread = Open3.popen3(environment, *full_command)
          stdin.close

          stdout_reader = Threads::StreamReader.new(
            stdout, stdout_text, mutex, tool_counts, on_line, false, method(:parse_tool_output)
          )
          stderr_reader = Threads::StreamReader.new(
            stderr, stderr_text, mutex, tool_counts, on_line, true, method(:parse_tool_output)
          )

          stdout_reader.join
          stderr_reader.join
          exit_status = wait_thread.value

          ExecutionResult.new(
            stdout_text: stdout_text,
            stderr_text: stderr_text,
            tool_counts: tool_counts,
            exit_code: exit_status.exitstatus || 1
          )
        end

        def execute_captured(environment, full_command)
          stdout, stderr, status = Open3.capture3(environment, *full_command, stdin_data: "")
          tool_counts = collect_tool_counts("#{stdout}\n#{stderr}")

          ExecutionResult.new(
            stdout_text: stdout,
            stderr_text: stderr,
            tool_counts: tool_counts,
            exit_code: status.exitstatus || 1
          )
        end
    end
  end
end
