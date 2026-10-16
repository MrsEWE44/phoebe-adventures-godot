"""Offline authoring only. Run audit_actor_bounds.gd first; edits Resource metadata, never image pixels."""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
report = json.loads((ROOT / '.godot/actor_bounds.json').read_text(encoding='utf-8'))

def numbers(value):
    return list(map(float, re.findall(r'-?\d+(?:\.\d+)?', value)))

def vector(x, y):
    return f'Vector2({x:.4f}, {y:.4f})'

for name, record in report.items():
    if name == 'chest' or not record['frames']:
        continue
    path = ROOT / 'Characters/Definitions' / f'{name}.tres'
    text = path.read_text(encoding='utf-8')
    x, y, w, h = numbers(record['bounds'])
    # Put the lowest standing/walking body pixel at the foot anchor.
    shift = max(0, y+h)
    offset = numbers(re.search(r'sprite_offset = Vector2\(([^)]+)\)', text)[1])
    values = {
        'sprite_offset': vector(offset[0], offset[1]-shift),
        'hurtbox_size': vector(w+1, h+1),
        'hurtbox_offset': vector(x+w/2, y+h/2-shift),
        'foot_size': vector(20 if name in ['abyss_king','demon','blood_monster','tide_sorcerer','reef_shark'] else 14, 8),
        'foot_offset': vector(0,-2),
    }
    frames = {}
    for anim, index, bounds in record['frames']:
        bx, by, bw, bh = numbers(bounds)
        frames.setdefault(anim, []).append(f'Rect2({bx-.5:.4f}, {by-shift-.5:.4f}, {bw+1:.4f}, {bh+1:.4f})')
    values['hurtbox_frames'] = '{' + ', '.join(f'"{anim}": [{", ".join(rects)}]' for anim, rects in frames.items()) + '}'
    for key, value in values.items():
        pattern = rf'^{key} = .*?$'
        line = f'{key} = {value}'
        text = re.sub(pattern, lambda _: line, text, flags=re.M) if re.search(pattern, text, re.M) else text.rstrip()+'\n'+line+'\n'
    path.write_text(text, encoding='utf-8')
    print(f'{name}: body {w:.1f} x {h:.1f}, foot correction {shift:.2f}px')
