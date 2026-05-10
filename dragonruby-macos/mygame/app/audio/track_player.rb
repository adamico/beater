module Audio
  class TrackPlayer
    DENSITY_THRESHOLDS = [
      { range: 0.00...0.25, mask: :sparse },
      { range: 0.25...0.50, mask: :medium },
      { range: 0.50...0.75, mask: :dense  },
      { range: 0.75..1.01,  mask: :full   },
    ].freeze

    attr_reader :track_key, :completion, :filter_type

    def initialize(track_name, definition, args)
      @track_name  = track_name
      @track_key   = :"track_#{track_name}"
      @definition  = definition
      @completion  = 0.0
      @filter_type = :none

      @state = {
        completion:    0.0,
        note_queue:    [],
        active_filter: Filters::Null.new,
      }.merge(Filters::Null.initial_state)

      register_audio(args)
    end

    def update_completion(ratio)
      @completion             = ratio.clamp(0.0, 1.0)
      @state[:completion]     = @completion
    end

    def queue_dot_sfx
      @state[:note_queue] << { samples: @definition.sfx_fn.call, pos: 0 }
    end

    def unlock_fully
      update_completion(1.0)
    end

    def swap_filter(type, **opts)
      filter, init_state     = FilterFactory.build(type, **opts)
      @filter_type           = type
      @state.merge!(init_state)
      @state[:active_filter] = filter
    end

    private

    def register_audio(args)
      state      = @state
      definition = @definition

      audio_lambda = lambda do
        completion = state[:completion]
        step       = BeatClock.current_step(Kernel.tick_count)
        frame_size = WaveGenerator::SILENCE_FRAME.length

        mask_key     = TrackPlayer::DENSITY_THRESHOLDS
                         .find { |t| t[:range].cover?(completion) }
                         &.dig(:mask) || :full
        active_steps = TrackLibrary::DENSITY_MASKS[mask_key]

        note_sym   = definition.pattern[step]
        base_frame = if note_sym && active_steps.include?(step) && BeatClock.step_changed?(Kernel.tick_count)
                       WaveGenerator.tile_to_frame(definition.wave_fn.call(note_sym))
                     else
                       WaveGenerator::SILENCE_FRAME.dup
                     end

        base_frame = state[:active_filter].process(base_frame, state)

        gain = case completion
               when 0.0...0.25 then 0.45
               when 0.25...0.50 then 0.68
               when 0.50...0.75 then 0.84
               else 1.0
               end
        base_frame.map! { |s| s * gain }

        state[:note_queue].each do |note|
          chunk_len = [frame_size, note[:samples].length - note[:pos]].min
          note[:samples].slice(note[:pos], chunk_len).each_with_index do |s, i|
            base_frame[i] = (base_frame[i] + s * 0.5).clamp(-1.0, 1.0)
          end
          note[:pos] += chunk_len
        end
        state[:note_queue].reject! { |n| n[:pos] >= n[:samples].length }

        base_frame
      end

      args.audio[@track_key] = {
        input:   [1, MusicTheory::SAMPLE_RATE, audio_lambda],
        gain:    0.0,
        looping: true,
        paused:  false,
      }
    end
  end
end
