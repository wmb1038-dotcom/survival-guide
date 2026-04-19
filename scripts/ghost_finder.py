import sqlite3
import os
from datetime import datetime, timedelta, timezone
from pathlib import Path
from rich.console import Console
from rich.table import Table
from rich.panel import Panel
from rich.text import Text

# --- Configuration ---
APP_SUPPORT = Path.home() / "Library" / "Application Support" / "awareness"
DB_PATH = APP_SUPPORT / "survival_maritime.db"
HST_OFFSET = -10 # Hawaii Standard Time is UTC-10

console = Console()

def get_now_hst():
    """Get current time in Hawaii Standard Time."""
    return datetime.now(timezone.utc) + timedelta(hours=HST_OFFSET)

def init_live_table():
    """Ensure the ais_live_pings table exists for the script to run."""
    with sqlite3.connect(DB_PATH) as conn:
        conn.execute("""
            CREATE TABLE IF NOT EXISTS ais_live_pings (
                mmsi TEXT PRIMARY KEY,
                vessel_name TEXT,
                lat REAL,
                lon REAL,
                timestamp TEXT
            )
        """)

def detect_anomalies():
    if not DB_PATH.exists():
        console.print(f"[red]Error: Database not found at {DB_PATH}[/red]")
        return

    init_live_table()
    now_hst = get_now_hst()
    lookahead_limit = now_hst + timedelta(hours=12)
    ping_expiry_limit = datetime.now(timezone.utc) - timedelta(hours=4)

    # 1. Search for upcoming arrivals
    # Note: ETA in port_schedules is stored as TEXT from the website (e.g. "2025-01-23 04:30:00")
    # We match by vessel_name since schedules didn't include MMSI
    query = """
        SELECT s.vessel_name, s.port_name, s.pier_number, s.eta, s.last_port, 
               p.mmsi, p.timestamp as last_ping, p.lat, p.lon
        FROM port_schedules s
        LEFT JOIN ais_live_pings p ON UPPER(s.vessel_name) = UPPER(p.vessel_name)
        WHERE s.eta != 'Unknown'
    """
    
    with sqlite3.connect(DB_PATH) as conn:
        conn.row_factory = sqlite3.Row
        rows = conn.execute(query).fetchall()

    anomalies = []
    
    for row in rows:
        try:
            # Parse the ETA string (assuming YYYY-MM-DD HH:MM:SS)
            eta_dt = datetime.strptime(row['eta'], "%Y-%m-%d %H:%M:%S")
            # Convert to a naive datetime for comparison or handle as HST
            # For simplicity, we compare strings or parse to naive
            
            if not (now_hst <= eta_dt <= lookahead_limit):
                continue

            vessel_type = "General"
            pier = row['pier_number'].upper()
            port = row['port_name'].upper()
            
            # 3. Categorize Cargo
            if "51" in pier or "52" in pier:
                vessel_type = "Food"
            elif "KALAELOA" in port or "BP" in pier:
                vessel_type = "Fuel"

            # 2. Validate AIS Activity
            is_ghost = False
            last_ping_str = "No Data"
            
            if row['last_ping']:
                last_ping_dt = datetime.fromisoformat(row['last_ping'])
                if last_ping_dt < ping_expiry_limit:
                    is_ghost = True
                last_ping_str = last_ping_dt.strftime("%H:%M HST")
            else:
                is_ghost = True

            if is_ghost:
                # 4. Escalate and Generate Web-Check command
                concern = "LOW"
                if vessel_type in ["Food", "Fuel"]:
                    concern = "ELEVATED"
                
                gemini_cmd = f"gemini -p \"Find last known location and status for vessel '{row['vessel_name']}'\""
                
                anomalies.append({
                    "name": row['vessel_name'],
                    "type": vessel_type,
                    "eta": row['eta'],
                    "last_ping": last_ping_str,
                    "concern": concern,
                    "cmd": gemini_cmd,
                    "lat": row['lat'],
                    "lon": row['lon']
                })
        except Exception:
            continue

    display_report(anomalies)

def display_report(anomalies):
    title = Text("⚓ MARITIME ANOMALY REPORT: OAHU", style="bold white on blue")
    console.print(Panel(title, expand=False))
    
    if not anomalies:
        console.print("[green]✓ No ghost vessels detected. All scheduled arrivals have active AIS pings.[/green]")
        return

    table = Table(show_header=True, header_style="bold magenta")
    table.add_column("Vessel Name")
    table.add_column("Type")
    table.add_column("Scheduled ETA")
    table.add_column("Last Ping")
    table.add_column("Concern Level")

    for a in anomalies:
        color = "yellow"
        if a['concern'] == "ELEVATED":
            color = "red"
        
        table.add_row(
            a['name'],
            a['type'],
            a['eta'],
            f"[{color}]{a['last_ping']}[/{color}]",
            f"[{color}]{a['concern']}[/{color}]"
        )

    console.print(table)

    console.print("\n[bold cyan]WEB-CHECK COMMANDS FOR GHOST VESSELS:[/bold cyan]")
    for a in anomalies:
        console.print(f"• {a['name']}: [dim]{a['cmd']}[/dim]")

if __name__ == "__main__":
    detect_anomalies()
