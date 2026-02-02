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

        if loop_context.config.tasks_mode && !File.exist?(Storage::Tasks.tasks_path)
          FileUtils.mkdir_p(Storage::State.dir)

          File.write(
            Storage::Tasks.tasks_path,
            "# Ralph Tasks\n\nAdd your tasks below using: `ralph --add-task \"description\"`\n"
          )

          Output::TasksFileCreated.call(path: Storage::Tasks.tasks_path)
        end

        Output::ConfigSummary.call(loop_context)
      end
    end
  end
end
