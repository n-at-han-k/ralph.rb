# frozen_string_literal: true

require "minitest/autorun"
require "ralph"

class TestLoop < Minitest::Test
  def test_initialize_with_defaults
    loop_engine = Ralph::Loop.new(prompt: "test prompt")

    assert_equal 0, loop_engine.iteration_number
    assert_equal false, loop_engine.completed
    assert_instance_of Ralph::Metrics, loop_engine.metrics
  end

  def test_elapsed_seconds_before_start
    loop_engine = Ralph::Loop.new(prompt: "test prompt")

    assert_in_delta 0.0, loop_engine.elapsed_seconds, 0.1
  end

  def test_build_prompt_includes_system_instructions
    loop_engine = Ralph::Loop.new(
      prompt: "fix the tests",
      completion: "<done>FINISHED</done>"
    )
    prompt = loop_engine.send(:build_prompt)

    assert_includes prompt, "You are working autonomously"
    assert_includes prompt, "Do NOT ask the user any questions"
    assert_includes prompt, "<done>FINISHED</done>"
    assert_includes prompt, "fix the tests"
  end

  def test_build_prompt_uses_default_completion_string
    loop_engine = Ralph::Loop.new(prompt: "test")
    prompt = loop_engine.send(:build_prompt)

    assert_includes prompt, "<promise>COMPLETE</promise>"
  end

  def test_check_completion_detects_string
    loop_engine = Ralph::Loop.new(
      prompt: "test",
      completion: "DONE"
    )

    assert_equal false, loop_engine.completed

    loop_engine.send(:check_completion, "some text with DONE in it")

    assert_equal true, loop_engine.completed
  end

  def test_check_completion_ignores_non_matching_text
    loop_engine = Ralph::Loop.new(
      prompt: "test",
      completion: "DONE"
    )
    loop_engine.send(:check_completion, "just regular text")

    assert_equal false, loop_engine.completed
  end

  def test_check_completion_handles_nil_text
    loop_engine = Ralph::Loop.new(prompt: "test")
    loop_engine.send(:check_completion, nil)

    assert_equal false, loop_engine.completed
  end
end
