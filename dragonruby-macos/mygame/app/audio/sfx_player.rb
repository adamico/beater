require 'app/game_settings'

module Audio
  module SFXPlayer
    SR = MusicTheory::SAMPLE_RATE.to_f
    # Shorthand so SFX lambdas read NOTE[:a4] instead of raw 440.0 floats.
    # Names match MusicTheory: a/b/c/d/e/f/g, sharps as `as bs cs ...`, flats
    # as `ab bb cb ...`, octave suffix 0..8 (e.g. :a4, :ds5, :eb5).
    NOTE = MusicTheory::NOTE_FREQUENCIES

    DEFAULT_GAIN = 0.8

    SFX_DEFINITIONS = {
      enemy_eaten: {
        gain: 0.3,
        samples: lambda {
          wave = :saw
          freqs = [NOTE[:a5], NOTE[:g5], NOTE[:f5], NOTE[:ds5],
                   NOTE[:c5], NOTE[:a4], NOTE[:g4], NOTE[:f4]]
          dur  = (SR / 60.0 * 3).ceil # ~50ms per note → ~400ms total
          ramp = 300                  # ~6ms half-cosine A/R
          half_pi = Math::PI / 2.0
          freqs.each_with_index.flat_map do |freq, idx|
            tail = 1.0 - idx.to_f / (freqs.length * 2)
            Array.new(dur) do |i|
              s = WaveGenerator.osc(wave, freq, i)
              env = if i < ramp
                      Math.sin(half_pi * i / ramp)**2
                    elsif i > dur - ramp
                      Math.sin(half_pi * (dur - i) / ramp)**2
                    else
                      1.0
                    end
              s * env * tail
            end
          end
        }
      },
      power_pellet: {
        gain: 0.25,
        # Ascending sine arpeggio. Earlier impl used tile_to_frame which
        # silently truncates back to one game frame regardless of the
        # requested duration — making the arpeggio collapse to ~68ms total.
        # Square+duty 0.3 also produced the "dirty" nasal harmonics.
        samples: lambda {
          wave = :tri
          freqs = [NOTE[:g4], NOTE[:c5], NOTE[:g5], NOTE[:c6]]
          dur = (SR / 60.0 * 4).ceil # ~67ms per note → ~270ms total
          ramp = 96
          freqs.each_with_index.flat_map do |freq, idx|
            tail = 1.0 - idx * 0.05 # tiny per-note decay so the top note doesn't dominate
            Array.new(dur) do |i|
              s = WaveGenerator.osc(wave, freq, i)
              env = if i < ramp then i.to_f / ramp
                    elsif i > dur - ramp then (dur - i).to_f / ramp
                    else 1.0
                    end
              s * env * tail
            end
          end
        }
      },
      game_over: {
        # Descending pitch sweep over 16 segments. Synthesised per-sample so
        # each segment is one continuous sine; earlier impl chained
        # tile_to_frame copies that reset phase mid-buffer (audible clicks),
        # and had no segment envelope so every segment-end was a step.
        gain: 0.3,
        samples: lambda {
          wave = :saw
          ramp = 128
          dur  = (SR / 60.0 * 4).ceil
          16.times.flat_map do |idx|
            t_seg = idx.to_f / 16
            freq  = 880.0 * ((110.0 / 880.0)**t_seg)
            tail  = 1.0 - t_seg * 0.5
            Array.new(dur) do |i|
              s = WaveGenerator.osc(wave, freq, i)
              env = if i < ramp then i.to_f / ramp
                    elsif i > dur - ramp then (dur - i).to_f / ramp
                    else 1.0
                    end
              s * env * tail
            end
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
        # Milestone stinger. Square chord stack with envelope-driven PWM:
        # duty sweeps from 0.2 (thin, harmonically rich → bright attack)
        # to 0.5 (symmetric → mellow bell). Pairs with the amplitude decay
        # so the sound brightens-then-rounds rather than fading flat.
        samples: lambda {
          wave = :square
          dur = (SR / 60.0 * 36).ceil # ~0.6s
          freqs = [NOTE[:c4], NOTE[:g4], NOTE[:c5], NOTE[:g5], NOTE[:c6]]
          attack = (SR * 0.008).to_i
          duty_start = 0.5
          duty_end   = 0.1
          Array.new(dur) do |i|
            t = i.to_f / dur
            duty = duty_start + (duty_end - duty_start) * t
            sum = freqs.inject(0.0) { |acc, f| acc + WaveGenerator.osc(wave, f, i, duty: duty) }
            env_attack = i < attack ? i.to_f / attack : 1.0
            env_decay  = (1.0 - t)**1.4
            sum / freqs.length * env_attack * env_decay
          end
        }
      },
      bullet_absorbed: {
        gain: 0.2,
        samples: lambda {
          wave = :square
          freq = NOTE[:a2]
          duty = 0.5
          dur  = (SR / 60.0 * 6).ceil # ~100ms
          attack = (SR * 0.002).to_i  # 2ms attack to kill onset click
          Array.new(dur) do |i|
            t = i.to_f / dur
            s = WaveGenerator.osc(wave, freq, i, duty: duty)
            env_attack = i < attack ? i.to_f / attack : 1.0
            env_decay  = 1.0 - t
            s * env_attack * env_decay
          end
        }
      },
      bullet_immune: {
        gain: 0.3,
        samples: lambda {
          wave = :sine
          dur = (SR / 60.0 * 9).ceil # ~150ms
          ramp = (SR * 0.004).to_i
          f1 = NOTE[:a5]
          f2 = NOTE[:a6]
          Array.new(dur) do |i|
            t   = i.to_f / dur
            env = if i < ramp then i.to_f / ramp
                  else (1.0 - t)**1.2
                  end
            (WaveGenerator.osc(wave, f1, i) + WaveGenerator.osc(wave, f2, i) * 0.6) * 0.55 * env
          end
        }
      },
      # Shoot — "sonic wave": three dissonant saws (minor 2nd cluster + a
      # tritone above) summed and fed into a 1-pole lowpass whose cutoff
      # opens at the midpoint and closes again at the tail. Triangle-shape
      # filter envelope reads as the wave "passing through" — closed →
      # open → closed.
      #
      # Filter math: alpha = exp(-2π·fc/SR) is the standard 1-pole IIR
      # coefficient. Recomputed per-sample so the cutoff actually sweeps.
      # Saws give the LP something to filter (sine in, sine out — no point).
      shoot: {
        gain: 0.6,
        samples: lambda {
          wave  = :saw
          freqs = [NOTE[:a4], NOTE[:bb4], NOTE[:ds5]] # min2 cluster + tritone
          dur   = (SR / 60.0 * 18).ceil # ~150ms
          attack = (SR * 0.02).to_i
          fc_min = 250.0   # cutoff at the ends (filter closed)
          fc_max = 5500.0  # cutoff at the peak (filter open)
          two_pi_over_sr = WaveGenerator::TWO_PI / SR
          lp = 0.0 # 1-pole filter state
          peak = 0.15 # filter-open peak position 0..1 (lower = open faster)
          Array.new(dur) do |i|
            t = i.to_f / dur
            # Asymmetric triangle on the cutoff: rises fast to `peak`,
            # falls slowly across the remainder.
            tri = t < peak ? t / peak : (1.0 - t) / (1.0 - peak)
            fc = fc_min + (fc_max - fc_min) * tri
            alpha = Math.exp(-two_pi_over_sr * fc)

            raw = freqs.inject(0.0) { |acc, f| acc + WaveGenerator.osc(wave, f, i) } / freqs.length
            lp = (1.0 - alpha) * raw + alpha * lp

            env_attack = i < attack ? i.to_f / attack : 1.0
            env_decay  = (1.0 - t)**1.4
            lp * env_attack * env_decay
          end
        }
      },
      # UI navigate — soft low sine blip for menu selection change + rotor moves.
      ui_navigate: {
        gain: 0.12,
        samples: lambda {
          wave = :sine
          dur = (SR / 60.0 * 5).ceil # ~80ms
          ramp = (SR * 0.005).to_i
          freq = NOTE[:c5]
          sustain_end = 0.4
          decay_span  = (dur - 2 * ramp).to_f
          Array.new(dur) do |i|
            env = if i < ramp
                    i.to_f / ramp
                  elsif i > dur - ramp
                    sustain_end * (dur - i).to_f / ramp
                  else
                    1.0 - (i - ramp).to_f / decay_span * (1.0 - sustain_end)
                  end
            WaveGenerator.osc(wave, freq, i) * env
          end
        }
      },
      # UI activate — brighter, slightly longer confirmation blip.
      ui_activate: {
        gain: 0.12,
        samples: lambda {
          wave = :tri
          dur = (SR / 60.0 * 9).ceil # ~150ms
          ramp = (SR * 0.005).to_i
          freq = NOTE[:g5]
          sustain_end = 0.4 # env level at the sustain→release seam
          decay_span  = (dur - 2 * ramp).to_f
          Array.new(dur) do |i|
            env = if i < ramp
                    i.to_f / ramp
                  elsif i > dur - ramp
                    # Release continues smoothly from sustain_end down to 0.
                    sustain_end * (dur - i).to_f / ramp
                  else
                    1.0 - (i - ramp).to_f / decay_span * (1.0 - sustain_end)
                  end
            WaveGenerator.osc(wave, freq, i) * env
          end
        }
      },
      # Player death — sub-bass impact click pre-layer + synth detune crash.
      # First ~80ms gets a low 60Hz punch for oomph; the existing detune sweep
      # continues over the full duration. Sits under the music duck.
      player_death: {
        gain: 0.5,
        samples: lambda {
          crash_wave = :sine
          punch_wave = :sine
          dur = (SR / 60.0 * 22).ceil # ~0.37s
          f1 = 220.0
          detune_start = 6.0
          detune_end   = 48.0
          punch_dur = (SR * 0.08).to_i # ~80ms sub-bass click
          punch_attack = (SR * 0.002).to_i # 2ms sharp click attack
          Array.new(dur) do |i|
            t   = i.to_f / dur
            f2  = f1 + detune_start + (detune_end - detune_start) * t
            env = (1.0 - t)**1.6
            crash = (WaveGenerator.osc(crash_wave, f1, i) +
                     WaveGenerator.osc(crash_wave, f2, i)) * 0.5 * env
            if i < punch_dur
              punch_env = if i < punch_attack then i.to_f / punch_attack
                          else (1.0 - (i - punch_attack).to_f / (punch_dur - punch_attack))**2.0
                          end
              punch = WaveGenerator.osc(punch_wave, 60.0, i) * 0.9 * punch_env
              crash + punch
            else
              crash
            end
          end
        }
      }
    }.freeze

    def self.play(args, sfx_name, gain: nil)
      entry = SFX_DEFINITIONS[sfx_name]
      return unless entry

      # Hot-reload support: DR reassigns SFX_DEFINITIONS to a new Hash when
      # this file changes on disk, so the constant's object_id flips. When
      # that happens, flush the pre-baked sample cache so the next play
      # re-bakes from the freshly edited lambda. Lets you edit a lambda in
      # the jukebox session and hear the change on the next click.
      token = SFX_DEFINITIONS.object_id
      if args.state.sfx_cache_token != token
        args.state.sfx_cache = {}
        args.state.sfx_cache_token = token
      end
      args.state.sfx_cache ||= {}
      args.state.sfx_cache[sfx_name] ||= entry[:samples].call
      cached = args.state.sfx_cache[sfx_name]
      return unless cached

      key     = next_key(args)
      pos_ref = [0]

      # DR's procedural audio recommends 0.1-0.5s per callback. A one-game-
      # frame chunk (17ms) is well below that and causes buffer-underrun
      # clicks. SFX are short and already fully baked, so the cleanest fix
      # is to hand DR the whole array in a single first call, then feed
      # silence frames until stop_at prunes the entry. No streaming, no
      # mid-buffer snap, no end-of-sample step.
      silence_frame = Array.new((SR / 60.0).ceil, 0.0)
      args.audio[key] = {
        input: [1, MusicTheory::SAMPLE_RATE, lambda {
          if pos_ref[0].zero?
            pos_ref[0] = cached.length
            cached
          else
            silence_frame
          end
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
