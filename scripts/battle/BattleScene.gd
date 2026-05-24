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
const PLAYER_SHEET_PATH: String = "res://art/characters/player/hero_combat_sheet.png"
const SLIME_SHEET_PATH: String = "res://art/enemies/slime/slime_combat_sheet.png"

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
var draw_pile: Array = []
var hand_cards: Array = []
var discard_pile: Array = []
var played_pile: Array = []
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
	result_continue_button.text = "继续"
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


func _start_battle() -> void:
	var game_manager: Node = _game_manager()
	player_state = {"hp": int(game_manager.get("player_hp")), "max_hp": int(game_manager.get("player_max_hp")), "block": 0}
	enemy_state = {"hp": ENEMY_START_HP, "max_hp": ENEMY_START_HP, "block": 0, "intent_damage": ENEMY_INTENT_DAMAGE}
	current_energy = PLAYER_MAX_ENERGY
	max_energy = PLAYER_MAX_ENERGY
	draw_pile = _build_starter_deck()
	draw_pile.shuffle()
	hand_cards.clear()
	discard_pile.clear()
	played_pile.clear()

	if player_view != null and player_view.has_method("setup_hp"):
		player_view.call("setup_hp", player_state["hp"], player_state["max_hp"])
	if enemy_view != null and enemy_view.has_method("setup_hp"):
		enemy_view.call("setup_hp", enemy_state["hp"], enemy_state["max_hp"])

	_start_player_turn()


func _start_player_turn() -> void:
	if _is_battle_finished():
		return

	battle_state = BattleState.PLAYER_TURN
	player_state["block"] = 0
	set_energy(max_energy, max_energy)
	_draw_until_hand_size(HAND_DRAW_COUNT)
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
	played_pile.append(card_data.duplicate(true))
	if _is_battle_finished():
		return

	_update_all_battle_ui("结算：%s" % str(card_data.get("name", "")))

	await get_tree().create_timer(0.35).timeout
	if _is_battle_finished():
		return

	discard_pile.append(card_data.duplicate(true))
	_sync_pile_counts()
	battle_state = BattleState.PLAYER_TURN
	_set_hand_enabled(true)
	_update_all_battle_ui("玩家回合")


func _resolve_card_effect(card_data: Dictionary) -> void:
	var damage: int = int(card_data.get("damage", 0))
	var block: int = int(card_data.get("block", 0))

	if damage > 0:
		if player_view != null and player_view.has_method("play_attack"):
			player_view.call("play_attack")
		_deal_damage_to_enemy(damage)
		_spawn_floating_text(_get_enemy_canvas_position() + Vector2(0, -170), "-%d" % damage, Color(1.0, 0.35, 0.22, 1.0))

	if block > 0:
		player_state["block"] = int(player_state.get("block", 0)) + block
		if player_view != null and player_view.has_method("play_block_gain"):
			player_view.call("play_block_gain")
		var block_text_position: Vector2 = player_view.get_global_transform_with_canvas().origin if player_view != null else player_slot.get_global_transform_with_canvas().origin
		_spawn_floating_text(block_text_position + Vector2(0, -170), "+%d 格挡" % block, Color(0.48, 0.78, 1.0, 1.0))

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
	_discard_current_hand()
	_sync_hand_area()
	_update_all_battle_ui("敌人回合")
	_run_enemy_turn()


func _run_enemy_turn() -> void:
	await get_tree().create_timer(0.35).timeout
	if _is_battle_finished():
		return

	if enemy_view != null and enemy_view.has_method("play_attack"):
		enemy_view.call("play_attack")

	await get_tree().create_timer(0.35).timeout
	_deal_damage_to_player(int(enemy_state.get("intent_damage", ENEMY_INTENT_DAMAGE)))
	_update_all_battle_ui("敌人攻击")
	_check_victory_or_defeat()
	if _is_battle_finished():
		return

	await get_tree().create_timer(0.45).timeout
	_start_player_turn()


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
		result_label.text = "战斗胜利\n奖励金币 +20" if victory else "战斗失败"
	if result_continue_button != null:
		result_continue_button.visible = victory
	if result_menu_button != null:
		result_menu_button.visible = not victory
	_update_all_battle_ui("胜利" if victory else "失败")


func _on_victory_continue_pressed() -> void:
	var game_manager: Node = _game_manager()
	game_manager.call("add_gold", 20)
	game_manager.call("complete_map_node", str(game_manager.get("current_node_id")))
	get_tree().change_scene_to_file(MAP_SCENE_PATH)


func _on_defeat_menu_pressed() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)


func _is_battle_finished() -> bool:
	return battle_state == BattleState.VICTORY or battle_state == BattleState.DEFEAT


func _update_all_battle_ui(status_text: String) -> void:
	if turn_status_label != null:
		turn_status_label.text = status_text
	if enemy_intent_label != null:
		enemy_intent_label.text = "攻 %d" % int(enemy_state.get("intent_damage", ENEMY_INTENT_DAMAGE))
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
		_make_card("bash", "重击", 2, "Attack", "Common", "造成 8 点伤害。", "res://art/cards/basic_attack_art.png", 8, 0),
		_make_card("poison_blade", "毒刃", 1, "Attack", "Uncommon", "造成 5 点伤害。", "res://art/cards/basic_attack_art.png", 5, 0),
		_make_card("focus", "专注", 1, "Power", "Rare", "获得 1 点格挡。", "res://art/cards/focus_art.png", 0, 1)
	]


func _make_card(
	card_id: String,
	card_name: String,
	cost: int,
	card_type: String,
	rarity: String,
	description: String,
	art_path: String,
	damage: int,
	block: int
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
