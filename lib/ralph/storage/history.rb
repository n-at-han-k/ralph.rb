# frozen_string_literal: true

require "json"
require "fileutils"

module Ralph
  module Storage
    # Manages iteration history and performance tracking.
    #
    # Stores everything as plain hashes. No structs, no ceremony.
    # Each iteration is a hash appended to an array, persisted as JSON.
    class History
      include ::Ralph::Helpers

      EMPTY_HISTORY = {
        "iterations" => [],
        "total_duration_ms" => 0,
        "struggle_indicators" => {
          "repeated_errors" => {},
          "no_progress_iterations" => 0,
          "short_iterations" => 0
        }
      }.freeze

      attr_reader :history

      def initialize
        @history = self.class.empty_history
        self.class.save_history(@history)
      end

      # Record a completed iteration.
      def record(state_iteration:, iteration_start:, result:, struggle_indicators:)
        entry = {
          "iteration" => state_iteration,
          "started_at" => Time.at(iteration_start / 1000.0).utc.iso8601,
          "ended_at" => Time.now.utc.iso8601,
          "duration_ms" => result.duration_ms,
          "tools_used" => result.tool_counts,
          "files_modified" => result.files_modified,
          "exit_code" => result.exit_code,
          "completion_detected" => result.completion_detected,
          "errors" => result.errors
        }

        append(entry, result.duration_ms, struggle_indicators)
      end

      # Record an iteration that raised an exception before producing a result.
      def record_error(state_iteration:, iteration_start:, error:)
        iteration_duration = now_ms - iteration_start

        entry = {
          "iteration" => state_iteration,
          "started_at" => Time.at(iteration_start / 1000.0).utc.iso8601,
          "ended_at" => Time.now.utc.iso8601,
          "duration_ms" => iteration_duration,
          "tools_used" => {},
          "files_modified" => [],
          "exit_code" => -1,
          "completion_detected" => false,
          "errors" => [error.to_s[0, 200]]
        }

        append(entry, iteration_duration, nil)
      end

      def total_duration_ms
        @history["total_duration_ms"]
      end

      # --- Class API (raw persistence) ---

      class << self
        def state_dir
          File.join(Dir.pwd, ".ralph")
        end

        def history_path
          File.join(state_dir, "ralph-history.json")
        end

        def empty_history
          JSON.parse(JSON.generate(EMPTY_HISTORY))
        end

        def save_history(history)
          FileUtils.mkdir_p(state_dir)
          File.write(history_path, JSON.pretty_generate(history))
        end

        def load_history
          return empty_history unless File.exist?(history_path)

          JSON.parse(File.read(history_path))
        rescue StandardError
          empty_history
        end

        def clear_history
          File.delete(history_path) if File.exist?(history_path)
        rescue StandardError
          # ignore
        end
      end

      private

      def append(entry, duration_ms, struggle_indicators)
        @history["iterations"] << entry
        @history["total_duration_ms"] += duration_ms
        @history["struggle_indicators"] = struggle_indicators if struggle_indicators
        self.class.save_history(@history)
      end
    end
  end
end
