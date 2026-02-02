# frozen_string_literal: true

module Ralph
  module Output
    class NonzeroExitWarning
      def self.call(agent:, exit_code:)
        warn "\n⚠️  #{agent.config_name} exited with code #{exit_code}. Continuing to next iteration."
      end
    end
  end
end
