# frozen_string_literal: true

require "fileutils"

module Ralph
  module Storage
    # Manages task tracking and workflow coordination
    class Tasks
      class << self
        # --- File Paths ---
        def state_dir
          File.join(Dir.pwd, ".ralph")
        end

        def tasks_path
          File.join(state_dir, "ralph-tasks.md")
        end

        # --- Tasks Management ---
        def load_tasks
          return nil unless File.exist?(tasks_path)
          content = File.read(tasks_path)
          TasksCollection.parse(content)
        rescue StandardError
          nil
        end

        def save_tasks(tasks)
          FileUtils.mkdir_p(state_dir)
          content = "# Ralph Tasks\n\n"
          tasks.each do |task|
            content << task.to_s << "\n"
            task.subtasks.each do |subtask|
              content << "  #{subtask.to_s}\n"
            end
          end
          File.write(tasks_path, content)
        end

        def clear_tasks
          File.delete(tasks_path) if File.exist?(tasks_path)
        rescue StandardError
          # ignore
        end

        def tasks_exist?
          File.exist?(tasks_path)
        end

        # --- Task Initialization ---
        def initialize_tasks_file
          FileUtils.mkdir_p(state_dir)
          content = "# Ralph Tasks\n\nAdd your tasks below using: `ralph --add-task \"description\"`\n"
          File.write(tasks_path, content)
          tasks_path
        end
      end
    end

    # --- Task Models ---

    # Individual task with status and subtasks
    class Task
      attr_accessor :text, :status, :subtasks, :original_line

      def initialize(text:, status: :todo, subtasks: [], original_line: nil)
        @text = text
        @status = status
        @subtasks = subtasks
        @original_line = original_line
      end

      def status_char
        case status
        when :complete then "x"
        when :in_progress then "/"
        else " "
        end
      end

      def to_s
        "- [#{status_char}] #{text}"
      end

      def todo?        = status == :todo
      def in_progress? = status == :in_progress
      def complete?    = status == :complete

      def toggle_status
        case status
        when :todo        then @status = :in_progress
        when :in_progress then @status = :complete
        when :complete    then @status = :todo
        end
      end

      def mark_complete!    = @status = :complete
      def mark_in_progress! = @status = :in_progress
      def mark_todo!        = @status = :todo
    end

    # Collection of tasks with enumerable interface
    class TasksCollection
      include Enumerable

      def initialize(tasks = [])
        @tasks = tasks
      end

      def each(&block)  = @tasks.each(&block)
      def count(&block) = @tasks.count(&block)

      def empty? = @tasks.empty?
      def length = @tasks.length
      def any?   = @tasks.any?

      def self.parse(content)
        tasks = []
        current_task = nil

        content.each_line do |line|
          # Top-level task: starts with "- [" at beginning (no leading whitespace)
          if (match = line.match(/^- \[([ x\/])\]\s*(.+)/))
            tasks << current_task if current_task
            status_char = match[1]
            text = match[2]
            status = case status_char
                     when "x" then :complete
                     when "/" then :in_progress
                     else :todo
                     end
            current_task = Task.new(text: text, status: status, subtasks: [], original_line: line.chomp)
            next
          end

          # Subtask: starts with whitespace followed by "- ["
          if (match = line.match(/^\s+- \[([ x\/])\]\s*(.+)/)) && current_task
            status_char = match[1]
            text = match[2]
            status = case status_char
                     when "x" then :complete
                     when "/" then :in_progress
                     else :todo
                     end
            current_task.subtasks << Task.new(text: text, status: status, subtasks: [], original_line: line.chomp)
          end
        end

        tasks << current_task if current_task
        new(tasks)
      end

      # Display tasks with numbering for CLI
      def display_with_indices
        if empty?
          puts "No tasks found."
          return
        end

        puts "Current tasks:"
        each_with_index do |task, i|
          icon = status_icon(task.status)
          puts "#{i + 1}. #{icon} #{task.text}"

          task.subtasks.each do |subtask|
            sub_icon = status_icon(subtask.status)
            puts "   #{sub_icon} #{subtask.text}"
          end
        end
      end

      def current = find { |t| t.status == :in_progress }
      def next = find { |t| t.status == :todo }

      def all_complete?
        !empty? && all? { |t| t.status == :complete }
      end

      def status_icon(status)
        case status
        when :complete    then "\u2705"
        when :in_progress then "\u{1F504}"
        else "\u{23F8}\uFE0F"
        end
      end

      def self.status_icon(status)
        case status
        when :complete    then "\u2705"
        when :in_progress then "\u{1F504}"
        else "\u{23F8}\uFE0F"
        end
      end
    end
  end
end