"""Offline tracing of walkable stone paths. Output collisions are editable scene nodes."""
from pathlib import Path
from PIL import Image,ImageDraw
import json
from author_chapter4 import header,gate,packed,vec,simplify
R=Path(__file__).resolve().parents[1]
def put(p,s):
 p=R/p;p.parent.mkdir(parents=True,exist_ok=True);p.write_text(s,encoding='utf-8')
def loops(mask):
 edges={};w,h=mask.size
 def on(x,y):return 0<=x<w and 0<=y<h and mask.getpixel((x,y))
 for y in range(h):
  for x in range(w):
   if not on(x,y):continue
   for a,b,n in [((x,y),(x+1,y),(x,y-1)),((x+1,y),(x+1,y+1),(x+1,y)),((x+1,y+1),(x,y+1),(x,y+1)),((x,y+1),(x,y),(x-1,y))]:
    if not on(*n):edges.setdefault(a,[]).append(b)
 result=[]
 while edges:
  start=next(iter(edges));p=start;line=[]
  while p in edges:
   line.append((p[0]*4,p[1]*4));nxt=edges[p].pop()
   if not edges[p]:del edges[p]
   p=nxt
   if p==start:break
  assert p==start, "open contour"
  if len(line)<8:continue
  m=len(line)//2;result.append(simplify(line[:m+1],3)[:-1]+simplify(line[m:]+line[:1],3)[:-1])
 return result
# Normalized image coordinates; bridge centerlines and walkable platforms.
LAYOUTS=[
 ((535,490),(72,483),(925,482),(370,375,655,606), [[(535,400),(535,185)],[(535,590),(535,802)]],[(535,178,160,48),(535,802,180,52)]),
 ((500,483),(64,478),(935,482),(340,368,642,570), [[(503,400),(503,180)],[(500,550),(500,813)],[(500,812),(245,723),(125,762)],[(500,812),(750,724),(872,760)],[(502,188),(747,137),(839,175)],[(500,185),(310,138),(213,178)]],[(500,162,165,42)]),
 ((495,485),(65,480),(945,480),(340,350,636,616), [[(390,395),(323,196),(386,127),(587,196),(751,260),(809,333),(819,477)],[(490,596),(529,750),(650,812)],[(650,812),(337,860),(190,753),(102,683)]],[(640,812,172,45)]),
 ((500,485),(90,480),(910,480),(325,294,660,643),[],[]),
 ((505,493),(80,488),(925,486),(347,375,663,615),[[(500,400),(500,163)],[(510,590),(513,820)]],[(510,820,164,55)]),
 ((500,490),(65,480),(925,480),(341,370,652,616),[[(500,395),(500,178)],[(499,600),(500,822)],[(500,177),(273,84),(120,161)],[(500,175),(738,86),(886,166)],[(500,823),(290,721),(211,764)],[(500,823),(757,742)]],[(500,164,150,40)]),
 ((500,476),(76,478),(925,477),(350,343,658,590),[[(500,380),(500,145)],[(500,576),(500,776)],[(500,775),(258,704),(195,626)],[(500,775),(740,694),(798,598)],[(500,142),(727,210),(805,301)]],[(500,143,162,42)]),
 ((500,490),(92,477),(910,477),(342,342,648,611),[[(505,380),(505,180)]],[(505,173,190,48)]),
 ((500,525),(89,405),(925,547),(337,375,659,650),[[(89,405),(365,523)],[(635,559),(925,547)],[(500,412),(500,217)],[(500,616),(500,830)]],[(500,213,162,43)]),
 ((500,600),(100,267),(900,267),(205,472,800,731),[[(100,267),(160,292),(201,361),(325,429),(345,498)],[(900,267),(831,301),(801,350),(675,428),(651,498)],[(500,484),(500,151)],[(500,703),(500,910)]],[(500,153,150,42),(500,916,78,28)])]
TITLES=['余烬中的主唱','葱绿的回声','红白巫女的消息','不再返场的巡演','断线后的来电','橘色牢笼','折翼的回声','静夜留下的路标','时空胶囊的交易','把四个名字带回家']
WAVES=[3,5,8,10,5,7,7,10,10,12]
def scene(path,script,mask,name):
 s=header(path,script).replace('Scence/Chapter4/'+script+'.gd','Scence/Chapter5/'+script+'.gd')
 s+=f'[node name="{name}" type="Node2D"]\nscript = ExtResource("script")\nbiome = "hell"\n'+(f'level_index = {37+int(name.split("_")[-1])}\n' if script=='arena' else '')
 s+='[node name="Background" type="Sprite2D" parent="."]\ntexture = ExtResource("bg")\ncentered = false\n[node name="Terrain" type="StaticBody2D" parent="."]\ncollision_layer = 2\ncollision_mask = 0\n'
 for j,p in enumerate(loops(mask)):s+=f'[node name="StoneRoad_{j}" type="CollisionPolygon2D" parent="Terrain"]\nbuild_mode = 1\npolygon = {packed(p)}\n'
 s+='[node name="Navigation" type="Node2D" parent="."]\nscript = ExtResource("nav")\n'
 return s
for n,(center,left,right,bounds,paths,platforms) in enumerate(LAYOUTS,1):
 cv=lambda p:(round(p[0]*1.448),round(p[1]*1.086));q=lambda p:tuple(v/4 for v in cv(p))
 mask=Image.new('1',(362,272));d=ImageDraw.Draw(mask);d.ellipse((*q(bounds[:2]),*q(bounds[2:])),fill=1)
 routes=list(paths)
 if n<=8:routes+=[[left,right]]
 for route in routes:d.line([q(p) for p in route],fill=1,width=13,joint='curve')
 for x,y,rx,ry in platforms+[(left[0],left[1],42,24),(right[0],right[1],42,24)]:d.ellipse((*q((x-rx,y-ry)),*q((x+rx,y+ry))),fill=1)
 if n==5:d.rectangle((*q((476,466)),*q((526,511))),fill=0)
 if n==10:
  for x in [345,624]:d.rectangle((*q((x,571)),*q((x+30,615))),fill=0)
 s=scene(f'Maps/Level5/5-{n}.png','arena',mask,f'Hell_{n}');spawn=(left[0]+44,left[1]+5)
 for name,p in [('Spawn',spawn),('ArenaCenter',center),('RescuePosition',(center[0]-50,center[1]+40))]:s+=f'[node name="{name}" type="Marker2D" parent="."]\nposition = {vec(cv(p))}\n'
 s+=f'[node name="Player" parent="." instance=ExtResource("player")]\nposition = {vec(cv(spawn))}\n[node name="Portals" type="Node2D" parent="."]\n'
 s+=gate('LockedEntrance',cv(left),n+37,-2,'1,.15,.2,1')+gate('Exit',cv(right),n+37,-1)
 s+='[node name="EnemySpawns" type="Node2D" parent="."]\n'
 for j,(dx,dy) in enumerate([(-90,0),(95,0),(0,-70),(0,75),(-50,40),(60,40)]):s+=f'[node name="Spawn_{j}" type="Marker2D" parent="EnemySpawns"]\nposition = {vec(cv((center[0]+dx,center[1]+dy)))}\n'
 s+='[node name="Doors" type="Node2D" parent="."]\n[node name="Switches" type="Node2D" parent="."]\n[node name="Chests" type="Node2D" parent="."]\n'
 s+=f'[node name="Supply" parent="Chests" instance=ExtResource("chest")]\nposition = {vec(cv((center[0]+80,center[1]+20)))}\nchest_id = "hell_supply"\nreward = "health_large"\n'
 put(f'Scence/Levels/level_{n+37}.tscn',s)
 put(f'Scence/Levels/data/level_{n+37}.json',json.dumps({'chapter':5,'number':n,'name':TITLES[n-1],'map':f'Maps/Level5/5-{n}.png','waves':WAVES[n-1],'survival_seconds':0,'adventure':{'intro':'左门封锁，清除全部波次后从右门离开。'}},ensure_ascii=False,indent=2))
platforms=[(750,959,150,38),(342,800,116,35),(922,721,142,38),(480,572,114,32),(1150,499,137,34),(802,383,95,24),(754,264,87,18),(1220,280,142,34),(290,222,112,30),(750,155,143,23)]
routes=[[(750,1070),(750,963),(601,913),(594,888),(424,830),(342,800)],[(450,790),(758,719),(922,721)],[(990,748),(1020,800)],[(922,721),(790,717),(770,687),(573,600),(480,572)],[(480,572),(570,570),(1030,505),(1150,499)],[(1100,456),(850,402),(802,383)],[(1188,425),(1232,316),(1220,280)],[(875,350),(1101,290),(1220,280)],[(760,360),(747,276),(754,264)],[(754,264),(669,258),(410,232),(290,222)],[(343,245),(379,304)],[(750,245),(750,155)],[(840,163),(1120,225),(1160,250)]]
mask=Image.new('1',(362,272));d=ImageDraw.Draw(mask)
for route in routes:d.line([(x/4,y/4) for x,y in route],fill=1,width=12,joint='curve')
for x,y,rx,ry in platforms:d.ellipse(((x-rx)/4,(y-ry)/4,(x+rx)/4,(y+ry)/4),fill=1)
s=scene('Maps/Level5/5.png','hub',mask,'Chapter5')+'[node name="Spawn" type="Marker2D" parent="."]\nposition = Vector2(750,1030)\n[node name="Player" parent="." instance=ExtResource("player")]\nposition = Vector2(750,1030)\n[node name="Portals" type="Node2D" parent="."]\n'
for i,(x,y,_,_) in enumerate(platforms):
 part=gate(f'Gate_{i+1:02}',(x,y),38+i,0,'1,.35,.1,1');part=__import__('re').sub(r'portal_id = &"[^"]+"',f'portal_id = &"hell_{i+1:02}"',part);s+=part
s+='[node name="NPCs" type="Node2D" parent="."]\n';put('Scence/Chapter5.tscn',s)
print('Authored eleven Chapter5 maps with editor-owned path boundaries.')
