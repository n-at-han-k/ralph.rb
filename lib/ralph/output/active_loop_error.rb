# frozen_string_literal: true

module Ralph
  module Output
    class ActiveLoopError
      def self.call(iteration:, started_at:, state_path:)
        $stderr.puts "Error: A Ralph loop is already active (iteration #{iteration})"
        $stderr.puts "Started at: #{started_at}"
        $stderr.puts "To cancel it, press Ctrl+C in its terminal or delete #{state_path}"
      end
    end
  end
end