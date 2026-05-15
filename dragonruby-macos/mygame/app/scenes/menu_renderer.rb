# Shared rendering helpers for menu screens (title, pause, settings, etc.).
# Keeps the look-and-feel of selectable button stacks in one place.
module Scenes
  module MenuRenderer
    SELECTED_FILL    = { r: 80,  g: 40,  b: 0   }.freeze
    UNSELECTED_FILL  = { r: 20,  g: 20,  b: 30  }.freeze
    SELECTED_BORDER  = { r: 255, g: 230, b: 100 }.freeze
    UNSELECTED_BORDER = { r: 90, g: 90, b: 110 }.freeze
    LABEL_COLOR      = { r: 255, g: 255, b: 255 }.freeze
    HEADING_COLOR    = { r: 255, g: 230, b: 100 }.freeze

    # Build a vertical stack of equally-sized item rects centred horizontally.
    def self.item_rects(count, screen_w:, top_y:, item_w:, item_h:, gap:)
      count.times.map do |i|
        {
          x: (screen_w - item_w) / 2,
          y: top_y - i * (item_h + gap),
          w: item_w,
          h: item_h
        }
      end
    end

    # Draws boxed selectable buttons with the shared selected/unselected style.
    # `labels` is parallel to `rects`; `selected` is the index to highlight.
    def self.draw_items(outputs, rects, labels, selected, label_size: 4)
      rects.each_with_index do |rect, i|
        is_sel = (i == selected)
        fill = is_sel ? SELECTED_FILL : UNSELECTED_FILL
        border = is_sel ? SELECTED_BORDER : UNSELECTED_BORDER

        outputs.primitives << rect.merge(fill).solid!
        outputs.primitives << rect.merge(border).border!
        outputs.primitives << {
          x: rect[:x] + rect[:w] / 2,
          y: rect[:y] + rect[:h] / 2,
          text: labels[i],
          size_enum: label_size,
          alignment_enum: 1,
          vertical_alignment_enum: 1,
          **LABEL_COLOR
        }.label!
      end
    end

    # Centred heading label (the big yellow "BEAT2R" / "PAUSED" type).
    def self.draw_heading(outputs, text, x:, y:, size: 14)
      outputs.primitives << {
        x: x, y: y, text: text,
        size_enum: size, alignment_enum: 1, vertical_alignment_enum: 1,
        **HEADING_COLOR
      }.label!
    end

    # Full-screen dimming overlay (used by pause).
    def self.draw_dim(outputs, w:, h:, alpha: 160)
      outputs.primitives << {
        x: 0, y: 0, w: w, h: h,
        r: 0, g: 0, b: 0, a: alpha
      }.solid!
    end

    # Settings row: left-aligned label, right-aligned value, optional fill
    # bar for sliders. `value_ratio` (0..1) draws the slider track + thumb;
    # pass nil for non-slider rows (toggles, static).
    def self.draw_setting_row(outputs, rect, label:, value_text:, selected:, value_ratio: nil)
      fill = selected ? SELECTED_FILL : UNSELECTED_FILL
      border = selected ? SELECTED_BORDER : UNSELECTED_BORDER

      outputs.primitives << rect.merge(fill).solid!
      outputs.primitives << rect.merge(border).border!

      outputs.primitives << {
        x: rect[:x] + 18, y: rect[:y] + rect[:h] / 2,
        text: label, size_enum: 3, alignment_enum: 0, vertical_alignment_enum: 1,
        **LABEL_COLOR
      }.label!

      if value_ratio
        track_x = rect[:x] + rect[:w] - 260
        track_y = rect[:y] + rect[:h] / 2 - 4
        track_w = 180
        outputs.primitives << {
          x: track_x, y: track_y, w: track_w, h: 8, r: 60, g: 60, b: 70
        }.solid!
        outputs.primitives << {
          x: track_x, y: track_y, w: (track_w * value_ratio).to_i, h: 8,
          r: 255, g: 200, b: 80
        }.solid!
      end

      outputs.primitives << {
        x: rect[:x] + rect[:w] - 18, y: rect[:y] + rect[:h] / 2,
        text: value_text, size_enum: 3, alignment_enum: 2, vertical_alignment_enum: 1,
        **LABEL_COLOR
      }.label!
    end
  end
end
