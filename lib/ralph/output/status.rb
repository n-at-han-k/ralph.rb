# frozen_string_literal: true

module Ralph
  module Output
    class Status
      def self.call(options:)
        new(options).call
      end

      def initialize(options)
        @options = options
      end

      def call
        state = State.load_state
        history = State.load_history
        context = State.load_context
        show_tasks = @options[:tasks_mode] || state&.tasks_mode

        print_header
        print_loop_status(state)
        print_pending_context(context)
        print_tasks if show_tasks
        print_history(history)
        print_footer
      end

      private

        def print_header
          puts <<~HEADER

            \u2554#{"=" * 66}\u2557
            \u2551                    Ralph Wiggum Status                           \u2551
            \u255A#{"=" * 66}\u255D
          HEADER
        end

        def print_loop_status(state)
          if state&.active
            print_active_loop(state)
          else
            puts "\u23F9\uFE0F  No active loop"
          end
        end

        def print_active_loop(state)
          elapsed = Helpers.now_ms - (Time.parse(state.started_at).to_f * 1000).to_i
          elapsed_str = Helpers.format_duration_long(elapsed)
          puts "\u{1F504} ACTIVE LOOP"
          max_str = state.max_iterations > 0 ? " / #{state.max_iterations}" : " (unlimited)"
          puts "   Iteration:    #{state.iteration}#{max_str}"
          puts "   Started:      #{state.started_at}"
          puts "   Elapsed:      #{elapsed_str}"
          puts "   Promise:      #{state.completion_promise}"
          agent_label = if state.agent
            cfg = Agents.resolve(state.agent)
            cfg ? cfg.config_name : state.agent
          else
            "OpenCode"
          end
          puts "   Agent:        #{agent_label}"
          puts "   Model:        #{state.model}" if state.model && !state.model.empty?
          if state.tasks_mode
            puts "   Tasks Mode:   ENABLED"
            puts "   Task Promise: #{state.task_promise}"
          end
          prompt_preview = state.prompt[0, 60] + (state.prompt.length > 60 ? "..." : "")
          puts "   Prompt:       #{prompt_preview}"
        end

        def print_pending_context(context)
          return unless context

          puts "\n\u{1F4DD} PENDING CONTEXT (will be injected next iteration):"
          puts "   #{context.split("\n").join("\n   ")}"
        end

        def print_tasks
          if File.exist?(State.tasks_path)
            begin
              tasks_content = File.read(State.tasks_path)
              tasks = Tasks.parse(tasks_content)
              print_current_tasks(tasks)
            rescue StandardError
              puts "\n\u{1F4CB} CURRENT TASKS: (error reading tasks)"
            end
          else
            puts "\n\u{1F4CB} CURRENT TASKS: (no tasks file found)"
          end
        end

        def print_current_tasks(tasks)
          if tasks.any?
            puts "\n\u{1F4CB} CURRENT TASKS:"
            tasks.each_with_index do |task, i|
              icon = tasks.status_icon(task.status)
              puts "   #{i + 1}. #{icon} #{task.text}"
              task.subtasks.each do |subtask|
                sub_icon = tasks.status_icon(subtask.status)
                puts "      #{sub_icon} #{subtask.text}"
              end
            end
            complete = tasks.count { |t| t.status == :complete }
            in_progress = tasks.count { |t| t.status == :in_progress }
            puts "\n   Progress: #{complete}/#{tasks.length} complete, #{in_progress} in progress"
          else
            puts "\n\u{1F4CB} CURRENT TASKS: (no tasks found)"
          end
        end

        def print_history(history)
          return unless history.iterations.any?

          puts "\n\u{1F4CA} HISTORY (#{history.iterations.length} iterations)"
          puts "   Total time:   #{Helpers.format_duration_long(history.total_duration_ms)}"

          recent = history.iterations.last(5)
          print_recent_iterations(recent)

          si = history.struggle_indicators
          has_repeated = si.repeated_errors.values.any? { |c| c >= 2 }
          if si.no_progress_iterations >= 3 || si.short_iterations >= 3 || has_repeated
            print_struggle_warnings(si)
          end
        end

        def print_recent_iterations(iterations)
          puts "\n   Recent iterations:"
          iterations.each do |iter|
            tools = iter.tools_used
                      .sort_by { |_, v| -v }
                      .first(3)
                      .map { |k, v| "#{k}:#{v}" }
                      .join(" ")
            status_icon = if iter.completion_detected
              "\u2705"
            elsif iter.exit_code != 0
              "\u274C"
            else
              "\u{1F504}"
            end
            puts "   #{status_icon} ##{iter.iteration}: #{Helpers.format_duration_long(iter.duration_ms)} | #{tools.empty? ? "no tools" : tools}"
          end
        end

        def print_struggle_warnings(si)
          puts "\n\u26A0\uFE0F  STRUGGLE INDICATORS:"
          if si.no_progress_iterations >= 3
            puts "   - No file changes in #{si.no_progress_iterations} iterations"
          end
          if si.short_iterations >= 3
            puts "   - #{si.short_iterations} very short iterations (< 30s)"
          end
          top_errors = si.repeated_errors
                         .select { |_, count| count >= 2 }
                         .sort_by { |_, count| -count }
                         .first(3)
          top_errors.each do |error, count|
            puts "   - Same error #{count}x: \"#{error[0, 50]}...\""
          end
          puts "\n   \u{1F4A1} Consider using: ralph --add-context \"your hint here\""
        end

        def print_footer
          puts ""
        end
    end
  end
end
