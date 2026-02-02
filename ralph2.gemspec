# frozen_string_literal: true

require_relative "lib/ralph/version"

Gem::Specification.new do |spec|
  spec.name = "ralph"
  spec.version = Ralph::VERSION
  spec.authors = ["Nathan Kidd"]
  spec.email = ["nathankidd@hey.com"]

  spec.summary = "Autonomous agentic loop for Claude Code, Codex & OpenCode"

  spec.description = <<~DESC
    Ralph Wiggum Loop - Iterative AI development with AI agents.
    An autonomous agentic loop that drives Claude Code, Codex, and OpenCode.
  DESC

  spec.homepage = "https://github.com/n-at-han-k/ralph.rb"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.3"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["documentation_uri"] = spec.homepage
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "minitest", "~> 5.0"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rubocop", "~> 1.21"
end
