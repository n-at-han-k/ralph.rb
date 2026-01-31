# frozen_string_literal: true

module Ralph
  module Output
    class ContextConsumed
      def self.call
        puts "📝 Context was consumed this iteration"
      end
    end
  end
end