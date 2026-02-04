# frozen_string_literal: true

require "minitest/autorun"
require "ralph"

class TestOpencode < Minitest::Test
  def test_initialize_with_defaults
    agent = Ralph::Opencode.new

    assert_nil agent.model
    assert_nil agent.agent
    assert_nil agent.pid
  end

  def test_initialize_with_options
    agent = Ralph::Opencode.new(model: "opus-4.5", agent: "code")

    assert_equal "opus-4.5", agent.model
    assert_equal "code", agent.agent
  end

  def test_build_command_minimal
    agent = Ralph::Opencode.new
    command = agent.send(:build_command, "hello world")

    assert_equal ["opencode", "run", "--format", "json", "hello world"], command
  end

  def test_build_command_with_model
    agent = Ralph::Opencode.new(model: "opus-4.5")
    command = agent.send(:build_command, "hello world")

    assert_equal ["opencode", "run", "--model", "opus-4.5", "--format", "json", "hello world"], command
  end

  def test_build_command_with_all_options
    agent = Ralph::Opencode.new(model: "opus-4.5", agent: "code")
    command = agent.send(:build_command, "hello world")

    expected = ["opencode", "run", "--model", "opus-4.5", "--agent", "code", "--format", "json", "hello world"]
    assert_equal expected, command
  end

  def test_cancel_without_pid_does_not_raise
    agent = Ralph::Opencode.new
    # Should not raise even without a running process
    agent.cancel
  end
end
