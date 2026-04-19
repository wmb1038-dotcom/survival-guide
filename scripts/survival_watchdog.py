import json
import os
import subprocess
import sys
from datetime import datetime

def trigger_macos_alert(status, headline, action):
    """Triggers system-level alerts on macOS based on severity."""
    
    # 1. Sound Alert
    if status == 'RED':
        # Repeated 'Sosumi' or 'Ping' for urgency
        for _ in range(3):
            os.system('afplay /System/Library/Sounds/Sosumi.aiff')
    elif status == 'YELLOW':
        os.system('afplay /System/Library/Sounds/Tink.aiff')

    # 2. Visual Modal Alert via AppleScript
    # We use subprocess to safely handle quotes in the headline/action
    icon_type = "critical" if status == 'RED' else "caution"
    
    applescript = f'''
    display alert "{status}: {headline}" ¬
    message "{action}" ¬
    as {icon_type} ¬
    buttons {{"Understood"}} default button "Understood"
    '''
    
    try:
        subprocess.run(['osascript', '-e', applescript], check=True)
    except Exception as e:
        print(f"Error triggering AppleScript alert: {e}")

def main():
    # Read JSON from stdin (piped from Gemini CLI)
    try:
        input_data = sys.stdin.read()
        if not input_data.strip():
            print("No data received via pipe.")
            return

        # Attempt to find JSON block if Gemini returns conversational text
        if "{" in input_data:
            json_start = input_data.find("{")
            json_end = input_data.rfind("}") + 1
            data = json.loads(input_data[json_start:json_end])
        else:
            print("No valid JSON found in input.")
            return

        status = data.get('status', 'GREEN').upper()
        headline = data.get('headline', 'No Alert')
        action = data.get('survival_action', 'Continue monitoring.')

        print(f"[{datetime.now().strftime('%H:%M:%S')}] Current Status: {status}")
        
        if status in ['RED', 'YELLOW']:
            trigger_macos_alert(status, headline, action)
        else:
            print("System Clear. No alerts triggered.")

    except json.JSONDecodeError:
        print("Error: Could not parse JSON from Gemini output.")
    except Exception as e:
        print(f"Unexpected error: {e}")

if __name__ == "__main__":
    main()
