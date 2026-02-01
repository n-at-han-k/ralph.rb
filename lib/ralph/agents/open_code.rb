# frozen_string_literal: true

module Ralph
  module Agents
    class OpenCode < Base
      def type
        :opencode
      end

      def command
        "opencode"
      end

      def config_name
        "OpenCode"
      end

      def build_args(prompt, model, _options)
        args = ["run"]
        args.push("-m", model) if model && !model.empty?
        args.push(prompt)
        args
      end

      def parse_tool_output(line)
        match = strip_ansi(line).match(/^\|\s{2}([A-Za-z0-9_-]+)/)
        match ? match[1] : nil
      end
    end
  end
end
