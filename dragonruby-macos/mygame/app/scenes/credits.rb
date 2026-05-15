require 'app/scenes/scene_director'
require 'app/scenes/scene_layout'
require 'app/scenes/menu_input'
require 'app/scenes/menu_controller'
require 'app/scenes/menu_renderer'
require 'app/scenes/menu_scene'

module Scenes
  class Credits
    include MenuScene

    ITEMS = %i[back].freeze
    LABELS = { back: 'BACK' }.freeze
    ITEM_W = 240
    ITEM_H = 52
    ITEM_GAP = 14
    ITEMS_TOP_Y = 130

    # Content sourced from CONTEXT.md "Credits".
    LINES = [
      'Design, code, music — Andrea D\'Amico',
      'kc00l @ Fifth Layer Studio',
      '',
      'Engine — DragonRuby GTK',
      'Reference — The Pac-Man Dossier by Jamey Pittman',
      'Inspired by Pac-Man (Namco, 1980)',
      'and Wizard of Wor (Midway, 1980)'
    ].freeze
    LINE_H = 36

    def initialize
      @selected = 0
    end

    def tick(args)
      handle_menu_input(args)
      render(args)
    end

    private

    def item_count = ITEMS.length

    def item_rects
      MenuRenderer.item_rects(
        ITEMS.length,
        screen_w: SceneLayout::SCREEN_W,
        top_y: ITEMS_TOP_Y,
        item_w: ITEM_W,
        item_h: ITEM_H,
        gap: ITEM_GAP
      )
    end

    def on_activate(_args)
      SceneDirector.request(:title)
    end

    def on_cancel(_args)
      SceneDirector.request(:title)
    end

    def render(args)
      outputs = args.outputs
      outputs.background_color = [12, 8, 24]

      MenuRenderer.draw_heading(
        outputs, 'CREDITS',
        x: SceneLayout::SCREEN_W / 2,
        y: SceneLayout.header_center_y,
        size: 12
      )

      cx = SceneLayout::SCREEN_W / 2
      top_y = SceneLayout::SCREEN_H - SceneLayout::HEADER_H - 60
      LINES.each_with_index do |line, i|
        outputs.primitives << {
          x: cx, y: top_y - i * LINE_H,
          text: line, size_enum: 3,
          alignment_enum: 1, vertical_alignment_enum: 1,
          r: 220, g: 220, b: 220
        }.label!
      end

      MenuRenderer.draw_items(
        outputs, item_rects,
        ITEMS.map { |k| LABELS[k] },
        @selected
      )
      SceneDirector.draw_fade(outputs)
    end
  end
end
