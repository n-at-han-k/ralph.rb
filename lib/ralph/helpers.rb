# frozen_string_literal: true

module Ralph
  module Helpers
    def strip_ansi(input)
      input.gsub(/\x1B\[[0-9;]*m/, "")
    end

    def escape_regex(str)
      Regexp.escape(str)
    end

    def format_duration(ms)
      total_seconds = [0, (ms / 1000).floor].max
      hours = total_seconds / 3600
      minutes = (total_seconds % 3600) / 60
      seconds = total_seconds % 60

      if hours > 0
        "#{hours}:#{minutes.to_s.rjust(2, '0')}:#{seconds.to_s.rjust(2, '0')}"
      else
        "#{minutes}:#{seconds.to_s.rjust(2, '0')}"
      end
    end

    def format_duration_long(ms)
      total_seconds = [0, (ms / 1000).floor].max
      hours = total_seconds / 3600
      minutes = (total_seconds % 3600) / 60
      seconds = total_seconds % 60

      if hours > 0
        "#{hours}h #{minutes}m #{seconds}s"
      elsif minutes > 0
        "#{minutes}m #{seconds}s"
      else
        "#{seconds}s"
      end
    end

    def format_tool_summary(tool_counts, max_items = 6)
      return "" if tool_counts.empty?

      entries = tool_counts.sort_by { |_, v| -v }
      shown = entries.first(max_items)
      remaining = entries.length - shown.length

      parts = shown.map { |name, count| "#{name} #{count}" }
      parts << "+#{remaining} more" if remaining > 0
      parts.join(" • ")
    end

    def check_completion(output, promise)
      pattern = /<promise>\s*#{escape_regex(promise)}\s*<\/promise>/i
      output.match?(pattern)
    end

    # Cross-platform which
    def which(cmd)
      exts = ENV["PATHEXT"] ? ENV["PATHEXT"].split(";") : [""]
      ENV["PATH"].split(File::PATH_SEPARATOR).each do |path|
        exts.each do |ext|
          exe = File.join(path, "#{cmd}#{ext}")
          return exe if File.executable?(exe) && !File.directory?(exe)
        end
      end
      nil
    end

    def now_ms
      (Time.now.to_f * 1000).to_i
    end
  end
end
