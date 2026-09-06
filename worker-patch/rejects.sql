CREATE TABLE IF NOT EXISTS rejects (
  word TEXT NOT NULL,
  device_id TEXT NOT NULL,
  day INTEGER,
  created_at TEXT DEFAULT (datetime('now'))
);
CREATE INDEX IF NOT EXISTS idx_rejects_word ON rejects(word);
CREATE INDEX IF NOT EXISTS idx_rejects_created ON rejects(created_at);
