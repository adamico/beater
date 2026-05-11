module Audio
  class TrackPlayer
    attr_reader :track_key, :completion, :filter_type, :backend
    DEFAULT_STREAM_SAMPLE_RATE = MusicTheory::SAMPLE_RATE

    def initialize(track_name, definition, args, backend: :legacy)
      @track_name  = track_name
      @track_key   = :"track_#{track_name}"
      @definition  = definition
      @completion  = 0.0
      @filter_type = :none
      @backend     = backend
      @stream_sample_rate = self.class.detect_wav_sample_rate(@definition.input_path) || DEFAULT_STREAM_SAMPLE_RATE
      @last_native_params = nil
      @last_output_gain = nil

      register_audio(args)
    end

    def update_completion(ratio)
      @completion = ratio.clamp(0.0, 1.0)
    end

    def queue_dot_sfx
      nil
    end

    def unlock_fully
      update_completion(1.0)
    end

    def swap_filter(type, **opts)
      @filter_type = type
    end

    def apply_mix_settings(args, gain:, cutoff_hz:, resonance:, duck_multiplier:, bypass_mix:)
      final_gain = (gain.to_f * duck_multiplier.to_f).clamp(0.0, 1.2)

      # For procedural streams, changing gain while playing can cause clicks.
      # Keep native stream gain stable; only legacy/file playback uses this path.
      if @backend != :native && (!@last_output_gain || (@last_output_gain - final_gain).abs > 0.001)
        args.audio[@track_key]&.tap { |a| a.gain = final_gain }
        @last_output_gain = final_gain
      end

      return unless @backend == :native

      current_params = {
        cutoff_hz: cutoff_hz ? cutoff_hz.to_f : nil,
        resonance: resonance ? resonance.to_f : nil,
        gain: final_gain,
        bypass_mix: 1.0,
      }

      return if same_native_params?(@last_native_params, current_params)

      @last_native_params = current_params

      NativeBridge.push_track_params(
        track_name: @track_name,
        cutoff_hz: current_params[:cutoff_hz],
        resonance: current_params[:resonance],
        gain: current_params[:gain],
        bypass_mix: current_params[:bypass_mix]
      )
    end

    private

    def self.detect_wav_sample_rate(path)
      return nil unless path
      candidates = [
        path,
        File.join("mygame", path)
      ]

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

          sample_rate = header[24, 4].unpack("V")[0]
          return sample_rate if sample_rate && sample_rate > 0
        rescue StandardError
          next
        end
      end

      nil
    end

    def same_native_params?(a, b)
      return false unless a

      almost_equal = ->(x, y, eps) {
        return x.nil? && y.nil? if x.nil? || y.nil?

        (x - y).abs <= eps
      }

      almost_equal.call(a[:cutoff_hz], b[:cutoff_hz], 0.5) &&
        almost_equal.call(a[:resonance], b[:resonance], 0.01) &&
        almost_equal.call(a[:gain], b[:gain], 0.001) &&
        almost_equal.call(a[:bypass_mix], b[:bypass_mix], 0.001)
    end

    def register_audio(args)
      return register_native_audio(args) if @backend == :native && NativeBridge.ready_for_streaming?

      register_legacy_audio(args)
    end

    def register_legacy_audio(args)
      args.audio[@track_key] = {
        input:   @definition.input_path,
        gain:    1.0,
        looping: true,
        paused:  false,
      }
    end

    def register_native_audio(args)
      offset_frames = 0
      # DragonRuby recommends procedural callbacks return at least 0.1s-0.5s of audio
      # per call to avoid skips/clicks; use 0.25s as a stable middle ground.
      frame_count = (@stream_sample_rate * 0.25).ceil

      args.audio[@track_key] = {
        input: [2, @stream_sample_rate, lambda {
          chunk = NativeBridge.next_chunk(
            track_name: @track_name,
            input_path: @definition.input_path,
            offset_frames: offset_frames,
            frame_count: frame_count
          )
          # Native chunk is interleaved stereo, so advance by frame count.
          offset_frames += (chunk.length / 2)
          chunk
        }],
        gain: 1.0,
        looping: true,
        paused: false,
      }
    end
  end
end
