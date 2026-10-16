"""Offline editor collision authoring: retain only the wall/road boundary shell.

Reads the existing rectangular terrain without altering walkable space. Writes
ordinary RectangleShape2D resources to .tscn; no runtime collision generation.
The original rectangle scenes and their reachable cells are backed up locally.
"""
from pathlib import Path
import json
import re
import sys
import numpy as np
from simplify_terrain import largest_rectangle

ROOT = Path(__file__).resolve().parents[1]
SIZE = 16


def author(path, write=False):
    source = path.read_text(encoding="utf-8")
    sizes = {key: (float(w), float(h)) for key, w, h in re.findall(
        r'\[sub_resource type="RectangleShape2D" id="(Block_\d+)"\]\nsize = Vector2\(([^,]+), ([^)]+)\)', source)}
    if not sizes:
        return None  # Already authored, or a scene with hand-drawn polygons.
    solid = np.zeros((59, 105), dtype=bool)
    for key, px, py in re.findall(r'\[node name="(Block_\d+)" type="CollisionShape2D" parent="Terrain"\]\nposition = Vector2\(([^,]+), ([^)]+)\)', source):
        w, h = sizes[key]
        x, y = float(px)-w/2, float(py)-h/2
        solid[max(0, round(y/SIZE)):min(59, round((y+h)/SIZE)),
              max(0, round(x/SIZE)):min(105, round((x+w)/SIZE))] = True
    free = ~solid
    adjacent = np.zeros_like(solid)
    adjacent[1:] |= free[:-1]
    adjacent[:-1] |= free[1:]
    adjacent[:, 1:] |= free[:, :-1]
    adjacent[:, :-1] |= free[:, 1:]
    boundary = solid & adjacent
    remaining = boundary.copy()
    rects = []
    while remaining.any():
        x, y, w, h = largest_rectangle(remaining)
        remaining[y:y+h, x:x+w] = False
        rects.append((x*SIZE, y*SIZE, w*SIZE, h*SIZE))
    rects.extend([(-32,-32,1736,32),(-32,941,1736,32),(-32,0,32,941),(1672,0,32,941)])
    result = dict(before=len(sizes), after=len(rects), filled_cells=int(solid.sum()), boundary_cells=int(boundary.sum()))
    if write:
        backup = ROOT / ".godot/boundary_backups" / path.relative_to(ROOT)
        backup.parent.mkdir(parents=True, exist_ok=True)
        if not backup.exists(): backup.write_text(source, encoding="utf-8")
        source = re.sub(r'\[sub_resource type="RectangleShape2D" id="Block_\d+"\]\n.*?(?=\n\[)', '', source, flags=re.S)
        source = re.sub(r'\[node name="Block_\d+" type="CollisionShape2D" parent="Terrain"\]\n.*?(?=\n\[|\Z)', '', source, flags=re.S)
        resources, nodes = [], []
        for i, (x,y,w,h) in enumerate(rects):
            key = f"Boundary_{i:03d}"
            resources.append(f'[sub_resource type="RectangleShape2D" id="{key}"]\nsize = Vector2({w}, {h})\n')
            nodes.append(f'[node name="{key}" type="CollisionShape2D" parent="Terrain"]\nposition = Vector2({x+w/2}, {y+h/2})\nshape = SubResource("{key}")\n')
        first = source.index('[node ')
        source = source[:first] + '\n'.join(resources) + '\n' + source[first:]
        source += '\n' + '\n'.join(nodes)
        path.write_text(source, encoding="utf-8")
    return result


if __name__ == "__main__":
    write = "--write" in sys.argv
    baseline = ROOT / ".godot/navigation_after.json"
    backup = ROOT / ".godot/boundary_navigation_before.json"
    if write and not backup.exists(): backup.write_bytes(baseline.read_bytes())
    report = {}
    for path in [ROOT/"Scence/Chapter2.tscn", *sorted((ROOT/"Scence/Levels").glob("level_*.tscn"))]:
        result = author(path, write)
        if result:
            report[str(path.relative_to(ROOT))] = result
            print(path.name, result)
    if write: (ROOT/".godot/boundary_report.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
