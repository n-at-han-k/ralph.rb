# frozen_string_literal: true

require "minitest/autorun"

$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))
require "ralph"

class TestCLIIntegration < Minitest::Test
  # Stub Loop#initialize and Loop#run so no LLM requests are made.
  # Records the config passed to initialize for assertion.
  def setup
    @loop_calls = []
    calls = @loop_calls
    Ralph::Loop.alias_method(:_original_initialize, :initialize)
    Ralph::Loop.alias_method(:_original_run, :run)
    Ralph::Loop.define_method(:initialize) do |config, state:, history:, context:, tasks:|
      calls << config
    end
    Ralph::Loop.define_method(:run) do
      # no-op
    end
  end

  def teardown
    Ralph::Loop.alias_method(:initialize, :_original_initialize)
    Ralph::Loop.alias_method(:run, :_original_run)
    Ralph::Loop.undef_method(:_original_initialize)
    Ralph::Loop.undef_method(:_original_run)
  end

  # --- Subcommands (no loop invoked) ---

  def test_help_exits_zero
    assert_raises(SystemExit) do
      Ralph::CLI.new.run(["--help"])
    end
  end

  def test_version_prints_and_exits
    ex = assert_raises(SystemExit) do
      capture_io do
        Ralph::CLI.new.run(["--version"])
      end
    end
    assert_equal 0, ex.status
  end

  # --- Empty prompt ---

  def test_no_prompt_aborts
    _out, err = capture_io do
      assert_raises(SystemExit) do
        Ralph::CLI.new.run([])
      end
    end
    assert_match(/No prompt provided/, err)
  end

  # --- Prompt resolution (inline args) ---

  def test_inline_prompt_single_arg
    Ralph::CLI.new.run(["Build a REST API"])
    assert_equal 1, @loop_calls.length
    assert_equal "Build a REST API", @loop_calls.first.prompt.to_s
  end

  def test_inline_prompt_multiple_args
    Ralph::CLI.new.run(["Build", "a", "REST", "API"])
    assert_equal 1, @loop_calls.length
    assert_equal "Build a REST API", @loop_calls.first.prompt.to_s
  end

  # --- Options pass through to Loop ---

  def test_options_forwarded_to_loop
    Ralph::CLI.new.run([
      "Do stuff",
      "--max-iterations", "5",
      "--min-iterations", "2",
      "--completion-promise", "DONE",
      "--model", "gpt-5",
      "--agent", "opencode",
      "--no-stream"
    ])
    config = @loop_calls.first
    assert_equal 5, config.max_iterations
    assert_equal 2, config.min_iterations
    assert_equal "DONE", config.completion_promise
    assert_equal "gpt-5", config.model
    assert_equal "opencode", config.chosen_agent
    assert_equal false, config.stream_output
  end

  # --- Validation ---

  def test_min_greater_than_max_aborts
    _out, err = capture_io do
      assert_raises(SystemExit) do
        Ralph::CLI.new.run(["Do stuff", "--min-iterations", "10", "--max-iterations", "5"])
      end
    end
    assert_match(/min-iterations.*cannot be greater than.*max-iterations/, err)
    assert_empty @loop_calls
  end

end
