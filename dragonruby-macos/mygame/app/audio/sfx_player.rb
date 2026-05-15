module Audio
  module SFXPlayer
    SR = MusicTheory::SAMPLE_RATE.to_f

    DEFAULT_GAIN = 0.8

    SFX_DEFINITIONS = {
      enemy_eaten: {
        gain: 0.3,
        samples: lambda {
          freqs = [880, 783, 698, 622, 523, 440, 392, 349]
          ramp  = 96 # ~2ms A/R per segment kills boundary clicks
          freqs.each_with_index.flat_map do |freq, idx|
            dur  = (SR / 60.0 * 2).ceil
            seg  = (WaveGenerator.tile_to_frame(WaveGenerator.sine_period(freq)) * 2).first(dur)
            tail = 1.0 - idx.to_f / (freqs.length * 2) # gentle overall decay
            seg.map.with_index do |s, i|
              env = if i < ramp then i.to_f / ramp
                    elsif i > dur - ramp then (dur - i).to_f / ramp
                    else 1.0
                    end
              s * env * tail
            end
          end
        }
      },
      power_pellet: {
        gain: 0.2,
        samples: lambda {
          [440, 523, 659, 880].flat_map do |freq|
            dur = (SR / 60.0 * 3).ceil
            WaveGenerator.tile_to_frame(WaveGenerator.square_period(freq, duty: 0.3)).first(dur)
          end
        }
      },
      game_over: {
        samples: lambda {
          16.times.flat_map do |i|
            t    = i.to_f / 16
            freq = 880.0 * ((110.0 / 880.0)**t)
            dur  = (SR / 60.0 * 4).ceil
            WaveGenerator.tile_to_frame(WaveGenerator.sine_period(freq))
            .first(dur).map { |s| s * (1.0 - t * 0.5) }
          end
        }
      },
      dot_tick: {
        gain: 0.1,
        samples: lambda {
          WaveGenerator.tile_to_frame(WaveGenerator.sine_period(1200)).first(400)
        }
      },
      track_complete: {
        gain: 0.3,
        # Bright ascending arpeggio — milestone stinger for a finished track.
        samples: lambda {
          [523, 659, 784, 1047].flat_map do |freq|
            dur = (SR / 60.0 * 5).ceil
            WaveGenerator.tile_to_frame(WaveGenerator.square_period(freq, duty: 0.4)).first(dur)
          end
        }
      },
      # ADR-0011: partial bullet hit on enraged ghost — short metallic clank.
      bullet_absorbed: {
        gain: 0.4,
        samples: lambda {
          dur = (SR / 60.0 * 4).ceil
          WaveGenerator.tile_to_frame(WaveGenerator.square_period(220, duty: 0.5))
          .first(dur).map.with_index { |s, i| s * (1.0 - i.to_f / dur) }
        }
      },
      # ADR-0011: bullet against immune (:enrage2) ghost — deeper, harsher.
      bullet_immune: {
        gain: 0.4,
        samples: lambda {
          dur = (SR / 60.0 * 6).ceil
          WaveGenerator.tile_to_frame(WaveGenerator.square_period(110, duty: 0.5))
          .first(dur).map.with_index { |s, i| s * (1.0 - i.to_f / dur) }
        }
      }
    }.freeze

    def self.play(args, sfx_name, gain: nil)
      entry = SFX_DEFINITIONS[sfx_name]
      return unless entry

      args.state.sfx_cache ||= {}
      args.state.sfx_cache[sfx_name] ||= entry[:samples].call
      cached = args.state.sfx_cache[sfx_name]
      return unless cached

      key     = next_key(args)
      pos_ref = [0]

      args.audio[key] = {
        input: [1, MusicTheory::SAMPLE_RATE, lambda {
          chunk = cached.slice(pos_ref[0], (SR / 60.0).ceil) || []
          pos_ref[0] += chunk.length
          chunk
        }],
        gain: gain || entry[:gain] || DEFAULT_GAIN,
        looping: false,
        paused: false,
        stop_at: args.tick_count + (cached.length / (SR / 60.0)).ceil + 2
      }
    end

    def self.next_key(args)
      args.state.sfx_counter ||= 0
      args.state.sfx_counter  += 1
      :"sfx_#{args.state.sfx_counter}"
    end
  end
end
