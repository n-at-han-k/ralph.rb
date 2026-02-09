# frozen_string_literal: true

module Ralph
  module Prompt
    # The planning prompt -- instructs the agent to study specs, compare against
    # code, and produce a prioritized task list in plans/. It does NOT implement
    # anything. It does NOT commit anything.
    #
    # Responds to #to_s returning the complete prompt text for one iteration.
    class Plan
      DEFAULT_ALL_DONE = "<promise>COMPLETE</promise>"
      DEFAULT_GOAL = "Consider missing elements and plan accordingly. " \
                     "If an element is missing, search first to confirm it doesn't exist, " \
                     "then if needed author the specification at specs/FILENAME.md."

      attr_reader :all_done

      def initialize(goal: nil, all_done: DEFAULT_ALL_DONE)
        @goal = goal && !goal.strip.empty? ? goal : DEFAULT_GOAL
        @all_done = all_done
      end

      # Plan mode has no task-done signal
      def task_done
        nil
      end

      def to_s
        format(TEMPLATE, goal: @goal, all_done: @all_done)
      end

      private

      TEMPLATE = <<~PROMPT
        0a. Study `specs/*` to learn the application specifications.
        0b. Study the plans in `plans/` (if present) to understand the plan so far.
        0c. Study `lib/*` to understand the existing codebase and shared utilities.

        1. Study the plans in `plans/` (if present; they may be incorrect) and study existing source code in `lib/*` and compare it against `specs/*`. Analyze findings, prioritize tasks, and create/update the plans in `plans/` as bullet point lists sorted in priority of items yet to be implemented. Think carefully. Consider searching for TODO, minimal implementations, placeholders, skipped/flaky tests, and inconsistent patterns. Study the plans to determine the starting point for research and keep them up to date with items considered complete/incomplete.

        IMPORTANT: Plan only. Do NOT implement anything. Do NOT assume functionality is missing; confirm with code search first.

        ULTIMATE GOAL: %{goal}

        When you have completed the plan, output the exact completion string on its own line: %{all_done}
      PROMPT
    end
  end
end
