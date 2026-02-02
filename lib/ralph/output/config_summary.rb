# frozen_string_literal: true

module Ralph
  module Output
    class ConfigSummary
      def self.call(loop_context)
        config = loop_context.config
        agent = loop_context.agent
        prompt = loop_context.prompt

        prompt_text = prompt.to_s
        prompt_preview = prompt_text.gsub(/\s+/, ' ')[0, 80] + (prompt_text.length > 80 ? '...' : '')
        puts "Task: #{prompt_preview}"
        puts "Completion promise: #{config.completion_promise}"
        if config.tasks_mode
          puts 'Tasks mode: ENABLED'
          puts "Task promise: #{config.task_promise}"
        end
        puts "Min iterations: #{config.min_iterations}"
        puts "Max iterations: #{config.max_iterations > 0 ? config.max_iterations : 'unlimited'}"
        puts "Agent: #{agent.config_name}"
        puts "Model: #{config.model}" if config.model && !config.model.empty?
        puts 'OpenCode plugins: non-auth plugins disabled' if config.disable_plugins && agent.type == :opencode
        puts 'Permissions: auto-approve all tools' if config.allow_all_permissions
        puts ''
        puts 'Starting loop... (Ctrl+C to stop)'
        puts '═' * 68
      end
    end
  end
end
