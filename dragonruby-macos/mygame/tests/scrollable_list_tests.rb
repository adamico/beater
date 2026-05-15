require 'app/scenes/scrollable_list'

def fixture_list(items: 10, region_h: 200, row_h: 40, gap: 10)
  list = Scenes::ScrollableList.new(
    region: { x: 0, y: 0, w: 600, h: region_h },
    row_h: row_h,
    gap: gap
  )
  [list, items]
end

def test_scrollable_list_not_scrollable_when_content_fits(_args, assert)
  list, items = fixture_list(items: 3, region_h: 200, row_h: 40, gap: 10)
  assert.equal! list.scrollable?(items), false
  rects = list.row_rects(item_count: items)
  assert.equal! rects.compact.length, 3
end

def test_scrollable_list_clips_offscreen_rows(_args, assert)
  list, items = fixture_list(items: 10, region_h: 100, row_h: 40, gap: 0)
  # visible_rows ≈ floor((100 + 0) / 40) = 2
  assert.equal! list.visible_rows, 2
  rects = list.row_rects(item_count: items)
  assert.equal! rects.compact.length, 2
  assert.equal! rects[0].nil?, false
  assert.equal! rects[2].nil?, true
end

def test_scrollable_list_ensure_visible_scrolls_down(_args, assert)
  list, items = fixture_list(items: 10, region_h: 100, row_h: 40, gap: 0)
  list.ensure_visible(5, items)
  # Selected index 5 must be in [offset, offset + visible_rows).
  assert.true! (list.offset..list.offset + list.visible_rows - 1).include?(5)
end

def test_scrollable_list_ensure_visible_clamps_to_max(_args, assert)
  list, items = fixture_list(items: 10, region_h: 100, row_h: 40, gap: 0)
  list.ensure_visible(99, items)
  assert.equal! list.offset, list.max_offset(items)
end

def test_scrollable_list_no_clamp_when_fits(_args, assert)
  list, items = fixture_list(items: 2, region_h: 500, row_h: 40, gap: 0)
  list.ensure_visible(0, items)
  assert.equal! list.offset, 0
  assert.equal! list.max_offset(items), 0
end
