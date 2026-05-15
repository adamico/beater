require 'app/scenes/scene_director'
require 'app/scenes/menu_input'
require 'app/scenes/menu_controller'

# Mixin for scene classes that present a vertical list of selectable items.
# Provides the standard input loop: MenuController for nav/hover/click/confirm/
# cancel, plus optional horizontal-axis adjust for slider-style rows.
#
# Including classes must:
#   - own a `@selected` integer
#   - implement `item_count` and `item_rects`
#   - implement `on_activate(args)` and `on_cancel(args)`
# Including classes may:
#   - implement `on_adjust(direction, args)` to consume the horizontal axis
#     (default: no-op). `direction` is -1 / +1.
module Scenes
  module MenuScene
    def handle_menu_input(args)
      return if SceneDirector.transitioning?

      result = MenuController.update(
        args, selected: @selected, count: item_count, item_rects: item_rects
      )
      @selected = result[:selected]

      delta_h = MenuInput.horizontal_delta(args)
      on_adjust(delta_h, args) if delta_h != 0 && respond_to?(:on_adjust, true)

      case result[:action]
      when :activate then on_activate(args)
      when :cancel   then on_cancel(args)
      end
    end
  end
end
