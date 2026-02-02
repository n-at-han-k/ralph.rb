# frozen_string_literal: true

module Ralph
  module Output
    class Banner
      def self.call(loop_context)
        Output::NoPluginWarning.call(loop_context) if loop_context.config.disable_plugins

        puts <<~BANNER

          ╔#{'=' * 66}╗
          ║                    Ralph Wiggum Loop                            ║
          ║         Iterative AI Development with #{loop_context.agent.config_name.ljust(20)}        ║
          ╚#{'=' * 66}╝
        BANNER

        if loop_context.config.tasks_mode
          tasks_storage = Storage::Tasks.new
          unless File.exist?(tasks_storage.path)
            tasks_storage.initialize_tasks_file
            Output::TasksFileCreated.call(path: tasks_storage.path)
          end
        end

        Output::ConfigSummary.call(loop_context)
      end
    end
  end
end
