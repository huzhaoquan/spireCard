extends Control

const MAP_SCENE_PATH: String = "res://scenes/map/MapScene.tscn"

var chest_button: Button
var result_label: Label
var return_button: Button
var opened: bool = false


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var background: ColorRect = ColorRect.new()
	background.color = Color(0.045, 0.035, 0.025, 1)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	_add_label("宝箱房", Vector2(760, 120), Vector2(400, 80), 52)
	result_label = _add_label("", Vector2(560, 620), Vector2(800, 70), 30)

	chest_button = Button.new()
	chest_button.text = "宝箱"
	chest_button.position = Vector2(810, 330)
	chest_button.size = Vector2(300, 180)
	chest_button.pivot_offset = chest_button.size * 0.5
	chest_button.add_theme_font_size_override("font_size", 42)
	chest_button.pressed.connect(_on_chest_pressed)
	add_child(chest_button)

	return_button = Button.new()
	return_button.text = "返回地图"
	return_button.position = Vector2(800, 760)
	return_button.size = Vector2(320, 64)
	return_button.visible = false
	return_button.add_theme_font_size_override("font_size", 24)
	return_button.pressed.connect(_return_to_map)
	add_child(return_button)


func _on_chest_pressed() -> void:
	if opened:
		return

	opened = true
	chest_button.disabled = true
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(chest_button, "scale", Vector2(1.18, 1.18), 0.22)
	tween.tween_property(chest_button, "modulate", Color(1.5, 1.25, 0.65, 1), 0.18)
	tween.tween_property(chest_button, "scale", Vector2.ONE, 0.18)

	var relic: Dictionary = {"id": "old_charm", "name": "古旧护符", "description": "战斗开始时获得 3 点格挡"}
	_game_manager().call("add_relic", relic)
	result_label.text = "获得遗物：古旧护符"
	return_button.visible = true


func _return_to_map() -> void:
	var game_manager: Node = _game_manager()
	game_manager.call("complete_map_node", str(game_manager.get("current_node_id")))
	get_tree().change_scene_to_file(MAP_SCENE_PATH)


func _add_label(text: String, pos: Vector2, label_size: Vector2, font_size: int) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.position = pos
	label.size = label_size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(0.95, 0.84, 0.62, 1))
	add_child(label)
	return label


func _game_manager() -> Node:
	return get_node("/root/GameManager")
