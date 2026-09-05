CREATE TABLE IF NOT EXISTS word_flags (
  word TEXT NOT NULL,
  device_id TEXT NOT NULL,
  day INTEGER,
  created_at TEXT DEFAULT (datetime('now')),
  UNIQUE(word, device_id)
);
CREATE INDEX IF NOT EXISTS idx_word_flags_word ON word_flags(word);
