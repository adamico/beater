require 'app/scenes/scene_director'
require 'app/scenes/menu_input'
require 'app/scenes/menu_controller'
require 'app/scenes/menu_renderer'
require 'app/scenes/menu_scene'

module Scenes
  class Title
    include MenuScene
    TITLE = 'BEAT2R'
    TAGLINE = 'Maze. Beat. Repeat.'
    CREDITS = 'kc00l @ Fifth Layer Studio 2026'
    ITEMS = %i[play settings instructions quit].freeze
    LABELS = {
      play: 'PLAY',
      settings: 'SETTINGS',
      instructions: 'INSTRUCTIONS',
      quit: 'QUIT'
    }.freeze

    ITEM_W = 280
    ITEM_H = 56
    ITEM_GAP = 18
    ITEMS_TOP_Y = 280
    SCREEN_W = SceneDirector::SCREEN_W
    SCREEN_H = SceneDirector::SCREEN_H

    def initialize
      @selected = 0
    end

    def tick(args)
      handle_menu_input(args)
      render(args)
    end

    private

    def item_count = ITEMS.length

    def on_activate(_args)
      case ITEMS[@selected]
      when :play then SceneDirector.request(:playing)
      when :settings then SceneDirector.request(:settings, return_to: :title)
      when :instructions then SceneDirector.request(:instructions)
      when :quit then $gtk.request_quit
      end
    end

    def on_cancel(_args)
      # Title has nowhere to go back to — Quit is an explicit menu item.
    end

    def item_rects
      MenuRenderer.item_rects(
        ITEMS.length,
        screen_w: SCREEN_W,
        top_y: SCREEN_H - ITEMS_TOP_Y,
        item_w: ITEM_W,
        item_h: ITEM_H,
        gap: ITEM_GAP
      )
    end

    def render(args)
      outputs = args.outputs
      outputs.background_color = [12, 8, 24]

      render_title_and_tagline(outputs)
      render_menu_items(outputs)
      render_instructions(outputs)
      render_credits(outputs)
      SceneDirector.draw_fade(outputs)
    end

    def render_title_and_tagline(outputs)
      MenuRenderer.draw_heading(outputs, TITLE, x: SCREEN_W / 2, y: SCREEN_H - 120, size: 20)
      outputs.primitives << {
        x: SCREEN_W / 2, y: SCREEN_H - 180,
        text: TAGLINE,
        size_enum: 4,
        alignment_enum: 1,
        r: 220, g: 220, b: 220
      }.label!
    end

    def render_menu_items(outputs)
      MenuRenderer.draw_items(
        outputs, item_rects, ITEMS.map { |k| LABELS[k] }, @selected
      )
    end

    def render_instructions(outputs)
      outputs.primitives << {
        x: SCREEN_W / 2, y: 120,
        text: 'Use arrow keys/WASD or mouse to navigate, Space/Enter or click to select',
        size_enum: -2,
        alignment_enum: 1,
        r: 140, g: 140, b: 160
      }.label!
    end

    def render_credits(outputs)
      outputs.primitives << {
        x: SCREEN_W / 2, y: 40,
        text: CREDITS,
        size_enum: -2,
        alignment_enum: 1,
        r: 140, g: 140, b: 160
      }.label!
    end
  end
end
