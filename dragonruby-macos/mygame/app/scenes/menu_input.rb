# Direct keyboard / gamepad / mouse polling for menu scenes (see Q6).
# Stateless: each call inspects args and returns a high-level action.
module Scenes
  module MenuInput
    # Edge-triggered vertical axis: mirrors the up/down vocabulary of
    # KeyboardController (which uses args.inputs.up_down for held state),
    # but reads key_down so menus advance once per press, not per frame.
    # Returns -1 = up, +1 = down, 0 = no input.
    def self.navigate_delta(args)
      kb = args.inputs.keyboard.key_down
      pad = args.inputs.controller_one.key_down
      return -1 if kb.up || kb.w_scancode || pad.up
      return 1 if kb.down || kb.s_scancode || pad.down

      0
    end

    # Edge-triggered horizontal axis for menus that need it (e.g. initials rotor).
    def self.horizontal_delta(args)
      kb = args.inputs.keyboard.key_down
      pad = args.inputs.controller_one.key_down
      return -1 if kb.left || kb.a_scancode || pad.left
      return 1 if kb.right || kb.d_scancode || pad.right

      0
    end

    def self.confirm?(args)
      kb = args.inputs.keyboard.key_down
      pad = args.inputs.controller_one.key_down
      kb.enter || kb.space || pad.a || pad.start
    end

    def self.cancel?(args)
      kb = args.inputs.keyboard.key_down
      pad = args.inputs.controller_one.key_down
      kb.escape || pad.b
    end

    # Pause toggle: P / Start / Escape / B. Same set whether entering or
    # leaving pause — callers decide the direction by current Game state.
    def self.pause?(args)
      kb = args.inputs.keyboard.key_down
      pad = args.inputs.controller_one.key_down
      kb.escape || kb.p || pad.start || pad.b
    end

    def self.mouse_click?(args)
      args.inputs.mouse.click
    end

    def self.mouse_pos(args)
      [args.inputs.mouse.x, args.inputs.mouse.y]
    end

    def self.hover_index(args, item_rects)
      mx, my = mouse_pos(args)
      item_rects.each_with_index do |r, i|
        return i if mx >= r[:x] && mx <= r[:x] + r[:w] &&
                    my >= r[:y] && my <= r[:y] + r[:h]
      end
      nil
    end
  end
end
