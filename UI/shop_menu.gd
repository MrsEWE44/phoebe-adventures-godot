extends RefCounted
static func open(npc: Node, category: String, page:=0, notice:="") -> void:
	var campaign=npc.get_node("/root/Campaign")
	var dialogue=npc.get_node("/root/Dialogue")
	var ids: Array=campaign.Shop.entries(category)
	var options: Array=[]
	var details:=PackedStringArray()
	for i in range(page*4,mini(ids.size(),page*4+4)):
		var id: String=ids[i]
		var offer: Dictionary=campaign.Shop.STOCK[id]
		var lock: String=" · Lv.%d 解锁"%offer.level if campaign.player_level()<int(offer.level) else ""
		var data: Dictionary=campaign.Items.item(id)
		var restriction: String="（当前角色不能装备，可为队友购买）" if category=="weapons" and not campaign.can_equip_weapon(id) else ""
		details.append(str(data.name)+"："+campaign.Items.short_description(id)+restriction)
		options.append({"id":id,"text":"%s · %d 币 · 持有 ×%d%s"%[data.name,offer.price,campaign.item_count(id),lock],"icon":data.get("texture"),"disabled":campaign.player_level()<int(offer.level) or campaign.profile.coins<int(offer.price) or (data.kind!="consumable" and campaign.item_count(id)>0)})
	if page>0: options.append({"id":"previous_stock","text":"上一页"})
	if page*4+4<ids.size(): options.append({"id":"next_stock","text":"下一页"})
	options.append({"id":"switch_stock","text":"查看防具与药品" if category=="weapons" else "查看武器"})
	var lines: Array[String]=["%s\nLv.%d · 游戏币 %d · %s（%d/%d页）\n购买后按 B 管理装备；武器可在背包花费游戏币强化至 +10。"%[notice,campaign.player_level(),campaign.profile.coins,"武器" if category=="weapons" else "防具和药品",page+1,ceili(ids.size()/4.0)]]
	lines[0]+="\n\n"+"\n".join(details)
	dialogue.open(npc.display_name,lines,options,npc,func(id):
		var next_page: int=page
		var next_category: String=category
		var result:=""
		if id=="next_stock": next_page+=1
		elif id=="previous_stock": next_page-=1
		elif id=="switch_stock": next_page=0;next_category="items" if category=="weapons" else "weapons"
		else: result="购买成功："+campaign.Items.item(id).name if campaign.purchase(id) else "无法购买：检查等级、游戏币，或是否已拥有。"
		dialogue.close()
		open(npc,next_category,next_page,result))
