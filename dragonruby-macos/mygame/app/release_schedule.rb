require 'app/ghost.rb'

class ReleaseSchedule
  DOT_THRESHOLD = {
    blinky: 0,
    pinky:  0,
    inky:   30,
    clyde:  60
  }.freeze
  STALL_TICKS = 4 * 60

  def initialize
    reset
  end

  def reset
    @released = { blinky: true, pinky: false, inky: false, clyde: false }
    @dot_count = 0
    @ticks_since_release = 0
  end

  def released?(id)
    @released[id]
  end

  def on_dot_eaten
    @dot_count += 1
    @ticks_since_release = 0
  end

  def tick
    @ticks_since_release += 1
    Ghost::IDENTITIES.each do |id|
      next if @released[id]
      threshold = DOT_THRESHOLD[id]
      if @dot_count >= threshold || @ticks_since_release >= STALL_TICKS
        @released[id] = true
        @ticks_since_release = 0
        yield(id) if block_given?
        break
      end
    end
  end
end
