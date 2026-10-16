"""Offline scene/resource authoring. Runtime only reads the resulting editable nodes.

No source bitmap is modified. AtlasTexture regions reuse the supplied 4x3 sheets.
Map outlines are manually traced in normalized image coordinates (0..1000).
"""
from pathlib import Path
import json
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
def write(path, text):
    target = ROOT / path
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(text, encoding='utf-8')
def vec(p): return f'Vector2({p[0]}, {p[1]})'
def packed(points): return 'PackedVector2Array('+', '.join(str(v) for p in points for v in p)+')'
def simplify(points, tolerance=4.0):
    if len(points)<3:return points
    a,b=points[0],points[-1]; dx,dy=b[0]-a[0],b[1]-a[1]
    denom=(dx*dx+dy*dy)**.5
    distances=[abs(dx*(a[1]-p[1])-(a[0]-p[0])*dy)/denom if denom else ((a[0]-p[0])**2+(a[1]-p[1])**2)**.5 for p in points]
    idx=max(range(len(points)),key=lambda i:distances[i])
    if distances[idx]<=tolerance:return [a,b]
    return simplify(points[:idx+1],tolerance)[:-1]+simplify(points[idx:],tolerance)

# One connected perimeter per arena; graves/walls inside the floor have separate shapes.
MAPS = [
 ('哥特沼泽遗迹传送之路', '失声的琴房', (165,505),(922,510),(500,490), [(40,510),(55,475),(110,475),(125,470),(230,478),(350,480),(395,425),(430,405),(475,365),(475,240),(460,220),(460,140),(490,120),(535,145),(550,190),(515,230),(515,365),(560,410),(610,445),(645,478),(870,475),(890,465),(950,500),(960,545),(935,570),(892,555),(865,530),(645,535),(610,590),(530,650),(525,700),(480,700),(480,645),(430,605),(380,548),(350,535),(235,535),(130,520),(110,555),(85,590),(50,575)], []),
 ('幽冥沼泽墓园传送之路','黄白和弦',(160,475),(935,475),(500,465),[(35,465),(55,440),(100,440),(120,460),(170,445),(185,420),(220,420),(240,450),(390,465),(400,400),(445,370),(467,342),(467,300),(450,285),(450,240),(485,225),(520,240),(525,285),(515,305),(515,345),(570,400),(612,445),(620,462),(870,462),(900,440),(950,445),(975,485),(955,520),(920,535),(885,505),(620,505),(620,555),(555,595),(520,618),(515,670),(475,670),(475,615),(427,585),(393,530),(390,495),(240,490),(205,475),(175,480),(130,510),(100,505),(95,565),(45,565)],[]),
 ('幽绿沼泽中的双界传送门','无法停止的歌',(180,500),(925,415),(520,500),[(50,390),(90,380),(120,405),(150,463),(208,504),(315,492),(400,470),(404,408),(430,366),(470,340),(470,280),(480,245),(440,205),(440,175),(475,147),(495,155),(500,190),(545,243),(605,265),(623,325),(605,405),(640,450),(670,486),(750,510),(817,510),(860,470),(893,435),(906,401),(948,385),(975,415),(952,469),(905,492),(830,540),(755,550),(670,526),(638,558),(594,615),(545,652),(548,716),(610,785),(655,806),(645,845),(610,855),(567,808),(508,763),(497,675),(500,643),(450,620),(395,573),(398,524),(318,536),(210,544),(146,505),(101,474),(65,468)],[(480,365,530,407),(440,515,470,550)]),
 ('幽光沼泽中的双重传送门','看清杂音',(175,485),(920,483),(520,490),[(58,480),(78,445),(125,440),(160,460),(340,460),(390,423),(432,377),(440,335),(480,295),(495,250),(535,242),(570,264),(600,315),(630,335),(635,385),(612,429),(650,460),(835,460),(875,438),(915,434),(954,472),(965,510),(930,540),(887,531),(865,505),(650,510),(640,573),(585,632),(558,672),(540,731),(495,735),(478,686),(454,649),(406,609),(379,560),(377,510),(155,510),(130,551),(83,551),(60,527)],[]),
 ('幽暗沼泽中的哥特遗迹秘境','同化的回声',(170,509),(920,519),(515,510),[(42,516),(65,471),(110,471),(143,475),(347,475),(386,416),(420,345),(460,290),(490,270),(491,228),(529,228),(536,273),(573,284),(650,289),(680,273),(705,299),(710,331),(691,353),(690,423),(690,470),(871,476),(900,495),(930,490),(965,520),(955,560),(918,584),(889,560),(870,534),(696,537),(675,592),(619,666),(560,732),(548,789),(492,790),(490,746),(440,700),(400,639),(366,568),(351,535),(145,535),(120,580),(65,580),(43,560)],[(390,476,410,515),(635,486,650,523)]),
 ('哥特沼泽遗迹双门战场','真身与伪装',(170,490),(939,478),(530,476),[(25,464),(55,438),(100,450),(140,470),(245,465),(315,441),(355,410),(380,356),(410,348),(431,333),(480,331),(500,286),(480,260),(480,230),(520,224),(550,248),(550,281),(525,320),(580,331),(640,355),(670,386),(701,415),(747,437),(843,479),(900,474),(920,455),(955,449),(972,487),(949,520),(910,522),(882,504),(839,514),(740,480),(696,459),(659,534),(630,591),(589,631),(588,697),(628,759),(665,785),(660,820),(629,835),(590,801),(548,755),(531,703),(531,651),(480,639),(438,613),(408,566),(385,512),(329,478),(248,506),(139,510),(105,526),(67,542),(30,511)],[(556,549,573,576)]),
 ('诅咒沼泽双生传送门','两分钟的排练',(165,460),(930,458),(500,475),[(25,453),(55,430),(95,432),(125,441),(234,445),(268,459),(380,460),(405,409),(442,370),(485,347),(482,309),(530,300),(536,349),(570,379),(598,423),(611,459),(877,447),(895,431),(947,430),(975,459),(970,500),(934,523),(895,515),(875,485),(620,501),(607,546),(570,584),(537,608),(530,666),(503,681),(473,666),(480,608),(433,580),(405,551),(388,502),(278,499),(236,485),(133,489),(115,535),(93,565),(62,550),(47,501)],[]),
 ('诅咒沼泽的双重传送门','背叛的指挥者',(170,452),(936,452),(510,505),[(25,456),(55,430),(98,422),(128,439),(300,440),(350,399),(409,345),(435,310),(480,271),(458,240),(425,210),(443,185),(485,198),(518,254),(564,261),(594,219),(620,216),(627,280),(650,340),(690,378),(715,440),(879,437),(910,425),(953,439),(975,468),(950,500),(917,498),(883,480),(714,491),(670,536),(652,590),(627,649),(671,710),(707,743),(700,775),(664,784),(610,733),(573,701),(560,639),(495,661),(445,648),(388,615),(344,557),(300,500),(290,617),(260,663),(207,740),(173,756),(143,739),(149,713),(190,700),(230,632),(260,593),(260,479),(130,482),(110,525),(55,525)],[(475,445,565,493),(414,433,436,465)]),
 ('紫色封印至绿色传送门的幽暗沼泽墓园','被操纵的真相',(175,435),(922,544),(488,508),[(24,398),(55,379),(100,386),(129,406),(305,443),(347,415),(391,375),(450,367),(488,349),(493,308),(504,245),(490,230),(493,211),(533,204),(548,223),(535,250),(520,309),(514,362),(548,396),(563,442),(599,485),(859,531),(890,534),(916,522),(957,543),(972,580),(948,609),(914,612),(887,586),(859,571),(598,526),(560,568),(509,607),(463,633),(442,682),(421,729),(446,766),(442,796),(412,802),(386,769),(360,754),(364,714),(400,675),(416,627),(388,599),(355,565),(336,529),(314,486),(133,446),(102,490),(67,480),(40,453)],[(401,411,433,439),(492,414,517,436)]),
 ('幽暗沼泽哥特遗迹迷宫','最后的合奏',(170,466),(937,478),(523,481),[(28,455),(55,437),(101,443),(126,450),(319,450),(351,417),(376,390),(407,373),(466,370),(504,361),(509,313),(524,252),(531,209),(532,170),(548,148),(577,150),(589,178),(577,209),(560,253),(548,317),(549,369),(597,400),(629,442),(685,469),(878,477),(918,465),(954,489),(976,519),(954,548),(919,545),(886,514),(684,507),(639,547),(605,580),(554,610),(550,673),(541,735),(557,774),(552,801),(525,805),(511,776),(484,769),(482,747),(508,727),(517,672),(518,607),(466,590),(423,570),(389,526),(350,486),(323,480),(129,480),(111,520),(75,530),(40,490)],[(570,405,598,438)])
]

def author_sprites(only=None):
    sources={'mutsumi':'睦子米','soyo':'soyo狸','anon':'千早爱音','anon_glasses':'千早爱音戴眼镜','anon_dragon':'千早爱音奶龙','tensura':'天素罗','weiro':'天素罗伪罗'}
    for ident,source in sources.items():
        if only is not None and ident not in only: continue
        path='Art/Chapter4/anon_glasses_transparent.png' if ident=='anon_glasses' else f'NextPlayer/{source}精灵图.png'
        w,h=Image.open(ROOT/path).size; cw,ch=w/4,h/3
        # These sheets are not evenly spaced: equal thirds cut off feet/tails.
        # Author atlas regions only; leave the source PNG pixels untouched.
        fitted = ident in ['anon_glasses','anon_dragon']
        if fitted:
            pixels=Image.open(ROOT/path).convert('RGBA')
            xs=[0,362,724,1086,1448] if ident=='anon_glasses' else [100,408,744,1056,1448]
            ys=[0,401,750,1086] if ident=='anon_glasses' else [0,369,726,1086]
            cw,ch=402,402
        text=f'[gd_resource type="SpriteFrames" format=3]\n[ext_resource type="Texture2D" path="res://{path}" id="tex"]\n'
        for row in range(3):
            for col in range(4):
                if fitted:
                    occupied=[(x,y) for y in range(ys[row],ys[row+1]) for x in range(xs[col],xs[col+1]) if pixels.getpixel((x,y))[3]>=32]
                    left=min(p[0] for p in occupied); top=min(p[1] for p in occupied)
                    width=max(p[0] for p in occupied)-left+1; height=max(p[1] for p in occupied)-top+1
                    text+=f'[sub_resource type="AtlasTexture" id="f{row}_{col}"]\natlas = ExtResource("tex")\nregion = Rect2({left}, {top}, {width}, {height})\nmargin = Rect2({(cw-width)/2}, {ch-height}, {cw-width}, {ch-height})\n'
                else:
                    text+=f'[sub_resource type="AtlasTexture" id="f{row}_{col}"]\natlas = ExtResource("tex")\nregion = Rect2({col*cw}, {row*ch}, {cw}, {ch})\n'
        animations=[]
        for name,col,rows in [('idle',1,[0]),('down',1,[0,1,0,2]),('up',3,[0,1,0,2]),('left',0 if ident in ['tensura','anon_dragon'] else 2,[0,1,0,2]),('walk',1,[0,1,0,2]),('attack',1,[1,2]),('hurt',1,[0]),('death',1,[0])]:
            frames=', '.join('{"duration":1.0,"texture":SubResource("f%d_%d")}'%(r,col) for r in rows)
            animations.append('{"name":&"%s","speed":8.0,"loop":%s,"frames":[%s]}'%(name,'false' if name in ['hurt','death','attack'] else 'true',frames))
        write(f'Art/Chapter4/{ident}.tres',text+'[resource]\nanimations = ['+',\n'.join(animations)+']\n')
        for variant,height in ([(ident,60)] if ident not in ['tensura','weiro'] else [(ident+'_minion',40),(ident+'_mini',64),(ident+'_full',86)]):
            player=ident not in ['tensura','weiro']; hp=180 if player else (110 if variant.endswith('minion') else 850 if variant.endswith('mini') else 2300)
            weapon={'mutsumi':'pink_cello','soyo':'ivory_cello'}.get(ident,'voice_wave')
            voice='anon' if ident.startswith('anon') else 'mutsumi' if ident=='mutsumi' else 'tensura'
            data=f'''[gd_resource type="Resource" format=3]
[ext_resource type="Script" path="res://Characters/character_definition.gd" id="s"]
[ext_resource type="SpriteFrames" path="res://Art/Chapter4/{ident}.tres" id="a"]
[ext_resource type="Resource" path="res://Characters/Voices/{voice}.tres" id="v"]
[ext_resource type="Resource" path="res://Characters/Ultimates/phoebe.tres" id="u"]
[resource]
script = ExtResource("s")
character_id = "{variant}"
display_name = "{source}{'幼体' if variant.endswith('minion') else '中级体' if variant.endswith('mini') else '完全体' if variant.endswith('full') else ''}"
character_type = {0 if player else 1 if variant.endswith('minion') else 3}
max_health = {hp}
movement_speed = {145 if player else 85}
damage_multiplier = {1.6 if ident=='soyo' else 1.0}
default_weapon = "{weapon}"
allowed_weapons = Array[String]([{','.join(json.dumps(x) for x in ([weapon,'music_drums','conductor'] if player else []))}])
animations = ExtResource("a")
reaction_animations = ExtResource("a")
ultimate_animations = ExtResource("a")
voice_profile = ExtResource("v")
ultimate = ExtResource("u")
sprite_scale = Vector2({height/ch},{height/ch})
sprite_offset = Vector2(0,{-height/2})
reaction_scale = Vector2({height/ch},{height/ch})
reaction_offset = Vector2(0,{-height/2})
ultimate_scale = Vector2({height/ch},{height/ch})
ultimate_offset = Vector2(0,{-height/2})
hurtbox_size = Vector2({height*(.7 if player else .88)},{height*.9})
hurtbox_offset = Vector2(0,{-height*.48})
foot_size = Vector2(18,10)
home_biome = "swamp"
'''
            if player:
                data=data.replace('res://Characters/Ultimates/phoebe.tres',f'res://Characters/Ultimates/{ident}.tres')
                write(f'Characters/Ultimates/{ident}.tres',f'''[gd_resource type="Resource" format=3]
[ext_resource type="Script" path="res://Characters/ultimate_definition.gd" id="s"]
[resource]
script = ExtResource("s")
display_name = "{'终曲·直线共振' if ident=='soyo' else '回响·环形共鸣'}"
damage = 900.0
radius = 240.0
cooldown = 12.0
weapon_id = "{weapon}"
''')
            write(f'Characters/Definitions/{variant}.tres',data)
            if not player:
                actor=(ROOT/'Characters/Actors/naiwa_mini.tscn').read_text(encoding='utf8').replace('res://Scence/Chapter3/enemy.gd','res://Scence/Chapter4/enemy.gd').replace('naiwa_mini',variant).replace('res://Art/Chapter3/naiwa.tres',f'res://Art/Chapter4/{ident}.tres').replace('35.75,51.699999999999996',f'{height*.88},{height*.9}').replace('0,-26.4',f'0,{-height*.48}')
                write(f'Characters/Actors/{variant}.tscn',actor)

def author_voices():
    import runpy
    runpy.run_path(str(ROOT/'Tools/build_named_voice_profiles.py'),run_name='__main__')

def author_soyo_full():
    text=(ROOT/'Characters/Definitions/soyo.tres').read_text(encoding='utf8')
    text=text.replace('damage_multiplier = 1.6','damage_multiplier = 2.0')
    text=text.replace('character_id = "soyo"','character_id = "soyo_full"').replace('display_name = "soyo狸"','display_name = "soyo狸·完全体"').replace('max_health = 180','max_health = 320').replace('default_weapon = "ivory_cello"','default_weapon = "conductor"')
    text=text.replace('allowed_weapons = Array[String](["ivory_cello","music_drums","conductor"])','allowed_weapons = Array[String](["conductor"])')
    write('Characters/Definitions/soyo_full.tres',text)

def author_weapons():
    for ident,name,color,damage in [('pink_cello','粉色大提琴','#ed91c5',42),('ivory_cello','黄白大提琴','#ffe8a0',62),('voice_wave','主唱声波','#f698c5',18),('music_drums','共振架子鼓','#9bcfeb',90),('conductor','音乐指挥棒','#f5e8be',100)]:
        body=f'<path d="M27 24 C6 19 4 37 17 42 C6 55 18 65 32 60 C47 65 57 53 44 42 C57 30 48 20 36 24 L35 5 L29 5Z" fill="{color}" stroke="#523b61" stroke-width="3"/><path d="M30 7V57 M34 7V57 M22 39q-8 5 0 9 M41 39q8 5 0 9 M32 60v4" fill="none" stroke="#805375" stroke-width="2"/>'
        if ident=='conductor': body='<path d="M10 54L51 8" stroke="#fff5cc" stroke-width="6"/><path d="M8 58L23 40" stroke="#be8842" stroke-width="9"/><circle cx="51" cy="8" r="6" fill="#a5ffe2"/>'
        if ident=='music_drums': body='<ellipse cx="32" cy="32" rx="23" ry="17" fill="#cef4ff" stroke="#d9aa61" stroke-width="4"/><path d="M9 32v17q23 20 46 0V32 M17 6l32 40 M46 6L16 43" fill="none" stroke="#d9aa61" stroke-width="5"/>'
        if ident=='voice_wave': body='<path d="M14 24q20-22 37 0 M10 35q23-28 45 0 M7 49q25-30 52 0" fill="none" stroke="#ff9ccd" stroke-width="5"/>'
        write(f'Art/Chapter4/{ident}.svg','<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64">'+body+'</svg>')
        write(f'Weapons/Definitions/{ident}.gd',f'''extends "res://Weapons/weapon_definition.gd"
func _init() -> void:
	weapon_id="{ident}"
	weapon_name="{name}"
	kind="ranged"
	damage_type="magic"
	damage={damage}
	cooldown={1.0 if ident=='music_drums' else .6}
	attack_range=360.0
	texture=preload("res://Art/Chapter4/{ident}.svg")
	display_width={0 if ident=='voice_wave' else 38}
	drop_enabled=false
	auto_fire={'true' if ident=='voice_wave' else 'false'}
''')

def gate(name,p,index,target,color='0.3, 1, 0.7, 1'):
    return f'''[node name="{name}" type="Area2D" parent="Portals"]
position = {vec(p)}
collision_layer = 32
collision_mask = 1
script = ExtResource("gate")
portal_id = &"{'music_%02d'%(index-27) if target==0 else name}"
level_index = {index}
target_chapter = {target}
portal_color = Color({', '.join(str(float(c)) for c in color.split(','))})
visual_offset = Vector2(0,-35)
visual_radius = 20.0
[node name="CollisionShape2D" type="CollisionShape2D" parent="Portals/{name}"]
shape = SubResource("Gate")
[node name="Barrier" type="StaticBody2D" parent="Portals/{name}"]
collision_layer = 2
collision_mask = 0
[node name="CollisionShape2D" type="CollisionShape2D" parent="Portals/{name}/Barrier"]
shape = SubResource("Barrier")
disabled = true
'''

def author_maps():
    for num,(filename,title,spawn,exit,center,outline,obstacles) in enumerate(MAPS,1):
        index=num+27; path=f'Maps/Level4/{filename}.png'; w,h=Image.open(ROOT/path).size
        pt=lambda p:(round(p[0]*w/1000),round(p[1]*h/1000))
        s=header(path,'arena')
        s+=f'[node name="Arena4_{num}" type="Node2D"]\nscript = ExtResource("script")\nlevel_index = {index}\n'
        s+='[node name="Background" type="Sprite2D" parent="."]\ntexture = ExtResource("bg")\ncentered = false\n'
        s+='[node name="Terrain" type="StaticBody2D" parent="."]\ncollision_layer = 2\ncollision_mask = 0\n'
        s+='[node name="RoadBoundary" type="CollisionPolygon2D" parent="Terrain"]\nbuild_mode = 1\npolygon = '+packed([pt(p) for p in outline])+'\n'
        for i,(x1,y1,x2,y2) in enumerate(obstacles):
            s+=f'[node name="WallOrGrave_{i}" type="CollisionPolygon2D" parent="Terrain"]\npolygon = '+packed([pt((x1,y1)),pt((x2,y1)),pt((x2,y2)),pt((x1,y2))])+'\n'
        s+='[node name="Navigation" type="Node2D" parent="."]\nscript = ExtResource("nav")\n'
        for name,p in [('Spawn',spawn),('ArenaCenter',center),('RescuePosition',(center[0]-70,center[1]+60))]:
            s+=f'[node name="{name}" type="Marker2D" parent="."]\nposition = {vec(pt(p))}\n'
        s+=f'[node name="Player" parent="." instance=ExtResource("player")]\nposition = {vec(pt(spawn))}\n'
        s+='[node name="Portals" type="Node2D" parent="."]\n'
        s+=gate('Exit',pt(exit),index,-1)
        s+=gate('LockedEntrance',pt((70,spawn[1]-10)),index,-2,'0.7, 0.25, 1, 1')
        s+='[node name="EnemySpawns" type="Node2D" parent="."]\n'
        for j,(dx,dy) in enumerate([(-65,0),(60,0),(0,-80),(0,75),(-30,30),(40,-25)]):
            s+=f'[node name="Spawn_{j}" type="Marker2D" parent="EnemySpawns"]\nposition = {vec(pt((center[0]+dx,center[1]+dy)))}\n'
        s+='[node name="Doors" type="Node2D" parent="."]\n[node name="Switches" type="Node2D" parent="."]\n[node name="Chests" type="Node2D" parent="."]\n'
        s+=f'[node name="Supply" parent="Chests" instance=ExtResource("chest")]\nposition = {vec(pt((spawn[0]+55,spawn[1])))}\nchest_id = "music_supply"\nreward = "health_large"\n'
        if num==10:
            s+='\n[node name="BandSeats" type="Node2D" parent="."]\n'
            for member,point in [('mutsumi',(682,482)),('anon',(720,525)),('soyo',(680,565))]:
                s+=f'[node name="{member}" type="Marker2D" parent="BandSeats"]\nposition = Vector2({point[0]}, {point[1]})\n'
        write(f'Scence/Levels/level_{index:02d}.tscn',s)
        write(f'Scence/Levels/data/level_{index:02d}.json',json.dumps({'name':title,'map':path,'chapter':4,'number':num,'waves':5 if num==10 else (2 if num<3 else 3),'survival_seconds':121 if num==7 else 0,'adventure':{'intro':'第四章 · '+title+'。左门封锁，完成挑战后从右门离开。'}},ensure_ascii=False,indent=2))
    write('Scence/Chapter4/map_manifest.json',json.dumps({f'4-{i}':f'Maps/Level4/{m[0]}.png' for i,m in enumerate(MAPS,1)},ensure_ascii=False,indent=2))

def header(path,script):
    return f'''[gd_scene format=3]
[ext_resource type="Texture2D" path="res://{path}" id="bg"]
[ext_resource type="Script" path="res://Scence/Chapter4/{script}.gd" id="script"]
[ext_resource type="Script" path="res://Scence/Levels/geometry.gd" id="nav"]
[ext_resource type="Script" path="res://Scence/Chapter3/gate.gd" id="gate"]
[ext_resource type="PackedScene" path="res://Player/Phoebe.tscn" id="player"]
[ext_resource type="PackedScene" path="res://Combat/chest.tscn" id="chest"]
[sub_resource type="RectangleShape2D" id="Gate"]
size = Vector2(38,24)
[sub_resource type="RectangleShape2D" id="Barrier"]
size = Vector2(42,20)
'''

def author_hub():
    # Trace the visible connected stone roads. Raster union is offline only.
    paths=[([(903,919),(903,831),(906,769),(823,659),(775,630),(623,520),(615,479),(781,438),(1005,446)],38),
           ([(906,769),(1100,745),(1272,736),(1240,693),(1194,668),(1170,610),(947,587),(844,628),(775,630)],36),
           ([(781,438),(736,376),(702,340),(715,300),(962,281),(1009,249),(1013,166),(888,166),(831,139),(668,143)],32),
           ([(1009,249),(1099,298),(1135,312),(1248,351),(1356,357),(1413,315),(1320,231),(1191,206),(1068,181),(1013,166)],34),
           ([(1191,206),(1403,205),(1393,172)],38)]
    mask=Image.new('1',(418,236)); draw=ImageDraw.Draw(mask)
    portals=[(906,769),(1272,736),(775,630),(1170,610),(615,479),(1005,446),(715,300),(1135,312),(668,143),(1013,166)]
    for path,width in paths: draw.line([(x//4,y//4) for x,y in path],fill=1,width=max(52,width)//4,joint='curve')
    for x,y in portals+[(1393,172)]: draw.ellipse((x//4-10,y//4-4,x//4+10,y//4+6),fill=1)
    edges={}
    def on(x,y): return 0<=x<418 and 0<=y<236 and mask.getpixel((x,y))
    for y in range(236):
        for x in range(418):
            if not on(x,y): continue
            for a,b,n in [((x,y),(x+1,y),(x,y-1)),((x+1,y),(x+1,y+1),(x+1,y)),((x+1,y+1),(x,y+1),(x,y+1)),((x,y+1),(x,y),(x-1,y))]:
                if not on(*n): edges[a]=b
    loops=[]
    while edges:
        start=next(iter(edges)); p=start; loop=[]
        while p in edges:
            loop.append(p);p=edges.pop(p)
            if p==start:break
        # Remove collinear stair-edge points, retain the authored path silhouette.
        simple=[p for i,p in enumerate(loop) if (p[0]-loop[i-1][0])*(loop[(i+1)%len(loop)][1]-p[1])!=(p[1]-loop[i-1][1])*(loop[(i+1)%len(loop)][0]-p[0])]
        scaled=[(x*4,y*4) for x,y in simple]
        halfway=len(scaled)//2
        loops.append(simplify(scaled[:halfway+1])[:-1]+simplify(scaled[halfway:]+scaled[:1])[:-1])
    s=header('Maps/Level4/4.png','hub')+'[node name="Chapter4" type="Node2D"]\nscript = ExtResource("script")\n[node name="Background" type="Sprite2D" parent="."]\ntexture = ExtResource("bg")\ncentered = false\n[node name="Terrain" type="StaticBody2D" parent="."]\ncollision_layer = 2\ncollision_mask = 0\n'
    for i,loop in enumerate(loops): s+=f'[node name="RoadBoundary_{i}" type="CollisionPolygon2D" parent="Terrain"]\nbuild_mode = 1\npolygon = '+packed(loop)+'\n'
    s+='[node name="Navigation" type="Node2D" parent="."]\nscript = ExtResource("nav")\n[node name="Spawn" type="Marker2D" parent="."]\nposition = Vector2(903,831)\n[node name="Player" parent="." instance=ExtResource("player")]\nposition = Vector2(903,831)\n[node name="Portals" type="Node2D" parent="."]\n'
    colors=['1,.2,.3,1','1,.5,.1,1','1,.8,.2,1','.4,1,.2,1','.2,1,1,1','.2,.5,1,1','.7,.2,1,1','1,.2,.8,1','.9,.9,1,1','.6,.1,1,1']
    for i,p in enumerate(portals): s+=gate(f'Gate_{i+1:02}',p,28+i,0,colors[i])
    s+=gate('EnterChapter5',(1393,172),0,5)
    s+='[node name="NPCs" type="Node2D" parent="."]\n'
    write('Scence/Chapter4.tscn',s)

if __name__=='__main__':
    author_voices(); author_sprites(); author_soyo_full(); author_weapons(); author_maps(); author_hub()
    print('Authored chapter 4: 10 scenes, map manifest, 7 sprite atlases, actor definitions and music weapons.')
