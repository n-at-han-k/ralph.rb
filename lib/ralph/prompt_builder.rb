# frozen_string_literal: true

module Ralph
  module PromptBuilder
    module_function

    def build(state, _agent)
      context = State.load_context
      context_section = if context
        <<~SECTION

          ## Additional Context (added by user mid-loop)

          #{context}

          ---
        SECTION
      else
        ""
      end

      if state.tasks_mode
        tasks_section = build_tasks_section(state)
        <<~PROMPT.strip
          # Ralph Wiggum Loop - Iteration #{state.iteration}

          You are in an iterative development loop working through a task list.
          #{context_section}#{tasks_section}
          ## Your Main Goal

          #{state.prompt}

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
      else
        <<~PROMPT.strip
          # Ralph Wiggum Loop - Iteration #{state.iteration}

          You are in an iterative development loop. Work on the task below until you can genuinely complete it.
          #{context_section}
          ## Your Task

          #{state.prompt}

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
    end

    def build_tasks_section(state)
      tasks_path = State.tasks_path
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

        task_instructions = if current_task
          <<~INST
            \u{1F504} CURRENT TASK: "#{current_task.text}"
               Focus on completing this specific task.
               When done: Mark as [x] in .ralph/ralph-tasks.md and output <promise>#{state.task_promise}</promise>
          INST
        elsif next_task
          <<~INST
            \u{1F4CD} NEXT TASK: "#{next_task.text}"
               Mark as [/] in .ralph/ralph-tasks.md before starting.
               When done: Mark as [x] and output <promise>#{state.task_promise}</promise>
          INST
        elsif tasks.all_complete?
          <<~INST
            \u2705 ALL TASKS COMPLETE!
               Output <promise>#{state.completion_promise}</promise> to finish.
          INST
        else
          <<~INST
            \u{1F4CB} No tasks found. Add tasks to .ralph/ralph-tasks.md or use `ralph --add-task`
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
  end
end
