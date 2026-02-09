# frozen_string_literal: true

require "minitest/autorun"
require "ralph"

class TestPromptBuild < Minitest::Test
  def test_to_s_includes_core_instructions
    prompt = Ralph::Prompt::Build.new

    text = prompt.to_s

    assert_includes text, "Study `specs/*`"
    assert_includes text, "Study the plans in `plans/`"
    assert_includes text, "implement ONE item from the plans"
    assert_includes text, "run the tests and checks"
    assert_includes text, "git commit"
  end

  def test_to_s_includes_default_signals
    prompt = Ralph::Prompt::Build.new

    text = prompt.to_s

    assert_includes text, "<task>DONE</task>"
    assert_includes text, "<promise>COMPLETE</promise>"
  end

  def test_to_s_includes_guardrail_numbers
    prompt = Ralph::Prompt::Build.new

    text = prompt.to_s

    assert_includes text, "99999."
    assert_includes text, "9999999999999999."
  end

  def test_to_s_with_custom_signals
    prompt = Ralph::Prompt::Build.new(
      task_done: "<done>TASK</done>",
      all_done: "<done>ALL</done>"
    )

    text = prompt.to_s

    assert_includes text, "<done>TASK</done>"
    assert_includes text, "<done>ALL</done>"
    refute_includes text, "<task>DONE</task>"
    refute_includes text, "<promise>COMPLETE</promise>"
  end

  def test_to_s_with_context
    prompt = Ralph::Prompt::Build.new(context: "Focus on the auth module first")

    text = prompt.to_s

    assert_includes text, "Focus on the auth module first"
    assert_includes text, "---"
  end

  def test_to_s_without_context
    prompt = Ralph::Prompt::Build.new

    text = prompt.to_s

    refute_includes text, "---"
  end

  def test_to_s_with_blank_context
    prompt = Ralph::Prompt::Build.new(context: "   ")

    text = prompt.to_s

    refute_includes text, "---"
  end
end

class TestPromptPlan < Minitest::Test
  def test_to_s_includes_core_instructions
    prompt = Ralph::Prompt::Plan.new

    text = prompt.to_s

    assert_includes text, "Study `specs/*`"
    assert_includes text, "Study the plans in `plans/`"
    assert_includes text, "Plan only. Do NOT implement anything."
    assert_includes text, "prioritize tasks"
  end

  def test_to_s_includes_default_goal
    prompt = Ralph::Prompt::Plan.new

    text = prompt.to_s

    assert_includes text, "ULTIMATE GOAL: Consider missing elements"
  end

  def test_to_s_with_custom_goal
    prompt = Ralph::Prompt::Plan.new(goal: "user authentication system")

    text = prompt.to_s

    assert_includes text, "ULTIMATE GOAL: user authentication system"
    refute_includes text, "Consider missing elements"
  end

  def test_to_s_with_blank_goal_uses_default
    prompt = Ralph::Prompt::Plan.new(goal: "   ")

    text = prompt.to_s

    assert_includes text, "ULTIMATE GOAL: Consider missing elements"
  end

  def test_to_s_includes_default_completion
    prompt = Ralph::Prompt::Plan.new

    text = prompt.to_s

    assert_includes text, "<promise>COMPLETE</promise>"
  end

  def test_to_s_with_custom_completion
    prompt = Ralph::Prompt::Plan.new(all_done: "<finished>DONE</finished>")

    text = prompt.to_s

    assert_includes text, "<finished>DONE</finished>"
    refute_includes text, "<promise>COMPLETE</promise>"
  end
end
