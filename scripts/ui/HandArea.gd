extends Control

# HandArea 只负责展示手牌 UI、拖拽目标判定和出牌动画，不包含战斗结算。

# 卡牌释放到有效区域后通知 BattleScene 做能量、目标和战斗状态校验。
signal card_play_requested(card_data: Dictionary, card_view: Control, target_id: String)

# CardView 场景路径，动态实例化每一张手牌。
const CARD_VIEW_SCENE: PackedScene = preload("res://scenes/ui/CardView.tscn")

# UI 特效播放器脚本，点击或释放攻击牌时用来播放斩击特效。
const VFX_PLAYER_SCRIPT = preload("res://scripts/ui/VfxPlayer.gd")

# 已生成的斩击特效 sprite sheet。
const SLASH_EFFECT_TEXTURE_PATH: String = "res://art/fx/slash_effect_sheet.png"

# CardView 的默认尺寸，需要和 CardView.gd / CardView.tscn 保持一致。
const CARD_SIZE: Vector2 = Vector2(240, 320)

# 手牌区域左右边距，避免卡牌贴到窗口边缘。
const SIDE_MARGIN: float = 24.0

# 手牌距离 HandArea 底部的距离。
const BOTTOM_MARGIN: float = 18.0
const DOCK_HEIGHT: float = 96.0
const PILE_ICON_SIZE: Vector2 = Vector2(42, 42)

# 理想的卡牌中心间距；窗口较窄或卡牌较多时会自动压缩。
const TARGET_CENTER_SPACING: float = 155.0

# 最小显示缩放，保证最多 10 张手牌仍能放进屏幕。
const MIN_CARD_SCALE: float = 0.58

# 扇形最大旋转角度，左侧为负角度，右侧为正角度。
const MAX_FAN_ROTATION: float = 10.0

# 两侧卡牌最大下沉距离，形成轻微弧形。
const MAX_SIDE_SINK: float = 34.0

# 手牌布局变化时的平滑动画时间。
const LAYOUT_TWEEN_TIME: float = 0.22

# 无效释放时回到手牌位置的动画时间。
const RETURN_TWEEN_TIME: float = 0.2

# 有效释放时飞向目标点的动画时间。
const PLAY_TWEEN_TIME: float = 0.25

# 最多展示 12 张手牌，主要用于卡牌 UI 测试和少量抽牌效果验证。
const MAX_HAND_CARDS: int = 12

# UI 测试场景的旧释放高度；BattleScene 中 Attack 会优先使用注册的敌人区域。
const ATTACK_RELEASE_Y: float = 500.0
const NON_ATTACK_RELEASE_Y: float = 700.0

# 不同类型卡牌释放成功后的飞行目标点，使用视口坐标。
const ATTACK_TARGET_GLOBAL: Vector2 = Vector2(960, 300)
const SKILL_TARGET_GLOBAL: Vector2 = Vector2(960, 650)
const POWER_TARGET_GLOBAL: Vector2 = Vector2(960, 520)

# 保存当前手牌数据，方便重新布局和移除已释放卡牌。
var current_cards: Array = []

# 限制手牌最大缩放。默认 1.0，BattleScene 可以调小，避免遮挡角色。
var max_card_scale: float = 1.0

# 布局 Tween 只保留一个，避免重复布局时多个 Tween 互相抢属性。
var layout_tween: Tween

# 当前正在拖拽的卡牌，用于实时更新箭头轨迹。
var dragging_card_view: Control

# 箭头起点，坐标基于 DragArrow 节点。
var drag_arrow_start: Vector2 = Vector2.ZERO

# 正在处理释放结果的卡牌列表，用于防止同一张牌重复释放。
var resolving_card_views: Array = []

# BattleScene 注册的可投放目标。v1 只有一个敌人，但这里保留数组接口。
var drop_targets: Array = []

# 非攻击牌释放到这个 Y 以上视为进入战斗区域。
var battle_area_release_y: float = NON_ATTACK_RELEASE_Y
var dragging_card_data: Dictionary = {}
var draw_pile_count: int = 0
var discard_pile_count: int = 0

# BattleScene 接管出牌结算后打开；普通 UI 测试场景仍走本地演示动画。
var external_play_resolution_enabled: bool = false

@onready var drag_arrow: Control = $DragArrow
@onready var fx_layer: Control = $FxLayer
@onready var cards_layer: Control = $CardsLayer

var dock_texture_rect: TextureRect
var dock_scrim: ColorRect
var draw_pile_icon: TextureRect
var draw_pile_label: Label
var discard_pile_icon: TextureRect
var discard_pile_label: Label
var target_highlight: ColorRect
var invalid_release_label: Label


func _ready() -> void:
	# HandArea 本身不拦截鼠标，让 CardView 根节点处理悬停和拖拽。
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_setup_hand_hud()
	set_process(false)


func _notification(what: int) -> void:
	# 窗口尺寸变化时重新计算底部居中的扇形布局，并用 Tween 平滑过渡。
	if not is_node_ready():
		return

	if what == NOTIFICATION_RESIZED:
		_layout_hand_hud()
		if cards_layer.get_child_count() > 0:
			_layout_cards(true)


func _process(_delta: float) -> void:
	# 拖拽中实时更新箭头终点到鼠标当前位置。
	if dragging_card_view == null:
		return

	_update_drag_arrow(get_viewport().get_mouse_position())


func set_cards(cards: Array) -> void:
	# 接收外部传入的卡牌数据，并根据数组内容重新生成手牌。
	current_cards = cards.duplicate(true)
	if current_cards.size() > MAX_HAND_CARDS:
		current_cards = current_cards.slice(0, MAX_HAND_CARDS)

	_clear_card_views()
	_create_card_views()
	_layout_cards(true)


func set_drop_targets(targets: Array) -> void:
	# 接收 BattleScene 传入的敌人投放区域，使用视口坐标 Rect2 做命中判断。
	drop_targets = targets.duplicate(true)
	external_play_resolution_enabled = not drop_targets.is_empty()
	_update_target_highlight(false)


func set_battle_area_release_y(global_y: float) -> void:
	# Skill / Power 不需要具体目标，只要释放到手牌区上方的战斗区域即可。
	battle_area_release_y = global_y


func set_max_card_scale(new_max_card_scale: float) -> void:
	# 外部场景可以控制手牌最大尺寸，不影响 CardView 自身默认尺寸。
	max_card_scale = clampf(new_max_card_scale, MIN_CARD_SCALE, 1.0)
	_layout_cards(true)


func set_pile_counts(new_draw_pile_count: int, new_discard_pile_count: int) -> void:
	draw_pile_count = maxi(new_draw_pile_count, 0)
	discard_pile_count = maxi(new_discard_pile_count, 0)
	_update_pile_labels()


func set_hand_interaction_enabled(enabled: bool) -> void:
	# 战斗结算、敌人回合或胜负结束时统一启停手牌交互。
	for child in cards_layer.get_children():
		var card_view: Control = child as Control
		if card_view != null and card_view.has_method("set_interaction_enabled"):
			card_view.call("set_interaction_enabled", enabled)


func reject_card(card_view: Control) -> void:
	# BattleScene 校验失败时调用，让卡牌回到原始手牌位置。
	if not is_instance_valid(card_view):
		return

	_return_card_to_hand(card_view)


func confirm_card_play(card_data: Dictionary, card_view: Control, target_global_position: Vector2) -> void:
	# BattleScene 校验成功后调用，HandArea 只负责出牌飞行动画和移除 UI。
	if not is_instance_valid(card_view):
		return

	_play_card(card_data, card_view, target_global_position)


func _clear_card_views() -> void:
	# 停止旧布局动画，避免旧 CardView 释放后 Tween 仍尝试操作它们。
	if layout_tween != null and layout_tween.is_valid():
		layout_tween.kill()
		layout_tween = null

	resolving_card_views.clear()
	dragging_card_view = null
	dragging_card_data.clear()
	_hide_drag_arrow()
	_update_target_highlight(false)

	# 清理旧的 CardView，避免重复调用 set_cards() 时残留旧手牌。
	for child in cards_layer.get_children():
		cards_layer.remove_child(child)
		child.queue_free()


func _create_card_views() -> void:
	# 只创建 CardView 实例和填充数据，具体扇形位置统一交给 _layout_cards()。
	for index in range(current_cards.size()):
		var card_view: Control = CARD_VIEW_SCENE.instantiate() as Control
		card_view.name = "CardView%d" % (index + 1)
		card_view.position = Vector2(size.x * 0.5 - CARD_SIZE.x * 0.5, size.y)
		card_view.rotation_degrees = 0.0
		card_view.scale = Vector2.ONE
		card_view.z_index = index

		cards_layer.add_child(card_view)

		# 只调用 CardView 的 setup() 填充数据，不加入任何抽牌或战斗行为。
		if card_view.has_method("setup"):
			card_view.call("setup", current_cards[index])

		# 接收 CardView 的拖拽和释放信号。
		if card_view.has_signal("card_drag_started"):
			card_view.connect("card_drag_started", Callable(self, "_on_card_drag_started"))
		if card_view.has_signal("card_released"):
			card_view.connect("card_released", Callable(self, "_on_card_released"))
		if card_view.has_signal("card_clicked"):
			card_view.connect("card_clicked", Callable(self, "_on_card_clicked"))


func _layout_cards(animated: bool) -> void:
	# 没有卡牌时不需要布局。
	var card_count: int = cards_layer.get_child_count()
	if card_count == 0:
		return

	if layout_tween != null and layout_tween.is_valid():
		layout_tween.kill()
		layout_tween = null

	if animated:
		layout_tween = create_tween()
		layout_tween.set_parallel(true)
		layout_tween.set_trans(Tween.TRANS_QUAD)
		layout_tween.set_ease(Tween.EASE_OUT)

	var card_scale: float = _get_card_scale(card_count)
	var displayed_card_size: Vector2 = CARD_SIZE * card_scale
	var center_spacing: float = _get_center_spacing(card_count, displayed_card_size.x, card_scale)
	var middle_index: float = float(card_count - 1) * 0.5
	var total_center_span: float = center_spacing * float(card_count - 1)
	var first_center_x: float = size.x * 0.5 - total_center_span * 0.5
	var max_sink: float = MAX_SIDE_SINK * card_scale
	var base_y: float = size.y - displayed_card_size.y - BOTTOM_MARGIN - max_sink - 18.0

	for index in range(card_count):
		var card_view: Control = cards_layer.get_child(index) as Control
		var normalized: float = _get_normalized_hand_offset(index, middle_index)
		var side_sink: float = absf(normalized) * MAX_SIDE_SINK * card_scale
		var target_center_x: float = first_center_x + center_spacing * float(index)
		var target_position: Vector2 = Vector2(target_center_x - displayed_card_size.x * 0.5, base_y + side_sink)
		var target_scale: Vector2 = Vector2(card_scale, card_scale)
		var target_rotation: float = normalized * MAX_FAN_ROTATION
		var target_z_index: int = index

		# 先更新 CardView 的“静止布局”，这样悬停结束时会回到新的扇形位置。
		if card_view.has_method("set_rest_transform"):
			card_view.call("set_rest_transform", target_position, target_scale, target_rotation, target_z_index)

		# 正在拖拽、悬停或处理释放结果的卡牌不被布局 Tween 抢属性。
		if _is_card_hovered(card_view) or _is_card_resolving(card_view):
			continue

		if animated and layout_tween != null:
			layout_tween.tween_property(card_view, "position", target_position, LAYOUT_TWEEN_TIME)
			layout_tween.tween_property(card_view, "scale", target_scale, LAYOUT_TWEEN_TIME)
			layout_tween.tween_property(card_view, "rotation_degrees", target_rotation, LAYOUT_TWEEN_TIME)
			card_view.z_index = target_z_index
		else:
			card_view.position = target_position
			card_view.scale = target_scale
			card_view.rotation_degrees = target_rotation
			card_view.z_index = target_z_index


func _on_card_drag_started(_card_data: Dictionary, card_view: Control, drag_start_global_position: Vector2) -> void:
	# 拖拽开始时显示箭头，箭头起点使用卡牌原始手牌位置附近。
	if _is_card_resolving(card_view):
		return

	dragging_card_view = card_view
	dragging_card_data = _card_data.duplicate(true)
	drag_arrow_start = _global_to_arrow_local(drag_start_global_position)
	drag_arrow.visible = true
	set_process(true)
	_update_drag_arrow(get_viewport().get_mouse_position())


func _on_card_released(card_data: Dictionary, card_view: Control, release_global_position: Vector2) -> void:
	# 释放时隐藏箭头，由 HandArea 判断目标区域；战斗结算交给 BattleScene。
	if _is_card_resolving(card_view):
		return

	dragging_card_view = null
	dragging_card_data.clear()
	_hide_drag_arrow()
	_update_target_highlight(false)

	if not external_play_resolution_enabled:
		if _is_demo_valid_release(card_data, release_global_position):
			_play_card(card_data, card_view, _get_play_target_global_position(card_data))
		else:
			_return_card_to_hand(card_view)
		return

	var target_id: String = _get_release_target_id(card_data, release_global_position)
	if target_id.is_empty():
		_show_invalid_release_hint()
		_return_card_to_hand(card_view)
		return

	_mark_card_resolving(card_view, true)
	if card_view.has_method("set_interaction_enabled"):
		card_view.call("set_interaction_enabled", false)
	card_play_requested.emit(card_data, card_view, target_id)


func _return_card_to_hand(card_view: Control) -> void:
	# 无效释放时 0.2 秒内回到原始手牌位置、角度和缩放。
	_mark_card_resolving(card_view, true)
	if card_view.has_method("set_interaction_enabled"):
		card_view.call("set_interaction_enabled", false)

	var target_position: Vector2 = card_view.call("get_rest_position")
	var target_scale: Vector2 = card_view.call("get_rest_scale")
	var target_rotation: float = float(card_view.call("get_rest_rotation_degrees"))
	var target_z_index: int = int(card_view.call("get_rest_z_index"))
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	card_view.modulate = Color(1.0, 0.64, 0.58, 1.0)
	tween.tween_property(card_view, "position", target_position, RETURN_TWEEN_TIME)
	tween.tween_property(card_view, "scale", target_scale, RETURN_TWEEN_TIME)
	tween.tween_property(card_view, "rotation_degrees", target_rotation, RETURN_TWEEN_TIME)
	tween.tween_property(card_view, "modulate", Color(1, 1, 1, 1), RETURN_TWEEN_TIME)
	tween.chain().tween_callback(Callable(self, "_finish_return_to_hand").bind(card_view, target_z_index))


func _finish_return_to_hand(card_view: Control, target_z_index: int) -> void:
	# 回手牌动画结束后恢复交互和层级。
	if not is_instance_valid(card_view):
		return

	card_view.z_index = target_z_index
	if card_view.has_method("set_interaction_enabled"):
		card_view.call("set_interaction_enabled", true)

	_mark_card_resolving(card_view, false)


func _play_card(card_data: Dictionary, card_view: Control, target_global_position: Vector2) -> void:
	# 有效释放时飞向对应目标点，缩小并淡出，完成后移除并重新布局。
	_mark_card_resolving(card_view, true)
	if card_view.has_method("set_interaction_enabled"):
		card_view.call("set_interaction_enabled", false)

	if _is_attack_card(card_data):
		_play_slash_effect(target_global_position)

	var target_local_position: Vector2 = _global_to_cards_layer_local(target_global_position) - CARD_SIZE * 0.5
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(card_view, "position", target_local_position, PLAY_TWEEN_TIME)
	tween.tween_property(card_view, "scale", Vector2(0.35, 0.35), PLAY_TWEEN_TIME)
	tween.tween_property(card_view, "rotation_degrees", 0.0, PLAY_TWEEN_TIME)
	tween.tween_property(card_view, "modulate", Color(1, 1, 1, 0), PLAY_TWEEN_TIME)
	tween.chain().tween_callback(Callable(self, "_finish_play_card").bind(card_view))


func _finish_play_card(card_view: Control) -> void:
	# 出牌动画结束后移除卡牌数据和节点，再重新布局剩余手牌。
	if not is_instance_valid(card_view):
		return

	var card_index: int = card_view.get_index()
	if card_index >= 0 and card_index < current_cards.size():
		current_cards.remove_at(card_index)

	_mark_card_resolving(card_view, false)
	cards_layer.remove_child(card_view)
	card_view.queue_free()
	_layout_cards(true)


func _get_release_target_id(card_data: Dictionary, release_global_position: Vector2) -> String:
	# Attack 必须释放到敌人区域；Skill / Power 只要求释放到战斗区域。
	var card_type: String = str(card_data.get("type", "Skill"))
	if card_type == "Attack":
		for target in drop_targets:
			if not (target is Dictionary):
				continue
			if str(target.get("type", "")) != "enemy":
				continue
			var target_rect: Rect2 = target.get("global_rect", Rect2())
			if target_rect.has_point(release_global_position):
				return str(target.get("id", ""))
		return ""

	if release_global_position.y < battle_area_release_y:
		return "self"

	return ""


func _is_demo_valid_release(card_data: Dictionary, release_global_position: Vector2) -> bool:
	# 没有 BattleScene 接管时保留旧 UI demo 的高度判定。
	var card_type: String = str(card_data.get("type", "Skill"))
	if card_type == "Attack":
		return release_global_position.y < ATTACK_RELEASE_Y

	return release_global_position.y < NON_ATTACK_RELEASE_Y


func _get_play_target_global_position(card_data: Dictionary) -> Vector2:
	# 按卡牌类型返回释放成功后的飞行目标点。
	var card_type: String = str(card_data.get("type", "Skill"))
	if card_type == "Attack":
		return ATTACK_TARGET_GLOBAL
	if card_type == "Power":
		return POWER_TARGET_GLOBAL

	return SKILL_TARGET_GLOBAL


func _update_drag_arrow(mouse_global_position: Vector2) -> void:
	# 将全局鼠标坐标转换到箭头节点坐标系后更新绘制。
	if drag_arrow == null:
		return

	var arrow_end: Vector2 = _global_to_arrow_local(mouse_global_position)
	drag_arrow.call("set_points", drag_arrow_start, arrow_end)
	_update_target_highlight(_is_attack_card(dragging_card_data), mouse_global_position)


func _hide_drag_arrow() -> void:
	# 松开鼠标或清理手牌时隐藏箭头。
	set_process(false)
	if drag_arrow != null:
		drag_arrow.visible = false
	_update_target_highlight(false)


func _setup_hand_hud() -> void:
	dock_scrim = ColorRect.new()
	dock_scrim.name = "DockScrim"
	dock_scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dock_scrim.z_index = -30
	add_child(dock_scrim)

	dock_texture_rect = TextureRect.new()
	dock_texture_rect.name = "HandDockTexture"
	dock_texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dock_texture_rect.z_index = -20
	dock_texture_rect.stretch_mode = TextureRect.STRETCH_SCALE
	dock_texture_rect.texture = null
	dock_texture_rect.visible = false
	add_child(dock_texture_rect)

	draw_pile_icon = _make_pile_icon("DrawPileIcon", "")
	draw_pile_label = _make_pile_label("DrawPileLabel")
	discard_pile_icon = _make_pile_icon("DiscardPileIcon", "")
	discard_pile_label = _make_pile_label("DiscardPileLabel")

	target_highlight = ColorRect.new()
	target_highlight.name = "TargetHighlight"
	target_highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	target_highlight.color = Color(0.98, 0.12, 0.08, 0.18)
	target_highlight.visible = false
	target_highlight.z_index = 4
	add_child(target_highlight)

	invalid_release_label = Label.new()
	invalid_release_label.name = "InvalidReleaseLabel"
	invalid_release_label.size = Vector2(180, 34)
	invalid_release_label.text = "目标无效"
	invalid_release_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	invalid_release_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	invalid_release_label.add_theme_font_size_override("font_size", 20)
	invalid_release_label.add_theme_color_override("font_color", Color(1.0, 0.42, 0.36, 1.0))
	invalid_release_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
	invalid_release_label.add_theme_constant_override("shadow_offset_x", 2)
	invalid_release_label.add_theme_constant_override("shadow_offset_y", 2)
	invalid_release_label.visible = false
	invalid_release_label.z_index = 80
	add_child(invalid_release_label)

	_layout_hand_hud()
	_update_pile_labels()


func _make_pile_icon(node_name: String, texture_path: String) -> TextureRect:
	var icon: TextureRect = TextureRect.new()
	icon.name = node_name
	icon.size = PILE_ICON_SIZE
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.z_index = 2
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = _load_texture_or_null(texture_path)
	icon.visible = false
	add_child(icon)
	return icon


func _make_pile_label(node_name: String) -> Label:
	var label: Label = Label.new()
	label.name = node_name
	label.size = Vector2(86, 30)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.z_index = 3
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(0.88, 0.84, 0.76, 0.92))
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.95))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	add_child(label)
	return label


func _layout_hand_hud() -> void:
	if dock_scrim != null:
		dock_scrim.position = Vector2(0.0, maxf(size.y - DOCK_HEIGHT, 0.0))
		dock_scrim.size = Vector2(size.x, DOCK_HEIGHT)
		dock_scrim.color = Color(0.025, 0.022, 0.025, 0.34)

	if dock_texture_rect != null:
		dock_texture_rect.visible = false

	var pile_y: float = maxf(size.y - 42.0, 0.0)
	if draw_pile_icon != null:
		draw_pile_icon.position = Vector2(230.0, pile_y)
	if draw_pile_label != null:
		draw_pile_label.position = Vector2(250.0, pile_y)
	if discard_pile_icon != null:
		discard_pile_icon.position = Vector2(maxf(size.x - 310.0, 230.0), pile_y)
	if discard_pile_label != null:
		discard_pile_label.position = Vector2(maxf(size.x - 336.0, 250.0), pile_y)


func _update_pile_labels() -> void:
	if draw_pile_label != null:
		draw_pile_label.text = "抽 %d" % draw_pile_count
	if discard_pile_label != null:
		discard_pile_label.text = "弃 %d" % discard_pile_count


func _update_target_highlight(should_show: bool, mouse_global_position: Vector2 = Vector2.ZERO) -> void:
	if target_highlight == null:
		return

	if not should_show or drop_targets.is_empty():
		target_highlight.visible = false
		return

	for target in drop_targets:
		if not (target is Dictionary):
			continue
		if str(target.get("type", "")) != "enemy":
			continue
		var target_rect: Rect2 = target.get("global_rect", Rect2())
		var local_top_left: Vector2 = _global_to_local_position(target_rect.position)
		var local_bottom_right: Vector2 = _global_to_local_position(target_rect.position + target_rect.size)
		target_highlight.position = local_top_left
		target_highlight.size = local_bottom_right - local_top_left
		var highlight_alpha: float = 0.26 if target_rect.has_point(mouse_global_position) else 0.14
		target_highlight.color = Color(1.0, 0.08, 0.04, highlight_alpha)
		target_highlight.visible = true
		return

	target_highlight.visible = false


func _show_invalid_release_hint() -> void:
	if invalid_release_label == null:
		return

	var mouse_position: Vector2 = _global_to_local_position(get_viewport().get_mouse_position())
	invalid_release_label.position = mouse_position + Vector2(-90.0, -58.0)
	invalid_release_label.modulate = Color(1, 1, 1, 1)
	invalid_release_label.visible = true

	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(invalid_release_label, "position", invalid_release_label.position + Vector2(0.0, -22.0), 0.28)
	tween.parallel().tween_property(invalid_release_label, "modulate", Color(1, 1, 1, 0), 0.28)
	tween.chain().tween_callback(Callable(self, "_hide_invalid_release_hint"))


func _hide_invalid_release_hint() -> void:
	if invalid_release_label != null:
		invalid_release_label.visible = false


func _global_to_local_position(global_position: Vector2) -> Vector2:
	return get_global_transform_with_canvas().affine_inverse() * global_position


func _global_to_arrow_local(global_position: Vector2) -> Vector2:
	# 将视口坐标转换为 DragArrow 的本地坐标。
	return drag_arrow.get_global_transform_with_canvas().affine_inverse() * global_position


func _global_to_cards_layer_local(global_position: Vector2) -> Vector2:
	# 将视口坐标转换为 CardsLayer 的本地坐标。
	return cards_layer.get_global_transform_with_canvas().affine_inverse() * global_position


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


func _get_card_scale(card_count: int) -> float:
	# 根据卡牌数量和 HandArea 宽度计算缩放，支持 1 到 10 张牌。
	var available_width: float = maxf(size.x - SIDE_MARGIN * 2.0, CARD_SIZE.x)
	var desired_width: float = CARD_SIZE.x + TARGET_CENTER_SPACING * float(maxi(card_count - 1, 0))
	var scale_by_width: float = available_width / desired_width
	return clampf(scale_by_width, MIN_CARD_SCALE, max_card_scale)


func _get_center_spacing(card_count: int, displayed_card_width: float, card_scale: float) -> float:
	# 1 张牌不需要间距；多张牌根据宽度压缩，必要时允许轻微重叠。
	if card_count <= 1:
		return 0.0

	var available_width: float = maxf(size.x - SIDE_MARGIN * 2.0, displayed_card_width)
	var fit_spacing: float = maxf((available_width - displayed_card_width) / float(card_count - 1), 0.0)
	var desired_spacing: float = TARGET_CENTER_SPACING * card_scale
	return minf(desired_spacing, fit_spacing)


func _get_normalized_hand_offset(index: int, middle_index: float) -> float:
	# 返回 -1 到 1 的手牌相对位置，中间牌接近 0。
	if middle_index <= 0.0:
		return 0.0

	return (float(index) - middle_index) / middle_index


func _is_card_hovered(card_view: Control) -> bool:
	# 查询 CardView 是否处于悬停或拖拽状态，避免布局 Tween 覆盖交互动画。
	if card_view.has_method("is_card_hovered"):
		return bool(card_view.call("is_card_hovered"))

	return false


func _is_card_resolving(card_view: Control) -> bool:
	# 判断卡牌是否正在处理释放结果，防止同一张卡牌重复释放。
	return resolving_card_views.has(card_view)


func _mark_card_resolving(card_view: Control, resolving: bool) -> void:
	# 维护释放处理列表。
	if resolving:
		if not resolving_card_views.has(card_view):
			resolving_card_views.append(card_view)
	else:
		resolving_card_views.erase(card_view)


func _on_card_clicked(card_data: Dictionary, _card_view: Control) -> void:
	# 保留点击信号处理；当前拖拽出牌流程不依赖它。
	var card_name: String = str(card_data.get("name", "未命名"))
	print("已选择卡牌：%s" % card_name)

	if _is_attack_card(card_data):
		_play_slash_effect(ATTACK_TARGET_GLOBAL)


func _is_attack_card(card_data: Dictionary) -> bool:
	# 当前只给 Attack 类型卡牌接入斩击特效。
	return str(card_data.get("type", "Skill")) == "Attack"


func _play_slash_effect(global_position: Vector2) -> void:
	# 在独立 FX 层播放斩击，不影响手牌布局和拖拽逻辑。
	if fx_layer == null:
		return

	var vfx_player: Control = VFX_PLAYER_SCRIPT.play_at(fx_layer, global_position, SLASH_EFFECT_TEXTURE_PATH)
	if vfx_player != null:
		vfx_player.z_index = 60
