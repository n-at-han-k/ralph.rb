# frozen_string_literal: true

module Ralph
  module Output
    class TasksFileCreated
      def self.call(path:)
        puts "\u{1F4CB} Created tasks file: #{path}"
      end
    end
  end
end