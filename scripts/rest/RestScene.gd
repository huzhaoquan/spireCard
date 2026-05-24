extends Control

const MAP_SCENE_PATH: String = "res://scenes/map/MapScene.tscn"
const BACKGROUND_PATH: String = "res://art/backgrounds/rest/rest_bg.png"
const HP_ICON_PATH: String = "res://art/ui/icon_hp.png"
const CAMPFIRE_ICON_PATH: String = "res://art/ui/rest_campfire_icon.png"
const UPGRADE_ICON_PATH: String = "res://art/ui/upgrade_card_icon.png"

var hp_label: Label
var message_label: Label
var rest_button: Button


func _ready() -> void:
	_build_ui()
	_update_hp_label()


func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	_add_background()
	_add_title()
	_add_status_panel()
	_add_action_cards()
	_add_return_button()


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
		fallback.color = Color(0.055, 0.04, 0.032, 1)
		fallback.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(fallback)

	var shade: ColorRect = ColorRect.new()
	shade.color = Color(0, 0, 0, 0.22)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)


func _add_title() -> void:
	_add_label("休息点", Vector2(610, 80), Vector2(700, 82), 58, Color(1.0, 0.76, 0.38, 1), HORIZONTAL_ALIGNMENT_CENTER)
	_add_label("火光短暂驱散尖塔的寒意", Vector2(660, 154), Vector2(600, 36), 24, Color(0.84, 0.73, 0.58, 1), HORIZONTAL_ALIGNMENT_CENTER)


func _add_status_panel() -> void:
	var panel: Panel = _make_panel(Vector2(705, 232), Vector2(510, 84), Color(0.09, 0.06, 0.045, 0.72))
	panel.name = "HpPanel"
	_add_icon(HP_ICON_PATH, Vector2(732, 252), Vector2(44, 44))
	hp_label = _add_label("", Vector2(790, 248), Vector2(370, 48), 30, Color(1.0, 0.42, 0.34, 1), HORIZONTAL_ALIGNMENT_LEFT)


func _add_action_cards() -> void:
	_add_action_card(
		Vector2(448, 408),
		CAMPFIRE_ICON_PATH,
		"休息",
		"恢复最大生命值的 30%",
		"休息",
		Callable(self, "_on_rest_pressed"),
		true
	)
	_add_action_card(
		Vector2(1032, 408),
		UPGRADE_ICON_PATH,
		"升级卡牌",
		"强化一张牌。当前版本先保留入口。",
		"升级",
		Callable(self, "_on_upgrade_pressed"),
		false
	)
	message_label = _add_label("", Vector2(610, 720), Vector2(700, 48), 28, Color(0.95, 0.78, 0.42, 1), HORIZONTAL_ALIGNMENT_CENTER)


func _add_return_button() -> void:
	_add_button("返回地图", Vector2(810, 875), Vector2(300, 64), Callable(self, "_return_to_map"))


func _add_action_card(card_pos: Vector2, icon_path: String, title_text: String, body_text: String, button_text: String, callback: Callable, is_rest: bool) -> void:
	var panel: Panel = _make_panel(card_pos, Vector2(440, 250), Color(0.11, 0.075, 0.052, 0.76))
	panel.name = "%sCard" % title_text
	_add_icon(icon_path, card_pos + Vector2(36, 42), Vector2(112, 112))
	_add_label(title_text, card_pos + Vector2(174, 42), Vector2(220, 42), 30, Color(0.98, 0.78, 0.42, 1), HORIZONTAL_ALIGNMENT_LEFT)
	var body: Label = _add_label(body_text, card_pos + Vector2(174, 92), Vector2(220, 70), 21, Color(0.84, 0.78, 0.66, 1), HORIZONTAL_ALIGNMENT_LEFT)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var button: Button = _add_button(button_text, card_pos + Vector2(174, 178), Vector2(180, 46), callback)
	if is_rest:
		rest_button = button


func _on_rest_pressed() -> void:
	var game_manager: Node = _game_manager()
	var heal_amount: int = int(ceil(float(int(game_manager.get("player_max_hp"))) * 0.3))
	game_manager.call("heal", heal_amount)
	rest_button.disabled = true
	message_label.text = "已恢复生命"
	_update_hp_label()


func _on_upgrade_pressed() -> void:
	message_label.text = "升级卡牌功能未实现"
	print("升级卡牌功能未实现")


func _return_to_map() -> void:
	var game_manager: Node = _game_manager()
	game_manager.call("complete_map_node", str(game_manager.get("current_node_id")))
	get_tree().change_scene_to_file(MAP_SCENE_PATH)


func _update_hp_label() -> void:
	var game_manager: Node = _game_manager()
	hp_label.text = "HP %d / %d" % [int(game_manager.get("player_hp")), int(game_manager.get("player_max_hp"))]


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
	style.border_color = Color(0.78, 0.46, 0.18, 0.82)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.shadow_color = Color(0, 0, 0, 0.36)
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
	style.bg_color = Color(0.13, 0.12, 0.11, 0.76) if disabled else Color(0.34, 0.13, 0.07, 0.92)
	style.border_color = Color(0.28, 0.26, 0.22, 0.75) if disabled else (Color(1.0, 0.66, 0.25, 1) if hover else Color(0.7, 0.4, 0.16, 1))
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
