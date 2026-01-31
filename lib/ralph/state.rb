# frozen_string_literal: true

module Ralph
  module State
    module_function

    # --- State Management ---
    def save_state(state)
      Storage::State.save_state(state)
    end

    def load_state
      Storage::State.load_state
    end

    def clear_state
      Storage::State.clear_state
    end

    def state_dir
      Storage::State.state_dir
    end

    def state_path
      Storage::State.state_path
    end

    # --- History Management ---
    def save_history(history)
      Storage::History.save_history(history)
    end

    def load_history
      Storage::History.load_history
    end

    def clear_history
      Storage::History.clear_history
    end

    def history_path
      Storage::History.history_path
    end

    # --- Context Management ---
    def load_context
      Storage::Context.load_context
    end

    def clear_context
      Storage::Context.clear_context
    end

    def context_path
      Storage::Context.context_path
    end

    # --- Tasks Management ---
    def tasks_path
      Storage::Tasks.tasks_path
    end

    # --- File Change Detection ---
    def capture_file_snapshot
      Storage::State.capture_file_snapshot
    end

    def modified_files_since_snapshot(before, after)
      Storage::State.modified_files_since_snapshot(before, after)
    end

    # --- Configuration Management ---
    def load_plugins_from_config(config_path)
      Storage::State.load_plugins_from_config(config_path)
    end

    def ensure_ralph_config(filter_plugins: false, allow_all_permissions: false)
      Storage::State.ensure_ralph_config(filter_plugins: filter_plugins, allow_all_permissions: allow_all_permissions)
    end
  end
end
