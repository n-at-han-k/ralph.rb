# frozen_string_literal: true

module Ralph
  module Output
    class Banner
      def self.call(agent_name:)
        puts <<~BANNER

          ╔#{"=" * 66}╗
          ║                    Ralph Wiggum Loop                            ║
          ║         Iterative AI Development with #{agent_name.ljust(20)}        ║
          ╚#{"=" * 66}╝
        BANNER
      end
    end
  end
end