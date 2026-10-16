extends CanvasLayer
## One modal owns pause/input, so NPC dialogue cannot accidentally attack or open menus.
signal closed
var active := false
var was_paused := false
var source: Node
var on_choice: Callable
var on_closed: Callable
var panel_root: Control
var speaker_label: Label
var content_label: RichTextLabel
var portrait: TextureRect
var choices_box: VBoxContainer
var dialogue_panel: PanelContainer
var options_scroll: ScrollContainer
var pages: Array[String] = []
var page_index := 0
var choices: Array = []
var allow_close := true

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 30
	panel_root = Control.new()
	panel_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(panel_root)
	var shade := ColorRect.new()
	shade.color = Color(0.015,.025,.045,.65)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel_root.add_child(shade)
	var panel := PanelContainer.new()
	dialogue_panel=panel
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_left = 64
	panel.offset_right = -64
	panel.offset_top = -410
	panel.offset_bottom = -32
	var style := StyleBoxFlat.new()
	style.bg_color = Color("14202c")
	style.border_color = Color("d0ab69")
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 18
	style.content_margin_bottom = 18
	panel.add_theme_stylebox_override("panel",style)
	panel_root.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",24)
	panel.add_child(row)
	portrait = TextureRect.new()
	portrait.custom_minimum_size = Vector2(124,124)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(portrait)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation",10)
	row.add_child(column)
	speaker_label = Label.new()
	speaker_label.add_theme_font_size_override("font_size",24)
	speaker_label.add_theme_color_override("font_color",Color("f1cd84"))
	column.add_child(speaker_label)
	content_label = RichTextLabel.new()
	content_label.custom_minimum_size.y = 66
	content_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_label.add_theme_font_size_override("normal_font_size",20)
	column.add_child(content_label)
	options_scroll=ScrollContainer.new()
	options_scroll.custom_minimum_size.y=190
	options_scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	options_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	options_scroll.follow_focus=true
	column.add_child(options_scroll)
	choices_box = VBoxContainer.new()
	choices_box.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	options_scroll.add_child(choices_box)
	panel_root.hide()

func open(speaker: String, lines: Array[String], options: Array = [], actor: Node = null, callback: Callable = Callable(), finish: Callable = Callable(), dismissible := true) -> bool:
	if active or get_tree().paused or lines.is_empty():
		return false
	active = true
	allow_close = dismissible
	was_paused = get_tree().paused
	get_tree().paused = true
	source = actor
	on_choice = callback
	on_closed = finish
	pages = lines.duplicate()
	page_index = 0
	choices = options.duplicate(true)
	speaker_label.text = speaker
	portrait.texture = null
	if is_instance_valid(actor) and actor.get("animated_sprite") != null:
		var sprite: AnimatedSprite2D = actor.animated_sprite
		portrait.texture = sprite.sprite_frames.get_frame_texture(sprite.animation,sprite.frame)
		# Strip sheets can have large transparent cells; crop the portrait UVs only.
		if portrait.texture != null:
			var image := portrait.texture.get_image()
			if image != null and not image.is_compressed():
				var used := image.get_used_rect()
				if used.has_area():
					var crop := AtlasTexture.new()
					crop.atlas = portrait.texture
					crop.region = used
					portrait.texture = crop
	panel_root.show()
	_render()
	return true

func _render() -> void:
	content_label.text = pages[page_index]
	content_label.scroll_to_line(0)
	portrait.visible=portrait.texture!=null
	for child in choices_box.get_children():
		choices_box.remove_child(child)
		child.queue_free()
	if page_index < pages.size()-1:
		add_choice("继续  ·  E / Enter", "next")
	else:
		for option: Dictionary in choices:
			add_choice(str(option.text),str(option.id),option.get("icon"),bool(option.get("disabled",false)))
		if allow_close: add_choice("结束对话  ·  Esc", "close")
	# Keep merchant options visible at the default 720p viewport.
	var options_height:=clampi(ceili(choices_box.get_combined_minimum_size().y),100,320)
	options_scroll.custom_minimum_size.y=options_height
	# Reserve actual reading space for manuals; keep both panes scrollable on small screens.
	var line_count:=0
	var chars_per_line:=42 if portrait.visible else 50
	for line in pages[page_index].split("\n"):
		line_count+=maxi(1,ceili(float(line.length())/chars_per_line))
	var available:=maxi(220,int(get_viewport().get_visible_rect().size.y)-80)
	var reading_height:=clampi(line_count*29,90,mini(330,maxi(90,available-options_height-108)))
	content_label.custom_minimum_size.y=reading_height
	dialogue_panel.offset_top=-mini(available,maxi(350,options_height+reading_height+108))
	options_scroll.scroll_vertical=0
	for button in choices_box.get_children():
		if not button.disabled:
			button.grab_focus()
			break

func add_choice(text: String, id: String, icon: Texture2D=null, disabled:=false) -> void:
	var button := Button.new()
	button.text = text
	button.icon=icon
	button.expand_icon=true
	button.add_theme_constant_override("icon_max_width",28)
	button.disabled=disabled
	button.set_meta("choice_id",id)
	if icon!=null:
		button.alignment=HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size.y=36
	button.add_theme_font_size_override("font_size",16)
	button.pressed.connect(select.bind(id))
	choices_box.add_child(button)

func select(id: String) -> void:
	if not active:
		return
	if id == "next":
		page_index = mini(page_index+1,pages.size()-1)
		_render()
	elif id == "close":
		if allow_close: close()
	elif on_choice.is_valid():
		on_choice.call(id)

func reply(text: String) -> void:
	content_label.text = text

func show_page(speaker: String, text: String, options: Array, icon: Texture2D=null) -> void:
	if not active: return
	speaker_label.text=speaker
	portrait.texture=icon
	if icon!=null:
		var image:=icon.get_image()
		if image!=null and not image.is_compressed():
			var used:=image.get_used_rect()
			if used.has_area():
				var crop:=AtlasTexture.new()
				crop.atlas=icon
				crop.region=used
				portrait.texture=crop
	pages.assign([text])
	page_index=0
	choices=options.duplicate(true)
	_render()

func close() -> void:
	if not active:
		return
	active = false
	panel_root.hide()
	get_tree().paused = was_paused
	for player in get_tree().get_nodes_in_group("players"):
		if player.has_method("note_activity"):
			player.note_activity()
	var finish := on_closed
	on_choice = Callable()
	on_closed = Callable()
	source = null
	closed.emit()
	if finish.is_valid():
		finish.call()

func _input(event: InputEvent) -> void:
	if not active:
		return
	if event is InputEventKey:
		if event.pressed and not event.echo:
			if event.physical_keycode == KEY_ESCAPE:
				if allow_close: close()
			elif event.physical_keycode == KEY_E or event.physical_keycode == KEY_ENTER or event.physical_keycode == KEY_SPACE:
				if page_index < pages.size()-1:
					select("next")
				elif get_viewport().gui_get_focus_owner() is Button:
					get_viewport().gui_get_focus_owner().pressed.emit()
		# Allow UI focus navigation; swallow gameplay keys before other _input callbacks.
		if event.physical_keycode not in [KEY_UP,KEY_DOWN,KEY_LEFT,KEY_RIGHT,KEY_TAB]:
			get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	if active and not is_instance_valid(source):
		close()
