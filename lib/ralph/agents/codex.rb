# frozen_string_literal: true

module Ralph
  module Agents
    class Codex < Base

      def type = :codex
      def command = "codex"
      def config_name = "Codex"

      def build_args(prompt, model, options)
        args = ["exec"]
        args.push("--model", model) if model && !model.empty?
        args.push("--full-auto") if options && options[:allow_all_permissions]
        args.push(prompt)
        args
      end

      def parse_tool_output(line)
        match = strip_ansi(line).match(/(?:Tool:|Using|Calling|Running)\s+([A-Za-z0-9_-]+)/i)
        match ? match[1] : nil
      end
    end
  end
end
