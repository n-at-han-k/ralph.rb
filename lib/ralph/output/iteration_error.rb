# frozen_string_literal: true

module Ralph
  module Output
    class IterationError
      def self.call(iteration:, error:)
        $stderr.puts "\n❌ Error in iteration #{iteration}: #{error}"
        puts "Continuing to next iteration..."
      end
    end
  end
end