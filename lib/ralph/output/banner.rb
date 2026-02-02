# frozen_string_literal: true

module Ralph
  module Output
    class Banner
      def self.call(loop_context)
        puts <<~BANNER

          ╔#{'=' * 66}╗
          ║                    Ralph Wiggum Loop                            ║
          ║         Iterative AI Development with #{loop_context.agent.config_name.ljust(20)}        ║
          ╚#{'=' * 66}╝
        BANNER
      end
    end
  end
end
