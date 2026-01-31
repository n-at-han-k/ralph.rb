# frozen_string_literal: true

require_relative "state"

module Ralph
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

  class Tasks
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
