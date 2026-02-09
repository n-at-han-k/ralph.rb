# frozen_string_literal: true

module Ralph
  # The core iteration engine. Runs opencode in a loop, restarting fresh
  # iterations whenever context grows too large or time limits are hit.
  # The loop ends when:
  #   - the agent emits the all-done completion string
  #   - max iterations are reached
  #   - total duration is exceeded
  #
  # An iteration ends early (and a fresh one begins) when:
  #   - the agent emits the task-done string (build mode only)
  #   - context limit is exceeded
  class Loop
    attr_reader :metrics, :iteration_number, :completed, :iteration_outcomes

    def initialize(options)
      @prompt = options[:prompt]
      @model = options[:model]
      @max_iterations = options[:max_iterations]
      @duration_limit = options[:duration]
      @max_context = options[:max_context]
      @all_done_string = resolve_all_done_string(options)
      @task_done_string = resolve_task_done_string
      @metrics = Metrics.new
      @iteration_number = 0
      @completed = false
      @iteration_outcomes = []
      @started_at = nil
      @display = Display.new(self)
    end

    # Run the main loop until a termination condition is met.
    def run
      @started_at = now_seconds
      @display.show_start(prompt_text)

      loop do
        break if should_stop_loop?

        @iteration_number += 1
        @metrics.new_iteration
        @display.show_iteration_start

        iteration = run_iteration

        @iteration_outcomes << { number: iteration.number, outcome: iteration.outcome }
        @display.show_iteration_end

        if iteration.all_done?
          @completed = true
        end
      end

      @display.show_summary
      @completed
    end

    # Total elapsed wall-clock seconds since the loop started
    def elapsed_seconds
      if @started_at
        now_seconds - @started_at
      else
        0.0
      end
    end

    private

    # Read all-done string from the prompt object if it responds to it,
    # falling back to the CLI --completion option or the default.
    def resolve_all_done_string(options)
      if options[:completion]
        options[:completion]
      elsif @prompt.respond_to?(:all_done) && @prompt.all_done
        @prompt.all_done
      else
        Prompt::Build::DEFAULT_ALL_DONE
      end
    end

    # Read task-done string from the prompt object. Plan prompts return nil,
    # meaning the loop will not watch for task-done signals.
    def resolve_task_done_string
      if @prompt.respond_to?(:task_done)
        @prompt.task_done
      else
        nil
      end
    end

    def prompt_text
      @prompt.to_s
    end

    def should_stop_loop?
      if @completed
        true
      elsif @max_iterations && @iteration_number >= @max_iterations
        @display.show_termination("max iterations reached (#{@max_iterations})")
        true
      elsif duration_exceeded?
        @display.show_termination("duration limit reached (#{@duration_limit}s)")
        true
      else
        false
      end
    end

    def run_iteration
      iteration = Iteration.new(
        number: @iteration_number,
        prompt_text: prompt_text,
        model: @model,
        task_done_string: @task_done_string,
        all_done_string: @all_done_string,
        metrics: @metrics,
        display: @display
      )

      iteration.run(
        max_context: @max_context,
        duration_exceeded: -> { duration_exceeded? }
      )

      iteration
    end

    def duration_exceeded?
      @duration_limit && elapsed_seconds >= @duration_limit
    end

    def now_seconds
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end
  end
end
