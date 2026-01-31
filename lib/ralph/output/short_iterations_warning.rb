module Ralph
  module Output
    class ShortIterationsWarning
      def self.call(count:)
        puts "   - #{count} very short iterations (< 30s)"
      end
    end
  end
end