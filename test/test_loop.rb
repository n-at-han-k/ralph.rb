# frozen_string_literal: true

require "minitest/autorun"
require "ralph"

class TestLoop < Minitest::Test
  def test_initialize_with_defaults
    prompt = Ralph::Prompt::Build.new
    loop_engine = Ralph::Loop.new(prompt: prompt)

    assert_equal 0, loop_engine.iteration_number
    assert_equal false, loop_engine.completed
    assert_instance_of Ralph::Metrics, loop_engine.metrics
    assert_equal [], loop_engine.iteration_outcomes
  end

  def test_elapsed_seconds_before_start
    prompt = Ralph::Prompt::Build.new
    loop_engine = Ralph::Loop.new(prompt: prompt)

    assert_in_delta 0.0, loop_engine.elapsed_seconds, 0.1
  end

  def test_prompt_text_uses_build_prompt
    prompt = Ralph::Prompt::Build.new(context: "fix the tests")
    loop_engine = Ralph::Loop.new(prompt: prompt)
    text = loop_engine.send(:prompt_text)

    assert_includes text, "implement ONE item from the plans"
    assert_includes text, "fix the tests"
    assert_includes text, "<task>DONE</task>"
    assert_includes text, "<promise>COMPLETE</promise>"
  end

  def test_prompt_text_uses_plan_prompt
    prompt = Ralph::Prompt::Plan.new(goal: "user auth system")
    loop_engine = Ralph::Loop.new(prompt: prompt)
    text = loop_engine.send(:prompt_text)

    assert_includes text, "ULTIMATE GOAL: user auth system"
    assert_includes text, "Plan only. Do NOT implement anything."
  end

  def test_prompt_text_with_custom_completion
    prompt = Ralph::Prompt::Build.new(all_done: "<done>FINISHED</done>")
    loop_engine = Ralph::Loop.new(prompt: prompt)
    text = loop_engine.send(:prompt_text)

    assert_includes text, "<done>FINISHED</done>"
  end

  def test_reads_all_done_from_prompt_object
    prompt = Ralph::Prompt::Build.new(all_done: "<custom>DONE</custom>")
    loop_engine = Ralph::Loop.new(prompt: prompt)

    assert_equal "<custom>DONE</custom>", loop_engine.instance_variable_get(:@all_done_string)
  end

  def test_reads_task_done_from_build_prompt
    prompt = Ralph::Prompt::Build.new(task_done: "<custom>TASK</custom>")
    loop_engine = Ralph::Loop.new(prompt: prompt)

    assert_equal "<custom>TASK</custom>", loop_engine.instance_variable_get(:@task_done_string)
  end

  def test_plan_prompt_has_nil_task_done
    prompt = Ralph::Prompt::Plan.new
    loop_engine = Ralph::Loop.new(prompt: prompt)

    assert_nil loop_engine.instance_variable_get(:@task_done_string)
  end

  def test_cli_completion_option_overrides_prompt_all_done
    prompt = Ralph::Prompt::Build.new(all_done: "<prompt>DONE</prompt>")
    loop_engine = Ralph::Loop.new(prompt: prompt, completion: "<cli>OVERRIDE</cli>")

    assert_equal "<cli>OVERRIDE</cli>", loop_engine.instance_variable_get(:@all_done_string)
  end
end
