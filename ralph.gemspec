# frozen_string_literal: true

require_relative "lib/ralph/version"

Gem::Specification.new do |spec|
  spec.name          = "ralph"
  spec.version       = Ralph::VERSION
  spec.authors       = ["Nathan K"]
  spec.license       = "MIT"

  spec.summary       = "Autonomous agentic loop for Claude Code, Codex & OpenCode"
  spec.description   = "Ralph Wiggum Loop - Iterative AI development with AI agents. " \
                        "An autonomous agentic loop that drives Claude Code, Codex, and OpenCode."
  spec.homepage      = "https://github.com/n-at-han-k/ralph.rb"

  spec.required_ruby_version = ">= 3.3"

  spec.metadata["homepage_uri"]    = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"]   = "#{spec.homepage}/releases"

  spec.files         = Dir["lib/**/*", "exe/*", "LICENSE", "README.md"]
  spec.bindir        = "exe"
  spec.executables   = ["ralph"]

  spec.require_paths = ["lib"]
end
