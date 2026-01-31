# frozen_string_literal: true

require "fileutils"
require "json"
require "optparse"
require "open3"

module Ralph
end

# Require everything by globbing, because I'm too lazy to do anything else
Dir[File.join(__dir__, "ralph", "**", "*.rb")].sort.each { |f| require f }
