class EatSequencer
  EAT_POINTS = [200, 400, 800, 1600].freeze
  EAT_PAUSE_TICKS = 60 # 1s arcade-style freeze on eat

  attr_accessor :eat_pause_ticks
  attr_reader :popup

  def initialize(state_machine:)
    @fsm = state_machine
    reset
  end

  def reset
    @eat_chain = 0
    @eat_pause_ticks = 0
    @popup = nil
  end

  def reset_chain
    @eat_chain = 0
  end

  def frozen?
    @eat_pause_ticks > 0
  end

  def on_ghost_eaten(args, ghost)
    points = EAT_POINTS[[@eat_chain, EAT_POINTS.size - 1].min]
    audio = args.state.audio
    audio.on_ghost_eat_freeze_begin(args)
    # Audio tick normally runs at frame start; push updated duck now so hit is immediate.
    audio.tick(args)
    audio.on_enemy_eaten(args, sequence: @eat_chain + 1)
    @eat_chain += 1
    @fsm.enter_eaten(ghost)
    @eat_pause_ticks = EAT_PAUSE_TICKS
    @popup = { x: ghost.x + ghost.w / 2, y: ghost.y + ghost.h / 2, text: points.to_s }
    points
  end

  def tick_freeze(args)
    status = args.state.audio.on_ghost_eat_freeze_tick(args)
    @eat_pause_ticks -= 1 if @eat_pause_ticks > 0
    if @eat_pause_ticks <= 0 && status == :done
      @eat_pause_ticks = 0
      @popup = nil
    end
  end
end
