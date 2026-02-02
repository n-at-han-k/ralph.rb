# frozen_string_literal: true

module Ralph
  module Output
    class ActiveLoopError
      def self.call(existing_state, path:)
        $stderr.puts "Error: A Ralph loop is already active (iteration #{existing_state.iteration})"
        $stderr.puts "Started at: #{existing_state.started_at}"
        $stderr.puts "To cancel it, press Ctrl+C in its terminal or delete #{path}"
      end
    end
  end
end
