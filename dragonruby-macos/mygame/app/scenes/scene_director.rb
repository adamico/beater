# Scene-transition request, the single full-rebuild path (see ADR-0012).
#
# Owns the current scene symbol, the pending request, and the fade transition.
# `request(name)` is the only sanctioned way to swap scenes. Top of `tick`
# applies the request via a ~15-frame fade-out / swap / fade-in.
module SceneDirector
  FADE_FRAMES = 15
  SCREEN_W = 1280
  SCREEN_H = 720

  @current = :title
  @requested = nil
  @phase = :idle # :idle | :fading_out | :fading_in
  @phase_t = 0
  @return_to = nil

  class << self
    attr_reader :current, :phase, :return_to

    def reset!
      @current = :title
      @requested = nil
      @phase = :idle
      @phase_t = 0
      @return_to = nil
    end

    def request(name, return_to: nil)
      return if @requested
      return if @phase != :idle

      @requested = name
      @return_to = return_to if return_to
      @phase = :fading_out
      @phase_t = 0
    end

    # Caller drives the transition each frame. Yields `:swap` exactly once,
    # at the apex of the fade-out → fade-in handoff, so the caller can rebuild
    # state and apply audio fade in lockstep with the visual fade.
    def tick_transition
      case @phase
      when :fading_out
        @phase_t += 1
        if @phase_t >= FADE_FRAMES
          @current = @requested
          @requested = nil
          yield :swap if block_given?
          @phase = :fading_in
          @phase_t = 0
        end
      when :fading_in
        @phase_t += 1
        if @phase_t >= FADE_FRAMES
          @phase = :idle
          @phase_t = 0
        end
      end
    end

    # Black overlay alpha (0..255) for the current fade phase.
    def fade_alpha
      case @phase
      when :fading_out then ((@phase_t.to_f / FADE_FRAMES) * 255).to_i
      when :fading_in  then (255 - (@phase_t.to_f / FADE_FRAMES) * 255).to_i
      else 0
      end
    end

    # Audio duck multiplier matched to fade alpha (1.0 at idle, 0 at apex).
    def audio_gain_multiplier
      1.0 - (fade_alpha / 255.0)
    end

    def draw_fade(outputs)
      a = fade_alpha
      return if a <= 0

      outputs.primitives << {
        x: 0, y: 0, w: SCREEN_W, h: SCREEN_H,
        r: 0, g: 0, b: 0, a: a
      }.solid!
    end

    # True while a scene swap is pending; callers can skip input handling.
    def transitioning?
      @phase != :idle
    end
  end
end
