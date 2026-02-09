# frozen_string_literal: true

require "minitest/autorun"
require "ralph"

class TestIteration < Minitest::Test
  def test_check_signals_detects_all_done
    iteration = build_iteration(all_done_string: "<promise>COMPLETE</promise>")
    iteration.send(:check_signals, "some text with <promise>COMPLETE</promise> in it")

    assert_equal :all_done, iteration.outcome
    assert iteration.all_done?
  end

  def test_check_signals_detects_task_done
    iteration = build_iteration(task_done_string: "<task>DONE</task>")
    iteration.send(:check_signals, "finished this task <task>DONE</task>")

    assert_equal :task_done, iteration.outcome
    assert iteration.task_done?
    refute iteration.all_done?
  end

  def test_check_signals_ignores_non_matching_text
    iteration = build_iteration
    iteration.send(:check_signals, "just regular text")

    assert_nil iteration.outcome
    refute iteration.task_done?
    refute iteration.all_done?
  end

  def test_check_signals_handles_nil_text
    iteration = build_iteration
    iteration.send(:check_signals, nil)

    assert_nil iteration.outcome
  end

  def test_all_done_takes_priority_over_task_done
    iteration = build_iteration(
      task_done_string: "<task>DONE</task>",
      all_done_string: "<promise>COMPLETE</promise>"
    )
    iteration.send(:check_signals, "<promise>COMPLETE</promise> and <task>DONE</task>")

    assert_equal :all_done, iteration.outcome
    assert iteration.all_done?
  end

  def test_plan_mode_ignores_task_done_with_nil_signal
    iteration = build_iteration(task_done_string: nil)
    iteration.send(:check_signals, "some text with <task>DONE</task> in it")

    assert_nil iteration.outcome
    refute iteration.task_done?
  end

  def test_plan_mode_still_detects_all_done
    iteration = build_iteration(task_done_string: nil, all_done_string: "<promise>COMPLETE</promise>")
    iteration.send(:check_signals, "<promise>COMPLETE</promise>")

    assert_equal :all_done, iteration.outcome
  end

  def test_error_predicate
    iteration = build_iteration
    iteration.instance_variable_set(:@outcome, :error)

    assert iteration.error?
  end

  def test_initial_outcome_is_nil
    iteration = build_iteration

    assert_nil iteration.outcome
  end

  def test_number_accessor
    iteration = build_iteration(number: 5)

    assert_equal 5, iteration.number
  end

  def test_run_handles_agent_not_found
    display = Ralph::Display.new(nil)
    iteration = Ralph::Iteration.new(
      number: 1,
      prompt_text: "test",
      model: "nonexistent-model",
      task_done_string: "<task>DONE</task>",
      all_done_string: "<promise>COMPLETE</promise>",
      metrics: Ralph::Metrics.new,
      display: display
    )

    # Opencode spawns a subprocess -- if the binary doesn't exist, we get Errno::ENOENT.
    # We stub Opencode to raise this error.
    opencode_stub = Object.new
    def opencode_stub.run(_prompt)
      raise Errno::ENOENT, "No such file or directory - nonexistent"
    end

    Ralph::Opencode.stub(:new, opencode_stub) do
      capture_io { iteration.run }
    end

    assert iteration.error?
    assert_equal :error, iteration.outcome
  end

  def test_run_handles_io_error
    display = Ralph::Display.new(nil)
    iteration = Ralph::Iteration.new(
      number: 1,
      prompt_text: "test",
      model: nil,
      task_done_string: "<task>DONE</task>",
      all_done_string: "<promise>COMPLETE</promise>",
      metrics: Ralph::Metrics.new,
      display: display
    )

    opencode_stub = Object.new
    def opencode_stub.run(_prompt)
      raise IOError, "broken pipe"
    end

    Ralph::Opencode.stub(:new, opencode_stub) do
      capture_io { iteration.run }
    end

    assert iteration.error?
  end

  def test_run_handles_unexpected_error
    display = Ralph::Display.new(nil)
    iteration = Ralph::Iteration.new(
      number: 1,
      prompt_text: "test",
      model: nil,
      task_done_string: "<task>DONE</task>",
      all_done_string: "<promise>COMPLETE</promise>",
      metrics: Ralph::Metrics.new,
      display: display
    )

    opencode_stub = Object.new
    def opencode_stub.run(_prompt)
      raise RuntimeError, "something went wrong"
    end

    Ralph::Opencode.stub(:new, opencode_stub) do
      capture_io { iteration.run }
    end

    assert iteration.error?
  end

  private

  def build_iteration(
    number: 1,
    task_done_string: "<task>DONE</task>",
    all_done_string: "<promise>COMPLETE</promise>"
  )
    Ralph::Iteration.new(
      number: number,
      prompt_text: "test prompt",
      model: nil,
      task_done_string: task_done_string,
      all_done_string: all_done_string,
      metrics: Ralph::Metrics.new,
      display: Ralph::Display.new(nil)
    )
  end
end
