# frozen_string_literal: true

require "minitest/autorun"
require "ralph"

class TestCLI < Minitest::Test
  def test_version_flag
    assert_output("ralph #{Ralph::VERSION}\n") do
      assert_raises(SystemExit) do
        Ralph::CLI.new(["--version"]).run
      end
    end
  end

  def test_help_flag
    output, = capture_io do
      assert_raises(SystemExit) do
        Ralph::CLI.new(["--help"]).run
      end
    end

    assert_includes output, "Usage: ralph"
    assert_includes output, "--model"
    assert_includes output, "--max-iterations"
    assert_includes output, "--duration"
    assert_includes output, "--max-context"
    assert_includes output, "--completion"
    assert_includes output, "build"
    assert_includes output, "plan"
  end

  def test_parse_options_extracts_model
    cli = Ralph::CLI.new(["--model=opus-4.5", "hello"])
    cli.send(:parse_options)

    assert_equal "opus-4.5", cli.instance_variable_get(:@options)[:model]
  end

  def test_parse_options_extracts_max_iterations
    cli = Ralph::CLI.new(["--max-iterations=10", "hello"])
    cli.send(:parse_options)

    assert_equal 10, cli.instance_variable_get(:@options)[:max_iterations]
  end

  def test_parse_options_extracts_duration
    cli = Ralph::CLI.new(["--duration=300", "hello"])
    cli.send(:parse_options)

    assert_equal 300, cli.instance_variable_get(:@options)[:duration]
  end

  def test_parse_options_extracts_max_context
    cli = Ralph::CLI.new(["--max-context=80000", "hello"])
    cli.send(:parse_options)

    assert_equal 80_000, cli.instance_variable_get(:@options)[:max_context]
  end

  def test_parse_options_extracts_completion
    cli = Ralph::CLI.new(["--completion=<promise>COMPLETE</promise>", "hello"])
    cli.send(:parse_options)

    assert_equal "<promise>COMPLETE</promise>", cli.instance_variable_get(:@options)[:completion]
  end

  # --- Subcommand routing ---

  def test_default_subcommand_is_build
    cli = Ralph::CLI.new(["hello"])
    assert_equal "build", cli.subcommand
  end

  def test_explicit_build_subcommand
    cli = Ralph::CLI.new(["build", "hello"])
    assert_equal "build", cli.subcommand
  end

  def test_explicit_plan_subcommand
    cli = Ralph::CLI.new(["plan", "user auth system"])
    assert_equal "plan", cli.subcommand
  end

  def test_bare_invocation_defaults_to_build
    cli = Ralph::CLI.new(["--max-iterations=10"])
    assert_equal "build", cli.subcommand
  end

  def test_build_subcommand_creates_build_prompt
    cli = Ralph::CLI.new(["build", "focus on auth"])
    cli.send(:parse_options)
    prompt = cli.send(:build_prompt_object)

    assert_instance_of Ralph::Prompt::Build, prompt
    assert_includes prompt.to_s, "focus on auth"
  end

  def test_plan_subcommand_creates_plan_prompt
    cli = Ralph::CLI.new(["plan", "user authentication system"])
    cli.send(:parse_options)
    prompt = cli.send(:build_prompt_object)

    assert_instance_of Ralph::Prompt::Plan, prompt
    assert_includes prompt.to_s, "user authentication system"
  end

  def test_build_prompt_object_without_text
    cli = Ralph::CLI.new([])
    cli.send(:parse_options)
    prompt = cli.send(:build_prompt_object)

    assert_instance_of Ralph::Prompt::Build, prompt
  end

  def test_plan_prompt_object_without_goal
    cli = Ralph::CLI.new(["plan"])
    cli.send(:parse_options)
    prompt = cli.send(:build_prompt_object)

    assert_instance_of Ralph::Prompt::Plan, prompt
    assert_includes prompt.to_s, "ULTIMATE GOAL:"
  end

  def test_read_user_text_from_args
    cli = Ralph::CLI.new(["hello", "world"])
    cli.send(:parse_options)
    text = cli.send(:read_user_text)

    assert_equal "hello world", text
  end

  def test_read_user_text_returns_nil_without_input
    cli = Ralph::CLI.new([])
    cli.send(:parse_options)
    text = cli.send(:read_user_text)

    assert_nil text
  end

  def test_invalid_option_exits
    _output, error_output = capture_io do
      assert_raises(SystemExit) do
        Ralph::CLI.new(["--bogus"]).run
      end
    end

    assert_includes error_output, "Error"
  end

  def test_completion_option_passed_to_build_prompt
    cli = Ralph::CLI.new(["build", "--completion=FINISHED", "hello"])
    cli.send(:parse_options)
    prompt = cli.send(:build_prompt_object)

    assert_instance_of Ralph::Prompt::Build, prompt
    assert_includes prompt.to_s, "FINISHED"
  end

  def test_completion_option_passed_to_plan_prompt
    cli = Ralph::CLI.new(["plan", "--completion=FINISHED", "hello"])
    cli.send(:parse_options)
    prompt = cli.send(:build_prompt_object)

    assert_instance_of Ralph::Prompt::Plan, prompt
    assert_includes prompt.to_s, "FINISHED"
  end
end
