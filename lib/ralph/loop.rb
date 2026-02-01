# frozen_string_literal: true

module Ralph
  class Loop
    include ::Ralph::Helpers

    def call(config)
      @config = config

      Storage::State.load.then do |existing_state|
        if existing_state&.active
          Output::ActiveLoopError.call(iteration: existing_state.iteration, started_at: existing_state.started_at,
                                       state_path: Storage::State.path)
          exit 1
        else
          @agent_config = resolve_agent!(@config.agent_type)

          # Initialize iteration executor
          @iteration = Iteration.new(
            agent_config: @agent_config,
            model: @config.model,
            options: {
              allow_all_permissions: @config.allow_all_permissions,
              disable_plugins: @config.disable_plugins,
              stream_output: @config.stream_output,
              verbose_tools: @config.verbose_tools,
              completion_promise: @config.completion_promise
            }
          )

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
          run_loop
        end
      end
    end

    private

    def resolve_agent!(agent_type)
      Agents.resolve(agent_type).tap do |agent_config|
        agent_config.validate!
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

    # ---------- Main loop ----------

    def run_loop
      loop do
        break if @config.stopping
        break if max_iterations_reached?

        Output::IterationHeader.call(
          config: @config,
          iteration: @state.iteration
        )
        outcome = run_iteration
        break if outcome == :break

        advance_iteration
        sleep 1
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

    def advance_iteration
      @state.iteration += 1
      @state.save
    end

    # ---------- Single iteration ----------

    def run_iteration
      context_at_start = Storage::Context.new
      iteration_start  = now_ms

      # Build prompt for this iteration
      full_prompt = @prompt.build_iteration(@state, @agent_config)

      # Execute iteration using the Iteration class
      @iteration.call(full_prompt, iteration_start: iteration_start).then do |result|
        Output::IterationSummary.call(
          iteration: @state.iteration,
          elapsed_ms: result.duration_ms,
          tool_counts: result.tool_counts,
          exit_code: result.exit_code,
          completion_detected: result.completion_detected
        )

        @history.record(
          state_iteration: @state.iteration,
          iteration_start: iteration_start,
          result: result,
          struggle_indicators: @iteration.struggle_indicators
        )

        # Check for task completion if in tasks mode
        task_completion_detected = if @config.tasks_mode
                                     check_completion(
                                       "#{result.stdout_text}\n#{result.stderr_text}",
                                       @config.task_promise
                                     )
                                   else
                                     false
                                   end

        warn_if_struggling
        detect_plugin_error!("#{result.stdout_text}\n#{result.stderr_text}")
        warn_nonzero_exit(result.exit_code)
        report_task_completion(task_completion_detected, result.completion_detected)

        outcome = completion(result.completion_detected)
        if outcome == :break
          outcome
        else
          consume_context(context_at_start)

          auto_commit_changes if @config.auto_commit

          :continue
        end
      end
    rescue StandardError => e
      iteration_error(e, iteration_start)
      :continue
    end

    # ---------- Struggle tracking ----------

    def warn_if_struggling
      return unless @state.iteration > 2 && @iteration.struggling?

      si = @iteration.struggle_indicators
      Output::StruggleWarning.call(
        no_progress_iterations: si.no_progress_iterations,
        short_iterations: si.short_iterations
      )
    end

    # ---------- Completion & error handling ----------

    def detect_plugin_error!(combined_output)
      return unless @agent_config.type == :opencode && detect_placeholder_plugin_error(combined_output)

      Output::PluginError.call
      Storage::State.clear
      exit 1
    end

    def warn_nonzero_exit(exit_code)
      return if exit_code == 0

      Output::NonzeroExitWarning.call(agent_config: @agent_config, exit_code: exit_code)
    end

    def report_task_completion(task_completion_detected, completion_detected)
      return unless task_completion_detected && !completion_detected

      Output::TaskCompletion.call(config: @config, next_iteration: @state.iteration + 1)
    end

    def completion(completion_detected)
      if completion_detected
        :continue

      elsif @state.iteration < @config.min_iterations
        Output::CompletionDeferred.call(
          config: @config, next_iteration: @state.iteration + 1
        )
        :continue

      else
        Output::CompletionDetected.call(
          config: @config,
          iteration: @state.iteration,
          total_duration_ms: @history.total_duration_ms
        )
        Storage::State.clear
        Storage::History.clear_history
        Storage::Context.new.clear
        :break

      end
    end

    def consume_context(context_at_start)
      return unless context_at_start.present?

      Output::ContextConsumed.call
      context_at_start.clear
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

    def iteration_error(error, iteration_start)
      if @config.current_pid
        begin
          Process.kill('TERM', @config.current_pid)
        rescue StandardError
          # process may have exited
        end
        @config.current_pid = nil
      end

      Output::IterationError.call(iteration: @state.iteration, error: error)

      @history.record_error(
        state_iteration: @state.iteration,
        iteration_start: iteration_start,
        error: error
      )

      advance_iteration
      sleep 2
    end
  end
end
