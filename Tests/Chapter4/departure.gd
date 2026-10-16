extends SceneTree
var checks := 0
var failures := 0
func ck(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var c = root.get_node("Campaign")
	c.saving_enabled = false
	root.get_node("Story").automatic_enabled = false
	c.reset_state(40)
	for index in range(1, 28):
		var state: Dictionary = c.level_state(index)
		state.doors = c.Catalog.all_door_ids(index)
		state.rescued = true
		if index >= 18: state.arena = {"finished": true}
		c.completed.append(index)
	for id in ["nuonuo", "doro", "gugu", "ikun"]:
		c.profile[id+"_unlocked"] = true
		c.profile.party_health[id] = c.player_stats(id).health
	c.hub_chapter = 4
	c.active_level = 28
	c.ensure_character_allowed()
	ck(c.profile.character == "phoebe", "entry keeps Phoebe")
	for id in ["phoebe", "nuonuo", "doro", "gugu"]:
		ck(id in c.party_ids(), id+" available in 4-1")
		c.select_character(id)
		ck(c.profile.character == id, id+" selectable in 4-1")
	c.save_path = "res://.godot/chapter4-departure-test.json"
	c.saving_enabled = true
	ck(c.save_progress() and c.load_progress(), "pre-victory save reload")
	ck(c.profile.character == "gugu", "reload retains old friend")
	for id in ["phoebe", "nuonuo", "doro", "gugu"]: ck(id in c.party_ids(), id+" available after reload")
	c.level_state(28).arena = {"finished": true}
	ck(c.complete_arena(28), "4-1 victory")
	ck(c.profile.character == "ikun", "departure switches current old friend to Ikun")
	ck(c.profile.mutsumi_unlocked, "Mutsumi joins")
	for id in ["phoebe", "nuonuo", "doro", "gugu"]:
		ck(id not in c.party_ids(), id+" leaves after victory")
	c.active_level = 0
	ck(c.save_progress() and c.load_progress(), "post-victory save reload")
	for chapter in [1, 3, 4]:
		c.hub_chapter = chapter
		for id in ["phoebe", "nuonuo", "doro", "gugu"]:
			ck(not c.character_allowed(id), id+" departure persists in chapter "+str(chapter))
	c.saving_enabled = false
	print("CHAPTER4 DEPARTURE: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
