# frozen_string_literal: true

module Ralph
  module Output
    class NonzeroExitWarning
      def self.call(agent_name:, exit_code:)
        warn "\n⚠️  #{agent_name} exited with code #{exit_code}. Continuing to next iteration."
      end
    end
  end
end