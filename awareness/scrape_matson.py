"""Scraper for Matson's Hawaii vessel schedule.
Parses the WESTBOUND section of the Matson Hawaii PDF.
"""

import io
import logging
import re
from datetime import datetime, timezone
from typing import List, Dict, Any

import httpx
import pdfplumber
from . import db

SCHEDULE_URL = "https://fss.matson.com/fss/reports/haw.pdf"
LOG_PATH = db.APP_SUPPORT / "ingest.log"

def setup_logging():
    logger = logging.getLogger("awareness.scrape_matson")
    if not logger.handlers:
        logger.setLevel(logging.INFO)
        fh = logging.FileHandler(LOG_PATH)
        fh.setFormatter(logging.Formatter("%(asctime)s %(levelname)s %(message)s"))
        logger.addHandler(fh)
        sh = logging.StreamHandler()
        sh.setFormatter(logging.Formatter("%(asctime)s %(levelname)s %(message)s"))
        logger.addHandler(sh)
    return logger

def parse_schedule_pdf(pdf_data: bytes) -> List[Dict[str, Any]]:
    results = []
    with pdfplumber.open(io.BytesIO(pdf_data)) as pdf:
        for page in pdf.pages:
            text = page.extract_text()
            if not text or "WESTBOUND" not in text:
                continue
            
            lines = text.split('\n')
            wb_idx = -1
            for i, line in enumerate(lines):
                if "WESTBOUND" in line:
                    wb_idx = i
                    break
            
            if wb_idx == -1 or len(lines) < wb_idx + 3:
                continue
                
            raw_vessels = lines[wb_idx + 1].split()
            voyages = lines[wb_idx + 2].split()
            
            # Fix vessel names with spaces
            vessels = []
            skip = 0
            for i, v in enumerate(raw_vessels):
                if skip > 0:
                    skip -= 1
                    continue
                if v == "DANIEL" and i+2 < len(raw_vessels) and raw_vessels[i+2] == "INOUYE":
                    vessels.append("DANIEL K. INOUYE")
                    skip = 2
                elif v == "KAIMANA" and i+1 < len(raw_vessels) and raw_vessels[i+1] == "HILA":
                    vessels.append("KAIMANA HILA")
                    skip = 1
                elif v == "RJ" and i+1 < len(raw_vessels) and raw_vessels[i+1] == "PFEIFFER":
                    vessels.append("RJ PFEIFFER")
                    skip = 1
                elif v == "MATSON" and i+1 < len(raw_vessels) and raw_vessels[i+1] == "OAHU":
                    vessels.append("MATSON OAHU")
                    skip = 1
                else:
                    vessels.append(v)
            
            count = min(len(vessels), len(voyages))
            port_map = {"TACOMA": "SEA", "OAKLAND": "OAK", "LOS ANGELES": "LGB"}
            dep_data = {code: [] for code in ["SEA", "OAK", "LGB"]}
            arr_hnl = []
            
            current_mode = None
            for line in lines[wb_idx + 3:]:
                u_line = line.upper()
                if "DEPARTS" in u_line: current_mode = "DEPARTS"; continue
                if "ARRIVES" in u_line: current_mode = "ARRIVES"; continue
                
                parts = line.split()
                if not parts: continue
                
                if current_mode == "DEPARTS":
                    if u_line.startswith("LOS ANGELES"):
                        dep_data["LGB"] = parts[2:]
                    elif u_line.startswith("TACOMA"):
                        dep_data["SEA"] = parts[1:]
                    elif u_line.startswith("OAKLAND"):
                        dep_data["OAK"] = parts[1:]
                elif current_mode == "ARRIVES" and u_line.startswith("HONOLULU"):
                    arr_hnl = parts[1:]

            scraped_at = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S")
            for i in range(count):
                vessel = vessels[i]
                voyage = voyages[i]
                arrival = arr_hnl[i] if i < len(arr_hnl) else None
                if not arrival or arrival == "--": continue
                
                for code, dates in dep_data.items():
                    departure = dates[i] if i < len(dates) else None
                    if departure and departure not in ("--", "X", ""):
                        # Matson uses 'Day MM/DD' or just 'Day' and 'MM/DD' split.
                        # Usually parts[1:] gives ['Wed', '04/01', 'Tue', '04/07'...]
                        # If departure is 'Wed', we might need to peek ahead.
                        # But simpler: just use the raw string for now as requested.
                        results.append({
                            "carrier": "matson",
                            "voyage_id": voyage,
                            "vessel_name": vessel,
                            "origin": code,
                            "destination": "HNL",
                            "scheduled_departure": departure,
                            "scheduled_arrival": arrival,
                            "scraped_at": scraped_at
                        })
    return results

def upsert_schedules(schedules: List[Dict[str, Any]]):
    with db.connect() as conn:
        conn.executemany("""
            INSERT INTO schedules (
                carrier, voyage_id, vessel_name, origin, destination,
                scheduled_departure, scheduled_arrival, scraped_at
            ) VALUES (
                :carrier, :voyage_id, :vessel_name, :origin, :destination,
                :scheduled_departure, :scheduled_arrival, :scraped_at
            )
            ON CONFLICT(carrier, voyage_id) DO UPDATE SET
                vessel_name = excluded.vessel_name,
                origin = excluded.origin,
                destination = excluded.destination,
                scheduled_departure = excluded.scheduled_departure,
                scheduled_arrival = excluded.scheduled_arrival,
                scraped_at = excluded.scraped_at
        """, schedules)

def run():
    logger = setup_logging()
    logger.info("Starting Matson schedule scrape...")
    try:
        headers = {"User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"}
        with httpx.Client(follow_redirects=True, headers=headers) as client:
            resp = client.get(SCHEDULE_URL)
            resp.raise_for_status()
            pdf_data = resp.content
            
        schedules = parse_schedule_pdf(pdf_data)
        if not schedules:
            logger.error("No schedule rows extracted from PDF. Check for layout changes.")
            return
            
        upsert_schedules(schedules)
        logger.info(f"Successfully scraped and upserted {len(schedules)} Matson voyages.")
    except Exception as e:
        logger.error(f"Matson scrape failed: {e}")
        raise

if __name__ == "__main__":
    run()
