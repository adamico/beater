require 'app/scenes/menu_input'

# Stateless menu-input reducer: takes the caller's current selection and the
# item rects, returns the updated selection and an action symbol. Centralises
# the kb-overrides-hover precedence and click/confirm/cancel resolution that
# title, pause, settings, etc. all share.
module Scenes
  module MenuController
    # @return [Hash] { selected:, action: :activate | :cancel | :none }
    def self.update(args, selected:, count:, item_rects:)
      delta = MenuInput.navigate_delta(args)
      kb_used = delta != 0
      selected = (selected + delta) % count if kb_used

      hover = MenuInput.hover_index(args, item_rects)
      # Hover only steers when keyboard didn't fire and the pointer moved —
      # prevents a stale cursor from yanking selection after a key press.
      selected = hover if hover && !kb_used && args.inputs.mouse.moved

      if MenuInput.mouse_click?(args) && hover
        return { selected: hover, action: :activate }
      end

      return { selected: selected, action: :activate } if MenuInput.confirm?(args)
      return { selected: selected, action: :cancel } if MenuInput.cancel?(args)

      { selected: selected, action: :none }
    end
  end
end
