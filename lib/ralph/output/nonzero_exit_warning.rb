# frozen_string_literal: true

module Ralph
  module Output
    class NonzeroExitWarning
      def self.call(loop_context, result)
        warn "\n⚠️  #{loop_context.config.chosen_agent.config_name} exited with code #{result.exit_code}. Continuing to next iteration."
      end
    end
  end
end
