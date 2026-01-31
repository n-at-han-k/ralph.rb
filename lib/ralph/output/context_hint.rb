module Ralph
  module Output
    class ContextHint
      def self.call
        puts "\n   💡 Consider using: ralph --add-context \"your hint here\""
      end
    end
  end
end