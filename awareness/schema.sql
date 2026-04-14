-- Known fleet: Matson, Pasha, and any tanker we've seen before.
-- Upserted as we learn about new hulls.
CREATE TABLE IF NOT EXISTS vessels (
  mmsi          INTEGER PRIMARY KEY,
  imo           INTEGER,
  name          TEXT,
  ais_type      INTEGER,         -- 70-79 cargo, 80-89 tanker
  operator      TEXT,            -- 'matson', 'pasha', 'par_hawaii', 'unknown'
  first_seen    TEXT NOT NULL,
  last_seen     TEXT NOT NULL
);

-- Raw-ish AIS observations, normalized just enough to be queryable.
-- Append-only. Roll off after 90 days.
CREATE TABLE IF NOT EXISTS ais_observations (
  id            INTEGER PRIMARY KEY,
  mmsi          INTEGER NOT NULL,
  ts            TEXT NOT NULL,
  lat           REAL NOT NULL,
  lon           REAL NOT NULL,
  sog           REAL,            -- speed over ground, knots
  cog           REAL,            -- course over ground
  destination   TEXT,            -- raw self-reported
  dest_norm     TEXT,            -- 'HNL' if normalizer matched
  eta_reported  TEXT
);
CREATE INDEX IF NOT EXISTS idx_ais_mmsi_ts ON ais_observations(mmsi, ts);

-- Scheduled sailings scraped from Matson/Pasha sites.
-- Upserted by (carrier, voyage_id).
CREATE TABLE IF NOT EXISTS schedules (
  carrier       TEXT NOT NULL,   -- 'matson' | 'pasha'
  voyage_id     TEXT NOT NULL,
  vessel_name   TEXT NOT NULL,
  origin        TEXT NOT NULL,   -- 'LGB', 'OAK', 'SAN'
  destination   TEXT NOT NULL,   -- 'HNL'
  scheduled_departure TEXT,
  scheduled_arrival   TEXT,
  scraped_at    TEXT NOT NULL,
  PRIMARY KEY (carrier, voyage_id)
);

-- Marine Exchange of SoCal daily snapshot. Append-only.
CREATE TABLE IF NOT EXISTS socal_congestion (
  ts            TEXT PRIMARY KEY,
  ships_at_anchor       INTEGER,
  ships_at_berth        INTEGER,
  ships_inbound_24h     INTEGER,
  ships_inbound_3day    INTEGER
);

-- Anomalies the threshold layer fires. Append-only; the app marks them read.
CREATE TABLE IF NOT EXISTS alerts (
  id            INTEGER PRIMARY KEY,
  ts            TEXT NOT NULL,
  severity      TEXT NOT NULL,   -- 'info' | 'watch' | 'warning'
  category      TEXT NOT NULL,   -- 'tanker' | 'container' | 'upstream'
  message       TEXT NOT NULL,
  detail_json   TEXT,
  acknowledged  INTEGER NOT NULL DEFAULT 0
);
