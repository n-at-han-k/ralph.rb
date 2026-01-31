module Ralph
  module Output
    class ActiveLoopStatus
      def self.call(state:)
        elapsed = Helpers.now_ms - (Time.parse(state.started_at).to_f * 1000).to_i
        elapsed_str = Helpers.format_duration_long(elapsed)
        puts "🔄 ACTIVE LOOP"
        max_str = state.max_iterations > 0 ? " / #{state.max_iterations}" : " (unlimited)"
        puts "   Iteration:    #{state.iteration}#{max_str}"
        puts "   Started:      #{state.started_at}"
        puts "   Elapsed:      #{elapsed_str}"
        puts "   Promise:      #{state.completion_promise}"
        agent_label = if state.agent
          cfg = Agents.resolve(state.agent)
          cfg ? cfg.config_name : state.agent
        else
          "OpenCode"
        end
        puts "   Agent:        #{agent_label}"
        puts "   Model:        #{state.model}" if state.model && !state.model.empty?
        if state.tasks_mode
          puts "   Tasks Mode:   ENABLED"
          puts "   Task Promise: #{state.task_promise}"
        end
        prompt_preview = state.prompt[0, 60] + (state.prompt.length > 60 ? "..." : "")
        puts "   Prompt:       #{prompt_preview}"
      end
    end
  end
end