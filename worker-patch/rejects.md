# Rejected-word log — Worker additions

One table, one POST route, one page to read it. Nothing else changes.

## 1. Schema

`wrangler d1 execute <db-name> --file=./rejects.sql --remote`

```sql
CREATE TABLE IF NOT EXISTS rejects (
  word TEXT NOT NULL,
  device_id TEXT NOT NULL,
  day INTEGER,
  created_at TEXT DEFAULT (datetime('now'))
);
CREATE INDEX IF NOT EXISTS idx_rejects_word ON rejects(word);
CREATE INDEX IF NOT EXISTS idx_rejects_created ON rejects(created_at);
```

## 2. Routes

Add before the `/leaderboard` handler.

```js
// POST /rejects {words:[...], day, deviceId}
if (request.method === "POST" && url.pathname === "/rejects") {
  let body;
  try { body = await request.json(); } catch (e) {
    return jsonResponse({ error: "invalid payload" }, headers, 400);
  }
  const deviceId = String(body.deviceId || "").slice(0, 64);
  const day = Number(body.day);
  const words = Array.isArray(body.words) ? body.words : [];
  if (!deviceId || !Number.isInteger(day)) {
    return jsonResponse({ error: "invalid payload" }, headers, 400);
  }
  const clean = [...new Set(
    words.map(w => String(w).toLowerCase()).filter(w => /^[a-z]{3,50}$/.test(w))
  )].slice(0, 25);
  if (clean.length) {
    await env.DB.batch(clean.map(w =>
      env.DB.prepare("INSERT INTO rejects (word, device_id, day) VALUES (?, ?, ?)")
        .bind(w, deviceId, day)
    ));
  }
  return jsonResponse({ ok: true, stored: clean.length }, headers);
}

// GET /rejects — the full running list, most-attempted first.
// Optional ?days=N narrows it; by default nothing is cut off.
if (request.method === "GET" && url.pathname === "/rejects") {
  const daysParam = url.searchParams.get("days");
  const days = daysParam ? Math.max(1, Number(daysParam)) : null;
  const where = days ? "WHERE created_at >= datetime('now', ?)" : "";
  const sql =
    `SELECT word,
            COUNT(DISTINCT device_id) AS players,
            COUNT(*) AS attempts,
            MIN(created_at) AS first_seen,
            MAX(created_at) AS last_seen
     FROM rejects
     ${where}
     GROUP BY word
     ORDER BY players DESC, attempts DESC, word ASC`;
  const stmt = days ? env.DB.prepare(sql).bind('-' + days + ' days') : env.DB.prepare(sql);
  const { results } = await stmt.all();

  // plain text so it can be read on a phone without tooling
  if (url.searchParams.get("format") === "text") {
    const lines = results.map(r => `${String(r.players).padStart(4)}  ${r.word}`);
    return new Response(
      `Rejected words${days ? `, last ${days} days` : ' (all time)'}\n` +
      `${results.length} distinct\n\nplayers  word\n` + lines.join("\n"),
      { headers: { ...headers, "Content-Type": "text/plain; charset=utf-8" } }
    );
  }
  return jsonResponse({ days: days, count: results.length, rejects: results }, headers);
}
```

## 3. Reading it

Bookmark this. It's the whole list, always current, no time limit:

`https://word-burger-leaderboard.hamish-harris.workers.dev/rejects?format=text`

Words most players tried appear at the top. Two-letter words never arrive —
they're filtered in the game before sending.

Add `&days=7` if you ever want to see only what's come in recently.

## 4. Housekeeping

Nothing is pruned; the list is meant to keep going. If it ever needs
trimming, individual words can be cleared once they've been added to the
dictionary:

```sql
DELETE FROM rejects WHERE word IN ('artisanally', 'jungian');
```
