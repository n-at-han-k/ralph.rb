module Ralph
  module Output
    class HistoryHeader
      def self.call(iteration_count:)
        puts "\n📊 HISTORY (#{iteration_count} iterations)"
      end
    end
  end
end