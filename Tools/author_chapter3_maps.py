"""Offline traced floor outlines. Writes editable boundary polygons, no runtime terrain generation.
Coordinates are traced on each 1672x941 original; PNG pixels are never modified.
"""
from pathlib import Path
import json, math
from author_chapter2_maps import road, contours, node, vec
ROOT=Path(__file__).resolve().parents[1]
def area(x,y,rx,ry): return (x,y,rx,ry)
maps={
0:dict(spawn=(805,860),entry=(805,880),exit=(850,104),center=(855,541),
 roads=[road(52,(805,900),(805,830),(734,780),(673,760),(594,765),(511,763),(511,739)),
 road(57,(805,830),(880,836),(906,820)),road(51,(673,760),(723,721),(839,701),(993,700),(1060,679)),
 road(48,(993,700),(1178,688),(1217,634),(1207,593)),road(52,(1207,593),(1127,570),(1020,565),(1014,583),(1014,640)),
 road(52,(1127,570),(958,550),(868,538),(738,490),(630,490),(530,473),(530,453)),
 road(52,(630,490),(630,390),(618,362)),road(53,(630,390),(748,370),(895,349),(1068,326),(1179,285),(1180,228),(1155,199)),
 road(48,(1068,326),(1068,301)),road(52,(737,370),(737,253),(736,213),(851,213),(852,150),(852,114)),
 road(50,(736,213),(614,213),(612,187)),road(50,(851,213),(1047,211),(1155,205))],
 pads=[area(805,830,66,28),area(905,835,61,25),area(511,763,65,24),area(1060,698,54,25),area(1207,604,55,29),area(868,538,68,25),area(530,476,57,27),area(618,366,48,24),area(1068,322,49,25),area(612,211,49,25),area(1155,206,48,24)]),
1:dict(spawn=(440,744),entry=(293,778),exit=(1450,180),center=(880,488),
 roads=[road(83,(295,837),(295,790),(430,747),(623,746),(804,702),(880,672),(883,549)),road(76,(883,488),(698,436),(657,365),(563,322)),road(80,(883,488),(1100,460),(1280,421),(1321,349),(1390,264),(1442,210),(1450,176))],
 pads=[area(293,798,75,38),area(880,489,146,77),area(541,305,133,57),area(1353,277,121,61)]),
2:dict(spawn=(392,698),entry=(255,803),exit=(1444,174),center=(635,414),
 roads=[road(78,(271,846),(255,799),(300,744),(430,695),(554,634),(598,559),(620,489)),road(76,(635,418),(806,444),(977,430),(1120,412),(1175,372),(1289,307),(1394,217),(1444,174))],
 pads=[area(259,798,67,40),area(630,419,176,78),area(1316,280,137,64)]),
3:dict(spawn=(400,718),entry=(290,776),exit=(1357,168),center=(864,449),
 roads=[road(78,(285,840),(291,778),(383,726),(589,691),(666,652),(744,617),(783,557),(864,486)),road(84,(865,450),(1043,441),(1217,398),(1239,348),(1309,297),(1357,168))],
 pads=[area(289,779,80,42),area(864,453,160, 72),area(1318,250,156,65)]),
4:dict(spawn=(395,709),entry=(281,738),exit=(1428,172),center=(534,461),
 roads=[road(76,(277,798),(281,738),(393,707),(478,666),(520,590),(531,488)),road(78,(539,461),(759,458),(1007,446),(1245,476),(1332,403),(1394,303),(1419,237),(1428,172)),road(68,(534,461),(411,388),(391,341))],
 pads=[area(281,738,84, 40),area(534,461,151,78),area(1267,475,155,79),area(1423,233,96,42),area(418,359,70,38)]),
5:dict(spawn=(405,716),entry=(259,757),exit=(1417,187),center=(896,531),
 roads=[road(82,(259,809),(259,757),(411,718),(570,694),(751,650),(871,598),(896,539)),road(80,(896,530),(1037,472),(1117,465),(1290,403),(1382,326),(1417,187))],
 pads=[area(259,757,86,45),area(896,529,139,77),area(1397,289,116,56)]),
6:dict(spawn=(401,729),entry=(259,757),exit=(1473,195),center=(859,499),
 roads=[road(76,(258,829),(259,757),(405,727),(576,673),(690,629),(803,562),(859,499)),road(85,(859,499),(1060,422),(1250,350),(1376,270),(1473,195)),road(64,(859,499),(768,417),(743,399))],
 pads=[area(259,757,83,42),area(859,499,151,73),area(1389,261,129,57),area(746,399,65,33)]),
7:dict(spawn=(401,723),entry=(254,776),exit=(1440,173),center=(1071,479),
 roads=[road(84,(254,839),(254,776),(413,720),(597,709),(749,638),(878,576),(1044,518)),road(80,(1071,479),(1266,396),(1397,291),(1440,173)),road(80,(1071,479),(870,389),(659,329),(540,278))],
 pads=[area(254,776,83,44),area(1071,479,164,81),area(523,259,173,71),area(1433,222,92,45)]),
8:dict(spawn=(366,742),entry=(228,783),exit=(1426,178),center=(877,496),
 roads=[road(80,(228,829),(228,783),(369,742),(533,708),(697,660),(780,608),(877,496)),road(86,(877,496),(1061,409),(1169,355),(1294,320),(1372,224),(1426,178)),road( 70,(877,496),(802,427),(734,376),(711,324),(674,306))],
 pads=[area(228,783,79,41),area(877,496,134,76),area(1307,278,151,70),area(673,307,78,37)]),
9:dict(spawn=(400,735),entry=(267,777),exit=(1422,164),center=(919,527),
 roads=[road(85,(267,827),(267,777),(416,733),(608,698),(761,671),(841,641),(895,566)),road(79,(919,527),(1134,469),(1255,425),(1327,330),(1405,226),(1422,164)),road(81,(919,527),(712,476),(615,418),(586,358),(487,292))],
 pads=[area(267,777,85,44),area(919,527,157, 70),area(499,265,178,73),area(1393,233,103,49)]),
10:dict(spawn=(442,678),entry=(311,792),exit=(1442,173),center=(701,458),
 roads=[road(85,(272,865),(311,792),(358,728),(480,646),(567,610),(622,544),(701,458)),road( 80,(701,458),(886,425),(1064,392),(1181,299),(1336,243),(1442,173))],
 pads=[area(308,797,85,44),area(701,457,155,77),area(1318,243,154,70)])}
COLORS=['ff3030','2277ff','b050ff','48f53e','ffc329','ff3488','ff7919','301340','efffff','7951ff']
HUB_PORTALS=[(905,804),(511,748),(1060,669),(1207,580),(868,519),(618,346),(1068,301),(612,190),(530,455),(1155,187)]
NAMES=['赤门冰桥','蓝门守望','紫晶试炼','绿庭围攻','金门狂笑','绯红回廊','橙门救援','暗门双魇','霜白长夜','终焉王座']
def author(n,d):
 hub=n==0;idx=n+17
 lines=['[gd_scene format=3]']
 for key,typ,path in [('bg','Texture2D','Maps/Level3/'+('3.png' if hub else f'3-{n}.png')),('script','Script','Scence/Chapter3/'+('hub.gd' if hub else 'arena.gd')),('nav','Script','Scence/Levels/geometry.gd'),('player','PackedScene','Player/Phoebe.tscn'),('portal','Script','Scence/Chapter3/gate.gd')]:
  lines.append(f'[ext_resource type="{typ}" path="res://{path}" id="{key}"]')
 if hub: lines.append('[ext_resource type="Script" path="res://Scence/Chapter3/guide.gd" id="guide"]')
 lines+=['[sub_resource type="RectangleShape2D" id="Gate"]\nsize = Vector2(32,22)','[sub_resource type="RectangleShape2D" id="Barrier"]\nsize = Vector2(46,18)']
 lines+=[node('Chapter3Hub' if hub else f'Arena3_{n}','Node2D',None,'script = ExtResource("script")'+('' if hub else f'\nlevel_index = {idx}')),node('Background','Sprite2D',body='texture = ExtResource("bg")\ncentered = false'),node('Terrain','StaticBody2D',body='collision_layer = 2\ncollision_mask = 0')]
 loops=contours(d)
 for k,loop in enumerate(loops):
  lines.append(node(f'FloorBoundary_{k}','CollisionPolygon2D','Terrain','build_mode = 1\npolygon = PackedVector2Array('+','.join(str(round(v,2)) for p in loop for v in p)+')'))
 lines += [node('Navigation','Node2D',body='script = ExtResource("nav")'),node('Spawn','Marker2D',body='position = '+vec(d['spawn']))]
 lines.append('\n[node name="Player" parent="." instance=ExtResource("player")]\nposition = '+vec(d['spawn']))
 lines.append(node('Portals','Node2D'))
 def gate(name,p,index,color,target=0):
  portal_id={4:'chapter4_preview',2:'chapter2_return',-1:'arena_exit',-2:'arena_entry'}.get(target,f'ice_{index-17:02d}')
  body=f'position = {vec(p)}\nscript = ExtResource("portal")\nlevel_index = {index}\nportal_id = &"{portal_id}"\ntarget_chapter = {target}\nportal_color = Color({int(color[0:2],16)/255},{int(color[2:4],16)/255},{int(color[4:6],16)/255},1)\ncollision_layer = 32\ncollision_mask = 1'
  if not hub: body+='\nvisual_offset = Vector2(0,-60)\nvisual_radius = 25.0'
  lines.append(node(name,'Area2D','Portals',body));lines.append(node('CollisionShape2D','CollisionShape2D','Portals/'+name,'shape = SubResource("Gate")'))
  lines.append(node('Barrier','StaticBody2D','Portals/'+name,'collision_layer = 2\ncollision_mask = 0'))
  lines.append(node('CollisionShape2D','CollisionShape2D','Portals/'+name+'/Barrier','shape = SubResource("Barrier")\ndisabled = true'))
 if hub:
  lines.append(node('NPCs','Node2D'))
  lines.append(node('Guide','CharacterBody2D','NPCs','position = Vector2(762,805)\nscript = ExtResource("guide")'))
  for i,p in enumerate(HUB_PORTALS):gate('Ice%02d'%(i+1),p,i+18,COLORS[i])
  gate('Chapter4Preview',d['exit'],0,'44cfff',4)
  gate('BackToOcean',d['entry'],0,'499cff',2)
 else:
  gate('Exit',d['exit'],idx,'aadfff',-1)
  gate('LockedEntrance',d['entry'],idx,COLORS[n-1],-2)
  lines.append(node('ArenaCenter','Marker2D',body='position = '+vec(d['center'])))
  lines.append(node('EnemySpawns','Node2D'))
  from author_chapter2_maps import floor_snapper
  snap=floor_snapper(d)
  for k in range(8):
   p=(d['center'][0]+math.cos(k*math.tau/8)*115,d['center'][1]+math.sin(k*math.tau/8)*51)
   lines.append(node(f'Spawn{k}','Marker2D','EnemySpawns','position = '+vec(snap(p))))
  config=dict(name=NAMES[n-1],chapter=3,biome='snow',bridges=[],waves=min(n+1,5),survival_seconds=240 if n==9 else (180 if n==7 else 0),adventure={'intro':'清除当前波次后继续；左下入口封锁，胜利后右上出口开放。'})
  (ROOT/f'Scence/Levels/data/level_{idx:02d}.json').write_text(json.dumps(config,ensure_ascii=False,indent=2),encoding='utf8')
 path=ROOT/('Scence/Chapter3.tscn' if hub else f'Scence/Levels/level_{idx:02d}.tscn')
 path.write_text('\n'.join(lines),encoding='utf8')
 print(path.name,'boundary contours',len(loops),'segments',sum(len(x) for x in loops))
if __name__=='__main__':
 for n,d in maps.items():author(n,d)
