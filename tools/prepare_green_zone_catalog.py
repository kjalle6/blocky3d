"""Promote the complete Green Zone terrain/prop collection without altering art."""
from pathlib import Path
from PIL import Image
import hashlib
import json
import re
import shutil

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets/library/tilesets/green_zone"
OUTPUT = ROOT / "assets/art/green_zone/catalog"
ENTRIES = {}
FILES = []


def hull(points):
    points = sorted(set(points))
    def cross(a, b, c):
        return (b[0]-a[0])*(c[1]-a[1]) - (b[1]-a[1])*(c[0]-a[0])
    lower, upper = [], []
    for point in points:
        while len(lower) > 1 and cross(lower[-2], lower[-1], point) <= 0:
            lower.pop()
        lower.append(point)
    for point in reversed(points):
        while len(upper) > 1 and cross(upper[-2], upper[-1], point) <= 0:
            upper.pop()
        upper.append(point)
    return lower[:-1] + upper[:-1]


def promote(relative, target):
    source, output = SOURCE / relative, OUTPUT / target
    digest = hashlib.sha256(source.read_bytes()).hexdigest()
    if output.exists() and hashlib.sha256(output.read_bytes()).hexdigest() != digest:
        raise RuntimeError(f"Refusing to overwrite changed production art: {output}")
    output.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(source, output)
    FILES.append({"source": str(source.relative_to(ROOT)).replace('\\', '/'),
                  "output": str(output.relative_to(ROOT)).replace('\\', '/'), "sha256": digest})
    return "res://" + str(output.relative_to(ROOT)).replace('\\', '/')


for number in range(1, 97):
    source = f"1 Tiles/Tile_{number:02d}.png"
    with Image.open(SOURCE / source) as image:
        image = image.convert("RGBA")
        assert image.size == (32, 32)
        # Terrain 73-96 are the pack's distant silhouettes, not walkable ground.
        solid = number <= 72
        points = []
        if solid:
            for y in range(32):
                for x in range(32):
                    if image.getpixel((x, y))[3] >= 128:
                        points.extend([(x, y), (x+1, y), (x, y+1), (x+1, y+1)])
        polygon = hull(points) if points else []
    title = "Scenery" if not solid else "Grass slope" if number in (42, 43) else "Grass" if number in [1, 2, 3, 5, 6, 7, 8, 18, 49, 50, 51, 52] else "Stone"
    ENTRIES[f"gz_tile_{number:02d}"] = {
        "name": f"{title} tile {number:02d}", "zone": "Green Zone",
        "category": "Terrain tiles" if solid else "Scenery tiles", "kind": "tile",
        "image": promote(source, f"tiles/tile_{number:02d}.png"), "anchor": "grid", "crop": False,
        "solid": solid, "polygon": polygon,
        "description": "Solid terrain. Click or drag to paint on the tile grid. Shift keeps the brush active." if solid else "Background silhouette. Paint on the tile grid; players and bullets pass through it."
    }

GROUPS = {"Benches": "Bench", "Bushes": "Bush", "Fence": "Fence", "Fountain": "Fountain", "Grass": "Grass tuft", "Leaf": "Leaves", "Stones": "Stone"}
for source in sorted((SOURCE / "3 Objects").rglob("*.png")):
    group = source.parent.name
    basename = source.stem.replace("Rapm", "Ramp").replace("Garbage_Can", "Bin")
    label = (GROUPS[group] + " " + basename) if group in GROUPS else re.sub(r"(?<=\D)(\d)", r" \1", basename)
    template = "gz_prop_" + re.sub(r"[^a-z0-9]+", "_", group.lower() + "_" + source.stem.lower())
    ENTRIES[template] = {
        "name": label, "zone": "Green Zone", "category": "Decorations", "kind": "decoration",
        "image": promote(source.relative_to(SOURCE), f"props/{group.lower()}/{source.name}"),
        "anchor": "air" if group == "Leaf" else "ground",
        "description": "Scenery only. Players and bullets pass through it; it has no climbing, ramp, pickup, or other interaction."
    }

ANIMATIONS = {"Card": (8, 8, True), "Money": (6, 8, True), "Skateboard": (9, 10, True), "Fountain": (4, 8, True), "Chest_open": (7, 8, False)}
for name, (frames, fps, loop) in ANIMATIONS.items():
    source = f"4 Animated objects/{name}.png"
    with Image.open(SOURCE / source) as image:
        image = image.convert("RGBA")
        # The chest has seven 32px cells; its final two transparent columns
        # were cropped from the source sheet. Keep the original frame stride.
        width, height = (32 if name == "Chest_open" else image.width // frames), image.height
        assert width * frames == image.width or (name == "Chest_open" and image.width == 222)
        boxes = [image.crop((i*width, 0, (i+1)*width, height)).getchannel("A").getbbox() for i in range(frames)]
        boxes = [box for box in boxes if box]
        region = [min(b[0] for b in boxes), min(b[1] for b in boxes), max(b[2] for b in boxes), max(b[3] for b in boxes)]
        region[2] -= region[0]
        region[3] -= region[1]
    ENTRIES["gz_animated_" + name.lower()] = {
        "name": "Chest opening" if name == "Chest_open" else "Animated " + name.lower(),
        "zone": "Green Zone", "category": "Animated scenery", "kind": "decoration",
        "image": promote(source, f"animated/{name}.png"), "anchor": "ground",
        "frames": frames, "frame_width": width, "fps": fps, "loop": loop, "frame_region": region,
        "description": "Animated scenery only; it does not grant items or end the level. " + ("Loops during play." if loop else "Opens once when the level starts, then stays open.")
    }

catalog = ROOT / "resources/level_catalogs/green_zone.json"
catalog.parent.mkdir(parents=True, exist_ok=True)
catalog.write_text(json.dumps(ENTRIES, indent=2) + "\n", encoding="utf-8")
(OUTPUT / "manifest.json").write_text(json.dumps({"pack": "Green Zone", "scope": "96 terrain tiles, 78 static props, 5 animated props; backgrounds excluded", "files": FILES}, indent=2) + "\n", encoding="utf-8")
print(f"Promoted {len(FILES)} unchanged images; generated {len(ENTRIES)} stable catalog templates.")
