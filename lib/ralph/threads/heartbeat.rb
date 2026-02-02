# frozen_string_literal: true

module Ralph
  module Threads
    class Heartbeat
      include ::Ralph::Helpers

      def initialize(iteration_start:, heartbeat_interval_ms:, timing:, mutex:)
        @iteration_start = iteration_start
        @heartbeat_interval_ms = heartbeat_interval_ms
        @timing = timing
        @mutex = mutex

        @thread = Thread.new { run_loop }
      end

      def stop
        @thread&.kill
      end

      def join
        @thread&.join
      end

      private

      def run_loop
        loop do
          sleep(@heartbeat_interval_ms / 1000.0)
          now_ms.then do |now|
            if now - @mutex.synchronize { @timing[:last_printed_at] } >= @heartbeat_interval_ms
              @mutex.synchronize do
                puts "⏳ working... elapsed #{format_duration(now - @iteration_start)} · last activity #{format_duration(now - @timing[:last_activity_at])} ago"
                @timing[:last_printed_at] = now_ms
              end
            end
          end
        end
      rescue StandardError
        # thread cleanup
      end
    end
  end
end
