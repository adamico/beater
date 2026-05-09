# app/renderer.rb
#
# Owns all drawing concerns. Game hands it the world objects each tick;
# Renderer pushes primitives into DR's outputs. Stateless w.r.t. outputs
# (no held reference); state is just the projection used to map grid
# ordinals to pixel rects.

class Renderer
  BACKGROUND   = [30, 30, 30].freeze
  WALL_COLOR   = { r: 255, g: 255, b: 255 }.freeze
  PELLET_COLOR = { r: 255, g: 200, b: 150 }.freeze

  PELLET_SIZE       = 4
  POWER_PELLET_SIZE = 8

  def initialize(projection)
    @projection = projection
  end

  def draw(outputs, maze, pellets, player)
    outputs.background_color = BACKGROUND
    draw_walls(outputs, maze)
    draw_pellets(outputs, pellets)
    draw_player(outputs, player)
  end

  def draw_walls(outputs, maze)
    outputs.lines << maze.wall_segments(@projection).map { |seg| { **seg, **WALL_COLOR } }
  end

  def draw_pellets(outputs, pellets)
    solids = []
    pellets.each do |(gx, gy), kind|
      rect = @projection.cell_rect(gx, gy)
      size = kind == :power ? POWER_PELLET_SIZE : PELLET_SIZE
      pad = (@projection.cell_size - size) / 2
      solids << { x: rect[:x] + pad, y: rect[:y] + pad, w: size, h: size, **PELLET_COLOR }
    end
    outputs.solids << solids
  end

  def draw_player(outputs, player)
    return if outside_playfield?(player.rect)
    outputs.solids << player.to_solid
  end

  def outside_playfield?(rect)
    pf = @projection.playfield_rect
    rect[:x] + rect[:w] <= pf[:x] ||
      rect[:x] >= pf[:x] + pf[:w] ||
      rect[:y] + rect[:h] <= pf[:y] ||
      rect[:y] >= pf[:y] + pf[:h]
  end
end
