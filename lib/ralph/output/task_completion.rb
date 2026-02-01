# frozen_string_literal: true

module Ralph
  module Output
    class TaskCompletion
      def self.call(config:, next_iteration:)
        puts "\n🔄 Task completion detected: <promise>#{config.task_promise}</promise>"
        puts "   Moving to next task in iteration #{next_iteration}..."
      end
    end
  end
end
