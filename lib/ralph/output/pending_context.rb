module Ralph
  module Output
    class PendingContext
      def self.call(context:)
        puts "\n📝 PENDING CONTEXT (will be injected next iteration):"
        puts "   #{context.split("\n").join("\n   ")}"
      end
    end
  end
end