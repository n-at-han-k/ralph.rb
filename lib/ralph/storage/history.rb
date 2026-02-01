# frozen_string_literal: true

require "json"
require "fileutils"

module Ralph
  # Single iteration record
  IterationHistory = Struct.new(
    :iteration,           # Integer
    :started_at,          # String (ISO 8601)
    :ended_at,            # String (ISO 8601)
    :duration_ms,         # Integer
    :tools_used,          # Hash<String, Integer>
    :files_modified,      # Array<String>
    :exit_code,           # Integer
    :completion_detected, # Boolean
    :errors,              # Array<String>
    keyword_init: true
  )

  # Full history across iterations
  RalphHistory = Struct.new(
    :iterations,          # Array<IterationHistory>
    :total_duration_ms,   # Integer
    :struggle_indicators, # StruggleIndicators
    keyword_init: true
  ) do
    def self.empty
      new(
        iterations: [],
        total_duration_ms: 0,
        struggle_indicators: StruggleIndicators.empty
      )
    end
  end

  # Struggle indicators
  StruggleIndicators = Struct.new(
    :repeated_errors,        # Hash<String, Integer>
    :no_progress_iterations, # Integer
    :short_iterations,       # Integer
    keyword_init: true
  ) do
    def self.empty
      new(repeated_errors: {}, no_progress_iterations: 0, short_iterations: 0)
    end
  end

  module Storage
    # Manages iteration history and performance tracking.
    #
    # Class methods handle raw persistence (save/load/clear).
    # Instance methods provide a higher-level recording API that Loop uses.
    class History
      # --- Instance API (used by Loop) ---

      attr_reader :history

      def initialize
        @history = RalphHistory.empty
        self.class.save_history(@history)
      end

      # Record a completed iteration (success or failure from the agent).
      def record(state_iteration:, iteration_start:, result:, struggle_indicators:)
        iter_record = IterationHistory.new(
          iteration: state_iteration,
          started_at: Time.at(iteration_start / 1000.0).utc.iso8601,
          ended_at: Time.now.utc.iso8601,
          duration_ms: result.duration_ms,
          tools_used: result.tool_counts,
          files_modified: result.files_modified,
          exit_code: result.exit_code,
          completion_detected: result.completion_detected,
          errors: result.errors
        )

        append(iter_record, result.duration_ms, struggle_indicators)
      end

      # Record an iteration that raised an exception before producing a result.
      def record_error(state_iteration:, iteration_start:, error:)
        iteration_duration = Helpers.now_ms - iteration_start

        error_record = IterationHistory.new(
          iteration: state_iteration,
          started_at: Time.at(iteration_start / 1000.0).utc.iso8601,
          ended_at: Time.now.utc.iso8601,
          duration_ms: iteration_duration,
          tools_used: {},
          files_modified: [],
          exit_code: -1,
          completion_detected: false,
          errors: [error.to_s[0, 200]]
        )

        append(error_record, iteration_duration, nil)
      end

      def total_duration_ms
        @history.total_duration_ms
      end

      # --- Class API (raw persistence) ---

      class << self
        def state_dir
          File.join(Dir.pwd, ".ralph")
        end

        def history_path
          File.join(state_dir, "ralph-history.json")
        end

        def save_history(history)
          FileUtils.mkdir_p(state_dir)
          data = {
            iterations: history.iterations.map { |iter|
              {
                iteration: iter.iteration,
                startedAt: iter.started_at,
                endedAt: iter.ended_at,
                durationMs: iter.duration_ms,
                toolsUsed: iter.tools_used,
                filesModified: iter.files_modified,
                exitCode: iter.exit_code,
                completionDetected: iter.completion_detected,
                errors: iter.errors
              }
            },
            totalDurationMs: history.total_duration_ms,
            struggleIndicators: {
              repeatedErrors: history.struggle_indicators.repeated_errors,
              noProgressIterations: history.struggle_indicators.no_progress_iterations,
              shortIterations: history.struggle_indicators.short_iterations
            }
          }
          File.write(history_path, JSON.pretty_generate(data))
        end

        def load_history
          return RalphHistory.empty unless File.exist?(history_path)
          data = JSON.parse(File.read(history_path))
          iterations = (data["iterations"] || []).map do |iter|
            IterationHistory.new(
              iteration: iter["iteration"],
              started_at: iter["startedAt"],
              ended_at: iter["endedAt"],
              duration_ms: iter["durationMs"],
              tools_used: iter["toolsUsed"] || {},
              files_modified: iter["filesModified"] || [],
              exit_code: iter["exitCode"],
              completion_detected: iter["completionDetected"],
              errors: iter["errors"] || []
            )
          end
          si = data["struggleIndicators"] || {}
          RalphHistory.new(
            iterations: iterations,
            total_duration_ms: data["totalDurationMs"] || 0,
            struggle_indicators: StruggleIndicators.new(
              repeated_errors: si["repeatedErrors"] || {},
              no_progress_iterations: si["noProgressIterations"] || 0,
              short_iterations: si["shortIterations"] || 0
            )
          )
        rescue StandardError
          RalphHistory.empty
        end

        def clear_history
          File.delete(history_path) if File.exist?(history_path)
        rescue StandardError
          # ignore
        end
      end

      private

      def append(record, duration_ms, struggle_indicators)
        @history.iterations << record
        @history.total_duration_ms += duration_ms
        @history.struggle_indicators = struggle_indicators if struggle_indicators
        self.class.save_history(@history)
      end
    end
  end
end