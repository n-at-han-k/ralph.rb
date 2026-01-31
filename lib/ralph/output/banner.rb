# frozen_string_literal: true

module Ralph
  module Output
    class Banner
      def self.call(agent_name:)
        puts <<~BANNER

          \u2554#{"=" * 66}\u2557
          \u2551                    Ralph Wiggum Loop                            \u2551
          \u2551         Iterative AI Development with #{agent_name.ljust(20)}        \u2551
          \u255A#{"=" * 66}\u255D
        BANNER
      end
    end
  end
end