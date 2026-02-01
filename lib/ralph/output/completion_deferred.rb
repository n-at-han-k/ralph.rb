# frozen_string_literal: true

module Ralph
  module Output
    class CompletionDeferred
      def self.call(config:, next_iteration:)
        puts "\n⏳ Completion promise detected, but minimum iterations (#{config.min_iterations}) not yet reached."
        puts "   Continuing to iteration #{next_iteration}..."
      end
    end
  end
end
