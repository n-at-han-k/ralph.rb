# frozen_string_literal: true

module Ralph
  class Prompt
    class Error < StandardError; end

    attr_reader :text, :source

    def initialize(text, source: "")
      @text = text
      @source = source
    end

    def to_s = @text
    def empty? = @text.strip.empty?
    def from_file? = !@source.empty?

    def context_section
      @_context_section ||= Storage::Context.new.then do |context|
        if context.present?
          "
            ## Additional Context (added by user mid-loop)

            #{context.content}

            ---
          "
        else
          ""
        end
      end
    end

    def task_mode_prompt
      tasks_section = build_tasks_section(state)
      <<~PROMPT.strip
        # Ralph Wiggum Loop - Iteration #{state.iteration}

        You are in an iterative development loop working through a task list.
        #{context_section}#{tasks_section}
        ## Your Main Goal

        #{@text}

        ## Critical Rules

        - Work on ONE task at a time from .ralph/ralph-tasks.md
        - ONLY output <promise>#{state.task_promise}</promise> when the current task is complete and marked in ralph-tasks.md
        - ONLY output <promise>#{state.completion_promise}</promise> when ALL tasks are truly done
        - Do NOT lie or output false promises to exit the loop
        - If stuck, try a different approach
        - Check your work before claiming completion

        ## Current Iteration: #{state.iteration}#{state.max_iterations > 0 ? " / #{state.max_iterations}" : " (unlimited)"} (min: #{state.min_iterations || 1})

        Tasks Mode: ENABLED - Work on one task at a time from ralph-tasks.md

        Now, work on the current task. Good luck!
      PROMPT
    end

    def non_task_mode_prompt
      <<~PROMPT.strip
        # Ralph Wiggum Loop - Iteration #{state.iteration}

        You are in an iterative development loop. Work on the task below until you can genuinely complete it.
        #{context_section}
        ## Your Task

        #{@text}

        ## Instructions

        1. Read the current state of files to understand what's been done
        2. Track your progress and plan remaining work
        3. Make progress on the task
        4. Run tests/verification if applicable
        5. When the task is GENUINELY COMPLETE, output:
           <promise>#{state.completion_promise}</promise>

        ## Critical Rules

        - ONLY output <promise>#{state.completion_promise}</promise> when the task is truly done
        - Do NOT lie or output false promises to exit the loop
        - If stuck, try a different approach
        - Check your work before claiming completion
        - The loop will continue until you succeed

        ## Current Iteration: #{state.iteration}#{state.max_iterations > 0 ? " / #{state.max_iterations}" : " (unlimited)"} (min: #{state.min_iterations || 1})

        Now, work on the task. Good luck!
      PROMPT
    end

    # Build the full iteration prompt sent to the LLM.
    # +state+ is a Storage::State with iteration metadata.
    # +_agent+ is the agent config (reserved for future use).
    def build_iteration(state, _agent)
      if state.tasks_mode
        task_mode_prompt
      else
        non_task_mode_prompt
      end
    end

    private

      def build_tasks_section(state)
        tasks_path = Storage::Tasks.new.path
        unless File.exist?(tasks_path)
          return <<~SECTION

            ## TASKS MODE: Enabled (no tasks file found)

            Create .ralph/ralph-tasks.md with your task list, or use `ralph --add-task "description"` to add tasks.
          SECTION
        end

        begin
           tasks_content = File.read(tasks_path)
           tasks = Tasks.parse(tasks_content)
           current_task = tasks.current
           next_task = tasks.next

           task_instructions =
             if current_task
               <<~INST
                🔄 CURRENT TASK: "#{current_task.text}"
                   Focus on completing this specific task.
                   When done: Mark as [x] in .ralph/ralph-tasks.md and output <promise>#{state.task_promise}</promise>
              INST
             elsif next_task
               <<~INST
                📍 NEXT TASK: "#{next_task.text}"
                   Mark as [/] in .ralph/ralph-tasks.md before starting.
                   When done: Mark as [x] and output <promise>#{state.task_promise}</promise>
              INST
             elsif tasks.all_complete?
               <<~INST
                ✅ ALL TASKS COMPLETE!
                   Output <promise>#{state.completion_promise}</promise> to finish.
              INST
             else
               <<~INST
                📋 No tasks found. Add tasks to .ralph/ralph-tasks.md or use `ralph --add-task`
              INST
             end

           <<~SECTION

            ## TASKS MODE: Working through task list

            Current tasks from .ralph/ralph-tasks.md:
            ```markdown
            #{tasks_content.strip}
            ```
            #{task_instructions}
            ### Task Workflow
            1. Find any task marked [/] (in progress). If none, pick the first [ ] task.
            2. Mark the task as [/] in ralph-tasks.md before starting.
            3. Complete the task.
            4. Mark as [x] when verified complete.
            5. Output <promise>#{state.task_promise}</promise> to move to the next task.
            6. Only output <promise>#{state.completion_promise}</promise> when ALL tasks are [x].

            ---
          SECTION
         rescue StandardError
           <<~SECTION

            ## TASKS MODE: Error reading tasks file

            Unable to read .ralph/ralph-tasks.md
          SECTION
        end
      end

      class << self
        def from_parts(parts, prompt_file: nil)

          if prompt_file && !prompt_file.empty?
            from_file(prompt_file)

          elsif parts.length == 1 && File.exist?(parts[0])
            from_file(parts[0])

          else
            new(parts.join(" "), source: "")
          end

        rescue Errno::EACCES
          raise Error, "Unable to read prompt file: #{path}"
          new(content, source: path)
        end

        private

          def from_file(path)
            unless File.exist?(path)
              raise Error, "Prompt file not found: #{path}"
            end

            unless File.file?(path)
              raise Error, "Prompt path is not a file: #{path}"
            end

            File.read(path).then do |content|
              if content.strip.empty?
                raise Error, "Prompt file is empty: #{path}"
              end

              new(content, source: path)
            end
          end
      end
  end
end
