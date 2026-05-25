extends Node2D

# BattleScene 是 v1 战斗流程入口：管理回合、抽牌、能量、伤害、格挡和胜负。
# 角色节点、手牌区和顶部 Dock 仍保持各自展示职责。

enum BattleState {
	PLAYER_TURN,
	RESOLVING_CARD,
	ENEMY_TURN,
	VICTORY,
	DEFEAT
}

# 目标构图尺寸，和 project.godot 的 1920x1080 保持一致。
const VIEWPORT_SIZE: Vector2 = Vector2(1920, 1080)
const HAND_AREA_HEIGHT: float = 270.0
const HAND_DRAW_COUNT: int = 5

const PLAYER_START_HP: int = 70
const PLAYER_MAX_ENERGY: int = 3
const ENEMY_START_HP: int = 32
const ENEMY_INTENT_DAMAGE: int = 6
const ENEMY_TARGET_ID: String = "enemy_0"

const BACKGROUND_TEXTURE_PATH: String = "res://art/backgrounds/battle/battle_bg_dungeon.png"
const TORCH_TEXTURE_PATH: String = "res://art/backgrounds/battle/props/torch_wall.png"
const PILLAR_TEXTURE_PATH: String = "res://art/backgrounds/battle/props/broken_pillar.png"
const DEBRIS_TEXTURE_PATH: String = "res://art/backgrounds/battle/props/ground_debris.png"
const ENERGY_ORB_TEXTURE_PATH: String = "res://art/ui/energy_orb.png"
const HAND_AREA_SCENE_PATH: String = "res://scenes/ui/HandArea.tscn"
const ACTOR_VIEW_SCENE_PATH: String = "res://scenes/battle/BattleActorView.tscn"
const MAP_SCENE_PATH: String = "res://scenes/map/MapScene.tscn"
const MAIN_MENU_SCENE_PATH: String = "res://scenes/menu/MainMenu.tscn"
const CARD_REWARD_SCENE_PATH: String = "res://scenes/reward/CardRewardScene.tscn"
const PLAYER_SHEET_PATH: String = "res://art/characters/player/hero_combat_sheet.png"
const SLIME_SHEET_PATH: String = "res://art/enemies/slime/slime_combat_sheet.png"
const RAVEN_EXECUTIONER_SHEET_PATH: String = "res://art/enemies/raven_executioner/raven_executioner_combat_sheet.png"
const CRACKED_CORE_SLIME_SHEET_PATH: String = "res://art/enemies/cracked_core_slime/cracked_core_slime_combat_sheet.png"
const FORGED_SOUL_TYRANT_SHEET_PATH: String = "res://art/enemies/forged_soul_tyrant/forged_soul_tyrant_combat_sheet.png"

const STATUS_DEFINITIONS := {
	"strength": {"name": "力量", "short_name": "力", "ticks_down": false},
	"dexterity": {"name": "敏捷", "short_name": "敏", "ticks_down": false},
	"vulnerable": {"name": "易伤", "short_name": "易", "ticks_down": true},
	"weak": {"name": "虚弱", "short_name": "弱", "ticks_down": true},
	"frail": {"name": "脆弱", "short_name": "脆", "ticks_down": true},
	"execution_mark": {"name": "处刑印记", "short_name": "印记", "ticks_down": false}
}

@onready var background_sprite: Sprite2D = $BackgroundLayer/Background
@onready var left_torch: Sprite2D = $BackgroundLayer/DecorationLayer/LeftTorch
@onready var right_torch: Sprite2D = $BackgroundLayer/DecorationLayer/RightTorch
@onready var broken_pillar: Sprite2D = $BackgroundLayer/DecorationLayer/BrokenPillar
@onready var debris_left: Sprite2D = $BackgroundLayer/DecorationLayer/DebrisLeft
@onready var debris_center: Sprite2D = $BackgroundLayer/DecorationLayer/DebrisCenter
@onready var debris_right: Sprite2D = $BackgroundLayer/DecorationLayer/DebrisRight

@onready var player_slot: Marker2D = $SlotLayer/PlayerSlot
@onready var enemy_slot: Marker2D = $SlotLayer/EnemySlot
@onready var hand_ui_layer: CanvasLayer = $HandUiLayer
@onready var hand_area_slot: Control = $HandUiLayer/HandAreaSlot
@onready var battle_top_dock: Control = $HandUiLayer/BattleTopDock
@onready var top_dock_backdrop: ColorRect = $HandUiLayer/TopDockBackdrop
@onready var top_dock_bottom_line: ColorRect = $HandUiLayer/TopDockBottomLine
@onready var energy_orb: TextureRect = $HandUiLayer/EnergyPanel/EnergyOrb
@onready var energy_label: Label = $HandUiLayer/EnergyPanel/EnergyLabel

var current_energy: int = PLAYER_MAX_ENERGY
var max_energy: int = PLAYER_MAX_ENERGY
var battle_state: int = BattleState.PLAYER_TURN

var player_state: Dictionary = {}
var enemy_state: Dictionary = {}
var current_enemy_definition: Dictionary = {}
var draw_pile: Array = []
var hand_cards: Array = []
var discard_pile: Array = []
var played_pile: Array = []
var exhaust_pile: Array = []
var next_card_instance_id: int = 1

var player_view: Node2D
var enemy_view: Node2D
var hand_area: Control

var turn_status_label: Label
var enemy_intent_label: Label
var enemy_intent_icon: TextureRect
var enemy_intent_value_label: Label
var end_turn_frame: TextureRect
var end_turn_button: Button
var result_overlay: ColorRect
var result_label: Label
var result_continue_button: Button
var result_menu_button: Button


func _ready() -> void:
	if not get_viewport().size_changed.is_connected(Callable(self, "_setup_top_dock_backdrop")):
		get_viewport().size_changed.connect(Callable(self, "_setup_top_dock_backdrop"))
	if not get_viewport().size_changed.is_connected(Callable(self, "_refresh_drop_targets")):
		get_viewport().size_changed.connect(Callable(self, "_refresh_drop_targets"))

	_setup_background()
	_setup_decorations()
	_setup_actor_views()
	_setup_top_dock_backdrop()
	_setup_top_dock()
	_setup_energy_ui()
	_setup_hand_area()
	_setup_battle_flow_ui()
	_start_battle()


func _setup_background() -> void:
	var background_texture: Texture2D = _load_texture_or_null(BACKGROUND_TEXTURE_PATH)
	if background_texture == null:
		background_sprite.visible = false
		return

	background_sprite.visible = true
	background_sprite.texture = background_texture
	background_sprite.position = VIEWPORT_SIZE * 0.5

	var texture_size: Vector2 = background_texture.get_size()
	if texture_size.x > 0.0 and texture_size.y > 0.0:
		background_sprite.scale = Vector2(VIEWPORT_SIZE.x / texture_size.x, VIEWPORT_SIZE.y / texture_size.y)


func _setup_decorations() -> void:
	_assign_texture_or_hide(left_torch, TORCH_TEXTURE_PATH)
	_assign_texture_or_hide(right_torch, TORCH_TEXTURE_PATH)
	right_torch.flip_h = true
	_assign_texture_or_hide(broken_pillar, PILLAR_TEXTURE_PATH)
	_assign_texture_or_hide(debris_left, DEBRIS_TEXTURE_PATH)
	_assign_texture_or_hide(debris_center, DEBRIS_TEXTURE_PATH)
	_assign_texture_or_hide(debris_right, DEBRIS_TEXTURE_PATH)


func _setup_hand_area() -> void:
	hand_area_slot.position = Vector2(0.0, VIEWPORT_SIZE.y - HAND_AREA_HEIGHT)
	hand_area_slot.size = Vector2(VIEWPORT_SIZE.x, HAND_AREA_HEIGHT)

	if not ResourceLoader.exists(HAND_AREA_SCENE_PATH):
		return

	var hand_area_resource: Resource = ResourceLoader.load(HAND_AREA_SCENE_PATH)
	if not (hand_area_resource is PackedScene):
		return

	var hand_area_scene: PackedScene = hand_area_resource as PackedScene
	hand_area = hand_area_scene.instantiate() as Control
	if hand_area == null:
		return

	hand_area_slot.add_child(hand_area)
	hand_area.set_anchors_preset(Control.PRESET_FULL_RECT)
	hand_area.offset_left = 0.0
	hand_area.offset_top = 0.0
	hand_area.offset_right = 0.0
	hand_area.offset_bottom = 0.0

	if hand_area.has_method("set_max_card_scale"):
		hand_area.call("set_max_card_scale", 0.72)
	if hand_area.has_method("set_battle_area_release_y"):
		hand_area.call("set_battle_area_release_y", hand_area_slot.global_position.y - 40.0)
	if hand_area.has_signal("card_play_requested"):
		hand_area.connect("card_play_requested", Callable(self, "_on_card_play_requested"))

	_refresh_drop_targets()


func _setup_actor_views() -> void:
	if not ResourceLoader.exists(ACTOR_VIEW_SCENE_PATH):
		return

	var actor_view_resource: Resource = ResourceLoader.load(ACTOR_VIEW_SCENE_PATH)
	if not (actor_view_resource is PackedScene):
		return

	var actor_view_scene: PackedScene = actor_view_resource as PackedScene
	player_view = actor_view_scene.instantiate() as Node2D
	enemy_view = actor_view_scene.instantiate() as Node2D
	if player_view == null or enemy_view == null:
		return

	player_slot.add_child(player_view)
	enemy_slot.add_child(enemy_view)
	player_slot.position = Vector2(455, 650)
	enemy_slot.position = Vector2(1450, 625)

	if player_view.has_method("set_visual_scale"):
		player_view.call("set_visual_scale", Vector2(2.48, 2.48))
	if enemy_view.has_method("set_visual_scale"):
		enemy_view.call("set_visual_scale", Vector2(2.42, 2.42))
	if player_view.has_method("set_horizontal_flip"):
		player_view.call("set_horizontal_flip", false)
	if enemy_view.has_method("set_horizontal_flip"):
		enemy_view.call("set_horizontal_flip", false)
	if player_view.has_method("setup"):
		player_view.call("setup", PLAYER_SHEET_PATH)
	if enemy_view.has_method("setup"):
		enemy_view.call("setup", SLIME_SHEET_PATH)


func _setup_energy_ui() -> void:
	var energy_panel: Control = $HandUiLayer/EnergyPanel
	var energy_background: ColorRect = $HandUiLayer/EnergyPanel/PanelBackground
	if energy_panel != null:
		energy_panel.position = Vector2(118.0, 845.0)
		energy_panel.size = Vector2(156.0, 104.0)
		energy_panel.z_index = 20
	if energy_background != null:
		energy_background.position = Vector2(26.0, 20.0)
		energy_background.size = Vector2(116.0, 62.0)
		energy_background.color = Color(0.035, 0.03, 0.038, 0.58)

	var orb_texture: Texture2D = _load_texture_or_null(ENERGY_ORB_TEXTURE_PATH)
	if orb_texture != null:
		energy_orb.texture = orb_texture
		energy_orb.visible = true
	else:
		energy_orb.texture = null
		energy_orb.visible = false

	set_energy(current_energy, max_energy)


func _setup_top_dock() -> void:
	if battle_top_dock == null:
		return

	var game_manager: Node = _game_manager()
	if battle_top_dock.has_method("set_player_info"):
		battle_top_dock.call("set_player_info", "铁甲战士", int(game_manager.get("player_hp")), int(game_manager.get("player_max_hp")))
	if battle_top_dock.has_method("set_gold"):
		battle_top_dock.call("set_gold", int(game_manager.get("gold")))
	if battle_top_dock.has_method("set_floor"):
		battle_top_dock.call("set_floor", int(game_manager.get("floor")))
	if battle_top_dock.has_method("set_deck_count"):
		battle_top_dock.call("set_deck_count", 0)
	if battle_top_dock.has_method("set_potions"):
		battle_top_dock.call("set_potions", [
			{"id": "fire_potion", "name": "火焰药水", "icon_path": ""},
			null,
			null
		])


func _setup_top_dock_backdrop() -> void:
	var viewport_width: float = maxf(get_viewport_rect().size.x, VIEWPORT_SIZE.x)

	if top_dock_backdrop != null:
		top_dock_backdrop.position = Vector2.ZERO
		top_dock_backdrop.size = Vector2(viewport_width, 72.0)
		top_dock_backdrop.z_index = 0
		top_dock_backdrop.color = Color(0.08, 0.075, 0.085, 0.32)
		top_dock_backdrop.visible = true

	if top_dock_bottom_line != null:
		top_dock_bottom_line.position = Vector2(0.0, 71.0)
		top_dock_bottom_line.size = Vector2(viewport_width, 2.0)
		top_dock_bottom_line.z_index = 2
		top_dock_bottom_line.color = Color(0.72, 0.52, 0.24, 0.28)
		top_dock_bottom_line.visible = true


func _setup_battle_flow_ui() -> void:
	turn_status_label = _make_label("TurnStatusLabel", Vector2(760, 82), Vector2(400, 36), 24, Color(1.0, 0.92, 0.74, 0.92))
	_setup_enemy_intent_ui()

	end_turn_frame = TextureRect.new()
	end_turn_frame.name = "EndTurnFrame"
	end_turn_frame.position = Vector2(0, 0)
	end_turn_frame.size = Vector2.ZERO
	end_turn_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	end_turn_frame.stretch_mode = TextureRect.STRETCH_SCALE
	end_turn_frame.texture = null
	end_turn_frame.visible = false
	end_turn_frame.z_index = 29
	hand_ui_layer.add_child(end_turn_frame)

	end_turn_button = Button.new()
	end_turn_button.name = "EndTurnButton"
	end_turn_button.position = Vector2(1690, 780)
	end_turn_button.size = Vector2(150, 46)
	end_turn_button.text = "结束回合"
	end_turn_button.z_index = 30
	end_turn_button.focus_mode = Control.FOCUS_NONE
	end_turn_button.add_theme_font_size_override("font_size", 20)
	end_turn_button.add_theme_color_override("font_color", Color(0.96, 0.88, 0.72, 1.0))
	end_turn_button.add_theme_color_override("font_hover_color", Color(1.0, 0.98, 0.82, 1.0))
	end_turn_button.add_theme_color_override("font_pressed_color", Color(0.94, 0.72, 0.44, 1.0))
	end_turn_button.add_theme_color_override("font_disabled_color", Color(0.55, 0.52, 0.48, 0.8))
	_apply_end_turn_button_style()
	end_turn_button.pressed.connect(Callable(self, "_on_end_turn_pressed"))
	end_turn_button.mouse_entered.connect(Callable(self, "_on_end_turn_hover_changed").bind(true))
	end_turn_button.mouse_exited.connect(Callable(self, "_on_end_turn_hover_changed").bind(false))
	hand_ui_layer.add_child(end_turn_button)

	result_overlay = ColorRect.new()
	result_overlay.name = "ResultOverlay"
	result_overlay.position = Vector2.ZERO
	result_overlay.size = VIEWPORT_SIZE
	result_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	result_overlay.color = Color(0.02, 0.018, 0.015, 0.72)
	result_overlay.z_index = 100
	result_overlay.visible = false
	hand_ui_layer.add_child(result_overlay)

	result_label = Label.new()
	result_label.name = "ResultLabel"
	result_label.position = Vector2(610, 430)
	result_label.size = Vector2(700, 140)
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	result_label.add_theme_font_size_override("font_size", 72)
	result_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.55, 1.0))
	result_overlay.add_child(result_label)

	result_continue_button = Button.new()
	result_continue_button.name = "ContinueButton"
	result_continue_button.text = "领取卡牌奖励"
	result_continue_button.position = Vector2(760, 610)
	result_continue_button.size = Vector2(400, 66)
	result_continue_button.add_theme_font_size_override("font_size", 26)
	result_continue_button.pressed.connect(Callable(self, "_on_victory_continue_pressed"))
	result_overlay.add_child(result_continue_button)

	result_menu_button = Button.new()
	result_menu_button.name = "MainMenuButton"
	result_menu_button.text = "返回主菜单"
	result_menu_button.position = Vector2(760, 700)
	result_menu_button.size = Vector2(400, 66)
	result_menu_button.add_theme_font_size_override("font_size", 26)
	result_menu_button.pressed.connect(Callable(self, "_on_defeat_menu_pressed"))
	result_overlay.add_child(result_menu_button)


func _setup_enemy_intent_ui() -> void:
	enemy_intent_label = _make_label("EnemyIntentLabel", Vector2(1374, 324), Vector2(96, 34), 22, Color(1.0, 0.72, 0.58, 1.0))
	enemy_intent_label.text = "攻 6"
	enemy_intent_label.visible = false

	enemy_intent_icon = TextureRect.new()
	enemy_intent_icon.name = "EnemyIntentIcon"
	enemy_intent_icon.position = Vector2.ZERO
	enemy_intent_icon.size = Vector2.ZERO
	enemy_intent_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	enemy_intent_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	enemy_intent_icon.texture = null
	enemy_intent_icon.visible = false
	enemy_intent_icon.z_index = 26
	hand_ui_layer.add_child(enemy_intent_icon)

	enemy_intent_value_label = Label.new()
	enemy_intent_value_label.name = "EnemyIntentValueLabel"
	enemy_intent_value_label.position = Vector2.ZERO
	enemy_intent_value_label.size = Vector2.ZERO
	enemy_intent_value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	enemy_intent_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	enemy_intent_value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	enemy_intent_value_label.add_theme_font_size_override("font_size", 28)
	enemy_intent_value_label.add_theme_color_override("font_color", Color(1.0, 0.76, 0.62, 1.0))
	enemy_intent_value_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	enemy_intent_value_label.add_theme_constant_override("shadow_offset_x", 2)
	enemy_intent_value_label.add_theme_constant_override("shadow_offset_y", 2)
	enemy_intent_value_label.z_index = 27
	enemy_intent_value_label.visible = false
	hand_ui_layer.add_child(enemy_intent_value_label)


func _make_label(label_name: String, label_position: Vector2, label_size: Vector2, font_size: int, font_color: Color) -> Label:
	var label: Label = Label.new()
	label.name = label_name
	label.position = label_position
	label.size = label_size
	label.z_index = 25
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", font_color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	hand_ui_layer.add_child(label)
	return label


func _apply_end_turn_button_style() -> void:
	if end_turn_button == null:
		return

	end_turn_button.add_theme_stylebox_override("normal", _make_button_style(Color(0.06, 0.052, 0.045, 0.62), Color(0.72, 0.52, 0.27, 0.55)))
	end_turn_button.add_theme_stylebox_override("hover", _make_button_style(Color(0.12, 0.09, 0.065, 0.76), Color(0.92, 0.68, 0.32, 0.78)))
	end_turn_button.add_theme_stylebox_override("pressed", _make_button_style(Color(0.04, 0.035, 0.032, 0.82), Color(0.86, 0.56, 0.24, 0.78)))
	end_turn_button.add_theme_stylebox_override("disabled", _make_button_style(Color(0.05, 0.05, 0.055, 0.38), Color(0.30, 0.29, 0.27, 0.45)))


func _make_button_style(bg_color: Color, border_color: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style


func _on_end_turn_hover_changed(is_hovered: bool) -> void:
	if end_turn_frame == null:
		return

	end_turn_frame.modulate = Color(1.08, 1.04, 0.92, 1.0) if is_hovered and not end_turn_button.disabled else Color(1, 1, 1, 1)


func _select_enemy_definition() -> Dictionary:
	var game_manager: Node = _game_manager()
	var node_type: String = str(game_manager.get("current_node_type"))
	var node_id: String = str(game_manager.get("current_node_id"))

	if node_type == "battle_boss":
		return _make_forged_soul_tyrant_definition()
	if node_type == "battle_elite":
		if node_id == "5-3":
			return _make_raven_executioner_definition()
		return _make_cracked_core_slime_definition()
	return _make_normal_slime_definition()


func _build_enemy_state(enemy_definition: Dictionary) -> Dictionary:
	var action_pattern: Array = enemy_definition.get("action_pattern", [])
	var state: Dictionary = {
		"id": str(enemy_definition.get("id", "normal_slime")),
		"name": str(enemy_definition.get("name", "史莱姆")),
		"hp": int(enemy_definition.get("hp", ENEMY_START_HP)),
		"max_hp": int(enemy_definition.get("hp", ENEMY_START_HP)),
		"block": 0,
		"strength": int(enemy_definition.get("strength", 0)),
		"turn_index": 0,
		"phase": 1,
		"phase_changed": false,
		"action_pattern": action_pattern,
		"phase_two_pattern": enemy_definition.get("phase_two_pattern", []),
		"phase_two_threshold": int(enemy_definition.get("phase_two_threshold", 0)),
		"status_effects": {},
		"intent_damage": ENEMY_INTENT_DAMAGE,
		"current_action": {}
	}
	state["current_action"] = _get_enemy_action_for_state(state)
	var first_action: Dictionary = state["current_action"]
	state["intent_damage"] = maxi(int(first_action.get("damage", 0)), 0) * maxi(int(first_action.get("hits", 1)), 1)
	return state


func _make_normal_slime_definition() -> Dictionary:
	return {
		"id": "normal_slime",
		"name": "沼泽史莱姆",
		"hp": 32,
		"sheet_path": SLIME_SHEET_PATH,
		"visual_scale": Vector2(2.42, 2.42),
		"action_pattern": [
			{"name": "黏液撞击", "damage": 6, "hits": 1}
		]
	}


func _make_raven_executioner_definition() -> Dictionary:
	return {
		"id": "raven_executioner",
		"name": "鸦冠处刑者",
		"hp": 68,
		"sheet_path": RAVEN_EXECUTIONER_SHEET_PATH,
		"visual_scale": Vector2(2.58, 2.58),
		"action_pattern": [
			{"name": "破绽凝视", "block": 8, "mark_player": true, "intent_label": "印记+挡 8"},
			{"name": "连斩", "damage": 7, "hits": 2, "mark_bonus": 3},
			{"name": "架势调整", "block": 12, "gain_strength": 2, "intent_label": "挡 12 / 力量 2"},
			{"name": "处决", "damage": 20, "hits": 1, "mark_bonus": 6, "consume_mark": true}
		]
	}


func _make_cracked_core_slime_definition() -> Dictionary:
	return {
		"id": "cracked_core_slime",
		"name": "裂核史莱姆",
		"hp": 82,
		"sheet_path": CRACKED_CORE_SLIME_SHEET_PATH,
		"visual_scale": Vector2(2.62, 2.62),
		"action_pattern": [
			{"name": "黏液护壳", "block": 14, "intent_label": "挡 14"},
			{"name": "酸液撞击", "damage": 10, "hits": 1, "block_bonus_damage": 4, "apply_player_status": {"weak": 1}},
			{"name": "裂核膨胀", "gain_strength": 3, "intent_label": "力量 3"},
			{"name": "分裂重压", "damage": 8, "hits": 2}
		]
	}


func _make_forged_soul_tyrant_definition() -> Dictionary:
	return {
		"id": "forged_soul_tyrant",
		"name": "铸魂暴君",
		"hp": 180,
		"sheet_path": FORGED_SOUL_TYRANT_SHEET_PATH,
		"visual_scale": Vector2(3.05, 3.05),
		"phase_two_threshold": 90,
		"action_pattern": [
			{"name": "暴君挥砍", "damage": 12, "hits": 1},
			{"name": "铸魂护甲", "block": 18, "intent_label": "挡 18"},
			{"name": "战意升温", "gain_strength": 3, "intent_label": "力量 3"},
			{"name": "裂地连击", "damage": 6, "hits": 3}
		],
		"phase_two_pattern": [
			{"name": "王座压迫", "damage": 14, "hits": 1, "draw_reduction": 1, "apply_player_status": {"weak": 2}},
			{"name": "黑铁壁垒", "block": 22, "apply_player_status": {"frail": 2}},
			{"name": "终焉连斩", "damage": 8, "hits": 4},
			{"name": "暴君审判", "damage": 32, "hits": 1}
		]
	}


func _start_battle() -> void:
	var game_manager: Node = _game_manager()
	player_state = {
		"hp": int(game_manager.get("player_hp")),
		"max_hp": int(game_manager.get("player_max_hp")),
		"block": 0,
		"strength": 0,
		"powers": {},
		"turn_effects": {},
		"status_effects": {},
		"draw_reduction_next_turn": 0
	}
	current_enemy_definition = _select_enemy_definition()
	enemy_state = _build_enemy_state(current_enemy_definition)
	current_energy = PLAYER_MAX_ENERGY
	max_energy = PLAYER_MAX_ENERGY
	draw_pile = _build_run_deck()
	draw_pile.shuffle()
	hand_cards.clear()
	discard_pile.clear()
	played_pile.clear()
	exhaust_pile.clear()

	if player_view != null and player_view.has_method("setup_hp"):
		player_view.call("setup_hp", player_state["hp"], player_state["max_hp"])
	if enemy_view != null and enemy_view.has_method("setup_hp"):
		enemy_view.call("setup_hp", enemy_state["hp"], enemy_state["max_hp"])
	if enemy_view != null and enemy_view.has_method("set_visual_scale"):
		enemy_view.call("set_visual_scale", current_enemy_definition.get("visual_scale", Vector2(2.42, 2.42)))
	if enemy_view != null and enemy_view.has_method("setup"):
		enemy_view.call("setup", str(current_enemy_definition.get("sheet_path", SLIME_SHEET_PATH)))

	_start_player_turn()


func _start_player_turn() -> void:
	if _is_battle_finished():
		return

	battle_state = BattleState.PLAYER_TURN
	if not _has_power("retain_block"):
		player_state["block"] = 0
	player_state["turn_effects"] = {}
	_apply_start_of_turn_powers()
	set_energy(max_energy, max_energy)
	var draw_count: int = maxi(HAND_DRAW_COUNT - int(player_state.get("draw_reduction_next_turn", 0)), 1)
	player_state["draw_reduction_next_turn"] = 0
	_draw_until_hand_size(draw_count)
	_sync_hand_area()
	_set_hand_enabled(true)
	_update_all_battle_ui("玩家回合")


func _on_card_play_requested(card_data: Dictionary, card_view: Control, target_id: String) -> void:
	if battle_state != BattleState.PLAYER_TURN:
		_reject_card(card_view)
		return

	if not _is_card_target_valid(card_data, target_id):
		_update_all_battle_ui("目标无效")
		_reject_card(card_view)
		return

	var cost: int = int(card_data.get("cost", 0))
	if not spend_energy(cost):
		_update_all_battle_ui("能量不足")
		_reject_card(card_view)
		return

	battle_state = BattleState.RESOLVING_CARD
	_set_hand_enabled(false)
	_remove_card_from_hand(card_data)

	var play_position: Vector2 = _get_card_play_position(card_data, target_id)
	if hand_area != null and hand_area.has_method("confirm_card_play"):
		hand_area.call("confirm_card_play", card_data, card_view, play_position)

	_resolve_card_effect(card_data)
	var remove_after_play: bool = _is_card_removed_after_play(card_data)
	if remove_after_play:
		exhaust_pile.append(card_data.duplicate(true))
		if bool(card_data.get("exhaust", false)):
			_trigger_card_exhaust(card_data)
	else:
		played_pile.append(card_data.duplicate(true))
	if _is_battle_finished():
		return

	_update_all_battle_ui("结算：%s" % str(card_data.get("name", "")))

	await get_tree().create_timer(0.35).timeout
	if _is_battle_finished():
		return

	if not remove_after_play:
		discard_pile.append(card_data.duplicate(true))
	_sync_pile_counts()
	battle_state = BattleState.PLAYER_TURN
	_set_hand_enabled(true)
	_update_all_battle_ui("玩家回合")


func _resolve_card_effect(card_data: Dictionary) -> void:
	var damage: int = _get_card_damage(card_data)
	var block: int = int(card_data.get("block", 0))
	var card_type: String = str(card_data.get("type", "Skill"))

	if damage > 0:
		var hit_count: int = _consume_attack_repeat_count(card_data)
		for hit_index in range(hit_count):
			if player_view != null and player_view.has_method("play_attack"):
				player_view.call("play_attack")
			_deal_damage_to_enemy(damage)
			_spawn_floating_text(_get_enemy_canvas_position() + Vector2(0, -170 - float(hit_index) * 26.0), "-%d" % damage, Color(1.0, 0.35, 0.22, 1.0))
		if card_type == "Attack":
			_trigger_attack_played()

	if block > 0:
		_gain_block(block)

	var gain_strength: int = int(card_data.get("gain_strength", 0))
	if gain_strength > 0 and _can_gain_strength_from_card(card_data):
		_gain_strength(gain_strength)

	if bool(card_data.get("double_strength", false)):
		var current_strength: int = int(player_state.get("strength", 0))
		_gain_strength(current_strength)

	var strength_per_turn: int = int(card_data.get("strength_per_turn", 0))
	if strength_per_turn > 0:
		_add_power_value("strength_per_turn", strength_per_turn)
		_spawn_player_text("力量涌动 +%d/回合" % strength_per_turn, Color(1.0, 0.36, 0.22, 1.0))

	if bool(card_data.get("retain_block", false)):
		_set_power_enabled("retain_block", true)
		_spawn_player_text("格挡保留", Color(0.48, 0.78, 1.0, 1.0))

	var exhaust_block: int = int(card_data.get("on_card_exhaust_gain_block", 0))
	if exhaust_block > 0:
		_add_power_value("on_card_exhaust_gain_block", exhaust_block)
		_spawn_player_text("消耗得格挡 +%d" % exhaust_block, Color(0.48, 0.78, 1.0, 1.0))

	var rage_block: int = int(card_data.get("on_attack_played_gain_block", 0))
	if rage_block > 0:
		_add_turn_effect_value("on_attack_played_gain_block", rage_block)
		_spawn_player_text("本回合攻击得格挡 +%d" % rage_block, Color(0.48, 0.78, 1.0, 1.0))

	var repeat_count: int = int(card_data.get("next_attack_repeat_count", 0))
	if repeat_count > 0:
		_add_turn_effect_value("next_attack_repeat_count", repeat_count)
		_spawn_player_text("下一张攻击 x%d" % (repeat_count + 1), Color(1.0, 0.74, 0.32, 1.0))

	_apply_status_map_to_actor("enemy", card_data.get("apply_enemy_status", {}))
	_apply_status_map_to_actor("player", card_data.get("apply_player_status", {}))
	_check_victory_or_defeat()


func _deal_damage_to_enemy(amount: int) -> void:
	var remaining_damage: int = maxi(amount, 0)
	var enemy_block: int = int(enemy_state.get("block", 0))
	var blocked: int = mini(enemy_block, remaining_damage)
	enemy_state["block"] = enemy_block - blocked
	remaining_damage -= blocked
	enemy_state["hp"] = maxi(int(enemy_state.get("hp", 0)) - remaining_damage, 0)

	if enemy_view != null:
		if int(enemy_state["hp"]) <= 0 and enemy_view.has_method("play_death"):
			enemy_view.call("play_death")
		elif enemy_view.has_method("play_hit"):
			enemy_view.call("play_hit")

	if enemy_view != null and enemy_view.has_method("set_hp"):
		enemy_view.call("set_hp", enemy_state["hp"], enemy_state["max_hp"])

	_maybe_trigger_enemy_phase_change()


func _deal_damage_to_player(amount: int) -> void:
	var remaining_damage: int = maxi(amount, 0)
	var player_block: int = int(player_state.get("block", 0))
	var blocked: int = mini(player_block, remaining_damage)
	player_state["block"] = player_block - blocked
	remaining_damage -= blocked
	player_state["hp"] = maxi(int(player_state.get("hp", 0)) - remaining_damage, 0)
	_game_manager().set("player_hp", int(player_state["hp"]))

	if player_view != null:
		if int(player_state["hp"]) <= 0 and player_view.has_method("play_death"):
			player_view.call("play_death")
		elif remaining_damage > 0 and player_view.has_method("play_hit"):
			player_view.call("play_hit")
			_spawn_floating_text(player_view.get_global_transform_with_canvas().origin + Vector2(0, -170), "-%d" % remaining_damage, Color(1.0, 0.32, 0.24, 1.0))
		elif blocked > 0 and player_view.has_method("play_block_gain"):
			player_view.call("play_block_gain")

	if player_view != null and player_view.has_method("set_hp"):
		player_view.call("set_hp", player_state["hp"], player_state["max_hp"])


func _on_end_turn_pressed() -> void:
	if battle_state != BattleState.PLAYER_TURN:
		return

	_end_player_turn()


func _end_player_turn() -> void:
	battle_state = BattleState.ENEMY_TURN
	_set_hand_enabled(false)
	player_state["turn_effects"] = {}
	_tick_actor_statuses("player")
	_discard_current_hand()
	_sync_hand_area()
	_update_all_battle_ui("敌人回合")
	_run_enemy_turn()


func _run_enemy_turn() -> void:
	await get_tree().create_timer(0.35).timeout
	if _is_battle_finished():
		return

	enemy_state["block"] = 0
	var action: Dictionary = _get_current_enemy_action()
	var total_hits: int = int(action.get("hits", 1))
	var damage_per_hit: int = _get_enemy_action_damage(action)
	if damage_per_hit > 0 and enemy_view != null and enemy_view.has_method("play_attack"):
		enemy_view.call("play_attack")

	await get_tree().create_timer(0.35).timeout
	for hit_index in range(total_hits):
		if damage_per_hit > 0:
			_deal_damage_to_player(damage_per_hit)
			if hit_index < total_hits - 1:
				await get_tree().create_timer(0.12).timeout

	_apply_enemy_non_damage_effects(action)
	_update_all_battle_ui(str(action.get("name", "敌人行动")))
	_check_victory_or_defeat()
	if _is_battle_finished():
		return

	await get_tree().create_timer(0.45).timeout
	_advance_enemy_action()
	_tick_actor_statuses("enemy")
	_refresh_enemy_intent_damage()
	_start_player_turn()


func _get_current_enemy_action() -> Dictionary:
	var action: Variant = enemy_state.get("current_action", {})
	if action is Dictionary and not (action as Dictionary).is_empty():
		return (action as Dictionary).duplicate(true)

	var next_action: Dictionary = _get_enemy_action_for_state(enemy_state)
	enemy_state["current_action"] = next_action
	enemy_state["intent_damage"] = _get_enemy_action_total_damage(next_action)
	return next_action


func _get_enemy_action_for_state(state: Dictionary) -> Dictionary:
	var pattern: Array = state.get("action_pattern", [])
	if pattern.is_empty():
		return {"name": "攻击", "damage": ENEMY_INTENT_DAMAGE, "hits": 1}

	var turn_index: int = int(state.get("turn_index", 0))
	var action: Variant = pattern[turn_index % pattern.size()]
	if action is Dictionary:
		return (action as Dictionary).duplicate(true)
	return {"name": "攻击", "damage": ENEMY_INTENT_DAMAGE, "hits": 1}


func _advance_enemy_action() -> void:
	enemy_state["turn_index"] = int(enemy_state.get("turn_index", 0)) + 1
	var next_action: Dictionary = _get_enemy_action_for_state(enemy_state)
	enemy_state["current_action"] = next_action
	_refresh_enemy_intent_damage()


func _refresh_enemy_intent_damage() -> void:
	var action: Dictionary = _get_current_enemy_action()
	enemy_state["intent_damage"] = _get_enemy_action_total_damage(action)


func _get_enemy_action_damage(action: Dictionary) -> int:
	var damage: int = int(action.get("damage", 0))
	if damage <= 0:
		return 0

	damage += int(enemy_state.get("strength", 0))
	if bool(_get_player_status_effects().get("execution_mark", false)):
		damage += int(action.get("mark_bonus", 0))
	if int(player_state.get("block", 0)) > 0:
		damage += int(action.get("block_bonus_damage", 0))
	return _apply_damage_status_modifiers(damage, "enemy", "player")


func _get_enemy_action_total_damage(action: Dictionary) -> int:
	return _get_enemy_action_damage(action) * maxi(int(action.get("hits", 1)), 1)


func _apply_enemy_non_damage_effects(action: Dictionary) -> void:
	var block_amount: int = int(action.get("block", 0))
	if block_amount > 0:
		block_amount = _apply_block_status_modifiers(block_amount, "enemy")
		enemy_state["block"] = int(enemy_state.get("block", 0)) + block_amount
		if enemy_view != null and enemy_view.has_method("play_block_gain"):
			enemy_view.call("play_block_gain")
		_spawn_enemy_text("+%d 格挡" % block_amount, Color(0.48, 0.78, 1.0, 1.0))

	var gain_strength: int = int(action.get("gain_strength", 0))
	if gain_strength > 0:
		enemy_state["strength"] = int(enemy_state.get("strength", 0)) + gain_strength
		_spawn_enemy_text("+%d 力量" % gain_strength, Color(1.0, 0.36, 0.22, 1.0))

	if bool(action.get("mark_player", false)):
		_apply_status_to_actor("player", "execution_mark", 1)

	if bool(action.get("consume_mark", false)):
		_remove_status_from_actor("player", "execution_mark")

	var draw_reduction: int = int(action.get("draw_reduction", 0))
	if draw_reduction > 0:
		player_state["draw_reduction_next_turn"] = draw_reduction
		_spawn_player_text("下回合少抽 %d" % draw_reduction, Color(0.74, 0.55, 1.0, 1.0))

	_apply_status_map_to_actor("player", action.get("apply_player_status", {}))
	_apply_status_map_to_actor("enemy", action.get("apply_enemy_status", {}))


func _maybe_trigger_enemy_phase_change() -> void:
	if bool(enemy_state.get("phase_changed", false)):
		return
	if int(enemy_state.get("hp", 0)) <= 0:
		return

	var threshold: int = int(enemy_state.get("phase_two_threshold", 0))
	var phase_two_pattern: Array = enemy_state.get("phase_two_pattern", [])
	if threshold <= 0 or phase_two_pattern.is_empty():
		return
	if int(enemy_state.get("hp", 0)) > threshold:
		return

	enemy_state["phase"] = 2
	enemy_state["phase_changed"] = true
	enemy_state["action_pattern"] = phase_two_pattern
	enemy_state["turn_index"] = 0
	enemy_state["block"] = 25
	enemy_state["strength"] = int(enemy_state.get("strength", 0)) + 4
	var next_action: Dictionary = _get_enemy_action_for_state(enemy_state)
	enemy_state["current_action"] = next_action
	enemy_state["intent_damage"] = _get_enemy_action_total_damage(next_action)
	_spawn_enemy_text("铸魂暴走", Color(1.0, 0.38, 0.16, 1.0))


func _draw_until_hand_size(target_size: int) -> void:
	while hand_cards.size() < target_size:
		if draw_pile.is_empty():
			if discard_pile.is_empty():
				return
			draw_pile = discard_pile.duplicate(true)
			discard_pile.clear()
			draw_pile.shuffle()

		if draw_pile.is_empty():
			return

		hand_cards.append(draw_pile.pop_back())


func _discard_current_hand() -> void:
	for card in hand_cards:
		discard_pile.append(card.duplicate(true))
	hand_cards.clear()


func _remove_card_from_hand(card_data: Dictionary) -> void:
	var instance_id: int = int(card_data.get("instance_id", -1))
	for index in range(hand_cards.size()):
		var hand_card: Dictionary = hand_cards[index]
		if int(hand_card.get("instance_id", -2)) == instance_id:
			hand_cards.remove_at(index)
			return


func _sync_hand_area() -> void:
	if hand_area != null and hand_area.has_method("set_cards"):
		hand_area.call("set_cards", hand_cards)
	_sync_pile_counts()
	_refresh_drop_targets()


func _sync_pile_counts() -> void:
	if hand_area != null and hand_area.has_method("set_pile_counts"):
		hand_area.call("set_pile_counts", draw_pile.size(), discard_pile.size())


func _spawn_floating_text(canvas_position: Vector2, text: String, color: Color) -> void:
	var label: Label = Label.new()
	label.name = "FloatingText"
	label.position = canvas_position - Vector2(80.0, 18.0)
	label.size = Vector2(160.0, 42.0)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.text = text
	label.z_index = 70
	label.add_theme_font_size_override("font_size", 30)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	hand_ui_layer.add_child(label)

	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "position", label.position + Vector2(0.0, -54.0), 0.58)
	tween.tween_property(label, "modulate", Color(1, 1, 1, 0), 0.58)
	tween.chain().tween_callback(Callable(label, "queue_free"))


func _refresh_drop_targets() -> void:
	if hand_area == null or not hand_area.has_method("set_drop_targets"):
		return

	var enemy_center: Vector2 = _get_enemy_canvas_position()
	var enemy_rect: Rect2 = Rect2(enemy_center - Vector2(210, 230), Vector2(420, 420))
	hand_area.call("set_drop_targets", [
		{
			"id": ENEMY_TARGET_ID,
			"type": "enemy",
			"global_rect": enemy_rect,
			"play_position": enemy_center + Vector2(0, -40)
		}
	])


func _get_enemy_canvas_position() -> Vector2:
	if enemy_view != null:
		return enemy_view.get_global_transform_with_canvas().origin
	return enemy_slot.get_global_transform_with_canvas().origin


func _get_card_play_position(card_data: Dictionary, target_id: String) -> Vector2:
	if str(card_data.get("type", "Skill")) == "Attack" and target_id == ENEMY_TARGET_ID:
		return _get_enemy_canvas_position() + Vector2(0, -40)
	if str(card_data.get("type", "Skill")) == "Power":
		return Vector2(960, 520)
	return Vector2(500, 560)


func _is_card_target_valid(card_data: Dictionary, target_id: String) -> bool:
	var card_type: String = str(card_data.get("type", "Skill"))
	if card_type == "Attack":
		return target_id == ENEMY_TARGET_ID and int(enemy_state.get("hp", 0)) > 0
	return target_id == "self"


func _get_card_damage(card_data: Dictionary) -> int:
	var base_damage: int = maxi(int(player_state.get("block", 0)), 0) if bool(card_data.get("damage_from_block", false)) else int(card_data.get("damage", 0))
	if base_damage <= 0:
		return 0

	if str(card_data.get("type", "Skill")) == "Attack":
		base_damage += int(player_state.get("strength", 0))
		base_damage = _apply_damage_status_modifiers(base_damage, "player", "enemy")

	return maxi(base_damage, 0)


func _consume_attack_repeat_count(card_data: Dictionary) -> int:
	if str(card_data.get("type", "Skill")) != "Attack":
		return 1

	var turn_effects: Dictionary = _get_turn_effects()
	var repeat_count: int = int(turn_effects.get("next_attack_repeat_count", 0))
	if repeat_count <= 0:
		return 1

	turn_effects["next_attack_repeat_count"] = 0
	player_state["turn_effects"] = turn_effects
	return 1 + repeat_count


func _trigger_attack_played() -> void:
	var rage_block: int = int(_get_turn_effects().get("on_attack_played_gain_block", 0))
	if rage_block > 0:
		_gain_block(rage_block)


func _trigger_card_exhaust(_card_data: Dictionary) -> void:
	var exhaust_block: int = int(_get_powers().get("on_card_exhaust_gain_block", 0))
	if exhaust_block > 0:
		_gain_block(exhaust_block)


func _is_card_removed_after_play(card_data: Dictionary) -> bool:
	if str(card_data.get("type", "Skill")) == "Power":
		return true
	return bool(card_data.get("exhaust", false))


func _can_gain_strength_from_card(card_data: Dictionary) -> bool:
	if not bool(card_data.get("requires_enemy_intent_attack", false)):
		return true
	return int(enemy_state.get("intent_damage", 0)) > 0


func _apply_start_of_turn_powers() -> void:
	var strength_per_turn: int = int(_get_powers().get("strength_per_turn", 0))
	if strength_per_turn > 0:
		_gain_strength(strength_per_turn)


func _gain_strength(amount: int) -> void:
	var safe_amount: int = maxi(amount, 0)
	if safe_amount <= 0:
		return

	player_state["strength"] = int(player_state.get("strength", 0)) + safe_amount
	_spawn_player_text("+%d 力量" % safe_amount, Color(1.0, 0.36, 0.22, 1.0))


func _gain_block(amount: int) -> void:
	var safe_amount: int = _apply_block_status_modifiers(amount, "player")
	if safe_amount <= 0:
		return

	player_state["block"] = int(player_state.get("block", 0)) + safe_amount
	if player_view != null and player_view.has_method("play_block_gain"):
		player_view.call("play_block_gain")
	_spawn_player_text("+%d 格挡" % safe_amount, Color(0.48, 0.78, 1.0, 1.0))


func _spawn_player_text(text: String, color: Color) -> void:
	var block_text_position: Vector2 = player_view.get_global_transform_with_canvas().origin if player_view != null else player_slot.get_global_transform_with_canvas().origin
	_spawn_floating_text(block_text_position + Vector2(0, -170), text, color)


func _spawn_enemy_text(text: String, color: Color) -> void:
	_spawn_floating_text(_get_enemy_canvas_position() + Vector2(0, -170), text, color)


func _apply_damage_status_modifiers(amount: int, source_actor: String, target_actor: String) -> int:
	var modified_amount: float = float(maxi(amount, 0))
	if _get_actor_status_amount(target_actor, "vulnerable") > 0:
		modified_amount *= 1.5
	if _get_actor_status_amount(source_actor, "weak") > 0:
		modified_amount *= 0.75
	return maxi(floori(modified_amount), 0)


func _apply_block_status_modifiers(amount: int, actor_id: String) -> int:
	var modified_amount: int = maxi(amount, 0)
	modified_amount += _get_actor_status_amount(actor_id, "dexterity")
	if _get_actor_status_amount(actor_id, "frail") > 0:
		modified_amount = floori(float(modified_amount) * 0.75)
	return maxi(modified_amount, 0)


func _apply_status_map_to_actor(actor_id: String, status_map: Variant) -> void:
	if not (status_map is Dictionary):
		return

	var typed_status_map: Dictionary = status_map as Dictionary
	for status_id in typed_status_map.keys():
		_apply_status_to_actor(actor_id, str(status_id), int(typed_status_map[status_id]))


func _apply_status_to_actor(actor_id: String, status_id: String, amount: int) -> void:
	var safe_amount: int = maxi(amount, 0)
	if safe_amount <= 0:
		return

	var statuses: Dictionary = _get_actor_status_effects(actor_id)
	if status_id == "execution_mark":
		statuses[status_id] = 1
	else:
		statuses[status_id] = int(statuses.get(status_id, 0)) + safe_amount
	_set_actor_status_effects(actor_id, statuses)
	_spawn_status_text(actor_id, status_id, safe_amount)


func _remove_status_from_actor(actor_id: String, status_id: String) -> void:
	var statuses: Dictionary = _get_actor_status_effects(actor_id)
	statuses.erase(status_id)
	_set_actor_status_effects(actor_id, statuses)


func _tick_actor_statuses(actor_id: String) -> void:
	var statuses: Dictionary = _get_actor_status_effects(actor_id)
	var changed: bool = false
	for status_id in statuses.keys():
		if not bool(_get_status_definition(str(status_id)).get("ticks_down", true)):
			continue
		var next_amount: int = int(statuses[status_id]) - 1
		if next_amount <= 0:
			statuses.erase(status_id)
		else:
			statuses[status_id] = next_amount
		changed = true

	if changed:
		_set_actor_status_effects(actor_id, statuses)


func _get_actor_status_amount(actor_id: String, status_id: String) -> int:
	if status_id == "strength":
		return int(player_state.get("strength", 0)) if actor_id == "player" else int(enemy_state.get("strength", 0))
	return int(_get_actor_status_effects(actor_id).get(status_id, 0))


func _get_actor_status_effects(actor_id: String) -> Dictionary:
	var status_effects: Variant = player_state.get("status_effects", {}) if actor_id == "player" else enemy_state.get("status_effects", {})
	if status_effects is Dictionary:
		return (status_effects as Dictionary).duplicate(true)
	return {}


func _set_actor_status_effects(actor_id: String, statuses: Dictionary) -> void:
	if actor_id == "player":
		player_state["status_effects"] = statuses
	else:
		enemy_state["status_effects"] = statuses
	if actor_id == "enemy":
		_refresh_enemy_intent_damage()


func _get_status_definition(status_id: String) -> Dictionary:
	var definition: Variant = STATUS_DEFINITIONS.get(status_id, {})
	if definition is Dictionary:
		return definition as Dictionary
	return {}


func _get_status_short_name(status_id: String) -> String:
	var definition: Dictionary = _get_status_definition(status_id)
	return str(definition.get("short_name", status_id))


func _get_status_full_name(status_id: String) -> String:
	var definition: Dictionary = _get_status_definition(status_id)
	return str(definition.get("name", status_id))


func _spawn_status_text(actor_id: String, status_id: String, amount: int) -> void:
	var text: String = _get_status_full_name(status_id)
	if status_id != "execution_mark":
		text += " +%d" % amount
	if actor_id == "player":
		_spawn_player_text(text, Color(1.0, 0.42, 0.28, 1.0))
	else:
		_spawn_enemy_text(text, Color(1.0, 0.42, 0.28, 1.0))


func _get_player_status_effects() -> Dictionary:
	return _get_actor_status_effects("player")


func _set_player_status_effect(effect_id: String, enabled: bool) -> void:
	if enabled:
		_apply_status_to_actor("player", effect_id, 1)
	else:
		_remove_status_from_actor("player", effect_id)


func _get_powers() -> Dictionary:
	var powers: Variant = player_state.get("powers", {})
	if powers is Dictionary:
		return (powers as Dictionary).duplicate(true)
	return {}


func _get_turn_effects() -> Dictionary:
	var turn_effects: Variant = player_state.get("turn_effects", {})
	if turn_effects is Dictionary:
		return (turn_effects as Dictionary).duplicate(true)
	return {}


func _set_power_enabled(power_id: String, enabled: bool) -> void:
	var powers: Dictionary = _get_powers()
	powers[power_id] = enabled
	player_state["powers"] = powers


func _has_power(power_id: String) -> bool:
	return bool(_get_powers().get(power_id, false))


func _add_power_value(power_id: String, amount: int) -> void:
	var safe_amount: int = maxi(amount, 0)
	if safe_amount <= 0:
		return

	var powers: Dictionary = _get_powers()
	powers[power_id] = int(powers.get(power_id, 0)) + safe_amount
	player_state["powers"] = powers


func _add_turn_effect_value(effect_id: String, amount: int) -> void:
	var safe_amount: int = maxi(amount, 0)
	if safe_amount <= 0:
		return

	var turn_effects: Dictionary = _get_turn_effects()
	turn_effects[effect_id] = int(turn_effects.get(effect_id, 0)) + safe_amount
	player_state["turn_effects"] = turn_effects


func _reject_card(card_view: Control) -> void:
	if hand_area != null and hand_area.has_method("reject_card"):
		hand_area.call("reject_card", card_view)


func _set_hand_enabled(enabled: bool) -> void:
	if hand_area != null and hand_area.has_method("set_hand_interaction_enabled"):
		hand_area.call("set_hand_interaction_enabled", enabled)
	if end_turn_button != null:
		end_turn_button.disabled = not enabled
	if end_turn_frame != null:
		end_turn_frame.modulate = Color(1, 1, 1, 1) if enabled else Color(0.55, 0.55, 0.55, 0.72)


func _check_victory_or_defeat() -> void:
	if int(enemy_state.get("hp", 0)) <= 0:
		_finish_battle(true)
		return

	if int(player_state.get("hp", 0)) <= 0:
		_finish_battle(false)


func _finish_battle(victory: bool) -> void:
	battle_state = BattleState.VICTORY if victory else BattleState.DEFEAT
	_set_hand_enabled(false)
	if result_overlay != null:
		result_overlay.visible = true
	if result_label != null:
		result_label.text = "战斗胜利\n选择卡牌奖励" if victory else "战斗失败"
	if result_continue_button != null:
		result_continue_button.visible = victory
	if result_menu_button != null:
		result_menu_button.visible = not victory
	_update_all_battle_ui("胜利" if victory else "失败")


func _on_victory_continue_pressed() -> void:
	var game_manager: Node = _game_manager()
	game_manager.call("add_gold", _get_victory_gold_reward())
	get_tree().change_scene_to_file(CARD_REWARD_SCENE_PATH)


func _on_defeat_menu_pressed() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)


func _get_victory_gold_reward() -> int:
	var node_type: String = str(_game_manager().get("current_node_type"))
	match node_type:
		"battle_elite":
			return 35
		"battle_boss":
			return 80
	return 20


func _is_battle_finished() -> bool:
	return battle_state == BattleState.VICTORY or battle_state == BattleState.DEFEAT


func _update_all_battle_ui(status_text: String) -> void:
	if turn_status_label != null:
		turn_status_label.text = _format_turn_status(status_text)
	if enemy_intent_label != null:
		enemy_intent_label.text = _format_enemy_intent_text()
		enemy_intent_label.visible = int(enemy_state.get("hp", ENEMY_START_HP)) > 0
	if enemy_intent_value_label != null:
		enemy_intent_value_label.visible = false
	if enemy_intent_icon != null:
		enemy_intent_icon.visible = false

	_update_energy_label()

	if player_view != null and player_view.has_method("set_hp"):
		player_view.call("set_hp", player_state.get("hp", PLAYER_START_HP), player_state.get("max_hp", PLAYER_START_HP))
	if player_view != null and player_view.has_method("set_block"):
		player_view.call("set_block", player_state.get("block", 0))
	if enemy_view != null and enemy_view.has_method("set_hp"):
		enemy_view.call("set_hp", enemy_state.get("hp", ENEMY_START_HP), enemy_state.get("max_hp", ENEMY_START_HP))
	if enemy_view != null and enemy_view.has_method("set_block"):
		enemy_view.call("set_block", enemy_state.get("block", 0))
	if battle_top_dock != null and battle_top_dock.has_method("set_player_info"):
		battle_top_dock.call("set_player_info", "铁甲战士", player_state.get("hp", PLAYER_START_HP), player_state.get("max_hp", PLAYER_START_HP))
	if battle_top_dock != null and battle_top_dock.has_method("set_gold"):
		battle_top_dock.call("set_gold", int(_game_manager().get("gold")))
	if battle_top_dock != null and battle_top_dock.has_method("set_floor"):
		battle_top_dock.call("set_floor", int(_game_manager().get("floor")))
	if battle_top_dock != null and battle_top_dock.has_method("set_deck_count"):
		battle_top_dock.call("set_deck_count", draw_pile.size())


func _format_turn_status(status_text: String) -> String:
	var parts: PackedStringArray = PackedStringArray([status_text])
	var enemy_name: String = str(enemy_state.get("name", ""))
	if not enemy_name.is_empty():
		parts.append(enemy_name)
	var strength: int = int(player_state.get("strength", 0))
	if strength > 0:
		parts.append("力量 %d" % strength)
	_append_actor_status_summary(parts, "player", "")
	var powers: Dictionary = _get_powers()
	if int(powers.get("strength_per_turn", 0)) > 0:
		parts.append("恶魔 +%d" % int(powers.get("strength_per_turn", 0)))
	if bool(powers.get("retain_block", false)):
		parts.append("壁垒")
	if int(powers.get("on_card_exhaust_gain_block", 0)) > 0:
		parts.append("无惧 +%d" % int(powers.get("on_card_exhaust_gain_block", 0)))
	var turn_effects: Dictionary = _get_turn_effects()
	if int(turn_effects.get("on_attack_played_gain_block", 0)) > 0:
		parts.append("盛怒 +%d" % int(turn_effects.get("on_attack_played_gain_block", 0)))
	if int(turn_effects.get("next_attack_repeat_count", 0)) > 0:
		parts.append("双发")
	var enemy_strength: int = int(enemy_state.get("strength", 0))
	if enemy_strength > 0:
		parts.append("敌力 %d" % enemy_strength)
	_append_actor_status_summary(parts, "enemy", "敌")
	return " | ".join(parts)


func _append_actor_status_summary(parts: PackedStringArray, actor_id: String, prefix: String) -> void:
	var statuses: Dictionary = _get_actor_status_effects(actor_id)
	for status_id in statuses.keys():
		var amount: int = int(statuses[status_id])
		if amount <= 0:
			continue
		if str(status_id) == "execution_mark":
			parts.append("%s%s" % [prefix, _get_status_short_name(str(status_id))])
		else:
			parts.append("%s%s %d" % [prefix, _get_status_short_name(str(status_id)), amount])


func _format_enemy_intent_text() -> String:
	var action: Dictionary = _get_current_enemy_action()
	if action.has("intent_label"):
		return str(action.get("intent_label", ""))

	var parts: PackedStringArray = PackedStringArray()
	var damage: int = _get_enemy_action_damage(action)
	var hits: int = maxi(int(action.get("hits", 1)), 1)
	if damage > 0:
		if hits == 1:
			parts.append("攻 %d" % damage)
		else:
			parts.append("攻 %dx%d" % [damage, hits])

	var block_amount: int = int(action.get("block", 0))
	if block_amount > 0:
		parts.append("挡 %d" % block_amount)

	var gain_strength: int = int(action.get("gain_strength", 0))
	if gain_strength > 0:
		parts.append("力 %d" % gain_strength)

	if bool(action.get("mark_player", false)):
		parts.append("印记")
	if int(action.get("draw_reduction", 0)) > 0:
		parts.append("少抽 %d" % int(action.get("draw_reduction", 0)))
	var player_status: Variant = action.get("apply_player_status", {})
	if player_status is Dictionary:
		for status_id in (player_status as Dictionary).keys():
			parts.append("%s %d" % [_get_status_short_name(str(status_id)), int((player_status as Dictionary)[status_id])])
	var enemy_status: Variant = action.get("apply_enemy_status", {})
	if enemy_status is Dictionary:
		for status_id in (enemy_status as Dictionary).keys():
			parts.append("自%s %d" % [_get_status_short_name(str(status_id)), int((enemy_status as Dictionary)[status_id])])
	if parts.is_empty():
		return str(action.get("name", "行动"))
	return " / ".join(parts)


func set_energy(new_current_energy: int, new_max_energy: int) -> void:
	max_energy = maxi(new_max_energy, 1)
	current_energy = clampi(new_current_energy, 0, max_energy)
	_update_energy_label()


func spend_energy(cost: int) -> bool:
	var safe_cost: int = maxi(cost, 0)
	if current_energy < safe_cost:
		return false

	current_energy -= safe_cost
	_update_energy_label()
	return true


func reset_energy() -> void:
	set_energy(max_energy, max_energy)


func _update_energy_label() -> void:
	if energy_label == null:
		return

	energy_label.text = "%d/%d" % [current_energy, max_energy]


func _build_run_deck() -> Array:
	var deck: Array = _build_starter_deck()
	var game_manager: Node = _game_manager()
	var acquired_cards: Array = game_manager.get("deck_cards")
	for card_entry in acquired_cards:
		if not (card_entry is Dictionary):
			continue
		var card_id: String = str(card_entry.get("id", ""))
		var card: Dictionary = _make_card_from_library(card_id)
		if not card.is_empty():
			deck.append(card)
	return deck


func _build_starter_deck() -> Array:
	next_card_instance_id = 1
	return [
		_make_card("strike", "打击", 1, "Attack", "Common", "造成 6 点伤害。", "res://art/cards/basic_attack_art.png", 6, 0),
		_make_card("strike", "打击", 1, "Attack", "Common", "造成 6 点伤害。", "res://art/cards/basic_attack_art.png", 6, 0),
		_make_card("strike", "打击", 1, "Attack", "Common", "造成 6 点伤害。", "res://art/cards/basic_attack_art.png", 6, 0),
		_make_card("strike", "打击", 1, "Attack", "Common", "造成 6 点伤害。", "res://art/cards/basic_attack_art.png", 6, 0),
		_make_card("strike", "打击", 1, "Attack", "Common", "造成 6 点伤害。", "res://art/cards/basic_attack_art.png", 6, 0),
		_make_card("defend", "防御", 1, "Skill", "Common", "获得 5 点格挡。", "res://art/cards/basic_defend_art.png", 0, 5),
		_make_card("defend", "防御", 1, "Skill", "Common", "获得 5 点格挡。", "res://art/cards/basic_defend_art.png", 0, 5),
		_make_card("defend", "防御", 1, "Skill", "Common", "获得 5 点格挡。", "res://art/cards/basic_defend_art.png", 0, 5),
		_make_card("defend", "防御", 1, "Skill", "Common", "获得 5 点格挡。", "res://art/cards/basic_defend_art.png", 0, 5),
		_make_card("bash", "重击", 2, "Attack", "Common", "造成 8 点伤害。施加 2 层易伤。", "res://art/cards/bash_art.png", 8, 0, {"apply_enemy_status": {"vulnerable": 2}})
	]


func _make_card_from_library(card_id: String) -> Dictionary:
	match card_id:
		"strike":
			return _make_card("strike", "打击", 1, "Attack", "Common", "造成 6 点伤害。", "res://art/cards/basic_attack_art.png", 6, 0)
		"defend":
			return _make_card("defend", "防御", 1, "Skill", "Common", "获得 5 点格挡。", "res://art/cards/basic_defend_art.png", 0, 5)
		"bash":
			return _make_card("bash", "重击", 2, "Attack", "Common", "造成 8 点伤害。施加 2 层易伤。", "res://art/cards/bash_art.png", 8, 0, {"apply_enemy_status": {"vulnerable": 2}})
		"demon_form":
			return _make_card("demon_form", "恶魔形态", 3, "Power", "Rare", "在你的回合开始时，获得 2 点力量。", "res://art/cards/demon_form_art.png", 0, 0, {"strength_per_turn": 2})
		"spot_weakness":
			return _make_card("spot_weakness", "观察弱点", 1, "Skill", "Uncommon", "如果目标意图为攻击，获得 3 点力量。", "res://art/cards/spot_weakness_art.png", 0, 0, {"gain_strength": 3, "requires_enemy_intent_attack": true})
		"limit_break":
			return _make_card("limit_break", "突破极限", 1, "Skill", "Rare", "使你的力量翻倍。消耗。", "res://art/cards/limit_break_art.png", 0, 0, {"double_strength": true, "exhaust": true})
		"double_tap":
			return _make_card("double_tap", "双发", 1, "Skill", "Rare", "本回合你的下一张攻击牌打出两次。", "res://art/cards/double_tap_art.png", 0, 0, {"next_attack_repeat_count": 1})
		"body_slam":
			return _make_card("body_slam", "全身撞击", 1, "Attack", "Common", "造成等同于当前格挡的伤害。", "res://art/cards/body_slam_art.png", 0, 0, {"damage_from_block": true})
		"barricade":
			return _make_card("barricade", "壁垒", 3, "Power", "Rare", "你的格挡在回合开始时不再消失。", "res://art/cards/barricade_art.png", 0, 0, {"retain_block": true})
		"feel_no_pain":
			return _make_card("feel_no_pain", "无惧疼痛", 1, "Power", "Uncommon", "每当有一张牌被消耗时，获得 3 点格挡。", "res://art/cards/feel_no_pain_art.png", 0, 0, {"on_card_exhaust_gain_block": 3})
		"rage":
			return _make_card("rage", "盛怒", 0, "Skill", "Uncommon", "本回合每当你打出一张攻击牌，获得 3 点格挡。", "res://art/cards/rage_art.png", 0, 0, {"on_attack_played_gain_block": 3})
	return {}


func _make_card(
	card_id: String,
	card_name: String,
	cost: int,
	card_type: String,
	rarity: String,
	description: String,
	art_path: String,
	damage: int,
	block: int,
	extra_data: Dictionary = {}
) -> Dictionary:
	var card: Dictionary = {
		"instance_id": next_card_instance_id,
		"id": card_id,
		"name": card_name,
		"cost": cost,
		"type": card_type,
		"rarity": rarity,
		"description": description,
		"art_path": art_path,
		"frame_path": "",
		"damage": damage,
		"block": block
	}
	for key in extra_data.keys():
		card[key] = extra_data[key]
	next_card_instance_id += 1
	return card


func _assign_texture_or_hide(sprite: Sprite2D, texture_path: String) -> void:
	var loaded_texture: Texture2D = _load_texture_or_null(texture_path)
	if loaded_texture == null:
		sprite.visible = false
		return

	sprite.texture = loaded_texture
	sprite.visible = true


func _load_texture_or_null(texture_path: String) -> Texture2D:
	if texture_path.is_empty():
		return null

	if ResourceLoader.exists(texture_path):
		var loaded_resource: Resource = ResourceLoader.load(texture_path)
		if loaded_resource is Texture2D:
			return loaded_resource as Texture2D

	if FileAccess.file_exists(texture_path):
		var image: Image = Image.new()
		var load_error: int = image.load(texture_path)
		if load_error == OK:
			return ImageTexture.create_from_image(image)

	return null


func _game_manager() -> Node:
	return get_node("/root/GameManager")
