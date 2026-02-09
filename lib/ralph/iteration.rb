# frozen_string_literal: true

module Ralph
  # Represents a single execution cycle within the loop. Runs the agent with
  # the prompt, monitors events, detects signals, and can be cancelled at
  # any time. Tracks the outcome of the iteration (task-done, all-done,
  # context guard, error, etc.).
  class Iteration
    OUTCOMES = %i[task_done all_done context_limit duration_limit error].freeze

    attr_reader :number, :outcome

    def initialize(number:, prompt_text:, model:, task_done_string:, all_done_string:, metrics:, display:)
      @number = number
      @prompt_text = prompt_text
      @model = model
      @task_done_string = task_done_string
      @all_done_string = all_done_string
      @metrics = metrics
      @display = display
      @outcome = nil
      @agent = nil
    end

    # Run the iteration. Yields control back to the loop via the check block
    # which determines if the iteration should be cancelled due to external
    # limits (context, duration). Returns the outcome symbol.
    def run(max_context: nil, duration_exceeded: nil)
      @agent = Opencode.new(model: @model)

      @agent.run(@prompt_text) do |event|
        @metrics.process(event)
        @display.show_event(event)

        if event.is_a?(Events::Text)
          check_signals(event.text)
        end

        if @outcome
          @agent.cancel
          break
        end

        if max_context && @metrics.current_context >= max_context
          @outcome = :context_limit
          @display.show_iteration_cancelled(
            "context limit reached (#{@metrics.current_context}/#{max_context})"
          )
          @agent.cancel
          break
        end

        if duration_exceeded&.call
          @outcome = :duration_limit
          @display.show_iteration_cancelled("duration limit reached")
          @agent.cancel
          break
        end
      end
    rescue Errno::ENOENT => error
      @outcome = :error
      @display.show_iteration_error("agent not found: #{error.message}")
    rescue IOError, Errno::EPIPE => error
      @outcome = :error
      @display.show_iteration_error("agent communication error: #{error.message}")
    rescue StandardError => error
      @outcome = :error
      @display.show_iteration_error("unexpected error: #{error.message}")
    ensure
      @outcome ||= :unknown
    end

    # Whether this iteration ended because the agent signaled task-done
    def task_done?
      @outcome == :task_done
    end

    # Whether this iteration ended because the agent signaled all-done
    def all_done?
      @outcome == :all_done
    end

    # Whether this iteration ended due to an error
    def error?
      @outcome == :error
    end

    private

    def check_signals(text)
      if text
        if text.include?(@all_done_string)
          @outcome = :all_done
        elsif @task_done_string && text.include?(@task_done_string)
          @outcome = :task_done
        end
      end
    end
  end
end
