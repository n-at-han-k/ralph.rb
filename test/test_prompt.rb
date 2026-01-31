# frozen_string_literal: true

require "minitest/autorun"
require "tempfile"

$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))
require "ralph"

class TestPrompt < Minitest::Test
  def test_from_args_single_part
    parts = ["Build a REST API"]
    prompt = Ralph::Prompt.from_parts(parts)
    
    assert_equal "Build a REST API", prompt.to_s
    assert_equal "", prompt.source
    refute prompt.from_file?
    refute prompt.empty?
  end

  def test_from_args_multiple_parts
    parts = ["Build", "a", "REST", "API"]
    prompt = Ralph::Prompt.from_parts(parts)
    
    assert_equal "Build a REST API", prompt.to_s
    assert_equal "", prompt.source
    refute prompt.from_file?
    refute prompt.empty?
  end

  def test_from_args_empty_parts
    parts = []
    prompt = Ralph::Prompt.from_parts(parts)
    
    assert_equal "", prompt.to_s
    assert_equal "", prompt.source
    refute prompt.from_file?
    assert prompt.empty?
  end

  def test_from_args_whitespace_parts
    parts = ["  ", "\t", "\n"]
    prompt = Ralph::Prompt.from_parts(parts)
    
    assert_equal "   \t \n", prompt.to_s # join with spaces (first element has 2 spaces + 1 from join)
    assert_equal "", prompt.source
    refute prompt.from_file?
    assert prompt.empty? # Empty because it's only whitespace
  end

  def test_from_explicit_prompt_file
    temp_file = create_temp_file("Create a simple hello world app")
    
    prompt = Ralph::Prompt.from_parts([], prompt_file: temp_file.path)
    
    assert_equal "Create a simple hello world app", prompt.to_s
    assert_equal temp_file.path, prompt.source
    assert prompt.from_file?
    refute prompt.empty?
    
    temp_file.close
    temp_file.unlink
  end

  def test_from_implicit_file_single_part
    temp_file = create_temp_file("Build a todo app")
    
    prompt = Ralph::Prompt.from_parts([temp_file.path])
    
    assert_equal "Build a todo app", prompt.to_s
    assert_equal temp_file.path, prompt.source
    assert prompt.from_file?
    refute prompt.empty?
    
    temp_file.close
    temp_file.unlink
  end

  def test_from_implicit_file_multiple_parts_fallback
    parts = ["file1", "file2", "extra"]
    prompt = Ralph::Prompt.from_parts(parts)
    
    # Should join as args, not treat as files
    assert_equal "file1 file2 extra", prompt.to_s
    assert_equal "", prompt.source
    refute prompt.from_file?
    refute prompt.empty?
  end

  def test_prompt_file_priority_explicit_over_implicit
    temp_file1 = create_temp_file("Content from explicit file")
    temp_file2 = create_temp_file("Content from implicit file")
    
    prompt = Ralph::Prompt.from_parts([temp_file2.path], prompt_file: temp_file1.path)
    
    # Should use explicit file, not implicit
    assert_equal "Content from explicit file", prompt.to_s
    assert_equal temp_file1.path, prompt.source
    assert prompt.from_file?
    refute prompt.empty?
    
    temp_file1.close
    temp_file1.unlink
    temp_file2.close
    temp_file2.unlink
  end

  def test_file_not_found_error
    prompt = Ralph::Prompt.from_parts(["nonexistent_file.md"])
    
    # Should treat as args, not file (since only single part but file doesn't exist)
    assert_equal "nonexistent_file.md", prompt.to_s
    assert_equal "", prompt.source
    refute prompt.from_file?
    refute prompt.empty?
  end

  def test_explicit_file_not_found_error
    assert_raises(Ralph::Prompt::Error) do
      Ralph::Prompt.from_parts([], prompt_file: "nonexistent_file.md")
    end
  end

  def test_file_path_is_directory
    Dir.mktmpdir do |dir|
      assert_raises(Ralph::Prompt::Error) do
        Ralph::Prompt.from_parts([], prompt_file: dir)
      end
    end
  end

  def test_empty_file_error
    temp_file = Tempfile.new("empty_prompt")
    temp_file.write("") # Write empty string
    temp_file.flush
    
    assert_raises(Ralph::Prompt::Error) do
      Ralph::Prompt.from_parts([], prompt_file: temp_file.path)
    end
    
    temp_file.close
    temp_file.unlink
  end

  def test_whitespace_only_file_error
    temp_file = Tempfile.new("whitespace_prompt")
    temp_file.write("   \n\t  \n  ") # Only whitespace
    temp_file.flush
    
    assert_raises(Ralph::Prompt::Error) do
      Ralph::Prompt.from_parts([], prompt_file: temp_file.path)
    end
    
    temp_file.close
    temp_file.unlink
  end

  def test_file_with_valid_content
    temp_file = create_temp_file("   Valid content with spaces   ")
    
    prompt = Ralph::Prompt.from_parts([], prompt_file: temp_file.path)
    
    assert_equal "   Valid content with spaces   ", prompt.to_s
    assert_equal temp_file.path, prompt.source
    assert prompt.from_file?
    refute prompt.empty? # Not empty because it contains whitespace
    
    temp_file.close
    temp_file.unlink
  end

  def test_empty_method_strips_whitespace
    # Test with pure whitespace
    prompt = Ralph::Prompt.new("   \n\t  \n  ")
    assert prompt.empty?
    
    # Test with content
    prompt = Ralph::Prompt.new("  Valid content  ")
    refute prompt.empty?
    
    # Test with empty string
    prompt = Ralph::Prompt.new("")
    assert prompt.empty?
  end

  def test_to_s_returns_raw_text
    content = "Build a REST API with tests"
    prompt = Ralph::Prompt.new(content)
    
    assert_equal content, prompt.to_s
  end

  def test_from_file_detection
    file_prompt = Ralph::Prompt.new("Content", source: "test.md")
    assert file_prompt.from_file?
    
    args_prompt = Ralph::Prompt.new("Content", source: "")
    refute args_prompt.from_file?
  end

  def test_error_messages
    # Test file not found
    error = assert_raises(Ralph::Prompt::Error) do
      Ralph::Prompt.from_parts([], prompt_file: "missing.md")
    end
    assert_match(/Prompt file not found/, error.message)
    assert_match(/missing\.md/, error.message)
    
    # Test directory instead of file
    Dir.mktmpdir do |dir|
      error = assert_raises(Ralph::Prompt::Error) do
        Ralph::Prompt.from_parts([], prompt_file: dir)
      end
      assert_match(/Prompt path is not a file/, error.message)
      assert_match(/#{dir}/, error.message)
    end
    
    # Test empty file
    temp_file = Tempfile.new("empty")
    temp_file.flush
    error = assert_raises(Ralph::Prompt::Error) do
      Ralph::Prompt.from_parts([], prompt_file: temp_file.path)
    end
    assert_match(/Prompt file is empty/, error.message)
    assert_match(/#{temp_file.path}/, error.message)
    temp_file.close
    temp_file.unlink
  end

  private

  def create_temp_file(content)
    temp_file = Tempfile.new("test_prompt")
    temp_file.write(content)
    temp_file.flush
    temp_file
  end
end