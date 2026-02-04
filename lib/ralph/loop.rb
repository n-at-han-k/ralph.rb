# frozen_string_literal: true

module Ralph
  # The core iteration engine. Runs opencode in a loop, restarting fresh
  # iterations whenever context grows too large or time limits are hit.
  # The loop ends when:
  #   - the agent emits the completion string
  #   - max iterations are reached
  #   - total duration is exceeded
  class Loop
    SYSTEM_PROMPT = <<~PROMPT
      You are working autonomously in a loop. IMPORTANT RULES:
      1. Do NOT ask the user any questions. Do NOT wait for user input.
         If you need information, read the specs, code, or docs yourself.
      2. Work through the task methodically. Use the todo list to track progress.
      3. When you have FULLY completed the task, you MUST output the exact
         completion string on its own line: %<completion>s
      4. Do not output the completion string until ALL work is truly done.
    PROMPT

    attr_reader :metrics, :iteration_number, :completed

    def initialize(options)
      @prompt = options[:prompt]
      @model = options[:model]
      @max_iterations = options[:max_iterations]
      @duration_limit = options[:duration]
      @max_context = options[:max_context]
      @completion_string = options[:completion] || "<promise>COMPLETE</promise>"
      @metrics = Metrics.new
      @iteration_number = 0
      @completed = false
      @started_at = nil
      @display = Display.new(self)
    end

    # Run the main loop until a termination condition is met.
    def run
      @started_at = now_seconds
      @display.show_start(@prompt)

      loop do
        break if should_stop_loop?

        @iteration_number += 1
        @metrics.new_iteration
        @display.show_iteration_start

        run_iteration

        @display.show_iteration_end
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

    def should_stop_loop?
      if @completed
        true
      elsif @max_iterations && @iteration_number >= @max_iterations
        @display.show_termination("max iterations reached (#{@max_iterations})")
        true
      elsif @duration_limit && elapsed_seconds >= @duration_limit
        @display.show_termination("duration limit reached (#{@duration_limit}s)")
        true
      else
        false
      end
    end

    def run_iteration
      iteration_started_at = now_seconds
      agent = Opencode.new(model: @model)
      full_prompt = build_prompt

      agent.run(full_prompt) do |event|
        @metrics.process(event)
        @display.show_event(event)

        if event.is_a?(Events::Text)
          check_completion(event.text)
        end

        if should_cancel_iteration?(iteration_started_at)
          @display.show_iteration_cancelled(cancel_reason(iteration_started_at))
          agent.cancel
          break
        end
      end
    end

    def should_cancel_iteration?(iteration_started_at)
      if @max_context && @metrics.current_context >= @max_context
        true
      elsif @duration_limit && elapsed_seconds >= @duration_limit
        true
      else
        false
      end
    end

    def cancel_reason(iteration_started_at)
      if @max_context && @metrics.current_context >= @max_context
        "context limit reached (#{@metrics.current_context}/#{@max_context})"
      elsif @duration_limit && elapsed_seconds >= @duration_limit
        "duration limit reached"
      else
        "unknown"
      end
    end

    def check_completion(text)
      if text && text.include?(@completion_string)
        @completed = true
      end
    end

    def build_prompt
      system_instructions = format(SYSTEM_PROMPT, completion: @completion_string)
      "#{system_instructions}\n\n---\n\n#{@prompt}"
    end

    def now_seconds
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end
  end
end
