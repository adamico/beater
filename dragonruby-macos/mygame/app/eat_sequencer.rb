class EatSequencer
  EAT_POINTS = [200, 400, 800, 1600].freeze
  EAT_PAUSE_TICKS = 5       # ~80ms sim hitstop (TG2)
  POPUP_TICKS = 50          # ~0.83s float+fade lifetime (TG2)
  POPUP_FLOAT_PER_TICK = 0.6
  CHAIN_TIMEOUT_TICKS = 180 # ~3s stopgap chain reset (TG2/TG1 placeholder)

  attr_accessor :eat_pause_ticks, :audio_envelope_active
  attr_reader :popup

  def initialize(state_machine:)
    @fsm = state_machine
    reset
  end

  def reset
    @eat_chain = 0
    @eat_pause_ticks = 0
    @popup = nil
    @popup_ticks = 0
    @chain_timeout = 0
    @audio_envelope_active = false
  end

  def reset_chain
    @eat_chain = 0
    @chain_timeout = 0
  end

  def frozen?
    @eat_pause_ticks > 0
  end

  def on_ghost_eaten(args, ghost)
    points = EAT_POINTS[[@eat_chain, EAT_POINTS.size - 1].min]
    audio = args.state.audio
    audio.on_ghost_eat_freeze_begin(args)
    audio.tick(args)
    audio.on_enemy_eaten(args, sequence: @eat_chain + 1)
    @eat_chain += 1
    @chain_timeout = CHAIN_TIMEOUT_TICKS
    @fsm.enter_eaten(ghost)
    ghost.eaten_flash_ticks = Ghost::EATEN_FLASH_TICKS if ghost.respond_to?(:eaten_flash_ticks=)
    @eat_pause_ticks = EAT_PAUSE_TICKS
    @popup = { x: ghost.x + ghost.w / 2, y: ghost.y + ghost.h / 2, text: points.to_s, alpha: 255 }
    @popup_ticks = POPUP_TICKS
    @audio_envelope_active = true
    points
  end

  # Called every tick by Game (regardless of frozen?). Advances sim hitstop,
  # popup lifetime, chain timeout, and the (decoupled, longer) audio duck
  # envelope.
  def tick(args)
    tick_sim_freeze
    tick_popup
    tick_chain
    tick_audio_envelope(args)
  end

  # Back-compat: older callers/tests invoke tick_freeze.
  alias_method :tick_freeze, :tick

  private

  def tick_sim_freeze
    @eat_pause_ticks -= 1 if @eat_pause_ticks > 0
  end

  def tick_popup
    return unless @popup
    @popup_ticks -= 1
    if @popup_ticks <= 0
      @popup = nil
      return
    end
    fade = (@popup_ticks.to_f / POPUP_TICKS).clamp(0.0, 1.0)
    @popup = @popup.merge(
      y: @popup[:y] + POPUP_FLOAT_PER_TICK,
      alpha: (fade * 255).to_i
    )
  end

  def tick_chain
    return if @chain_timeout <= 0
    @chain_timeout -= 1
    reset_chain if @chain_timeout <= 0
  end

  def tick_audio_envelope(args)
    return unless @audio_envelope_active || @eat_pause_ticks > 0
    status = args.state.audio.on_ghost_eat_freeze_tick(args)
    @audio_envelope_active = false if status == :done
  end
end
