# frozen_string_literal: true

module Ralph
  # Wraps the opencode CLI to run headless agent sessions with JSON stream output.
  #
  # Spawns `opencode run` as a subprocess and yields parsed events line-by-line
  # from the JSON stream. Supports cancellation via Process.kill.
  class Opencode
    attr_reader :model, :agent, :pid

    def initialize(model: nil, agent: nil)
      @model = model
      @agent = agent
      @pid = nil
      @process_thread = nil
    end

    # Run opencode with the given prompt. Yields each parsed Event to the block.
    # Returns the exit status of the opencode process.
    def run(prompt, &block)
      command = build_command(prompt)
      @pid = nil

      Open3.popen3(*command) do |stdin, stdout, stderr, wait_thread|
        @pid = wait_thread.pid
        stdin.close

        stdout.each_line do |line|
          line.strip!
          if line.length > 0
            Events.parse(line).then do |event|
              block.call(event) if event
            end
          end
        end

        wait_thread.value
      end
    end

    # Send SIGTERM to the running opencode process.
    def cancel
      if @pid
        Process.kill("TERM", @pid)
      end
    rescue Errno::ESRCH
      # Process already exited -- nothing to do
    end

    # Check whether opencode is available on the system PATH.
    def self.available?
      system("which opencode > /dev/null 2>&1")
    end

    private

    def build_command(prompt)
      command = ["opencode", "run"]
      command.push("--model", @model) if @model
      command.push("--agent", @agent) if @agent
      command.push("--format", "json")
      command.push(prompt)
      command
    end
  end
end
