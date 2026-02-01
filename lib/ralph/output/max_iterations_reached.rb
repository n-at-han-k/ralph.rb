# frozen_string_literal: true

module Ralph
  module Output
    class MaxIterationsReached
      extend ::Ralph::Helpers

      def self.call(max_iterations:, total_duration_ms:)
        puts "\n╔#{"=" * 66}╗"
        puts "║  Max iterations (#{max_iterations}) reached. Loop stopped."
        puts "║  Total time: #{format_duration_long(total_duration_ms)}"
        puts "╚#{"=" * 66}╝"
      end
    end
  end
end