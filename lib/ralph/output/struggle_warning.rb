# frozen_string_literal: true

module Ralph
  module Output
    class StruggleWarning
      def self.call(no_progress_iterations:, short_iterations:)
        puts "\n\u26A0\uFE0F  Potential struggle detected:"
        if no_progress_iterations >= 3
          puts "   - No file changes in #{no_progress_iterations} iterations"
        end
        if short_iterations >= 3
          puts "   - #{short_iterations} very short iterations"
        end
        puts "   \u{1F4A1} Tip: Use 'ralph --add-context \"hint\"' in another terminal to guide the agent"
      end
    end
  end
end