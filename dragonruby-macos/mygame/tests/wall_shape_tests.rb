require 'app/wall_shape.rb'

def all_walls
  { t: true, b: true, l: true, r: true, tl: true, tr: true, bl: true, br: true }
end

def no_walls
  { t: false, b: false, l: false, r: false, tl: false, tr: false, bl: false, br: false }
end

def test_classify_inner_corner_br args, assert
  # b && r && !br → inner concave corner facing bottom-right
  mask = all_walls.merge(br: false)
  assert.equal! WallShape.classify(**mask), WallShape::CORNER_BR
end

def test_classify_inner_corner_bl args, assert
  mask = all_walls.merge(bl: false)
  assert.equal! WallShape.classify(**mask), WallShape::CORNER_BL
end

def test_classify_inner_corner_tr args, assert
  mask = all_walls.merge(tr: false)
  assert.equal! WallShape.classify(**mask), WallShape::CORNER_TR
end

def test_classify_inner_corner_tl args, assert
  mask = all_walls.merge(tl: false)
  assert.equal! WallShape.classify(**mask), WallShape::CORNER_TL
end

def test_classify_outer_corner_br args, assert
  # No top, no left; bottom + right neighbors → outer convex corner BR
  mask = no_walls.merge(b: true, r: true)
  assert.equal! WallShape.classify(**mask), WallShape::CORNER_BR
end

def test_classify_horizontal_strip args, assert
  # Walls on left and right only → horizontal strip
  mask = no_walls.merge(l: true, r: true)
  assert.equal! WallShape.classify(**mask), WallShape::WALL_H
end

def test_classify_vertical_strip args, assert
  mask = no_walls.merge(t: true, b: true)
  assert.equal! WallShape.classify(**mask), WallShape::WALL_V
end

def test_classify_interior args, assert
  # All 8 neighbors walls, no missing diagonal → fully interior
  assert.equal! WallShape.classify(**all_walls), WallShape::INTERIOR
end

def test_classify_t_junction_uses_h args, assert
  # Top, left, right walls present (with diagonals), bottom missing.
  # Original 12-branch logic falls through to !t || !b → WALL_H.
  mask = { t: true, b: false, l: true, r: true,
           tl: true, tr: true, bl: false, br: false }
  assert.equal! WallShape.classify(**mask), WallShape::WALL_H
end

def test_from_char_roundtrip args, assert
  WallShape::ALL.each do |shape|
    assert.equal! WallShape.from_char(shape.char), shape
  end
end

def test_from_char_unknown_returns_nil args, assert
  assert.nil! WallShape.from_char(".")
  assert.nil! WallShape.from_char("z")
end

def test_segments_corner_br_in_unit_rect args, assert
  rect = { x: 0, y: 0, w: 20, h: 20 }
  segments = WallShape::CORNER_BR.segments(rect)
  assert.equal! segments.length, 2
  # First segment: bottom-mid → center
  assert.equal! segments[0], { x: 10, y: 0, x2: 10, y2: 10 }
  # Second segment: center → right-mid
  assert.equal! segments[1], { x: 10, y: 10, x2: 20, y2: 10 }
end

def test_segments_interior_is_empty args, assert
  segments = WallShape::INTERIOR.segments(x: 0, y: 0, w: 20, h: 20)
  assert.equal! segments, []
end

def test_segments_horizontal_wall args, assert
  rect = { x: 100, y: 200, w: 20, h: 20 }
  segments = WallShape::WALL_H.segments(rect)
  assert.equal! segments, [{ x: 100, y: 210, x2: 120, y2: 210 }]
end
