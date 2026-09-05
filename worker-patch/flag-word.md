# Word flagging — Worker additions

Two routes plus one table. Read-only apart from the insert.

## 1. Schema

```sql
CREATE TABLE IF NOT EXISTS word_flags (
  word TEXT NOT NULL,
  device_id TEXT NOT NULL,
  day INTEGER,
  created_at TEXT DEFAULT (datetime('now')),
  UNIQUE(word, device_id)
);
CREATE INDEX IF NOT EXISTS idx_word_flags_word ON word_flags(word);
```

Apply with:
`wrangler d1 execute <db-name> --file=./flag-word.sql --remote`

## 2. Routes

Drop these in alongside the existing ones, before the `/leaderboard` handler.

```js
// POST /flag-word {word, day, deviceId}
if (request.method === "POST" && url.pathname === "/flag-word") {
  let body;
  try { body = await request.json(); } catch (e) {
    return jsonResponse({ error: "invalid payload" }, headers, 400);
  }
  const word = String(body.word || "").toLowerCase();
  const day = Number(body.day);
  const deviceId = String(body.deviceId || "").slice(0, 64);
  if (!/^[a-z]{3,50}$/.test(word) || !Number.isInteger(day) || day < 0 || !deviceId) {
    return jsonResponse({ error: "invalid payload" }, headers, 400);
  }
  await env.DB.prepare(
    "INSERT OR IGNORE INTO word_flags (word, device_id, day) VALUES (?, ?, ?)"
  ).bind(word, deviceId, day).run();
  return jsonResponse({ ok: true, word }, headers);
}

// GET /flags?limit=50 — the review list, most-flagged first
if (request.method === "GET" && url.pathname === "/flags") {
  const limit = Math.min(200, Math.max(1, Number(url.searchParams.get("limit")) || 50));
  const { results } = await env.DB.prepare(
    `SELECT word, COUNT(*) AS players, MIN(created_at) AS first_seen
     FROM word_flags GROUP BY word ORDER BY players DESC, first_seen ASC LIMIT ?`
  ).bind(limit).all();
  return jsonResponse({ flags: results }, headers);
}
```

## 3. Reviewing

`https://word-burger-leaderboard.hamish-harris.workers.dev/flags`
returns every flagged word ranked by how many different players flagged it.
