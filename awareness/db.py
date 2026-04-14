"""Thin SQLite wrapper for the awareness database."""

from __future__ import annotations

import contextlib
import sqlite3
from pathlib import Path

APP_SUPPORT = Path.home() / "Library" / "Application Support" / "awareness"
DB_PATH = APP_SUPPORT / "maritime.db"


def _schema_sql() -> str:
    return (Path(__file__).parent / "schema.sql").read_text()


def init(db_path: Path = DB_PATH) -> Path:
    """Create the DB directory and apply the schema. Safe to call repeatedly."""
    db_path.parent.mkdir(parents=True, exist_ok=True)
    with sqlite3.connect(db_path) as conn:
        conn.executescript(_schema_sql())
    return db_path


@contextlib.contextmanager
def connect(db_path: Path = DB_PATH):
    """Yield a sqlite3.Connection with FK enforcement and Row factory.

    Commits on clean exit; rolls back on exception.
    """
    db_path.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(db_path)
    conn.row_factory = sqlite3.Row
    try:
        conn.execute("PRAGMA foreign_keys = ON")
        yield conn
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()


def reset(db_path: Path = DB_PATH) -> Path:
    """Drop and recreate the database. For development only."""
    if db_path.exists():
        db_path.unlink()
    return init(db_path)
