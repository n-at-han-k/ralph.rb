# frozen_string_literal: true

module Ralph
  module Prompt
    # The building prompt -- the heart of ralph. Instructs the agent to study
    # specs, read the plan, pick ONE task, implement it, validate, update the
    # plan, commit, and signal task-done.
    #
    # Responds to #to_s returning the complete prompt text for one iteration.
    class Build
      DEFAULT_TASK_DONE = "<task>DONE</task>"
      DEFAULT_ALL_DONE = "<promise>COMPLETE</promise>"

      attr_reader :task_done, :all_done

      def initialize(task_done: DEFAULT_TASK_DONE, all_done: DEFAULT_ALL_DONE, context: nil)
        @task_done = task_done
        @all_done = all_done
        @context = context
      end

      def to_s
        prompt = format(TEMPLATE, task_done: @task_done, all_done: @all_done)
        if @context && !@context.strip.empty?
          "#{prompt}\n\n---\n\n#{@context}"
        else
          prompt
        end
      end

      private

      TEMPLATE = <<~PROMPT
        0a. Study `specs/*` to learn the application specifications.
        0b. Study the plans in `plans/`.
        0c. For reference, the application source code is in `lib/*`.

        1. Your task is to implement ONE item from the plans. Follow the plans in `plans/` and choose the most important item to address. Before making changes, search the codebase (don't assume not implemented).
        2. After implementing functionality or resolving problems, run the tests and checks for that unit of code that was improved. If functionality is missing then it's your job to add it as per the application specifications. Think carefully.
        3. When you discover issues, immediately update the plans in `plans/` with your findings. When resolved, update and remove the item.
        4. When the tests pass, update the plans in `plans/`, then `git add -A` then `git commit` with a message describing the changes. After the commit, `git push`.
        5. After committing, output the task-done signal on its own line: %{task_done}
        6. If there are no remaining items in the plans, output the all-done signal instead: %{all_done}

        99999. Important: When authoring documentation, capture the why -- tests and implementation importance.
        999999. Important: Single sources of truth, no migrations/adapters. If tests unrelated to your work fail, resolve them as part of the increment.
        9999999. As soon as there are no build or test errors create a git tag. If there are no git tags start at 0.0.0 and increment patch by 1 for example 0.0.1 if 0.0.0 does not exist.
        99999999. You may add extra logging if required to debug issues.
        999999999. Keep the plans in `plans/` current with learnings -- future work depends on this to avoid duplicating efforts. Update especially after finishing your turn.
        9999999999. When you learn something new about how to run the application, update @AGENTS.md but keep it brief. For example if you run commands multiple times before learning the correct command then that file should be updated.
        99999999999. For any bugs you notice, resolve them or document them in the plans even if it is unrelated to the current piece of work.
        999999999999. Implement functionality completely. Placeholders and stubs waste efforts and time redoing the same work.
        9999999999999. When plans become large periodically clean out the items that are completed.
        99999999999999. If you find inconsistencies in the specs/* then carefully update the specs.
        999999999999999. IMPORTANT: Keep @AGENTS.md operational only -- status updates and progress notes belong in the plans. A bloated AGENTS.md pollutes every future loop's context.
        9999999999999999. IMPORTANT: Do ONE task per iteration. Pick it, do it, commit it, signal task-done. Do not continue to the next task -- the loop will start a fresh iteration for that.
      PROMPT
    end
  end
end
