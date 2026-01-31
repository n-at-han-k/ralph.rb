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
    # Manages iteration history and performance tracking
    class History
      class << self
        # --- File Paths ---
        def state_dir
          File.join(Dir.pwd, ".ralph")
        end

        def history_path
          File.join(state_dir, "ralph-history.json")
        end

        # --- History Management ---
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
    end
  end
end