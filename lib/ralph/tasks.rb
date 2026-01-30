# frozen_string_literal: true

require_relative "types"
require_relative "state"

module Ralph
  module Tasks
    module_function

    # Parse markdown tasks into structured data
    def parse(content)
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
      tasks
    end

    # Display tasks with numbering for CLI
    def display_with_indices(tasks)
      if tasks.empty?
        puts "No tasks found."
        return
      end

      puts "Current tasks:"
      tasks.each_with_index do |task, i|
        icon = status_icon(task.status)
        puts "#{i + 1}. #{icon} #{task.text}"

        task.subtasks.each do |subtask|
          sub_icon = status_icon(subtask.status)
          puts "   #{sub_icon} #{subtask.text}"
        end
      end
    end

    # Find the current in-progress task
    def find_current(tasks)
      tasks.find { |t| t.status == :in_progress }
    end

    # Find the next incomplete task
    def find_next(tasks)
      tasks.find { |t| t.status == :todo }
    end

    # Check if all tasks are complete
    def all_complete?(tasks)
      !tasks.empty? && tasks.all? { |t| t.status == :complete }
    end

    def status_icon(status)
      case status
      when :complete    then "\u2705"
      when :in_progress then "\u{1F504}"
      else "\u{23F8}\uFE0F"
      end
    end
  end
end
