module Audio
  class TrackPlayer
    attr_reader :track_key, :completion, :filter_type

    def initialize(track_name, definition, args)
      @track_name  = track_name
      @track_key   = :"track_#{track_name}"
      @definition  = definition
      @completion  = 0.0
      @filter_type = :none

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

    private

    def register_audio(args)
      args.audio[@track_key] = {
        input:   @definition.input_path,
        gain:    0.0,
        looping: true,
        paused:  false,
      }
    end
  end
end
