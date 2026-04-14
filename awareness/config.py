"""Configuration loader for awareness.

Reads ~/Library/Application Support/awareness/config.toml.
Falls back to built-in defaults if the file is absent — the tool is usable
for local testing without a config file (API calls will simply be skipped).
"""

from __future__ import annotations

import tomllib
from pathlib import Path
from typing import Any, NamedTuple

CONFIG_PATH = Path.home() / "Library" / "Application Support" / "awareness" / "config.toml"


class BoundingBox(NamedTuple):
    min_lat: float
    max_lat: float
    min_lon: float
    max_lon: float


_DEFAULT_BBOX: dict[str, float] = {
    "min_lat": 21.2,
    "max_lat": 21.7,
    "min_lon": -158.3,
    "max_lon": -157.6,
}

_DEFAULTS: dict[str, Any] = {
    "aisstream_api_key": "",
    "oahu_bbox": _DEFAULT_BBOX,
    "poll_intervals": {
        "ais_reconnect": 30,      # seconds between WebSocket reconnect attempts
        "port_page": 300,         # seconds between schedule page fetches
        "congestion_page": 3600,  # seconds between SoCal congestion fetches
    },
}


def _parse_bbox(raw: Any) -> BoundingBox:
    """Parse and validate the [oahu_bbox] table into a BoundingBox.

    Raises ValueError with a descriptive message on any problem.
    """
    if not isinstance(raw, dict):
        raise ValueError(
            "oahu_bbox must be a TOML table with min_lat/max_lat/min_lon/max_lon keys, "
            f"got {type(raw).__name__}"
        )
    required = ("min_lat", "max_lat", "min_lon", "max_lon")
    missing = [k for k in required if k not in raw]
    if missing:
        raise ValueError(f"oahu_bbox is missing required keys: {missing}")
    try:
        bb = BoundingBox(
            min_lat=float(raw["min_lat"]),
            max_lat=float(raw["max_lat"]),
            min_lon=float(raw["min_lon"]),
            max_lon=float(raw["max_lon"]),
        )
    except (TypeError, ValueError) as exc:
        raise ValueError(f"oahu_bbox values must be numbers: {exc}") from exc
    if bb.min_lat >= bb.max_lat:
        raise ValueError(
            f"oahu_bbox: min_lat ({bb.min_lat}) must be less than max_lat ({bb.max_lat})"
        )
    if bb.min_lon >= bb.max_lon:
        raise ValueError(
            f"oahu_bbox: min_lon ({bb.min_lon}) must be less than max_lon ({bb.max_lon})"
        )
    return bb


class Config:
    def __init__(self, data: dict[str, Any]) -> None:
        merged = {**_DEFAULTS, **data}
        self.aisstream_api_key: str = merged["aisstream_api_key"]
        self.oahu_bbox: BoundingBox = _parse_bbox(merged["oahu_bbox"])
        self.poll_intervals: dict[str, int] = {
            **_DEFAULTS["poll_intervals"],
            **merged.get("poll_intervals", {}),
        }

    @property
    def key_set(self) -> bool:
        return bool(self.aisstream_api_key)

    def __repr__(self) -> str:
        preview = self.aisstream_api_key[:6] + "…" if self.key_set else "(not set)"
        return f"Config(key={preview}, bbox={self.oahu_bbox})"


def load(path: Path = CONFIG_PATH) -> Config:
    """Load config.toml; return defaults if the file does not exist."""
    if not path.exists():
        return Config({})
    with open(path, "rb") as fh:
        data = tomllib.load(fh)
    return Config(data)
