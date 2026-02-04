# frozen_string_literal: true

require "minitest/autorun"
require "ralph"

class TestMetrics < Minitest::Test
  def setup
    @metrics = Ralph::Metrics.new
  end

  def test_initial_state
    assert_equal 0, @metrics.current_context
    assert_equal 0, @metrics.tokens_consumed
    assert_equal 0, @metrics.step_count
    assert_equal [], @metrics.steps
  end

  def test_process_step_finish_tracks_context
    event = build_step_finish(input: 2, output: 392, cache_read: 0, cache_write: 15_463)
    @metrics.process(event)

    assert_equal 15_465, @metrics.current_context
    assert_equal 1, @metrics.step_count
  end

  def test_process_multiple_steps_tracks_growth
    # Replicate the 4-step example from specs/metrics.md
    @metrics.process(build_step_finish(input: 2, output: 392, cache_read: 0, cache_write: 15_463))
    assert_equal 15_465, @metrics.current_context

    @metrics.process(build_step_finish(input: 5, output: 109, cache_read: 15_463, cache_write: 820))
    assert_equal 16_288, @metrics.current_context

    @metrics.process(build_step_finish(input: 6, output: 354, cache_read: 16_283, cache_write: 575))
    assert_equal 16_864, @metrics.current_context

    @metrics.process(build_step_finish(input: 5, output: 1164, cache_read: 16_858, cache_write: 798))
    assert_equal 17_661, @metrics.current_context

    assert_equal 4, @metrics.step_count
  end

  def test_tokens_consumed_sums_all_token_fields
    @metrics.process(build_step_finish(input: 2, output: 392, cache_read: 0, cache_write: 15_463))
    @metrics.process(build_step_finish(input: 5, output: 109, cache_read: 15_463, cache_write: 820))

    # (2 + 392 + 0 + 15463) + (5 + 109 + 15463 + 820)
    expected = 15_857 + 16_397
    assert_equal expected, @metrics.tokens_consumed
  end

  def test_ignores_non_step_finish_events
    text_event = Ralph::Events::Text.new({
      "type" => "text",
      "timestamp" => 123,
      "sessionID" => "ses_test",
      "part" => { "text" => "hello" }
    })
    @metrics.process(text_event)

    assert_equal 0, @metrics.current_context
    assert_equal 0, @metrics.step_count
  end

  def test_new_iteration_resets_iteration_steps
    @metrics.process(build_step_finish(input: 2, output: 100, cache_read: 0, cache_write: 1000))
    assert_equal 1_102, @metrics.iteration_tokens

    @metrics.new_iteration
    assert_equal 0, @metrics.iteration_tokens

    @metrics.process(build_step_finish(input: 5, output: 200, cache_read: 1000, cache_write: 500))
    assert_equal 1_705, @metrics.iteration_tokens

    # Total steps still includes all
    assert_equal 2, @metrics.step_count
  end

  def test_context_growth_rate
    @metrics.process(build_step_finish(input: 2, output: 100, cache_read: 0, cache_write: 1000))
    @metrics.process(build_step_finish(input: 5, output: 200, cache_read: 1000, cache_write: 500))
    @metrics.process(build_step_finish(input: 3, output: 150, cache_read: 1500, cache_write: 300))

    # First context: 1002, last context: 1803
    # Growth over 2 intervals: (1803 - 1002) / 2 = 400.5
    assert_in_delta 400.5, @metrics.context_growth_rate, 0.1
  end

  def test_context_growth_rate_with_single_step
    @metrics.process(build_step_finish(input: 2, output: 100, cache_read: 0, cache_write: 1000))

    assert_in_delta 0.0, @metrics.context_growth_rate, 0.1
  end

  def test_reset_clears_everything
    @metrics.process(build_step_finish(input: 2, output: 100, cache_read: 0, cache_write: 1000))
    @metrics.reset

    assert_equal 0, @metrics.current_context
    assert_equal 0, @metrics.tokens_consumed
    assert_equal 0, @metrics.step_count
  end

  private

  def build_step_finish(input:, output:, cache_read:, cache_write:)
    Ralph::Events::StepFinish.new({
      "type" => "step_finish",
      "timestamp" => 1_770_187_087_202,
      "sessionID" => "ses_test",
      "part" => {
        "id" => "prt_test",
        "sessionID" => "ses_test",
        "messageID" => "msg_test",
        "type" => "step-finish",
        "reason" => "tool-calls",
        "snapshot" => "abc123",
        "cost" => 0,
        "tokens" => {
          "input" => input,
          "output" => output,
          "reasoning" => 0,
          "cache" => {
            "read" => cache_read,
            "write" => cache_write
          }
        }
      }
    })
  end
end
