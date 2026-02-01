# frozen_string_literal: true

module Ralph
  module Output
    class CompletionDetected
      extend ::Ralph::Helpers

      def self.call(config:, iteration:, total_duration_ms:)
        puts "\n╔#{'=' * 66}╗"
        puts "║  ✅ Completion promise detected: <promise>#{config.completion_promise}</promise>"
        puts "║  Task completed in #{iteration} iteration(s)"
        puts "║  Total time: #{format_duration_long(total_duration_ms)}"
        puts "╚#{'=' * 66}╝"
      end
    end
  end
end
