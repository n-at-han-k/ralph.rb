# frozen_string_literal: true

module Ralph
  class Prompt
    class Error < StandardError; end

    attr_reader :text, :source

    def initialize(text, source: "")
      @text = text
      @source = source
    end

    def to_s
      @text
    end

    def empty?
      @text.strip.empty?
    end

    def from_file?
      !@source.empty?
    end

    class << self
      def from_parts(parts, prompt_file: nil)
        if prompt_file && !prompt_file.empty?
          from_file(prompt_file)
        elsif parts.length == 1 && File.exist?(parts[0])
          from_file(parts[0])
        else
          from_args(parts)
        end
      end

      private

      def from_file(path)
        content = read_file_with_validation(path)
        new(content, source: path)
      end

      def from_args(parts)
        new(parts.join(" "), source: "")
      end

      def read_file_with_validation(path)
        unless File.exist?(path)
          raise Error, "Prompt file not found: #{path}"
        end

        unless File.file?(path)
          raise Error, "Prompt path is not a file: #{path}"
        end

        content = File.read(path)
        if content.strip.empty?
          raise Error, "Prompt file is empty: #{path}"
        end

        content
      rescue Errno::EACCES
        raise Error, "Unable to read prompt file: #{path}"
      end
    end
  end
end
