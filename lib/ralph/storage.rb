# frozen_string_literal: true

require_relative "storage/history"
require_relative "storage/state"
require_relative "storage/context"
require_relative "storage/tasks"

module Ralph
  # Main storage module that provides unified access to all storage components
  module Storage
    module_function

    # --- State Management ---
    def save_state(state)
      State.save_state(state)
    end

    def load_state
      State.load_state
    end

    def clear_state
      State.clear_state
    end

    def state_dir
      State.state_dir
    end

    def state_path
      State.state_path
    end

    # --- History Management ---
    def save_history(history)
      History.save_history(history)
    end

    def load_history
      History.load_history
    end

    def clear_history
      History.clear_history
    end

    def history_path
      History.history_path
    end

    # --- Context Management ---
    def load_context
      Context.load_context
    end

    def clear_context
      Context.clear_context
    end

    def context_path
      Context.context_path
    end

    # --- Tasks Management ---
    def save_tasks(tasks)
      Tasks.save_tasks(tasks)
    end

    def load_tasks
      Tasks.load_tasks
    end

    def clear_tasks
      Tasks.clear_tasks
    end

    def tasks_path
      Tasks.tasks_path
    end

    def tasks_exist?
      Tasks.tasks_exist?
    end

    # --- File Change Detection ---
    def capture_file_snapshot
      State.capture_file_snapshot
    end

    def modified_files_since_snapshot(before, after)
      State.modified_files_since_snapshot(before, after)
    end

    # --- Configuration Management ---
    def load_plugins_from_config(config_path)
      State.load_plugins_from_config(config_path)
    end

    def ensure_ralph_config(filter_plugins: false, allow_all_permissions: false)
      State.ensure_ralph_config(filter_plugins: filter_plugins, allow_all_permissions: allow_all_permissions)
    end
  end
end