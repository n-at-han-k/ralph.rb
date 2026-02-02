# frozen_string_literal: true

require "minitest/autorun"
require "tmpdir"
require "fileutils"

$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))
require "ralph"

class TestLoopBugs < Minitest::Test
  # Build a minimal config-like object that Loop and its collaborators expect.
  FakeConfig = Struct.new(
    :prompt, :max_iterations, :min_iterations, :completion_promise,
    :tasks_mode, :task_promise, :model, :chosen_agent, :stopping,
    :stream_output, :verbose_tools, :disable_plugins, :allow_all_permissions,
    :current_pid,
    keyword_init: true
  )

  def setup
    @tmpdir = Dir.mktmpdir("ralph_test")
    @original_dir = Dir.pwd
    Dir.chdir(@tmpdir)
  end

  def teardown
    Dir.chdir(@original_dir)
    FileUtils.rm_rf(@tmpdir)
  end

  # Helper to build a state object for testing
  def build_state(active: true, iteration: 1)
    Ralph::Storage::State.new(
      active: active,
      iteration: iteration,
      min_iterations: 1,
      max_iterations: 10,
      completion_promise: "DONE",
      tasks_mode: false,
      task_promise: nil,
      prompt: "test prompt",
      started_at: Time.now.utc.iso8601,
      model: "test-model",
      agent: "test-agent"
    )
  end

  def build_config(overrides = {})
    FakeConfig.new(**{
      prompt: "test prompt",
      max_iterations: 10,
      min_iterations: 1,
      completion_promise: "DONE",
      tasks_mode: false,
      task_promise: nil,
      model: "test-model",
      chosen_agent: "test-agent",
      stopping: false,
      stream_output: false,
      verbose_tools: false,
      disable_plugins: false,
      allow_all_permissions: false,
      current_pid: nil
    }.merge(overrides))
  end

  # -----------------------------------------------------------------------
  # Bug 1 FIX: existing_state now captures state BEFORE saving, so it does
  # not read back the state that initialize just saved.
  # -----------------------------------------------------------------------
  def test_existing_state_does_not_see_self_as_active
    state = build_state(active: true)
    config = build_config
    history = Ralph::Storage::History.new
    context = Ralph::Storage::Context.new
    tasks = Ralph::Storage::Tasks.new

    # No prior state file exists on disk
    refute File.exist?(Ralph::Storage::State.path),
      "Precondition: no state file before Loop.new"

    loop_instance = Ralph::Loop.new(config, state, history, context, tasks)

    # After initialize, the state file exists (because initialize saves it)
    assert File.exist?(Ralph::Storage::State.path),
      "State file should exist after Loop.new"

    # But existing_state was captured BEFORE the save, so it's nil
    assert_nil loop_instance.existing_state,
      "existing_state should be nil when no prior loop was running"
  end

  def test_existing_state_detects_previously_active_loop
    # Simulate a previous loop's state file on disk
    state = build_state(active: true)
    state.save

    # Now create a new loop — it should detect the previous state
    new_state = build_state(active: true, iteration: 1)
    config = build_config
    history = Ralph::Storage::History.new
    context = Ralph::Storage::Context.new
    tasks = Ralph::Storage::Tasks.new

    loop_instance = Ralph::Loop.new(config, new_state, history, context, tasks)

    assert loop_instance.existing_state&.active,
      "existing_state should detect the previously saved active state"
  end

  # -----------------------------------------------------------------------
  # Bug 2 FIX: Output::Iteration::Header.call now receives self, not @loop.
  # -----------------------------------------------------------------------
  def test_iteration_header_receives_loop_not_nil
    state = build_state(active: true)
    config = build_config(stopping: false, max_iterations: 1)
    history = Ralph::Storage::History.new
    context = Ralph::Storage::Context.new
    tasks = Ralph::Storage::Tasks.new

    loop_instance = Ralph::Loop.new(config, state, history, context, tasks)

    # Verify the source no longer references @loop in the Header call
    source = File.read(File.expand_path("../lib/ralph/loop.rb", __dir__))
    run_method = source[/def run\b.*?(?=\n\s{4}(?:def |private\b|end\b\s*\z))/m]

    refute_match(/Header\.call\(@loop\)/, run_method,
      "Header.call should receive self, not @loop")
    assert_match(/Header\.call\(self\)/, run_method,
      "Header.call should receive self")
  end

  # -----------------------------------------------------------------------
  # Bug 3 FIX: history is recorded by the Loop, not the Iteration.
  # -----------------------------------------------------------------------
  def test_history_is_recorded_by_loop
    source = File.read(File.expand_path("../lib/ralph/loop.rb", __dir__))

    # Loop records history via @history.record and @history.record_error
    assert_match(/@history\.record\(/, source,
      "Loop should call @history.record")
    assert_match(/@history\.record_error\(/, source,
      "Loop should call @history.record_error for error results")

    # Iteration does NOT reference @history
    iteration_source = File.read(File.expand_path("../lib/ralph/iteration.rb", __dir__))
    refute_match(/@history/, iteration_source,
      "Iteration should not reference @history")

    # iteration.struggling? and iteration.context_at_start are reachable
    assert_match(/iteration\.struggling\?/, source,
      "iteration.struggling? should still be referenced")
    assert_match(/iteration\.context_at_start/, source,
      "iteration.context_at_start should still be referenced")
  end
end

class TestIterationResult < Minitest::Test
  def test_result_statuses
    assert_equal %i[completed continuing failed fatal error],
      Ralph::Iteration::Result::STATUSES
  end

  def test_result_status_predicates
    result = Ralph::Iteration::Result.new(
      status: :completed,
      agent_result: nil,
      duration_ms: 100,
      files_modified: [],
      completion_detected: true,
      errors: []
    )

    assert result.completed?
    refute result.continuing?
    refute result.failed?
    refute result.fatal?
    refute result.error?
  end

  def test_result_with_nil_agent_result
    result = Ralph::Iteration::Result.new(
      status: :error,
      agent_result: nil,
      duration_ms: 100,
      files_modified: [],
      completion_detected: false,
      errors: ["something went wrong"]
    )

    assert result.error?
    assert_nil result.exit_code
    assert_equal "", result.stdout_text
    assert_equal "", result.stderr_text
    assert_equal({}, result.tool_counts)
    assert_equal "", result.combined_output
  end

  def test_each_status_predicate
    Ralph::Iteration::Result::STATUSES.each do |status|
      result = Ralph::Iteration::Result.new(
        status: status,
        agent_result: nil,
        duration_ms: 0,
        files_modified: [],
        completion_detected: false,
        errors: []
      )

      assert_equal status, result.status
      assert result.send(:"#{status}?"),
        "#{status}? should be true when status is #{status}"

      other_statuses = Ralph::Iteration::Result::STATUSES - [status]
      other_statuses.each do |other|
        refute result.send(:"#{other}?"),
          "#{other}? should be false when status is #{status}"
      end
    end
  end
end
