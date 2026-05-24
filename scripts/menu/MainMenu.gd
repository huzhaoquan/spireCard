extends Control

const MAP_SCENE_PATH: String = "res://scenes/map/MapScene.tscn"
const BACKGROUND_PATH: String = "res://art/backgrounds/menu/main_menu_bg.png"
const TITLE_IMAGE_PATH: String = "res://art/ui/main_menu_title.png"
const BUTTON_ORNAMENT_PATH: String = "res://art/ui/menu_button_ornament.png"
const MENU_BUTTON_SIZE: Vector2 = Vector2(430, 182)
const MENU_BUTTON_TEXT_INSET: Vector2 = Vector2(70, 58)

var buttons: Array[Button] = []


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	_add_background()
	_add_title_block()
	_add_menu_buttons()


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
		fallback.color = Color(0.05, 0.035, 0.03, 1)
		fallback.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(fallback)

	var vignette: ColorRect = ColorRect.new()
	vignette.color = Color(0, 0, 0, 0.28)
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vignette)

	var menu_shade: ColorRect = ColorRect.new()
	menu_shade.position = Vector2(1190, 0)
	menu_shade.size = Vector2(730, 1080)
	menu_shade.color = Color(0.04, 0.03, 0.025, 0.42)
	menu_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(menu_shade)


func _add_title_block() -> void:
	var title_texture: Texture2D = _load_texture_or_null(TITLE_IMAGE_PATH)
	if title_texture != null:
		var title_image: TextureRect = TextureRect.new()
		title_image.texture = title_texture
		title_image.position = Vector2(82, 88)
		title_image.size = Vector2(900, 220)
		title_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		title_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		title_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(title_image)
	else:
		var title: Label = _make_label("尖塔卡牌", Vector2(120, 118), Vector2(820, 112), 82, Color(0.96, 0.76, 0.34, 1), HORIZONTAL_ALIGNMENT_LEFT, true)
		title.add_theme_color_override("font_shadow_color", Color(0.08, 0.02, 0.0, 1))
		title.add_theme_constant_override("shadow_offset_x", 4)
		title.add_theme_constant_override("shadow_offset_y", 4)

	var subtitle: Label = _make_label("在尖塔的阴影下重新洗牌", Vector2(138, 292), Vector2(620, 42), 29, Color(0.84, 0.72, 0.55, 1), HORIZONTAL_ALIGNMENT_LEFT, false)
	subtitle.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	subtitle.add_theme_constant_override("shadow_offset_x", 2)
	subtitle.add_theme_constant_override("shadow_offset_y", 2)


func _add_menu_buttons() -> void:
	var items: Array = [
		["开始游戏", Callable(self, "_on_start_pressed"), true],
		["继续游戏", Callable(self, "_on_continue_pressed"), false],
		["设置", Callable(self, "_on_settings_pressed"), false],
		["退出游戏", Callable(self, "_on_quit_pressed"), false]
	]

	for index in range(items.size()):
		var button_position: Vector2 = Vector2(1304, 282 + index * 168)
		_add_button_ornament(button_position)
		var button: Button = _make_button(str(items[index][0]), button_position, bool(items[index][2]))
		button.pressed.connect(items[index][1])
		add_child(button)
		buttons.append(button)


func _add_button_ornament(button_position: Vector2) -> void:
	var texture: Texture2D = _load_texture_or_null(BUTTON_ORNAMENT_PATH)
	if texture == null:
		return

	var ornament: TextureRect = TextureRect.new()
	ornament.texture = texture
	ornament.position = button_position
	ornament.size = MENU_BUTTON_SIZE
	ornament.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ornament.stretch_mode = TextureRect.STRETCH_SCALE
	ornament.modulate = Color(1, 0.94, 0.78, 0.92)
	ornament.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ornament)


func _make_button(label_text: String, button_position: Vector2, primary: bool) -> Button:
	var button: Button = Button.new()
	button.text = label_text
	button.position = button_position + MENU_BUTTON_TEXT_INSET
	button.size = MENU_BUTTON_SIZE - MENU_BUTTON_TEXT_INSET * 2.0
	button.pivot_offset = button.size * 0.5
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 31)
	button.add_theme_font_override("font", _make_game_font(true))
	button.add_theme_stylebox_override("normal", _button_style(false))
	button.add_theme_stylebox_override("hover", _button_style(true))
	button.add_theme_stylebox_override("pressed", _button_style(true))
	button.add_theme_stylebox_override("disabled", _button_style(false))
	button.add_theme_color_override("font_color", Color(0.96, 0.84, 0.62, 1))
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.94, 0.72, 1))
	return button


func _button_style(hover: bool) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.46, 0.18, 0.06, 0.18) if hover else Color(0, 0, 0, 0)
	style.border_color = Color(0, 0, 0, 0)
	style.set_corner_radius_all(4)
	return style


func _make_label(text: String, pos: Vector2, label_size: Vector2, font_size: int, font_color: Color, alignment: int, display_font: bool) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.position = pos
	label.size = label_size
	label.horizontal_alignment = alignment
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_font_override("font", _make_game_font(display_font))
	label.add_theme_color_override("font_color", font_color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label


func _make_game_font(display_font: bool) -> SystemFont:
	var font: SystemFont = SystemFont.new()
	if display_font:
		font.font_names = PackedStringArray(["LiSu", "FZYaoTi", "STXingkai", "STLiti", "KaiTi", "Microsoft YaHei UI", "Microsoft YaHei"])
	else:
		font.font_names = PackedStringArray(["LiSu", "KaiTi", "STKaiti", "Microsoft YaHei UI", "Microsoft YaHei"])
	return font


func _on_start_pressed() -> void:
	_game_manager().call("start_new_run")
	get_tree().change_scene_to_file(MAP_SCENE_PATH)


func _on_continue_pressed() -> void:
	print("继续游戏功能未实现")


func _on_settings_pressed() -> void:
	print("设置功能未实现")


func _on_quit_pressed() -> void:
	get_tree().quit()


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
