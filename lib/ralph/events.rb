# frozen_string_literal: true

module Ralph
  module Events
    # Base event wrapping the common fields from opencode JSON stream lines
    class Base
      attr_reader :type, :timestamp, :session_id, :part

      def initialize(data)
        @type = data["type"]
        @timestamp = data["timestamp"]
        @session_id = data["sessionID"]
        @part = data["part"] || {}
      end
    end

    # Emitted when a new LLM step begins
    class StepStart < Base
      def snapshot
        part["snapshot"]
      end
    end

    # Emitted when the model streams text content
    class Text < Base
      def text
        part["text"]
      end
    end

    # Emitted when the model invokes a tool
    class ToolUse < Base
      def tool
        part["tool"]
      end

      def call_id
        part["callID"]
      end

      def state
        part["state"] || {}
      end

      def status
        state["status"]
      end

      def input
        state["input"]
      end

      def output
        state["output"]
      end
    end

    # Emitted when a step completes -- carries the token usage data
    class StepFinish < Base
      def reason
        part["reason"]
      end

      def tokens
        part["tokens"] || {}
      end

      def input_tokens
        tokens["input"] || 0
      end

      def output_tokens
        tokens["output"] || 0
      end

      def reasoning_tokens
        tokens["reasoning"] || 0
      end

      def cache
        tokens["cache"] || {}
      end

      def cache_read
        cache["read"] || 0
      end

      def cache_write
        cache["write"] || 0
      end

      # Total context size for this step: input + cache.read + cache.write
      def context_size
        input_tokens + cache_read + cache_write
      end
    end

    EVENT_TYPES = {
      "step_start" => StepStart,
      "text" => Text,
      "tool_use" => ToolUse,
      "step_finish" => StepFinish
    }.freeze

    # Parse a single JSON line into the appropriate event object.
    # Returns nil for unknown event types or malformed JSON.
    def self.parse(line)
      data = JSON.parse(line)
      event_class = EVENT_TYPES[data["type"]]
      if event_class
        event_class.new(data)
      end
    rescue JSON::ParserError
      nil
    end
  end
end
