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

      @agent = Agents.resolve(@config.agent_type).tap do |resolved_agent|
        resolved_agent.validate!
      end

      @struggle_indicators = { 'repeated_errors' => {}, 'no_progress_iterations' => 0, 'short_iterations' => 0 }

      @prompt = @config.prompt
    end

    def run
      Storage::State.load.then do |existing_state|
        if existing_state&.active
          Output::ActiveLoopError.call(
            iteration: existing_state.iteration,
            started_at: existing_state.started_at,
            state_path: Storage::State.path
          )
          exit 1
        else
          Output::NoPluginWarning.call(self) if @config.disable_plugins

          Output::Banner.call(self)

          @state = Storage::State.from_config(@config, prompt: @prompt).tap(&:save)

          if @config.tasks_mode && !File.exist?(Storage::Tasks.tasks_path)
            FileUtils.mkdir_p(Storage::State.dir)

            File.write(
              Storage::Tasks.tasks_path,
              "# Ralph Tasks\n\nAdd your tasks below using: `ralph --add-task \"description\"`\n"
            )

            Output::TasksFileCreated.call(path: Storage::Tasks.tasks_path)
          end

          @history = Storage::History.new

          Output::ConfigSummary.call(self)

          setup_signal_handler

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

          loop do
            if @config.stopping
              break
            elsif max_iterations_reached?
              Output::MaxIterationsReached.call(self)
              Storage::State.clear
              break
            else
              Output::Iteration::Header.call(self)

              Iteration.new(self).run.then do |outcome|
                if outcome&.complete?
                  Output::CompletionDetected.call(self)
                  Storage::State.clear
                  Storage::History.clear_history
                  Storage::Context.new.clear
                  break
                else
                  if outcome
                    if outcome.context_at_start.present?
                      Output::ContextConsumed.call
                      outcome.context_at_start.clear
                    end
                  end

                  @state.iteration += 1
                  @state.save

                  sleep 1
                end
              end
            end
          end
        end
      end
    end

    private

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

      def max_iterations_reached?
        @config.max_iterations > 0 && @state.iteration > @config.max_iterations
      end
  end
end
