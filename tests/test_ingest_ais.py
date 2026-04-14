"""Tests for awareness/ingest_ais.py.

Uses a fake WebSocket — never hits the real AISStream API.
"""

from __future__ import annotations

import asyncio
import json
import logging
import sqlite3
from pathlib import Path
from unittest.mock import patch

import pytest

import awareness.db as db_mod
from awareness import config as cfg_mod
from awareness.ingest_ais import (
    MATSON_NAMES,
    PASHA_NAMES,
    _build_subscription,
    _coerce_scalar,
    _format_eta,
    _normalize_name,
    _parse_ais_timestamp,
    _parse_position_report,
    _redact_key,
    _stream,
    classify_operator,
    flush_batch,
    retag_existing_vessels,
)

log = logging.getLogger("test_ingest_ais")

# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------


@pytest.fixture()
def tmp_db(tmp_path: Path):
    """Temp DB with full schema applied; db module globals redirected."""
    tmp_file = tmp_path / "maritime.db"
    with (
        patch.object(db_mod, "APP_SUPPORT", tmp_path),
        patch.object(db_mod, "DB_PATH", tmp_file),
    ):
        db_mod.init(tmp_file)
        yield tmp_file


def _cfg() -> cfg_mod.Config:
    return cfg_mod.Config({"aisstream_api_key": "testkey_abc123"})


# ---------------------------------------------------------------------------
# classify_operator
# ---------------------------------------------------------------------------


def test_matson_prefix():
    assert classify_operator("MATSON ANCHORAGE", None) == "matson"


def test_matson_named_vessel():
    assert classify_operator("LURLINE", None) == "matson"
    assert classify_operator("KAIMANA HILA", None) == "matson"
    assert classify_operator("DANIEL K INOUYE", None) == "matson"


def test_matson_case_insensitive():
    assert classify_operator("matson express", None) == "matson"
    assert classify_operator("Maunalei", None) == "matson"


def test_pasha_vessel():
    assert classify_operator("GEORGE III", None) == "pasha"
    assert classify_operator("JANET MARIE", None) == "pasha"


def test_tanker_by_type():
    assert classify_operator("SOME TANKER", 80) == "tanker_unknown"
    assert classify_operator("SOME TANKER", 85) == "tanker_unknown"
    assert classify_operator("SOME TANKER", 89) == "tanker_unknown"


def test_tanker_type_boundary():
    # 80–89 are tanker; 79 falls in cargo range; 90 is unknown
    assert classify_operator("CARGO SHIP", 79) == "cargo_unknown"
    assert classify_operator("OTHER SHIP", 90) == "unknown"


def test_unknown_vessel():
    # ais_type 90+ has no category; None also falls through to unknown
    assert classify_operator("RANDOM SHIP", 90) == "unknown"
    assert classify_operator("", None) == "unknown"


def test_pasha_name_with_trailing_period():
    # Live AISStream sends "MARJORIE C." — period must not break the match.
    assert classify_operator("MARJORIE C.", None) == "pasha"


def test_matson_name_with_internal_period():
    # Live AISStream sends "DANIEL K. INOUYE".
    assert classify_operator("DANIEL K. INOUYE", None) == "matson"


def test_cargo_unknown_type_range():
    # ais_type 70–79 with no fleet match → cargo_unknown.
    assert classify_operator("SOME FREIGHTER", 74) == "cargo_unknown"
    assert classify_operator("BULK CARRIER", 70) == "cargo_unknown"
    assert classify_operator("GENERAL CARGO", 79) == "cargo_unknown"


def test_tanker_lowercase_name():
    # Lowercase name should not interfere with type-based classification.
    assert classify_operator("kodaijisan", 80) == "tanker_unknown"


# ---------------------------------------------------------------------------
# _normalize_name
# ---------------------------------------------------------------------------


def test_normalize_name_strips_periods():
    assert _normalize_name("DANIEL K. INOUYE") == "DANIEL K INOUYE"
    assert _normalize_name("MARJORIE C.") == "MARJORIE C"


def test_normalize_name_collapses_whitespace():
    assert _normalize_name("  LURLINE  ") == "LURLINE"
    assert _normalize_name("MATSON  NAVIGATOR") == "MATSON NAVIGATOR"


def test_normalize_name_uppercases():
    assert _normalize_name("lurline") == "LURLINE"


def test_normalize_name_removes_hyphens_and_commas():
    # Hyphens and commas are deleted, not replaced with a space.
    assert _normalize_name("JEAN-ANNE") == "JEANANNE"
    assert _normalize_name("SHIP, VESSEL") == "SHIP VESSEL"


# ---------------------------------------------------------------------------
# retag_existing_vessels
# ---------------------------------------------------------------------------


def test_retag_fixes_stale_operator(tmp_db: Path):
    """Vessels stored with wrong operator are corrected by retag_existing_vessels."""
    # Insert a Pasha vessel with the wrong operator (simulating pre-fix state).
    with sqlite3.connect(tmp_db) as conn:
        conn.execute(
            "INSERT INTO vessels (mmsi, name, ais_type, operator, first_seen, last_seen) "
            "VALUES (?, ?, ?, ?, datetime('now'), datetime('now'))",
            (366100001, "MARJORIE C.", None, "unknown"),
        )

    count = retag_existing_vessels(tmp_db)
    assert count == 1

    with sqlite3.connect(tmp_db) as conn:
        row = conn.execute(
            "SELECT operator FROM vessels WHERE mmsi = 366100001"
        ).fetchone()
    assert row[0] == "pasha"


def test_retag_returns_row_count(tmp_db: Path):
    with sqlite3.connect(tmp_db) as conn:
        for mmsi, name in [(366200001, "LURLINE"), (366200002, "GEORGE III")]:
            conn.execute(
                "INSERT INTO vessels (mmsi, name, ais_type, operator, first_seen, last_seen) "
                "VALUES (?, ?, NULL, 'unknown', datetime('now'), datetime('now'))",
                (mmsi, name),
            )
        conn.commit()

    count = retag_existing_vessels(tmp_db)
    assert count == 2


# ---------------------------------------------------------------------------
# flush_batch — vessel created with correct operator
# ---------------------------------------------------------------------------


def test_flush_creates_matson_vessel(tmp_db: Path):
    pending = [
        ("position", 123456789, "2024-01-01T00:00:00Z", 21.3, -158.0, 12.5, 180.0, "MAUNALEI")
    ]
    flush_batch(pending, tmp_db, log)

    with sqlite3.connect(tmp_db) as conn:
        row = conn.execute(
            "SELECT mmsi, name, operator FROM vessels WHERE mmsi = 123456789"
        ).fetchone()

    assert row is not None
    assert row[1] == "MAUNALEI"
    assert row[2] == "matson"


def test_flush_creates_observation_correct_fields(tmp_db: Path):
    pending = [
        ("position", 987654321, "2024-06-15T12:00:00Z", 21.5, -157.8, 8.3, 270.0, "MATSONIA")
    ]
    flush_batch(pending, tmp_db, log)

    with sqlite3.connect(tmp_db) as conn:
        row = conn.execute(
            "SELECT mmsi, ts, lat, lon, sog, cog FROM ais_observations WHERE mmsi = 987654321"
        ).fetchone()

    assert row is not None
    assert row[0] == 987654321
    assert row[1] == "2024-06-15T12:00:00Z"
    assert row[2] == pytest.approx(21.5)
    assert row[3] == pytest.approx(-157.8)
    assert row[4] == pytest.approx(8.3)
    assert row[5] == pytest.approx(270.0)


def test_flush_static_data_upserts_vessel(tmp_db: Path):
    pending = [
        ("static", 111222333, "2024-01-01T00:00:00Z", "LURLINE", 9999999, 71, "HNL", None)
    ]
    flush_batch(pending, tmp_db, log)

    with sqlite3.connect(tmp_db) as conn:
        row = conn.execute(
            "SELECT name, imo, ais_type, operator FROM vessels WHERE mmsi = 111222333"
        ).fetchone()

    assert row is not None
    assert row[0] == "LURLINE"
    assert row[1] == 9999999
    assert row[2] == 71
    assert row[3] == "matson"


def test_flush_empty_pending_is_noop(tmp_db: Path):
    pending: list = []
    flush_batch(pending, tmp_db, log)  # must not raise

    with sqlite3.connect(tmp_db) as conn:
        count = conn.execute("SELECT count(*) FROM vessels").fetchone()[0]
    assert count == 0


# ---------------------------------------------------------------------------
# _coerce_scalar
# ---------------------------------------------------------------------------


def test_coerce_scalar_passes_primitives():
    for val in ("hello", 42, 3.14, True, None, b"bytes"):
        assert _coerce_scalar(val, "f", log) is val


def test_coerce_scalar_returns_none_for_dict():
    result = _coerce_scalar({"key": "val"}, "eta", log)
    assert result is None


def test_coerce_scalar_returns_none_for_list():
    result = _coerce_scalar([1, 2, 3], "coords", log)
    assert result is None


# ---------------------------------------------------------------------------
# _format_eta
# ---------------------------------------------------------------------------


def test_format_eta_typical_dict():
    assert _format_eta({"Month": 3, "Day": 15, "Hour": 14, "Minute": 30}) == "03-15T14:30Z"


def test_format_eta_all_zeros_returns_none():
    assert _format_eta({"Month": 0, "Day": 0, "Hour": 0, "Minute": 0}) is None


def test_format_eta_none_returns_none():
    assert _format_eta(None) is None


def test_format_eta_string_passthrough():
    assert _format_eta("2024-03-15T14:30Z") == "2024-03-15T14:30Z"


def test_format_eta_empty_string_returns_none():
    assert _format_eta("") is None


def test_format_eta_unexpected_type_returns_none():
    assert _format_eta(12345) is None


# ---------------------------------------------------------------------------
# Regression: nested shapes that triggered the original 'type dict' error
# ---------------------------------------------------------------------------


def test_flush_position_with_dict_nav_status_succeeds(tmp_db: Path):
    """NavigationalStatus arriving as a dict must not crash the insert.

    We don't store nav_status, but the coercion layer must handle any
    unexpected shape that leaks through future parser changes.
    """
    # Simulate what would happen if a future parser accidentally included a
    # dict-typed field; flush_batch must survive and write the good fields.
    pending = [
        # sog deliberately passed as a dict to prove _coerce_scalar saves us
        ("position", 366001001, "2024-06-01T00:00:00Z", 21.3, -158.0,
         {"Value": 12.5},   # dict instead of float — coerced to None
         180.0, "MATSON TEST"),
    ]
    flush_batch(pending, tmp_db, log)

    with sqlite3.connect(tmp_db) as conn:
        row = conn.execute(
            "SELECT mmsi, lat, lon, sog FROM ais_observations WHERE mmsi = 366001001"
        ).fetchone()

    assert row is not None, "Row must be inserted despite coercion"
    assert row[1] == pytest.approx(21.3)
    assert row[2] == pytest.approx(-158.0)
    assert row[3] is None  # dict was coerced to None


def test_flush_static_dict_eta_stored_as_formatted_string(tmp_db: Path):
    """ETA arriving as {Month,Day,Hour,Minute} dict must be formatted, not rejected."""
    pending = [
        ("static", 366002002, "2024-06-01T00:00:00Z", "MATSONIA",
         None, 71,
         "HNL",
         {"Month": 4, "Day": 20, "Hour": 8, "Minute": 0}),
    ]
    flush_batch(pending, tmp_db, log)

    with sqlite3.connect(tmp_db) as conn:
        # A position row must exist first for update_static_data to find; here
        # we just verify the vessel upserted cleanly (update_static_data is a
        # no-op when there is no recent observation, which is fine).
        row = conn.execute(
            "SELECT name, ais_type FROM vessels WHERE mmsi = 366002002"
        ).fetchone()

    assert row is not None
    assert row[0] == "MATSONIA"
    assert row[1] == 71


def test_flush_static_dict_eta_written_to_observation(tmp_db: Path):
    """ETA dict is formatted and written to the matching observation row."""
    mmsi = 366003003
    # Insert a recent observation first so update_static_data has a target.
    with db_mod.connect(tmp_db) as conn:
        conn.execute(
            "INSERT INTO ais_observations (mmsi, ts, lat, lon) VALUES (?, datetime('now'), 21.3, -158.0)",
            (mmsi,),
        )

    pending = [
        ("static", mmsi, "2024-06-01T00:00:00Z", "LURLINE",
         None, 71, "HNL",
         {"Month": 6, "Day": 1, "Hour": 10, "Minute": 30}),
    ]
    flush_batch(pending, tmp_db, log)

    with sqlite3.connect(tmp_db) as conn:
        row = conn.execute(
            "SELECT eta_reported FROM ais_observations WHERE mmsi = ?", (mmsi,)
        ).fetchone()

    assert row is not None
    assert row[0] == "06-01T10:30Z"


def test_flush_static_zero_eta_stored_as_none(tmp_db: Path):
    """All-zero ETA dict (AIS 'not set') must be stored as NULL, not '00-00T00:00Z'."""
    mmsi = 366004004
    with db_mod.connect(tmp_db) as conn:
        conn.execute(
            "INSERT INTO ais_observations (mmsi, ts, lat, lon) VALUES (?, datetime('now'), 21.3, -158.0)",
            (mmsi,),
        )

    pending = [
        ("static", mmsi, "2024-06-01T00:00:00Z", "GEORGE III",
         None, 71, "HNL",
         {"Month": 0, "Day": 0, "Hour": 0, "Minute": 0}),
    ]
    flush_batch(pending, tmp_db, log)

    with sqlite3.connect(tmp_db) as conn:
        row = conn.execute(
            "SELECT eta_reported FROM ais_observations WHERE mmsi = ?", (mmsi,)
        ).fetchone()

    assert row is not None
    assert row[0] is None


# ---------------------------------------------------------------------------
# _stream — reconnect on disconnect
# ---------------------------------------------------------------------------


def _make_canned_position_msg(mmsi: int = 366123456) -> str:
    return json.dumps({
        "MessageType": "PositionReport",
        "MetaData": {
            "MMSI": mmsi,
            "ShipName": "MATSON NAVIGATOR",
            "latitude": 21.3,
            "longitude": -158.1,
            "time_utc": "2024-01-01T00:00:00Z",
        },
        "Message": {
            "PositionReport": {
                "Sog": 14.2,
                "Cog": 95.0,
                "NavigationalStatus": 0,
            }
        },
    })


def test_reconnect_fires_on_disconnect(tmp_db: Path):
    """_stream must reconnect after an OSError/disconnect."""

    connect_calls: list[int] = []

    async def run():
        stop = asyncio.Event()
        call_num = 0

        def fake_connect(url, **kwargs):
            nonlocal call_num
            call_num += 1
            n = call_num

            class FakeWS:
                async def send(self, _data: str) -> None:
                    connect_calls.append(n)
                    if n >= 2:
                        # Second connection established — signal clean shutdown
                        stop.set()

                async def recv(self) -> str:
                    if n == 1:
                        # Simulate server-side disconnect immediately after subscribe
                        raise OSError("simulated disconnect")
                    # Second connection: block until stop is set
                    await asyncio.sleep(10)
                    return ""  # unreachable

                async def __aenter__(self):
                    return self

                async def __aexit__(self, *args):
                    return False

            return FakeWS()

        with patch("awareness.ingest_ais.websockets.connect", side_effect=fake_connect):
            try:
                await asyncio.wait_for(
                    _stream(_cfg(), tmp_db, log, stop),
                    timeout=6.0,  # backoff starts at 1s; 6s is safe headroom
                )
            except asyncio.TimeoutError:
                pytest.fail("_stream did not reconnect within timeout")

    asyncio.run(run())
    assert len(connect_calls) >= 2, (
        f"Expected at least 2 connection attempts, got {len(connect_calls)}"
    )


def test_stream_writes_position_to_db(tmp_db: Path):
    """Messages delivered over the fake WS end up in ais_observations."""

    msg = _make_canned_position_msg(mmsi=366999111)

    async def run():
        stop = asyncio.Event()
        call_num = 0

        def fake_connect(url, **kwargs):
            nonlocal call_num
            call_num += 1

            msgs = iter([msg])

            class FakeWS:
                async def send(self, _data: str) -> None:
                    pass

                async def recv(self) -> str:
                    try:
                        return next(msgs)
                    except StopIteration:
                        # No more messages — signal stop and block
                        stop.set()
                        await asyncio.sleep(10)
                        return ""

                async def __aenter__(self):
                    return self

                async def __aexit__(self, *args):
                    return False

            return FakeWS()

        with patch("awareness.ingest_ais.websockets.connect", side_effect=fake_connect):
            try:
                await asyncio.wait_for(_stream(_cfg(), tmp_db, log, stop), timeout=6.0)
            except asyncio.TimeoutError:
                pytest.fail("_stream timed out before flushing")

    asyncio.run(run())

    with sqlite3.connect(tmp_db) as conn:
        row = conn.execute(
            "SELECT mmsi, lat, lon, sog FROM ais_observations WHERE mmsi = 366999111"
        ).fetchone()

    assert row is not None
    assert row[0] == 366999111
    assert row[1] == pytest.approx(21.3)
    assert row[2] == pytest.approx(-158.1)
    assert row[3] == pytest.approx(14.2)


# ---------------------------------------------------------------------------
# BoundingBox config parsing and validation
# ---------------------------------------------------------------------------


def _bbox_cfg(min_lat=20.3, max_lat=22.0, min_lon=-159.0, max_lon=-157.0) -> cfg_mod.Config:
    return cfg_mod.Config({
        "aisstream_api_key": "abcdefghijklmnop",
        "oahu_bbox": {
            "min_lat": min_lat, "max_lat": max_lat,
            "min_lon": min_lon, "max_lon": max_lon,
        },
    })


def test_bbox_parsed_into_namedtuple():
    cfg = _bbox_cfg()
    bb = cfg.oahu_bbox
    assert bb.min_lat == pytest.approx(20.3)
    assert bb.max_lat == pytest.approx(22.0)
    assert bb.min_lon == pytest.approx(-159.0)
    assert bb.max_lon == pytest.approx(-157.0)


def test_bbox_missing_key_raises():
    with pytest.raises(ValueError, match="missing required keys"):
        cfg_mod.Config({"oahu_bbox": {"min_lat": 20.3, "max_lat": 22.0, "min_lon": -159.0}})


def test_bbox_inverted_lat_raises():
    with pytest.raises(ValueError, match="min_lat"):
        _bbox_cfg(min_lat=22.0, max_lat=20.3)


def test_bbox_inverted_lon_raises():
    with pytest.raises(ValueError, match="min_lon"):
        _bbox_cfg(min_lon=-157.0, max_lon=-159.0)


def test_bbox_equal_lat_raises():
    with pytest.raises(ValueError, match="min_lat"):
        _bbox_cfg(min_lat=21.0, max_lat=21.0)


# ---------------------------------------------------------------------------
# Subscription payload — BoundingBoxes corner ordering
# ---------------------------------------------------------------------------


def test_subscription_bounding_boxes_structure():
    """BoundingBoxes must be [[[sw_lat, sw_lon], [ne_lat, ne_lon]]] — lat first."""
    cfg = _bbox_cfg(min_lat=20.3, max_lat=22.0, min_lon=-159.0, max_lon=-157.0)
    sub = _build_subscription(cfg)

    assert "BoundingBoxes" in sub
    boxes = sub["BoundingBoxes"]
    assert len(boxes) == 1, "exactly one bounding box"
    box = boxes[0]
    assert len(box) == 2, "sw and ne corners"
    sw, ne = box
    assert sw == [20.3, -159.0], f"SW corner should be [min_lat, min_lon], got {sw}"
    assert ne == [22.0, -157.0], f"NE corner should be [max_lat, max_lon], got {ne}"


def test_subscription_filter_message_types():
    sub = _build_subscription(_bbox_cfg())
    assert sub["FilterMessageTypes"] == ["PositionReport", "ShipStaticData"]


def test_subscription_api_key_present():
    sub = _build_subscription(_bbox_cfg())
    assert sub["APIKey"] == "abcdefghijklmnop"


# ---------------------------------------------------------------------------
# Key redaction
# ---------------------------------------------------------------------------


def test_redact_key_long():
    assert _redact_key("abcdefghijklmnop") == "abcd...mnop"


def test_redact_key_short():
    assert _redact_key("short") == "****"


def test_redact_key_exactly_eight():
    # 8 chars: not >= 9, so masked
    assert _redact_key("12345678") == "****"


def test_redact_key_nine_chars():
    assert _redact_key("123456789") == "1234...6789"


# ---------------------------------------------------------------------------
# _parse_ais_timestamp — Go-style time_utc normalization
# ---------------------------------------------------------------------------


def test_parse_ais_timestamp_go_format():
    """Go runtime format with nanoseconds and timezone suffix is normalized correctly."""
    result = _parse_ais_timestamp("2026-04-13 19:39:24.123456789 +0000 UTC")
    assert result == "2026-04-13 19:39:24"


def test_parse_ais_timestamp_iso_t_format():
    """Standard ISO-8601 with T separator and Z suffix is also handled."""
    result = _parse_ais_timestamp("2024-01-01T00:00:00Z")
    assert result == "2024-01-01 00:00:00"


def test_parse_ais_timestamp_empty_returns_wallclock():
    """Empty string falls back to a valid wall-clock string."""
    result = _parse_ais_timestamp("")
    # Must match YYYY-MM-DD HH:MM:SS
    assert len(result) == 19
    assert result[4] == "-" and result[7] == "-" and result[10] == " "


# ---------------------------------------------------------------------------
# Regression: Go-style time_utc stored as SQLite-parseable ts
# ---------------------------------------------------------------------------


def test_go_timestamp_sqlite_datetime_parseable(tmp_db: Path):
    """PositionReport with a Go-style time_utc must produce a ts that SQLite's
    datetime() function can parse — i.e. SELECT datetime(ts) must be non-NULL."""
    go_ts = "2026-04-13 19:39:24.123456789 +0000 UTC"
    msg = {
        "MetaData": {
            "MMSI": 777888999,
            "ShipName": "MATSON TEST",
            "latitude": 21.3,
            "longitude": -158.0,
            "time_utc": go_ts,
        },
        "Message": {
            "PositionReport": {"Sog": 10.0, "Cog": 90.0}
        },
    }
    pending = [_parse_position_report(msg)]
    flush_batch(pending, tmp_db, log)

    with sqlite3.connect(tmp_db) as conn:
        result = conn.execute(
            "SELECT datetime(ts) FROM ais_observations WHERE mmsi = 777888999"
        ).fetchone()

    assert result is not None, "No row inserted"
    assert result[0] not in (None, ""), (
        f"datetime(ts) returned {result[0]!r} — ts is not SQLite-parseable. "
        "The Go-style timestamp was not normalized before storage."
    )
