"""Verify that db.init() is idempotent and all tables/indexes are created."""

from __future__ import annotations

import sqlite3
from pathlib import Path
from unittest.mock import patch

import pytest

import awareness.db as db_mod

EXPECTED_TABLES = {"vessels", "ais_observations", "schedules", "socal_congestion", "alerts"}
EXPECTED_INDEXES = {"idx_ais_mmsi_ts"}


def _introspect(path: Path) -> tuple[set[str], set[str]]:
    with sqlite3.connect(path) as conn:
        tables = {
            r[0]
            for r in conn.execute(
                "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'"
            )
        }
        indexes = {
            r[0]
            for r in conn.execute(
                "SELECT name FROM sqlite_master WHERE type='index' AND name NOT LIKE 'sqlite_%'"
            )
        }
    return tables, indexes


@pytest.fixture()
def tmp_db(tmp_path: Path):
    """Redirect db module globals to a throwaway temp directory."""
    tmp_file = tmp_path / "maritime.db"
    with (
        patch.object(db_mod, "APP_SUPPORT", tmp_path),
        patch.object(db_mod, "DB_PATH", tmp_file),
    ):
        yield tmp_file


def test_init_creates_all_tables(tmp_db: Path) -> None:
    db_mod.init(tmp_db)
    tables, _ = _introspect(tmp_db)
    assert tables == EXPECTED_TABLES


def test_init_creates_indexes(tmp_db: Path) -> None:
    db_mod.init(tmp_db)
    _, indexes = _introspect(tmp_db)
    assert EXPECTED_INDEXES <= indexes


def test_init_is_idempotent(tmp_db: Path) -> None:
    db_mod.init(tmp_db)
    db_mod.init(tmp_db)  # must not raise or corrupt
    tables, _ = _introspect(tmp_db)
    assert tables == EXPECTED_TABLES


def test_connect_yields_working_connection(tmp_db: Path) -> None:
    db_mod.init(tmp_db)
    with db_mod.connect(tmp_db) as conn:
        count = conn.execute("SELECT count(*) FROM vessels").fetchone()[0]
    assert count == 0


def test_reset_clears_rows_and_recreates_schema(tmp_db: Path) -> None:
    db_mod.init(tmp_db)
    with db_mod.connect(tmp_db) as conn:
        conn.execute(
            "INSERT INTO vessels (mmsi, name, first_seen, last_seen) "
            "VALUES (123456789, 'Maunalei', datetime('now'), datetime('now'))"
        )
    db_mod.reset(tmp_db)
    with db_mod.connect(tmp_db) as conn:
        count = conn.execute("SELECT count(*) FROM vessels").fetchone()[0]
    assert count == 0
    tables, _ = _introspect(tmp_db)
    assert tables == EXPECTED_TABLES
