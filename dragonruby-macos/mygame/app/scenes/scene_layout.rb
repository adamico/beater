require 'app/scenes/scene_director'

# Default screen regions for menu-style scenes. Eliminates per-scene y tweaks
# by giving every scene the same vertical zones:
#
#   +----------------+ SCREEN_H
#   | HEADER region  |  HEADER_H px from top, centred heading
#   +----------------+
#   |                |
#   | CONTENT region | grows to fill, scroll-clipped via ScrollableList
#   |                |
#   +----------------+
#   | CONTROLS pad   | (optional, scenes can opt out)
#   +----------------+
#   | FOOTER region  |  FOOTER_H px from bottom, hints / version etc.
#   +----------------+ 0
#
# All scenes ask for `regions(controls: true|false)` and render into the
# returned rects. The content region's height drives scroll thresholds.
module Scenes
  module SceneLayout
    SCREEN_W = SceneDirector::SCREEN_W
    SCREEN_H = SceneDirector::SCREEN_H

    HEADER_H = 90
    FOOTER_H = 60
    CONTROLS_H = 170 # height reserved for a help/instructions block
    CONTENT_PAD_TOP = 20 # breathing room between header and first content row

    def self.header
      { x: 0, y: SCREEN_H - HEADER_H, w: SCREEN_W, h: HEADER_H }
    end

    def self.footer
      { x: 0, y: 0, w: SCREEN_W, h: FOOTER_H }
    end

    def self.controls
      { x: 0, y: FOOTER_H, w: SCREEN_W, h: CONTROLS_H }
    end

    # Content region — fills the middle. Pass controls: true to reserve space
    # for the controls block above the footer.
    def self.content(controls: false)
      bottom = FOOTER_H + (controls ? CONTROLS_H : 0)
      top    = SCREEN_H - HEADER_H
      { x: 0, y: bottom, w: SCREEN_W, h: top - bottom }
    end

    def self.header_center_y
      r = header
      r[:y] + r[:h] / 2
    end

    def self.footer_center_y
      r = footer
      r[:y] + r[:h] / 2
    end

    DEBUG_COLORS = {
      'HEADER'   => { r: 255, g: 100, b: 100 },
      'CONTENT'  => { r: 100, g: 255, b: 100 },
      'CONTROLS' => { r: 100, g: 180, b: 255 },
      'FOOTER'   => { r: 255, g: 220, b: 80 }
    }.freeze

    # F2 toggles, called from main.rb once per tick after scene render.
    def self.tick_debug(args)
      if args.inputs.keyboard.key_down.f2
        args.state.debug_layout = !args.state.debug_layout
      end
      draw_debug(args.outputs) if args.state.debug_layout
    end

    # Borders + region name + dimensions for every named region. Always
    # includes content with controls reserved so the controls rect is
    # visible regardless of which scene opted in.
    def self.draw_debug(outputs)
      rects = {
        'HEADER'   => header,
        'CONTROLS' => controls,
        'CONTENT'  => content(controls: true),
        'FOOTER'   => footer
      }
      rects.each { |name, rect| draw_debug_rect(outputs, name, rect) }
    end

    def self.draw_debug_rect(outputs, name, rect)
      color = DEBUG_COLORS[name] || { r: 255, g: 255, b: 255 }
      outputs.primitives << rect.merge(color).border!
      outputs.primitives << {
        x: rect[:x] + 6, y: rect[:y] + rect[:h] - 6,
        text: "#{name} #{rect[:w]}x#{rect[:h]} @ (#{rect[:x]},#{rect[:y]})",
        size_enum: 0, alignment_enum: 0, vertical_alignment_enum: 2,
        **color
      }.label!
    end
  end
end
