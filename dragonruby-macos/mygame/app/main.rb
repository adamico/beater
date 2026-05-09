require 'data/maps/pacman_layout.rb'
require 'app/game.rb'

module Main
  def tick args
    @game ||= Game.new
    @game.args = args
    @game.tick
  end

  def reset args
    @game = nil
  end
end

GTK.reset
