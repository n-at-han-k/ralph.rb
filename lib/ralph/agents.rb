module Ralph
  module Agents

    module_function

    AGENT_NAME_MAP = {
      "opencode" => :opencode,
      "claude-code" => :claude_code,
      "codex" => :codex
    }.freeze

    def valid_agent_names = AGENT_NAME_MAP.keys

    def resolve(name_str)
      AGENT_NAME_MAP[name_str].then do |sym|
        case sym
        when :opencode    then OpenCode.new.call
        when :claude_code then ClaudeCode.new.call
        when :codex       then Codex.new.call
        else nil          end
      end
    end
  end
end
