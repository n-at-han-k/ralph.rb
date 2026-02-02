# frozen_string_literal: true

require "minitest/autorun"
require "tmpdir"
require "fileutils"

$LOAD_PATH.unshift(File.expand_path("../../lib", __dir__))
require "ralph"

# Lightweight fake objects used across all output tests.
FakeAgent = Struct.new(:config_name, :type, keyword_init: true)

FakeConfig = Struct.new(
  :chosen_agent, :completion_promise, :task_promise, :tasks_mode,
  :min_iterations, :max_iterations, :model, :disable_plugins,
  :allow_all_permissions, :prompt, :stopping, :stream_output,
  :verbose_tools, :current_pid,
  keyword_init: true
)

FakeState = Struct.new(:iteration, :active, :started_at, keyword_init: true)

FakeHistory = Struct.new(:total_duration_ms, keyword_init: true)

FakePrompt = Struct.new(:text) do
  def to_s = text
  def empty? = text.strip.empty?
end

FakeResult = Struct.new(:exit_code, :combined_output, :tool_counts, :duration_ms,
                        :completion_detected, :status, keyword_init: true) do
  def error? = status == :error
end

FakeLoopContext = Struct.new(:config, :agent, :state, :history, :prompt, :struggle_indicators,
                             keyword_init: true)

def build_loop_context(overrides = {})
  agent = overrides.delete(:agent) || FakeAgent.new(config_name: "opencode", type: :opencode)
  config = overrides.delete(:config) || FakeConfig.new(
    chosen_agent: agent,
    completion_promise: "COMPLETE",
    task_promise: "READY_FOR_NEXT_TASK",
    tasks_mode: false,
    min_iterations: 1,
    max_iterations: 10,
    model: "test-model",
    disable_plugins: false,
    allow_all_permissions: false,
    prompt: "test prompt",
    stopping: false,
    stream_output: false,
    verbose_tools: false,
    current_pid: nil
  )
  state = overrides.delete(:state) || FakeState.new(iteration: 3, active: true, started_at: Time.now.utc.iso8601)
  history = overrides.delete(:history) || FakeHistory.new(total_duration_ms: 60_000)
  prompt = overrides.delete(:prompt) || FakePrompt.new("test prompt")
  struggle_indicators = overrides.delete(:struggle_indicators) || {
    no_progress_iterations: 0,
    short_iterations: 0,
    repeated_errors: {}
  }

  FakeLoopContext.new(
    config: config,
    agent: agent,
    state: state,
    history: history,
    prompt: prompt,
    struggle_indicators: struggle_indicators
  )
end

def build_result(overrides = {})
  FakeResult.new(**{
    exit_code: 0,
    combined_output: "",
    tool_counts: {},
    duration_ms: 5_000,
    completion_detected: false,
    status: :continuing
  }.merge(overrides))
end

# -----------------------------------------------------------------------
# ActiveLoopError
# -----------------------------------------------------------------------
class TestActiveLoopError < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir("ralph_test")
    @original_dir = Dir.pwd
    Dir.chdir(@tmpdir)
  end

  def teardown
    Dir.chdir(@original_dir)
    FileUtils.rm_rf(@tmpdir)
  end

  def test_prints_error_with_iteration_and_path
    existing_state = Ralph::Storage::State.new(
      active: true, iteration: 5, min_iterations: 1, max_iterations: 10,
      completion_promise: "DONE", tasks_mode: false, task_promise: nil,
      prompt: "test", started_at: Time.now.utc.iso8601, model: "m", agent: "a"
    )

    output = capture_io { Ralph::Output::ActiveLoopError.call(existing_state, path: "/tmp/state.json") }
    stderr = output[1]

    assert_match(/already active.*iteration 5/i, stderr)
    assert_match(%r{/tmp/state\.json}, stderr)
  end
end

# -----------------------------------------------------------------------
# Banner
# -----------------------------------------------------------------------
class TestBanner < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir("ralph_test")
    @original_dir = Dir.pwd
    Dir.chdir(@tmpdir)
  end

  def teardown
    Dir.chdir(@original_dir)
    FileUtils.rm_rf(@tmpdir)
  end

  def test_prints_banner_with_agent_name
    loop_context = build_loop_context
    output = capture_io { Ralph::Output::Banner.call(loop_context) }[0]

    assert_match(/Ralph Wiggum Loop/, output)
    assert_match(/opencode/, output)
  end
end

# -----------------------------------------------------------------------
# MaxIterationsReached
# -----------------------------------------------------------------------
class TestMaxIterationsReached < Minitest::Test
  def test_prints_max_iterations_and_total_time
    loop_context = build_loop_context
    output = capture_io { Ralph::Output::MaxIterationsReached.call(loop_context) }[0]

    assert_match(/Max iterations.*10.*reached/i, output)
    assert_match(/Total time/, output)
  end
end

# -----------------------------------------------------------------------
# Iteration::Header
# -----------------------------------------------------------------------
class TestIterationHeader < Minitest::Test
  def test_prints_iteration_number
    loop_context = build_loop_context
    output = capture_io { Ralph::Output::Iteration::Header.call(loop_context) }[0]

    assert_match(/Iteration 3/, output)
    assert_match(%r{/ 10}, output)
  end

  def test_prints_min_info_when_below_minimum
    loop_context = build_loop_context(
      config: FakeConfig.new(
        chosen_agent: FakeAgent.new(config_name: "opencode", type: :opencode),
        completion_promise: "COMPLETE", task_promise: nil, tasks_mode: false,
        min_iterations: 5, max_iterations: 10, model: nil, disable_plugins: false,
        allow_all_permissions: false, prompt: "test", stopping: false,
        stream_output: false, verbose_tools: false, current_pid: nil
      ),
      state: FakeState.new(iteration: 2, active: true, started_at: Time.now.utc.iso8601)
    )
    output = capture_io { Ralph::Output::Iteration::Header.call(loop_context) }[0]

    assert_match(/min: 5/, output)
  end
end

# -----------------------------------------------------------------------
# Iteration::Summary
# -----------------------------------------------------------------------
class TestIterationSummary < Minitest::Test
  def test_prints_summary_with_tools
    loop_context = build_loop_context
    result = build_result(tool_counts: { "Write" => 3, "Read" => 5 }, exit_code: 0, duration_ms: 12_000)
    output = capture_io { Ralph::Output::Iteration::Summary.call(loop_context, result) }[0]

    assert_match(/Iteration: 3/, output)
    assert_match(/Exit code: 0/, output)
    assert_match(/Read/, output)
    assert_match(/Write/, output)
  end

  def test_prints_none_when_no_tools
    loop_context = build_loop_context
    result = build_result(tool_counts: {})
    output = capture_io { Ralph::Output::Iteration::Summary.call(loop_context, result) }[0]

    assert_match(/Tools:.*none/, output)
  end
end

# -----------------------------------------------------------------------
# Iteration::Error
# -----------------------------------------------------------------------
class TestIterationError < Minitest::Test
  def test_prints_error_message
    loop_context = build_loop_context
    output = capture_io { Ralph::Output::Iteration::Error.call(loop_context, "something broke") }
    stderr = output[1]

    assert_match(/Error in iteration 3.*something broke/, stderr)
  end
end

# -----------------------------------------------------------------------
# PluginError
# -----------------------------------------------------------------------
class TestPluginError < Minitest::Test
  def test_prints_plugin_error
    output = capture_io { Ralph::Output::PluginError.call }[1]

    assert_match(/legacy.*ralph-wiggum.*plugin/i, output)
    assert_match(/--no-plugins/, output)
  end
end

# -----------------------------------------------------------------------
# NonzeroExitWarning
# -----------------------------------------------------------------------
class TestNonzeroExitWarning < Minitest::Test
  def test_prints_agent_name_and_exit_code
    loop_context = build_loop_context
    result = build_result(exit_code: 42)
    output = capture_io { Ralph::Output::NonzeroExitWarning.call(loop_context, result) }[1]

    assert_match(/opencode.*exited with code 42/i, output)
  end
end

# -----------------------------------------------------------------------
# TaskCompletion
# -----------------------------------------------------------------------
class TestTaskCompletion < Minitest::Test
  def test_prints_task_promise_and_next_iteration
    loop_context = build_loop_context(
      config: FakeConfig.new(
        chosen_agent: FakeAgent.new(config_name: "opencode", type: :opencode),
        completion_promise: "COMPLETE", task_promise: "READY_FOR_NEXT_TASK", tasks_mode: true,
        min_iterations: 1, max_iterations: 10, model: nil, disable_plugins: false,
        allow_all_permissions: false, prompt: "test", stopping: false,
        stream_output: false, verbose_tools: false, current_pid: nil
      ),
      state: FakeState.new(iteration: 3, active: true, started_at: Time.now.utc.iso8601)
    )
    output = capture_io { Ralph::Output::TaskCompletion.call(loop_context) }[0]

    assert_match(/READY_FOR_NEXT_TASK/, output)
    assert_match(/iteration 4/, output)
  end
end

# -----------------------------------------------------------------------
# CompletionDetected
# -----------------------------------------------------------------------
class TestCompletionDetected < Minitest::Test
  def test_prints_completion_promise_and_iteration_count
    loop_context = build_loop_context
    output = capture_io { Ralph::Output::CompletionDetected.call(loop_context) }[0]

    assert_match(/COMPLETE/, output)
    assert_match(/3 iteration/, output)
    assert_match(/Total time/, output)
  end
end

# -----------------------------------------------------------------------
# StruggleWarning
# -----------------------------------------------------------------------
class TestStruggleWarning < Minitest::Test
  def test_prints_no_progress_warning
    loop_context = build_loop_context(
      struggle_indicators: {
        no_progress_iterations: 5,
        short_iterations: 0,
        repeated_errors: {}
      }
    )
    output = capture_io { Ralph::Output::StruggleWarning.call(loop_context) }[0]

    assert_match(/Potential struggle detected/, output)
    assert_match(/No file changes in 5 iterations/, output)
    refute_match(/very short iterations/, output)
  end

  def test_prints_short_iterations_warning
    loop_context = build_loop_context(
      struggle_indicators: {
        no_progress_iterations: 0,
        short_iterations: 4,
        repeated_errors: {}
      }
    )
    output = capture_io { Ralph::Output::StruggleWarning.call(loop_context) }[0]

    assert_match(/4 very short iterations/, output)
    refute_match(/No file changes/, output)
  end

  def test_prints_both_warnings
    loop_context = build_loop_context(
      struggle_indicators: {
        no_progress_iterations: 3,
        short_iterations: 3,
        repeated_errors: {}
      }
    )
    output = capture_io { Ralph::Output::StruggleWarning.call(loop_context) }[0]

    assert_match(/No file changes in 3 iterations/, output)
    assert_match(/3 very short iterations/, output)
  end
end

# -----------------------------------------------------------------------
# ContextConsumed
# -----------------------------------------------------------------------
class TestContextConsumed < Minitest::Test
  def test_prints_context_consumed
    output = capture_io { Ralph::Output::ContextConsumed.call }[0]

    assert_match(/Context was consumed/, output)
  end
end

# -----------------------------------------------------------------------
# CompletionDeferred
# -----------------------------------------------------------------------
class TestCompletionDeferred < Minitest::Test
  def test_prints_deferral_message
    config = FakeConfig.new(
      chosen_agent: FakeAgent.new(config_name: "opencode", type: :opencode),
      completion_promise: "COMPLETE", task_promise: nil, tasks_mode: false,
      min_iterations: 5, max_iterations: 10, model: nil, disable_plugins: false,
      allow_all_permissions: false, prompt: "test", stopping: false,
      stream_output: false, verbose_tools: false, current_pid: nil
    )
    output = capture_io { Ralph::Output::CompletionDeferred.call(config: config, next_iteration: 3) }[0]

    assert_match(/minimum iterations.*5.*not yet reached/i, output)
    assert_match(/iteration 3/, output)
  end
end

# -----------------------------------------------------------------------
# TasksFileCreated
# -----------------------------------------------------------------------
class TestTasksFileCreated < Minitest::Test
  def test_prints_path
    output = capture_io { Ralph::Output::TasksFileCreated.call(path: "/tmp/tasks.md") }[0]

    assert_match(%r{/tmp/tasks\.md}, output)
  end
end

# -----------------------------------------------------------------------
# NoPluginWarning
# -----------------------------------------------------------------------
class TestNoPluginWarning < Minitest::Test
  def test_warns_for_claude_code
    loop_context = build_loop_context(
      agent: FakeAgent.new(config_name: "claude-code", type: :claude_code)
    )
    output = capture_io { Ralph::Output::NoPluginWarning.call(loop_context) }[1]

    assert_match(/no effect.*Claude Code/i, output)
  end

  def test_warns_for_codex
    loop_context = build_loop_context(
      agent: FakeAgent.new(config_name: "codex", type: :codex)
    )
    output = capture_io { Ralph::Output::NoPluginWarning.call(loop_context) }[1]

    assert_match(/no effect.*Codex/i, output)
  end

  def test_no_warning_for_opencode
    loop_context = build_loop_context(
      agent: FakeAgent.new(config_name: "opencode", type: :opencode)
    )
    output = capture_io { Ralph::Output::NoPluginWarning.call(loop_context) }[1]

    assert_equal "", output
  end
end
