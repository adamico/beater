# app/banner.rb
#
# Transient centre-screen text overlay for play-scene state announcements
# (READY / LEVEL COMPLETE / GAME OVER + the "press any key" subtext).
# Pure-function: Banner.build(state) -> { labels: [...] }. Distinct from
# Hud, which owns the *persistent* play-scene overlay.

module Banner
  TEXT_COLOR    = { r: 255, g: 255, b: 255 }.freeze
  SUBTEXT_COLOR = { r: 200, g: 200, b: 200 }.freeze

  STATE_TEXT = {
    ready:          'READY?',
    level_complete: 'LEVEL COMPLETE',
    game_over:      'GAME OVER'
  }.freeze

  # States that get the "press any key" subtext below the main banner.
  SUBTEXT_STATES = %i[level_complete game_over].freeze

  def self.build(state)
    out = { labels: [] }
    text = STATE_TEXT[state]
    return out unless text

    cx = Camera::SCREEN_W / 2
    cy = Camera::SCREEN_H / 2
    out[:labels] << {
      x: cx, y: cy + 24, text: text, size_enum: 12,
      alignment_enum: 1, vertical_alignment_enum: 1, **TEXT_COLOR
    }
    return out unless SUBTEXT_STATES.include?(state)

    out[:labels] << {
      x: cx, y: cy - 28, text: 'press any key', size_enum: 2,
      alignment_enum: 1, vertical_alignment_enum: 1, **SUBTEXT_COLOR
    }
    out
  end
end
