# frozen_string_literal: true

module Ralph
  # Handles all terminal output for the loop -- iteration status, metrics,
  # agent text, and summary information.
  class Display
    SEPARATOR = "-" * 60

    def initialize(loop_engine)
      @loop_engine = loop_engine
    end

    def show_start(prompt)
      puts SEPARATOR
      puts "ralph -- autonomous agentic loop"
      puts SEPARATOR
      puts "Prompt: #{prompt[0, 200]}#{"..." if prompt.length > 200}"
      puts SEPARATOR
    end

    def show_iteration_start
      puts
      puts "#{SEPARATOR}"
      puts "Iteration #{@loop_engine.iteration_number} | " \
           "elapsed: #{format_duration(@loop_engine.elapsed_seconds)} | " \
           "context: #{format_tokens(@loop_engine.metrics.current_context)} | " \
           "tokens: #{format_tokens(@loop_engine.metrics.tokens_consumed)}"
      puts SEPARATOR
    end

    def show_event(event)
      if event.is_a?(Events::Text) && event.text
        print event.text
        $stdout.flush
      end

      if event.is_a?(Events::ToolUse)
        puts
        puts "  [tool] #{event.tool} (#{event.status})"
      end

      if event.is_a?(Events::StepFinish)
        puts
        puts "  [step] context=#{format_tokens(event.context_size)} " \
             "output=#{format_tokens(event.output_tokens)} " \
             "cache_r=#{format_tokens(event.cache_read)} " \
             "cache_w=#{format_tokens(event.cache_write)}"
      end
    end

    def show_iteration_end
      puts
      puts "  Iteration #{@loop_engine.iteration_number} complete | " \
           "steps: #{@loop_engine.metrics.step_count} | " \
           "iteration tokens: #{format_tokens(@loop_engine.metrics.iteration_tokens)}"
    end

    def show_iteration_cancelled(reason)
      puts
      puts "  ** Iteration cancelled: #{reason}"
    end

    def show_termination(reason)
      puts
      puts "  ** Loop terminated: #{reason}"
    end

    def show_summary
      metrics = @loop_engine.metrics
      puts
      puts SEPARATOR
      puts "SUMMARY"
      puts SEPARATOR
      puts "  Status:      #{@loop_engine.completed ? "COMPLETED" : "TERMINATED"}"
      puts "  Iterations:  #{@loop_engine.iteration_number}"
      puts "  Duration:    #{format_duration(@loop_engine.elapsed_seconds)}"
      puts "  Steps:       #{metrics.step_count}"
      puts "  Tokens:      #{format_tokens(metrics.tokens_consumed)}"
      puts "  Context:     #{format_tokens(metrics.current_context)}"
      puts SEPARATOR
    end

    private

    def format_duration(seconds)
      minutes = (seconds / 60).to_i
      remaining_seconds = (seconds % 60).to_i
      if minutes > 0
        "#{minutes}m #{remaining_seconds}s"
      else
        "#{remaining_seconds}s"
      end
    end

    def format_tokens(count)
      if count >= 1_000_000
        format("%.1fM", count / 1_000_000.0)
      elsif count >= 1_000
        format("%.1fk", count / 1_000.0)
      else
        count.to_s
      end
    end
  end
end
