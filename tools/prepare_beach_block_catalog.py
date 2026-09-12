"""Expose the six existing production sand pieces in the shared block brush."""
import json
from pathlib import Path
from PIL import Image

root = Path(__file__).resolve().parents[1]
folder = Path("assets/art/green_zone/shoreline/tiles")
labels = {
    "top_left": "Sand top left", "top": "Sand top", "top_right": "Sand top right",
    "body_left": "Sand left edge", "body": "Sand fill", "body_right": "Sand right edge",
}
entries = {}
for name, label in labels.items():
    path = folder / (name + ".png")
    with Image.open(root / path) as image:
        assert image.size == (32, 32)
        left, top, right, bottom = image.convert("RGBA").getchannel("A").getbbox()
    entries["beach_tile_" + name] = {
        "name": label, "zone": "Beach", "category": "Terrain tiles", "kind": "tile",
        "image": "res://" + path.as_posix(), "anchor": "grid", "crop": False,
        "solid": True, "surface": "sand",
        "polygon": [[left, top], [right, top], [right, bottom], [left, bottom]],
        "description": "Solid sand block. Click or drag to build; right-click or Esc finishes the brush.",
    }
(root / "resources/level_catalogs/beach.json").write_text(json.dumps(entries, indent=2) + "\n", encoding="utf-8")
print("Added six sand block definitions referencing unchanged production art.")
