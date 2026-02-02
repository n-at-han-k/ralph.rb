# frozen_string_literal: true

module Ralph
  module Output
    class CompletionDetected
      extend ::Ralph::Helpers

      def self.call(loop_context)
        puts "\n╔#{'=' * 66}╗"
        puts "║  ✅ Completion promise detected: <promise>#{loop_context.config.completion_promise}</promise>"
        puts "║  Task completed in #{loop_context.state.iteration} iteration(s)"
        puts "║  Total time: #{format_duration_long(loop_context.history.total_duration_ms)}"
        puts "╚#{'=' * 66}╝"
      end
    end
  end
end
