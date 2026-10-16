"""Offline scene authoring only. Runtime never invokes this tool.

Road centrelines and widths were traced against each supplied map. Their union is
converted to closed contours, simplified within 3 pixels, split into <=48 pixel
CollisionPolygon2D edges. Edit the resulting .tscn nodes directly in Godot.
No source images are changed. --write is required to replace authored scenes.
"""
from pathlib import Path
import math, json, re, sys
import numpy as np

ROOT=Path(__file__).resolve().parents[1]
W,H=1672,941
S=4
def road(width,*pts):return (width,pts)
def ellipse(x,y,rx,ry):return [(x+rx*math.cos(i*math.tau/24),y+ry*math.sin(i*math.tau/24)) for i in range(24)]
def polygon_mask(poly,X,Y):
    result=np.zeros(X.shape,dtype=bool)
    for a,b in zip(poly,poly[1:]+poly[:1]):
        if a[1]==b[1]:continue
        result ^= ((a[1]>Y)!=(b[1]>Y)) & (X<(b[0]-a[0])*(Y-a[1])/(b[1]-a[1])+a[0])
    return result

# width is the walkable floor width, not a collision strip width.
maps={
0:dict(name='潮汐遗迹',spawn=(836,861),exit=(836,439),
 roads=[road(62,(836,913),(836,775),(836,579),(836,454)),road(62,(836,338),(836,177)),
 road(36,(709,449),(700,449),(700,325),(836,325)),
 road(48,(836,454),(656,437),(487,437),(437,385),(340,348),(234,322),(203,297),(196,250),(145,241),(145,221)),
 road(48,(144,426),(241,410),(315,382),(375,375),(431,393),(487,437)),
 road(52,(234,448),(172,420),(144,420),(144,402)),
 road(48,(234,448),(245,505),(295,549),(339,577),(344,620),(399,645),(454,672),(506,735),(506,706)),
 road(42,(245,505),(238,540),(183,579),(127,604),(110,665),(117,708),(169,709),(169,676)),
 road(45,(836,178),(688,178),(621,176),(620,117),(565,111),(565,90)),
 road(46,(836,199),(1003,199),(1136,204),(1136,118),(1183,111),(1183,93)),
 road(46,(1136,204),(1192,207),(1257,239),(1455,245),(1541,258),(1541,241)),
 road(48,(836,454),(1026,437),(1191,437),(1297,451),(1297,427)),
 road(48,(1297,451),(1294,520),(1312,602),(1337,632),(1424,638),(1465,668),(1465,720),(1521,721),(1521,698)),
 road(44,(1541,258),(1536,301),(1507,344),(1457,370),(1411,407),(1357,447),(1297,451)),
 road(44,(1312,602),(1292,640),(1234,670),(1219,704),(1166,749),(1135,761))],
 bridges=[(682,310,36,151),(700,308,136,34)],
 pads=[(836,454,175,29),(836,579,60,29),(836,338,55,23),(145,242,57,24),(144,426,64,26),(169,712,66,22),(506,735,66,21),(565,112,57,22),(836,177,59,23),(1183,112,57,23),(1541,258,53,25),(1297,451,54,24),(1521,723,57,24)],
 doors=[(169,688),(506,716),(144,404),(145,220),(565,91),(836,159),(1183,92),(1541,239),(1297,430),(1521,703)]),
1:dict(name='潮门试炼',spawn=(836,875),exit=(836,881),
 roads=[road(64,(836,912),(836,128)),road(50,(836,473),(344,474),(246,477),(200,446),(177,389),(177,365)),road(50,(836,473),(1360,473),(1456,470),(1490,432),(1515,384),(1515,362)),road(48,(836,244),(673,234),(623,211),(558,211)),road(46,(836,244),(1021,235),(1152,220),(1228,187),(1306,166))],
 pads=[(836,477,121,86),(836,244,100,31),(836,375,50,27),(177,390,49,27),(1515,388,53,27)],doors=[(177,379),(1515,379),(836,146)],runes=[(235,465),(1450,468),(836,245)]),
2:dict(name='环礁双环',spawn=(836,859),exit=(836,862),
 roads=[road(65,(836,898),(836,677)),road(65,(836,324),(836,120)),road(48,(836,696),(662,688),(486,596),(486,441),(674,336),(1000,335),(1158,437),(1158,589),(986,683),(836,696)),road(45,(486,437),(426,413),(426,329),(250,329),(195,317),(171,276),(152,211),(145,180)),road(45,(486,589),(422,585),(359,642),(199,671),(145,669),(145,641)),road(44,(199,671),(185,739)),road(46,(1158,437),(1228,415),(1260,329),(1440,327),(1491,296),(1515,234),(1527,189)),road(46,(1158,589),(1226,594),(1291,647),(1464,671),(1515,669),(1515,641)),road(48,(836,220),(551,220),(427,307)),road(48,(836,220),(1128,220),(1250,292))],pads=[(836,696,86,34),(486,441,55,26),(486,584,60,32),(1158,443,58,28),(1158,584,59,30),(836,326,101,23),(836,221,100,30)],doors=[(145,198),(145,657),(1527,203),(1515,657),(836,139)],runes=[(230,325),(287,652),(1417,326),(1350,655),(836,329)]),
3:dict(name='回流长廊',spawn=(836,874),exit=(836,882),
 roads=[road(66,(836,912),(836,127)),road(45,(836,421),(689,421),(612,396),(527,395),(492,368),(438,323),(235,322),(165,362),(156,414),(178,465),(178,514),(208,551),(264,602),(205,600),(127,598),(86,639),(102,687),(152,744),(217,791),(256,797)),road(46,(836,586),(682,621),(581,667),(516,697),(412,692),(335,649),(263,602)),road(46,(836,421),(988,421),(1041,396),(1152,395),(1182,347),(1260,323),(1423,323),(1502,346),(1534,397),(1533,481),(1522,526),(1550,579),(1490,625),(1405,627),(1340,685),(1166,699),(1046,655),(836,586)),road(46,(1340,685),(1376,739),(1403,796),(1504,812)),road(48,(235,322),(232,218),(203,198)),road(48,(1423,323),(1437,223),(1452,203)),road(45,(232,218),(348,207),(380,152),(479,151),(616,213),(836,213),(1064,213),(1157,171)),road(44,(1280,178),(1295,212),(1452,221))],pads=[(836,585,100,25),(836,421,122,25),(836,213,105,28),(127,598,50,22),(1530,492,47,21)],doors=[(203,201),(1452,211),(836,139)],runes=[(287,321),(1352,323),(836,335)]),
4:dict(name='旋涡迷庭',spawn=(819,844),exit=(815,844),
 roads=[road(48,(819,844),(668,876),(577,831),(444,747),(399,687),(299,662),(233,609),(209,530),(242,490),(246,385),(214,353),(166,278),(121,253),(120,226)),road(48,(166,278),(273,245),(298,193),(430,153),(551,120),(630,144),(652,218),(704,236),(896,237),(1065,281),(1132,224),(1156,161),(1197,140),(1197,109)),road(46,(630,144),(774,142),(848,113),(969,106)),road(48,(652,218),(574,282),(535,324),(501,407),(500,442)),road(49,(1197,156),(1350,194),(1431,249),(1446,293),(1535,365),(1546,454),(1570,487),(1550,543),(1498,609),(1460,666),(1421,780),(1421,746)),road(49,(1421,793),(1266,811),(1143,814),(1078,857),(974,846),(819,844)),road(46,(1143,814),(1137,749),(1106,715),(1062,668),(1167,600),(1199,569),(1217,469),(1246,434),(1204,356),(1110,306),(1065,281)),road(46,(1062,688),(883,701),(704,701),(570,660),(525,649)),road(40,(1199,580),(1118,564),(1036,515),(974,479),(922,506),(834,535),(834,469))],pads=[(834,514,96,34),(1197,153,89,25),(121,269,53,35),(1421,790,82,27),(1062,688,52,30)],doors=[(120,246),(1197,132),(1421,766),(834,481)],runes=[(246,385),(1065,280),(1240,811),(1064,531)]),
5:dict(name='四象潮阵',spawn=(834,502),exit=(834,519),
 roads=[road(66,(834,470),(738,430),(585,348),(433,254),(334,192),(330,151)),road(64,(834,470),(947,422),(1081,346),(1232,258),(1368,192),(1368,150)),road(64,(834,470),(706,554),(552,641),(408,731),(319,781),(248,837),(248,803)),road(62,(834,470),(940,548),(1091,637),(1237,728),(1340,791),(1397,839),(1397,805))],pads=[(834,470,132,74),(834,415,40,30),(834,557,40,33),(334,197,60,23),(1368,197,60,24),(248,837,58,24),(1397,839,57,24)],doors=[(330,166),(1368,166),(248,816),(1397,818)],runes=[(545,323),(1131,318),(445,708),(1194,704)]),
6:dict(name='水母电廊',spawn=(836,867),exit=(836,881),
 roads=[road(64,(836,915),(836,150)),road(48,(836,539),(664,523),(621,508),(457,508),(327,510),(324,437),(249,430),(203,388),(151,353),(150,229),(160,178)),road(48,(836,539),(1005,523),(1055,508),(1210,508),(1338,510),(1347,438),(1433,420),(1470,378),(1521,335),(1508,230),(1518,178)),road(44,(150,209),(272,207),(360,208),(517,210),(612,255),(836,269),(1073,257),(1169,206),(1345,209),(1518,207))],pads=[(836,539,152,34),(836,269,135,28),(327,437,43,25),(1338,438,45,27),(160,210,60,22),(1518,208,56,23)],doors=[(160,187),(1518,188),(836,178)],runes=[(325,510),(1338,510),(836,366)]),
7:dict(name='沉碑回声',spawn=(836,879),exit=(836,894),
 roads=[road(64,(836,924),(836,152)),road(47,(836,550),(662,557),(467,558),(413,533),(414,509),(367,484),(201,455),(127,413),(127,349),(224,312),(235,246),(207,188),(189,177)),road(47,(413,533),(405,584),(377,618),(377,675),(337,713),(286,765),(170,770),(170,734)),road(44,(337,760),(457,770),(509,798)),road(48,(836,550),(1005,557),(1202,557),(1242,531),(1245,498),(1447,451),(1540,411),(1540,344),(1442,312),(1440,247),(1468,196),(1495,177)),road(47,(1242,531),(1274,594),(1277,647),(1335,711),(1395,761),(1505,763),(1505,731)),road(44,(1395,761),(1217,768),(1164,795)),road(45,(836,237),(707,216),(622,191)),road(45,(836,237),(962,213),(1060,179))],pads=[(836,550,150,34),(836,236,75,28),(377,618,40,24),(1277,602,43,26),(170,770,52,25),(1505,763,52,25)],doors=[(170,752),(1505,745),(836,180)],runes=[(334,715),(1328,711),(836,374)]),
8:dict(name='断桥寻径',spawn=(963,832),exit=(963,844),
 roads=[road(60,(963,868),(963,128)),road(45,(963,646),(741,646),(745,615),(682,580),(682,500),(420,485),(350,429),(243,401),(194,375),(194,270),(128,259),(124,156),(124,120)),road(45,(194,270),(259,252),(261,208),(221,172),(197,143),(124,145)),road(44,(261,193),(489,191),(529,190),(529,95)),road(46,(529,190),(552,235),(689,235),(687,341),(685,480)),road(42,(687,341),(812,342),(835,302),(868,305)),road(48,(420,485),(341,552),(280,602),(201,634),(140,608),(139,568)),road(45,(201,634),(192,722),(253,756),(341,790),(442,790)),road(47,(963,480),(1135,479),(1220,531),(1451,531),(1504,491),(1510,438),(1508,322),(1373,294),(1361,255),(1389,205),(1429,149),(1549,150),(1556,215)),road(46,(1451,531),(1451,592)),road(47,(1562,680),(1554,732),(1520,805),(1394,807),(1312,762),(1211,762),(1160,747))],pads=[(963,480,91,37),(963,646,52,31),(682,480,45,31),(529,190,45,26),(201,634,60,27)],
 # The artwork has disconnected bottom-right ruins: a saved stepping-stone bridge repairs the route.
 bridges=[(1433,578,36,228)],doors=[(124,141),(1562,698),(963,142)],runes=[(242,402),(1450,574),(963,315)]),
9:dict(name='潮汐王庭',spawn=(836,798),exit=(836,803),
 roads=[road(64,(836,831),(836,360)),road(50,(836,457),(659,455),(448,455),(377,434),(377,314),(458,287),(527,271),(478,231),(478,111)),road(46,(377,327),(208,327),(160,328),(160,278)),road(47,(527,271),(581,287),(687,285),(757,337),(752,398)),road(46,(659,278),(665,218),(672,176),(620,149),(478,140)),road(43,(672,176),(789,176)),road(48,(411,455),(418,514),(388,558),(338,592),(283,599)),road(48,(229,695),(229,744),(358,763),(424,778)),road(50,(836,457),(1017,456),(1142,456),(1229,403),(1229,310),(1315,271),(1363,238),(1367,113)),road(49,(1229,403),(1325,459),(1339,511),(1428,545),(1426,649),(1361,714),(1343,757),(1201,768),(1120,763),(1077,729),(1004,731)),road(46,(1428,545),(1543,514),(1584,493)),road(46,(1428,376),(1519,335),(1572,276),(1602,233),(1508,228),(1468,241),(1363,238))],pads=[(836,458,105,77),(836,732,45,39),(1428,545,57,30),(229,744,55,22),(478,142,67,24),(1367,147,59,25)],bridges=[(269,584,32,145)],doors=[(160,298),(478,128),(1367,130),(229,722)],runes=[(280,327),(479,245),(1340,252),(285,601)]),
10:dict(name='深渊终殿',spawn=(836,828),exit=(836,839),
 roads=[road(64,(836,867),(836,122)),road(50,(836,478),(512,478),(324,478),(263,503),(206,535),(183,601),(180,650),(126,644),(116,606)),road(48,(183,601),(214,650),(237,697),(281,737),(345,765),(476,765)),road(48,(108,744),(108,784),(201,771),(281,737)),road(49,(263,503),(275,400),(223,340),(181,298),(110,287),(110,245)),road(47,(181,298),(257,282),(271,225),(277,165),(434,160),(610,165),(641,211),(836,218),(1029,191),(1216,163),(1393,171),(1400,224),(1444,271),(1556,297),(1564,260)),road(48,(836,478),(1174,478),(1337,478),(1380,510),(1432,550),(1496,621),(1496,653),(1398,727),(1295,765),(1197,756)),road(48,(1337,478),(1337,412),(1391,357),(1444,271)),road(49,(1496,653),(1567,686),(1567,793),(1567,764))],pads=[(836,478,99,39),(836,775,112,32),(836,218,126,28),(183,650,67,28),(1496,650,57,25),(110,285,59,25),(1564,295,52,25),(108,784,46,22),(1567,793,47,22)],doors=[(108,767),(1567,777),(110,266),(1564,278),(836,145)],runes=[(238,697),(1463,676),(275,402),(1377,379),(836,326)])
}

# Follow the final temple's actual eastern staircase, rather than cutting the water corner.
maps[10]['roads'][-2] = road(48,(1337,478),(1408,445),(1466,403),(1486,356),(1444,303),(1444,271))
maps[10]['runes'][3] = (1430,429)

def rdp(points,tol=3):
    if len(points)<=2:return points
    a,b=np.array(points[0],float),np.array(points[-1],float); v=b-a
    pp=np.array(points,float); t=np.clip(((pp-a)@v)/max(v@v,1e-9),0,1)
    d=np.linalg.norm(pp-(a+t[:,None]*v),axis=1); i=int(d.argmax())
    if d[i]<=tol:return [points[0],points[-1]]
    return rdp(points[:i+1],tol)[:-1]+rdp(points[i:],tol)

def floor_mask(data):
    Y,X=np.mgrid[S/2:H:S,S/2:W:S]
    mask=np.zeros(X.shape,dtype=bool)
    for width,points in data['roads']:
        for a,b in zip(points,points[1:]):
            dx,dy=b[0]-a[0],b[1]-a[1]
            t=np.clip(((X-a[0])*dx+(Y-a[1])*dy)/max(dx*dx+dy*dy,1),0,1)
            mask |= (X-a[0]-t*dx)**2+(Y-a[1]-t*dy)**2 <= (width/2)**2
    for pad in data.get('pads',[]):mask |= polygon_mask(ellipse(*pad),X,Y)
    for x,y,w,h in data.get('bridges',[]):mask |= (X>=x)&(X<=x+w)&(Y>=y)&(Y<=y+h)
    return mask

def floor_snapper(data):
    mask=floor_mask(data)
    safe=mask.copy()
    for dy in range(-2,3):
        for dx in range(-2,3):safe &= np.roll(mask,(dy,dx),(0,1))
    safe[:2,:]=False;safe[-2:,:]=False;safe[:,:2]=False;safe[:,-2:]=False
    ys,xs=np.where(safe)
    points=np.stack(((xs+.5)*S,(ys+.5)*S),axis=1)
    def snap(p):
        best=points[np.argmin(np.sum((points-np.array(p))**2,axis=1))]
        return tuple(float(v) for v in best)
    return snap

def contours(data):
    mask=floor_mask(data)
    edges={}
    for y,x in zip(*np.where(mask)):
        if y==0 or not mask[y-1,x]:edges[(x*S,y*S)]=((x+1)*S,y*S)
        if x==mask.shape[1]-1 or not mask[y,x+1]:edges[((x+1)*S,y*S)]=((x+1)*S,(y+1)*S)
        if y==mask.shape[0]-1 or not mask[y+1,x]:edges[((x+1)*S,(y+1)*S)]=(x*S,(y+1)*S)
        if x==0 or not mask[y,x-1]:edges[(x*S,(y+1)*S)]=(x*S,y*S)
    loops=[]
    while edges:
        start=next(iter(edges));p=start;pts=[]
        while p in edges:
            pts.append(p);p=edges.pop(p)
            if p==start:break
        if len(pts)>3:
            mid=max(range(len(pts)),key=lambda i:(pts[i][0]-start[0])**2+(pts[i][1]-start[1])**2)
            loops.append(rdp(pts[:mid+1])[:-1]+rdp(pts[mid:]+[start])[:-1])
    return loops

def vec(p):return 'Vector2(%s,%s)'%(round(p[0],3),round(p[1],3))
def node(name,typ,parent='.',body=''):
    return f'\n[node name="{name}" type="{typ}"'+(f' parent="{parent}"' if parent is not None else '')+']\n'+body+'\n'
def scene(n,data):
    hub=n==0; idx=n+7
    snap=floor_snapper(data)
    bg='2.png' if hub else f'2-{n}.png'
    ext={'script':('Script','Scence/chapter2_hub.gd' if hub else 'Scence/Levels/level.gd'),'bg':('Texture2D','Maps/Level2/'+bg),'nav':('Script','Scence/Levels/geometry.gd'),'mech':('Script','Scence/Levels/mechanism.gd'),'portal':('Script','Scence/portal.gd'),'player':('PackedScene','Player/Phoebe.tscn'),'chest':('PackedScene','Combat/chest.tscn'),'npc':('Script','Characters/sea_npc.gd'),'water':('Script','Scence/underwater.gd'),'vent':('Script','Scence/sea_vent.gd')}
    lines=['[gd_scene format=3]']+[f'[ext_resource type="{t}" path="res://{p}" id="{id}"]' for id,(t,p) in ext.items()]
    lines+=['[sub_resource type="RectangleShape2D" id="Door"]\nsize = Vector2(44,14)','[sub_resource type="RectangleShape2D" id="Portal"]\nsize = Vector2(30,20)','[sub_resource type="CircleShape2D" id="Exit"]\nradius = 22.0','[sub_resource type="RectangleShape2D" id="Vent"]\nsize = Vector2(24,22)']
    if data.get('bridges'):
        lines.insert(1,'[ext_resource type="Texture2D" path="res://Maps/Tile/SWAMP TILESET 32x32.png" id="bridge_art"]')
        lines+=['[sub_resource type="AtlasTexture" id="BridgeVertical"]\natlas = ExtResource("bridge_art")\nregion = Rect2(388,224,24,32)', '[sub_resource type="AtlasTexture" id="BridgeHorizontal"]\natlas = ExtResource("bridge_art")\nregion = Rect2(412,292,40,24)']
    lines+=[node('Chapter2Hub' if hub else f'Level2_{n}','Node2D',None,'script = ExtResource("script")'+('' if hub else f'\nlevel_index = {idx}')),
    node('Background','Sprite2D',body='texture = ExtResource("bg")\ncentered = false'),node('Terrain','StaticBody2D',body='collision_layer = 2\ncollision_mask = 0')]
    count=0
    for loop in contours(data):
        for a,b in zip(loop,loop[1:]+loop[:1]):
            dx,dy=b[0]-a[0],b[1]-a[1]; length=math.hypot(dx,dy); pieces=max(1,math.ceil(length/48))
            nx,ny=-dy/length,dx/length
            for k in range(pieces):
                p=(a[0]+dx*k/pieces,a[1]+dy*k/pieces);q=(a[0]+dx*(k+1)/pieces,a[1]+dy*(k+1)/pieces)
                pts=[(p[0]+nx,p[1]+ny),(q[0]+nx,q[1]+ny),(q[0]-nx,q[1]-ny),(p[0]-nx,p[1]-ny)]
                coords=', '.join(str(round(v,3)) for pt in pts for v in pt)
                lines.append(node(f'RoadEdge_{count:03d}','CollisionPolygon2D','Terrain',f'polygon = PackedVector2Array({coords})'))
                count+=1
    lines+=[node('Navigation','Node2D',body='script = ExtResource("nav")'),node('Spawn','Marker2D',body='position = '+vec(data['spawn'])),node('Bridges','Node2D')]
    for i,(x,y,w,h) in enumerate(data.get('bridges',[])):
        lines.append(node(f'SteppingStones_{i}','Node2D','Bridges',f'position = {vec((x,y))}\nmetadata/size = {vec((w,h))}'))
        if h>w:
            for yy in range(0,h,32):
                lines.append(node(f'Tile_{yy}','Sprite2D',f'Bridges/SteppingStones_{i}',f'position = {vec((0,yy))}\ntexture = SubResource("BridgeVertical")\ncentered = false\nscale = {vec((w/24,min(32,h-yy)/32))}'))
        else:
            for xx in range(0,w,40):
                lines.append(node(f'Tile_{xx}','Sprite2D',f'Bridges/SteppingStones_{i}',f'position = {vec((xx,0))}\ntexture = SubResource("BridgeHorizontal")\ncentered = false\nscale = {vec((min(40,w-xx)/40,h/24))}'))
    lines += [node('ReturnPortal','Area2D',body='position = '+vec(data['exit'])+'\ncollision_layer = 32\ncollision_mask = 1'),node('CollisionShape2D','CollisionShape2D','ReturnPortal','shape = SubResource("Exit")'),node('Label','Label','ReturnPortal','offset_left = -60.0\noffset_top = 15.0\ntext = "E · 返回海岸"' if hub else 'offset_left = -42.0\noffset_top = 15.0\ntext = "通关后 E 返回"')]
    lines.append(node('Portals' if hub else 'Doors','Node2D'))
    for i,p in enumerate(data['doors']):
        id=f'sea_{i+1:02d}' if hub else f'door_{i+1}'
        parent='Portals' if hub else 'Doors'
        if hub:
            lines.append(node(id,'Area2D',parent,f'position = {vec(p)}\ncollision_layer = 32\ncollision_mask = 1\nscript = ExtResource("portal")\nportal_id = &"{id}"\ntarget_scene = "res://Scence/Levels/level_{i+8:02d}.tscn"\ntarget_spawn_id = &"entry"'))
            lines.append(node('CollisionShape2D','CollisionShape2D',parent+'/'+id,'shape = SubResource("Portal")'))
            lines.append(node('Label','Label',parent+'/'+id,f'offset_left = -38.0\noffset_top = 14.0\ntheme_override_font_sizes/font_size = 11\ntext = "2-{i+1}"'))
        else:
            cfg={'id':id,'type':'door','label':f'潮封门 {i+1}','requires':[f'rune_{i+1}']}
            lines.append(node(id,'Node2D',parent,f'position = {vec(p)}\nscript = ExtResource("mech")\nconfig = '+json.dumps(cfg,ensure_ascii=False)))
        lines.append(node('Barrier','StaticBody2D',parent+'/'+id,'collision_layer = 2\ncollision_mask = 0'))
        lines.append(node('CollisionShape2D','CollisionShape2D',parent+'/'+id+'/Barrier','shape = SubResource("Door")'))
    if hub:
        lines += ['\n[node name="Player" parent="." instance=ExtResource("player")]\nposition = '+vec(data['spawn']),node('NPCs','Node2D')]
        for name,service,pos in [('潮汐向导','help',(803,578)),('补给商人','items',(917,453)),('潮猎铁匠','weapons',(753,453))]:
            lines.append(node(service,'CharacterBody2D','NPCs',f'position = {vec(pos)}\nscript = ExtResource("npc")\ndisplay_name = "{name}"\nservice = "{service}"'))
        lines.append(node('Underwater','Node2D',body='script = ExtResource("water")'))
    else:
        lines += [node('Switches','Node2D'),node('EncounterSpawns','Node2D'),node('Chests','Node2D'),node('Traps','Node2D')]
        puzzles={}
        for i,p in enumerate(data['runes']):
            mode=['sequence','hold','direction'][(i+n-1)%3]
            kind={'sequence':'torch','hold':'plate','direction':'mirror'}[mode]
            symbols=[1,(i+n)%4] + ([2] if n>=5 else [])
            clue='潮纹顺序：'+' → '.join(['火','水','风','土'][s] for s in symbols)
            puzzle={'mode':mode,'sequence':symbols,'clue':clue} if mode=='sequence' else ({'mode':mode,'seconds':1.2+n*.08,'clue':'在踏板上保持不动，等待充能圆环完整亮起'} if mode=='hold' else {'mode':mode,'target':(i+n)%4,'clue':'光束应朝'+['北','东','南','西'][(i+n)%4]})
            puzzles[f'rune_{i+1}']=puzzle
            cfg={'id':f'rune_{i+1}','type':kind,'label':f'潮汐机关 {i+1}'}
            lines.append(node(f'rune_{i+1}','Node2D','Switches',f'position = {vec(p)}\nscript = ExtResource("mech")\nconfig = '+json.dumps(cfg,ensure_ascii=False)))
            door=data['doors'][i];center=snap((door[0],door[1]+42))
            lines.append(node(f'door_{i+1}','Marker2D','EncounterSpawns','position = '+vec(center)))
            if i==0 or i==len(data['runes'])-1:
                # Editor-visible vent footprint. It is a timed damage zone, not a solid roadblock.
                vp=snap((p[0],p[1]+48))
                lines.append(node(f'PressureVent_{i}','Area2D','Traps',f'position = {vec(vp)}\ncollision_layer = 0\ncollision_mask = 1\nscript = ExtResource("vent")\ndisabled_by = "rune_{i+1}"\nperiod = {4+n*.05}'))
                lines.append(node('CollisionShape2D','CollisionShape2D',f'Traps/PressureVent_{i}','shape = SubResource("Vent")'))
        # Guaranteed opening supplies; discovery rewards still roll at each door.
        rewards=['health','energy', ['harpoon','coral_trident'][(n-1)%2]]
        cp=[(data['spawn'][0]+19,data['spawn'][1]-30),data['runes'][0],data['runes'][-1]]
        for i,(reward,p) in enumerate(zip(rewards,cp)):
            lines.append(f'\n[node name="Supply_{i}" parent="Chests" instance=ExtResource("chest")]\nposition = {vec(snap((p[0],p[1]+24)))}\nchest_id = "sea{n}_supply_{i}"\nreward = "{reward}"')
        enemies=['reef_crab','reef_shark'] if n<4 else ['reef_shark','jellyfish','reef_crab','drowned_guard']
        boss='tide_sorcerer' if n in [4,7,9] else 'abyss_king'
        names=['潮门试炼','环礁双环','回流长廊','旋涡迷庭','四象潮阵','水母电廊','沉碑回声','断桥寻径','潮汐王庭','深渊终殿']
        hints=['三路封印各有机关，先收集入口补给。','沿双环寻找五处封印，地图能帮助辨认岔路。','上下长廊互通，可绕行避开守卫。','中央小岛由东侧窄桥接入，留意支路。','四条斜桥连接四象封印，中央广场适合躲避大招。','水母会远程放电，鱼叉能贯穿成排敌人。','沿阶梯找回沉碑线索，长廊可以拉开距离。','新增的踏石连接断桥，沿小地图找到最右侧封印。','潮汐血灵守护王庭，躲开远程连射。','五扇门全部开启并清除最后守卫，完成第二章，解锁篮球手。']
        meta={'index':idx,'chapter':2,'number':n,'name':names[n-1],'map':f'res://Maps/Level2/{bg}','floor_sample':[816,450,24,24],'adventure':{'intro':f'2-{n} · {names[n-1]}：探索、解谜、解封并清场。','hint':hints[n-1],'max_pack':min(4,2+n//4),'boss':boss,'enemies':enemies,'puzzles':puzzles}}
        (ROOT/f'Scence/Levels/data/level_{idx:02d}.json').write_text(json.dumps(meta,ensure_ascii=False,indent=2),encoding='utf-8')
    dest=ROOT/('Scence/Chapter2.tscn' if hub else f'Scence/Levels/level_{idx:02d}.tscn')
    dest.write_text('\n'.join(lines),encoding='utf-8')
    print(dest.name, 'editable edge segments:',count)

if __name__=='__main__':
    if '--write' not in sys.argv:raise SystemExit('Explicit --write required: this overwrites authored chapter 2 scene files.')
    for n,data in maps.items():scene(n,data)
