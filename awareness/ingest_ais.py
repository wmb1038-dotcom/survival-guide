"""AIS stream ingestor — connects to AISStream.io and writes to the local DB."""

from __future__ import annotations

import asyncio
import json
import logging
import logging.handlers
import re
import signal
import sqlite3
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import websockets
import websockets.exceptions

from . import config as cfg_mod, db

# ---------------------------------------------------------------------------
# Fleet classification constants — edit these to update operator mappings
# ---------------------------------------------------------------------------

# Punctuation stripped during fleet-name normalization.
_PUNCT_RE = re.compile(r'[.,\-]')


def _normalize_name(s: str) -> str:
    """Uppercase, collapse whitespace, strip periods/commas/hyphens.

    Used for fleet-set lookups only — the raw name is stored in the DB.
    """
    s = _PUNCT_RE.sub("", (s or "").upper())
    return " ".join(s.split())


MATSON_NAMES: frozenset[str] = frozenset({
    "LURLINE", "MATSONIA", "MANOA", "MAHIMAHI",
    "MANUKAI", "MAUNALEI", "DANIEL K INOUYE", "DANIEL K. INOUYE", "KAIMANA HILA",
})

PASHA_NAMES: frozenset[str] = frozenset({
    "GEORGE III", "JANET MARIE", "MARJORIE C", "JEAN ANNE",
})

# Pre-normalized versions of the fleet sets for punctuation-tolerant matching.
_MATSON_NORM: frozenset[str] = frozenset(_normalize_name(n) for n in MATSON_NAMES)
_PASHA_NORM:  frozenset[str] = frozenset(_normalize_name(n) for n in PASHA_NAMES)

AIS_STREAM_URL = "wss://stream.aisstream.io/v0/stream"
BATCH_SIZE = 50
BATCH_SECONDS = 2.0
MAX_BACKOFF = 60
LOG_PATH = db.APP_SUPPORT / "ingest.log"

# Types that SQLite's Python driver accepts without complaint.
_SCALAR_TYPES = (str, int, float, bool, bytes, type(None))

# Matches the date+time portion of both Go-style and ISO-8601 timestamps:
#   "2026-04-13 19:39:24.123456789 +0000 UTC"
#   "2024-01-01T00:00:00Z"
_GO_TS_RE = re.compile(r'(\d{4}-\d{2}-\d{2})[\sT](\d{2}:\d{2}:\d{2})')


# ---------------------------------------------------------------------------
# Logging setup
# ---------------------------------------------------------------------------

def _setup_logging() -> logging.Logger:
    LOG_PATH.parent.mkdir(parents=True, exist_ok=True)
    logger = logging.getLogger("awareness.ingest_ais")
    if logger.handlers:
        return logger
    logger.setLevel(logging.INFO)
    fh = logging.handlers.RotatingFileHandler(
        LOG_PATH, maxBytes=5 * 1024 * 1024, backupCount=3
    )
    fh.setFormatter(logging.Formatter("%(asctime)s %(levelname)s %(message)s"))
    logger.addHandler(fh)
    sh = logging.StreamHandler()
    sh.setFormatter(logging.Formatter("%(asctime)s %(levelname)s %(message)s"))
    logger.addHandler(sh)
    return logger


# ---------------------------------------------------------------------------
# Operator classification
# ---------------------------------------------------------------------------

def classify_operator(name: str, ais_type: int | None) -> str:
    norm = _normalize_name(name)
    if norm.startswith("MATSON ") or norm in _MATSON_NORM:
        return "matson"
    if norm in _PASHA_NORM:
        return "pasha"
    if ais_type is not None and 80 <= ais_type <= 89:
        return "tanker_unknown"
    if ais_type is not None and 70 <= ais_type <= 79:
        return "cargo_unknown"
    return "unknown"


# ---------------------------------------------------------------------------
# Database helpers
# ---------------------------------------------------------------------------

def _coerce_scalar(value: Any, field: str, log: logging.Logger) -> Any:
    """Return *value* if SQLite can bind it directly; otherwise warn and return None.

    datetime objects are converted to 'YYYY-MM-DD HH:MM:SS' strings rather than
    being nulled out, so a datetime that slips through the parser is still stored.
    """
    if isinstance(value, _SCALAR_TYPES):
        return value
    if isinstance(value, datetime):
        return value.strftime("%Y-%m-%d %H:%M:%S")
    log.warning(
        "Non-scalar value dropped — field=%r type=%s repr=%r",
        field, type(value).__name__, value,
    )
    return None


def _format_eta(eta: Any) -> str | None:
    """Convert AISStream's ETA dict {Month, Day, Hour, Minute} to 'MM-DDThh:mmZ'.

    Returns None when *eta* is already None, is a zero-field dict (meaning
    "not set" in the AIS spec), or is some other non-string type.
    """
    if eta is None:
        return None
    if isinstance(eta, str):
        return eta or None
    if not isinstance(eta, dict):
        return None
    month  = int(eta.get("Month",  0) or 0)
    day    = int(eta.get("Day",    0) or 0)
    hour   = int(eta.get("Hour",   0) or 0)
    minute = int(eta.get("Minute", 0) or 0)
    if not any((month, day, hour, minute)):
        return None  # all-zero means "not set" in the AIS spec
    return f"{month:02d}-{day:02d}T{hour:02d}:{minute:02d}Z"


def _parse_ais_timestamp(s: str) -> str:
    """Normalize an AISStream time_utc string to 'YYYY-MM-DD HH:MM:SS' (UTC).

    Handles the Go runtime format:  "2026-04-13 19:39:24.123456789 +0000 UTC"
    Also accepts standard ISO-8601: "2024-01-01T00:00:00Z"
    Falls back to the current UTC wall clock on parse failure, logging a warning.
    """
    if s:
        m = _GO_TS_RE.match(s.strip())
        if m:
            return f"{m.group(1)} {m.group(2)}"
    logging.getLogger("awareness.ingest_ais").warning(
        "Unparseable time_utc %r — substituting wall clock", s
    )
    return datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S")


def _now_utc() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S")


def upsert_vessel(
    conn: sqlite3.Connection,
    mmsi: int,
    name: str,
    ais_type: int | None = None,
    imo: int | None = None,
) -> None:
    now = _now_utc()
    operator = classify_operator(name, ais_type)
    conn.execute(
        """
        INSERT INTO vessels (mmsi, imo, name, ais_type, operator, first_seen, last_seen)
        VALUES (?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(mmsi) DO UPDATE SET
            name      = excluded.name,
            ais_type  = COALESCE(excluded.ais_type, vessels.ais_type),
            imo       = COALESCE(excluded.imo,       vessels.imo),
            operator  = excluded.operator,
            last_seen = excluded.last_seen
        """,
        (mmsi, imo, name, ais_type, operator, now, now),
    )


def retag_existing_vessels(db_path: Path = db.DB_PATH) -> int:
    """Re-run classify_operator on every row in vessels and update operator in place.

    Returns the number of rows updated.  Safe to call while ingest is stopped.
    """
    with db.connect(db_path) as conn:
        rows = conn.execute("SELECT mmsi, name, ais_type FROM vessels").fetchall()
        for row in rows:
            operator = classify_operator(row["name"], row["ais_type"])
            conn.execute(
                "UPDATE vessels SET operator = ? WHERE mmsi = ?",
                (operator, row["mmsi"]),
            )
    return len(rows)


def insert_observation(
    conn: sqlite3.Connection,
    mmsi: int,
    ts: str,
    lat: float,
    lon: float,
    sog: float | None,
    cog: float | None,
) -> None:
    conn.execute(
        """
        INSERT INTO ais_observations (mmsi, ts, lat, lon, sog, cog)
        VALUES (?, ?, ?, ?, ?, ?)
        """,
        (mmsi, ts, lat, lon, sog, cog),
    )


def update_static_data(
    conn: sqlite3.Connection,
    mmsi: int,
    destination: str | None,
    eta: str | None,
) -> None:
    """Write destination/ETA into the most recent observation within 10 minutes."""
    conn.execute(
        """
        UPDATE ais_observations
        SET destination = ?, eta_reported = ?
        WHERE id = (
            SELECT id FROM ais_observations
            WHERE mmsi = ?
              AND ts >= datetime('now', '-10 minutes')
            ORDER BY ts DESC
            LIMIT 1
        )
        """,
        (destination, eta, mmsi),
    )


# ---------------------------------------------------------------------------
# Message parsing
# ---------------------------------------------------------------------------

def _parse_position_report(msg: dict[str, Any]) -> tuple:
    meta = msg["MetaData"]
    pr = msg["Message"]["PositionReport"]
    sog_raw = pr.get("Sog")
    cog_raw = pr.get("Cog")
    return (
        "position",
        int(meta["MMSI"]),
        _parse_ais_timestamp(meta.get("time_utc", "")),
        float(meta["latitude"]),
        float(meta["longitude"]),
        float(sog_raw) if sog_raw is not None else None,
        float(cog_raw) if cog_raw is not None else None,
        (meta.get("ShipName") or "").strip(),
    )


def _parse_ship_static(msg: dict[str, Any]) -> tuple:
    meta = msg["MetaData"]
    sd = msg["Message"]["ShipStaticData"]
    # Eta arrives as a dict {Month, Day, Hour, Minute} — convert to a string.
    eta_raw = sd.get("Eta") if "Eta" in sd else sd.get("ETA")
    return (
        "static",
        int(meta["MMSI"]),
        _parse_ais_timestamp(meta.get("time_utc", "")),
        (meta.get("ShipName") or sd.get("Name") or "").strip(),
        sd.get("ImoNumber") or sd.get("Imo"),
        sd.get("Type"),
        sd.get("Destination"),
        _format_eta(eta_raw),
    )


# ---------------------------------------------------------------------------
# Batch flush
# ---------------------------------------------------------------------------

def flush_batch(pending: list[tuple], db_path: Path, log: logging.Logger) -> None:
    if not pending:
        return

    def _c(v: Any, f: str) -> Any:
        return _coerce_scalar(v, f, log)

    try:
        with db.connect(db_path) as conn:
            for row in pending:
                kind = row[0]
                if kind == "position":
                    _, mmsi, ts, lat, lon, sog, cog, name = row
                    obs_fields = ("mmsi", "ts", "lat", "lon", "sog", "cog")
                    obs_raw    = (mmsi, ts, lat, lon, sog, cog)
                    # Log full field breakdown at ERROR before any insert so the
                    # offending value is visible in ingest.log even on failure.
                    if not all(isinstance(v, _SCALAR_TYPES) for v in obs_raw):
                        log.error(
                            "Non-scalar field(s) in position row — breakdown: %s",
                            {f: (repr(v), type(v).__name__)
                             for f, v in zip(obs_fields, obs_raw)},
                        )
                    obs = tuple(_c(v, f) for v, f in zip(obs_raw, obs_fields))
                    upsert_vessel(conn, mmsi, _c(name, "name"))
                    insert_observation(conn, *obs)

                elif kind == "static":
                    _, mmsi, ts, name, imo, ais_type, destination, eta = row
                    # Normalise ETA here too — guards against callers that
                    # bypass _parse_ship_static with a raw dict.
                    eta = _format_eta(eta)
                    static_fields = ("mmsi", "ts", "name", "imo",
                                     "ais_type", "destination", "eta")
                    static_raw    = (mmsi, ts, name, imo, ais_type, destination, eta)
                    if not all(isinstance(v, _SCALAR_TYPES) for v in static_raw):
                        log.error(
                            "Non-scalar field(s) in static row — breakdown: %s",
                            {f: (repr(v), type(v).__name__)
                             for f, v in zip(static_fields, static_raw)},
                        )
                    c = {f: _c(v, f) for f, v in zip(static_fields, static_raw)}
                    upsert_vessel(conn, c["mmsi"], c["name"],
                                  ais_type=c["ais_type"], imo=c["imo"])
                    update_static_data(conn, c["mmsi"], c["destination"], c["eta"])

        log.debug("Flushed %d records", len(pending))
    except Exception as exc:
        log.error("Flush failed: %s", exc)
    pending.clear()


# ---------------------------------------------------------------------------
# Subscription builder
# ---------------------------------------------------------------------------

def _redact_key(key: str) -> str:
    """Show first 4 and last 4 chars; mask the middle."""
    if len(key) >= 9:
        return f"{key[:4]}...{key[-4:]}"
    return "****"


def _build_subscription(cfg: cfg_mod.Config) -> dict[str, Any]:
    """Return the AISStream subscription payload as a plain dict.

    BoundingBoxes format: [[[sw_lat, sw_lon], [ne_lat, ne_lon]]]
    AISStream wants LAT first in each pair; sw = (min_lat, min_lon),
    ne = (max_lat, max_lon).
    """
    bb = cfg.oahu_bbox
    return {
        "APIKey": cfg.aisstream_api_key,
        "BoundingBoxes": [[[bb.min_lat, bb.min_lon], [bb.max_lat, bb.max_lon]]],
        "FilterMessageTypes": ["PositionReport", "ShipStaticData"],
    }


# ---------------------------------------------------------------------------
# Core streaming loop
# ---------------------------------------------------------------------------

async def _stream(
    cfg: cfg_mod.Config,
    db_path: Path,
    log: logging.Logger,
    stop: asyncio.Event,
) -> None:
    sub = _build_subscription(cfg)
    # Log the full payload before the first send, with the key redacted.
    loggable = {**sub, "APIKey": _redact_key(cfg.aisstream_api_key)}
    log.info("Subscription payload: %s", json.dumps(loggable))
    sub_msg = json.dumps(sub)

    backoff = 1
    pending: list[tuple] = []

    while not stop.is_set():
        try:
            log.info("Connecting to %s", AIS_STREAM_URL)
            async with websockets.connect(AIS_STREAM_URL) as ws:
                log.info("Connected — sending subscription.")
                await ws.send(sub_msg)
                backoff = 1  # reset on successful connect
                last_flush = asyncio.get_running_loop().time()

                while not stop.is_set():
                    try:
                        raw = await asyncio.wait_for(ws.recv(), timeout=BATCH_SECONDS)
                    except asyncio.TimeoutError:
                        flush_batch(pending, db_path, log)
                        last_flush = asyncio.get_running_loop().time()
                        continue

                    try:
                        msg = json.loads(raw)
                    except json.JSONDecodeError:
                        continue

                    mtype = msg.get("MessageType")
                    if mtype == "PositionReport":
                        pending.append(_parse_position_report(msg))
                    elif mtype == "ShipStaticData":
                        pending.append(_parse_ship_static(msg))

                    now = asyncio.get_running_loop().time()
                    if len(pending) >= BATCH_SIZE or now - last_flush >= BATCH_SECONDS:
                        flush_batch(pending, db_path, log)
                        last_flush = now

        except (
            websockets.exceptions.ConnectionClosed,
            websockets.exceptions.WebSocketException,
            OSError,
        ) as exc:
            log.warning("Disconnected (%s). Reconnecting in %ds.", exc, backoff)
            flush_batch(pending, db_path, log)
            try:
                await asyncio.wait_for(stop.wait(), timeout=float(backoff))
            except asyncio.TimeoutError:
                pass
            backoff = min(backoff * 2, MAX_BACKOFF)

    flush_batch(pending, db_path, log)
    log.info("Ingest stopped cleanly.")


# ---------------------------------------------------------------------------
# Public entry point
# ---------------------------------------------------------------------------

def run(db_path: Path = db.DB_PATH) -> None:
    """Block until SIGINT/SIGTERM, streaming AIS data into the database."""
    log = _setup_logging()
    cfg = cfg_mod.load()
    if not cfg.key_set:
        log.error("No AISStream API key configured. Set aisstream_api_key in config.toml.")
        raise SystemExit(1)

    db.init(db_path)

    loop = asyncio.new_event_loop()
    asyncio.set_event_loop(loop)
    stop = asyncio.Event()

    def _shutdown(sig_name: str) -> None:
        log.info("Received %s — shutting down.", sig_name)
        loop.call_soon_threadsafe(stop.set)

    for sig in (signal.SIGINT, signal.SIGTERM):
        loop.add_signal_handler(sig, _shutdown, sig.name)

    try:
        loop.run_until_complete(_stream(cfg, db_path, log, stop))
    finally:
        loop.close()
