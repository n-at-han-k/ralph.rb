# frozen_string_literal: true

require "minitest/autorun"
require "tempfile"

$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))
require "ralph"

class TestCLIIntegration < Minitest::Test
  # Stub Loop#call so no LLM requests are made.
  # Records the options it was called with for assertion.
  def setup
    @loop_calls = []
    calls = @loop_calls
    Ralph::Loop.define_method(:call) do |config|
      calls << config
    end
  end

  def teardown
    Ralph::Loop.remove_method(:call)
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
    assert_equal "Build a REST API", @loop_calls.first.prompt
    assert_equal "", @loop_calls.first.prompt_source
  end

  def test_inline_prompt_multiple_args
    Ralph::CLI.new.run(["Build", "a", "REST", "API"])
    assert_equal 1, @loop_calls.length
    assert_equal "Build a REST API", @loop_calls.first.prompt
  end

  # --- Prompt resolution (explicit file) ---

  def test_explicit_prompt_file
    f = create_temp_file("Content from file")
    Ralph::CLI.new.run(["--prompt-file", f.path])
    assert_equal "Content from file", @loop_calls.first.prompt
    assert_equal f.path, @loop_calls.first.prompt_source
  ensure
    f&.close
    f&.unlink
  end

  # --- Prompt resolution (implicit file) ---

  def test_implicit_prompt_file
    f = create_temp_file("Implicit file content")
    Ralph::CLI.new.run([f.path])
    assert_equal "Implicit file content", @loop_calls.first.prompt
    assert_equal f.path, @loop_calls.first.prompt_source
  ensure
    f&.close
    f&.unlink
  end

  # --- Explicit file takes priority over implicit ---

  def test_explicit_file_beats_implicit
    f1 = create_temp_file("Explicit")
    f2 = create_temp_file("Implicit")
    Ralph::CLI.new.run(["--prompt-file", f1.path, f2.path])
    assert_equal "Explicit", @loop_calls.first.prompt
    assert_equal f1.path, @loop_calls.first.prompt_source
  ensure
    f1&.close; f1&.unlink
    f2&.close; f2&.unlink
  end

  # --- Missing explicit file aborts ---

  def test_missing_explicit_file_aborts
    _out, err = capture_io do
      assert_raises(SystemExit) do
        Ralph::CLI.new.run(["--prompt-file", "no_such_file.md"])
      end
    end
    assert_match(/Prompt file not found/, err)
    assert_empty @loop_calls
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
      "--no-commit",
      "--no-stream"
    ])
    config = @loop_calls.first
    assert_equal 5, config.max_iterations
    assert_equal 2, config.min_iterations
    assert_equal "DONE", config.completion_promise
    assert_equal "gpt-5", config.model
    assert_equal "opencode", config.agent_type
    assert_equal false, config.auto_commit
    assert_equal false, config.stream_output
  end

  def test_prompt_file_key_excluded_from_to_h
    f = create_temp_file("hello")
    Ralph::CLI.new.run(["--prompt-file", f.path])
    refute @loop_calls.first.to_h.key?(:prompt_file)
  ensure
    f&.close; f&.unlink
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

  private

  def create_temp_file(content)
    f = Tempfile.new("cli_test")
    f.write(content)
    f.flush
    f
  end
end
