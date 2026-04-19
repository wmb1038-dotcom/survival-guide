import sqlite3
import logging
from datetime import datetime, timezone
from pathlib import Path

import httpx
from bs4 import BeautifulSoup

# --- Constants & Paths ---
APP_SUPPORT = Path.home() / "Library" / "Application Support" / "awareness"
DB_PATH = APP_SUPPORT / "survival_maritime.db"
LOG_PATH = APP_SUPPORT / "ingest.log"

# Hawaii.PortCall.com URL
BASE_URL = "https://hawaii.portcall.com/"

def setup_logging():
    """Configure logging to both file and console."""
    APP_SUPPORT.mkdir(parents=True, exist_ok=True)
    logger = logging.getLogger("portcall_scraper")
    logger.setLevel(logging.INFO)
    
    if not logger.handlers:
        fh = logging.FileHandler(LOG_PATH)
        fh.setFormatter(logging.Formatter("%(asctime)s %(levelname)s: %(message)s"))
        logger.addHandler(fh)
        
        ch = logging.StreamHandler()
        ch.setFormatter(logging.Formatter("%(levelname)s: %(message)s"))
        logger.addHandler(ch)
    return logger

def init_db():
    """Initialize the SQLite database and create the port_schedules table."""
    DB_PATH.parent.mkdir(parents=True, exist_ok=True)
    with sqlite3.connect(DB_PATH) as conn:
        conn.execute("""
            CREATE TABLE IF NOT EXISTS port_schedules (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                port_name TEXT NOT NULL,
                vessel_name TEXT NOT NULL,
                pier_number TEXT,
                eta TEXT,
                last_port TEXT,
                scraped_at TEXT NOT NULL,
                UNIQUE(port_name, vessel_name, eta)
            )
        """)
    return DB_PATH

def scrape_schedules(logger: logging.Logger):
    """Scrape Honolulu and Kalaeloa schedules from the HTML page."""
    logger.info(f"Scraping schedules from {BASE_URL}...")
    
    headers = {
        "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"
    }
    
    try:
        # Use httpx with timeout as requested
        with httpx.Client(timeout=20.0, follow_redirects=True, headers=headers) as client:
            resp = client.get(BASE_URL)
            resp.raise_for_status()
            
        soup = BeautifulSoup(resp.text, 'html.parser')
        
        # Look for the traffic schedule table
        # We'll search for any table that contains common header keywords
        tables = soup.find_all('table')
        target_table = None
        for table in tables:
            headers_text = table.get_text().upper()
            if "VESSEL" in headers_text and "PIER" in headers_text and "ETA" in headers_text:
                target_table = table
                break
        
        if not target_table:
            # Fallback: search for specific table ID if known
            target_table = soup.find('table', {'id': 'traffic_schedule'})
            
        if not target_table:
            logger.error("Could not find traffic schedule table on page.")
            return []

        rows = target_table.find_all('tr')
        extracted_data = []
        scraped_at = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S")
        
        target_ports = ["HONOLULU", "KALAELOA BARBERS POINT"]

        for row in rows:
            cells = row.find_all(['td', 'th'])
            if len(cells) < 6:
                continue
            
            # Heuristic mapping based on common PortCall layout
            # Col 0: Port, Col 1: Vessel, Col 3: Pier, Col 5: ETA, Col 6: Last Port
            # We will search for port names in all cells first
            row_text = row.get_text().upper()
            matched_port = None
            for p in target_ports:
                if p in row_text:
                    matched_port = p.title()
                    break
            
            if not matched_port:
                continue
                
            # Try to be more specific with cell extraction
            # This is fragile but BeautifulSoup is requested
            texts = [c.get_text(strip=True) for c in cells]
            
            # Simple heuristic: PortCall tables often have Vessel in Col 1 or 2
            # Let's find the cell with 'HONOLULU' or 'KALAELOA' and assume it's the port cell
            port_idx = -1
            for i, t in enumerate(texts):
                if any(p in t.upper() for p in target_ports):
                    port_idx = i
                    break
            
            if port_idx == -1: continue
            
            # Based on standard layout:
            vessel_name = texts[port_idx + 1] if port_idx + 1 < len(texts) else "Unknown"
            pier        = texts[port_idx + 3] if port_idx + 3 < len(texts) else "Unknown"
            eta         = texts[port_idx + 5] if port_idx + 5 < len(texts) else "Unknown"
            last_port   = texts[port_idx + 6] if port_idx + 6 < len(texts) else "Unknown"

            extracted_data.append({
                "port_name": matched_port,
                "vessel_name": vessel_name,
                "pier_number": pier,
                "eta": eta,
                "last_port": last_port,
                "scraped_at": scraped_at
            })
            
        logger.info(f"Extracted {len(extracted_data)} schedule entries.")
        return extracted_data

    except httpx.ConnectTimeout:
        logger.error(f"Connection timed out while accessing {BASE_URL}")
    except httpx.HTTPStatusError as e:
        logger.error(f"HTTP error occurred: {e.response.status_code}")
    except Exception as e:
        logger.error(f"An unexpected error occurred: {e}")
    
    return []

def save_to_db(data, logger: logging.Logger):
    """Save extracted data to SQLite."""
    if not data:
        return
        
    try:
        with sqlite3.connect(DB_PATH) as conn:
            conn.executemany("""
                INSERT OR REPLACE INTO port_schedules 
                (port_name, vessel_name, pier_number, eta, last_port, scraped_at)
                VALUES (:port_name, :vessel_name, :pier_number, :eta, :last_port, :scraped_at)
            """, data)
        logger.info(f"Successfully saved {len(data)} records to {DB_PATH}")
    except Exception as e:
        logger.error(f"Failed to save data to database: {e}")

def main():
    logger = setup_logging()
    init_db()
    
    data = scrape_schedules(logger)
    save_to_db(data, logger)

if __name__ == "__main__":
    main()
