require 'app/game_settings.rb'

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
        gain: 0.4,
        # Milestone stinger: bright maj7 chord stack (C-E-G-B-C oct) with sine
        # bells. Sharp attack, long exponential decay — celebratory + dignified.
        samples: lambda {
          dur = (SR / 60.0 * 36).ceil # ~0.6s
          freqs = [261.6, 329.6, 392.0, 493.9, 523.3] # C4 E4 G4 B4 C5
          attack = (SR * 0.008).to_i # ~8ms sharp attack
          two_pi = 2.0 * Math::PI
          Array.new(dur) do |i|
            t   = i.to_f / dur
            sec = i.to_f / SR
            sum = freqs.inject(0.0) { |acc, f| acc + Math.sin(two_pi * f * sec) }
            env_attack = i < attack ? i.to_f / attack : 1.0
            env_decay  = (1.0 - t)**1.4
            sum / freqs.length * env_attack * env_decay
          end
        }
      },
      # UI navigate — soft low sine blip for menu selection change + rotor moves.
      ui_navigate: {
        gain: 0.12,
        samples: lambda {
          dur = (SR / 60.0 * 5).ceil # ~80ms
          ramp = (SR * 0.005).to_i
          two_pi = 2.0 * Math::PI
          freq = 600.0
          Array.new(dur) do |i|
            sec = i.to_f / SR
            env = if i < ramp then i.to_f / ramp
                  elsif i > dur - ramp then (dur - i).to_f / ramp
                  else 1.0 - (i - ramp).to_f / (dur - ramp) * 0.6
                  end
            Math.sin(two_pi * freq * sec) * env
          end
        }
      },
      # UI activate — brighter, slightly longer confirmation blip.
      ui_activate: {
        gain: 0.2,
        samples: lambda {
          dur = (SR / 60.0 * 9).ceil # ~150ms
          ramp = (SR * 0.004).to_i
          two_pi = 2.0 * Math::PI
          f1 = 880.0
          f2 = 1760.0
          Array.new(dur) do |i|
            sec = i.to_f / SR
            t   = i.to_f / dur
            env = if i < ramp then i.to_f / ramp
                  else (1.0 - t)**1.2
                  end
            (Math.sin(two_pi * f1 * sec) + Math.sin(two_pi * f2 * sec) * 0.6) * 0.55 * env
          end
        }
      },
      # Shoot — noise burst + 1500→400Hz sine sweep, ~120ms. "Air being cut".
      shoot: {
        gain: 0.25,
        samples: lambda {
          dur = (SR / 60.0 * 7).ceil # ~120ms
          attack = (SR * 0.003).to_i
          two_pi = 2.0 * Math::PI
          f_start = 1500.0
          f_end   = 400.0
          Array.new(dur) do |i|
            t   = i.to_f / dur
            sec = i.to_f / SR
            freq = f_start + (f_end - f_start) * t
            noise = rand * 2.0 - 1.0
            tone  = Math.sin(two_pi * freq * sec)
            env_attack = i < attack ? i.to_f / attack : 1.0
            env_decay  = (1.0 - t)**1.6
            (noise * 0.55 + tone * 0.45) * env_attack * env_decay
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
      # Player death — sub-bass impact click pre-layer + synth detune crash.
      # First ~80ms gets a low 60Hz punch for oomph; the existing detune sweep
      # continues over the full duration. Sits under the music duck.
      player_death: {
        gain: 0.5,
        samples: lambda {
          dur = (SR / 60.0 * 22).ceil # ~0.37s
          f1 = 220.0
          detune_start = 6.0
          detune_end   = 48.0
          two_pi = 2.0 * Math::PI
          punch_dur = (SR * 0.08).to_i # ~80ms sub-bass click
          punch_attack = (SR * 0.002).to_i # 2ms sharp click attack
          Array.new(dur) do |i|
            t   = i.to_f / dur
            sec = i.to_f / SR
            f2  = f1 + detune_start + (detune_end - detune_start) * t
            env = (1.0 - t)**1.6
            crash = (Math.sin(two_pi * f1 * sec) + Math.sin(two_pi * f2 * sec)) * 0.5 * env
            if i < punch_dur
              punch_env = if i < punch_attack then i.to_f / punch_attack
                          else (1.0 - (i - punch_attack).to_f / (punch_dur - punch_attack))**2.0
                          end
              punch = Math.sin(two_pi * 60.0 * sec) * 0.9 * punch_env
              crash + punch
            else
              crash
            end
          end
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
        gain: (gain || entry[:gain] || DEFAULT_GAIN) * GameSettings.sfx_gain,
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
