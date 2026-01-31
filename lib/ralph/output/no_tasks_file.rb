module Ralph
  module Output
    class NoTasksFile
      def self.call
        puts "\n📋 CURRENT TASKS: (no tasks file found)"
      end
    end
  end
end