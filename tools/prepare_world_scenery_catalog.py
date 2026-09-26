"""Expose the available world-building packs without modifying their artwork.

Run with Python + Pillow. Existing catalog IDs/art and level layouts are untouched.
Sheet dimensions and solid/scenery tile ranges below were reviewed against the
source images. UI, character combat sheets, full-screen/parallax backgrounds,
marketing previews and duplicate overview atlases are not placeable world props.
"""
from collections import Counter
from pathlib import Path
import hashlib
import json
import re
import shutil
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
LIBRARY = ROOT / "assets/library"
OUTPUT = ROOT / "assets/art/world_scenery"
ENTRIES, FILES, LICENSES, SKIPPED = {}, {}, {}, {}


def slug(text):
    return re.sub(r"[^a-z0-9]+", "_", text.lower()).strip("_")


def label(text):
    text = re.sub(r"^\d+\s+", "", text).replace("_", " ")
    text = re.sub(r"([a-z])([A-Z])", r"\1 \2", text)
    return text.replace("Decoratoins", "Decorations").replace("Rapm", "Ramp").replace("Metall", "Metal").strip().capitalize()


def promote(source):
    relative = source.relative_to(LIBRARY)
    target = OUTPUT / relative
    digest = hashlib.sha256(source.read_bytes()).hexdigest()
    if target.exists() and hashlib.sha256(target.read_bytes()).hexdigest() != digest:
        raise RuntimeError(f"Production asset differs: {target}")
    if not target.exists():
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, target)
    licenses = []
    for parent in source.parents:
        if parent == LIBRARY:
            break
        candidates = [p for p in parent.glob("*.txt") if p.stem.lower() in ("license", "source")]
        for path in candidates:
            dest = OUTPUT / path.relative_to(LIBRARY)
            dest.parent.mkdir(parents=True, exist_ok=True)
            if not dest.exists():
                shutil.copyfile(path, dest)
            licenses.append(dest.relative_to(ROOT).as_posix())
            LICENSES[licenses[-1]] = path.relative_to(ROOT).as_posix()
        if candidates:
            break
    FILES[relative.as_posix()] = {"source": source.relative_to(ROOT).as_posix(),
        "output": target.relative_to(ROOT).as_posix(), "sha256": digest, "licenses": licenses}
    return "res://" + target.relative_to(ROOT).as_posix()


def add(source, zone, name=None, frames=1, frame_width=None, loop=True, anchor="ground", region=None):
    with Image.open(source) as original:
        image = original.convert("RGBA")
        if not image.getchannel("A").getbbox():
            SKIPPED[source.relative_to(LIBRARY).as_posix()] = "Empty transparent image"
            return
        if frames > 1:
            fw = frame_width or image.height
            assert fw * frames == image.width, source
            boxes = [image.crop((i*fw, 0, (i+1)*fw, image.height)).getchannel("A").getbbox() for i in range(frames)]
            boxes = [box for box in boxes if box]
            x, y = min(b[0] for b in boxes), min(b[1] for b in boxes)
            region = [x, y, max(b[2] for b in boxes)-x, max(b[3] for b in boxes)-y]
    identifier = "scenery_" + slug(source.relative_to(LIBRARY).with_suffix("").as_posix())
    entry = {"name": name or label(source.stem), "zone": zone,
        "category": "Animated scenery" if frames > 1 else "Decorations", "kind": "decoration",
        "image": promote(source), "anchor": anchor,
        "description": f"{zone} scenery. Players and bullets pass through it. Artwork only; no damage, rewards, transport or other interaction."}
    if region is not None:
        entry["frame_region"] = region
    if frames > 1:
        entry.update(frames=frames, frame_width=fw, fps=8, loop=loop)
        entry["description"] += " Loops during play." if loop else " Plays once when the level starts."
    assert identifier not in ENTRIES, identifier
    ENTRIES[identifier] = entry


def hull(points):
    points = sorted(set(points))
    def cross(a, b, c):
        return (b[0]-a[0])*(c[1]-a[1])-(b[1]-a[1])*(c[0]-a[0])
    chains = []
    for sequence in (points, reversed(points)):
        chain = []
        for point in sequence:
            while len(chain) > 1 and cross(chain[-2], chain[-1], point) <= 0:
                chain.pop()
            chain.append(point)
        chains.append(chain[:-1])
    return chains[0] + chains[1]


def tile(source, zone, solid, surface="cave"):
    with Image.open(source) as image:
        if image.size != (32, 32):
            SKIPPED[source.relative_to(LIBRARY).as_posix()] = "Overview atlas; individual tiles included"
            return
        alpha = image.convert("RGBA").getchannel("A")
        points = []
        if solid:
            for y in range(32):
                for x in range(32):
                    if alpha.getpixel((x, y)) >= 128:
                        points.extend(((x,y),(x+1,y),(x,y+1),(x+1,y+1)))
        polygon = hull(points) if points else []
        solid = solid and len(polygon) >= 3
    identifier = "scenery_" + slug(source.relative_to(LIBRARY).with_suffix("").as_posix())
    ENTRIES[identifier] = {"name": ("Solid " if solid else "Scenery ") + label(source.stem),
        "zone": zone, "category": "Terrain tiles" if solid else "Scenery tiles", "kind": "tile",
        "image": promote(source), "anchor": "grid", "crop": False, "solid": solid,
        "surface": surface if solid else "silent", "polygon": polygon,
        "description": "Solid terrain block." if solid else "Scenery block. No collision or hazard damage."}


# All remaining zone terrain and object art. Existing Green Zone stays unchanged.
for pack in sorted((LIBRARY / "tilesets").iterdir()):
    if not pack.is_dir() or pack.name == "green_zone":
        continue
    zone = "Beach" if pack.name == "beach_zone" else label(pack.name).title()
    for path in sorted((pack / "1 Tiles").glob("*.png")):
        match = re.search(r"(\d+)$", path.stem)
        number = int(match[1]) if match else 0
        solid = number > 0 and not path.stem.startswith(("Water", "Back"))
        if pack.name == "desert_zone": solid = solid and number <= 50
        if pack.name == "dumb_zone": solid = solid and number <= 56
        if pack.name == "exclusion_zone": solid = solid and number <= 45 and number not in (5,6,7,8,35,36)
        if pack.name == "factory_zone": solid = solid and 32 <= number <= 56
        if pack.name == "powerstation_zone": solid = solid and number <= 44
        if pack.name == "piratebay_zone": solid = solid and number not in (1,2,3,4,13,22,23,24,35,36,37,38,39,40,41,42,43,44,45,46,47,48,49,50)
        tile(path, zone, solid, "sand" if pack.name in ("beach_zone", "desert_zone") else "cave")
    for path in sorted((pack / "3 Objects").rglob("*.png")):
        relative = path.relative_to(pack / "3 Objects")
        title = " · ".join(label(part) for part in relative.with_suffix("").parts)
        animated = pack.name == "seaport_zone" and (path.stem == "Move" or path.stem.endswith("Grab"))
        add(path, zone, title, frames=4 if animated else 1, frame_width=96 if animated else None)
    for path in sorted((pack / "4 Animated objects").glob("*.png")):
        with Image.open(path) as im:
            fw = {("industrial_zone", "Screen2"):32, ("industrial_zone", "Transporter"):96,
                  ("powerstation_zone", "Trap"):32}.get((pack.name, path.stem), im.height)
            count = im.width // fw
        add(path, zone, label(path.stem), count, fw,
            loop=not (path.stem in ("Chest", "Gas_start", "Gas_end", "Entry")))


# Environmental prop collections; leave source overview/poster sheets out.
collections = [
    ("environment/rocks/PNG", "Rocks", "ground"),
    ("environment/vegetation/trees/PNG", "Trees", "ground"),
    ("environment/vegetation/nature", "Nature", "ground"),
    ("environment/sky/clouds/PNG", "Clouds", "air"),
    ("environment/urban/graffiti", "Graffiti", "air"),
    ("environment/urban/city_visuals/billboards and ads", "Signs and billboards", "air"),
    ("environment/structures/bridges/3 Rope", "Bridges", "air"),
    ("vehicles/trucks", "Trucks", "ground"),
]
for relative, zone, anchor in collections:
    folder = LIBRARY / relative
    for path in sorted(folder.rglob("*.png")):
        parts = path.relative_to(folder).parts
        if len(parts) == 1 and path.stem.lower() in ("coupon", "preview", "palette"):
            continue
        if "0 All" in parts:
            SKIPPED[path.relative_to(LIBRARY).as_posix()] = "Duplicate; included under named graffiti group"
            continue
        if path.stem.lower().startswith(("coupon", "preview")):
            continue
        name = " · ".join(label(part) for part in path.relative_to(folder).with_suffix("").parts)
        frames, fw = 1, None
        if zone == "Trucks" and "2 Chassis" in parts:
            with Image.open(path) as im: fw, frames = im.height, im.width // im.height
        elif zone == "Trucks" and path.stem == "Flasher": fw, frames = 32, 6
        add(path, zone, name, frames, fw, anchor=anchor)

for path in sorted((LIBRARY / "environment/structures/bridges/1 Tiles").glob("*.png")):
    # Bridge beams/railings are decorative assembly pieces, not solid cubes.
    tile(path, "Bridges", False)

for path in sorted((LIBRARY / "environment/structures/bridges/2 Examples").glob("*.png")):
    add(path, "Bridges", "Assembled bridge " + path.stem, anchor="air")

add(LIBRARY / "environment/structures/cave_entrances/cave_entrance_green_zone_native.png", "Cave entrances", "Cave entrance")

door_root = LIBRARY / "environment/structures/doors_and_portals"
for path in sorted(door_root.rglob("*.png")):
    relative = path.relative_to(door_root)
    if relative.parts[0] == "3 Characters": continue
    name = " · ".join(label(part) for part in relative.with_suffix("").parts)
    fw = None
    if relative.parts[0] == "1 Doors" or path.stem == "Lift_door": fw = 32
    elif relative.parts[0] == "2 Portals" or path.stem == "Lift2": fw = 64
    elif path.stem == "Lift1": fw = 32
    if fw:
        with Image.open(path) as im: count = im.width // fw
        add(path, "Doors and portals", name + " animation", count, fw, loop=relative.parts[0] == "2 Portals")
        # A still, closed variant is useful for decorating without an automatic opening.
        key = "scenery_" + slug(path.relative_to(LIBRARY).with_suffix("").as_posix())
        entry = ENTRIES[key].copy()
        for field in ("frames", "frame_width", "fps", "loop"): entry.pop(field)
        entry.update(name=name + " (still)", category="Decorations")
        entry["description"] = "Decorative closed door or lift. Does not open, teleport or carry the player."
        ENTRIES[key + "_still"] = entry
    else: add(path, "Doors and portals", name, anchor="air")

# Decorative idle drone models. Their combat/movement sheets remain source art.
for path in sorted((LIBRARY / "vehicles/drones/1 Drones").glob("*/Idle.png")):
    with Image.open(path) as im: fw, count = im.height, im.width // im.height
    add(path, "Drones", "Drone " + path.parent.name + " (scenery)", count, fw, anchor="air")

output = ROOT / "resources/level_catalogs/world_scenery.json"
output.write_text(json.dumps(ENTRIES, indent=2) + "\n", encoding="utf-8")
manifest = {"scope": "World-building art from all tilesets, environment prop packs and vehicles",
    "excluded": "GUI/icons, playable character/enemy animations, full-screen lighting/VFX and parallax backgrounds have separate systems.",
    "files": list(FILES.values()), "licenses": LICENSES, "skipped": SKIPPED,
    "counts_by_zone": dict(sorted(Counter(e['zone'] for e in ENTRIES.values()).items()))}
(OUTPUT / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
print(f"Added {len(ENTRIES)} templates from {len(FILES)} original images.")
print(json.dumps(manifest["counts_by_zone"], indent=2))
