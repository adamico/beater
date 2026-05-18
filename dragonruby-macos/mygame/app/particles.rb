# app/particles.rb
#
# Render-only juice. World-space short-lived sprite confetti (ADR-0018).
# Game-owned, lives only in scene :playing. Tick frozen with the world
# (paused / dying / eat_freeze) so a paused burst resumes mid-flight.

class Particles
  MAX_PARTICLES   = 256
  DOT_BURST_COUNT = 6
  DOT_BURST_POWER = 12
  DOT_LIFETIME    = 18
  DOT_SIZE_PX     = 4
  DOT_SPEED_MIN   = 1.5
  DOT_SPEED_MAX   = 3.0

  attr_reader :list

  def initialize
    @list = []
  end

  # Spawn a colour burst centred on (world_x, world_y). `color_rgb` is a
  # `{ r:, g:, b: }` hash — Renderer reads it straight as a solid.
  def burst(world_x:, world_y:, color_rgb:, count: DOT_BURST_COUNT, lifetime: DOT_LIFETIME)
    count.times do
      angle = rand * Math::PI * 2.0
      speed = DOT_SPEED_MIN + rand * (DOT_SPEED_MAX - DOT_SPEED_MIN)
      @list << {
        x: world_x, y: world_y,
        vx: Math.cos(angle) * speed,
        vy: Math.sin(angle) * speed,
        life: lifetime,
        life_total: lifetime,
        size: DOT_SIZE_PX,
        r: color_rgb[:r], g: color_rgb[:g], b: color_rgb[:b]
      }
    end
    drop_overflow
  end

  # Power-pellet variant: bigger white burst.
  def power_burst(world_x:, world_y:)
    burst(world_x: world_x, world_y: world_y,
          color_rgb: { r: 255, g: 255, b: 255 },
          count: DOT_BURST_POWER, lifetime: DOT_LIFETIME)
  end

  # Advance one frame. Called only from tick_playing — frozen in
  # paused/dying/eat_freeze, matching Play clock (ADR-0013).
  def tick
    @list.each do |p|
      p[:x] += p[:vx]
      p[:y] += p[:vy]
      p[:life] -= 1
    end
    @list.reject! { |p| p[:life] <= 0 }
  end

  def clear!
    @list.clear
  end

  private

  def drop_overflow
    return if @list.size <= MAX_PARTICLES

    @list.shift(@list.size - MAX_PARTICLES)
  end
end
