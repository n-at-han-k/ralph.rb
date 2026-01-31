# frozen_string_literal: true

module Ralph
  module Output
    class ContextConsumed
      def self.call
        puts "\u{1F4DD} Context was consumed this iteration"
      end
    end
  end
end