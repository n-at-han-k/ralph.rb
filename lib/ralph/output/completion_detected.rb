# frozen_string_literal: true

require_relative "../helpers"

module Ralph
  module Output
    class CompletionDetected
      def self.call(completion_promise:, iteration:, total_duration_ms:)
        puts "\n\u2554#{"=" * 66}\u2557"
        puts "\u2551  \u2705 Completion promise detected: <promise>#{completion_promise}</promise>"
        puts "\u2551  Task completed in #{iteration} iteration(s)"
        puts "\u2551  Total time: #{Helpers.format_duration_long(total_duration_ms)}"
        puts "\u255A#{"=" * 66}\u255D"
      end
    end
  end
end