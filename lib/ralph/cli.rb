# frozen_string_literal: true

module Ralph
  # Command-line interface for ralph. Parses arguments, reads stdin when piped,
  # combines everything into a prompt, and launches the Loop.
  #
  # Usage:
  #   cat prompt.md | ralph "extra instructions" --model=opus-4.5 --max-iterations=10
  class CLI
    def initialize(argv)
      @argv = argv.dup
      @options = {
        model: nil,
        max_iterations: nil,
        duration: nil,
        max_context: nil,
        completion: nil
      }
    end

    def run
      parse_options
      build_prompt.then do |prompt|
        if prompt.nil? || prompt.strip.empty?
          $stderr.puts "Error: no prompt provided."
          $stderr.puts "Usage: ralph \"your prompt\" [options]"
          $stderr.puts "       cat prompt.md | ralph [options]"
          $stderr.puts
          $stderr.puts parser.help
          exit 1
        else
          @options[:prompt] = prompt
          Ralph::Loop.new(@options).run
        end
      end
    end

    private

    def parse_options
      parser.parse!(@argv)
    rescue OptionParser::InvalidOption, OptionParser::MissingArgument => error
      $stderr.puts "Error: #{error.message}"
      $stderr.puts parser.help
      exit 1
    end

    def parser
      @parser ||= OptionParser.new do |option_parser|
        option_parser.banner = "Usage: ralph [prompt] [options]"
        option_parser.separator ""
        option_parser.separator "Options:"

        option_parser.on("--model=MODEL", "Model to use (e.g. opus-4.5)") do |value|
          @options[:model] = value
        end

        option_parser.on("--max-iterations=N", Integer, "Maximum number of iterations") do |value|
          @options[:max_iterations] = value
        end

        option_parser.on("--duration=SECONDS", Integer, "Maximum total duration in seconds") do |value|
          @options[:duration] = value
        end

        option_parser.on("--max-context=N", Integer, "Maximum context tokens before iteration restart") do |value|
          @options[:max_context] = value
        end

        option_parser.on("--completion=STRING", "Completion string the agent emits when done") do |value|
          @options[:completion] = value
        end

        option_parser.on("-h", "--help", "Show this help message") do
          puts option_parser
          exit 0
        end

        option_parser.on("-v", "--version", "Show version") do
          puts "ralph #{Ralph::VERSION}"
          exit 0
        end
      end
    end

    def build_prompt
      parts = []

      # Read from stdin if data is being piped in
      unless $stdin.tty?
        stdin_content = $stdin.read
        parts << stdin_content if stdin_content && !stdin_content.strip.empty?
      end

      # Remaining positional arguments are the inline prompt
      parts << @argv.join(" ") if @argv.any?

      if parts.any?
        parts.join("\n\n")
      end
    end
  end
end
