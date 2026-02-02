# frozen_string_literal: true

module Ralph
  module Agents
    class ClaudeCode < Base

      def type = :claude_code
      def command = "claude"
      def config_name = "Claude Code"

      def build_args(prompt, model, options)
        args = ["-p", prompt]
        args.push("--model", model) if model && !model.empty?
        args.push("--dangerously-skip-permissions") if options && options[:allow_all_permissions]
        args
      end

      def parse_tool_output(line)
        match = strip_ansi(line).match(/(?:Using|Called|Tool:)\s+([A-Za-z0-9_-]+)/i)
        match ? match[1] : nil
      end
    end
  end
end
