module Audio
  class TrackPlayer
    attr_reader :track_key, :completion, :filter_type, :backend

    def initialize(track_name, definition, args, backend: :legacy)
      @track_name  = track_name
      @track_key   = :"track_#{track_name}"
      @definition  = definition
      @completion  = 0.0
      @filter_type = :none
      @backend     = backend

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

      args.audio[@track_key]&.tap { |a| a.gain = final_gain }

      return unless @backend == :native

      NativeBridge.push_track_params(
        track_name: @track_name,
        cutoff_hz: cutoff_hz,
        resonance: resonance,
        gain: final_gain,
        bypass_mix: bypass_mix
      )
    end

    private

    def register_audio(args)
      return register_native_audio(args) if @backend == :native && NativeBridge.ready_for_streaming?

      register_legacy_audio(args)
    end

    def register_legacy_audio(args)
      args.audio[@track_key] = {
        input:   @definition.input_path,
        gain:    0.0,
        looping: true,
        paused:  false,
      }
    end

    def register_native_audio(args)
      offset_frames = 0
      frame_count = (MusicTheory::SAMPLE_RATE / 60.0).ceil

      args.audio[@track_key] = {
        input: [1, MusicTheory::SAMPLE_RATE, lambda {
          chunk = NativeBridge.next_chunk(
            track_name: @track_name,
            input_path: @definition.input_path,
            offset_frames: offset_frames,
            frame_count: frame_count
          )
          offset_frames += chunk.length
          chunk
        }],
        gain: 1.0,
        looping: true,
        paused: false,
      }
    end
  end
end
