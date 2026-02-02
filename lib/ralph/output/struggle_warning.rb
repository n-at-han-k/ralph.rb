# frozen_string_literal: true

module Ralph
  module Output
    class StruggleWarning
      def self.call(loop_context)
        puts "\n⚠️  Potential struggle detected:"
        if loop_context.struggle_indicators[:no_progress_iterations] >= 3
          puts "   - No file changes in #{loop_context.struggle_indicators[:no_progress_iterations]} iterations"
        end
        if loop_context.struggle_indicators[:short_iterations] >= 3
          puts "   - #{loop_context.struggle_indicators[:short_iterations]} very short iterations"
        end
        puts "   💡 Tip: Use 'ralph --add-context \"hint\"' in another terminal to guide the agent"
      end
    end
  end
end