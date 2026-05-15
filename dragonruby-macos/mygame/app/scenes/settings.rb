require 'app/scenes/scene_director'
require 'app/scenes/scene_layout'
require 'app/scenes/scrollable_list'
require 'app/scenes/menu_input'
require 'app/scenes/menu_controller'
require 'app/scenes/menu_renderer'
require 'app/scenes/menu_scene'
require 'app/game_settings'

module Scenes
  class Settings
    include MenuScene

    SLIDER_STEP = 0.05
    ROW_W = 700
    ROW_H = 44
    ROW_GAP = 10

    # Each row: kind (:slider | :toggle), settings key, display label.
    ROWS = [
      { kind: :slider, key: :master_volume, label: 'MASTER VOLUME' },
      { kind: :slider, key: :music_volume,  label: 'MUSIC VOLUME' },
      { kind: :slider, key: :sfx_volume,    label: 'SFX VOLUME' },
      { kind: :toggle, key: :fullscreen,    label: 'FULLSCREEN' },
      { kind: :toggle, key: :reduced_flash, label: 'REDUCED FLASH' }
    ].freeze

    CONTROLS_HELP = [
      'Adjust/navigate: Arrow keys / WASD / D-pad / Mouse',
      'Confirm: Enter / Space / A',
      'Cancel: Esc / B'
    ].freeze
    CONTROLS_LINE_H = 22

    def initialize
      @selected = 0
      @list = ScrollableList.new(
        region: SceneLayout.content(controls: true),
        row_h: ROW_H,
        gap: ROW_GAP,
        max_row_w: ROW_W,
        pad_top: SceneLayout::CONTENT_PAD_TOP
      )
    end

    def tick(args)
      handle_menu_input(args)
      @list.ensure_visible(@selected, ROWS.length)
      render(args)
    end

    private

    def item_count = ROWS.length
    def item_rects = @list.row_rects(item_count: ROWS.length).compact

    def on_activate(args)
      on_adjust(1, args)
    end

    def on_cancel(_args)
      GameSettings.save!
      SceneDirector.request(SceneDirector.return_to || :title)
    end

    def on_adjust(direction, args)
      row = ROWS[@selected]
      case row[:kind]
      when :slider
        v = GameSettings.get(row[:key]) + direction * SLIDER_STEP
        v = v.clamp(0.0, 1.0).round(2)
        GameSettings.set(row[:key], v)
        # Live preview (Q7 rich audio): SFX/Master changes audition through
        # the SFX bus; music slider has no SFX preview path.
        args.state.audio&.on_dot_collected(args, :drums) if row[:key] != :music_volume
      when :toggle
        GameSettings.set(row[:key], !GameSettings.get(row[:key]))
        GameSettings.apply_window! if row[:key] == :fullscreen
      end
    end

    def render(args)
      outputs = args.outputs
      outputs.background_color = [12, 8, 24]

      render_header(outputs)
      render_rows(outputs)
      @list.draw_scrollbar(outputs, ROWS.length)
      render_controls_help(outputs)
      SceneDirector.draw_fade(outputs)
    end

    def render_header(outputs)
      MenuRenderer.draw_heading(
        outputs, 'SETTINGS',
        x: SceneLayout::SCREEN_W / 2,
        y: SceneLayout.header_center_y,
        size: 8
      )
    end

    def render_rows(outputs)
      rects = @list.row_rects(item_count: ROWS.length)
      rects.each_with_index do |rect, i|
        next unless rect

        row = ROWS[i]
        value = GameSettings.get(row[:key])
        MenuRenderer.draw_setting_row(
          outputs, rect,
          label: row[:label],
          value_text: value_text_for(row, value),
          selected: (i == @selected),
          value_ratio: row[:kind] == :slider ? value : nil
        )
      end
    end

    def value_text_for(row, value)
      case row[:kind]
      when :slider then "#{(value * 100).round}%"
      when :toggle then value ? 'ON' : 'OFF'
      end
    end

    def render_controls_help(outputs)
      region = SceneLayout.controls
      # Treat the header and each help line as one slot of CONTROLS_LINE_H.
      # Centring the slot stack around the region's y midpoint puts equal
      # space above the header and below the last line.
      slots = CONTROLS_HELP.length + 1
      mid_y = region[:y] + region[:h] / 2
      header_y = mid_y + ((slots - 1) * CONTROLS_LINE_H) / 2
      center_x = region[:x] + region[:w] / 2

      outputs.primitives << {
        x: center_x, y: header_y,
        text: 'CONTROLS', size_enum: 3, alignment_enum: 1, vertical_alignment_enum: 1,
        r: 200, g: 200, b: 220
      }.label!
      CONTROLS_HELP.each_with_index do |line, i|
        outputs.primitives << {
          x: center_x,
          y: header_y - (i + 1) * CONTROLS_LINE_H,
          text: line, size_enum: 1, alignment_enum: 1, vertical_alignment_enum: 1,
          r: 160, g: 160, b: 180
        }.label!
      end
    end
  end
end
