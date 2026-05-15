# Lays out a fixed-height row list inside a content region, with vertical
# scrolling when total row height exceeds the region. Stateless except for
# the scroll offset, which the caller owns and updates per selection change.
#
# Coordinates: DragonRuby's origin is bottom-left, so "top of region" is the
# highest y. Rows are stacked from the top down in *content space*; the
# scroll offset slides the content up so deeper rows come into view.
#
# Usage:
#   list = ScrollableList.new(region: SceneLayout.content, row_h: 44, gap: 10)
#   list.ensure_visible(@selected)
#   rects = list.row_rects(item_count: ROWS.length)  # nil for off-screen rows
#   list.draw_scrollbar(outputs) if list.scrollable?
module Scenes
  class ScrollableList
    SCROLLBAR_W = 8
    SCROLLBAR_PAD = 4

    attr_accessor :offset

    def initialize(region:, row_h:, gap: 0, max_row_w: nil, pad_top: 0, pad_bottom: 0)
      @region = region
      @row_h = row_h
      @gap = gap
      @max_row_w = max_row_w
      @pad_top = pad_top
      @pad_bottom = pad_bottom
      @offset = 0
    end

    def step
      @row_h + @gap
    end

    def total_content_height(item_count)
      [item_count * step - @gap, 0].max
    end

    def inner_h
      @region[:h] - @pad_top - @pad_bottom
    end

    def visible_rows
      # Floor: the last partly-visible row is rendered but counted as full when
      # deciding whether to scroll.
      ((inner_h + @gap) / step).floor
    end

    def scrollable?(item_count)
      item_count > visible_rows
    end

    def max_offset(item_count)
      [item_count - visible_rows, 0].max
    end

    # Adjust offset so `index` is on screen. Centres on the bounds — moving
    # past the top scrolls up, past the bottom scrolls down.
    def ensure_visible(index, item_count)
      max = max_offset(item_count)
      if index < @offset
        @offset = index
      elsif index >= @offset + visible_rows
        @offset = index - visible_rows + 1
      end
      @offset = @offset.clamp(0, max)
    end

    # Returns an array parallel to item indices. Off-screen rows are nil so
    # callers can skip rendering them.
    def row_rects(item_count:)
      top_y = @region[:y] + @region[:h] - @pad_top
      avail = @region[:w]
      avail -= (SCROLLBAR_W + SCROLLBAR_PAD * 2) if scrollable?(item_count)
      width = @max_row_w ? [@max_row_w, avail].min : avail

      item_count.times.map do |i|
        slot = i - @offset
        next nil if slot < 0 || slot >= visible_rows

        {
          x: @region[:x] + (@region[:w] - width) / 2,
          y: top_y - @row_h - slot * step,
          w: width,
          h: @row_h
        }
      end
    end

    def draw_scrollbar(outputs, item_count)
      return unless scrollable?(item_count)

      rail_x = @region[:x] + @region[:w] - SCROLLBAR_W - SCROLLBAR_PAD
      rail_y = @region[:y]
      rail_h = @region[:h]

      outputs.primitives << {
        x: rail_x, y: rail_y, w: SCROLLBAR_W, h: rail_h,
        r: 40, g: 40, b: 50
      }.solid!

      thumb_h = (rail_h * visible_rows.to_f / item_count).clamp(20, rail_h).to_i
      max = max_offset(item_count)
      thumb_y = max.zero? ? rail_y : (rail_y + rail_h - thumb_h - (rail_h - thumb_h) * @offset / max).to_i

      outputs.primitives << {
        x: rail_x, y: thumb_y, w: SCROLLBAR_W, h: thumb_h,
        r: 180, g: 160, b: 80
      }.solid!
    end
  end
end
