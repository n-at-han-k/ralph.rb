module Ralph
  module Output
    class RepeatedErrorWarning
      def self.call(error:, count:)
        puts "   - Same error #{count}x: \"#{error[0, 50]}...\""
      end
    end
  end
end