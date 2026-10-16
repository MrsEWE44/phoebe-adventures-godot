"""Offline authoring of Chapter5 atlas resources; original images stay untouched."""
from pathlib import Path
from PIL import Image
import re
import json
from chapter5_frame_layout import layout
R=Path(__file__).resolve().parents[1]
def put(p,s):
 p=R/p;p.parent.mkdir(parents=True,exist_ok=True);p.write_text(s,encoding='utf-8')
sources={k:(f'NextPlayer/{v}精灵图.png',v) for k,v in [('miku','初音未来'),('reimu','博丽灵梦'),('omo','奥摩'),('omo_spin','奥摩360度旋转')]}
for ident in ['miku','reimu','omo','omo_spin']:
 sources[ident]=(f'Art/Chapter5/{ident}_rgba.png',sources[ident][1])
for family,folder in [('naiwa','奶娃'),('kangaroo','袋鼠狗'),('fatkangaroo','肥袋鼠狗'),('dog','奶娃狗'),('mouse','奶娃鼠')]:
 for color,cn in [('green','墨绿色'),('purple','紫色'),('red','红色')]:sources[family+'_'+color]=(next((R/'NextPlayer'/folder).glob('*'+cn+'*.png')).relative_to(R).as_posix(),folder)
 if family!='naiwa':sources[family+'_plain']=sources[family+'_purple']
put('Art/Chapter5/paper.gdshader','shader_type canvas_item;\nuniform bool remove_white=false;\nuniform bool grayscale=false;\nvarying vec4 tint;\nvoid vertex(){tint=COLOR;}\nvoid fragment(){vec4 c=texture(TEXTURE,UV);if(remove_white){float w=min(c.r,min(c.g,c.b));c.a*=1.0-smoothstep(.96,.995,w);}if(grayscale){c.rgb=vec3(dot(c.rgb,vec3(.299,.587,.114)));}COLOR=c*tint;}')
for name,white,gray in [('white',True,False),('plain',False,True)]:put(f'Art/Chapter5/{name}.tres',f'[gd_resource type="ShaderMaterial" format=3]\n[ext_resource type="Shader" path="res://Art/Chapter5/paper.gdshader" id="s"]\n[resource]\nshader = ExtResource("s")\nshader_parameter/remove_white = {str(white).lower()}\nshader_parameter/grayscale = {str(gray).lower()}\n')
layouts={}
for ident,(path,name) in sources.items():
 im=Image.open(R/path);rows,cw,ch=layout(im)
 layouts[ident]={'source':path,'canvas':[cw,ch],'rows':rows}
 s=f'[gd_resource type="SpriteFrames" format=3]\n[ext_resource type="Texture2D" path="res://{path}" id="t"]\n'
 for r,row in enumerate(rows):
  for c,(x0,y0,x1,y1) in enumerate(row):
   fw,fh=x1-x0,y1-y0
   s+=f'[sub_resource type="AtlasTexture" id="f{r}{c}"]\natlas = ExtResource("t")\nregion = Rect2({x0},{y0},{fw},{fh})\nmargin = Rect2({(cw-fw)//2},{ch-fh-4},{cw-fw},{ch-fh})\nfilter_clip = true\n'
 animations=[]
 for anim,row,cols in [('idle',0,[0,1,2,3]),('down',0,[0,1,2,3]),('left',1,[0,1,2,3]),('up',2,[0,1,2,3]),('walk',0,[0,1,2,3]),('attack',0,[0,1,2,3]),('hit',0,[1]),('hurt',0,[1]),('death',0,[2])]:
  if len(rows[row])==3 and len(cols)==4: cols=[0,1,0,2]
  if anim=='idle':cols=[0]
  frames=','.join('{"duration":1.0,"texture":SubResource("f%d%d")}'%(row,c) for c in cols)
  animations.append('{"name":&"%s","loop":%s,"speed":8.0,"frames":[%s]}'%(anim,'false' if anim in ['hit','death','attack'] else 'true',frames))
 if ident=='omo_spin':animations.append('{"name":&"spin","loop":true,"speed":18.0,"frames":['+','.join('{"duration":1.0,"texture":SubResource("f%d%d")}'%(r,c) for r,row in enumerate(rows) for c in range(len(row)))+']}')
 put(f'Art/Chapter5/{ident}.tres',s+'[resource]\nanimations = ['+',\n'.join(animations)+']\n')
 if ident=='omo_spin':continue
 player=ident in ['miku','reimu'];omo=ident=='omo'
 for stage,hp,height in ([('',210 if ident=='miku' else 240,62)] if player or omo else [('minion',100,37),('small',220,45),('mini',600,61),('full',1600,79)]):
  key=ident+('_'+stage if stage else '');weapon={'miku':'leek_wave','reimu':'crescent_scythe'}.get(ident,'fists');mat='white' if im.mode=='RGB' else ('plain' if ident.endswith('plain') else '')
  text=f'[gd_resource type="Resource" format=3]\n[ext_resource type="Script" path="res://Characters/character_definition.gd" id="s"]\n[ext_resource type="SpriteFrames" path="res://Art/Chapter5/{ident}.tres" id="a"]\n[ext_resource type="Resource" path="res://Characters/Ultimates/phoebe.tres" id="u"]\n'
  if mat:text+=f'[ext_resource type="Material" path="res://Art/Chapter5/{mat}.tres" id="m"]\n'
  if ident.startswith('naiwa'):text+='[ext_resource type="Resource" path="res://Characters/Voices/naiwa.tres" id="v"]\n'
  suffix={'green':'铁壁','purple':'幽咒','red':'狂焰'}.get(ident.split('_')[-1],'');tier={'minion':'幼体','small':'小型体','mini':'中级体','full':'完全体'}.get(stage,'')
  text+=f'[resource]\nscript = ExtResource("s")\ncharacter_id = "{key}"\ndisplay_name = "{name}{suffix}{tier}"\ncharacter_type = {0 if player else 2 if omo else 3 if stage in ["mini","full"] else 1}\nmax_health = {hp}\nmovement_speed = {150 if player else 110}\ndefault_weapon = "{weapon}"\nanimations = ExtResource("a")\nreaction_animations = ExtResource("a")\nultimate_animations = ExtResource("a")\nultimate = ExtResource("u")\nsprite_scale = Vector2({height/ch},{height/ch})\nsprite_offset = Vector2(0,{-height*.5})\nreaction_scale = Vector2({height/ch},{height/ch})\nreaction_offset = Vector2(0,{-height*.5})\nultimate_scale = Vector2({height/ch},{height/ch})\nultimate_offset = Vector2(0,{-height*.5})\nhurtbox_size = Vector2({height*.64},{height*.82})\nhurtbox_offset = Vector2(0,{-height*.47})\nfoot_size = Vector2(16,10)\nhome_biome = "hell"\n'
  if mat:text+='sprite_material = ExtResource("m")\n'
  if ident.startswith('naiwa'):text+='voice_profile = ExtResource("v")\n'
  if ident!='miku':text+='faces_right = true\n'
  text=text.replace(f'Vector2(0,{-height*.5})',f'Vector2(0,{-height*.5+4*height/ch})')
  if player:
   text=text.replace('Characters/Ultimates/phoebe.tres',f'Characters/Ultimates/{ident}.tres')
   text+=f'allowed_weapons = Array[String](["{weapon}"])\n'
  put(f'Characters/Definitions/{key}.tres',text)
  if not player and not omo:
   actor=(R/'Characters/Actors/naiwa_mini.tscn').read_text(encoding='utf-8').replace('Scence/Chapter3/enemy.gd','Scence/Chapter5/enemy.gd').replace('naiwa_mini',key).replace('Art/Chapter3/naiwa.tres',f'Art/Chapter5/{ident}.tres').replace('35.75,51.699999999999996',f'{height*.64},{height*.82}').replace('0,-26.4',f'0,{-height*.47}')
   actor=re.sub(r'(\[node name="AnimatedSprite2D"[^\n]+\]\ntexture_filter = 1\n)position = [^\n]+\nscale = [^\n]+',rf'\g<1>position = Vector2(0,{-height*.5+4*height/ch})\nscale = Vector2({height/ch},{height/ch})',actor)
   put(f'Characters/Actors/{key}.tscn',actor)
for i,name in enumerate(['熔炉狱卒','缚魂灯守','断翼刽子手','静默典狱长','炼狱织谎者','地狱终焉'],1):
 key=f'hell_boss_{i}';text=(R/'Characters/Definitions/demon.tres').read_text(encoding='utf-8')
 for pattern,value in [(r'character_id = "[^"]+"',f'character_id = "{key}"'),(r'display_name = "[^"]+"',f'display_name = "{name}"'),(r'max_health = \d+',f'max_health = {2000+i*550}'),(r'sprite_scale = Vector2\([^\n]+',f'sprite_scale = Vector2({3+i*.18},{3+i*.18})'),(r'hurtbox_frames = .*',''),(r'hurtbox_size = .*','hurtbox_size = Vector2(64,76)'),(r'hurtbox_offset = .*','hurtbox_offset = Vector2(0,-38)')]:text=re.sub(pattern,value,text)
 text=re.sub(r'sprite_offset = .*',f'sprite_offset = Vector2({-3.5*(3+i*.18)}, {-10*(3+i*.18)})',text)
 put(f'Characters/Definitions/{key}.tres',text)
 actor=(R/'Characters/Actors/naiwa_mini.tscn').read_text(encoding='utf-8').replace('Scence/Chapter3/enemy.gd','Scence/Chapter5/enemy.gd').replace('naiwa_mini',key).replace('Art/Chapter3/naiwa.tres','Characters/Animations/demon.tres').replace('35.75,51.699999999999996','64,76').replace('0,-26.4','0,-38')
 actor+='[node name="HellCrown" type="Polygon2D" parent="."]\nposition = Vector2(0,-74)\npolygon = PackedVector2Array(-25,0,-29,-21,-10,-9,0,-26,10,-9,29,-21,25,0)\ncolor = Color(1,0.3,0.1,1)\n'
 put(f'Characters/Actors/{key}.tscn',actor)
for ident,name,damage,icon in [('leek_wave','缚魂大葱',68,'<path d="M17 56L40 26L55 8M40 26L31 5M40 26L50 2" stroke="#68e393" stroke-width="9"/><path d="M17 56L34 36" stroke="#fffbdc" stroke-width="12"/>'),('crescent_scythe','赤月大镰刀',180,'<path d="M18 61L45 13" stroke="#bd7550" stroke-width="5"/><path d="M14 6Q60-4 58 35Q45 12 14 6Z" fill="#e8eeff" stroke="#e56681" stroke-width="3"/>')]:
 put(f'Art/Chapter5/{ident}.svg','<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64">'+icon+'</svg>')
 put(f'Weapons/Definitions/{ident}.gd',f'extends "res://Weapons/weapon_definition.gd"\nfunc _init() -> void:\n\tweapon_id="{ident}"\n\tweapon_name="{name}"\n\tkind="ranged"\n\tdamage_type="magic"\n\tdamage={damage}\n\tcooldown=.65\n\tattack_range=240\n\ttexture=preload("res://Art/Chapter5/{ident}.svg")\n\tdisplay_width=42\n\tdrop_enabled=false\n')
put('Art/Chapter5/frame_layout.json',json.dumps(layouts,ensure_ascii=False,indent=2))
print('Authored Chapter5 sprite atlases, actor scenes, definitions and two weapons.')
