module Ralph
  module Output
    class RecentIterations
      def self.call(iterations:)
        puts "\n   Recent iterations:"
        iterations.each do |iter|
          tools = iter.tools_used
                    .sort_by { |_, v| -v }
                    .first(3)
                    .map { |k, v| "#{k}:#{v}" }
                    .join(" ")
          status_icon = if iter.completion_detected
            "✅"
          elsif iter.exit_code != 0
            "❌"
          else
            "🔄"
          end
          puts "   #{status_icon} ##{iter.iteration}: #{Helpers.format_duration_long(iter.duration_ms)} | #{tools.empty? ? "no tools" : tools}"
        end
      end
    end
  end
end