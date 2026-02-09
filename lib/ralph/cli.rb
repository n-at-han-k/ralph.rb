# frozen_string_literal: true

module Ralph
  # Command-line interface for ralph. Parses subcommands (build/plan),
  # arguments, reads stdin when piped, and launches the Loop.
  #
  # Usage:
  #   ralph build "focus on auth" --model=opus-4.5 --max-iterations=10
  #   ralph plan "user authentication system"
  #   ralph --max-iterations=10  # equivalent to: ralph build --max-iterations=10
  #   cat prompt.md | ralph build --model=opus-4.5
  class CLI
    SUBCOMMANDS = %w[build plan].freeze

    attr_reader :subcommand

    def initialize(argv)
      @argv = argv.dup
      @subcommand = extract_subcommand
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
      prompt_object = build_prompt_object
      @options[:prompt] = prompt_object

      Ralph::Loop.new(@options).run

    rescue OptionParser::InvalidOption, OptionParser::MissingArgument => error
      $stderr.puts "Error: #{error.message}"
      $stderr.puts parser.help
      exit 1
    end

    private

      def extract_subcommand
        if @argv.first && SUBCOMMANDS.include?(@argv.first)
          @argv.shift
        else
          "build"
        end
      end

      def parse_options
        parser.parse!(@argv)
      end
      
      def parser
        @parser ||= OptionParser.new do |option_parser|
          option_parser.banner = "Usage: ralph [build|plan] [text] [options]"
          option_parser.separator ""
          option_parser.separator "Subcommands:"
          option_parser.separator "  build    Implement tasks from the plan (default)"
          option_parser.separator "  plan     Gap analysis and plan generation"
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

      def read_user_text
        parts = []

        # Read from stdin if data is being piped in
        unless $stdin.tty?
          stdin_content = $stdin.read
          parts << stdin_content if stdin_content && !stdin_content.strip.empty?
        end

        # Remaining positional arguments are the inline text
        parts << @argv.join(" ") if @argv.any?

        parts.join("\n\n") if parts.any?
      end

      def build_prompt_object
        user_text = read_user_text
        completion = @options[:completion]

        if @subcommand == "plan"
          build_plan_prompt(user_text, completion)
        else
          build_build_prompt(user_text, completion)
        end
      end

      def build_plan_prompt(user_text, completion)
        Hash.new.then do |plan_options|
          plan_options[:goal] = user_text if user_text
          plan_options[:all_done] = completion if completion
          Prompt::Plan.new(**plan_options)
        end
      end

      def build_build_prompt(user_text, completion)
        Hash.new.then do |build_options|
          build_options[:context] = user_text if user_text
          build_options[:all_done] = completion if completion
          Prompt::Build.new(**build_options)
        end
      end
  end
end
