module Ralph
  module Output
    class CurrentTasks
      def self.call(tasks:)
        if tasks.any?
          puts "\n📋 CURRENT TASKS:"
          tasks.each_with_index do |task, i|
            icon = tasks.status_icon(task.status)
            puts "   #{i + 1}. #{icon} #{task.text}"
            task.subtasks.each do |subtask|
              sub_icon = tasks.status_icon(subtask.status)
              puts "      #{sub_icon} #{subtask.text}"
            end
          end
          complete = tasks.count { |t| t.status == :complete }
          in_progress = tasks.count { |t| t.status == :in_progress }
          puts "\n   Progress: #{complete}/#{tasks.length} complete, #{in_progress} in progress"
        else
          puts "\n📋 CURRENT TASKS: (no tasks found)"
        end
      end
    end
  end
end