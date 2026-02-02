# frozen_string_literal: true

module Ralph
  module Output
    class MaxIterationsReached
      extend ::Ralph::Helpers

      def self.call(loop_context)
        puts "\n╔#{'=' * 66}╗"
        puts "║  Max iterations (#{loop_context.config.max_iterations}) reached. Loop stopped."
        puts "║  Total time: #{format_duration_long(loop_context.history.total_duration_ms)}"
        puts "╚#{'=' * 66}╝"
      end
    end
  end
end
