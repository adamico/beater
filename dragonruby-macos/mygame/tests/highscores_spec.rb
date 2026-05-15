require 'app/highscores'

def test_highscores_reset_seeds_ten_descending_entries(_args, assert)
  Highscores.reset!
  entries = Highscores.entries
  assert.equal! entries.length, 10
  scores = entries.map { |e| e[:score] }
  assert.equal! scores, scores.sort.reverse
end

def test_highscores_qualifies_when_table_not_full(_args, assert)
  Highscores.instance_variable_set(:@entries, [])
  assert.equal! Highscores.qualifies?(1), true
end

def test_highscores_qualifies_only_when_beating_lowest(_args, assert)
  Highscores.reset!
  lowest = Highscores.entries.last[:score]
  assert.equal! Highscores.qualifies?(lowest), false
  assert.equal! Highscores.qualifies?(lowest + 1), true
end

def test_highscores_insert_sorts_by_score_then_time(_args, assert)
  Highscores.instance_variable_set(:@entries, [
    { score: 100, level_reached: 1, time_seconds: 30, initials: 'AAA', date: '2026-01-01' },
    { score: 200, level_reached: 1, time_seconds: 60, initials: 'BBB', date: '2026-01-01' }
  ])
  # Tie on score: shorter time wins, so this entry lands rank 2 ahead of AAA.
  rank = Highscores.insert(
    score: 100, level_reached: 2, time_seconds: 10,
    initials: 'CCC', date: '2026-01-02'
  )
  assert.equal! rank, 2
  assert.equal! Highscores.entries[1][:initials], 'CCC'
  assert.equal! Highscores.entries[2][:initials], 'AAA'
end

def test_highscores_insert_caps_at_max_entries(_args, assert)
  Highscores.reset!
  Highscores.insert(
    score: 999_999, level_reached: 99, time_seconds: 1,
    initials: 'ZZZ', date: '2026-01-01'
  )
  assert.equal! Highscores.entries.length, 10
  assert.equal! Highscores.entries.first[:initials], 'ZZZ'
end

def test_highscores_format_time_pads_mm_ss(_args, assert)
  assert.equal! Highscores.format_time(0), '00:00'
  assert.equal! Highscores.format_time(65), '01:05'
  assert.equal! Highscores.format_time(3725), '62:05'
end
