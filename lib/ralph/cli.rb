# frozen_string_literal: true

require "fileutils"
require "optparse"
require_relative "version"
require_relative "helpers"
require_relative "agents"
require_relative "state"
require_relative "tasks"
require_relative "loop"

module Ralph
  module CLI
    module_function

    def run(argv = ARGV)
      options = {
        prompt: "",
        min_iterations: 1,
        max_iterations: 0,
        completion_promise: "COMPLETE",
        tasks_mode: false,
        task_promise: "READY_FOR_NEXT_TASK",
        model: "",
        agent_type: "opencode",
        auto_commit: true,
        disable_plugins: false,
        allow_all_permissions: true,
        prompt_file: "",
        stream_output: true,
        verbose_tools: false,
        prompt_source: ""
      }

      # Subcommand state -- set by flags, dispatched after parsing
      command = nil
      command_arg = nil

      parser = build_parser(options) do |cmd, arg|
        command = cmd
        command_arg = arg
      end

      # Parse and collect remaining positional args as prompt parts
      prompt_parts = parser.parse(argv.dup)

      # Dispatch subcommands
      case command
      when :version
        puts "ralph #{VERSION}"
        exit 0
      when :status
        show_status(options)
        exit 0
      when :add_context
        handle_add_context(command_arg)
        exit 0
      when :clear_context
        handle_clear_context
        exit 0
      when :list_tasks
        handle_list_tasks
        exit 0
      when :add_task
        handle_add_task(command_arg)
        exit 0
      when :remove_task
        handle_remove_task(command_arg)
        exit 0
      end

      # Resolve prompt from file or positional args
      resolve_prompt!(options, prompt_parts)

      # Validate
      if options[:max_iterations] > 0 && options[:min_iterations] > options[:max_iterations]
        abort "Error: --min-iterations (#{options[:min_iterations]}) cannot be greater than --max-iterations (#{options[:max_iterations]})"
      end

      Ralph::Loop.new.call(**options)
    rescue OptionParser::ParseError => e
      abort "#{e.message}\nRun 'ralph --help' for available options"
    rescue StandardError => e
      $stderr.puts "Fatal error: #{e}"
      State.clear_state
      exit 1
    end

    def build_parser(options)
      OptionParser.new do |o|
        o.banner = <<~BANNER
          Ralph Wiggum Loop - Iterative AI development with AI agents

          Usage:
            ralph "<prompt>" [options]
            ralph --prompt-file <path> [options]

          Commands:
            --status            Show current Ralph loop status and history
            --add-context TEXT  Add context for the next iteration
            --clear-context     Clear any pending context
            --list-tasks        Display the current task list with indices
            --add-task "desc"   Add a new task to the list
            --remove-task N     Remove task at index N (including subtasks)

          Options:
        BANNER

        o.on("--agent AGENT", Agents.valid_agent_names, "AI agent: #{Agents.valid_agent_names.join(', ')} (default: opencode)") do |v|
          options[:agent_type] = v
        end

        o.on("--min-iterations N", Integer, "Minimum iterations before completion (default: 1)") do |v|
          options[:min_iterations] = v
        end

        o.on("--max-iterations N", Integer, "Maximum iterations before stopping (default: unlimited)") do |v|
          options[:max_iterations] = v
        end

        o.on("--completion-promise TEXT", "Phrase that signals completion (default: COMPLETE)") do |v|
          options[:completion_promise] = v
        end

        o.on("-t", "--tasks", "Enable Tasks Mode for structured task tracking") do
          options[:tasks_mode] = true
        end

        o.on("--task-promise TEXT", "Phrase that signals task completion (default: READY_FOR_NEXT_TASK)") do |v|
          options[:task_promise] = v
        end

        o.on("--model MODEL", "Model to use (agent-specific)") do |v|
          options[:model] = v
        end

        o.on("-f", "--prompt-file PATH", "--file PATH", "Read prompt content from a file") do |v|
          options[:prompt_file] = v
        end

        o.on("--[no-]stream", "Stream agent output in real-time (default: on)") do |v|
          options[:stream_output] = v
        end

        o.on("--verbose-tools", "Print every tool line (disable compact summary)") do
          options[:verbose_tools] = true
        end

        o.on("--no-plugins", "Disable non-auth OpenCode plugins (opencode only)") do
          options[:disable_plugins] = true
        end

        o.on("--[no-]commit", "Auto-commit after each iteration (default: on)") do |v|
          options[:auto_commit] = v
        end

        o.on("--[no-]allow-all", "Auto-approve all tool permissions (default: on)") do |v|
          options[:allow_all_permissions] = v
        end

        # Subcommands -- these set a command to dispatch after parsing
        o.on("-v", "--version", "Show version") do
          yield :version, nil
        end

        o.on("--status", "Show current loop status and history") do
          yield :status, nil
        end

        o.on("--add-context TEXT", "Add context for the next iteration") do |v|
          yield :add_context, v
        end

        o.on("--clear-context", "Clear any pending context") do
          yield :clear_context, nil
        end

        o.on("--list-tasks", "Display the current task list") do
          yield :list_tasks, nil
        end

        o.on("--add-task DESC", "Add a new task to the list") do |v|
          yield :add_task, v
        end

        o.on("--remove-task N", Integer, "Remove task at index N") do |v|
          yield :remove_task, v
        end

        o.separator ""
        o.separator "Examples:"
        o.separator '  ralph "Build a REST API for todos"'
        o.separator '  ralph "Fix the auth bug" --max-iterations 10'
        o.separator '  ralph "Add tests" --completion-promise "ALL TESTS PASS" --model openai/gpt-5.1'
        o.separator '  ralph --prompt-file ./prompt.md --max-iterations 5'
        o.separator '  ralph --status'
        o.separator '  ralph --add-context "Focus on the auth module first"'
        o.separator ""
        o.separator "How it works:"
        o.separator "  1. Sends your prompt to the selected AI agent"
        o.separator "  2. AI agent works on the task"
        o.separator "  3. Checks output for completion promise"
        o.separator "  4. If not complete, repeats with same prompt"
        o.separator "  5. AI sees its previous work in files"
        o.separator "  6. Continues until promise detected or max iterations"
        o.separator ""
        o.separator "To stop manually: Ctrl+C"
        o.separator "Learn more: https://ghuntley.com/ralph/"
      end
    end

    def resolve_prompt!(options, prompt_parts)
      if !options[:prompt_file].empty?
        options[:prompt_source] = options[:prompt_file]
        options[:prompt] = read_prompt_file(options[:prompt_file])
      elsif prompt_parts.length == 1 && File.exist?(prompt_parts[0])
        options[:prompt_source] = prompt_parts[0]
        options[:prompt] = read_prompt_file(prompt_parts[0])
      else
        options[:prompt] = prompt_parts.join(" ")
      end

      if options[:prompt].empty?
        abort "Error: No prompt provided\nUsage: ralph \"Your task description\" [options]\nRun 'ralph --help' for more information"
      end
    end

    # --- Command handlers ---

    def show_status(options)
      state = State.load_state
      history = State.load_history
      context = State.load_context
      show_tasks = options[:tasks_mode] || state&.tasks_mode

      puts <<~HEADER

        \u2554#{"=" * 66}\u2557
        \u2551                    Ralph Wiggum Status                           \u2551
        \u255A#{"=" * 66}\u255D
      HEADER

      if state&.active
        elapsed = Helpers.now_ms - (Time.parse(state.started_at).to_f * 1000).to_i
        elapsed_str = Helpers.format_duration_long(elapsed)
        puts "\u{1F504} ACTIVE LOOP"
        max_str = state.max_iterations > 0 ? " / #{state.max_iterations}" : " (unlimited)"
        puts "   Iteration:    #{state.iteration}#{max_str}"
        puts "   Started:      #{state.started_at}"
        puts "   Elapsed:      #{elapsed_str}"
        puts "   Promise:      #{state.completion_promise}"
        agent_label = if state.agent
          cfg = Agents.resolve(state.agent)
          cfg ? cfg.config_name : state.agent
        else
          "OpenCode"
        end
        puts "   Agent:        #{agent_label}"
        puts "   Model:        #{state.model}" if state.model && !state.model.empty?
        if state.tasks_mode
          puts "   Tasks Mode:   ENABLED"
          puts "   Task Promise: #{state.task_promise}"
        end
        prompt_preview = state.prompt[0, 60] + (state.prompt.length > 60 ? "..." : "")
        puts "   Prompt:       #{prompt_preview}"
      else
        puts "\u23F9\uFE0F  No active loop"
      end

      if context
        puts "\n\u{1F4DD} PENDING CONTEXT (will be injected next iteration):"
        puts "   #{context.split("\n").join("\n   ")}"
      end

      if show_tasks
        if File.exist?(State.tasks_path)
          begin
            tasks_content = File.read(State.tasks_path)
            tasks = Tasks.parse(tasks_content)
            if tasks.any?
              puts "\n\u{1F4CB} CURRENT TASKS:"
              tasks.each_with_index do |task, i|
                icon = Tasks.status_icon(task.status)
                puts "   #{i + 1}. #{icon} #{task.text}"
                task.subtasks.each do |subtask|
                  sub_icon = Tasks.status_icon(subtask.status)
                  puts "      #{sub_icon} #{subtask.text}"
                end
              end
              complete = tasks.count { |t| t.status == :complete }
              in_progress = tasks.count { |t| t.status == :in_progress }
              puts "\n   Progress: #{complete}/#{tasks.length} complete, #{in_progress} in progress"
            else
              puts "\n\u{1F4CB} CURRENT TASKS: (no tasks found)"
            end
          rescue StandardError
            puts "\n\u{1F4CB} CURRENT TASKS: (error reading tasks)"
          end
        else
          puts "\n\u{1F4CB} CURRENT TASKS: (no tasks file found)"
        end
      end

      if history.iterations.any?
        puts "\n\u{1F4CA} HISTORY (#{history.iterations.length} iterations)"
        puts "   Total time:   #{Helpers.format_duration_long(history.total_duration_ms)}"

        recent = history.iterations.last(5)
        puts "\n   Recent iterations:"
        recent.each do |iter|
          tools = iter.tools_used
                    .sort_by { |_, v| -v }
                    .first(3)
                    .map { |k, v| "#{k}:#{v}" }
                    .join(" ")
          status_icon = if iter.completion_detected
            "\u2705"
          elsif iter.exit_code != 0
            "\u274C"
          else
            "\u{1F504}"
          end
          puts "   #{status_icon} ##{iter.iteration}: #{Helpers.format_duration_long(iter.duration_ms)} | #{tools.empty? ? "no tools" : tools}"
        end

        si = history.struggle_indicators
        has_repeated = si.repeated_errors.values.any? { |c| c >= 2 }
        if si.no_progress_iterations >= 3 || si.short_iterations >= 3 || has_repeated
          puts "\n\u26A0\uFE0F  STRUGGLE INDICATORS:"
          if si.no_progress_iterations >= 3
            puts "   - No file changes in #{si.no_progress_iterations} iterations"
          end
          if si.short_iterations >= 3
            puts "   - #{si.short_iterations} very short iterations (< 30s)"
          end
          top_errors = si.repeated_errors
                         .select { |_, count| count >= 2 }
                         .sort_by { |_, count| -count }
                         .first(3)
          top_errors.each do |error, count|
            puts "   - Same error #{count}x: \"#{error[0, 50]}...\""
          end
          puts "\n   \u{1F4A1} Consider using: ralph --add-context \"your hint here\""
        end
      end

      puts ""
    end

    def handle_add_context(context_text)
      FileUtils.mkdir_p(State.state_dir)
      timestamp = Time.now.utc.iso8601
      new_entry = "\n## Context added at #{timestamp}\n#{context_text}\n"

      if File.exist?(State.context_path)
        existing = File.read(State.context_path)
        File.write(State.context_path, existing + new_entry)
      else
        File.write(State.context_path, "# Ralph Loop Context\n#{new_entry}")
      end

      puts "\u2705 Context added for next iteration"
      puts "   File: #{State.context_path}"

      state = State.load_state
      if state&.active
        puts "   Will be picked up in iteration #{state.iteration + 1}"
      else
        puts "   Will be used when loop starts"
      end
    end

    def handle_clear_context
      if File.exist?(State.context_path)
        File.delete(State.context_path)
        puts "\u2705 Context cleared"
      else
        puts "\u2139\uFE0F  No pending context to clear"
      end
    end

    def handle_list_tasks
      unless File.exist?(State.tasks_path)
        puts "No tasks file found. Use --add-task to create your first task."
        return
      end

      begin
        content = File.read(State.tasks_path)
        tasks = Tasks.parse(content)
        Tasks.display_with_indices(tasks)
      rescue StandardError => e
        $stderr.puts "Error reading tasks file: #{e}"
        exit 1
      end
    end

    def handle_add_task(description)
      FileUtils.mkdir_p(State.state_dir)

      begin
        content = if File.exist?(State.tasks_path)
          File.read(State.tasks_path)
        else
          "# Ralph Tasks\n\n"
        end

        new_content = content.rstrip + "\n" + "- [ ] #{description}\n"
        File.write(State.tasks_path, new_content)
        puts "\u2705 Task added: \"#{description}\""
      rescue StandardError => e
        $stderr.puts "Error adding task: #{e}"
        exit 1
      end
    end

    def handle_remove_task(task_index)
      unless File.exist?(State.tasks_path)
        $stderr.puts "Error: No tasks file found"
        exit 1
      end

      begin
        content = File.read(State.tasks_path)
        tasks = Tasks.parse(content)

        if task_index < 1 || task_index > tasks.length
          $stderr.puts "Error: Task index #{task_index} is out of range (1-#{tasks.length})"
          exit 1
        end

        lines = content.split("\n")
        new_lines = []
        in_removed_task = false
        current_task_line = 0

        lines.each do |line|
          if line.match?(/^- \[/)
            current_task_line += 1
            if current_task_line == task_index
              in_removed_task = true
              next
            else
              in_removed_task = false
            end
          end

          # Skip indented content under removed task
          if in_removed_task && line.match?(/^\s+/) && !line.strip.empty?
            next
          end

          new_lines << line
        end

        File.write(State.tasks_path, new_lines.join("\n"))
        puts "\u2705 Removed task #{task_index} and its subtasks"
      rescue StandardError => e
        $stderr.puts "Error removing task: #{e}"
        exit 1
      end
    end

    def read_prompt_file(path)
      unless File.exist?(path)
        abort "Error: Prompt file not found: #{path}"
      end

      unless File.file?(path)
        abort "Error: Prompt path is not a file: #{path}"
      end

      content = File.read(path)
      if content.strip.empty?
        abort "Error: Prompt file is empty: #{path}"
      end

      content
    rescue Errno::EACCES
      abort "Error: Unable to read prompt file: #{path}"
    end
  end
end
