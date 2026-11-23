// Persistence for the GAMEX database object.
//
// - DATABASE_URL set  → PostgreSQL. Every record is a row in `gamex_docs`
//   (collection, id, jsonb); settings-like values live in `gamex_kv`. Each
//   save writes only what changed, in one transaction.
// - no DATABASE_URL   → a JSON file (local development), written atomically.
//
// On the first PostgreSQL start an existing data/db.json is imported once and
// kept as db.json.migrated-<time>.
import fs from 'node:fs';
import path from 'node:path';

/** Field that identifies records in an array collection. */
const idField = (arr) => {
  if (!arr.length) return 'id';
  for (const f of ['id', 'token']) if (arr.every((x) => x && typeof x === 'object' && typeof x[f] === 'string')) return f;
  return null;
};

function jsonStore(file, seed) {
  let db;
  try {
    db = JSON.parse(fs.readFileSync(file, 'utf8'));
  } catch {
    db = seed();
  }
  return {
    kind: 'json',
    db,
    async persist(d) {
      fs.mkdirSync(path.dirname(file), { recursive: true });
      fs.writeFileSync(file + '.tmp', JSON.stringify(d));
      fs.renameSync(file + '.tmp', file);
    },
    async close() {},
  };
}

async function pgStore(url, file, seed) {
  const { default: pg } = await import('pg');
  const pool = new pg.Pool({ connectionString: url, max: 4 });
  await pool.query(`
    create table if not exists gamex_docs (
      col text not null,
      id text not null,
      data jsonb not null,
      updated_at timestamptz not null default now(),
      primary key (col, id)
    );
    create table if not exists gamex_kv (
      key text primary key,
      data jsonb not null,
      updated_at timestamptz not null default now()
    );`);

  // cache of what the database holds: "col\0id" → json, "kv\0key" → json
  const cache = new Map();
  let running = null;
  let again = false;
  let db;
  const meta = await pool.query(`select data from gamex_kv where key = '__meta'`);
  if (!meta.rowCount) {
    let source = 'seed';
    try {
      db = JSON.parse(fs.readFileSync(file, 'utf8'));
      source = 'db.json';
    } catch {
      db = seed();
    }
    await writeAll(db);
    await pool.query(`insert into gamex_kv(key, data) values ('__meta', $1)`, [JSON.stringify({ createdAt: new Date().toISOString(), source })]);
    if (source === 'db.json') fs.renameSync(file, `${file}.migrated-${Date.now()}`);
    console.log(`[storage] PostgreSQL initialised from ${source}`);
  } else {
    db = await readAll();
  }

  async function readAll() {
    const out = {};
    const kv = await pool.query(`select key, data from gamex_kv where key <> '__meta'`);
    const orders = {};
    for (const r of kv.rows) {
      if (r.key.startsWith('order:')) orders[r.key.slice(6)] = r.data;
      else out[r.key] = r.data;
      cache.set(`kv\0${r.key}`, JSON.stringify(r.data));
    }
    const docs = await pool.query(`select col, id, data from gamex_docs`);
    const byCol = {};
    for (const r of docs.rows) {
      (byCol[r.col] ??= new Map()).set(r.id, r.data);
      cache.set(`${r.col}\0${r.id}`, JSON.stringify(r.data));
    }
    for (const [col, m] of Object.entries(byCol)) {
      const order = orders[col] || [];
      const list = [];
      for (const id of order) if (m.has(id)) list.push(m.get(id)), m.delete(id);
      out[col] = [...list, ...m.values()];
    }
    for (const col of Object.keys(orders)) out[col] ??= [];
    return out;
  }

  async function writeAll(d) {
    cache.clear();
    await persist(d);
  }

  async function persist(d) {
    if (running) {
      again = true;
      return running;
    }
    running = (async () => {
      do {
        again = false;
        await writeDiff(d);
      } while (again);
    })().finally(() => (running = null));
    return running;
  }

  async function writeDiff(d) {
    const up = { col: [], id: [], data: [] };
    const kvUp = { key: [], data: [] };
    const seen = new Set();
    for (const [key, val] of Object.entries(d)) {
      const f = Array.isArray(val) ? idField(val) : null;
      if (f) {
        const ids = [];
        for (const item of val) {
          const id = item[f];
          const k = `${key}\0${id}`;
          if (seen.has(k)) continue;
          seen.add(k);
          ids.push(id);
          const s = JSON.stringify(item);
          if (cache.get(k) !== s) {
            up.col.push(key);
            up.id.push(id);
            up.data.push(s);
          }
        }
        const ok = `kv\0order:${key}`;
        const os = JSON.stringify(ids);
        seen.add(ok);
        if (cache.get(ok) !== os) {
          kvUp.key.push(`order:${key}`);
          kvUp.data.push(os);
        }
      } else {
        const k = `kv\0${key}`;
        seen.add(k);
        const s = JSON.stringify(val ?? null);
        if (cache.get(k) !== s) {
          kvUp.key.push(key);
          kvUp.data.push(s);
        }
      }
    }
    const gone = [...cache.keys()].filter((k) => !seen.has(k));
    if (!up.col.length && !kvUp.key.length && !gone.length) return;
    const c = await pool.connect();
    try {
      await c.query('begin');
      if (up.col.length) {
        await c.query(
          `insert into gamex_docs(col, id, data)
           select * from unnest($1::text[], $2::text[], $3::jsonb[])
           on conflict (col, id) do update set data = excluded.data, updated_at = now()`,
          [up.col, up.id, up.data],
        );
      }
      if (kvUp.key.length) {
        await c.query(
          `insert into gamex_kv(key, data)
           select * from unnest($1::text[], $2::jsonb[])
           on conflict (key) do update set data = excluded.data, updated_at = now()`,
          [kvUp.key, kvUp.data],
        );
      }
      const goneDocs = gone.filter((k) => !k.startsWith('kv\0')).map((k) => k.split('\0'));
      if (goneDocs.length) {
        await c.query(`delete from gamex_docs d using unnest($1::text[], $2::text[]) as g(col, id) where d.col = g.col and d.id = g.id`, [
          goneDocs.map((x) => x[0]),
          goneDocs.map((x) => x[1]),
        ]);
      }
      const goneKv = gone.filter((k) => k.startsWith('kv\0')).map((k) => k.slice(3));
      if (goneKv.length) await c.query(`delete from gamex_kv where key = any($1::text[])`, [goneKv]);
      await c.query('commit');
    } catch (e) {
      await c.query('rollback').catch(() => {});
      console.error('[storage] save failed:', e.message);
      return;
    } finally {
      c.release();
    }
    // Commit succeeded: update the cache.
    for (let i = 0; i < up.col.length; i++) cache.set(`${up.col[i]}\0${up.id[i]}`, up.data[i]);
    for (let i = 0; i < kvUp.key.length; i++) cache.set(`kv\0${kvUp.key[i]}`, kvUp.data[i]);
    for (const k of gone) cache.delete(k);
  }

  return {
    kind: 'postgres',
    db,
    persist,
    async close() {
      if (running) await running;
      await pool.end();
    },
  };
}

/** Opens the store. Returns { kind, db, persist(db), close() }. */
export async function openStore({ file, url, seed }) {
  return url ? pgStore(url, file, seed) : jsonStore(file, seed);
}
