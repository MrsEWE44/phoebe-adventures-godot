from pathlib import Path
from PIL import Image
root=Path(__file__).resolve().parents[1]
art=root/'Art/Progression'
im=Image.open(art/'items.png').convert('RGBA')
alpha=im.getchannel('A').point(lambda a:255 if a>150 else 0)
for i in range(16):
 x,y=round(i%4*im.width/4),round(i//4*im.height/4)
 right,bottom=round((i%4+1)*im.width/4),round((i//4+1)*im.height/4)
 a,b,c,d=alpha.crop((x,y,right,bottom)).getbbox()
 (art/f'item_{i}.tres').write_text(f'[gd_resource type="AtlasTexture" format=3]\n[ext_resource type="Texture2D" path="res://Art/Progression/items.png" id="a"]\n[resource]\natlas = ExtResource("a")\nregion = Rect2({x+a},{y+b},{c-a},{d-b})\n',encoding='utf8')
