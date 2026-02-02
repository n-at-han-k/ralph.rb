# frozen_string_literal: true

module Ralph
  module Output
    class TaskCompletion
      def self.call(loop_context)
        puts "\n🔄 Task completion detected: <promise>#{loop_context.config.task_promise}</promise>"
        puts "   Moving to next task in iteration #{loop_context.state.iteration + 1}..."
      end
    end
  end
end
