# frozen_string_literal: true

module Ralph
  module Output
    class TaskCompletion
      def self.call(task_promise:, next_iteration:)
        puts "\n\u{1F504} Task completion detected: <promise>#{task_promise}</promise>"
        puts "   Moving to next task in iteration #{next_iteration}..."
      end
    end
  end
end