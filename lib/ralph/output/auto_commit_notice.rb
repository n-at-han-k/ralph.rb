# frozen_string_literal: true

module Ralph
  module Output
    class AutoCommitNotice
      def self.call(iteration:)
        puts "\u{1F4DD} Auto-committed changes"
      end
    end
  end
end