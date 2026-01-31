# frozen_string_literal: true

# Backward compatibility wrapper that delegates to the new Storage module
# This maintains all existing functionality while the code is reorganized
module Ralph
  module State
    module_function

    # --- State Management ---
    def save_state(state)
      Storage.save_state(state)
    end

    def load_state
      Storage.load_state
    end

    def clear_state
      Storage.clear_state
    end

    def state_dir
      Storage.state_dir
    end

    def state_path
      Storage.state_path
    end

    # --- History Management ---
    def save_history(history)
      Storage.save_history(history)
    end

    def load_history
      Storage.load_history
    end

    def clear_history
      Storage.clear_history
    end

    def history_path
      Storage.history_path
    end

    # --- Context Management ---
    def load_context
      Storage.load_context
    end

    def clear_context
      Storage.clear_context
    end

    def context_path
      Storage.context_path
    end

    # --- Tasks Management ---
    def tasks_path
      Storage.tasks_path
    end

    # --- File Change Detection ---
    def capture_file_snapshot
      Storage.capture_file_snapshot
    end

    def modified_files_since_snapshot(before, after)
      Storage.modified_files_since_snapshot(before, after)
    end

    # --- Configuration Management ---
    def load_plugins_from_config(config_path)
      Storage.load_plugins_from_config(config_path)
    end

    def ensure_ralph_config(filter_plugins: false, allow_all_permissions: false)
      Storage.ensure_ralph_config(filter_plugins: filter_plugins, allow_all_permissions: allow_all_permissions)
    end
  end
end