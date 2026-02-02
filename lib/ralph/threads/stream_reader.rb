# frozen_string_literal: true

module Ralph
  module Threads
    class StreamReader
      def initialize(io, text_buffer, mutex, tool_counts, on_line, is_error, tool_parser)
        @io = io
        @text_buffer = text_buffer
        @mutex = mutex
        @tool_counts = tool_counts
        @on_line = on_line
        @is_error = is_error
        @tool_parser = tool_parser

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
        buffer = +""
        while (chunk = @io.read(4096))
          @text_buffer << chunk
          buffer << chunk
          while (index = buffer.index("\n"))
            line = buffer.slice!(0, index + 1).chomp
            tool = @tool_parser.call(line)
            @mutex.synchronize { @tool_counts[tool] += 1 } if tool
            @on_line.call(line, @is_error, tool) if @on_line
          end
        end
        unless buffer.empty?
          tool = @tool_parser.call(buffer)
          @mutex.synchronize { @tool_counts[tool] += 1 } if tool
          @on_line.call(buffer, @is_error, tool) if @on_line
        end
      rescue IOError
        # stream closed
      end
    end
  end
end
