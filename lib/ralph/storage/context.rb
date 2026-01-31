# frozen_string_literal: true

require "fileutils"

module Ralph
  module Storage
    # Manages persistent AI context for conversational continuity
    class Context
      class << self
        # --- File Paths ---
        def state_dir
          File.join(Dir.pwd, ".ralph")
        end

        def context_path
          File.join(state_dir, "ralph-context.md")
        end

        # --- Context Management ---
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

        # --- Context Manipulation ---
        def append_context(new_entry)
          FileUtils.mkdir_p(state_dir)
          if File.exist?(context_path)
            existing = File.read(context_path)
            File.write(context_path, existing + new_entry)
          else
            File.write(context_path, "# Ralph Loop Context\n#{new_entry}")
          end
        end

        def write_context(content)
          FileUtils.mkdir_p(state_dir)
          File.write(context_path, content)
        end
      end
    end
  end
end