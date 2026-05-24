extends Control

const MAP_NODE_SCENE: PackedScene = preload("res://scenes/map/MapNode.tscn")
const BATTLE_SCENE_PATH: String = "res://scenes/battle/BattleScene.tscn"
const SHOP_SCENE_PATH: String = "res://scenes/shop/ShopScene.tscn"
const REST_SCENE_PATH: String = "res://scenes/rest/RestScene.tscn"
const EVENT_SCENE_PATH: String = "res://scenes/event/EventScene.tscn"
const TREASURE_SCENE_PATH: String = "res://scenes/treasure/TreasureScene.tscn"
const MAIN_MENU_SCENE_PATH: String = "res://scenes/menu/MainMenu.tscn"

const MAP_BACKGROUND_PATH: String = "res://art/map/map_bg_dark_fantasy.png"
const RETURN_ORNAMENT_PATH: String = "res://art/map/map_return_button_ornament.png"
const TAB_ICONS := {
	"map": "res://art/map/icon_map_tab.png",
	"deck": "res://art/map/icon_deck_tab.png",
	"relic": "res://art/map/icon_relic_tab.png",
	"settings": "res://art/map/icon_settings_tab.png"
}

const TYPE_LABELS := {
	"battle_normal": "普通战斗",
	"battle_elite": "精英战斗",
	"battle_boss": "首领",
	"shop": "商人",
	"rest": "休息营地",
	"event": "神秘事件",
	"treasure": "宝藏"
}

const TYPE_DETAILS := {
	"battle_normal": "一场标准遭遇。胜利后获得金币并继续前进。",
	"battle_elite": "更危险的敌人，风险更高，奖励也更好。",
	"battle_boss": "本章最后的威胁。击败它才能离开这片荒原。",
	"shop": "商人营地。购买卡牌、遗物或药水。",
	"rest": "旅途中的安全营地。休息恢复，或准备升级卡牌。",
	"event": "未知遭遇。可能是机遇，也可能是代价。",
	"treasure": "被遗忘的宝箱，通常藏着遗物。"
}

const MAP_NODES: Array = [
	{"id": "1-1", "type": "rest", "title": "破碎营火", "position": Vector2(920, 910), "next_ids": ["2-1", "2-2"]},
	{"id": "2-1", "type": "battle_normal", "title": "沼泽入口", "position": Vector2(700, 800), "next_ids": ["3-1", "3-2"]},
	{"id": "2-2", "type": "battle_elite", "title": "巡猎者营地", "position": Vector2(1120, 785), "next_ids": ["3-2", "3-3"]},
	{"id": "3-1", "type": "event", "title": "雾中石碑", "position": Vector2(610, 665), "next_ids": ["4-1"]},
	{"id": "3-2", "type": "battle_normal", "title": "林间伏击", "position": Vector2(920, 660), "next_ids": ["4-1", "4-2"]},
	{"id": "3-3", "type": "treasure", "title": "沉船宝箱", "position": Vector2(1250, 650), "next_ids": ["4-2"]},
	{"id": "4-1", "type": "shop", "title": "流亡商队", "position": Vector2(740, 525), "next_ids": ["5-1", "5-2"]},
	{"id": "4-2", "type": "event", "title": "黑塔低语", "position": Vector2(1080, 520), "next_ids": ["5-2", "5-3"]},
	{"id": "5-1", "type": "battle_normal", "title": "废墟守卫", "position": Vector2(650, 390), "next_ids": ["6-1"]},
	{"id": "5-2", "type": "rest", "title": "古树营地", "position": Vector2(920, 405), "next_ids": ["6-1", "6-2"]},
	{"id": "5-3", "type": "battle_elite", "title": "鸦冠骑士", "position": Vector2(1215, 390), "next_ids": ["6-2"]},
	{"id": "6-1", "type": "battle_normal", "title": "城门前哨", "position": Vector2(790, 275), "next_ids": ["7-1"]},
	{"id": "6-2", "type": "shop", "title": "终末补给", "position": Vector2(1115, 275), "next_ids": ["7-1"]},
	{"id": "7-1", "type": "battle_boss", "title": "幽影王座", "position": Vector2(960, 165), "next_ids": []}
]

var node_layer: Control
var line_layer: Node2D
var details_title: Label
var details_type: Label
var details_body: Label
var details_route: Label
var map_nodes: Dictionary = {}
var node_lookup: Dictionary = {}


func _ready() -> void:
	_register_map_graph()
	_build_ui()
	_build_map()
	_show_node_details(MAP_NODES[0])


func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var background_texture: Texture2D = _load_texture_or_null(MAP_BACKGROUND_PATH)
	if background_texture != null:
		var background: TextureRect = TextureRect.new()
		background.texture = background_texture
		background.set_anchors_preset(Control.PRESET_FULL_RECT)
		background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		background.stretch_mode = TextureRect.STRETCH_SCALE
		background.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(background)
	else:
		var fallback_background: ColorRect = ColorRect.new()
		fallback_background.color = Color(0.055, 0.045, 0.035, 1.0)
		fallback_background.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(fallback_background)

	var shade: ColorRect = ColorRect.new()
	shade.color = Color(0, 0, 0, 0.18)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	_build_top_bar()
	_build_legend_panel()
	_build_details_panel()
	_build_return_button()

	line_layer = Node2D.new()
	line_layer.name = "RouteLineLayer"
	line_layer.z_index = 5
	add_child(line_layer)

	node_layer = Control.new()
	node_layer.name = "RouteNodeLayer"
	node_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	node_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node_layer.z_index = 10
	add_child(node_layer)


func _build_top_bar() -> void:
	var bar: ColorRect = ColorRect.new()
	bar.name = "TopStatusBar"
	bar.position = Vector2.ZERO
	bar.size = Vector2(1920, 88)
	bar.color = Color(0.035, 0.032, 0.03, 0.9)
	bar.z_index = 30
	add_child(bar)

	var game_manager: Node = _game_manager()
	_add_label("影刃", Vector2(32, 10), Vector2(160, 32), 26, Color(0.95, 0.82, 0.62, 1), HORIZONTAL_ALIGNMENT_LEFT)
	_add_label("HP %d/%d" % [int(game_manager.get("player_hp")), int(game_manager.get("player_max_hp"))], Vector2(220, 18), Vector2(170, 32), 24, Color(1.0, 0.32, 0.28, 1), HORIZONTAL_ALIGNMENT_LEFT)
	_add_label("金币 %d" % int(game_manager.get("gold")), Vector2(420, 18), Vector2(170, 32), 24, Color(0.95, 0.76, 0.34, 1), HORIZONTAL_ALIGNMENT_LEFT)
	_add_label("章节：1  幽影荒原", Vector2(760, 18), Vector2(320, 32), 24, Color(0.88, 0.78, 0.58, 1), HORIZONTAL_ALIGNMENT_CENTER)
	_add_label("层数：%d/7" % int(game_manager.get("floor")), Vector2(1110, 18), Vector2(180, 32), 24, Color(0.88, 0.78, 0.58, 1), HORIZONTAL_ALIGNMENT_CENTER)

	_add_top_icon("map", Vector2(1480, 8), "地图")
	_add_top_icon("deck", Vector2(1580, 8), "牌组")
	_add_top_icon("relic", Vector2(1680, 8), "遗物")
	_add_top_icon("settings", Vector2(1780, 8), "设置")


func _add_top_icon(icon_key: String, pos: Vector2, text: String) -> void:
	var texture: Texture2D = _load_texture_or_null(str(TAB_ICONS.get(icon_key, "")))
	var icon: TextureRect = TextureRect.new()
	icon.position = pos
	icon.size = Vector2(54, 54)
	icon.z_index = 40
	icon.texture = texture
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(icon)
	_add_label(text, pos + Vector2(-10, 52), Vector2(74, 24), 16, Color(0.86, 0.76, 0.56, 1), HORIZONTAL_ALIGNMENT_CENTER)


func _build_legend_panel() -> void:
	var panel: Panel = _make_panel("LegendPanel", Vector2(28, 132), Vector2(250, 470))
	_add_label("图例", panel.position + Vector2(30, 22), Vector2(178, 34), 26, Color(0.94, 0.82, 0.6, 1), HORIZONTAL_ALIGNMENT_CENTER)
	_add_panel_rule(panel.position + Vector2(28, 66), Vector2(194, 2))

	var entries: Array = [
		["battle_normal", "普通战斗"],
		["battle_elite", "精英战斗"],
		["rest", "休息营地"],
		["shop", "商人"],
		["event", "神秘事件"],
		["treasure", "宝藏"],
		["battle_boss", "首领"]
	]
	for index in range(entries.size()):
		var entry: Array = entries[index]
		var y: float = 82.0 + float(index) * 52.0
		_add_panel_row(panel.position + Vector2(18, y - 6), Vector2(214, 48), index)
		_add_small_icon(str(entry[0]), panel.position + Vector2(30, y))
		_add_label(str(entry[1]), panel.position + Vector2(84, y + 7), Vector2(130, 28), 20, Color(0.86, 0.8, 0.68, 1), HORIZONTAL_ALIGNMENT_LEFT)


func _build_details_panel() -> void:
	var panel: Panel = _make_panel("DetailPanel", Vector2(1452, 286), Vector2(388, 470))
	details_title = _add_label("", panel.position + Vector2(34, 34), Vector2(318, 50), 31, Color(0.96, 0.78, 0.44, 1), HORIZONTAL_ALIGNMENT_LEFT)
	details_type = _add_label("", panel.position + Vector2(34, 92), Vector2(318, 34), 22, Color(0.82, 0.9, 0.62, 1), HORIZONTAL_ALIGNMENT_LEFT)
	_add_panel_rule(panel.position + Vector2(34, 136), Vector2(318, 2))
	details_body = _add_label("", panel.position + Vector2(34, 158), Vector2(318, 146), 21, Color(0.86, 0.81, 0.7, 1), HORIZONTAL_ALIGNMENT_LEFT)
	details_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_add_panel_rule(panel.position + Vector2(34, 326), Vector2(318, 2))
	details_route = _add_label("", panel.position + Vector2(34, 348), Vector2(318, 74), 22, Color(0.65, 0.95, 0.42, 1), HORIZONTAL_ALIGNMENT_LEFT)
	details_route.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _build_return_button() -> void:
	var ornament: TextureRect = TextureRect.new()
	ornament.name = "ReturnButtonOrnament"
	ornament.position = Vector2(1610, 965)
	ornament.size = Vector2(260, 82)
	ornament.z_index = 40
	ornament.texture = _load_texture_or_null(RETURN_ORNAMENT_PATH)
	ornament.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ornament.stretch_mode = TextureRect.STRETCH_SCALE
	ornament.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ornament)

	var button: Button = Button.new()
	button.name = "ReturnButton"
	button.text = "返回"
	button.position = ornament.position + Vector2(30, 18)
	button.size = Vector2(200, 44)
	button.z_index = 41
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 28)
	button.pressed.connect(Callable(self, "_on_return_pressed"))
	add_child(button)


func _make_panel(panel_name: String, panel_position: Vector2, panel_size: Vector2) -> Panel:
	var panel: Panel = Panel.new()
	panel.name = panel_name
	panel.position = panel_position
	panel.size = panel_size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.z_index = 30

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.11, 0.075, 0.64)
	style.border_color = Color(0.72, 0.54, 0.28, 0.86)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.shadow_color = Color(0, 0, 0, 0.42)
	style.shadow_size = 12
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 18
	style.content_margin_bottom = 18
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	return panel


func _add_panel_rule(rule_position: Vector2, rule_size: Vector2) -> void:
	var rule: ColorRect = ColorRect.new()
	rule.position = rule_position
	rule.size = rule_size
	rule.color = Color(0.9, 0.66, 0.32, 0.55)
	rule.z_index = 39
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rule)


func _add_panel_row(row_position: Vector2, row_size: Vector2, row_index: int) -> void:
	var row: ColorRect = ColorRect.new()
	row.position = row_position
	row.size = row_size
	if row_index % 2 == 0:
		row.color = Color(0.58, 0.4, 0.18, 0.12)
	else:
		row.color = Color(0.42, 0.28, 0.13, 0.08)
	row.z_index = 32
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)


func _build_map() -> void:
	map_nodes.clear()
	node_lookup.clear()
	for node_data in MAP_NODES:
		node_lookup[str(node_data["id"])] = node_data

	_create_lines()
	_create_nodes()


func _create_lines() -> void:
	for node_data in MAP_NODES:
		var from_id: String = str(node_data["id"])
		for next_id in node_data.get("next_ids", []):
			if not node_lookup.has(str(next_id)):
				continue
			var line: Line2D = Line2D.new()
			line.width = _get_route_line_width(from_id, str(next_id))
			line.default_color = _get_route_line_color(from_id, str(next_id))
			line.points = PackedVector2Array([
				node_data["position"],
				node_lookup[str(next_id)]["position"]
			])
			line_layer.add_child(line)


func _create_nodes() -> void:
	for node_data in MAP_NODES:
		var map_node: Control = MAP_NODE_SCENE.instantiate() as Control
		map_node.position = node_data["position"] - Vector2(48, 48)
		node_layer.add_child(map_node)
		map_nodes[str(node_data["id"])] = map_node
		map_node.call("setup", node_data)
		map_node.call("set_state", _get_node_state(str(node_data["id"])))
		map_node.connect("node_clicked", Callable(self, "_on_node_clicked"))
		if map_node.has_signal("node_hovered"):
			map_node.connect("node_hovered", Callable(self, "_show_node_details"))


func _get_route_line_color(from_id: String, to_id: String) -> Color:
	var game_manager: Node = _game_manager()
	var completed: Array = game_manager.get("completed_node_ids")
	var available: Array = game_manager.get("available_node_ids")
	if completed.has(from_id) and completed.has(to_id):
		return Color(1.0, 0.72, 0.28, 0.95)
	if completed.has(from_id) and available.has(to_id):
		return Color(0.88, 0.72, 0.42, 0.82)
	return Color(0.55, 0.53, 0.46, 0.5)


func _get_route_line_width(from_id: String, to_id: String) -> float:
	var completed: Array = _game_manager().get("completed_node_ids")
	if completed.has(from_id) and completed.has(to_id):
		return 7.0
	return 4.0


func _get_node_state(node_id: String) -> String:
	var game_manager: Node = _game_manager()
	var completed_node_ids: Array = game_manager.get("completed_node_ids")
	var available_node_ids: Array = game_manager.get("available_node_ids")
	if completed_node_ids.has(node_id):
		return "completed"
	if available_node_ids.has(node_id):
		return "available"
	return "locked"


func _show_node_details(node_data: Dictionary) -> void:
	var node_type: String = str(node_data.get("type", "battle_normal"))
	var node_state: String = _get_node_state(str(node_data.get("id", "")))
	details_title.text = str(node_data.get("title", "未知地点"))
	details_type.text = str(TYPE_LABELS.get(node_type, node_type))
	details_body.text = str(TYPE_DETAILS.get(node_type, "前方状况不明。"))
	if node_state == "available":
		details_route.text = "建议路线：安全\n点击节点移动"
	elif node_state == "completed":
		details_route.text = "已完成\n路线已经记录"
	else:
		details_route.text = "尚未解锁\n先完成相连节点"


func _on_node_clicked(node_data: Dictionary) -> void:
	var node_id: String = str(node_data.get("id", ""))
	var node_type: String = str(node_data.get("type", ""))
	_game_manager().set("current_node_id", node_id)

	match node_type:
		"battle_normal":
			get_tree().change_scene_to_file(BATTLE_SCENE_PATH)
		"battle_elite":
			print("精英战斗")
			get_tree().change_scene_to_file(BATTLE_SCENE_PATH)
		"battle_boss":
			print("Boss战")
			get_tree().change_scene_to_file(BATTLE_SCENE_PATH)
		"shop":
			get_tree().change_scene_to_file(SHOP_SCENE_PATH)
		"rest":
			get_tree().change_scene_to_file(REST_SCENE_PATH)
		"event":
			get_tree().change_scene_to_file(EVENT_SCENE_PATH)
		"treasure":
			get_tree().change_scene_to_file(TREASURE_SCENE_PATH)
		_:
			print("未知节点：%s" % node_type)


func _register_map_graph() -> void:
	var connections: Dictionary = {}
	for node_data in MAP_NODES:
		var next_ids: Array = node_data.get("next_ids", [])
		connections[str(node_data["id"])] = next_ids.duplicate()
	_game_manager().call("register_map_connections", connections)


func _on_return_pressed() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)


func _add_small_icon(node_type: String, icon_position: Vector2) -> void:
	var icon: TextureRect = TextureRect.new()
	icon.position = icon_position
	icon.size = Vector2(38, 38)
	icon.z_index = 40
	icon.texture = _load_texture_or_null(_get_icon_path(node_type))
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(icon)


func _get_icon_path(node_type: String) -> String:
	match node_type:
		"battle_normal":
			return "res://art/map/icon_battle_normal.png"
		"battle_elite":
			return "res://art/map/icon_battle_elite.png"
		"battle_boss":
			return "res://art/map/icon_battle_boss.png"
		"shop":
			return "res://art/map/icon_shop.png"
		"rest":
			return "res://art/map/icon_rest.png"
		"event":
			return "res://art/map/icon_event.png"
		"treasure":
			return "res://art/map/icon_treasure.png"
	return ""


func _add_label(
	text: String,
	label_position: Vector2,
	label_size: Vector2,
	font_size: int,
	font_color: Color,
	alignment: int
) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.position = label_position
	label.size = label_size
	label.horizontal_alignment = alignment
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.z_index = 40
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", font_color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label


func _load_texture_or_null(texture_path: String) -> Texture2D:
	if texture_path.is_empty():
		return null

	if ResourceLoader.exists(texture_path):
		var loaded_resource: Resource = ResourceLoader.load(texture_path)
		if loaded_resource is Texture2D:
			return loaded_resource as Texture2D

	if FileAccess.file_exists(texture_path):
		var image: Image = Image.new()
		if image.load(texture_path) == OK:
			return ImageTexture.create_from_image(image)

	return null


func _game_manager() -> Node:
	return get_node("/root/GameManager")
