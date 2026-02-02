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
  # Bug 1: existing_state always returns active state because @state.save
  # in initialize writes active:true to disk before existing_state reads it.
  #
  # The intent is: check if a PREVIOUS loop is already running. But since
  # initialize saves the NEW state first, existing_state always finds it.
  # -----------------------------------------------------------------------
  def test_existing_state_always_sees_self_as_active
    state = build_state(active: true)
    config = build_config
    history = Ralph::Storage::History.new
    context = Ralph::Storage::Context.new
    tasks = Ralph::Storage::Tasks.new

    loop_instance = Ralph::Loop.new(config, state: state, history: history, context: context, tasks: tasks)

    # After initialize, the state file exists on disk with active: true
    # because initialize calls @state.save.
    assert File.exist?(Ralph::Storage::State.path),
      "State file should exist after Loop.new (because initialize saves it)"

    loaded_state = Ralph::Storage::State.load
    assert loaded_state.active,
      "The saved state has active: true"

    # The bug: existing_state reads from disk and gets the state we JUST saved.
    # It should detect a PREVIOUS loop's state, not our own.
    existing = loop_instance.existing_state
    assert existing.active,
      "BUG: existing_state returns the state we just saved (active: true), " \
      "so the 'already active' guard in run() will ALWAYS trigger and exit 1"
  end

  # Prove the bug manifests: run() always exits because it thinks another loop is active.
  def test_run_always_exits_due_to_existing_state_race
    state = build_state(active: true)
    config = build_config
    history = Ralph::Storage::History.new
    context = Ralph::Storage::Context.new
    tasks = Ralph::Storage::Tasks.new

    loop_instance = Ralph::Loop.new(config, state: state, history: history, context: context, tasks: tasks)

    # run() should proceed into the main loop, but instead it calls exit(1)
    # because existing_state&.active is true (it read back our own state).
    exit_raised = assert_raises(SystemExit) do
      capture_io { loop_instance.run }
    end

    assert_equal 1, exit_raised.status,
      "BUG: run() exits with status 1 because existing_state reads back the " \
      "state that initialize just saved, making it think another loop is active"
  end

  # -----------------------------------------------------------------------
  # Bug 2: loop.rb:69 references @loop which does not exist on Loop.
  # Output::Iteration::Header.call(@loop) should be self.
  # -----------------------------------------------------------------------
  def test_iteration_header_receives_nil_instead_of_loop
    # @loop is not defined on Loop, so it is nil.
    # Output::Iteration::Header.call(nil) will raise NoMethodError
    # when it tries to call nil.config
    state = build_state(active: true)
    config = build_config(stopping: false, max_iterations: 1)
    history = Ralph::Storage::History.new
    context = Ralph::Storage::Context.new
    tasks = Ralph::Storage::Tasks.new

    loop_instance = Ralph::Loop.new(config, state: state, history: history, context: context, tasks: tasks)

    # Verify @loop is nil on Loop instances (the ivar doesn't exist)
    refute loop_instance.instance_variable_defined?(:@loop),
      "BUG: @loop is not a defined instance variable on Loop — " \
      "line 69 uses @loop but should use self"

    # Directly test that the Header call with nil (what @loop evaluates to) fails
    assert_raises(NoMethodError) do
      Ralph::Output::Iteration::Header.call(nil)
    end
  end

  # -----------------------------------------------------------------------
  # Bug 3: loop.rb:77 and 113 reference local variable `iteration` which
  # is never assigned. The Iteration instance is created as
  # Iteration.new(self).run, and only the result is yielded into .then.
  # -----------------------------------------------------------------------
  def test_iteration_variable_not_available_in_loop_run
    # Parse the source of Loop#run and confirm that `iteration` is used
    # as a local variable but never assigned.
    source = File.read(File.expand_path("../lib/ralph/loop.rb", __dir__))

    # Extract the run method body (between "def run" and the next "def " or "private")
    run_method = source[/def run\b.*?(?=\n\s{4}(?:def |private\b|end\b\s*\z))/m]

    # `iteration.struggling?` and `iteration.context_at_start` appear in the code
    assert_match(/iteration\.struggling\?/, run_method,
      "Precondition: the code references iteration.struggling?")
    assert_match(/iteration\.context_at_start/, run_method,
      "Precondition: the code references iteration.context_at_start")

    # But `iteration` is never assigned as a local variable.
    # Iteration.new(self).run.then yields `result`, not the Iteration instance.
    refute_match(/^\s*iteration\s*=/, run_method,
      "BUG: `iteration` is referenced at lines 77 and 113 but never assigned " \
      "as a local variable. Iteration.new(self).run.then yields `result`, " \
      "not the Iteration instance. This will raise NameError at runtime.")

    # Also confirm the .then block receives `result`, not `iteration`
    assert_match(/\.then do \|result\|/, run_method,
      "The .then block yields `result`, confirming `iteration` is not available")
  end
end
