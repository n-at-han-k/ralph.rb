# frozen_string_literal: true

module Ralph
  module Agents
    class Base
      include ::Ralph::Helpers

      def type
        raise NotImplementedError
      end

      def command
        raise NotImplementedError
      end

      def config_name
        raise NotImplementedError
      end

      def build_args(_prompt, _model, _options)
        raise NotImplementedError
      end

      def build_env(_options)
        ENV.to_h.dup
      end

      def parse_tool_output(_line)
        raise NotImplementedError
      end

      def validate!
        path = which(command)
        unless path
          $stderr.puts "Error: #{config_name} CLI ('#{command}') not found."
          exit 1
        end
      end
    end
  end
end
