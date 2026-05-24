extends Control

const MAP_SCENE_PATH: String = "res://scenes/map/MapScene.tscn"

var result_label: Label
var option_buttons: Array[Button] = []
var return_button: Button


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var background: ColorRect = ColorRect.new()
	background.color = Color(0.045, 0.04, 0.06, 1)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	_add_label("神秘祭坛", Vector2(610, 150), Vector2(700, 80), 54)
	_add_label("你在黑暗中发现了一座古老祭坛，似乎可以用生命换取力量。", Vector2(460, 285), Vector2(1000, 90), 28)
	result_label = _add_label("", Vector2(560, 660), Vector2(800, 60), 28)

	option_buttons.append(_add_button("失去 10 点生命，获得 100 金币", Vector2(650, 430), Callable(self, "_choose_damage_for_gold")))
	option_buttons.append(_add_button("失去 20 金币，恢复 10 点生命", Vector2(650, 520), Callable(self, "_choose_gold_for_heal")))
	option_buttons.append(_add_button("离开", Vector2(650, 610), Callable(self, "_choose_leave")))

	return_button = _add_button("返回地图", Vector2(760, 780), Callable(self, "_return_to_map"))
	return_button.visible = false


func _choose_damage_for_gold() -> void:
	var game_manager: Node = _game_manager()
	game_manager.call("damage_player", 10)
	game_manager.call("add_gold", 100)
	_finish_choice("你献出鲜血，获得了 100 金币。")


func _choose_gold_for_heal() -> void:
	var game_manager: Node = _game_manager()
	if bool(game_manager.call("spend_gold", 20)):
		game_manager.call("heal", 10)
		_finish_choice("金币化作暖光，恢复了 10 点生命。")
	else:
		_finish_choice("金币不足，祭坛没有回应。")


func _choose_leave() -> void:
	_finish_choice("你离开了祭坛。")


func _finish_choice(text: String) -> void:
	result_label.text = text
	for button in option_buttons:
		button.disabled = true
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
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(0.92, 0.84, 0.68, 1))
	add_child(label)
	return label


func _add_button(text: String, pos: Vector2, callback: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.position = pos
	button.size = Vector2(620, 64)
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 23)
	button.pressed.connect(callback)
	add_child(button)
	return button


func _game_manager() -> Node:
	return get_node("/root/GameManager")
