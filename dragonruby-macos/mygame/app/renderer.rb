# app/renderer.rb
#
# Owns all drawing concerns. Game hands it the world objects each tick;
# Renderer pushes primitives into DR's outputs. Stateless w.r.t. outputs
# (no held reference); state is just the projection used to map grid
# ordinals to pixel rects.

class Renderer
  BACKGROUND      = [30, 30, 30].freeze
  WALL_COLOR      = { r: 255, g: 255, b: 255 }.freeze
  PELLET_COLOR    = { r: 255, g: 200, b: 150 }.freeze
  CLIP_BACKGROUND = [0, 0, 0, 0].freeze

  PELLET_SIZE       = 4
  POWER_PELLET_SIZE = 8

  def initialize(projection)
    @projection = projection
  end

  def draw(outputs, maze, pellets, player)
    outputs.background_color = BACKGROUND
    draw_walls(outputs, maze)
    draw_pellets(outputs, pellets)
    draw_player(outputs, maze, player)
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
      solids << {
        x: rect[:x] + pad, y: rect[:y] + pad,
        w: size, h: size, **PELLET_COLOR
      }
    end
    outputs.solids << solids
  end

  # Render the player into an off-screen target sized to the visible play
  # area, then blit. The clip hides the sprite as it crosses the wrap seam
  # so it doesn't peek out of the wrap-edge columns.
  def draw_player(outputs, maze, player)
    visible = @projection.rect_for_cell_bounds(maze.visible_cell_bounds)
    sprite = player.to_sprite

    outputs[:clipped_area].background_color = CLIP_BACKGROUND
    outputs[:clipped_area].w = visible[:w]
    outputs[:clipped_area].h = visible[:h]
    outputs[:clipped_area].sprites << sprite.merge(
      x: sprite[:x] - visible[:x],
      y: sprite[:y] - visible[:y]
    )

    outputs.sprites << {
      x: visible[:x], y: visible[:y],
      w: visible[:w], h: visible[:h],
      path: :clipped_area
    }
  end
end
