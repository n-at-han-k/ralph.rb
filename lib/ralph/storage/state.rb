# frozen_string_literal: true

require "json"
require "fileutils"

module Ralph
  module Storage
    # Represents and persists Ralph loop state
    class State
      attr_accessor :active, :iteration
      attr_reader :min_iterations, :max_iterations, :completion_promise,
                  :tasks_mode, :task_promise, :prompt, :started_at,
                  :model, :agent

      def initialize(active:, iteration:, min_iterations:, max_iterations:,
                     completion_promise:, tasks_mode:, task_promise:, prompt:,
                     started_at:, model:, agent:)
        @active = active
        @iteration = iteration
        @min_iterations = min_iterations
        @max_iterations = max_iterations
        @completion_promise = completion_promise
        @tasks_mode = tasks_mode
        @task_promise = task_promise
        @prompt = prompt
        @started_at = started_at
        @model = model
        @agent = agent
      end

      def save
        FileUtils.mkdir_p(self.class.dir)
        File.write(self.class.path, JSON.pretty_generate(to_h))
      end

      def clear
        File.delete(self.class.path) if File.exist?(self.class.path)
      rescue StandardError
        # ignore
      end

      def to_h
        {
          active: @active,
          iteration: @iteration,
          minIterations: @min_iterations,
          maxIterations: @max_iterations,
          completionPromise: @completion_promise,
          tasksMode: @tasks_mode,
          taskPromise: @task_promise,
          prompt: @prompt,
          startedAt: @started_at,
          model: @model,
          agent: @agent
        }
      end

      class << self
        def dir
          File.join(Dir.pwd, ".ralph")
        end

        def path
          File.join(dir, "ralph-loop.state.json")
        end

        def load
          return nil unless File.exist?(path)
          data = JSON.parse(File.read(path))
          new(
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

        def clear
          File.delete(path) if File.exist?(path)
        rescue StandardError
          # ignore
        end
      end

      # --- Configuration Management ---
      # NOTE: Commented out — this was generating a synthetic OpenCode config
      # to inject via OPENCODE_CONFIG env var. It worked around OpenCode's
      # permission system and reimplemented its config resolution logic.
      # If needed again, this should be an OpenCode feature, not a workaround.
      #
      # def self.load_plugins_from_config(config_path)
      #   return [] unless File.exist?(config_path)
      #   raw = File.read(config_path)
      #   without_block = raw.gsub(/\/\*[\s\S]*?\*\//, "")
      #   without_line = without_block.gsub(/^\s*\/\/.*$/, "")
      #   parsed = JSON.parse(without_line)
      #   plugins = parsed["plugin"]
      #   return [] unless plugins.is_a?(Array)
      #   plugins.select { |p| p.is_a?(String) }
      # rescue StandardError
      #   []
      # end
      #
      # def self.ensure_ralph_config(filter_plugins: false, allow_all_permissions: false)
      #   FileUtils.mkdir_p(dir)
      #   config_path = File.join(dir, "ralph-opencode.config.json")
      #
      #   xdg_config = ENV["XDG_CONFIG_HOME"] || File.join(ENV["HOME"] || "", ".config")
      #   user_config_path = File.join(xdg_config, "opencode", "opencode.json")
      #   project_config_path = File.join(Dir.pwd, ".ralph", "opencode.json")
      #   legacy_project_config_path = File.join(Dir.pwd, ".opencode", "opencode.json")
      #
      #   config = { "$schema" => "https://opencode.ai/config.json" }
      #
      #   if filter_plugins
      #     plugins = [
      #       *load_plugins_from_config(user_config_path),
      #       *load_plugins_from_config(project_config_path),
      #       *load_plugins_from_config(legacy_project_config_path)
      #     ].uniq.select { |p| p =~ /auth/i }
      #     config["plugin"] = plugins
      #   end
      #
      #   if allow_all_permissions
      #     config["permission"] = {
      #       "read" => "allow",
      #       "edit" => "allow",
      #       "glob" => "allow",
      #       "grep" => "allow",
      #       "list" => "allow",
      #       "bash" => "allow",
      #       "task" => "allow",
      #       "webfetch" => "allow",
      #       "websearch" => "allow",
      #       "codesearch" => "allow",
      #       "todowrite" => "allow",
      #       "todoread" => "allow",
      #       "question" => "allow",
      #       "lsp" => "allow",
      #       "external_directory" => "allow"
      #     }
      #   end
      #
      #   File.write(config_path, JSON.pretty_generate(config))
      #   config_path
      # end
    end
  end
end
