# Player-tunable settings, persisted to `settings.txt` via $gtk.serialize_state.
# Global, single-instance — Audio::Manager and SFXPlayer read from here every
# frame; Scenes::Settings mutates and persists on exit.
#
# `settings.txt` schema is versioned (see ADR-0013 rationale for save-format
# versioning); load gracefully falls back to defaults on missing/incompatible
# files (first-run behaviour, per Q17 = silent defaults).
module GameSettings
  SAVE_PATH = 'settings.txt'.freeze
  SAVE_VERSION = 1

  DEFAULTS = {
    master_volume: 0.8,
    music_volume: 0.7,
    sfx_volume: 0.9,
    fullscreen: false,
    reduced_flash: false
  }.freeze

  @values = DEFAULTS.dup

  class << self
    def reset!
      @values = DEFAULTS.dup
    end

    def get(key)
      @values.fetch(key, DEFAULTS[key])
    end

    def set(key, value)
      @values[key] = value
    end

    def to_h
      @values.dup
    end

    # Effective gain multipliers — what Audio::Manager / SFXPlayer apply.
    def music_gain
      get(:master_volume) * get(:music_volume)
    end

    def sfx_gain
      get(:master_volume) * get(:sfx_volume)
    end

    def load!
      raw = ($gtk.deserialize_state(SAVE_PATH) rescue nil)
      return reset! unless raw.is_a?(Hash) && raw[:version] == SAVE_VERSION

      DEFAULTS.each_key { |k| @values[k] = raw[k] unless raw[k].nil? }
    end

    def save!
      payload = { version: SAVE_VERSION }.merge(@values)
      $gtk.serialize_state(SAVE_PATH, payload)
    end

    # Apply OS-level side effects (fullscreen toggle). Called after load and
    # whenever the relevant value changes.
    def apply_window!
      return unless $gtk.respond_to?(:set_window_fullscreen)

      $gtk.set_window_fullscreen(get(:fullscreen))
    end
  end
end
