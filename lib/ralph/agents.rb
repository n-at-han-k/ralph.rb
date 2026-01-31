# frozen_string_literal: true

module Ralph
  # Agent configuration
  AgentConfig = Struct.new(
    :type,             # Symbol - :opencode, :claude_code, :codex
    :command,          # String - CLI command name
    :build_args,       # Proc(prompt, model, options) -> Array<String>
    :build_env,        # Proc(options) -> Hash<String, String>
    :parse_tool_output,# Proc(line) -> String or nil
    :config_name,      # String - display name
    keyword_init: true
  )
  module Agents
    module_function

    def all
      {
        opencode: AgentConfig.new(
          type: :opencode,
          command: "opencode",
          build_args: lambda { |prompt_text, model_name, _options|
            cmd_args = ["run"]
            if model_name && !model_name.empty?
              cmd_args.push("-m", model_name)
            end
            cmd_args.push(prompt_text)
            cmd_args
          },
          build_env: lambda { |options|
            env = ENV.to_h.dup
            if options[:filter_plugins] || options[:allow_all_permissions]
              env["OPENCODE_CONFIG"] = Storage::State.ensure_ralph_config(
                filter_plugins: options[:filter_plugins],
                allow_all_permissions: options[:allow_all_permissions]
              )
            end
            env
          },
          parse_tool_output: lambda { |line|
            match = Helpers.strip_ansi(line).match(/^\|\s{2}([A-Za-z0-9_-]+)/)
            match ? match[1] : nil
          },
          config_name: "OpenCode"
        ),

        claude_code: AgentConfig.new(
          type: :claude_code,
          command: "claude",
          build_args: lambda { |prompt_text, model_name, options|
            cmd_args = ["-p", prompt_text]
            if model_name && !model_name.empty?
              cmd_args.push("--model", model_name)
            end
            if options && options[:allow_all_permissions]
              cmd_args.push("--dangerously-skip-permissions")
            end
            cmd_args
          },
          build_env: lambda { |_options| ENV.to_h.dup },
          parse_tool_output: lambda { |line|
            match = Helpers.strip_ansi(line).match(/(?:Using|Called|Tool:)\s+([A-Za-z0-9_-]+)/i)
            match ? match[1] : nil
          },
          config_name: "Claude Code"
        ),

        codex: AgentConfig.new(
          type: :codex,
          command: "codex",
          build_args: lambda { |prompt_text, model_name, options|
            cmd_args = ["exec"]
            if model_name && !model_name.empty?
              cmd_args.push("--model", model_name)
            end
            if options && options[:allow_all_permissions]
              cmd_args.push("--full-auto")
            end
            cmd_args.push(prompt_text)
            cmd_args
          },
          build_env: lambda { |_options| ENV.to_h.dup },
          parse_tool_output: lambda { |line|
            match = Helpers.strip_ansi(line).match(/(?:Tool:|Using|Calling|Running)\s+([A-Za-z0-9_-]+)/i)
            match ? match[1] : nil
          },
          config_name: "Codex"
        )
      }
    end

    # Map CLI agent name strings to symbols
    AGENT_NAME_MAP = {
      "opencode" => :opencode,
      "claude-code" => :claude_code,
      "codex" => :codex
    }.freeze

    def resolve(name_str)
      sym = AGENT_NAME_MAP[name_str]
      return nil unless sym
      all[sym]
    end

    def valid_agent_names
      AGENT_NAME_MAP.keys
    end

    def validate!(agent_config)
      path = Helpers.which(agent_config.command)
      unless path
        $stderr.puts "Error: #{agent_config.config_name} CLI ('#{agent_config.command}') not found."
        exit 1
      end
    end
  end
end
