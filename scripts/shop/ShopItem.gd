extends Control

signal buy_requested(item_data: Dictionary, item_view: Control)

const SOLD_STAMP_PATH: String = "res://art/ui/sold_out_stamp.png"

var item_data: Dictionary = {}
var name_label: Label
var price_label: Label
var status_label: Label
var buy_button: Button
var icon: ColorRect
var sold_stamp: TextureRect


func _ready() -> void:
	custom_minimum_size = Vector2(300, 250)
	size = Vector2(300, 250)
	_build_ui()


func setup(data: Dictionary) -> void:
	item_data = data.duplicate(true)
	if not is_node_ready():
		return
	_apply_data()


func mark_sold_out() -> void:
	buy_button.disabled = true
	buy_button.text = "已售出"
	status_label.text = "已售出"
	sold_stamp.visible = true
	modulate = Color(0.72, 0.72, 0.72, 1)


func play_insufficient_feedback() -> void:
	status_label.text = "金币不足"
	status_label.add_theme_color_override("font_color", Color(1.0, 0.38, 0.28, 1))
	var origin: Vector2 = position
	var tween: Tween = create_tween()
	tween.tween_property(self, "position", origin + Vector2(12, 0), 0.05)
	tween.tween_property(self, "position", origin - Vector2(12, 0), 0.05)
	tween.tween_property(self, "position", origin, 0.05)


func _build_ui() -> void:
	var panel: Panel = Panel.new()
	panel.size = size
	panel.add_theme_stylebox_override("panel", _panel_style())
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)

	var top_plate: Panel = Panel.new()
	top_plate.position = Vector2(22, 18)
	top_plate.size = Vector2(256, 94)
	top_plate.add_theme_stylebox_override("panel", _preview_style())
	top_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top_plate)

	icon = ColorRect.new()
	icon.position = Vector2(112, 34)
	icon.size = Vector2(76, 60)
	icon.color = Color(0.34, 0.24, 0.16, 1)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(icon)

	status_label = _make_label(Vector2(34, 116), Vector2(232, 24), 18, Color(0.95, 0.74, 0.36, 1))
	name_label = _make_label(Vector2(26, 140), Vector2(248, 36), 24, Color(0.98, 0.86, 0.64, 1))
	price_label = _make_label(Vector2(48, 177), Vector2(204, 28), 21, Color(1.0, 0.74, 0.28, 1))

	buy_button = Button.new()
	buy_button.text = "购买"
	buy_button.position = Vector2(76, 208)
	buy_button.size = Vector2(148, 38)
	buy_button.focus_mode = Control.FOCUS_NONE
	buy_button.add_theme_font_size_override("font_size", 20)
	buy_button.add_theme_font_override("font", _make_game_font(true))
	buy_button.add_theme_stylebox_override("normal", _button_style(false, false))
	buy_button.add_theme_stylebox_override("hover", _button_style(true, false))
	buy_button.add_theme_stylebox_override("pressed", _button_style(true, false))
	buy_button.add_theme_stylebox_override("disabled", _button_style(false, true))
	buy_button.add_theme_color_override("font_color", Color(0.96, 0.84, 0.62, 1))
	buy_button.pressed.connect(Callable(self, "_on_buy_pressed"))
	add_child(buy_button)

	sold_stamp = TextureRect.new()
	sold_stamp.texture = _load_texture_or_null(SOLD_STAMP_PATH)
	sold_stamp.position = Vector2(82, 40)
	sold_stamp.size = Vector2(136, 136)
	sold_stamp.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sold_stamp.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sold_stamp.modulate = Color(1, 1, 1, 0.86)
	sold_stamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sold_stamp.visible = false
	add_child(sold_stamp)

	_apply_data()


func _apply_data() -> void:
	if name_label == null:
		return

	var category: String = str(item_data.get("category", "商品"))
	name_label.text = str(item_data.get("name", "商品"))
	price_label.text = "%d 金币" % int(item_data.get("price", 0))
	status_label.text = category
	status_label.add_theme_color_override("font_color", _category_color(category))
	var color_value: Variant = item_data.get("color", Color(0.34, 0.24, 0.16, 1))
	if color_value is Color:
		icon.color = color_value
	else:
		icon.color = Color(0.34, 0.24, 0.16, 1)


func _panel_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.13, 0.085, 0.055, 0.88)
	style.border_color = Color(0.66, 0.43, 0.19, 0.95)
	style.set_border_width_all(2)
	style.set_corner_radius_all(7)
	style.shadow_color = Color(0, 0, 0, 0.38)
	style.shadow_size = 10
	return style


func _preview_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.24, 0.17, 0.1, 0.58)
	style.border_color = Color(0.88, 0.6, 0.25, 0.45)
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	return style


func _button_style(hover: bool, disabled: bool) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.13, 0.12, 0.11, 0.76) if disabled else Color(0.36, 0.15, 0.08, 0.92)
	style.border_color = Color(0.3, 0.28, 0.24, 0.75) if disabled else (Color(1.0, 0.67, 0.27, 1) if hover else Color(0.7, 0.42, 0.18, 1))
	style.set_border_width_all(2)
	style.set_corner_radius_all(5)
	return style


func _category_color(category: String) -> Color:
	match category:
		"遗物":
			return Color(0.9, 0.78, 0.42, 1)
		"药水":
			return Color(0.72, 0.82, 1.0, 1)
		_:
			return Color(0.96, 0.62, 0.38, 1)


func _make_label(pos: Vector2, label_size: Vector2, font_size: int, font_color: Color) -> Label:
	var label: Label = Label.new()
	label.position = pos
	label.size = label_size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_font_override("font", _make_game_font(font_size >= 22))
	label.add_theme_color_override("font_color", font_color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
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


func _on_buy_pressed() -> void:
	buy_requested.emit(item_data, self)
