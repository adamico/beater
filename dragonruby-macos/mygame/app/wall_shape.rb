require 'app/tiles.rb'

class WallShape
  attr_reader :char

  def initialize(char, segment_fn)
    @char = char
    @segment_fn = segment_fn
  end

  def segments(rect)
    @segment_fn.call(rect)
  end

  CORNER_BR = new("1", ->(r) {
    cx = r[:x] + r[:w] / 2
    cy = r[:y] + r[:h] / 2
    [{ x: cx, y: r[:y],         x2: cx,            y2: cy },
     { x: cx, y: cy,            x2: r[:x] + r[:w], y2: cy }]
  })
  CORNER_BL = new("2", ->(r) {
    cx = r[:x] + r[:w] / 2
    cy = r[:y] + r[:h] / 2
    [{ x: cx, y: r[:y],         x2: cx,    y2: cy },
     { x: cx, y: cy,            x2: r[:x], y2: cy }]
  })
  CORNER_TR = new("3", ->(r) {
    cx = r[:x] + r[:w] / 2
    cy = r[:y] + r[:h] / 2
    [{ x: cx, y: r[:y] + r[:h], x2: cx,            y2: cy },
     { x: cx, y: cy,            x2: r[:x] + r[:w], y2: cy }]
  })
  CORNER_TL = new("4", ->(r) {
    cx = r[:x] + r[:w] / 2
    cy = r[:y] + r[:h] / 2
    [{ x: cx, y: r[:y] + r[:h], x2: cx,    y2: cy },
     { x: cx, y: cy,            x2: r[:x], y2: cy }]
  })
  WALL_H = new("h", ->(r) {
    cy = r[:y] + r[:h] / 2
    [{ x: r[:x], y: cy,         x2: r[:x] + r[:w], y2: cy }]
  })
  WALL_V = new("v", ->(r) {
    cx = r[:x] + r[:w] / 2
    [{ x: cx, y: r[:y] + r[:h], x2: cx, y2: r[:y] }]
  })
  INTERIOR = new("w", ->(_r) { [] })
  OUTER_BOTTOM = new("B", ->(r){
    [{ x: r[:x], y: r[:y],         x2: r[:x] + r[:w], y2: r[:y] }]
  })
  OUTER_TOP = new("T", ->(r) {
    [{ x: r[:x], y: r[:y] + r[:h], x2: r[:x] + r[:w], y2: r[:y] + r[:h] }]
  })
  OUTER_LEFT = new("L", ->(r) {
    [{ x: r[:x], y: r[:y],         x2: r[:x], y2: r[:y] + r[:h] }]
  })
  OUTER_RIGHT = new("R", ->(r) {
    [{ x: r[:x] + r[:w], y: r[:y],         x2: r[:x] + r[:w], y2: r[:y] + r[:h] }]
  })
  CORNER_OUTER_TR = new("5", ->(r) {
    cx = r[:x]
    cy = r[:y] + r[:h]
    [{ x: cx, y: r[:y],         x2: cx,            y2: cy },
     { x: cx, y: cy,            x2: r[:x] + r[:w], y2: cy }]
  })
  CORNER_OUTER_TL = new("6", ->(r) {
    cx = r[:x] + r[:w]
    cy = r[:y] + r[:h]
    [{ x: cx, y: r[:y],         x2: cx,    y2: cy },
      { x: cx, y: cy,            x2: r[:x], y2: cy }]
  })
  CORNER_OUTER_BL = new("7", ->(r) {
    cx = r[:x]
    cy = r[:y]
    [{ x: cx, y: r[:y] + r[:h], x2: cx,            y2: cy },
    { x: cx, y: cy,            x2: r[:x] + r[:w], y2: cy }]
  })
  CORNER_OUTER_BR = new("8", ->(r) {
    cx = r[:x] + r[:w]
    cy = r[:y]
    [{ x: cx, y: r[:y] + r[:h], x2: cx,    y2: cy },
    { x: cx, y: cy,            x2: r[:x], y2: cy }]
  })
  ALL = [
    CORNER_BR,
    CORNER_BL,
    CORNER_TR,
    CORNER_TL,
    WALL_H,
    WALL_V,
    INTERIOR,
    OUTER_BOTTOM,
    OUTER_TOP,
    OUTER_LEFT,
    OUTER_RIGHT,
    CORNER_OUTER_BR,
    CORNER_OUTER_BL,
    CORNER_OUTER_TR,
    CORNER_OUTER_TL,
  ].freeze
  BY_CHAR = ALL.each_with_object({}) { |s, h| h[s.char] = s }.freeze

  def self.from_char(ch)
    BY_CHAR[ch]
  end
end
