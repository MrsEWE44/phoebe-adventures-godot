"""Offline migration of levels 1-17 to editor-owned closed floor boundaries.

Trace the spawn-connected interior of land terrain, retaining holes and bridges.
Ocean maps use the existing artwork-traced routes. Repair the collapsed upper
room and the final ocean boundary leak. Collinear vertices are removed.
The output uses the same BUILD_SEGMENTS polygons as chapter three. Runtime only
reads these saved nodes. Re-running skips already migrated scenes.
"""
from collections import defaultdict
from copy import deepcopy
from pathlib import Path
import json
import re
import sys
import numpy as np
from PIL import Image, ImageDraw
from author_chapter2_maps import contours, maps as ocean_maps, road

ROOT = Path(__file__).resolve().parents[1]


def trace(mask):
    # Directed edges keep the floor on the right. At a diagonal corner prefer a
    # right turn so touching loops never become a self-intersecting polygon.
    edges = defaultdict(list)
    padded = np.pad(mask, 1)
    for side, neighbor in enumerate([padded[:-2, 1:-1], padded[1:-1, 2:],
                                     padded[2:, 1:-1], padded[1:-1, :-2]]):
        for y, x in zip(*np.where(mask & ~neighbor)):
            x, y = int(x), int(y)
            a, b = [((x,y),(x+1,y)),((x+1,y),(x+1,y+1)),
                    ((x+1,y+1),(x,y+1)),((x,y+1),(x,y))][side]
            edges[a].append(b)
    loops = []
    while edges:
        start = next(iter(edges))
        p, previous, loop = start, None, []
        while True:
            loop.append(p)
            choices = edges[p]
            if len(choices) > 1 and previous is not None:
                dx, dy = p[0]-previous[0], p[1]-previous[1]
                choices.sort(key=lambda q: -(dx*(q[1]-p[1])-dy*(q[0]-p[0])))
            q = choices.pop(0)
            if not choices: del edges[p]
            previous, p = p, q
            if p == start: break
        corners = []
        for i, b in enumerate(loop):
            a, c = loop[i-1], loop[(i+1)%len(loop)]
            if (b[0]-a[0])*(c[1]-b[1]) != (b[1]-a[1])*(c[0]-b[0]):
                corners.append(b)
        if len(corners) >= 3: loops.append(corners)
    return loops


def author(index, write):
    path = ROOT / f'Scence/Levels/level_{index:02}.tscn'
    source = path.read_text(encoding='utf8')
    live_source = source
    backup = ROOT / '.godot/early_contour_backups' / path.name
    if 'name="FloorBoundary_' in source:
        if '--rebuild' not in sys.argv: return None
        source = backup.read_text(encoding='utf8')
    blocks = re.findall(r'\[node [^\n]*type="CollisionShape2D" parent="Terrain"[^\n]*\]\n.*?(?=\n\[|\Z)', source, re.S)
    assert blocks, path
    background=re.search(r'\[node name="Background"[^\n]*\]\n.*?texture = ExtResource\("([^\"]+)"\)',source,re.S)[1]
    image_path=ROOT/re.search(r'path="res://([^\"]+)" id="'+re.escape(background)+r'"',source)[1]
    size = Image.open(image_path).size
    solid = np.zeros((size[1],size[0]), dtype=bool)
    resources = []
    for block in blocks:
        key = re.search(r'shape = SubResource\("([^\"]+)"\)', block)[1]
        resource = re.search(r'\[sub_resource type="RectangleShape2D" id="'+re.escape(key)+r'"\]\n.*?(?=\n\[)',source,re.S)[0]
        resources.append(resource)
        w,h = map(float,re.search(r'size = Vector2\(([^,]+), ([^)]+)\)',resource).groups())
        x,y = map(float,re.search(r'position = Vector2\(([^,]+), ([^)]+)\)',block).groups())
        solid[max(0,round(y-h/2)):min(size[1],round(y+h/2)), max(0,round(x-w/2)):min(size[0],round(x+w/2))] = True
    spawn = tuple(map(float,re.search(r'\[node name="Spawn"[^\n]+\]\nposition = Vector2\(([^,]+),\s*([^)]+)\)',source).groups()))
    if index >= 8:
        # Existing traced artwork paths also repair the old final-ocean leak.
        layout=deepcopy(ocean_maps[index-7])
        if index==17:
            layout['roads'].append(road(48,(1496,653),(1520,677),(1567,686),(1567,793)))
        loops = contours(layout)
    else:
        baseline = json.loads((ROOT/'.godot/navigation_baseline.json').read_text(encoding='utf8'))
        floor = np.zeros_like(solid)
        for cx,cy in baseline[f'res://Scence/Levels/level_{index:02}.tscn']['cells']:
            px,py = cx*8+4,cy*8+4
            floor[max(0,py-10):min(size[1],py+10),max(0,px-13):min(size[0],px+13)] = True
        floor &= ~solid
        if index==2:
            repair=Image.fromarray(floor)
            ImageDraw.Draw(repair).polygon([(535,45),(585,45),(585,95),(610,110),(630,165),(685,175),(695,208),(646,222),(606,193),(550,175),(526,150),(528,95)],fill=1)
            floor=np.array(repair,dtype=bool)
        loops = trace(floor)
    assert loops
    report = {'before':len(blocks),'after':len(loops),'edges':sum(map(len,loops))}
    if write:
        backup.parent.mkdir(parents=True,exist_ok=True)
        if not backup.exists(): backup.write_text(source,encoding='utf8')
        # A requested rebuild must preserve later chest, trap and story edits.
        source=live_source
        source=re.sub(r'\[node [^\n]*type="Collision(?:Shape|Polygon)2D" parent="Terrain"[^\n]*\]\n.*?(?=\n\[|\Z)', '',source,flags=re.S)
        for resource in resources: source=source.replace(resource,'')
        nodes=[]
        for i,loop in enumerate(loops):
            values=', '.join(str(v) for p in loop for v in p)
            nodes.append(f'[node name="FloorBoundary_{i}" type="CollisionPolygon2D" parent="Terrain"]\nbuild_mode = 1\npolygon = PackedVector2Array({values})\n')
        position=source.index('[node name="Terrain"')
        end=source.index('[node ',position+1)
        source=source[:end]+'\n'.join(nodes)+'\n'+source[end:]
        source=re.sub(r'load_steps=\d+ ', '', source,count=1)
        source=re.sub(r'\n{3,}','\n\n',source)
        path.write_text(source,encoding='utf8')
    # Diagnostic render only: original game textures are never altered.
    texture=Image.open(image_path).convert('RGB')
    draw=ImageDraw.Draw(texture)
    for loop in loops: draw.line(loop+[loop[0]], fill='#46ff94',width=3)
    draw.ellipse((spawn[0]-8,spawn[1]-8,spawn[0]+8,spawn[1]+8),fill='#ffff22')
    texture.thumbnail((640,360))
    output=ROOT/'.godot/early_contour_preview'
    output.mkdir(parents=True,exist_ok=True)
    texture.save(output/f'{index:02}.png')
    return report


if __name__=='__main__':
    report={}
    for index in range(1,18):
        result=author(index,'--write' in sys.argv)
        if result: report[str(index)]=result; print(index,result)
    if report: (ROOT/'.godot/early_contour_report.json').write_text(json.dumps(report,indent=2),encoding='utf8')
