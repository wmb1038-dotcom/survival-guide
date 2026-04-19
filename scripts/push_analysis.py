import httpx
import json

def push():
    data = {
      "TIMESTAMP": "Friday, April 17, 2026 | 9:55 PM HST",
      "CITY": "Makakilo",
      "STOPLIGHTS": {
        "WEATHER": {
          "status": "YELLOW",
          "label": "Weather Advisory",
          "hover_text": "• Small Craft Advisory: Trade winds building to 25kt.\n• High Surf: 8-12ft on North shores.\n• Impact: Fuel tanker berthing at Barbers Point delayed."
        },
        "GEOLOGICAL": {
          "status": "GREEN",
          "label": "Seismic/Tsunami",
          "hover_text": "• All Clear: No active tsunami threats.\n• Sensors: Only minor M1.2 activity near Pāhala.\n• Infrastructure: No risk to Oahu water/power."
        },
        "LOGISTICS": {
          "status": "YELLOW",
          "label": "Infrastructure",
          "hover_text": "• Roadwork: HECO utility work on Fort Barrette Rd.\n• H-1 Roving: Shoulder repairs near Makakilo exit.\n• Impact: Increased congestion at primary egress."
        },
        "RESOURCES": {
          "status": "YELLOW",
          "label": "Supply Chain",
          "hover_text": "• Gas Pulse: Honolulu avg at $5.65/gal.\n• Trend: +18% increase since March baseline.\n• Supply: Port operations normal but costs rising."
        }
      }
    }
    
    url = "http://localhost:8080/api/resilience"
    try:
        with httpx.Client(timeout=10.0) as client:
            r = client.post(url, json=data)
        if r.status_code == 204:
            print("✅ Success! Dashboard updated. Hover tooltips are now active.")
        else:
            print(f"❌ Server Error: {r.status_code}. Is the app running with 'Network Dashboard' ON?")
    except Exception as e:
        print(f"❌ Connection Error: {e}")

if __name__ == "__main__":
    push()
