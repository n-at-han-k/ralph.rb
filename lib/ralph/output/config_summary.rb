# frozen_string_literal: true

module Ralph
  module Output
    class ConfigSummary
      def self.call(prompt:, prompt_source:, completion_promise:, tasks_mode:, task_promise:, min_iterations:, max_iterations:, agent_name:, model:, disable_plugins:, agent_type:, allow_all:)
        prompt_preview = prompt.gsub(/\s+/, " ")[0, 80] + (prompt.length > 80 ? "..." : "")
        if prompt_source && !prompt_source.empty?
          puts "Task: #{prompt_source}"
          puts "Preview: #{prompt_preview}"
        else
          puts "Task: #{prompt_preview}"
        end
        puts "Completion promise: #{completion_promise}"
        if tasks_mode
          puts "Tasks mode: ENABLED"
          puts "Task promise: #{task_promise}"
        end
        puts "Min iterations: #{min_iterations}"
        puts "Max iterations: #{max_iterations > 0 ? max_iterations : "unlimited"}"
        puts "Agent: #{agent_name}"
        puts "Model: #{model}" if model && !model.empty?
        if disable_plugins && agent_type == :opencode
          puts "OpenCode plugins: non-auth plugins disabled"
        end
        puts "Permissions: auto-approve all tools" if allow_all
        puts ""
        puts "Starting loop... (Ctrl+C to stop)"
        puts "\u2550" * 68
      end
    end
  end
end