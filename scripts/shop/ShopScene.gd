extends Control

const MAP_SCENE_PATH: String = "res://scenes/map/MapScene.tscn"
const SHOP_ITEM_SCENE: PackedScene = preload("res://scenes/shop/ShopItem.tscn")
const BACKGROUND_PATH: String = "res://art/backgrounds/shop/shop_bg.png"
const GOLD_ICON_PATH: String = "res://art/ui/icon_gold.png"
const SHELF_PANEL_PATH: String = "res://art/ui/shop_shelf_panel.png"

var gold_label: Label
var message_label: Label


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_add_background()
	_add_header()
	_add_shop_area()
	_add_footer_buttons()
	_update_gold()


func _add_background() -> void:
	var texture: Texture2D = _load_texture_or_null(BACKGROUND_PATH)
	if texture != null:
		var background: TextureRect = TextureRect.new()
		background.texture = texture
		background.set_anchors_preset(Control.PRESET_FULL_RECT)
		background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		background.stretch_mode = TextureRect.STRETCH_SCALE
		background.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(background)
	else:
		var fallback: ColorRect = ColorRect.new()
		fallback.color = Color(0.06, 0.04, 0.03, 1)
		fallback.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(fallback)

	var shade: ColorRect = ColorRect.new()
	shade.color = Color(0, 0, 0, 0.26)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)


func _add_header() -> void:
	var header: Panel = _make_panel(Vector2(46, 34), Vector2(1828, 92), Color(0.08, 0.055, 0.04, 0.74))
	header.name = "ShopHeader"

	_add_label("商店", Vector2(760, 42), Vector2(400, 70), 50, Color(0.96, 0.76, 0.38, 1), HORIZONTAL_ALIGNMENT_CENTER)
	_add_label("陌生商人把战利品铺在烛光下", Vector2(720, 104), Vector2(480, 34), 22, Color(0.78, 0.68, 0.52, 1), HORIZONTAL_ALIGNMENT_CENTER)

	var gold_panel: Panel = _make_panel(Vector2(64, 54), Vector2(250, 52), Color(0.16, 0.1, 0.055, 0.78))
	gold_panel.name = "GoldPanel"
	_add_icon(GOLD_ICON_PATH, Vector2(82, 63), Vector2(34, 34))
	gold_label = _add_label("", Vector2(122, 60), Vector2(170, 40), 26, Color(1.0, 0.78, 0.32, 1), HORIZONTAL_ALIGNMENT_LEFT)


func _add_shop_area() -> void:
	_add_shelf_frame(Vector2(214, 166), Vector2(1492, 656))
	_add_label("商品", Vector2(270, 174), Vector2(180, 42), 28, Color(0.92, 0.75, 0.42, 1), HORIZONTAL_ALIGNMENT_LEFT)

	var items: Array = _get_shop_items()
	for index in range(items.size()):
		var item_view: Control = SHOP_ITEM_SCENE.instantiate() as Control
		var row: int = floori(float(index) / 3.0)
		item_view.position = Vector2(310 + float(index % 3) * 440.0, 250 + float(row) * 300.0)
		add_child(item_view)
		item_view.call("setup", items[index])
		item_view.connect("buy_requested", Callable(self, "_on_buy_requested"))

	message_label = _add_label("", Vector2(660, 838), Vector2(600, 44), 24, Color(0.92, 0.78, 0.48, 1), HORIZONTAL_ALIGNMENT_CENTER)


func _add_footer_buttons() -> void:
	_add_button("删除卡牌", Vector2(580, 910), Vector2(300, 62), Callable(self, "_on_remove_card_pressed"))
	_add_button("返回地图", Vector2(1040, 910), Vector2(300, 62), Callable(self, "_return_to_map"))


func _add_shelf_frame(pos: Vector2, panel_size: Vector2) -> void:
	var panel: Panel = _make_panel(pos, panel_size, Color(0.1, 0.07, 0.045, 0.62))
	panel.name = "ShelfPanel"

	var texture: Texture2D = _load_texture_or_null(SHELF_PANEL_PATH)
	if texture == null:
		return
	var frame: TextureRect = TextureRect.new()
	frame.texture = texture
	frame.position = pos
	frame.size = panel_size
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_SCALE
	frame.modulate = Color(1, 0.92, 0.78, 0.46)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)


func _get_shop_items() -> Array:
	return [
		{"id": "strike_plus", "name": "强化打击", "price": 60, "category": "卡牌", "color": Color(0.5, 0.1, 0.08, 1)},
		{"id": "guard", "name": "稳固防御", "price": 55, "category": "卡牌", "color": Color(0.1, 0.25, 0.55, 1)},
		{"id": "focus", "name": "专注", "price": 80, "category": "卡牌", "color": Color(0.42, 0.25, 0.08, 1)},
		{"id": "old_charm", "name": "古旧护符", "price": 120, "category": "遗物", "color": Color(0.58, 0.45, 0.18, 1)},
		{"id": "iron_scale", "name": "铁鳞片", "price": 110, "category": "遗物", "color": Color(0.28, 0.32, 0.36, 1)},
		{"id": "fire_potion", "name": "火焰药水", "price": 45, "category": "药水", "color": Color(0.78, 0.2, 0.08, 1)}
	]


func _on_buy_requested(item_data: Dictionary, item_view: Control) -> void:
	var game_manager: Node = _game_manager()
	var price: int = int(item_data.get("price", 0))
	if not bool(game_manager.call("spend_gold", price)):
		item_view.call("play_insufficient_feedback")
		message_label.text = "金币不足"
		return

	var category: String = str(item_data.get("category", ""))
	if category == "遗物":
		game_manager.call("add_relic", item_data)
	elif category == "药水":
		game_manager.call("add_potion", item_data)
	else:
		game_manager.call("add_card", item_data)

	item_view.call("mark_sold_out")
	message_label.text = "购买了 %s" % str(item_data.get("name", "商品"))
	_update_gold()


func _on_remove_card_pressed() -> void:
	message_label.text = "删除卡牌功能未实现"
	print("删除卡牌功能未实现")


func _return_to_map() -> void:
	var game_manager: Node = _game_manager()
	game_manager.call("complete_map_node", str(game_manager.get("current_node_id")))
	get_tree().change_scene_to_file(MAP_SCENE_PATH)


func _update_gold() -> void:
	gold_label.text = "%d" % int(_game_manager().get("gold"))


func _make_panel(pos: Vector2, panel_size: Vector2, color: Color) -> Panel:
	var panel: Panel = Panel.new()
	panel.position = pos
	panel.size = panel_size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _panel_style(color))
	add_child(panel)
	return panel


func _panel_style(color: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color(0.72, 0.48, 0.22, 0.82)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.shadow_color = Color(0, 0, 0, 0.34)
	style.shadow_size = 12
	return style


func _add_label(text: String, pos: Vector2, label_size: Vector2, font_size: int, font_color: Color, alignment: int) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.position = pos
	label.size = label_size
	label.horizontal_alignment = alignment
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_font_override("font", _make_game_font(font_size >= 28))
	label.add_theme_color_override("font_color", font_color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label


func _add_button(text: String, pos: Vector2, button_size: Vector2, callback: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.position = pos
	button.size = button_size
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 24)
	button.add_theme_font_override("font", _make_game_font(true))
	button.add_theme_stylebox_override("normal", _button_style(false, false))
	button.add_theme_stylebox_override("hover", _button_style(true, false))
	button.add_theme_stylebox_override("pressed", _button_style(true, false))
	button.add_theme_stylebox_override("disabled", _button_style(false, true))
	button.add_theme_color_override("font_color", Color(0.96, 0.84, 0.62, 1))
	button.pressed.connect(callback)
	add_child(button)
	return button


func _button_style(hover: bool, disabled: bool) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.13, 0.12, 0.11, 0.76) if disabled else Color(0.28, 0.12, 0.07, 0.9)
	style.border_color = Color(0.28, 0.26, 0.22, 0.75) if disabled else (Color(1.0, 0.68, 0.28, 1) if hover else Color(0.68, 0.42, 0.18, 1))
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	return style


func _add_icon(path: String, pos: Vector2, icon_size: Vector2) -> void:
	var texture: Texture2D = _load_texture_or_null(path)
	if texture == null:
		return
	var icon: TextureRect = TextureRect.new()
	icon.texture = texture
	icon.position = pos
	icon.size = icon_size
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(icon)


func _make_game_font(display_font: bool) -> SystemFont:
	var font: SystemFont = SystemFont.new()
	if display_font:
		font.font_names = PackedStringArray(["LiSu", "FZYaoTi", "STXingkai", "STLiti", "KaiTi", "Microsoft YaHei UI", "Microsoft YaHei"])
	else:
		font.font_names = PackedStringArray(["LiSu", "KaiTi", "STKaiti", "Microsoft YaHei UI", "Microsoft YaHei"])
	return font


func _load_texture_or_null(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var resource: Resource = ResourceLoader.load(path)
		if resource is Texture2D:
			return resource as Texture2D

	if FileAccess.file_exists(path):
		var image: Image = Image.new()
		if image.load(path) == OK:
			return ImageTexture.create_from_image(image)

	return null


func _game_manager() -> Node:
	return get_node("/root/GameManager")
