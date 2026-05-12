require 'app/audio/beat_clock.rb'
require 'app/audio/sfx_player.rb'

module Audio
  # Gates SFX playback to beat-step boundaries. Dot ticks accumulate to at most
  # one per step. Power pellet wins priority over dot tick on the same step.
  # Step resolution is half music BPM (so 8th-notes when music is in 16ths).
  class RhythmicSFXQueue
    def initialize(music_bpm: BeatClock::DEFAULT_BPM)
      set_music_bpm(music_bpm)
      @pending_dot_tick = false
      @pending_power_pellet = false
    end

    def set_music_bpm(bpm)
      @music_bpm = bpm.to_f
      @sfx_bpm = @music_bpm / 2.0
    end

    def queue_dot_tick
      @pending_dot_tick = true
    end

    def queue_power_pellet
      @pending_power_pellet = true
    end

    def tick(args)
      return unless BeatClock.step_changed?(args.tick_count, bpm: @sfx_bpm)

      if @pending_power_pellet
        SFXPlayer.play(args, :power_pellet)
        @pending_power_pellet = false
        @pending_dot_tick = false
      elsif @pending_dot_tick
        SFXPlayer.play(args, :dot_tick)
        @pending_dot_tick = false
      end
    end
  end
end
