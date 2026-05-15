require 'app/scenes/scene_director'
require 'app/scenes/scene_layout'
require 'app/scenes/menu_input'
require 'app/scenes/menu_controller'
require 'app/scenes/menu_renderer'
require 'app/scenes/menu_scene'

module Scenes
  class Instructions
    include MenuScene

    ITEMS = %i[back].freeze
    LABELS = { back: 'BACK' }.freeze
    ITEM_W = 240
    ITEM_H = 52
    ITEM_GAP = 14
    ITEMS_TOP_Y = 130

    RULES = [
      'Eat dots to clear each colour-coded Territory.',
      'Clearing a Territory pacifies its ghost — permanently.',
      'Power pellets grant 5 bullets each.',
      'Fire to kill ghosts; chain kills escalate the score.',
      'Enraged ghosts move faster and resist bullets.'
    ].freeze
    CONTROLS = [
      'Move — Arrow keys / WASD / D-pad',
      'Fire — Space / A',
      'Pause — Esc / P / Start'
    ].freeze
    LINE_H = 28
    SECTION_GAP = 24

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
        outputs, 'INSTRUCTIONS',
        x: SceneLayout::SCREEN_W / 2,
        y: SceneLayout.header_center_y,
        size: 10
      )

      cx = SceneLayout::SCREEN_W / 2
      y = SceneLayout::SCREEN_H - SceneLayout::HEADER_H - 40

      draw_section_heading(outputs, 'HOW TO PLAY', cx, y)
      y -= LINE_H
      RULES.each do |line|
        draw_line(outputs, line, cx, y, r: 220, g: 220, b: 220)
        y -= LINE_H
      end

      y -= SECTION_GAP
      draw_section_heading(outputs, 'CONTROLS', cx, y)
      y -= LINE_H
      CONTROLS.each do |line|
        draw_line(outputs, line, cx, y, r: 200, g: 200, b: 220)
        y -= LINE_H
      end

      MenuRenderer.draw_items(
        outputs, item_rects,
        ITEMS.map { |k| LABELS[k] },
        @selected
      )
      SceneDirector.draw_fade(outputs)
    end

    def draw_section_heading(outputs, text, cx, y)
      outputs.primitives << {
        x: cx, y: y, text: text, size_enum: 4,
        alignment_enum: 1, vertical_alignment_enum: 1,
        r: 255, g: 230, b: 100
      }.label!
    end

    def draw_line(outputs, text, cx, y, r:, g:, b:)
      outputs.primitives << {
        x: cx, y: y, text: text, size_enum: 2,
        alignment_enum: 1, vertical_alignment_enum: 1,
        r: r, g: g, b: b
      }.label!
    end
  end
end
