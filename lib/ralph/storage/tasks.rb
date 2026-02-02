# frozen_string_literal: true

require "fileutils"

module Ralph
  module Storage
    # Manages task tracking and workflow coordination.
    #
    # Always instantiate with Tasks.new — it represents the tasks file on disk.
    # Follows the same instance-based pattern as Context and History.
    class Tasks
      def initialize
        FileUtils.mkdir_p(dir)
      end

      def self.dir
        File.join(Dir.pwd, ".ralph")
      end

      def dir = self.class.dir

      def self.path
        File.join(dir, "ralph-tasks.md")
      end

      def path = self.class.path

      # --- Tasks Management ---
      def load_tasks
        if File.exist?(path)
          content = File.read(path)
          TasksCollection.parse(content)
        end
      rescue StandardError
        nil
      end

      def save_tasks(tasks)
        content = "# Ralph Tasks\n\n"
        tasks.each do |task|
          content << task.to_s << "\n"
          task.subtasks.each do |subtask|
            content << "  #{subtask}\n"
          end
        end
        File.write(path, content)
      end

      def clear_tasks
        File.delete(path) if File.exist?(path)
      rescue StandardError
        # ignore
      end

      def tasks_exist?
        File.exist?(path)
      end

      # --- Single Task Operations ---

      # Add a new task by description string.
      # Creates the tasks file if it doesn't exist.
      def add_task(description)
        tasks = load_tasks || TasksCollection.new
        task = Task.new(text: description, status: :todo)
        tasks.add(task)
        save_tasks(tasks)
        task
      end

      # Remove a task by 1-based index.
      # Returns the removed Task.
      # Raises IndexError if index is out of range.
      # Raises RuntimeError if no tasks file exists.
      def remove_task(index)
        raise "No tasks file found" unless tasks_exist?

        tasks = load_tasks
        removed = tasks.remove_at(index)
        save_tasks(tasks)
        removed
      end

      # --- Task Initialization ---
      def initialize_tasks_file
        content = "# Ralph Tasks\n\nAdd your tasks below using: `ralph --add-task \"description\"`\n"
        File.write(path, content)
        path
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

      # Add a task to the collection
      def add(task)
        @tasks << task
        self
      end

      # Remove a task (and its subtasks) by 1-based index.
      # Returns the removed Task, or raises IndexError if out of range.
      def remove_at(index)
        if index < 1 || index > @tasks.length
          raise IndexError, "Task index #{index} is out of range (1-#{@tasks.length})"
        end

        @tasks.delete_at(index - 1)
      end

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
        when :complete    then "✅"
        when :in_progress then "🔄"
        else "⏸️"
        end
      end

      def self.status_icon(status)
        case status
        when :complete    then "✅"
        when :in_progress then "🔄"
        else "⏸️"
        end
      end
    end
  end
end