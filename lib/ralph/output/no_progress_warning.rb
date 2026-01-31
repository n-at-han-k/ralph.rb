module Ralph
  module Output
    class NoProgressWarning
      def self.call(count:)
        puts "   - No file changes in #{count} iterations"
      end
    end
  end
end