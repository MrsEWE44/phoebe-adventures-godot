"""Author resource metadata only; original and generated PNG pixels remain unchanged."""
from pathlib import Path
from PIL import Image
import json
ROOT=Path(__file__).resolve().parents[1]
ART=ROOT/'Art/Chapter3'
def write(path,text): (ROOT/path).write_text(text,encoding='utf8')
def atlas(name,path,cols,rows,animations):
 im=Image.open(ROOT/path).convert('RGBA');alpha=im.getchannel('A').point(lambda x:255 if x>170 else 0)
 rects=[]
 for row in range(rows):
  for col in range(cols):
   x0,y0,x1,y1=round(col*im.width/cols),round(row*im.height/rows),round((col+1)*im.width/cols),round((row+1)*im.height/rows)
   bbox=alpha.crop((x0,y0,x1,y1)).getbbox() or (0,0,x1-x0,y1-y0)
   a,b,c,d=bbox;rects.append((x0+a,y0+b,c-a,d-b))
 cw=max(r[2] for r in rects)+8;ch=max(r[3] for r in rects)+8
 out=['[gd_resource type="SpriteFrames" format=3]',f'[ext_resource type="Texture2D" path="res://{path}" id="a"]']
 for i,(x,y,w,h) in enumerate(rects):out+=[f'[sub_resource type="AtlasTexture" id="f{i}"]','atlas = ExtResource("a")',f'region = Rect2({x},{y},{w},{h})',f'margin = Rect2({(cw-w)/2},{ch-h-3},{cw-w},{ch-h})']
 out+=['[resource]','animations = [']
 for anim,ids in animations.items():
  entries=', '.join('{"duration":1.0,"texture":SubResource("f%d")}'%i for i in ids)
  out.append('{"name":&"%s","speed":8.0,"loop":%s,"frames":[%s]},'%(anim,'false' if anim in ['death','attack','ultimate','hit'] else 'true',entries))
 out+= [']'];write('Art/Chapter3/'+name+'.tres','\n'.join(out));return ch
animations={'down':list(range(4)),'left':list(range(4,8)),'up':list(range(8,12)),'walk':list(range(4,8)),'idle':[0],'attack':list(range(12,16)),'ultimate':list(range(12,16)),'death':list(range(16,20)),'hit':[16,0],'hurt':[16,0]}
heights={name:atlas(name,'Art/Chapter3/'+name+'.png',4,5,animations) for name in ['doro','naiwa','gugu','q_penguin']}
heights['penguin']=atlas('penguin','NextPlayer/凑企鹅精灵图.png',4,3,{'down':[1,5,9,5],'left':[0,4,8,4],'up':[3,7,11,7],'walk':[0,4,8,4],'idle':[1],'attack':[0,4,8],'ultimate':[0,4,8],'death':[1,5,9],'hit':[5,1],'hurt':[5,1]})
def voice(name,folder,events):
 files=list(dict.fromkeys(v for vals in events.values() for v in vals));ids={f:'v'+str(i) for i,f in enumerate(files)}
 text='[gd_resource type="Resource" format=3]\n[ext_resource type="Script" path="res://Characters/voice_profile.gd" id="script"]\n'
 for f,i in ids.items():text+=f'[ext_resource type="AudioStream" path="res://Audio/{folder}/{f}" id="{i}"]\n'
 text+='[resource]\nscript = ExtResource("script")\nvolume_db = 0.0\nmax_duration = 5.0\nevent_cooldowns = {"hurt":3.0,"battle":10.0,"skill":5.0,"ultimate":6.0,"angry":8.0}\n'
 if name=='doro':
  captions=json.loads((ROOT/'Audio/Doro/lines.json').read_text(encoding='utf-8-sig'))
  text+='event_text = '+json.dumps({e:[v] for e,v in captions.items()},ensure_ascii=False)+'\n'
 for e,vals in events.items():text+=e+' = Array[AudioStream](['+', '.join(f'ExtResource("{ids[f]}")' for f in vals)+'])\n'
 write('Characters/Voices/'+name+'.tres',text)
for name,folder,idle,hurt,attack,death,ult in [
 ('q_penguin','Q币企鹅','Q币企鹅1.mp3','Q币企鹅生气.mp3','Q币企鹅2.mp3','Q币企鹅生气.mp3','Q币企鹅生气.mp3'),
 ('gugu','咕咕嘎嘎','咕嘎幸福.mp3','咕嘎嫌弃.mp3','咕嘎1.mp3','咕嘎疑问.mp3','咕嘎快乐.mp3'),
 ('penguin','凑企鹅','凑企鹅快乐.mp3','凑企鹅委屈.mp3','凑企鹅挑衅.mp3','凑企鹅难过至极.mp3','凑企鹅生气.mp3'),
 ('penguin_full','凑企鹅','凑企鹅挑衅.mp3','凑企鹅生气.mp3','凑企鹅非常生气忍无可忍.mp3','凑企鹅难过至极.mp3','凑企鹅非常生气忍无可忍.mp3'),
 ('naiwa','奶蛙','奶娃待命状态语音.mp3','奶娃搞事3音频.mp3','奶娃搞事音频.mp3','奶娃搞事3音频变声.mp3','奶娃认真语音.mp3'),
 ('naiwa_full','奶蛙','奶娃认真语音.mp3','奶娃搞事3音频.mp3','奶娃搞事2音频.mp3','奶娃搞事3音频变声.mp3','奶娃狂笑.mp3')]:
 voice(name,folder,{'idle':[idle],'battle':[attack],'hurt':[hurt],'death':[death],'skill':[attack],'ultimate':[ult],'angry':[hurt],'victory':[idle],'afraid':[hurt]})
voice('doro','Doro',{e:[e+'.wav'] for e in ['idle','hurt','death','angry','afraid','terrified','proud','skill','ultimate','victory','exhausted','battle']})
for name,title,art,hp,speed,size,ctype,weapon in [
 ('q_penguin','Q 币企鹅','q_penguin',100,145,44,0,'q_ak'),('doro','Doro','doro',400,125,48,0,'orange'),('gugu','咕咕嘎嘎','gugu',150,155,46,0,'penguin_rock'),
 ('naiwa_minion','奶娃幼体','naiwa',140,65, 30,1,'fists'),('naiwa_mini','奶娃小 BOSS','naiwa',1300,72,55,3,'fists'),('naiwa_full','奶娃完全体','naiwa',3200,60, 80,3,'fists'),
 ('penguin_mini','凑企鹅小 BOSS','penguin',2200,65,58,3,'penguin_rock'),('penguin_full','凑企鹅完全体','penguin',18000, 50,104,3,'penguin_rock')]:
 scale=size/(heights[art]-8);v=art
 text=f'''[gd_resource type="Resource" format=3]
[ext_resource type="Script" path="res://Characters/character_definition.gd" id="s"]
[ext_resource type="SpriteFrames" path="res://Art/Chapter3/{art}.tres" id="a"]
[ext_resource type="Resource" path="res://Characters/Voices/{v}.tres" id="v"]
[ext_resource type="Resource" path="res://Characters/Ultimates/{name if ctype==0 else 'creature'}.tres" id="u"]
[resource]
script = ExtResource("s")
character_id = "{name}"
display_name = "{title}"
character_type = {ctype}
max_health = {hp}
movement_speed = {speed}
default_weapon = "{weapon}"
animations = ExtResource("a")
reaction_animations = ExtResource("a")
ultimate_animations = ExtResource("a")
voice_profile = ExtResource("v")
ultimate = ExtResource("u")
sprite_scale = Vector2({scale},{scale})
sprite_offset = Vector2(0,{-size/2})
reaction_scale = Vector2({scale},{scale})
reaction_offset = Vector2(0,{-size/2})
ultimate_scale = Vector2({scale},{scale})
ultimate_offset = Vector2(0,{-size/2})
hurtbox_size = Vector2({size*.65},{size*.94})
hurtbox_offset = Vector2(0,{-size*.48})
foot_size = Vector2({min(18,size*.35)},10)
home_biome = "snow"
'''
 if name in ['q_penguin','doro','gugu']:text+=f'allowed_weapons = Array[String](["{weapon}"])\n'
 if name=='q_penguin':text+='allowed_chapters = Array[int]([3])\n'
 write('Characters/Definitions/'+name+'.tres',text)
 if ctype==0:
  ultname={'q_penguin':'决胜重炮 · 每场一次','doro':'橘子开花','gugu':'贴地滑翔'}[name]
  write('Characters/Ultimates/'+name+'.tres',f'[gd_resource type="Resource" format=3]\n[ext_resource type="Script" path="res://Characters/ultimate_definition.gd" id="s"]\n[resource]\nscript = ExtResource("s")\ndisplay_name = "{ultname}"\nweapon_id = "{weapon}"\ncooldown = {9999.0 if name=="q_penguin" else 8.0}\ninitial_charges = {1 if name=="q_penguin" else 3}\nmax_charges = {1 if name=="q_penguin" else 5}\n')
 # Actor scenes now own editable collision shapes. Never regenerate over them.
 elif not (ROOT/'Characters/Actors'/f'{name}.tscn').exists():
  raise RuntimeError(f'Missing authored actor scene {name}: duplicate an existing Characters/Actors scene and edit its shapes in Godot.')
print('Authored chapter3 character resources')

# Item regions retain source pixels and crop only via AtlasTexture metadata.
im=Image.open(ART/'weapons.png').convert('RGBA')
alpha=im.getchannel('A').point(lambda x:255 if x>128 else 0)
for i in range(8):
 x0,y0,x1,y1=round((i%4)*im.width/4),round((i//4)*im.height/2),round((i%4+1)*im.width/4),round((i//4+1)*im.height/2)
 a,b,c,d=alpha.crop((x0,y0,x1,y1)).getbbox()
 write(f'Art/Chapter3/item_{i}.tres',f'[gd_resource type="AtlasTexture" format=3]\n[ext_resource type="Texture2D" path="res://Art/Chapter3/weapons.png" id="a"]\n[resource]\natlas = ExtResource("a")\nregion = Rect2({x0+a},{y0+b},{c-a},{d-b})\n')

