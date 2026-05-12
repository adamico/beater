module Audio
  module WavInspector
    def self.sample_rate(path)
      return nil unless path
      candidates = [path, File.join("mygame", path)]

      candidates.each do |candidate|
        begin
          bytes = if File.respond_to?(:binread)
                    File.binread(candidate)
                  else
                    File.read(candidate)
                  end
          next unless bytes

          header = bytes[0, 44]
          next unless header && header.bytesize >= 28
          next unless header[0, 4] == "RIFF" && header[8, 4] == "WAVE"

          rate = header[24, 4].unpack("V")[0]
          return rate if rate && rate > 0
        rescue StandardError
          next
        end
      end

      nil
    end
  end
end
