# frozen_string_literal: true

require "minitest/autorun"

$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))
require "ralph"

class TestPromptTemplate < Minitest::Test
  def test_inject_with_string
    context = Ralph::Storage::Context.new
    tasks = Ralph::Storage::Tasks.new
    prompt = Ralph::PromptTemplate.inject("Build a REST API", context: context, tasks: tasks)

    assert_equal "Build a REST API", prompt.to_s
    refute prompt.empty?
  end

  def test_inject_empty_string
    context = Ralph::Storage::Context.new
    tasks = Ralph::Storage::Tasks.new
    prompt = Ralph::PromptTemplate.inject("", context: context, tasks: tasks)

    assert_equal "", prompt.to_s
    assert prompt.empty?
  end

  def test_inject_whitespace_string
    context = Ralph::Storage::Context.new
    tasks = Ralph::Storage::Tasks.new
    prompt = Ralph::PromptTemplate.inject("   \t \n", context: context, tasks: tasks)

    assert_equal "   \t \n", prompt.to_s
    assert prompt.empty?
  end

  def test_inject_with_piped_and_argv_prompt
    context = Ralph::Storage::Context.new
    tasks = Ralph::Storage::Tasks.new
    user_prompt = "contents from stdin\nBuild a REST API"
    prompt = Ralph::PromptTemplate.inject(user_prompt, context: context, tasks: tasks)

    assert_equal "contents from stdin\nBuild a REST API", prompt.to_s
    refute prompt.empty?
  end

  def test_empty_method_strips_whitespace
    # Test with pure whitespace
    prompt = Ralph::PromptTemplate.new("   \n\t  \n  ")
    assert prompt.empty?

    # Test with content
    prompt = Ralph::PromptTemplate.new("  Valid content  ")
    refute prompt.empty?

    # Test with empty string
    prompt = Ralph::PromptTemplate.new("")
    assert prompt.empty?
  end

  def test_to_s_returns_user_prompt
    content = "Build a REST API with tests"
    prompt = Ralph::PromptTemplate.new(content)

    assert_equal content, prompt.to_s
  end
end
