"""Offline rectangle authoring from the existing reachable floor, with player clearance preserved.

Requires .godot/navigation_baseline.json (Tools/export_navigation.gd).
Use --write to update only Terrain collision nodes; original scenes are backed up.
No runtime geometry generation and no source image edits.
"""
from pathlib import Path
import json, re, sys
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
CELL = 16

def largest_rectangle(mask):
    heights = np.zeros(mask.shape[1], dtype=int)
    best = (0, 0, 0, 0)
    area = 0
    for y, row in enumerate(mask):
        heights = (heights + 1) * row
        stack = []
        for x in range(len(heights)+1):
            height = int(heights[x]) if x < len(heights) else 0
            start = x
            while stack and stack[-1][1] > height:
                left, h = stack.pop()
                if h*(x-left) > area:
                    best, area = (left,y-h+1,x-left,h), h*(x-left)
                start = left
            if height and (not stack or stack[-1][1] < height):
                stack.append((start,height))
    return best

def rectangles(record):
    free = np.zeros((59,105), dtype=bool)
    # Preserve the full 18x12 clearance around every originally walkable centre.
    for cx,cy in record['cells']:
        px,py=cx*8+4,cy*8+4
        x0,x1=max(0,(px-10)//CELL),min(105,(px+10)//CELL+1)
        y0,y1=max(0,(py-7)//CELL),min(59,(py+7)//CELL+1)
        free[y0:y1,x0:x1]=True
    remaining = ~free
    result=[]
    while remaining.any():
        x,y,w,h=largest_rectangle(remaining)
        remaining[y:y+h,x:x+w]=False
        result.append((x*CELL,y*CELL,w*CELL,h*CELL))
    result.extend([(-32,-32,1736,32),(-32,941,1736,32),(-32,0,32,941),(1672,0,32,941)])
    return result

def write_scene(path, rects):
    text=path.read_text(encoding='utf-8')
    backup=ROOT/'.godot/collision_backups'/path.relative_to(ROOT)
    if not backup.exists():
        backup.parent.mkdir(parents=True,exist_ok=True)
        backup.write_text(text,encoding='utf-8')
    text=re.sub(r'\[node name="[^"]+" type="Collision(?:Polygon|Shape)2D" parent="Terrain"[^\]]*\]\n.*?(?=\n\[|\Z)', '',text,flags=re.S)
    resources=[]
    nodes=[]
    for i,(x,y,w,h) in enumerate(rects):
        name=f'Block_{i:03d}'
        resources.append(f'[sub_resource type="RectangleShape2D" id="{name}"]\nsize = Vector2({w}, {h})\n')
        nodes.append(f'[node name="{name}" type="CollisionShape2D" parent="Terrain"]\nposition = Vector2({x+w/2}, {y+h/2})\nshape = SubResource("{name}")\n')
    first=text.index('[node ')
    text=text[:first]+'\n'.join(resources)+'\n'+text[first:]
    text+='\n'+'\n'.join(nodes)
    text=re.sub(r'load_steps=\d+ ', '', text, count=1)
    path.write_text(text,encoding='utf-8')

if __name__=='__main__':
    report=json.loads((ROOT/'.godot/navigation_baseline.json').read_text(encoding='utf-8'))
    for name,record in report.items():
        rects=rectangles(record)
        print(f'{name}: {record["count"]} -> {len(rects)} rectangular blocks')
        if '--write' in sys.argv:
            write_scene(ROOT/name.removeprefix('res://'),rects)
