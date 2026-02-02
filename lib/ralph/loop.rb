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

    attr_reader :config, :agent, :state, :history, :prompt, :struggle_indicators

    def initialize(config)
      @config = config

      @struggle_indicators = { 'repeated_errors' => {}, 'no_progress_iterations' => 0, 'short_iterations' => 0 }

      @prompt = @config.prompt
      @state = Storage::State.from_config(@config, prompt: @prompt).tap(&:save)
      @history = Storage::History.new
    end

    def existing_state = @_existing_state ||= Storate::State.load

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
          Storage::State.clear
          break
        else
          Output::Iteration::Header.call(@loop)

          Iteration.new(self).run.then do |result|
            if result
              Output::Iteration::Summary.call(self, result)

              combined_output = result.combined_output

              if @state.iteration > 2 && iteration.struggling?
                Output::StruggleWarning.call(
                  no_progress_iterations: @struggle_indicators['no_progress_iterations'],
                  short_iterations: @struggle_indicators['short_iterations']
                )
              end

              Agents.resolve(@config.agent_type).then do |agent|

                agent.validate!

                agent.detect_fatal_error(combined_output).then do |fatal_error|
                  if fatal_error
                    Output::PluginError.call
                    Storage::State.clear
                    exit 1
                  end
                end

                unless result.exit_code == 0
                  Output::NonzeroExitWarning.call(agent: agent, exit_code: result.exit_code)
                end

                if @config.tasks_mode && !result.completion_detected
                  if check_completion(combined_output, @config.task_promise)
                    Output::TaskCompletion.call(config: @config, next_iteration: @state.iteration + 1)
                  end
                end

                if !result.completion_detected && @state.iteration >= @config.min_iterations
                  Output::CompletionDetected.call(self)
                  Storage::State.clear
                  Storage::History.clear_history
                  Storage::Context.new.clear
                  break
                else
                  if iteration.context_at_start.present?
                    Output::ContextConsumed.call
                    iteration.context_at_start.clear
                  end

                  @state.iteration += 1
                  @state.save

                  sleep 1
                end
              end

            else
              @state.iteration += 1
              @state.save

              sleep 1
            end
          end
        end
      end
    end

    private

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
          Storage::State.clear
          warn 'Loop cancelled.'
          exit 0
        end
      end
  end
end
