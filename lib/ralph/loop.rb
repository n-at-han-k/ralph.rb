#            _       _                _
#  _ __ __ _| |_ __ | |__   __      _(_) __ _  __ _ _   _ _ __ ___
# | '__/ _` | | '_ \| '_ \  \ \ /\ / / |/ _` |/ _` | | | | '_ ` _ \
# | | | (_| | | |_) | | | |  \ V  V /| | (_| | (_| | |_| | | | | | |
# |_|  \__,_|_| .__/|_| |_|   \_/\_/ |_|\__, |\__, |\__,_|_| |_| |_|
#             |_|                       |___/ |___/
#
# frozen_string_literal: true

module Ralph
  class Loop
    include ::Ralph::Helpers

    attr_reader :config, :agent, :state, :history, :context, :tasks, :prompt, :struggle_indicators

    def initialize(config, state, history, context, tasks)
      @config = config
      @state = state
      @history = history
      @context = context
      @tasks = tasks

      @struggle_indicators = {
        repeated_errors: {},
        no_progress_iterations: 0,
        short_iterations: 0
      }

      @prompt = @config.prompt
      @existing_state = Storage::State.load
      @state.save
    end

    def existing_state = @existing_state

    def run
      if existing_state&.active
        Output::ActiveLoopError.call(existing_state, path: Storage::State.path)
        exit 1
      end

      Output::Banner.call(self)

      # |..................................................|
      # |--------------------------------------------------|
      # |==================================================|
      # |**************************************************|
      # |##################################################|
      # | Main loop                                        |
      # |##################################################|
      # |**************************************************|
      # |==================================================|
      # |--------------------------------------------------|
      # |..................................................|
      #
      # © 2026 Nathan K.
      # Honestly, I've no idea where this graphic
      # wonder came from. It's MIT lisenced now, thought.

      setup_signal_handler

      loop do
        if @config.stopping
          break
        elsif max_iterations_reached?
          Output::MaxIterationsReached.call(self)
          @state.clear
          break
        else
          Output::Iteration::Header.call(self)

          iteration = Iteration.new(self)
          result = iteration.run

          record_history(result, iteration)
          process_result(result, iteration) || break

          @state.iteration += 1
          @state.save

          sleep 1
        end
      end
    end

    private

      def record_history(result, iteration)
        if result.error?
          @history.record_error(
            state_iteration: @state.iteration,
            iteration_start: iteration.iteration_start,
            error: result.errors.first || "Unknown error"
          )
        else
          @history.record(
            state_iteration: @state.iteration,
            iteration_start: iteration.iteration_start,
            result: result,
            struggle_indicators: iteration.struggle_indicators
          )
        end
      end

      def process_result(result, iteration)
        unless result.error?
          Output::Iteration::Summary.call(self, result)
        end

        case result.status
        when :fatal
          Output::PluginError.call
          @state.clear
          exit 1

        when :failed
          Output::NonzeroExitWarning.call(self, result)

          if @config.tasks_mode
            if check_completion(result.combined_output, @config.task_promise)
              Output::TaskCompletion.call(self)
            end
          end

        when :completed
          if @state.iteration >= @config.min_iterations
            Output::CompletionDetected.call(self)
            @state.clear
            Storage::History.clear_history
            @context.clear
          end

        when :continuing
          if @state.iteration > 2 && iteration.struggling?
            Output::StruggleWarning.call(self)
          end

          if @config.tasks_mode
            if check_completion(result.combined_output, @config.task_promise)
              Output::TaskCompletion.call(self)
            end
          end

          if iteration.context_at_start.present?
            Output::ContextConsumed.call
            iteration.context_at_start.clear
          end

        when :error
          # Already handled inside Iteration#handle_iteration_error
        end

        result.status != :completed || @state.iteration < @config.min_iterations
      end

      def max_iterations_reached?
        @config.max_iterations > 0 && @state.iteration > @config.max_iterations
      end

      def setup_signal_handler
        Signal.trap('INT') do
          if @config.stopping
            warn "\nForce stopping..."
            exit 1
          end
          @config.stopping = true
          warn "\nGracefully stopping Ralph loop..."
          if @config.current_pid
            begin
              Process.kill('TERM', @config.current_pid)
            rescue StandardError
              # process may have exited
            end
          end
          @state.clear
          warn 'Loop cancelled.'
          exit 0
        end
      end
  end
end
