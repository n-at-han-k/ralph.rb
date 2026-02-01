# frozen_string_literal: true

module Ralph

  class Loop
    def call(
      prompt:,
      min_iterations: 1,
      max_iterations: 0,
      completion_promise: "COMPLETE",
      tasks_mode: false,
      task_promise: "READY_FOR_NEXT_TASK",
      model: "",
      agent_type: "opencode",
      auto_commit: true,
      disable_plugins: false,
      allow_all_permissions: true,
      prompt_source: "",
      stream_output: true,
      verbose_tools: false
    )

      @prompt             = prompt
      @min_iterations     = min_iterations
      @max_iterations     = max_iterations
      @completion_promise = completion_promise
      @tasks_mode         = tasks_mode
      @task_promise       = task_promise
      @model              = model
      @agent_type         = agent_type
      @auto_commit        = auto_commit
      @disable_plugins    = disable_plugins
      @allow_all          = allow_all_permissions
      @prompt_source      = prompt_source
      @stream_output      = stream_output
      @verbose_tools      = verbose_tools
      @current_pid        = nil
      @stopping           = false

      Storage::State.load_state.then do |existing_state|
        if existing_state&.active
          Output::ActiveLoopError.call(iteration: existing_state.iteration, started_at: existing_state.started_at, state_path: Storage::State.state_path)
          exit 1
        else
          @agent_config = resolve_agent!(agent_type)

          # Initialize iteration executor
          @iteration = Iteration.new(
            agent_config: @agent_config,
            model: @model,
            options: {
              allow_all_permissions: @allow_all,
              disable_plugins: disable_plugins,
              stream_output: @stream_output,
              verbose_tools: @verbose_tools,
              completion_promise: @completion_promise
            }
          )

          if disable_plugins
            Output::NoPluginWarning.call(agent_type: @agent_config.type)
            case @agent_config.type
            when :claude_code
              warn "Warning: --no-plugins has no effect with Claude Code agent"
            when :codex
              warn "Warning: --no-plugins has no effect with Codex agent"
            end
          end

          Output::Banner.call(agent_name: @agent_config.config_name)

          @state = RalphState.new( active: true,
            iteration: 1,
            min_iterations: @min_iterations,
            max_iterations: @max_iterations,
            completion_promise: @completion_promise,
            tasks_mode: @tasks_mode,
            task_promise: @task_promise,
            prompt: @prompt,
            started_at: Time.now.utc.iso8601,
            model: @model,
            agent: @agent_type

          ).tap { Storage::State.save_state _1 }


          if @tasks_mode && !File.exist?(Storage::Tasks.tasks_path)
            FileUtils.mkdir_p(Storage::State.state_dir)
            File.write(Storage::Tasks.tasks_path, "# Ralph Tasks\n\nAdd your tasks below using: `ralph --add-task \"description\"`\n")
            Output::TasksFileCreated.call(path: Storage::Tasks.tasks_path)
          end

          @history = Storage::History.new

          Output::ConfigSummary.call(
            prompt: @prompt,
            prompt_source: @prompt_source,
            completion_promise: @completion_promise,
            tasks_mode: @tasks_mode,
            task_promise: @task_promise,
            min_iterations: @min_iterations,
            max_iterations: @max_iterations,
            agent_name: @agent_config.config_name,
            model: @model,
            disable_plugins: @disable_plugins,
            agent_type: @agent_config.type,
            allow_all: @allow_all
          )

          setup_signal_handler
          run_loop
        end
      end
    end

    private

      def resolve_agent!(agent_type)
        Agents.resolve(agent_type).tap do |agent_config|
          Agents.validate!(agent_config)
        end
      end

      def setup_signal_handler
        Signal.trap("INT") do
          if @stopping
            $stderr.puts "\nForce stopping..."
            exit 1
          end
          @stopping = true
          $stderr.puts "\nGracefully stopping Ralph loop..."
          if @current_pid
            begin
              Process.kill("TERM", @current_pid)
            rescue StandardError
              # process may have exited
            end
          end
          Storage::State.clear_state
          $stderr.puts "Loop cancelled."
          exit 0
        end
      end

      # ---------- Main loop ----------

      def run_loop
        loop do
          break if @stopping
          break if max_iterations_reached?

          Output::IterationHeader.call(
            iteration: @state.iteration,
            max_iterations: @max_iterations,
            min_iterations: @min_iterations
          )
          outcome = run_iteration
          break if outcome == :break

          advance_iteration
          sleep 1
        end
      end

      def max_iterations_reached?
        if @max_iterations > 0 && @state.iteration > @max_iterations
          Output::MaxIterationsReached.call(
            max_iterations: @max_iterations,
            total_duration_ms: @history.total_duration_ms
          )

          Storage::State.clear_state
          true
        else
          false
        end
      end

      def advance_iteration
        @state.iteration += 1
        Storage::State.save_state(@state)
      end

      # ---------- Single iteration ----------

      def run_iteration
        context_at_start = Storage::Context.load_context
        iteration_start  = Helpers.now_ms

        # Build prompt for this iteration
        full_prompt = PromptBuilder.build(@state, @agent_config)

        # Execute iteration using the Iteration class
        result = @iteration.call(full_prompt, iteration_start: iteration_start)

        # Check for task completion if in tasks mode
        task_completion_detected = @tasks_mode ? Helpers.check_completion("#{result.stdout_text}\n#{result.stderr_text}", @task_promise) : false

        print_iteration_summary(
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

        warn_if_struggling
        detect_plugin_error!("#{result.stdout_text}\n#{result.stderr_text}")
        warn_nonzero_exit(result.exit_code)
        report_task_completion(task_completion_detected, result.completion_detected)

        outcome = completion(result.completion_detected)
        return outcome if outcome == :break

        consume_context(context_at_start)

        auto_commit_changes if @auto_commit

        :continue
      rescue StandardError => e
        iteration_error(e, iteration_start)
        :continue
      end

      # ---------- Struggle tracking ----------

      def warn_if_struggling
        if @state.iteration > 2 && @iteration.struggling?
          si = @iteration.struggle_indicators
          Output::StruggleWarning.call(
            no_progress_iterations: si.no_progress_iterations,
            short_iterations: si.short_iterations
          )
        end
      end

      # ---------- Completion & error handling ----------

      def detect_plugin_error!(combined_output)
        if @agent_config.type == :opencode && Helpers.detect_placeholder_plugin_error(combined_output)
          Output::PluginError.call
          Storage::State.clear_state
          exit 1
        end
      end

      def warn_nonzero_exit(exit_code)
        return if exit_code == 0

        Output::NonzeroExitWarning.call(agent_name: @agent_config.config_name, exit_code: exit_code)
      end

      def report_task_completion(task_completion_detected, completion_detected)
        return unless task_completion_detected && !completion_detected

        Output::TaskCompletion.call(task_promise: @task_promise, next_iteration: @state.iteration + 1)
      end

      def completion(completion_detected)
        return :continue unless completion_detected

        if @state.iteration < @min_iterations
          Output::CompletionDeferred.call(min_iterations: @min_iterations, next_iteration: @state.iteration + 1)
          return :continue
        end

        Output::CompletionDetected.call(
          completion_promise: @completion_promise,
          iteration: @state.iteration,
          total_duration_ms: @history.total_duration_ms
        )
        Storage::State.clear_state
        Storage::History.clear_history
        Storage::Context.clear_context
        :break
      end

      def consume_context(context_at_start)
        if context_at_start
          Output::ContextConsumed.call
          Storage::Context.clear_context
        end
      end

      def auto_commit_changes
        status = `git status --porcelain 2>/dev/null`.strip
        return if status.empty?

        system("git", "add", "-A")
        system("git", "commit", "-m", "Ralph iteration #{@state.iteration}: work in progress",
               [:out, :err] => File::NULL)
        Output::AutoCommitNotice.call(iteration: @state.iteration)
      rescue StandardError
        # git commit failed, ok
      end

      def iteration_error(error, iteration_start)
        if @current_pid
          begin
            Process.kill("TERM", @current_pid)
          rescue StandardError
            # process may have exited
          end
          @current_pid = nil
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

      # ---------- Display ----------

      def print_iteration_summary(iteration:, elapsed_ms:, tool_counts:, exit_code:, completion_detected:)
        Output::IterationSummary.call(
          iteration: iteration,
          elapsed_ms: elapsed_ms,
          tool_counts: tool_counts,
          exit_code: exit_code,
          completion_detected: completion_detected
        )
      end
  end
end
