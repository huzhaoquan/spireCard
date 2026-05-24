extends Control

signal node_clicked(node_data: Dictionary)
signal node_hovered(node_data: Dictionary)

const ICON_PATHS := {
	"battle_normal": "res://art/map/icon_battle_normal.png",
	"battle_elite": "res://art/map/icon_battle_elite.png",
	"battle_boss": "res://art/map/icon_battle_boss.png",
	"shop": "res://art/map/icon_shop.png",
	"rest": "res://art/map/icon_rest.png",
	"event": "res://art/map/icon_event.png",
	"treasure": "res://art/map/icon_treasure.png"
}

const TYPE_LABELS := {
	"battle_normal": "战",
	"battle_elite": "精",
	"battle_boss": "王",
	"shop": "商",
	"rest": "休",
	"event": "?",
	"treasure": "宝"
}

const TYPE_COLORS := {
	"battle_normal": Color(0.55, 0.13, 0.1, 1.0),
	"battle_elite": Color(0.45, 0.08, 0.5, 1.0),
	"battle_boss": Color(0.72, 0.08, 0.07, 1.0),
	"shop": Color(0.75, 0.48, 0.12, 1.0),
	"rest": Color(0.95, 0.42, 0.12, 1.0),
	"event": Color(0.22, 0.28, 0.52, 1.0),
	"treasure": Color(0.8, 0.62, 0.16, 1.0)
}

const RING_PATHS := {
	"locked": "res://art/map/map_node_ring.png",
	"available": "res://art/map/map_node_ring_available.png",
	"completed": "res://art/map/map_node_ring_completed.png"
}

var node_data: Dictionary = {}
var node_state: String = "locked"
var ring_rect: TextureRect
var icon_rect: TextureRect
var fallback: ColorRect
var label: Label
var breathe_tween: Tween


func _ready() -> void:
	custom_minimum_size = Vector2(96, 96)
	size = Vector2(96, 96)
	pivot_offset = size * 0.5
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()
	mouse_entered.connect(Callable(self, "_on_mouse_entered"))
	mouse_exited.connect(Callable(self, "_on_mouse_exited"))
	gui_input.connect(Callable(self, "_on_gui_input"))


func setup(data: Dictionary) -> void:
	node_data = data.duplicate(true)
	_apply_icon()


func set_state(new_state: String) -> void:
	node_state = new_state
	mouse_filter = Control.MOUSE_FILTER_STOP
	_stop_breathe()
	_apply_ring()

	if node_state == "available":
		modulate = Color(1, 1, 1, 1)
		_start_breathe()
	elif node_state == "completed":
		modulate = Color(0.45, 0.45, 0.45, 1)
	else:
		modulate = Color(1, 1, 1, 0.35)


func _build_ui() -> void:
	ring_rect = TextureRect.new()
	ring_rect.position = Vector2.ZERO
	ring_rect.size = Vector2(96, 96)
	ring_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ring_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ring_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ring_rect)

	fallback = ColorRect.new()
	fallback.position = Vector2(24, 24)
	fallback.size = Vector2(48, 48)
	fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fallback)

	icon_rect = TextureRect.new()
	icon_rect.position = Vector2(18, 18)
	icon_rect.size = Vector2(60, 60)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(icon_rect)

	label = Label.new()
	label.size = Vector2(96, 96)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_color", Color(1, 0.92, 0.72, 1))
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	_apply_ring()


func _apply_icon() -> void:
	var node_type: String = str(node_data.get("type", "battle_normal"))
	var type_color: Variant = TYPE_COLORS.get(node_type, Color(0.25, 0.25, 0.25, 1))
	if type_color is Color:
		fallback.color = type_color
	else:
		fallback.color = Color(0.25, 0.25, 0.25, 1)
	label.text = str(TYPE_LABELS.get(node_type, "?"))

	var path: String = str(ICON_PATHS.get(node_type, ""))
	var loaded_texture: Texture2D = _load_texture_or_null(path)
	if loaded_texture != null:
		icon_rect.texture = loaded_texture
		icon_rect.visible = true
		fallback.visible = false
		label.visible = false
		return

	icon_rect.visible = false
	fallback.visible = true
	label.visible = true


func _apply_ring() -> void:
	if ring_rect == null:
		return

	var path: String = str(RING_PATHS.get(node_state, RING_PATHS["locked"]))
	var ring_texture: Texture2D = _load_texture_or_null(path)
	if ring_texture == null:
		ring_rect.visible = false
		return

	ring_rect.texture = ring_texture
	ring_rect.visible = true


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


func _on_gui_input(event: InputEvent) -> void:
	if node_state != "available":
		return
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			node_clicked.emit(node_data)
			accept_event()


func _on_mouse_entered() -> void:
	node_hovered.emit(node_data)
	if node_state == "available":
		_tween_scale(Vector2(1.15, 1.15))


func _on_mouse_exited() -> void:
	if node_state != "available":
		return
	_tween_scale(Vector2.ONE)


func _tween_scale(target_scale: Vector2) -> void:
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", target_scale, 0.12)


func _start_breathe() -> void:
	breathe_tween = create_tween()
	breathe_tween.set_loops()
	breathe_tween.tween_property(self, "modulate", Color(1.25, 1.18, 0.86, 1), 0.65)
	breathe_tween.tween_property(self, "modulate", Color(1, 1, 1, 1), 0.65)


func _stop_breathe() -> void:
	if breathe_tween != null and breathe_tween.is_valid():
		breathe_tween.kill()
	breathe_tween = null
