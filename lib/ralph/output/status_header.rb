module Ralph
  module Output
    class StatusHeader
      def self.call
        puts <<~HEADER

          ╔#{═ * 66}╗
          ║                    Ralph Wiggum Status                           ║
          ╚#{═ * 66}╝
        HEADER
      end

    private

    def self.═
      "="
    end
    end
  end
end