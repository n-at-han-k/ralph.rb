# frozen_string_literal: true

module Ralph
  class CLI
    def initialize(**options)
      @config = Config.new(**options)
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
          @config.agent_type = v
        end

        o.on("--min-iterations N", Integer, "Minimum iterations before completion (default: 1)") do |v|
          @config.min_iterations = v
        end

        o.on("--max-iterations N", Integer, "Maximum iterations before stopping (default: unlimited)") do |v|
          @config.max_iterations = v
        end

        o.on("--completion-promise TEXT", "Phrase that signals completion (default: COMPLETE)") do |v|
          @config.completion_promise = v
        end

        o.on("-t", "--tasks", "Enable Tasks Mode for structured task tracking") do
          @config.tasks_mode = true
        end

        o.on("--task-promise TEXT", "Phrase that signals task completion (default: READY_FOR_NEXT_TASK)") do |v|
          @config.task_promise = v
        end

        o.on("--model MODEL", "Model to use (agent-specific)") do |v|
          @config.model = v
        end

        o.on("-f", "--prompt-file PATH", "--file PATH", "Read prompt content from a file") do |v|
          @config.prompt_file = v
        end

        o.on("--[no-]stream", "Stream agent output in real-time (default: on)") do |v|
          @config.stream_output = v
        end

        o.on("--verbose-tools", "Print every tool line (disable compact summary)") do
          @config.verbose_tools = true
        end

        o.on("--no-plugins", "Disable non-auth OpenCode plugins (opencode only)") do
          @config.disable_plugins = true
        end

        o.on("--[no-]commit", "Auto-commit after each iteration (default: on)") do |v|
          @config.auto_commit = v
        end

        o.on("--[no-]allow-all", "Auto-approve all tool permissions (default: on)") do |v|
          @config.allow_all_permissions = v
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
        # Skip prompt resolution for subcommands that don't need a prompt
        unless command
          begin
            Prompt.from_parts(prompt_parts, prompt_file: @config.prompt_file).then do |prompt|
              if prompt.empty?
                abort "
                  Error: No prompt provided
                  Usage: ralph 'Your task description' [options]
                  Run 'ralph --help' for more information
                "
              end

              @config.prompt = prompt
            end
          rescue Prompt::Error => e
            abort e.message
          end
        end
      end

      # Dispatch subcommands
      case command
      when :version
        puts "ralph #{VERSION}"
        exit 0
      when :status
        Output::Status.call(options: @config.to_h)

        exit 0
      when :add_context
        add_context(command_arg)
        exit 0
      when :clear_context
        clear_context
        exit 0
      when :list_tasks
        list_tasks
        exit 0
      when :add_task
        add_task(command_arg)
        exit 0
      when :remove_task
        remove_task(command_arg)
        exit 0
      end

      if @config.max_iterations > 0 && @config.min_iterations > @config.max_iterations
        abort "Error: --min-iterations (#{@config.min_iterations}) cannot be greater than --max-iterations (#{@config.max_iterations})"
      end

      Ralph::Loop.new.call(@config)

    rescue OptionParser::ParseError => e
      abort "#{e.message}\nRun 'ralph --help' for available options"

    rescue StandardError => e
      $stderr.puts "Fatal error: #{e}"
      Storage::State.clear
      exit 1

    end

    private

      def add_context(context_text)
        timestamp = Time.now.utc.iso8601
        new_entry = "\n## Context added at #{timestamp}\n#{context_text}\n"
        Storage::Context.new.append(new_entry)

        puts "✅ Context added for next iteration"
        puts "   File: #{Storage::Context.new.path}"

        Storage::State.load.then do |state|
          if state&.active
            puts "   Will be picked up in iteration #{state.iteration + 1}"
          else
            puts "   Will be used when loop starts"
          end
        end
      end

      def clear_context
        context = Storage::Context.new
        if context.present?
          context.clear
          puts "✅ Context cleared"
        else
          puts "ℹ️  No pending context to clear"
        end
      end

      def list_tasks
        Storage::Tasks.load_tasks.then do |tasks|
          unless tasks
            puts "No tasks file found. Use --add-task to create your first task."
            return
          end

          tasks.display_with_indices
        end
      rescue StandardError => e
        $stderr.puts "Error reading tasks file: #{e}"
        exit 1
      end

      def add_task(description)
        Storage::Tasks.add_task(description)
        puts "✅ Task added: \"#{description}\""
      rescue StandardError => e
        $stderr.puts "Error adding task: #{e}"
        exit 1
      end

      def remove_task(task_index)
        Storage::Tasks.remove_task(task_index)
        puts "✅ Removed task #{task_index} and its subtasks"
      rescue IndexError => e
        $stderr.puts "Error: #{e.message}"
        exit 1
      rescue RuntimeError => e
        $stderr.puts "Error: #{e.message}"
        exit 1
      rescue StandardError => e
        $stderr.puts "Error removing task: #{e}"
        exit 1
      end
  end
end
