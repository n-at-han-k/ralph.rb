# frozen_string_literal: true

require "fileutils"
require "json"
require "optparse"
require "open3"

module Ralph
end

# Helpers must load first since other modules extend it at parse time
require_relative "ralph/helpers"

# Require everything else by globbing, because I'm too lazy to do anything else
Dir[File.join(__dir__, "ralph", "**", "*.rb")].sort.each { |f| require f }
