import os
import shutil
from dataclasses import dataclass
from typing import List, Dict

@dataclass
class OfflineBundle:
    id: str
    name: str
    size_gb: float
    description: str
    url: str

class ResilienceWizard:
    def __init__(self, library_path: str = "/Volumes/20TB_HDD/offline-library"):
        self.library_path = library_path
        self.zip_code = ""
        self.county = ""
        self.hazards = []
        
        # Defined bundles (ZIM files from Kiwix/Wikimedia mirrors)
        self.bundles = [
            OfflineBundle("wiki", "Core Wikipedia (English, no images)", 25.0, "The definitive offline knowledge base.", "https://download.kiwix.org/zim/wikipedia/wikipedia_en_all_nopic.zim"),
            OfflineBundle("med", "Medical Library (WikiMed + SF Handbook)", 4.0, "Trauma care and village health guides.", "https://download.kiwix.org/zim/other/wikimed_en_all.zim"),
            OfflineBundle("repair", "Civil Repair (iFixit + Engineering)", 10.0, "Plumbing, electrical, and engine repair.", "https://download.kiwix.org/zim/other/ifixit_en_all.zim"),
            OfflineBundle("maps", "Regional Map Pack (OSM)", 2.0, "Topographic and road data for your county.", "https://download.kiwix.org/zim/other/osm_en_all.zim"),
            OfflineBundle("survival", "Survival Essentials", 1.0, "Classic fieldcraft and survival field manuals.", "https://download.kiwix.org/zim/other/wikibooks_en_all.zim")
        ]

    def set_location(self, zip_code: str):
        """Maps ZIP code to Hawaii Counties and sets local hazards."""
        self.zip_code = zip_code
        # Specialized Hawaii mapping
        hi_zips = {
            "96707": "Honolulu County (Oahu)",
            "96706": "Honolulu County (Oahu)",
            "96720": "Hawaii County (Big Island)",
            "96732": "Maui County (Maui/Lanai/Molokai)",
            "96766": "Kauai County (Kauai)"
        }
        
        self.county = hi_zips.get(zip_code, "Unknown County")
        
        if zip_code.startswith("96"):
            self.hazards = ["Tsunami", "Hurricane", "Flash Flood"]
            if "Hawaii County" in self.county:
                self.hazards.append("Volcanic Activity")
        
        print(f"📍 Location Identified: {self.county}")
        print(f"⚠️ Primary Hazards: {', '.join(self.hazards)}")

    def check_disk_space(self, selected_bundles: List[str]) -> bool:
        """Verifies if the target drive has enough free space for the selection."""
        total_required = sum(b.size_gb for b in self.bundles if b.id in selected_bundles)
        
        if not os.path.exists(self.library_path):
            print(f"❌ Error: Target drive not found at {self.library_path}")
            return False
            
        usage = shutil.disk_usage(self.library_path)
        free_gb = usage.free / (1024**3)
        
        print(f"📊 Selection requires {total_required:.1f} GB. Target drive has {free_gb:.1f} GB free.")
        return free_gb >= total_required

    def generate_commands(self, selected_ids: List[str]) -> List[str]:
        """Generates aria2c commands for the selected bundles."""
        commands = []
        target_dir = os.path.join(self.library_path, "zim_archives")
        
        for bundle_id in selected_ids:
            bundle = next((b for b in self.bundles if b.id == bundle_id), None)
            if bundle:
                # aria2c optimized for high speed/resume support
                cmd = f"aria2c -c -x 16 -s 16 -d '{target_dir}' '{bundle.url}'"
                commands.append(cmd)
        return commands

    def run_cli_wizard(self):
        """Interactive CLI flow for the wizard."""
        print("🌟 LOCAL RESILIENCE WIZARD 🌟")
        zip_in = input("Enter your ZIP Code (e.g. 96707): ").strip()
        self.set_location(zip_in)
        
        print("\nSelect the offline bundles you wish to download:")
        for i, b in enumerate(self.bundles):
            print(f"[{i+1}] {b.name} (~{b.size_gb}GB) - {b.description}")
            
        choices = input("\nEnter numbers (e.g. 1, 2, 5) or 'all': ").strip()
        selected_ids = []
        
        if choices.lower() == 'all':
            selected_ids = [b.id for b in self.bundles]
        else:
            indices = [int(x.strip()) - 1 for x in choices.split(",") if x.strip().isdigit()]
            selected_ids = [self.bundles[i].id for i in indices if 0 <= i < len(self.bundles)]

        if not selected_ids:
            print("No bundles selected. Exiting.")
            return

        if self.check_disk_space(selected_ids):
            print("\n✅ SPACE VERIFIED. Execute the following commands to start download:")
            cmds = self.generate_commands(selected_ids)
            for c in cmds:
                print(f"\n{c}")
        else:
            print("\n❌ INSUFFICIENT SPACE. Please clear space on your 20TB drive and try again.")

if __name__ == "__main__":
    wizard = ResilienceWizard()
    wizard.run_cli_wizard()
