require 'app/scenes/scene_director'
require 'app/scenes/menu_input'
require 'app/scenes/menu_renderer'
require 'app/direction'
require 'app/player'
require 'app/ghost'

module Scenes
  # Dev-only sprite previewer. Selector + stage layout: pick an entity on the
  # left, a state in the middle, see the live `to_sprite` result on the right.
  # Modifier toggles cycle render-affecting state (enrage step, armor flash,
  # eaten flash) that isn't part of the FSM. See ADR-0016.
  class SpriteLab
    SCREEN_W = SceneDirector::SCREEN_W
    SCREEN_H = SceneDirector::SCREEN_H

    ENTITY_KEYS = %i[player blinky pinky inky clyde].freeze
    ENTITY_LABELS = {
      player: 'PLAYER',
      blinky: 'BLINKY',
      pinky: 'PINKY',
      inky: 'INKY',
      clyde: 'CLYDE'
    }.freeze

    PLAYER_STATES = %i[walk dying fire].freeze
    GHOST_STATES  = %i[scatter chase eaten imprisoning imprisoned].freeze
    ENRAGE_STEPS  = %i[off enrage1 enrage2].freeze

    CELL = 48
    STAGE_CX = 940
    STAGE_CY = 380

    def initialize
      @entity_idx = 0
      @state_idx = 0
      @paused = false
      @enrage_step = :off
      @instances = {}
      @cached_sprite = nil
      @step_once = false
      sync_instance!
    end

    def tick(args)
      handle_input(args)
      advance_anim unless @paused
      render(args)
    end

    private

    def current_entity = ENTITY_KEYS[@entity_idx]
    def states_for(entity) = entity == :player ? PLAYER_STATES : GHOST_STATES
    def current_state = states_for(current_entity)[@state_idx]

    def handle_input(args)
      return if SceneDirector.transitioning?

      if MenuInput.cancel?(args)
        SceneDirector.request(:title)
        return
      end

      kb = args.inputs.keyboard.key_down

      if kb.left || kb.a_scancode
        cycle_entity(-1)
      elsif kb.right || kb.d_scancode
        cycle_entity(+1)
      end

      if kb.up || kb.w_scancode
        cycle_state(-1)
      elsif kb.down || kb.s_scancode
        cycle_state(+1)
      end

      handle_entity_clicks(args)
      handle_state_clicks(args)
      handle_stage_click(args)

      @paused = !@paused if kb.space
      @step_once = true if @paused && kb.period
      trigger_armor_flash if kb.one
      trigger_eaten_flash if kb.two
      cycle_enrage(-1) if kb.open_square_brace
      cycle_enrage(+1) if kb.close_square_brace
      reset_anim! if kb.r
    end

    def handle_entity_clicks(args)
      return unless MenuInput.mouse_click?(args)

      idx = MenuInput.hover_index(args, entity_rects)
      return unless idx

      @entity_idx = idx
      @state_idx = 0
      sync_instance!
    end

    def handle_state_clicks(args)
      return unless MenuInput.mouse_click?(args)

      idx = MenuInput.hover_index(args, state_rects)
      return unless idx

      @state_idx = idx
      sync_instance!
    end

    def handle_stage_click(args)
      return unless MenuInput.mouse_click?(args)

      mx, my = MenuInput.mouse_pos(args)
      r = stage_rect
      return unless mx >= r[:x] && mx <= r[:x] + r[:w] &&
                    my >= r[:y] && my <= r[:y] + r[:h]

      @paused = !@paused
    end

    def cycle_entity(dir)
      @entity_idx = (@entity_idx + dir) % ENTITY_KEYS.length
      @state_idx = 0
      sync_instance!
    end

    def cycle_state(dir)
      @state_idx = (@state_idx + dir) % states_for(current_entity).length
      sync_instance!
    end

    def cycle_enrage(dir)
      i = ENRAGE_STEPS.index(@enrage_step) || 0
      @enrage_step = ENRAGE_STEPS[(i + dir) % ENRAGE_STEPS.length]
      inst = instance_for(current_entity)
      inst.enrage_step = @enrage_step if inst.respond_to?(:enrage_step=)
    end

    def trigger_armor_flash
      inst = instance_for(current_entity)
      inst.armor_flash! if inst.respond_to?(:armor_flash!)
    end

    def trigger_eaten_flash
      inst = instance_for(current_entity)
      return unless inst.is_a?(Ghost)

      inst.instance_variable_set(:@eaten_flash_ticks, Ghost::EATEN_FLASH_TICKS)
    end

    # Bring the current instance to a clean baseline for the selected state.
    # Called on every entity/state change.
    def sync_instance!
      inst = instance_for(current_entity)
      if inst.is_a?(Player)
        inst.clear_death
        inst.instance_variable_set(:@walk_ticks, 0)
        inst.instance_variable_set(:@fire_ticks, 0)
        case current_state
        when :dying then inst.begin_death
        when :fire  then inst.begin_fire_anim
        end
      elsif inst.is_a?(Ghost)
        inst.instance_variable_set(:@armor_flash_ticks, 0)
        inst.instance_variable_set(:@eaten_flash_ticks, 0)
        inst.state = current_state
        inst.enrage_step = @enrage_step
      end
      @cached_sprite = nil
    end

    def reset_anim!
      sync_instance!
    end

    # Entity owns its own frame cadence (Player::TICKS_PER_WALK_FRAME,
    # Player::DEATH_ANIM_TICKS, Ghost flash counters). The lab just ticks
    # once per frame and lets the entity decide what to render.
    def advance_anim
      advance_instance!
    end

    def advance_instance!
      inst = instance_for(current_entity)
      return unless inst.is_a?(Player)

      case current_state
      when :dying
        inst.tick_death
        if inst.death_anim_done?
          inst.clear_death
          inst.begin_death
        end
      when :fire
        inst.tick_fire_anim
        inst.begin_fire_anim unless inst.firing?
      else
        inst.instance_variable_set(:@walk_ticks,
                                   inst.instance_variable_get(:@walk_ticks).to_i + 1)
      end

      # Ghosts: armor / eaten flash counters self-decrement inside to_sprite.
    end

    def instance_for(entity)
      @instances[entity] ||= build_instance(entity)
    end

    def build_instance(entity)
      if entity == :player
        Player.new(x: 0, y: 0, w: CELL, h: CELL,
                   speed: 1.0, controller: nil, direction: Direction::LEFT)
      else
        Ghost.new(identity: entity, x: 0, y: 0, w: CELL, h: CELL,
                  speed: 1.0, scatter_target: [0, 0], spawn_cell: [0, 0],
                  controller: nil, direction: Direction::LEFT)
      end
    end

    # ---------- layout ----------

    ENTITY_LIST_X = 40
    STATE_LIST_X  = 270
    LIST_W        = 200
    LIST_H        = 36
    LIST_GAP      = 8
    LIST_TOP_Y    = SCREEN_H - 130

    def entity_rects
      ENTITY_KEYS.each_with_index.map do |_, i|
        { x: ENTITY_LIST_X, y: LIST_TOP_Y - i * (LIST_H + LIST_GAP),
          w: LIST_W, h: LIST_H }
      end
    end

    def state_rects
      states_for(current_entity).each_with_index.map do |_, i|
        { x: STATE_LIST_X, y: LIST_TOP_Y - i * (LIST_H + LIST_GAP),
          w: LIST_W, h: LIST_H }
      end
    end

    def stage_rect
      { x: 530, y: 130, w: 720, h: 500 }
    end

    # ---------- render ----------

    def render(args)
      out = args.outputs
      out.background_color = [12, 8, 24]

      render_heading(out)
      render_entity_list(out)
      render_state_list(out)
      render_stage(out)
      render_status(out)
      SceneDirector.draw_fade(out)
    end

    def render_heading(out)
      MenuRenderer.draw_heading(out, 'SPRITE LAB',
                                x: SCREEN_W / 2, y: SCREEN_H - 50, size: 8)
    end

    def render_entity_list(out)
      draw_section_label(out, 'ENTITY', ENTITY_LIST_X + LIST_W / 2)
      draw_list(out, entity_rects, ENTITY_KEYS.map { |k| ENTITY_LABELS[k] }, @entity_idx)
    end

    def render_state_list(out)
      draw_section_label(out, 'STATE', STATE_LIST_X + LIST_W / 2)
      labels = states_for(current_entity).map { |s| s.to_s.upcase }
      draw_list(out, state_rects, labels, @state_idx)
    end

    def draw_section_label(out, text, cx)
      out.primitives << {
        x: cx, y: SCREEN_H - 100,
        text: text, size_enum: 2, alignment_enum: 1,
        r: 200, g: 200, b: 220
      }.label!
    end

    def draw_list(out, rects, labels, selected)
      rects.each_with_index do |rect, i|
        sel = i == selected
        fill = sel ? MenuRenderer::SELECTED_FILL : MenuRenderer::UNSELECTED_FILL
        border = sel ? MenuRenderer::SELECTED_BORDER : MenuRenderer::UNSELECTED_BORDER
        out.primitives << rect.merge(fill).solid!
        out.primitives << rect.merge(border).border!
        out.primitives << {
          x: rect[:x] + 14, y: rect[:y] + rect[:h] / 2,
          text: labels[i], size_enum: 2,
          alignment_enum: 0, vertical_alignment_enum: 1,
          **MenuRenderer::LABEL_COLOR
        }.label!
      end
    end

    def render_stage(out)
      r = stage_rect
      out.primitives << r.merge(r: 22, g: 18, b: 36).solid!
      out.primitives << r.merge(MenuRenderer::UNSELECTED_BORDER).border!

      sprite = current_sprite
      return unless sprite

      out.primitives << sprite

      out.primitives << {
        x: STAGE_CX, y: r[:y] + 30,
        text: "#{ENTITY_LABELS[current_entity]}  ·  #{current_state.to_s.upcase}",
        size_enum: 4, alignment_enum: 1,
        r: 240, g: 230, b: 200
      }.label!
    end

    # Compute the sprite hash and recentre on the stage. Cached while paused
    # so the auto-decrementing flash counters in to_sprite don't keep ticking.
    def current_sprite
      if !@paused || @step_once || @cached_sprite.nil?
        @step_once = false
        inst = instance_for(current_entity)
        sprite = inst.to_sprite.dup
        sprite[:x] = STAGE_CX - sprite[:w] / 2.0
        sprite[:y] = STAGE_CY - sprite[:h] / 2.0
        @cached_sprite = sprite
      end
      @cached_sprite
    end

    def render_status(out)
      parts = [
        "enrage=#{@enrage_step}",
        @paused ? 'PAUSED' : 'PLAYING'
      ]
      out.primitives << {
        x: SCREEN_W / 2, y: 90,
        text: parts.join('   |   '),
        size_enum: 2, alignment_enum: 1,
        r: 200, g: 200, b: 220
      }.label!
      out.primitives << {
        x: SCREEN_W / 2, y: 55,
        text: '←/→ entity   ↑/↓ state   SPACE pause   . step   1 armor   2 eaten   [/] enrage   R restart   ESC back',
        size_enum: 0, alignment_enum: 1,
        r: 140, g: 140, b: 160
      }.label!
    end
  end
end
