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

  def test_build_prompt_from_args
    cli = Ralph::CLI.new(["hello", "world"])
    cli.send(:parse_options)
    prompt = cli.send(:build_prompt)

    assert_equal "hello world", prompt
  end

  def test_build_prompt_returns_nil_without_input
    cli = Ralph::CLI.new([])
    cli.send(:parse_options)
    prompt = cli.send(:build_prompt)

    assert_nil prompt
  end

  def test_invalid_option_exits
    _output, error_output = capture_io do
      assert_raises(SystemExit) do
        Ralph::CLI.new(["--bogus"]).run
      end
    end

    assert_includes error_output, "Error"
  end
end
