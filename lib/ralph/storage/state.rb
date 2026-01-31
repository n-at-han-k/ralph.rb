# frozen_string_literal: true

require "json"
require "fileutils"

module Ralph
  # Persistent loop state
  RalphState = Struct.new(
    :active,              # Boolean
    :iteration,           # Integer
    :min_iterations,      # Integer
    :max_iterations,      # Integer
    :completion_promise,  # String
    :tasks_mode,          # Boolean
    :task_promise,        # String
    :prompt,              # String
    :started_at,          # String (ISO 8601)
    :model,               # String
    :agent,               # String
    keyword_init: true
  )

  # File snapshot for change detection
  FileSnapshot = Struct.new(:files, keyword_init: true) # files: Hash<String, String>

  module Storage
    # Manages Ralph loop state persistence and session metadata
    class State
      class << self
        # --- File Paths ---
        def state_dir
          File.join(Dir.pwd, ".ralph")
        end

        def state_path
          File.join(state_dir, "ralph-loop.state.json")
        end

        # --- State Management ---
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

        # --- File Change Detection ---
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

        # --- Configuration Management ---
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
      end
    end
  end
end