module Ralph
  module Output
    class TasksFileError
      def self.call
        puts "\n📋 CURRENT TASKS: (error reading tasks)"
      end
    end
  end
end