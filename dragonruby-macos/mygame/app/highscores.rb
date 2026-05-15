# Local top-10 highscore table, persisted to `highscores.txt` via
# $gtk.serialize_state. Schema version 1 (see ADR-0013). Missing/incompatible
# file on first run → seeded with placeholders for visual interest.
module Highscores
  SAVE_PATH = 'highscores.txt'.freeze
  SAVE_VERSION = 1
  MAX_ENTRIES = 10

  PLACEHOLDER_INITIALS = %w[AAA BBB CCC DDD EEE FFF GGG HHH III JJJ].freeze
  PLACEHOLDER_DATE = '2026-01-01'.freeze

  @entries = []

  class << self
    attr_reader :entries

    def reset!
      @entries = seeded_placeholders
    end

    def load!
      raw = ($gtk.deserialize_state(SAVE_PATH) rescue nil)
      if raw.is_a?(Hash) && raw[:version] == SAVE_VERSION && raw[:entries].is_a?(Array)
        @entries = raw[:entries].first(MAX_ENTRIES)
      else
        reset!
      end
    end

    def save!
      $gtk.serialize_state(SAVE_PATH, { version: SAVE_VERSION, entries: @entries })
    end

    def qualifies?(score)
      return true if @entries.length < MAX_ENTRIES

      score > @entries.last[:score]
    end

    # Insert a new run and persist. Returns the 1-based rank of the inserted
    # entry, or nil if it didn't make the cut after sorting.
    def insert(score:, level_reached:, time_seconds:, initials:, date:)
      entry = {
        score: score, level_reached: level_reached,
        time_seconds: time_seconds, initials: initials, date: date
      }
      @entries << entry
      # Higher score wins; ties broken by shorter time. mruby has no sort_by!.
      @entries = @entries.sort_by { |e| [-e[:score].to_i, e[:time_seconds].to_i] }
      @entries = @entries.first(MAX_ENTRIES)
      save!
      idx = @entries.index(entry)
      idx.nil? ? nil : idx + 1
    end

    def format_time(seconds)
      seconds = seconds.to_i
      m = seconds / 60
      s = seconds % 60
      "#{pad2(m)}:#{pad2(s)}"
    end

    private

    def pad2(n)
      n = n.to_i
      n < 10 ? "0#{n}" : n.to_s
    end

    def seeded_placeholders
      base_scores = [5000, 4500, 4000, 3500, 3000, 2500, 2000, 1500, 1000, 500]
      base_scores.each_with_index.map do |sc, i|
        {
          score: sc, level_reached: 1, time_seconds: 60 + i * 20,
          initials: PLACEHOLDER_INITIALS[i], date: PLACEHOLDER_DATE
        }
      end
    end
  end
end
