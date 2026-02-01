# frozen_string_literal: true

module Ralph
  module Output
    class IterationSummary
      extend Helpers

      def self.call(iteration:, elapsed_ms:, tool_counts:, exit_code:, completion_detected:)
        tool_summary = format_tool_summary(tool_counts)
        puts "\nIteration Summary"
        puts "─" * 68
        puts "Iteration: #{iteration}"
        puts "Elapsed:   #{format_duration(elapsed_ms)}"
        if tool_summary && !tool_summary.empty?
          puts "Tools:     #{tool_summary}"
        else
          puts "Tools:     none"
        end
        puts "Exit code: #{exit_code}"
        puts "Completion promise: #{completion_detected ? "detected" : "not detected"}"
      end
    end
  end
end