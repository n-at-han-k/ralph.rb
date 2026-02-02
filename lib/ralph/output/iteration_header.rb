# frozen_string_literal: true

module Ralph
  module Output
    class IterationHeader
      def self.call(loop_context)
        config = loop_context.config
        iteration = loop_context.state.iteration

        iter_info = config.max_iterations > 0 ? " / #{config.max_iterations}" : ''
        min_info = config.min_iterations > 1 && iteration < config.min_iterations ? " (min: #{config.min_iterations})" : ''
        puts "\n🔄 Iteration #{iteration}#{iter_info}#{min_info}"
        puts '─' * 68
      end
    end
  end
end
