extends Control

const MAP_SCENE_PATH: String = "res://scenes/map/MapScene.tscn"
const CARD_VIEW_SCENE: PackedScene = preload("res://scenes/ui/CardView.tscn")

const RARITY_WEIGHTS := {
	"battle_normal": {"Common": 65, "Uncommon": 30, "Rare": 5},
	"battle_elite": {"Common": 35, "Uncommon": 45, "Rare": 20},
	"battle_boss": {"Common": 0, "Uncommon": 30, "Rare": 70}
}

const CARD_REWARD_POOL := {
	"body_slam": {
		"name": "全身撞击",
		"cost": 1,
		"type": "Attack",
		"rarity": "Common",
		"description": "造成等同于当前格挡的伤害。",
		"art_path": "res://art/cards/body_slam_art.png",
		"tags": ["block_damage"],
		"boss_core": true
	},
	"spot_weakness": {
		"name": "观察弱点",
		"cost": 1,
		"type": "Skill",
		"rarity": "Uncommon",
		"description": "如果目标意图为攻击，获得 3 点力量。",
		"art_path": "res://art/cards/spot_weakness_art.png",
		"tags": ["strength"],
		"boss_core": false
	},
	"feel_no_pain": {
		"name": "无惧疼痛",
		"cost": 1,
		"type": "Power",
		"rarity": "Uncommon",
		"description": "每当有一张牌被消耗时，获得 3 点格挡。",
		"art_path": "res://art/cards/feel_no_pain_art.png",
		"tags": ["block_damage", "power", "exhaust"],
		"boss_core": true
	},
	"rage": {
		"name": "盛怒",
		"cost": 0,
		"type": "Skill",
		"rarity": "Uncommon",
		"description": "本回合每当你打出一张攻击牌，获得 3 点格挡。",
		"art_path": "res://art/cards/rage_art.png",
		"tags": ["block_damage"],
		"boss_core": false
	},
	"demon_form": {
		"name": "恶魔形态",
		"cost": 3,
		"type": "Power",
		"rarity": "Rare",
		"description": "在你的回合开始时，获得 2 点力量。",
		"art_path": "res://art/cards/demon_form_art.png",
		"tags": ["strength", "power"],
		"boss_core": true
	},
	"limit_break": {
		"name": "突破极限",
		"cost": 1,
		"type": "Skill",
		"rarity": "Rare",
		"description": "使你的力量翻倍。消耗。",
		"art_path": "res://art/cards/limit_break_art.png",
		"tags": ["strength", "exhaust"],
		"boss_core": true
	},
	"double_tap": {
		"name": "双发",
		"cost": 1,
		"type": "Skill",
		"rarity": "Rare",
		"description": "本回合你的下一张攻击牌打出两次。",
		"art_path": "res://art/cards/double_tap_art.png",
		"tags": ["strength"],
		"boss_core": true
	},
	"barricade": {
		"name": "壁垒",
		"cost": 3,
		"type": "Power",
		"rarity": "Rare",
		"description": "你的格挡在回合开始时不再消失。",
		"art_path": "res://art/cards/barricade_art.png",
		"tags": ["block_damage", "power"],
		"boss_core": true
	}
}

var reward_cards: Array = []
var title_label: Label
var subtitle_label: Label
var card_area: Control
var skip_button: Button
var reward_finished: bool = false


func _ready() -> void:
	randomize()
	_build_ui()
	_generate_rewards()
	_show_rewards()


func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var background: ColorRect = ColorRect.new()
	background.color = Color(0.045, 0.036, 0.03, 1.0)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var shade: ColorRect = ColorRect.new()
	shade.color = Color(0.0, 0.0, 0.0, 0.18)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	title_label = _make_label(Vector2(560, 96), Vector2(800, 64), 46, Color(0.96, 0.78, 0.42, 1.0), HORIZONTAL_ALIGNMENT_CENTER)
	subtitle_label = _make_label(Vector2(520, 162), Vector2(880, 42), 23, Color(0.82, 0.74, 0.62, 1.0), HORIZONTAL_ALIGNMENT_CENTER)

	card_area = Control.new()
	card_area.name = "CardRewardArea"
	card_area.position = Vector2(0, 0)
	card_area.size = Vector2(1920, 1080)
	card_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(card_area)

	skip_button = Button.new()
	skip_button.text = "跳过奖励"
	skip_button.position = Vector2(810, 872)
	skip_button.size = Vector2(300, 62)
	skip_button.focus_mode = Control.FOCUS_NONE
	skip_button.add_theme_font_size_override("font_size", 25)
	skip_button.add_theme_font_override("font", _make_game_font(true))
	skip_button.add_theme_stylebox_override("normal", _button_style(false))
	skip_button.add_theme_stylebox_override("hover", _button_style(true))
	skip_button.add_theme_stylebox_override("pressed", _button_style(true))
	skip_button.add_theme_color_override("font_color", Color(0.96, 0.84, 0.62, 1.0))
	skip_button.pressed.connect(_on_skip_pressed)
	add_child(skip_button)


func _generate_rewards() -> void:
	var battle_type: String = _get_battle_type()
	reward_cards = _draw_reward_cards(battle_type, 3)
	title_label.text = _get_title_for_battle_type(battle_type)
	subtitle_label.text = "选择 1 张卡牌加入牌组，或跳过。"


func _show_rewards() -> void:
	for child in card_area.get_children():
		child.queue_free()

	var start_x: float = 500.0
	for index in range(reward_cards.size()):
		var card_view: Control = CARD_VIEW_SCENE.instantiate() as Control
		card_view.position = Vector2(start_x + float(index) * 340.0, 316.0)
		card_view.scale = Vector2(1.08, 1.08)
		card_view.z_index = index
		card_area.add_child(card_view)
		card_view.call("setup", reward_cards[index])
		if card_view.has_signal("card_clicked"):
			card_view.connect("card_clicked", Callable(self, "_on_card_clicked"))


func _draw_reward_cards(battle_type: String, count: int) -> Array:
	var selected: Array = []
	var forced_rarities: Array = _get_forced_rarities(battle_type)
	for rarity in forced_rarities:
		var card: Dictionary = _pick_weighted_card(battle_type, selected, str(rarity))
		if not card.is_empty():
			selected.append(card)

	while selected.size() < count:
		var rarity: String = _roll_rarity(battle_type)
		var picked: Dictionary = _pick_weighted_card(battle_type, selected, rarity)
		if picked.is_empty():
			picked = _pick_weighted_card(battle_type, selected, "")
		if picked.is_empty():
			break
		selected.append(picked)

	_update_reward_pity(selected, battle_type)
	return selected


func _get_forced_rarities(battle_type: String) -> Array:
	if battle_type == "battle_boss":
		return ["Rare", "Rare"]
	if battle_type == "battle_elite":
		return ["Uncommon"]
	if battle_type == "battle_normal" and int(_game_manager().get("card_reward_pity_counter")) >= 3:
		return ["Uncommon"]
	return []


func _roll_rarity(battle_type: String) -> String:
	var weights: Dictionary = RARITY_WEIGHTS.get(battle_type, RARITY_WEIGHTS["battle_normal"])
	var total: int = 0
	for rarity in weights.keys():
		total += int(weights[rarity])
	var roll: int = randi_range(1, maxi(total, 1))
	var cursor: int = 0
	for rarity in weights.keys():
		cursor += int(weights[rarity])
		if roll <= cursor:
			return str(rarity)
	return "Common"


func _pick_weighted_card(battle_type: String, already_selected: Array, forced_rarity: String) -> Dictionary:
	var weighted_cards: Array = []
	var selected_ids: Array = []
	for card in already_selected:
		selected_ids.append(str(card.get("id", "")))

	for card_id in CARD_REWARD_POOL.keys():
		if selected_ids.has(str(card_id)):
			continue
		var definition: Dictionary = CARD_REWARD_POOL[card_id]
		if not forced_rarity.is_empty() and str(definition.get("rarity", "")) != forced_rarity:
			continue
		if battle_type == "battle_boss" and str(definition.get("rarity", "")) == "Common" and not bool(definition.get("boss_core", false)):
			continue

		var weight: int = _get_card_weight(str(card_id), definition, battle_type)
		if weight > 0:
			weighted_cards.append({"id": card_id, "weight": weight})

	if weighted_cards.is_empty():
		return {}

	var total: int = 0
	for entry in weighted_cards:
		total += int(entry["weight"])
	var roll: int = randi_range(1, maxi(total, 1))
	var cursor: int = 0
	for entry in weighted_cards:
		cursor += int(entry["weight"])
		if roll <= cursor:
			return _make_reward_card(str(entry["id"]))
	return _make_reward_card(str(weighted_cards[0]["id"]))


func _get_card_weight(card_id: String, definition: Dictionary, battle_type: String) -> int:
	var weights: Dictionary = RARITY_WEIGHTS.get(battle_type, RARITY_WEIGHTS["battle_normal"])
	var rarity: String = str(definition.get("rarity", "Common"))
	var weight: int = maxi(int(weights.get(rarity, 1)), 1)
	if battle_type == "battle_boss" and bool(definition.get("boss_core", false)):
		weight += 35

	var deck_tag_counts: Dictionary = _get_deck_tag_counts()
	for tag in definition.get("tags", []):
		if int(deck_tag_counts.get(str(tag), 0)) > 0:
			weight += 20 if battle_type == "battle_normal" else 30

	var owned_count: int = _get_owned_card_count(card_id)
	if owned_count >= 2:
		weight = maxi(floori(float(weight) * 0.5), 1)
	if card_id in ["demon_form", "barricade"] and owned_count >= 1:
		weight = maxi(floori(float(weight) * 0.35), 1)
	return weight


func _get_deck_tag_counts() -> Dictionary:
	var counts: Dictionary = {}
	for card in _game_manager().get("deck_cards"):
		if not (card is Dictionary):
			continue
		var card_id: String = str(card.get("id", ""))
		if not CARD_REWARD_POOL.has(card_id):
			continue
		for tag in CARD_REWARD_POOL[card_id].get("tags", []):
			counts[str(tag)] = int(counts.get(str(tag), 0)) + 1
	return counts


func _get_owned_card_count(card_id: String) -> int:
	var count: int = 0
	for card in _game_manager().get("deck_cards"):
		if card is Dictionary and str(card.get("id", "")) == card_id:
			count += 1
	return count


func _update_reward_pity(selected: Array, battle_type: String) -> void:
	if battle_type != "battle_normal":
		return
	var has_uncommon_or_rare: bool = false
	for card in selected:
		if str(card.get("rarity", "Common")) != "Common":
			has_uncommon_or_rare = true
			break
	_game_manager().set("card_reward_pity_counter", 0 if has_uncommon_or_rare else int(_game_manager().get("card_reward_pity_counter")) + 1)


func _make_reward_card(card_id: String) -> Dictionary:
	if not CARD_REWARD_POOL.has(card_id):
		return {}
	var definition: Dictionary = CARD_REWARD_POOL[card_id]
	return {
		"id": card_id,
		"name": definition["name"],
		"cost": definition["cost"],
		"type": definition["type"],
		"rarity": definition["rarity"],
		"description": definition["description"],
		"art_path": definition["art_path"],
		"frame_path": ""
	}


func _on_card_clicked(card_data: Dictionary, _card_view: Control) -> void:
	if reward_finished:
		return
	reward_finished = true
	_game_manager().call("add_card", card_data)
	_finish_reward()


func _on_skip_pressed() -> void:
	if reward_finished:
		return
	reward_finished = true
	_finish_reward()


func _finish_reward() -> void:
	var game_manager: Node = _game_manager()
	game_manager.call("complete_map_node", str(game_manager.get("current_node_id")))
	get_tree().change_scene_to_file(MAP_SCENE_PATH)


func _get_battle_type() -> String:
	var node_type: String = str(_game_manager().get("current_node_type"))
	if node_type in ["battle_normal", "battle_elite", "battle_boss"]:
		return node_type
	return "battle_normal"


func _get_title_for_battle_type(battle_type: String) -> String:
	match battle_type:
		"battle_elite":
			return "精英奖励"
		"battle_boss":
			return "Boss 奖励"
	return "战斗奖励"


func _make_label(pos: Vector2, label_size: Vector2, font_size: int, font_color: Color, alignment: int) -> Label:
	var label: Label = Label.new()
	label.position = pos
	label.size = label_size
	label.horizontal_alignment = alignment
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_font_override("font", _make_game_font(font_size >= 28))
	label.add_theme_color_override("font_color", font_color)
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label


func _button_style(hover: bool) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.34, 0.14, 0.075, 0.94)
	style.border_color = Color(1.0, 0.68, 0.28, 1.0) if hover else Color(0.72, 0.44, 0.18, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	return style


func _make_game_font(display_font: bool) -> SystemFont:
	var font: SystemFont = SystemFont.new()
	if display_font:
		font.font_names = PackedStringArray(["LiSu", "FZYaoTi", "STXingkai", "STLiti", "KaiTi", "Microsoft YaHei UI", "Microsoft YaHei"])
	else:
		font.font_names = PackedStringArray(["LiSu", "KaiTi", "STKaiti", "Microsoft YaHei UI", "Microsoft YaHei"])
	return font


func _game_manager() -> Node:
	return get_node("/root/GameManager")
