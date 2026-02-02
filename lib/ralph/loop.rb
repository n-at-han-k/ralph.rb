# frozen_string_literal: true

module Ralph
  class Loop
    include ::Ralph::Helpers

    attr_reader :config, :agent_config, :state, :history, :prompt, :struggle_indicators

    def call(config)
      @config = config

      Storage::State.load.then do |existing_state|
        if existing_state&.active
          Output::ActiveLoopError.call(
            iteration: existing_state.iteration,
            started_at: existing_state.started_at,
            state_path: Storage::State.path
          )
          exit 1
        else
          @agent_config = resolve_agent!(@config.agent_type)

          # Struggle indicators are shared across iterations
          @struggle_indicators = { 'repeated_errors' => {}, 'no_progress_iterations' => 0, 'short_iterations' => 0 }

          Output::NoPluginWarning.call(agent_config: @agent_config) if @config.disable_plugins

          Output::Banner.call(agent_config: @agent_config)

          @prompt = @config.prompt

          @state = Storage::State.from_config(@config, prompt: @prompt).tap(&:save)

          if @config.tasks_mode && !File.exist?(Storage::Tasks.tasks_path)
            FileUtils.mkdir_p(Storage::State.dir)
            File.write(Storage::Tasks.tasks_path,
                       "# Ralph Tasks\n\nAdd your tasks below using: `ralph --add-task \"description\"`\n")
            Output::TasksFileCreated.call(path: Storage::Tasks.tasks_path)
          end

          @history = Storage::History.new

          Output::ConfigSummary.call(
            config: @config,
            agent_config: @agent_config,
            prompt: @prompt
          )

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
            if @config.stopping or max_iterations_reached?
              break
            else
              Output::IterationHeader.call(
                config: @config,
                iteration: @state.iteration
              )

              Iteration.new(self).run.then do |outcome|
                if outcome&.complete?
                  Output::CompletionDetected.call(
                    config: @config,
                    iteration: @state.iteration,
                    total_duration_ms: @history.total_duration_ms
                  )
                  Storage::State.clear
                  Storage::History.clear_history
                  Storage::Context.new.clear
                  break
                else
                  if outcome
                    consume_context(outcome.context_at_start)
                    auto_commit_changes if @config.auto_commit
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

    def resolve_agent!(agent_type)
      Agents.resolve(agent_type).tap do |resolved_agent_config|
        resolved_agent_config.validate!
      end
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

    def max_iterations_reached?
      if @config.max_iterations > 0 && @state.iteration > @config.max_iterations
        Output::MaxIterationsReached.call(
          config: @config,
          total_duration_ms: @history.total_duration_ms
        )

        Storage::State.clear
        true
      else
        false
      end
    end

    def consume_context(context_at_start)
      if context_at_start.present?
        Output::ContextConsumed.call
        context_at_start.clear
      end
    end

    def auto_commit_changes
      status = `git status --porcelain 2>/dev/null`.strip
      unless status.empty?
        system('git', 'add', '-A')
        system('git', 'commit', '-m', "Ralph iteration #{@state.iteration}: work in progress",
               %i[out err] => File::NULL)
        Output::AutoCommitNotice.call(iteration: @state.iteration)
      end
    rescue StandardError
      # git commit failed, ok
    end
  end
end
