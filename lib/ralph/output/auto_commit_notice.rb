# frozen_string_literal: true

module Ralph
  module Output
    class AutoCommitNotice
      def self.call(iteration:)
        puts "📝 Auto-committed changes"
      end
    end
  end
end