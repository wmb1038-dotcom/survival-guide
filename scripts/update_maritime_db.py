import sqlite3
import json
from datetime import datetime, timezone
from pathlib import Path

# --- Configuration ---
DB_NAME = "survival.db"
# Ensure we save it in the app's data directory for persistence
APP_SUPPORT = Path.home() / "Library" / "Application Support" / "awareness"
DB_PATH = APP_SUPPORT / DB_NAME

# Sample JSON data from the previous fetch (vessels arriving at Honolulu/Kalaeloa)
# In a real workflow, this would be passed in or read from a file.
MARITIME_DATA = [
    {"vessel_name": "NALE", "mmsi": "367000001", "pier": "29", "last_port": "SEA", "predicted_cargo": "General Cargo", "survival_priority": 2},
    {"vessel_name": "HALEAKALA", "mmsi": "367000002", "pier": "53", "last_port": "SEA", "predicted_cargo": "General Cargo", "survival_priority": 2},
    {"vessel_name": "MAUNA LOA", "mmsi": "367000003", "pier": "51C", "last_port": "SEA", "predicted_cargo": "Consumer Goods/Food", "survival_priority": 1},
    {"vessel_name": "MAHIMAHI", "mmsi": "367000004", "pier": "52", "last_port": "SEA", "predicted_cargo": "Consumer Goods/Food", "survival_priority": 1},
    {"vessel_name": "GEORGE III", "mmsi": "367000005", "pier": "51A", "last_port": "SEA", "predicted_cargo": "Consumer Goods/Food", "survival_priority": 1},
    {"vessel_name": "Tecumseh", "mmsi": "367000006", "pier": "BP-5 (Fuel Line)", "last_port": "SEA", "predicted_cargo": "Fuel/Petroleum", "survival_priority": 1},
    {"vessel_name": "NAVE OHANA", "mmsi": "367000007", "pier": "BP-5", "last_port": "SFO", "predicted_cargo": "Fuel/Petroleum", "survival_priority": 1}
]

def init_db():
    """Create the database and table if they don't exist."""
    APP_SUPPORT.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    
    # Create the requested schema
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS vessels (
            mmsi TEXT PRIMARY KEY,
            name TEXT,
            cargo_type TEXT,
            survival_score INTEGER,
            last_updated DATETIME
        )
    """)
    conn.commit()
    return conn

def update_vessels(conn, vessel_list):
    """Insert or Replace vessel data into the database."""
    cursor = conn.cursor()
    now = datetime.now(timezone.utc).isoformat()
    
    updated_count = 0
    for v in vessel_list:
        # Skip if MMSI is missing as it's our Primary Key
        if not v.get("mmsi"):
            continue
            
        data = (
            v["mmsi"],
            v["vessel_name"],
            v["predicted_cargo"],
            v["survival_priority"],
            now
        )
        
        cursor.execute("""
            INSERT OR REPLACE INTO vessels (mmsi, name, cargo_type, survival_score, last_updated)
            VALUES (?, ?, ?, ?, ?)
        """, data)
        updated_count += 1
        
    conn.commit()
    print(f"✓ Successfully updated {updated_count} vessels in {DB_PATH}")

if __name__ == "__main__":
    connection = init_db()
    try:
        update_vessels(connection, MARITIME_DATA)
    finally:
        connection.close()
