extends Control

const MAP_SCENE_PATH: String = "res://scenes/map/MapScene.tscn"
const BACKGROUND_PATH: String = "res://art/backgrounds/menu/main_menu_spire_style_bg.png"
const FALLBACK_BACKGROUND_PATH: String = "res://art/backgrounds/menu/main_menu_bg.png"
const LOGO_PATH: String = "res://art/ui/menu/main_menu_logo.png"
const FALLBACK_LOGO_RAW_PATH: String = "res://art/ui/menu/main_menu_logo_raw_magenta.png"

const VIEWPORT_SIZE: Vector2 = Vector2(1920, 1080)
const MENU_START_POSITION: Vector2 = Vector2(470, 660)
const MENU_ITEM_SIZE: Vector2 = Vector2(500, 50)
const MENU_ITEM_GAP: float = 58.0
const LOGO_SCALE: Vector2 = Vector2(0.45, 0.45)

var buttons: Array[Button] = []
var button_tweens: Dictionary = {}


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	_add_background()
	_add_save_info()
	_add_corner_note()
	_add_title_block()
	_add_menu_buttons()


func _add_background() -> void:
	var texture: Texture2D = _load_texture_or_null(BACKGROUND_PATH)
	if texture == null:
		texture = _load_texture_or_null(FALLBACK_BACKGROUND_PATH)

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
		fallback.color = Color(0.035, 0.035, 0.055, 1.0)
		fallback.set_anchors_preset(Control.PRESET_FULL_RECT)
		fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(fallback)

	var atmosphere_shade: ColorRect = ColorRect.new()
	atmosphere_shade.color = Color(0.0, 0.0, 0.0, 0.12)
	atmosphere_shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	atmosphere_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(atmosphere_shade)


func _add_save_info() -> void:
	var has_save: bool = bool(_game_manager().call("has_saved_run"))
	var icon_back: ColorRect = ColorRect.new()
	icon_back.name = "SaveSlotIcon"
	icon_back.position = Vector2(22.0, 22.0)
	icon_back.size = Vector2(46.0, 46.0)
	icon_back.color = Color(0.48, 0.18, 0.14, 0.92)
	icon_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(icon_back)

	var icon_mark: Label = _make_label("1", Vector2(37.0, 25.0), Vector2(34.0, 34.0), 22, Color(1.0, 0.82, 0.34, 1.0), HORIZONTAL_ALIGNMENT_CENTER, true)
	icon_mark.add_theme_color_override("font_outline_color", Color(0.05, 0.02, 0.015, 1.0))
	icon_mark.add_theme_constant_override("outline_size", 3)

	var save_label: Label = _make_label("存档1" if has_save else "无存档", Vector2(82.0, 20.0), Vector2(160.0, 26.0), 25, Color(1.0, 0.78, 0.28, 1.0), HORIZONTAL_ALIGNMENT_LEFT, true)
	save_label.add_theme_color_override("font_outline_color", Color(0.03, 0.025, 0.02, 1.0))
	save_label.add_theme_constant_override("outline_size", 2)

	var edit_label: Label = _make_label("可继续游戏" if has_save else "开始新旅程", Vector2(82.0, 50.0), Vector2(170.0, 24.0), 16, Color(0.40, 0.88, 1.0, 0.92), HORIZONTAL_ALIGNMENT_LEFT, false)
	edit_label.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.03, 1.0))
	edit_label.add_theme_constant_override("outline_size", 2)


func _add_corner_note() -> void:
	var version_label: Label = _make_label("v0.1", Vector2(1720.0, 24.0), Vector2(120.0, 24.0), 16, Color(0.20, 0.18, 0.15, 0.58), HORIZONTAL_ALIGNMENT_RIGHT, false)
	version_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var note_button: Button = Button.new()
	note_button.name = "NoteButton"
	note_button.text = "日志"
	note_button.position = Vector2(1844.0, 18.0)
	note_button.size = Vector2(58.0, 50.0)
	note_button.focus_mode = Control.FOCUS_NONE
	note_button.add_theme_font_override("font", _make_game_font(false))
	note_button.add_theme_font_size_override("font_size", 17)
	note_button.add_theme_color_override("font_color", Color(0.18, 0.12, 0.08, 0.85))
	note_button.add_theme_color_override("font_hover_color", Color(0.34, 0.15, 0.08, 1.0))
	note_button.add_theme_stylebox_override("normal", _note_button_style(false))
	note_button.add_theme_stylebox_override("hover", _note_button_style(true))
	note_button.add_theme_stylebox_override("pressed", _note_button_style(true))
	note_button.pressed.connect(_on_note_pressed)
	add_child(note_button)


func _add_title_block() -> void:
	var logo_texture: Texture2D = _load_texture_or_null(LOGO_PATH)
	if logo_texture == null:
		logo_texture = _load_texture_or_null(FALLBACK_LOGO_RAW_PATH)

	if logo_texture != null:
		var logo_shadow: TextureRect = TextureRect.new()
		logo_shadow.texture = logo_texture
		logo_shadow.position = Vector2(366.0, 164.0)
		logo_shadow.size = logo_texture.get_size()
		logo_shadow.scale = LOGO_SCALE
		logo_shadow.modulate = Color(0.0, 0.0, 0.0, 0.48)
		logo_shadow.stretch_mode = TextureRect.STRETCH_KEEP
		logo_shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(logo_shadow)

		var logo: TextureRect = TextureRect.new()
		logo.texture = logo_texture
		logo.position = Vector2(350.0, 148.0)
		logo.size = logo_texture.get_size()
		logo.scale = LOGO_SCALE
		logo.stretch_mode = TextureRect.STRETCH_KEEP
		logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(logo)
	else:
		var fallback_title: Label = _make_label("尖塔卡牌", Vector2(500.0, 250.0), Vector2(620.0, 130.0), 92, Color(1.0, 0.78, 0.12, 1.0), HORIZONTAL_ALIGNMENT_CENTER, true)
		fallback_title.add_theme_color_override("font_outline_color", Color(0.03, 0.02, 0.015, 1.0))
		fallback_title.add_theme_constant_override("outline_size", 6)

	var subtitle: Label = _make_label("在尖塔的阴影下重新洗牌", Vector2(400.0, 560.0), Vector2(620.0, 34.0), 24, Color(0.78, 0.86, 0.76, 0.84), HORIZONTAL_ALIGNMENT_CENTER, false)
	subtitle.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.92))
	subtitle.add_theme_constant_override("outline_size", 2)


func _add_menu_buttons() -> void:
	var has_save: bool = bool(_game_manager().call("has_saved_run"))
	var items: Array = [
		["继续游戏", Callable(self, "_on_continue_pressed"), has_save],
		["开始游戏", Callable(self, "_on_start_pressed"), true],
		["设置", Callable(self, "_on_settings_pressed"), true],
		["退出游戏", Callable(self, "_on_quit_pressed"), true]
	]

	for index in range(items.size()):
		var button_position: Vector2 = MENU_START_POSITION + Vector2(0.0, MENU_ITEM_GAP * float(index))
		var button: Button = _make_menu_button(str(items[index][0]), button_position, bool(items[index][2]))
		button.pressed.connect(items[index][1])
		button.mouse_entered.connect(Callable(self, "_on_menu_button_hovered").bind(button, true))
		button.mouse_exited.connect(Callable(self, "_on_menu_button_hovered").bind(button, false))
		add_child(button)
		buttons.append(button)


func _make_menu_button(label_text: String, button_position: Vector2, enabled: bool) -> Button:
	var button: Button = Button.new()
	button.text = label_text
	button.position = button_position
	button.set_meta("rest_position", button_position)
	button.size = MENU_ITEM_SIZE
	button.pivot_offset = Vector2(0.0, MENU_ITEM_SIZE.y * 0.5)
	button.focus_mode = Control.FOCUS_NONE
	button.disabled = not enabled
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.add_theme_font_size_override("font_size", 33)
	button.add_theme_font_override("font", _make_game_font(true))
	button.add_theme_stylebox_override("normal", _menu_button_style(false))
	button.add_theme_stylebox_override("hover", _menu_button_style(true))
	button.add_theme_stylebox_override("pressed", _menu_button_style(true))
	button.add_theme_stylebox_override("disabled", _menu_button_style(false))
	button.add_theme_color_override("font_color", Color(0.88, 0.86, 0.80, 1.0))
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.84, 0.32, 1.0))
	button.add_theme_color_override("font_pressed_color", Color(0.86, 0.56, 0.20, 1.0))
	button.add_theme_color_override("font_disabled_color", Color(0.46, 0.45, 0.43, 0.65))
	button.add_theme_color_override("font_outline_color", Color(0.02, 0.018, 0.014, 1.0))
	button.add_theme_constant_override("outline_size", 4)
	return button


func _on_menu_button_hovered(button: Button, hovered: bool) -> void:
	if button == null or button.disabled:
		return

	if button_tweens.has(button):
		var old_tween: Tween = button_tweens[button] as Tween
		if old_tween != null and old_tween.is_valid():
			old_tween.kill()

	var rest_position: Vector2 = button.get_meta("rest_position", button.position)
	var target_position: Vector2 = rest_position + Vector2(10.0, 0.0) if hovered else rest_position
	var target_scale: Vector2 = Vector2(1.04, 1.04) if hovered else Vector2.ONE

	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "position", target_position, 0.12)
	tween.tween_property(button, "scale", target_scale, 0.12)
	button_tweens[button] = tween


func _make_title_label(text: String, pos: Vector2, label_size: Vector2, font_size: int) -> Label:
	var label: Label = _make_label(text, pos, label_size, font_size, Color(1.0, 0.78, 0.12, 1.0), HORIZONTAL_ALIGNMENT_LEFT, true)
	label.add_theme_color_override("font_outline_color", Color(0.03, 0.02, 0.015, 1.0))
	label.add_theme_constant_override("outline_size", 6)
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.65))
	label.add_theme_constant_override("shadow_offset_x", 3)
	label.add_theme_constant_override("shadow_offset_y", 4)
	return label


func _make_title_shadow(text: String, pos: Vector2, label_size: Vector2, font_size: int) -> Label:
	var label: Label = _make_label(text, pos, label_size, font_size, Color(0.0, 0.0, 0.0, 0.58), HORIZONTAL_ALIGNMENT_LEFT, true)
	label.add_theme_constant_override("outline_size", 0)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _menu_button_style(hover: bool) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.035, 0.025, 0.12) if hover else Color(0, 0, 0, 0)
	style.border_color = Color(0.95, 0.68, 0.22, 0.22) if hover else Color(0, 0, 0, 0)
	style.border_width_left = 1 if hover else 0
	style.border_width_top = 1 if hover else 0
	style.border_width_right = 1 if hover else 0
	style.border_width_bottom = 1 if hover else 0
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	return style


func _note_button_style(hover: bool) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.77, 0.62, 0.38, 0.82) if hover else Color(0.64, 0.50, 0.31, 0.72)
	style.border_color = Color(0.16, 0.09, 0.04, 0.75)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
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
		font.font_names = PackedStringArray(["KaiTi", "STKaiti", "Microsoft YaHei UI", "Microsoft YaHei"])
	return font


func _on_start_pressed() -> void:
	_game_manager().call("start_new_run")
	get_tree().change_scene_to_file(MAP_SCENE_PATH)


func _on_continue_pressed() -> void:
	if bool(_game_manager().call("load_run")):
		get_tree().change_scene_to_file(MAP_SCENE_PATH)


func _on_settings_pressed() -> void:
	print("设置功能未实现")


func _on_note_pressed() -> void:
	print("日志功能未实现")


func _on_quit_pressed() -> void:
	get_tree().quit()


func _load_texture_or_null(path: String) -> Texture2D:
	if path.is_empty():
		return null

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
