"""Author atlas resources from generated RGBA originals; never edits PNG pixels."""
from pathlib import Path
import re
from PIL import Image

ROOT=Path(__file__).resolve().parents[1]
ART=ROOT/'Art/CombatUpdate'

def frames_resource(name, regions, canvas, animations):
    lines=['[gd_resource type="SpriteFrames" format=3]',f'[ext_resource type="Texture2D" path="res://Art/CombatUpdate/{name}.png" id="1"]']
    for i,(x,y,w,h) in enumerate(regions):
        lines += [f'[sub_resource type="AtlasTexture" id="f{i}"]','atlas = ExtResource("1")',f'region = Rect2({x}, {y}, {w}, {h})']
        if canvas:
            cw,ch=canvas
            lines += [f'margin = Rect2({(cw-w)/2}, {ch-h-5}, {cw-w}, {ch-h})']
    lines+=['[resource]','animations = [']
    for label,ids,loop,speed in animations:
        entries=', '.join('{"duration":1.0,"texture":SubResource("f%d")}'%i for i in ids)
        lines += ['{"name": &"%s", "loop":%s,"speed":%s,"frames":[%s]},'%(label,str(loop).lower(),speed,entries)]
    lines+= [']']
    path=ART/f'{name}.tres';path.write_text('\n'.join(lines)+'\n',encoding='utf8')

for name,side in [('nuonuo_walk','left'),('ikun_walk','right')]:
    im=Image.open(ART/f'{name}.png')
    mask=im.getchannel('A').point(lambda value:255 if value>96 else 0)
    rows=[0,354,695,1086] if name=='nuonuo_walk' else [0,362,724,1086]
    regions=[]
    for row in range(3):
        for col in range(4):
            x0,x1=round(col*im.width/4),round((col+1)*im.width/4)
            y0,y1=rows[row:row+2]
            a,b,c,d=mask.crop((x0,y0,x1,y1)).getbbox()
            a,b,c,d=max(0,a-2),max(0,b-2),min(x1-x0,c+2),min(y1-y0,d+2)
            regions.append((x0+a,y0+b,c-a,d-b))
    canvas=(max(r[2] for r in regions)+12,max(r[3] for r in regions)+12)
    frames_resource(name,regions,canvas,[('down',range(4),True,9),('left',range(4,8),True,9),('up',range(8,12),True,9)])
    character=name.replace('_walk','')
    p=ROOT/f'Characters/Definitions/{character}.tres'
    text=p.read_text(encoding='utf8')
    text=text.replace(f'res://Characters/Animations/{character}.tres',f'res://Art/CombatUpdate/{name}.tres')
    scale=44/(canvas[1]-12)
    for field,value in [('sprite_scale',f'Vector2({scale},{scale})'),('sprite_offset',f'Vector2(0,{-scale*(canvas[1]/2-5)})')]:
        pattern=rf'^{field} = .*?$'
        if re.search(pattern,text,re.M):text=re.sub(pattern,f'{field} = {value}',text,flags=re.M)
        else:text+=f'\n{field} = {value}\n'
    p.write_text(text,encoding='utf8')
    print(name,canvas,regions)

im=Image.open(ART/'thunder_crescent.png')
regions=[]
for row in range(2):
    for col in range(4):
        x,y=round(col*im.width/4),round(row*im.height/2)
        regions.append((x,y,round((col+1)*im.width/4)-x,round((row+1)*im.height/2)-y))
frames_resource('thunder_crescent',regions,None,[('slash',range(8),False,15)])

# A trimmed texture resource keeps the weapon grip and display width meaningful.
im=Image.open(ART/'pili_blade.png');a=im.getchannel('A').point(lambda v:255 if v>96 else 0);x,y,right,bottom=a.getbbox()
(ART/'pili_blade.tres').write_text(f'''[gd_resource type="AtlasTexture" format=3]
[ext_resource type="Texture2D" path="res://Art/CombatUpdate/pili_blade.png" id="1"]
[resource]
atlas = ExtResource("1")
region = Rect2({x}, {y}, {right-x}, {bottom-y})
''',encoding='utf8')
