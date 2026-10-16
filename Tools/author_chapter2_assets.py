"""One-time resource authoring. Leaves source PNG pixels untouched; runtime loads saved resources."""
from pathlib import Path
import json
import numpy as np
import soundfile as sf
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
def write(path, text):
    p = ROOT / path
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(text, encoding='utf-8')

def frames(path, image, rows, rects, width):
    lines = ['[gd_resource type="SpriteFrames" format=3]', f'[ext_resource type="Texture2D" path="res://{image}" id="1"]']
    for r, (y,h) in enumerate(rects):
        for c in range(4):
            lines += [f'[sub_resource type="AtlasTexture" id="r{r}c{c}"]', 'atlas = ExtResource("1")', f'region = Rect2({c*width}, {y}, {width}, {h})']
    animations=[]
    for name,r,loop,speed in rows:
        cells=', '.join('{"duration": 1.0, "texture": SubResource("r%dc%d")}'%(r,c) for c in range(4))
        animations.append('{"name": &"%s", "loop": %s, "speed": %s, "frames": [%s]}'%(name,str(loop).lower(),speed,cells))
    lines += ['[resource]', 'animations = ['+',\n'.join(animations)+']']
    write(path,'\n'.join(lines)+'\n')

ikun_rects=[(0,237),(214,237),(432,237),(649,237),(870,237),(1080,237),(1358,237)]
frames('Characters/Animations/ikun.tres','Art/Chapter2/ikun_sheet.png',[(n,r,True,7) for n,r in [('idle',0),('down',1),('left',2),('up',3)]],ikun_rects,237)
frames('Characters/Animations/ikun_states.tres','Art/Chapter2/ikun_sheet.png',[('hit',4,False,11),('hurt',4,True,4),('death',5,False,5)],ikun_rects,237)
frames('Characters/Animations/ikun_ultimate.tres','Art/Chapter2/ikun_sheet.png',[('ultimate',6,False,6)],ikun_rects,237)
write('Characters/Definitions/ikun.tres','''[gd_resource type="Resource" format=3]
[ext_resource type="Script" path="res://Characters/character_definition.gd" id="1"]
[ext_resource type="SpriteFrames" path="res://Characters/Animations/ikun.tres" id="2"]
[ext_resource type="SpriteFrames" path="res://Characters/Animations/ikun_states.tres" id="3"]
[ext_resource type="SpriteFrames" path="res://Characters/Animations/ikun_ultimate.tres" id="4"]
[ext_resource type="Resource" path="res://Characters/Voices/ikun.tres" id="5"]
[ext_resource type="Resource" path="res://Characters/Ultimates/ikun.tres" id="6"]
[resource]
script = ExtResource("1")
character_id = "ikun"
display_name = "坤坤"
max_health = 100
max_energy = 200
movement_speed = 145.0
default_weapon = "basketball"
skill_weapon = "basketball"
skill_projectiles = 3
faces_right = true
animations = ExtResource("2")
reaction_animations = ExtResource("3")
ultimate_animations = ExtResource("4")
voice_profile = ExtResource("5")
ultimate = ExtResource("6")
sprite_scale = Vector2(0.19,0.19)
sprite_offset = Vector2(0,-19)
reaction_scale = Vector2(0.19,0.19)
reaction_offset = Vector2(0,-19)
ultimate_scale = Vector2(0.19,0.19)
ultimate_offset = Vector2(0,-21)
hurtbox_size = Vector2(30,38)
hurtbox_offset = Vector2(0,-19)
''')
write('Characters/Ultimates/ikun.tres','''[gd_resource type="Resource" format=3]
[ext_resource type="Script" path="res://Characters/ultimate_definition.gd" id="1"]
[resource]
script = ExtResource("1")
display_name = "三分绝杀"
mode = "shot"
damage = 105
projectile_count = 3
projectile_speed = 440.0
projectile_range = 620.0
radius = 85.0
windup = 0.65
cooldown = 3.0
weapon_id = "basketball"
tint = Color(1,0.65,0.18,1)
''')
write('Player/Ikun.gd','extends "res://Characters/playable_character.gd"\n\nfunc _init() -> void:\n\tdefinition = preload("res://Characters/Definitions/ikun.tres")\n')
write('Player/Ikun.tscn','''[gd_scene format=3]
[ext_resource type="Script" path="res://Player/Ikun.gd" id="1"]
[ext_resource type="Resource" path="res://Characters/Definitions/ikun.tres" id="2"]
[sub_resource type="RectangleShape2D" id="Foot"]
size = Vector2(16,10)
[node name="Ikun" type="CharacterBody2D" groups=["players"]]
collision_layer = 1
collision_mask = 2
script = ExtResource("1")
definition = ExtResource("2")
[node name="CollisionShape2D" type="CollisionShape2D" parent="."]
shape = SubResource("Foot")
[node name="AnimatedSprite2D" type="AnimatedSprite2D" parent="."]
texture_filter = 1
[node name="Camera2D" type="Camera2D" parent="."]
zoom = Vector2(2,2)
position_smoothing_enabled = true
''')

# Irregular imagegen row spacing is represented explicitly in AtlasTexture regions.
aquatic=[('reef_crab','珊瑚钳蟹',0,58,52,False,1,36),('reef_shark','巡游礁鲨',1,76,74,False,1,42),('jellyfish','电光水母',2,62,38,True,1,38),('abyss_king','深渊蟹王',3,620,37,True,3,58)]
rects=[(42,250),(342,205),(551,332),(881,325)]
for id,name,row,hp,speed,ranged,role,size in aquatic:
    frames(f'Characters/Animations/{id}.tres','Art/Chapter2/aquatic.png',[(n,0,n not in ['death','hit'],6 if n!='attack' else 10) for n in ['default','idle','walk','attack','hit','death','ultimate']],[rects[row]],317.25)
    scale=size/317.25
    height=rects[row][1]*scale
    ult='blood_monster' if ranged else 'creature'
    if role==3: ult='abyss_king'
    write(f'Characters/Definitions/{id}.tres',f'''[gd_resource type="Resource" format=3]
[ext_resource type="Script" path="res://Characters/character_definition.gd" id="1"]
[ext_resource type="SpriteFrames" path="res://Characters/Animations/{id}.tres" id="2"]
[ext_resource type="Resource" path="res://Characters/Ultimates/{ult}.tres" id="3"]
[resource]
script = ExtResource("1")
character_id = "{id}"
display_name = "{name}"
character_type = {role}
max_health = {hp}
movement_speed = {speed}.0
aquatic = true
ranged_attack = {str(ranged).lower()}
animations = ExtResource("2")
ultimate = ExtResource("3")
sprite_scale = Vector2({scale},{scale})
sprite_offset = Vector2(0,{-height*.45})
hurtbox_size = Vector2({size*.86},{height*.84})
hurtbox_offset = Vector2(0,{-height*.45})
''')
    write(f'Characters/Actors/{id}.tscn',f'''[gd_scene format=3]
[ext_resource type="Script" path="res://Combat/enemy.gd" id="1"]
[ext_resource type="Resource" path="res://Characters/Definitions/{id}.tres" id="2"]
[node name="{id}" type="CharacterBody2D"]
script = ExtResource("1")
definition = ExtResource("2")
''')
write('Characters/Ultimates/abyss_king.tres','''[gd_resource type="Resource" format=3]
[ext_resource type="Script" path="res://Characters/ultimate_definition.gd" id="1"]
[resource]
script = ExtResource("1")
display_name = "深渊潮汐"
mode = "area"
damage = 32
radius = 115.0
windup = 1.3
cooldown = 9.0
tint = Color(0.2,0.8,1,1)
''')
# Existing Enemys sprite strips remain the source for these water-corrupted guardians.
for source,id,name,hp in [('orc','drowned_guard','溺水遗迹卫士',100),('blood_monster','tide_sorcerer','潮汐血灵',480)]:
    text=(ROOT/f'Characters/Definitions/{source}.tres').read_text(encoding='utf-8')
    import re
    text=re.sub(r'character_id = ".*"',f'character_id = "{id}"',text)
    text=re.sub(r'display_name = ".*"',f'display_name = "{name}"',text)
    text=re.sub(r'max_health = \d+',f'max_health = {hp}',text)+'\naquatic = true\n'
    write(f'Characters/Definitions/{id}.tres',text)
    scene=(ROOT/f'Characters/Actors/{source}.tscn').read_text(encoding='utf-8').replace(f'Definitions/{source}.tres',f'Definitions/{id}.tres')
    write(f'Characters/Actors/{id}.tscn',scene)

# Per-cell tight UVs, no raster crop/repaint.
im=Image.open(ROOT/'Art/Chapter2/weapons.png')
a=np.asarray(im)[:,:,3]>80
weapon_rects=[]
for r in range(2):
    for c in range(4):
        x0,x1=round(c*im.width/4),round((c+1)*im.width/4)
        y0,y1=round(r*im.height/2),round((r+1)*im.height/2)
        ys,xs=np.where(a[y0:y1,x0:x1]); weapon_rects.append((x0+int(xs.min()),y0+int(ys.min()),int(xs.max()-xs.min()+1),int(ys.max()-ys.min()+1)))
weapon_rects[0]=(84,130,265,266)
weapon_rects[1]=(425,175,440,184)
write('Weapons/chapter2_art.gd','extends RefCounted\nconst REGIONS = ['+', '.join('Rect2(%s)'%','.join(map(str,r)) for r in weapon_rects)+']\n\nstatic func texture(index: int) -> Texture2D:\n\tvar atlas := AtlasTexture.new()\n\tatlas.atlas = preload("res://Art/Chapter2/weapons.png")\n\tatlas.region = REGIONS[index]\n\treturn atlas\n')
weapons=[('basketball','弹跳篮球',0,4,26,0,.46,380,260,20,16,0,1,False),('harpoon','潮猎鱼叉枪',1,5,30,2,.42,560,520,32,20,0,1,True),('coral_trident','珊瑚三叉戟',2,7,35,0,.48,72,420,36,16,0,0,True),('torpedo','深海鱼雷炮',3,6,58,8,1.05,480,270,36,22,62,0,True)]
for i,(id,name,tex,proj,damage,cost,cd,reach,speed,width,pwidth,blast,pierce,drop) in enumerate(weapons):
    kind='melee' if id=='coral_trident' else 'ranged'
    write(f'Weapons/Definitions/{id}.gd',f'''extends "res://Weapons/weapon_definition.gd"

func _init() -> void:
\tweapon_id = "{id}"
\tweapon_name = "{name}"
\tkind = "{kind}"
\tdamage = {damage}
\tenergy_cost = {cost}
\tcooldown = {cd}
\tattack_range = {reach}.0
\tprojectile_speed = {speed}.0
\tdisplay_width = {width}.0
\tprojectile_width = {pwidth}.0
\tprojectile_hit_radius = {5 if id=='basketball' else 2.5}
\texplosion_radius = {blast}.0
\tpierce = {pierce}
\tdrop_enabled = {str(drop).lower()}
\tdrop_order = {20+i}
\taquatic_multiplier = {1.6 if id!='basketball' else 1.0}
\tbounces = {2 if id=='basketball' else 0}
\ttexture = preload("res://Weapons/chapter2_art.gd").texture({tex})
\tprojectile_texture = preload("res://Weapons/chapter2_art.gd").texture({proj})
''')

# Normalize the three supplied recordings, keeping each recording's original voice.
folder=ROOT/'Audio/坤坤'
sources=['坤坤你干嘛哎哟.mp3','坤坤你干嘛哎哟完整.mp3','坤坤amagi.mp3']
manifest=[]
for i,name in enumerate(sources):
    samples,sr=sf.read(folder/name,always_2d=True)
    rms=float(np.sqrt(np.mean(samples*samples)))
    gain=min(.88/max(float(np.max(np.abs(samples))),1e-7),10**(-18/20)/max(rms,1e-7))
    samples*=gain
    dest=folder/'Gameplay'/f'voice_{i+1}.wav';dest.parent.mkdir(exist_ok=True)
    sf.write(dest,samples,sr,subtype='PCM_16')
    manifest.append({'source':name,'output':dest.name,'duration':len(samples)/sr,'gain_db':round(20*np.log10(gain),2)})
write('Audio/坤坤/Gameplay/manifest.json',json.dumps(manifest,ensure_ascii=False,indent=2))
write('Audio/坤坤/Gameplay/README.md','# 坤坤游戏语音\n三条原录音仅做响度归一，不合成新台词或克隆声音。受击与死亡随机使用前两条，待机随机使用全部三条。单次最多播放 5 秒，死亡可打断其它台词。完整素材保留在父目录。\n')
voice=['[gd_resource type="Resource" format=3]','[ext_resource type="Script" path="res://Characters/voice_profile.gd" id="1"]']
for i in range(3): voice.append(f'[ext_resource type="AudioStream" path="res://Audio/坤坤/Gameplay/voice_{i+1}.wav" id="v{i}"]')
voice+=['[resource]','script = ExtResource("1")','volume_db = 0.0','max_duration = 5.0']
for event,ids in {'idle':[0,1,2],'hurt':[0,1],'death':[0,1],'battle':[2],'angry':[1],'afraid':[0],'terrified':[1],'proud':[2],'skill':[2],'ultimate':[2],'victory':[2],'exhausted':[0]}.items():
    voice.append(f'{event} = Array[AudioStream](['+', '.join(f'ExtResource("v{i}")' for i in ids)+'])')
voice+=['event_cooldowns = {"hurt": 3.0, "battle": 12.0, "skill": 8.0, "angry": 10.0}','event_text = {"idle":["（即兴哼唱）"],"hurt":["你干嘛，哎哟！"],"death":["哎哟……"],"ultimate":["（三分绝杀！）"],"skill":["（连投！）"]}']
write('Characters/Voices/ikun.tres','\n'.join(voice)+'\n')
print('Authored chapter 2 character, enemy, weapon and normalized voice resources.')
