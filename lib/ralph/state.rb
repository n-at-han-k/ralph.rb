# frozen_string_literal: true

require "json"
require "fileutils"
require_relative "types"

module Ralph
  module State
    module_function

    def state_dir
      File.join(Dir.pwd, ".ralph")
    end

    def state_path
      File.join(state_dir, "ralph-loop.state.json")
    end

    def context_path
      File.join(state_dir, "ralph-context.md")
    end

    def history_path
      File.join(state_dir, "ralph-history.json")
    end

    def tasks_path
      File.join(state_dir, "ralph-tasks.md")
    end

    # --- State ---

    def save_state(state)
      FileUtils.mkdir_p(state_dir)
      data = {
        active: state.active,
        iteration: state.iteration,
        minIterations: state.min_iterations,
        maxIterations: state.max_iterations,
        completionPromise: state.completion_promise,
        tasksMode: state.tasks_mode,
        taskPromise: state.task_promise,
        prompt: state.prompt,
        startedAt: state.started_at,
        model: state.model,
        agent: state.agent
      }
      File.write(state_path, JSON.pretty_generate(data))
    end

    def load_state
      return nil unless File.exist?(state_path)
      data = JSON.parse(File.read(state_path))
      RalphState.new(
        active: data["active"],
        iteration: data["iteration"],
        min_iterations: data["minIterations"],
        max_iterations: data["maxIterations"],
        completion_promise: data["completionPromise"],
        tasks_mode: data["tasksMode"],
        task_promise: data["taskPromise"],
        prompt: data["prompt"],
        started_at: data["startedAt"],
        model: data["model"],
        agent: data["agent"]
      )
    rescue StandardError
      nil
    end

    def clear_state
      File.delete(state_path) if File.exist?(state_path)
    rescue StandardError
      # ignore
    end

    # --- History ---

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

    # --- Context ---

    def load_context
      return nil unless File.exist?(context_path)
      content = File.read(context_path).strip
      content.empty? ? nil : content
    rescue StandardError
      nil
    end

    def clear_context
      File.delete(context_path) if File.exist?(context_path)
    rescue StandardError
      # ignore
    end

    # --- OpenCode Config ---

    def load_plugins_from_config(config_path)
      return [] unless File.exist?(config_path)
      raw = File.read(config_path)
      # Basic JSONC support: strip // and /* */ comments
      without_block = raw.gsub(/\/\*[\s\S]*?\*\//, "")
      without_line = without_block.gsub(/^\s*\/\/.*$/, "")
      parsed = JSON.parse(without_line)
      plugins = parsed["plugin"]
      return [] unless plugins.is_a?(Array)
      plugins.select { |p| p.is_a?(String) }
    rescue StandardError
      []
    end

    def ensure_ralph_config(filter_plugins: false, allow_all_permissions: false)
      FileUtils.mkdir_p(state_dir)
      config_path = File.join(state_dir, "ralph-opencode.config.json")

      xdg_config = ENV["XDG_CONFIG_HOME"] || File.join(ENV["HOME"] || "", ".config")
      user_config_path = File.join(xdg_config, "opencode", "opencode.json")
      project_config_path = File.join(Dir.pwd, ".ralph", "opencode.json")
      legacy_project_config_path = File.join(Dir.pwd, ".opencode", "opencode.json")

      config = { "$schema" => "https://opencode.ai/config.json" }

      if filter_plugins
        plugins = [
          *load_plugins_from_config(user_config_path),
          *load_plugins_from_config(project_config_path),
          *load_plugins_from_config(legacy_project_config_path)
        ].uniq.select { |p| p =~ /auth/i }
        config["plugin"] = plugins
      end

      if allow_all_permissions
        config["permission"] = {
          "read" => "allow",
          "edit" => "allow",
          "glob" => "allow",
          "grep" => "allow",
          "list" => "allow",
          "bash" => "allow",
          "task" => "allow",
          "webfetch" => "allow",
          "websearch" => "allow",
          "codesearch" => "allow",
          "todowrite" => "allow",
          "todoread" => "allow",
          "question" => "allow",
          "lsp" => "allow",
          "external_directory" => "allow"
        }
      end

      File.write(config_path, JSON.pretty_generate(config))
      config_path
    end

    # --- File Snapshots ---

    def capture_file_snapshot
      files = {}
      begin
        status = `git status --porcelain 2>/dev/null`.strip
        tracked = `git ls-files 2>/dev/null`.strip

        all_files = Set.new
        status.each_line do |line|
          name = line[3..]&.strip
          all_files.add(name) if name && !name.empty?
        end
        tracked.each_line do |file|
          f = file.strip
          all_files.add(f) unless f.empty?
        end

        all_files.each do |file|
          begin
            hash = `git hash-object #{file} 2>/dev/null`.strip
            files[file] = hash unless hash.empty?
          rescue StandardError
            # skip
          end
        end
      rescue StandardError
        # git not available
      end
      FileSnapshot.new(files: files)
    end

    def modified_files_since_snapshot(before, after)
      changed = []

      after.files.each do |file, hash|
        prev_hash = before.files[file]
        changed << file if prev_hash != hash
      end

      before.files.each_key do |file|
        changed << file unless after.files.key?(file)
      end

      changed
    end
  end
end
