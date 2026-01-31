# frozen_string_literal: true

module Ralph
  module Output
    class PluginError
      def self.call
        $stderr.puts "\n❌ OpenCode tried to load the legacy 'ralph-wiggum' plugin. This package is CLI-only."
        $stderr.puts "Remove 'ralph-wiggum' from your opencode.json plugin list, or re-run with --no-plugins."
      end
    end
  end
end