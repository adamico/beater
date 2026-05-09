# app/world.rb
#
# Per-tick bag passed to Controllers. Built fresh by Game each tick.
class World
  attr_reader :inputs, :maze, :projection, :player, :pellets

  def initialize(inputs:, maze:, projection:, player:, pellets:)
    @inputs = inputs
    @maze = maze
    @projection = projection
    @player = player
    @pellets = pellets
  end
end
