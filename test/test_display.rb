# frozen_string_literal: true

require "minitest/autorun"
require "ralph"

class TestDisplay < Minitest::Test
  def test_format_duration_seconds_only
    display = Ralph::Display.new(nil)
    formatted = display.send(:format_duration, 45.3)

    assert_equal "45s", formatted
  end

  def test_format_duration_minutes_and_seconds
    display = Ralph::Display.new(nil)
    formatted = display.send(:format_duration, 125.7)

    assert_equal "2m 5s", formatted
  end

  def test_format_tokens_small
    display = Ralph::Display.new(nil)

    assert_equal "500", display.send(:format_tokens, 500)
  end

  def test_format_tokens_thousands
    display = Ralph::Display.new(nil)

    assert_equal "15.5k", display.send(:format_tokens, 15_465)
  end

  def test_format_tokens_millions
    display = Ralph::Display.new(nil)

    assert_equal "1.2M", display.send(:format_tokens, 1_234_567)
  end

  def test_show_start_outputs_prompt
    prompt = Ralph::Prompt::Build.new(context: "test prompt")
    loop_engine = Ralph::Loop.new(prompt: prompt)
    display = Ralph::Display.new(loop_engine)

    output = capture_io { display.show_start("test prompt") }.first

    assert_includes output, "ralph -- autonomous agentic loop"
    assert_includes output, "test prompt"
  end

  def test_show_summary_outputs_status
    prompt = Ralph::Prompt::Build.new
    loop_engine = Ralph::Loop.new(prompt: prompt)
    display = Ralph::Display.new(loop_engine)

    output = capture_io { display.show_summary }.first

    assert_includes output, "SUMMARY"
    assert_includes output, "TERMINATED"
    assert_includes output, "Iterations:"
  end

  def test_show_iteration_error_outputs_message
    display = Ralph::Display.new(nil)

    output = capture_io { display.show_iteration_error("agent crashed") }.first

    assert_includes output, "Iteration error"
    assert_includes output, "agent crashed"
  end
end
