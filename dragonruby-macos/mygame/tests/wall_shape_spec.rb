require 'app/wall_shape.rb'

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
