"""One-time addition of editor-visible sea contact triggers to the first hub."""
from pathlib import Path
import re
p=Path(__file__).resolve().parents[1]/'Scence/level1.tscn'
s=p.read_text(encoding='utf-8')
if '[node name="OceanEntry"' in s:
    raise SystemExit('OceanEntry already authored; edit its polygons in Godot.')
s=s.replace('[sub_resource type="RectangleShape2D" id="PortalShape_temple"]','[ext_resource type="Script" path="res://Scence/ocean_entry.gd" id="ocean_entry"]\n\n[sub_resource type="RectangleShape2D" id="PortalShape_temple"]',1)
extra='\n[node name="OceanEntry" type="Area2D" parent="."]\ncollision_layer = 32\ncollision_mask = 1\nscript = ExtResource("ocean_entry")\n'
for name in ['WestWater','EastWater']:
    values=re.search(r'\[node name="'+name+r'"[^\n]+\]\npolygon = PackedVector2Array\(([^)]+)\)',s).group(1)
    pts=list(map(float,values.split(',')))
    for i in range(1,len(pts),2):pts[i]-=9
    extra+=f'\n[node name="{name}Contact" type="CollisionPolygon2D" parent="OceanEntry"]\npolygon = PackedVector2Array('+','.join(map(str,pts))+')\n'
extra+='\n[node name="SeaSign" type="Label" parent="."]\noffset_left = 943.0\noffset_top = 675.0\ntext = "触碰海水 · 潮汐遗迹 / 第二章"\ntheme_override_font_sizes/font_size = 15\n'
p.write_text(s+extra,encoding='utf-8')
print('Authored two shoreline contact polygons, retaining existing coast terrain.')
