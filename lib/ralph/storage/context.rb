# frozen_string_literal: true

require "fileutils"

module Ralph
  module Storage
    # Represents the persistent AI context file for conversational continuity.
    #
    # Always instantiate with Context.new — it represents the file on disk.
    # Content is read lazily; the file is created on first write/append.
    class Context
      attr_reader :path

      def initialize
        FileUtils.mkdir_p(dir)
      end

      def self.dir
        @dir ||= File.join(Dir.pwd, ".ralph")
      end

      def dir = self.class.dir

      def path
        @path ||= File.join(dir, "ralph-context.md")
      end

      def content
        if File.exist?(path)
          text = File.read(path).strip
          text.empty? ? nil : text
        end
      rescue StandardError
        nil
      end

      def present? = !content.nil?

      def append(text)
        if File.exist?(path)
          write(File.read(path) + text)
        else
          write("# Ralph Loop Context\n#{text}")
        end
      end

      def write(text)
        File.write(path, text)
      end

      def clear
        if File.exist?(path)
          File.delete(path) 
        end
      end
    end
  end
end
