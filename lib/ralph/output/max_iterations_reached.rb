# frozen_string_literal: true

module Ralph
  module Output
    class MaxIterationsReached
      def self.call(max_iterations:, total_duration_ms:)
        puts "\n\u2554#{"=" * 66}\u2557"
        puts "\u2551  Max iterations (#{max_iterations}) reached. Loop stopped."
        puts "\u2551  Total time: #{Helpers.format_duration_long(total_duration_ms)}"
        puts "\u255A#{"=" * 66}\u255D"
      end
    end
  end
end