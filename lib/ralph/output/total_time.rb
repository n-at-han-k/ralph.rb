module Ralph
  module Output
    class TotalTime
      def self.call(total_duration_ms:)
        puts "   Total time:   #{Helpers.format_duration_long(total_duration_ms)}"
      end
    end
  end
end