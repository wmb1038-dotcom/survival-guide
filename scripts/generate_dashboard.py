#!/usr/bin/env python3
"""
Unified Layered Map Dashboard.
Combines Water Sources and Maritime Traffic into a single interactive Folium map.
"""

import json
import sqlite3
from datetime import datetime, timezone
from pathlib import Path

import folium
from awareness import config, db

# --- Constants & Paths ---
APP_SUPPORT = db.APP_SUPPORT
DASHBOARD_PATH = Path("app_data/dashboard.html")
WATER_SOURCES_JSON = APP_SUPPORT / "water_sources.json"

# --- Helper: Water Source Styles ---
WATER_STYLES = {
    "Well":            {"color": "#80CC66", "icon": "tint"},
    "Spring":          {"color": "#00FFFF", "icon": "drop"},
    "Stream / River":  {"color": "#0000FF", "icon": "water"},
    "Lake / Pond":     {"color": "#3380E6", "icon": "drop"},
    "Rain Collection": {"color": "#66B3FF", "icon": "cloud-download"},
    "Municipal Tap":   {"color": "#008080", "icon": "faucet"},
    "Other":           {"color": "#808080", "icon": "info-sign"},
}

# --- Helper: AIS Type Mapping ---
def get_ais_type_name(code):
    """Convert AIS numeric type codes to human-readable names."""
    if not code:
        return "Unknown"
    
    code = int(code)
    # Cargo (70-79)
    if 70 <= code <= 79:
        return f"Cargo ({code})"
    # Tanker (80-89)
    if 80 <= code <= 89:
        return f"Tanker ({code})"
    # Passenger (60-69)
    if 60 <= code <= 69:
        return f"Passenger ({code})"
    # Special Category (50-59)
    if code == 50: return "Pilot Vessel (50)"
    if code == 51: return "Search and Rescue (51)"
    if code == 52: return "Tug (52)"
    if code == 53: return "Port Tender (53)"
    if code == 54: return "Anti-Pollution (54)"
    if code == 55: return "Law Enforcement (55)"
    if code == 58: return "Medical Transport (58)"
    if 50 <= code <= 59:
        return f"Special Category ({code})"
    
    # Other Common
    if 30 == code: return "Fishing (30)"
    if 31 == code: return "Towing (31)"
    if 32 == code: return "Dredging (32)"
    if 33 == code: return "Diving Ops (33)"
    if 35 == code: return "Military (35)"
    if 36 == code: return "Sailing (36)"
    if 37 == code: return "Pleasure Craft (37)"
    
    return f"Type {code}"

def get_water_sources():
    if WATER_SOURCES_JSON.exists():
        try:
            with open(WATER_SOURCES_JSON, "r") as f:
                return json.load(f)
        except Exception:
            pass
    return [
        {
            "name": "Waikiki Well (Sample)",
            "type": "Well",
            "latitude": 21.28,
            "longitude": -157.83,
            "reliability": "Year-Round",
            "treatmentRequired": True,
            "notes": "Sample data — not a real survival source."
        },
        {
            "name": "Manoa Stream (Sample)",
            "type": "Stream / River",
            "latitude": 21.31,
            "longitude": -157.81,
            "reliability": "Seasonal",
            "treatmentRequired": True,
            "notes": "Check for leptospirosis."
        }
    ]

def get_maritime_traffic():
    if not db.DB_PATH.exists():
        return []
    
    query = """
    SELECT 
        v.name,
        v.operator,
        v.ais_type,
        o.lat,
        o.lon,
        o.sog,
        o.cog,
        o.ts
    FROM vessels v
    JOIN (
        SELECT mmsi, lat, lon, sog, cog, MAX(ts) as ts
        FROM ais_observations
        WHERE ts >= datetime('now', '-60 minutes')
          AND lat IS NOT NULL 
          AND lon IS NOT NULL
        GROUP BY mmsi
    ) o ON v.mmsi = o.mmsi
    """
    try:
        with db.connect() as conn:
            rows = conn.execute(query).fetchall()
            print(f"DEBUG: Found {len(rows)} maritime vessels with positions in last 60 minutes.")
            return rows
    except Exception as e:
        print(f"Maritime query error: {e}")
        return []

def generate():
    cfg = config.load()
    bb = cfg.oahu_bbox
    center_lat = (bb.min_lat + bb.max_lat) / 2
    center_lon = (bb.min_lon + bb.max_lon) / 2
    
    # Create map with multiple tile layers
    m = folium.Map(
        location=[center_lat, center_lon],
        zoom_start=11,
        tiles=None
    )
    
    folium.TileLayer("cartodbpositron", name="Light Mode (Standard)").add_to(m)
    folium.TileLayer("cartodbdark_matter", name="Dark Mode").add_to(m)
    folium.TileLayer(
        tiles="https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}",
        attr="Esri",
        name="Satellite"
    ).add_to(m)

    # 2. Layer 1: Water Sources
    fg_water = folium.FeatureGroup(name="Water Sources")
    sources = get_water_sources()
    for s in sources:
        style = WATER_STYLES.get(s.get("type"), WATER_STYLES["Other"])
        popup_text = f"<b>{s.get('name')}</b><br>Type: {s.get('type')}<br>Reliability: {s.get('reliability')}"
        if s.get("treatmentRequired"):
            popup_text += "<br><span style='color:red;'>⚠ Treatment Required</span>"
        
        folium.Marker(
            location=[s["latitude"], s["longitude"]],
            popup=folium.Popup(popup_text, max_width=300),
            icon=folium.Icon(color="blue", icon=style["icon"]),
        ).add_to(fg_water)
    
    # 3. Layer 2: Maritime Traffic
    fg_maritime = folium.FeatureGroup(name="Maritime Traffic")
    vessels = get_maritime_traffic()
    
    op_colors = {
        "matson": "blue",
        "pasha": "orange",
        "tanker_unknown": "red",
        "cargo_unknown": "gray",
        "unknown": "gray"
    }
    
    now = datetime.now(timezone.utc)
    
    for v in vessels:
        color = op_colors.get(v["operator"], "gray")
        type_name = get_ais_type_name(v["ais_type"])
        
        try:
            ts_dt = datetime.strptime(v["ts"], "%Y-%m-%d %H:%M:%S").replace(tzinfo=timezone.utc)
            ago_min = int((now - ts_dt).total_seconds() / 60)
        except Exception:
            ago_min = "?"
            
        popup_text = (
            f"<b>{v['name'] or 'Unknown Vessel'}</b><br>"
            f"Operator: {v['operator'].title()}<br>"
            f"Ship Type: {type_name}<br>"
            f"Speed: {v['sog'] or 0} kn<br>"
            f"Course: {v['cog'] or 0}°<br>"
            f"Last seen: {ago_min} min ago"
        )
        
        folium.CircleMarker(
            location=[v["lat"], v["lon"]],
            radius=8,
            color=color,
            weight=2,
            fill=True,
            fill_color=color,
            fill_opacity=0.6,
            popup=folium.Popup(popup_text, max_width=250)
        ).add_to(fg_maritime)
        
    # 4. Finalise
    fg_water.add_to(m)
    fg_maritime.add_to(m)
    folium.LayerControl(collapsed=False).add_to(m)
    
    DASHBOARD_PATH.parent.mkdir(exist_ok=True)
    m.save(DASHBOARD_PATH)
    print(f"✓ Dashboard generated: {DASHBOARD_PATH.absolute()}")

if __name__ == "__main__":
    generate()
