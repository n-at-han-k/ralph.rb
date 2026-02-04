# frozen_string_literal: true

module Ralph
  # Tracks token usage and context size from opencode JSON stream events.
  #
  # Context formula per step: input + cache.read + cache.write
  # Each step's cache.read ~= previous step's (cache.read + cache.write).
  class Metrics
    attr_reader :steps, :iteration_steps, :total_input_tokens, :total_output_tokens

    def initialize
      @steps = []
      @iteration_steps = []
      @total_input_tokens = 0
      @total_output_tokens = 0
      @iteration_count = 0
    end

    # Process a parsed event. Only StepFinish events carry token data.
    def process(event)
      if event.is_a?(Events::StepFinish)
        record = {
          input: event.input_tokens,
          output: event.output_tokens,
          reasoning: event.reasoning_tokens,
          cache_read: event.cache_read,
          cache_write: event.cache_write,
          context: event.context_size,
          timestamp: event.timestamp
        }
        @steps << record
        @iteration_steps << record
        @total_input_tokens += event.input_tokens
        @total_output_tokens += event.output_tokens
      end
    end

    # Current context size from the most recent step_finish
    def current_context
      if @steps.any?
        @steps.last[:context]
      else
        0
      end
    end

    # Total tokens consumed across all steps (input + output)
    def tokens_consumed
      @steps.sum { |step| step[:input] + step[:output] + step[:cache_read] + step[:cache_write] }
    end

    # Tokens consumed in the current iteration only
    def iteration_tokens
      @iteration_steps.sum { |step| step[:input] + step[:output] + step[:cache_read] + step[:cache_write] }
    end

    # Number of LLM steps completed
    def step_count
      @steps.length
    end

    # Signal a new iteration -- resets per-iteration tracking
    def new_iteration
      @iteration_count += 1
      @iteration_steps = []
    end

    # Context growth rate: average tokens added per step
    def context_growth_rate
      if @steps.length >= 2
        first_context = @steps.first[:context]
        last_context = @steps.last[:context]
        (last_context - first_context).to_f / (@steps.length - 1)
      else
        0.0
      end
    end

    # Reset all metrics (used for full restart)
    def reset
      @steps = []
      @iteration_steps = []
      @total_input_tokens = 0
      @total_output_tokens = 0
      @iteration_count = 0
    end
  end
end
