# frozen_string_literal: true

module Ralph
  module Git
    # Captures and compares file state via git for change detection
    class FileSnapshot
      attr_reader :files

      def initialize(files)
        @files = files
      end

      # Capture a snapshot of all tracked/modified files and their git hashes
      def self.capture
        files = {}
        begin
          status = `git status --porcelain 2>/dev/null`.strip
          tracked = `git ls-files 2>/dev/null`.strip

          all_files = Set.new
          status.each_line do |line|
            name = line[3..]&.strip
            all_files.add(name) if name && !name.empty?
          end
          tracked.each_line do |file|
            f = file.strip
            all_files.add(f) unless f.empty?
          end

          all_files.each do |file|
            begin
              hash = `git hash-object #{file} 2>/dev/null`.strip
              files[file] = hash unless hash.empty?
            rescue StandardError
              # skip
            end
          end
        rescue StandardError
          # git not available
        end
        new(files)
      end

      # Return list of files that changed between two snapshots
      def self.modified_since(before, after)
        changed = []

        after.files.each do |file, hash|
          prev_hash = before.files[file]
          changed << file if prev_hash != hash
        end

        before.files.each_key do |file|
          changed << file unless after.files.key?(file)
        end

        changed
      end
    end
  end
end
