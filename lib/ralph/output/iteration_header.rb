# frozen_string_literal: true

module Ralph
  module Output
    class IterationHeader
      def self.call(iteration:, max_iterations:, min_iterations:)
        iter_info = max_iterations > 0 ? " / #{max_iterations}" : ""
        min_info = min_iterations > 1 && iteration < min_iterations ? " (min: #{min_iterations})" : ""
        puts "\n\u{1F504} Iteration #{iteration}#{iter_info}#{min_info}"
        puts "\u2500" * 68
      end
    end
  end
end