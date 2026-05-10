module Audio
  module SFXPlayer
    SR = MusicTheory::SAMPLE_RATE.to_f

    SFX_DEFINITIONS = {
      enemy_eaten: -> {
        [880, 783, 698, 622, 523, 440, 392, 349].flat_map do |freq|
          dur = (SR / 60.0 * 2).ceil
          (WaveGenerator.tile_to_frame(WaveGenerator.sine_period(freq)) * 2).first(dur)
        end
      },
      power_pellet: -> {
        [440, 523, 659, 880].flat_map do |freq|
          dur = (SR / 60.0 * 3).ceil
          WaveGenerator.tile_to_frame(WaveGenerator.square_period(freq, duty: 0.3)).first(dur)
        end
      },
      game_over: -> {
        16.times.flat_map do |i|
          t    = i.to_f / 16
          freq = 880.0 * ((110.0 / 880.0) ** t)
          dur  = (SR / 60.0 * 4).ceil
          WaveGenerator.tile_to_frame(WaveGenerator.sine_period(freq))
            .first(dur).map { |s| s * (1.0 - t * 0.5) }
        end
      },
      dot_tick: -> {
        WaveGenerator.tile_to_frame(WaveGenerator.sine_period(1200))
          .first(400).map { |s| s * 0.25 }
      },
    }.freeze

    def self.play(args, sfx_name)
      args.state.sfx_cache ||= {}
      args.state.sfx_cache[sfx_name] ||= SFX_DEFINITIONS[sfx_name]&.call
      cached = args.state.sfx_cache[sfx_name]
      return unless cached

      key     = next_key(args)
      pos_ref = [0]

      args.audio[key] = {
        input:   [1, MusicTheory::SAMPLE_RATE, -> {
          chunk = cached.slice(pos_ref[0], (SR / 60.0).ceil) || []
          pos_ref[0] += chunk.length
          chunk
        }],
        gain:    0.8,
        looping: false,
        paused:  false,
        stop_at: args.tick_count + (cached.length / (SR / 60.0)).ceil + 2,
      }
    end

    def self.next_key(args)
      args.state.sfx_counter ||= 0
      args.state.sfx_counter  += 1
      :"sfx_#{args.state.sfx_counter}"
    end
  end
end
