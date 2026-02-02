# frozen_string_literal: true

module Ralph
  module Output
    module Iteration
      class Header
        def self.call(loop_context)
          config = loop_context.config
          iteration = loop_context.state.iteration

          iter_info = config.max_iterations > 0 ? " / #{config.max_iterations}" : ''
          min_info = config.min_iterations > 1 && iteration < config.min_iterations ? " (min: #{config.min_iterations})" : ''
          puts "\n🔄 Iteration #{iteration}#{iter_info}#{min_info}"
          puts '─' * 68
        end
      end

      class Summary
        extend ::Ralph::Helpers

        def self.call(loop_context, result)
          tool_summary = format_tool_summary(result.tool_counts)
          puts "\nIteration Summary"
          puts "─" * 68
          puts "Iteration: #{loop_context.state.iteration}"
          puts "Elapsed:   #{format_duration(result.duration_ms)}"
          if tool_summary && !tool_summary.empty?
            puts "Tools:     #{tool_summary}"
          else
            puts "Tools:     none"
          end
          puts "Exit code: #{result.exit_code}"
          puts "Completion promise: #{result.completion_detected ? "detected" : "not detected"}"
        end
      end

      class Error
        def self.call(loop_context, error)
          $stderr.puts "\n❌ Error in iteration #{loop_context.state.iteration}: #{error}"
          puts "Continuing to next iteration..."
        end
      end
    end
  end
end
