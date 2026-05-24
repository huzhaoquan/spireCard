extends Control

# BattleTopDock 只负责顶部状态栏 UI 展示，不包含战斗、地图、牌库或设置逻辑。

# 顶部栏固定高度。
const DOCK_HEIGHT: float = 72.0

# 顶部 Dock 图标资源路径；资源不存在时显示纯色占位。
const ICON_PATHS: Dictionary = {
	"hp": "res://art/ui/icon_hp.png",
	"gold": "res://art/ui/icon_gold.png",
	"floor": "res://art/ui/icon_floor.png",
	"map": "res://art/ui/icon_map.png",
	"deck": "res://art/ui/icon_deck.png",
	"settings": "res://art/ui/icon_settings.png"
}

# 左侧角色状态区域。
@onready var background: ColorRect = $Background
@onready var class_icon_placeholder: ColorRect = $Background/LeftStatusArea/ClassIconPlaceholder
@onready var class_icon: TextureRect = $Background/LeftStatusArea/ClassIcon
@onready var class_name_label: Label = $Background/LeftStatusArea/ClassNameLabel
@onready var hp_icon_placeholder: ColorRect = $Background/LeftStatusArea/HpIconPlaceholder
@onready var hp_icon: TextureRect = $Background/LeftStatusArea/HpIcon
@onready var hp_label: Label = $Background/LeftStatusArea/HpLabel
@onready var gold_icon_placeholder: ColorRect = $Background/LeftStatusArea/GoldIconPlaceholder
@onready var gold_icon: TextureRect = $Background/LeftStatusArea/GoldIcon
@onready var gold_label: Label = $Background/LeftStatusArea/GoldLabel
@onready var potion_slots: Array = [
	$Background/LeftStatusArea/PotionSlots/PotionSlot1,
	$Background/LeftStatusArea/PotionSlots/PotionSlot2,
	$Background/LeftStatusArea/PotionSlots/PotionSlot3
]

# 中间楼层区域。
@onready var floor_icon_placeholder: ColorRect = $Background/FloorArea/FloorIconPlaceholder
@onready var floor_icon: TextureRect = $Background/FloorArea/FloorIcon
@onready var floor_label: Label = $Background/FloorArea/FloorLabel

# 右侧按钮区域。
@onready var map_button: Button = $Background/RightMenuArea/MapButton
@onready var map_icon_placeholder: ColorRect = $Background/RightMenuArea/MapButton/MapIconPlaceholder
@onready var map_icon: TextureRect = $Background/RightMenuArea/MapButton/MapIcon
@onready var deck_button: Button = $Background/RightMenuArea/DeckButton
@onready var deck_icon_placeholder: ColorRect = $Background/RightMenuArea/DeckButton/DeckIconPlaceholder
@onready var deck_icon: TextureRect = $Background/RightMenuArea/DeckButton/DeckIcon
@onready var deck_count_label: Label = $Background/RightMenuArea/DeckCountLabel
@onready var settings_button: Button = $Background/RightMenuArea/SettingsButton
@onready var settings_icon_placeholder: ColorRect = $Background/RightMenuArea/SettingsButton/SettingsIconPlaceholder
@onready var settings_icon: TextureRect = $Background/RightMenuArea/SettingsButton/SettingsIcon


func _ready() -> void:
	# Dock 横向铺满顶部，避免被父节点尺寸影响。
	_layout_dock_background()
	mouse_filter = Control.MOUSE_FILTER_STOP

	_setup_icons()
	_apply_compact_battle_layout()
	_connect_buttons()

	# 默认演示数据，BattleScene 会在启动时覆盖。
	set_player_info("铁甲战士", 85, 85)
	set_gold(130)
	set_floor(7)
	set_deck_count(12)
	set_potions([null, null, null])


func _notification(what: int) -> void:
	# 视口尺寸变化时，继续保持顶部背景横向铺满。
	if not is_node_ready():
		return

	if what == NOTIFICATION_RESIZED:
		_layout_dock_background()


func _layout_dock_background() -> void:
	# CanvasLayer 下面的 Control 有时不会自动按父级撑开，这里直接按视口宽度设置尺寸。
	var viewport_size: Vector2 = get_viewport_rect().size
	position = Vector2.ZERO
	size = Vector2(viewport_size.x, DOCK_HEIGHT)
	custom_minimum_size = size

	if background == null:
		return

	background.position = Vector2.ZERO
	background.size = size
	background.color = Color(0.08, 0.075, 0.085, 0.18)
	if is_node_ready():
		_apply_compact_battle_layout()


func set_player_info(player_class_name: String, hp: int, max_hp: int) -> void:
	# 设置职业名称和 HP 文本，只做展示。
	class_name_label.text = player_class_name
	hp_label.text = "%d/%d" % [maxi(hp, 0), maxi(max_hp, 1)]


func set_gold(gold: int) -> void:
	# 设置金币数量。
	gold_label.text = str(maxi(gold, 0))


func set_floor(floor: int) -> void:
	# 设置当前楼层。
	floor_label.text = "第 %d 层" % maxi(floor, 1)


func set_deck_count(count: int) -> void:
	# 设置牌库数量。
	deck_count_label.text = str(maxi(count, 0))


func set_potions(potions: Array) -> void:
	# 刷新 3 个药水槽。字典代表有药水，null 代表空槽。
	for index in range(potion_slots.size()):
		var slot: Control = potion_slots[index] as Control
		var potion_data: Variant = null
		if index < potions.size():
			potion_data = potions[index]

		_update_potion_slot(slot, potion_data)


func _setup_icons() -> void:
	# 自动加载图标；没有资源时保留纯色占位。
	_apply_icon("hp", hp_icon, hp_icon_placeholder)
	_apply_icon("gold", gold_icon, gold_icon_placeholder)
	_apply_icon("floor", floor_icon, floor_icon_placeholder)
	_apply_icon("map", map_icon, map_icon_placeholder)
	_apply_icon("deck", deck_icon, deck_icon_placeholder)
	_apply_icon("settings", settings_icon, settings_icon_placeholder)

	# 职业图标暂时没有专属资源，保留职业占位。
	class_icon.texture = null
	class_icon.visible = false
	class_icon_placeholder.visible = true


func _connect_buttons() -> void:
	# 这里先只打印，不打开真实界面。
	if not map_button.pressed.is_connected(_on_map_button_pressed):
		map_button.pressed.connect(_on_map_button_pressed)
	if not deck_button.pressed.is_connected(_on_deck_button_pressed):
		deck_button.pressed.connect(_on_deck_button_pressed)
	if not settings_button.pressed.is_connected(_on_settings_button_pressed):
		settings_button.pressed.connect(_on_settings_button_pressed)


func _apply_compact_battle_layout() -> void:
	var viewport_width: float = get_viewport_rect().size.x
	var left_area: Control = $Background/LeftStatusArea
	var floor_area: Control = $Background/FloorArea
	var right_area: Control = $Background/RightMenuArea

	if left_area != null:
		left_area.position = Vector2(18.0, 9.0)
		left_area.size = Vector2(520.0, 54.0)
	if class_icon_placeholder != null:
		class_icon_placeholder.visible = false
	if class_icon != null:
		class_icon.visible = false
	if class_name_label != null:
		class_name_label.position = Vector2(0.0, 11.0)
		class_name_label.size = Vector2(142.0, 32.0)
		class_name_label.add_theme_font_size_override("font_size", 20)
	if hp_icon_placeholder != null:
		hp_icon_placeholder.position = Vector2(154.0, 9.0)
		hp_icon_placeholder.size = Vector2(34.0, 34.0)
	if hp_icon != null:
		hp_icon.position = Vector2(148.0, 3.0)
		hp_icon.size = Vector2(46.0, 46.0)
	if hp_label != null:
		hp_label.position = Vector2(198.0, 11.0)
		hp_label.size = Vector2(82.0, 32.0)
		hp_label.add_theme_font_size_override("font_size", 20)
	if gold_icon_placeholder != null:
		gold_icon_placeholder.position = Vector2(302.0, 9.0)
		gold_icon_placeholder.size = Vector2(34.0, 34.0)
	if gold_icon != null:
		gold_icon.position = Vector2(296.0, 3.0)
		gold_icon.size = Vector2(46.0, 46.0)
	if gold_label != null:
		gold_label.position = Vector2(346.0, 11.0)
		gold_label.size = Vector2(74.0, 32.0)
		gold_label.add_theme_font_size_override("font_size", 20)

	var potion_slots_node: Control = $Background/LeftStatusArea/PotionSlots
	if potion_slots_node != null:
		potion_slots_node.visible = false

	if floor_area != null:
		floor_area.position = Vector2(viewport_width * 0.5 - 86.0, 9.0)
		floor_area.size = Vector2(172.0, 54.0)
	if floor_icon_placeholder != null:
		floor_icon_placeholder.position = Vector2(0.0, 9.0)
		floor_icon_placeholder.size = Vector2(34.0, 34.0)
	if floor_icon != null:
		floor_icon.position = Vector2(-6.0, 3.0)
		floor_icon.size = Vector2(46.0, 46.0)
	if floor_label != null:
		floor_label.position = Vector2(44.0, 11.0)
		floor_label.size = Vector2(110.0, 32.0)
		floor_label.add_theme_font_size_override("font_size", 22)

	if right_area != null:
		right_area.position = Vector2(maxf(viewport_width - 354.0, 980.0), 8.0)
		right_area.size = Vector2(336.0, 56.0)

	_style_top_button(map_button, map_icon, map_icon_placeholder, Vector2(0.0, 0.0), "地图")
	_style_top_button(deck_button, deck_icon, deck_icon_placeholder, Vector2(94.0, 0.0), "牌库")
	_style_top_button(settings_button, settings_icon, settings_icon_placeholder, Vector2(240.0, 0.0), "设置")
	if deck_count_label != null:
		deck_count_label.position = Vector2(188.0, 12.0)
		deck_count_label.size = Vector2(42.0, 32.0)
		deck_count_label.add_theme_font_size_override("font_size", 20)


func _style_top_button(button: Button, icon: TextureRect, placeholder: ColorRect, button_position: Vector2, button_text: String) -> void:
	if button == null:
		return

	button.position = button_position
	button.size = Vector2(84.0, 56.0)
	button.text = button_text
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_color_override("font_color", Color(0.90, 0.84, 0.72, 0.92))
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.94, 0.78, 1.0))
	button.add_theme_color_override("font_pressed_color", Color(0.80, 0.62, 0.38, 1.0))
	button.add_theme_stylebox_override("normal", _make_top_button_style(Color(0.04, 0.038, 0.045, 0.16), Color(0.62, 0.46, 0.24, 0.25)))
	button.add_theme_stylebox_override("hover", _make_top_button_style(Color(0.12, 0.095, 0.075, 0.30), Color(0.90, 0.65, 0.30, 0.48)))
	button.add_theme_stylebox_override("pressed", _make_top_button_style(Color(0.06, 0.052, 0.05, 0.38), Color(0.82, 0.52, 0.22, 0.58)))
	button.add_theme_stylebox_override("disabled", _make_top_button_style(Color(0.04, 0.04, 0.045, 0.10), Color(0.24, 0.24, 0.24, 0.28)))

	if placeholder != null:
		placeholder.position = Vector2(8.0, 10.0)
		placeholder.size = Vector2(34.0, 34.0)
	if icon != null:
		icon.position = Vector2(2.0, 4.0)
		icon.size = Vector2(46.0, 46.0)


func _make_top_button_style(bg_color: Color, border_color: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 6
	style.content_margin_right = 6
	return style


func _apply_icon(icon_key: String, texture_rect: TextureRect, placeholder: ColorRect) -> void:
	# 给指定图标节点安全加载贴图；失败时显示占位。
	var icon_path: String = str(ICON_PATHS.get(icon_key, ""))
	var icon_texture: Texture2D = _load_texture_or_null(icon_path)
	if icon_texture == null:
		texture_rect.texture = null
		texture_rect.visible = false
		placeholder.visible = true
		return

	texture_rect.texture = icon_texture
	texture_rect.visible = true
	placeholder.visible = false


func _update_potion_slot(slot: Control, potion_data: Variant) -> void:
	# 药水槽只区分空槽和有药水两种状态。
	var fill: ColorRect = slot.get_node("Fill") as ColorRect
	var label: Label = slot.get_node("Label") as Label

	if potion_data == null:
		fill.color = Color(0.08, 0.075, 0.085, 0.85)
		label.text = ""
		return

	fill.color = Color(0.42, 0.13, 0.12, 0.95)
	if potion_data is Dictionary:
		var potion_name: String = str((potion_data as Dictionary).get("name", "药"))
		label.text = potion_name.substr(0, 1)
	else:
		label.text = "药"


func _on_map_button_pressed() -> void:
	# 地图界面后续再接，这里只打印。
	print("打开地图")


func _on_deck_button_pressed() -> void:
	# 牌库界面后续再接，这里只打印。
	print("打开牌库")


func _on_settings_button_pressed() -> void:
	# 设置界面后续再接，这里只打印。
	print("打开设置")


func _load_texture_or_null(texture_path: String) -> Texture2D:
	# 优先使用 Godot 已导入资源；失败时直接读取 PNG，避免刚复制资源时无法显示。
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
