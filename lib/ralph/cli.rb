# frozen_string_literal: true

module Ralph
  class CLI
    def initialize
      @options = {
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
    end

    def run(argv = ARGV)
      # Subcommand state -- set by flags, dispatched after parsing
      command = nil
      command_arg = nil

      parser = OptionParser.new do |o|
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
          @options[:agent_type] = v
        end

        o.on("--min-iterations N", Integer, "Minimum iterations before completion (default: 1)") do |v|
          @options[:min_iterations] = v
        end

        o.on("--max-iterations N", Integer, "Maximum iterations before stopping (default: unlimited)") do |v|
          @options[:max_iterations] = v
        end

        o.on("--completion-promise TEXT", "Phrase that signals completion (default: COMPLETE)") do |v|
          @options[:completion_promise] = v
        end

        o.on("-t", "--tasks", "Enable Tasks Mode for structured task tracking") do
          @options[:tasks_mode] = true
        end

        o.on("--task-promise TEXT", "Phrase that signals task completion (default: READY_FOR_NEXT_TASK)") do |v|
          @options[:task_promise] = v
        end

        o.on("--model MODEL", "Model to use (agent-specific)") do |v|
          @options[:model] = v
        end

        o.on("-f", "--prompt-file PATH", "--file PATH", "Read prompt content from a file") do |v|
          @options[:prompt_file] = v
        end

        o.on("--[no-]stream", "Stream agent output in real-time (default: on)") do |v|
          @options[:stream_output] = v
        end

        o.on("--verbose-tools", "Print every tool line (disable compact summary)") do
          @options[:verbose_tools] = true
        end

        o.on("--no-plugins", "Disable non-auth OpenCode plugins (opencode only)") do
          @options[:disable_plugins] = true
        end

        o.on("--[no-]commit", "Auto-commit after each iteration (default: on)") do |v|
          @options[:auto_commit] = v
        end

        o.on("--[no-]allow-all", "Auto-approve all tool permissions (default: on)") do |v|
          @options[:allow_all_permissions] = v
        end

        # Subcommands -- these set a command to dispatch after parsing
        o.on("-v", "--version", "Show version") do
          command = :version
          command_arg = nil
        end

        o.on("--status", "Show current loop status and history") do
          command = :status
          command_arg = nil
        end

        o.on("--add-context TEXT", "Add context for the next iteration") do |v|
          command = :add_context
          command_arg = v
        end

        o.on("--clear-context", "Clear any pending context") do
          command = :clear_context
          command_arg = nil
        end

        o.on("--list-tasks", "Display the current task list") do
          command = :list_tasks
          command_arg = nil
        end

        o.on("--add-task DESC", "Add a new task to the list") do |v|
          command = :add_task
          command_arg = v
        end

        o.on("--remove-task N", Integer, "Remove task at index N") do |v|
          command = :remove_task
          command_arg = v
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

      parser.parse(argv.dup).then do |prompt_parts|
        begin
          Prompt.from_parts(prompt_parts, prompt_file: @options[:prompt_file]).then do |prompt|
            if prompt.empty?
              abort "
                Error: No prompt provided
                Usage: ralph 'Your task description' [options]
                Run 'ralph --help' for more information
              "
            end

            @options[:prompt] = prompt.to_s
            @options[:prompt_source] = prompt.source
          end
        rescue Prompt::Error => e
          abort e.message
        end
      end


      # Dispatch subcommands
      case command
      when :version
        puts "ralph #{VERSION}"
        exit 0
      when :status
        show_status(@options)
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

      # Validate
      if @options[:max_iterations] > 0 && @options[:min_iterations] > @options[:max_iterations]
        abort "Error: --min-iterations (#{@options[:min_iterations]}) cannot be greater than --max-iterations (#{@options[:max_iterations]})"
      end

      # Remove prompt_file from options as Loop doesn't accept it
      loop_options = @options.reject { |key, _| key == :prompt_file }
      Ralph::Loop.new.call(**loop_options)

    rescue OptionParser::ParseError => e
      abort "#{e.message}\nRun 'ralph --help' for available options"

    rescue StandardError => e
      $stderr.puts "Fatal error: #{e}"
      State.clear_state
      exit 1

    end

    private

      def show_status(options = @options)
        Output::Status.call(options: options)
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
          tasks.display_with_indices
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
  end
end
