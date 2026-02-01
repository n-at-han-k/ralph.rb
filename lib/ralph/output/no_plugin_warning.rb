module Ralph
  module Output
    class NoPluginWarning
      def self.call(agent_config:)
        case agent_config.type
        when :claude_code
          warn 'Warning: --no-plugins has no effect with Claude Code agent'
        when :codex
          warn 'Warning: --no-plugins has no effect with Codex agent'
        end
      end
    end
  end
end
