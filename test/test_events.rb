# frozen_string_literal: true

require "minitest/autorun"
require "ralph"

class TestEvents < Minitest::Test
  def test_parse_step_start
    json = '{"type":"step_start","timestamp":1770187082911,"sessionID":"ses_abc123","part":{"id":"prt_1","sessionID":"ses_abc123","messageID":"msg_1","type":"step-start","snapshot":"abc123"}}'
    event = Ralph::Events.parse(json)

    assert_instance_of Ralph::Events::StepStart, event
    assert_equal "step_start", event.type
    assert_equal 1_770_187_082_911, event.timestamp
    assert_equal "ses_abc123", event.session_id
    assert_equal "abc123", event.snapshot
  end

  def test_parse_text
    json = '{"type":"text","timestamp":1770187082912,"sessionID":"ses_abc123","part":{"id":"prt_2","sessionID":"ses_abc123","messageID":"msg_1","type":"text","text":"Hello world"}}'
    event = Ralph::Events.parse(json)

    assert_instance_of Ralph::Events::Text, event
    assert_equal "Hello world", event.text
  end

  def test_parse_tool_use
    json = '{"type":"tool_use","timestamp":1770187087186,"sessionID":"ses_abc123","part":{"id":"prt_3","sessionID":"ses_abc123","messageID":"msg_1","type":"tool","callID":"toolu_123","tool":"write","state":{"status":"completed","input":{"filePath":"/tmp/test.rb"},"output":"ok"}}}'
    event = Ralph::Events.parse(json)

    assert_instance_of Ralph::Events::ToolUse, event
    assert_equal "write", event.tool
    assert_equal "toolu_123", event.call_id
    assert_equal "completed", event.status
  end

  def test_parse_step_finish
    json = '{"type":"step_finish","timestamp":1770187087202,"sessionID":"ses_abc123","part":{"id":"prt_4","sessionID":"ses_abc123","messageID":"msg_1","type":"step-finish","reason":"tool-calls","snapshot":"def456","cost":0,"tokens":{"input":2,"output":392,"reasoning":0,"cache":{"read":0,"write":15463}}}}'
    event = Ralph::Events.parse(json)

    assert_instance_of Ralph::Events::StepFinish, event
    assert_equal "tool-calls", event.reason
    assert_equal 2, event.input_tokens
    assert_equal 392, event.output_tokens
    assert_equal 0, event.reasoning_tokens
    assert_equal 0, event.cache_read
    assert_equal 15_463, event.cache_write
    assert_equal 15_465, event.context_size
  end

  def test_parse_step_finish_with_cache_read
    json = '{"type":"step_finish","timestamp":1770187100738,"sessionID":"ses_abc123","part":{"id":"prt_5","sessionID":"ses_abc123","messageID":"msg_1","type":"step-finish","reason":"tool-calls","snapshot":"ghi789","cost":0,"tokens":{"input":5,"output":109,"reasoning":0,"cache":{"read":15463,"write":820}}}}'
    event = Ralph::Events.parse(json)

    assert_equal 5, event.input_tokens
    assert_equal 15_463, event.cache_read
    assert_equal 820, event.cache_write
    assert_equal 16_288, event.context_size
  end

  def test_parse_unknown_type_returns_nil
    json = '{"type":"session.created","timestamp":123,"sessionID":"ses_abc123","part":{}}'
    event = Ralph::Events.parse(json)

    assert_nil event
  end

  def test_parse_invalid_json_returns_nil
    event = Ralph::Events.parse("not json at all")

    assert_nil event
  end

  def test_parse_empty_string_returns_nil
    event = Ralph::Events.parse("")

    assert_nil event
  end

  def test_context_size_formula
    # Context = input + cache.read + cache.write
    # From the spec example: step 3 has input=6, cache.read=16283, cache.write=575 => 16864
    json = '{"type":"step_finish","timestamp":1770187105737,"sessionID":"ses_abc123","part":{"id":"prt_6","sessionID":"ses_abc123","messageID":"msg_1","type":"step-finish","reason":"tool-calls","snapshot":"jkl012","cost":0,"tokens":{"input":6,"output":354,"reasoning":0,"cache":{"read":16283,"write":575}}}}'
    event = Ralph::Events.parse(json)

    assert_equal 16_864, event.context_size
  end
end
