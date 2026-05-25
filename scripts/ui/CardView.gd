extends Control

# 点击卡牌时发出信号，把当前卡牌数据和 CardView 自身一起传给上层。
signal card_clicked(card_data: Dictionary, card_view: Control)

# 开始拖拽卡牌时发出信号，HandArea 用它显示箭头轨迹。
signal card_drag_started(card_data: Dictionary, card_view: Control, drag_start_global_position: Vector2)

# 松开卡牌时发出信号，HandArea 用它判断是否出牌。
signal card_released(card_data: Dictionary, card_view: Control, release_global_position: Vector2)

# 卡牌 UI 的默认尺寸，供场景初始化和运行时兜底使用。
const CARD_SIZE := Vector2(240, 320)

# 鼠标悬停时的移动、缩放和动画时间。
const HOVER_OFFSET := Vector2(0, -60)
const HOVER_SCALE := Vector2(1.15, 1.15)
const HOVER_Z_INDEX := 100
const DRAG_Z_INDEX := 200
const HOVER_TWEEN_TIME := 0.16
const HOVER_KEEP_PADDING := 8.0
const DRAG_SCALE := Vector2(1.15, 1.15)
const DRAG_LERP_SPEED := 22.0
const CLICK_DRAG_THRESHOLD := 10.0

# 常用稀有度颜色，用纯色背景区分不同卡牌品质。
const RARITY_COLORS := {
	"Common": Color(0.16, 0.14, 0.12, 1.0),
	"Uncommon": Color(0.12, 0.18, 0.15, 1.0),
	"Rare": Color(0.18, 0.13, 0.08, 1.0)
}

# 卡牌类型到默认卡框资源的映射；自定义 frame_path 会优先于这里的默认资源。
const CARD_TYPE_FRAME_PATHS := {
	"Attack": "res://art/ui/card_frame_attack.png",
	"Skill": "res://art/ui/card_frame_skill.png",
	"Power": "res://art/ui/card_frame_power.png"
}

const CARD_HOVER_SFX_PATH := "res://art/audio/card_hover_freesound.wav"

# 通过节点路径缓存控件引用，避免每次刷新时重复查找。
@onready var background: ColorRect = $Background
@onready var frame_texture: TextureRect = $FrameTexture
@onready var cost_label: Label = $CostLabel
@onready var name_label: Label = $NameLabel
@onready var art_placeholder: ColorRect = $ArtPlaceholder
@onready var art_texture: TextureRect = $ArtTexture
@onready var type_label: Label = $TypeLabel
@onready var description_label: Label = $DescriptionLabel

# 记录卡牌进入悬停前的原始状态，鼠标离开时恢复。
var original_position := Vector2.ZERO
var original_scale := Vector2.ONE
var original_rotation_degrees := 0.0
var original_z_index := 0

# 只保留一个 Tween，快速进出时先停止旧动画，避免多个 Tween 叠加抖动。
var hover_tween: Tween
var is_hovered := false

# 保存 setup() 传入的卡牌数据，点击时通过 signal 发给 HandArea。
var current_card_data: Dictionary = {}

# 拖拽状态只负责显示和释放信号，不判断是否出牌。
var is_dragging := false
var drag_mouse_offset := Vector2.ZERO
var drag_target_position := Vector2.ZERO
var drag_start_global_position := Vector2.ZERO
var interaction_enabled := true
var hover_audio_player: AudioStreamPlayer


func _ready() -> void:
	# 进入场景树时保证卡牌控件有固定的演示尺寸。
	custom_minimum_size = CARD_SIZE
	size = CARD_SIZE
	pivot_offset = CARD_SIZE * 0.5
	_set_child_mouse_filter_ignore(self)
	_apply_text_styles()
	_setup_hover_audio()

	# 缓存初始变换，支持卡牌在测试场景里预先摆放、缩放或旋转。
	original_position = position
	original_scale = scale
	original_rotation_degrees = rotation_degrees
	original_z_index = z_index

	# 接收鼠标事件，并用代码连接信号，避免依赖场景编辑器里的外部连接。
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process(false)
	set_process_input(true)
	mouse_entered.connect(_on_mouse_entered)


func _process(_delta: float) -> void:
	if is_dragging:
		_update_drag_position(_delta)
		return

	# 卡牌悬停后自身会移动，如果直接依赖 mouse_exited，鼠标可能瞬间离开移动后的矩形导致回弹。
	# 这里使用“原始位置矩形 + 悬停位置矩形”的合并区域，让悬停判定稳定。
	if not is_hovered:
		return

	if not _get_hover_keep_rect().has_point(_get_mouse_position_in_parent()):
		_end_hover()


func _gui_input(event: InputEvent) -> void:
	# 左键按下后进入拖拽状态；CardView 不判断释放是否有效。
	if not interaction_enabled:
		return

	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			_begin_drag()
			accept_event()


func _input(event: InputEvent) -> void:
	# 拖拽时即使鼠标离开卡牌，也要能收到全局松开事件。
	if not is_dragging:
		return

	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and not mouse_event.pressed:
			var viewport: Viewport = get_viewport()
			_release_drag()
			if viewport != null:
				viewport.set_input_as_handled()


func setup(card_data: Dictionary) -> void:
	# 保存一份卡牌数据，点击卡牌时原样传出。
	current_card_data = card_data.duplicate(true)

	# 从字典读取基础字段；缺失字段使用安全默认值，避免测试数据不完整时报错。
	var card_name := str(card_data.get("name", "未命名"))
	var card_cost := str(card_data.get("cost", ""))
	var card_type := str(card_data.get("type", "Skill"))
	var card_rarity := str(card_data.get("rarity", "Common"))
	var card_description := str(card_data.get("description", ""))
	var art_path := str(card_data.get("art_path", ""))
	var frame_path := str(card_data.get("frame_path", ""))

	# 文本区域只展示 UI Demo 所需信息，不处理任何战斗效果。
	name_label.text = card_name
	cost_label.text = card_cost
	type_label.text = _get_type_label(card_type)
	description_label.text = card_description

	# 没有背景图时使用稀有度纯色作为卡牌背景。
	background.color = RARITY_COLORS.get(card_rarity, RARITY_COLORS["Common"])

	# 尝试加载卡框贴图；frame_path 不为空时优先使用，否则按卡牌类型选择默认卡框。
	var resolved_frame_path := _get_frame_path(card_type, frame_path)
	var frame := _load_texture_or_null(resolved_frame_path)
	if frame != null:
		frame_texture.texture = frame
		frame_texture.visible = true
	else:
		frame_texture.texture = null
		frame_texture.visible = false

	# 尝试加载插画贴图；路径为空或资源不存在时显示纯色插画占位。
	var art := _load_texture_or_null(art_path)
	if art != null:
		art_texture.texture = art
		art_texture.visible = true
		art_placeholder.visible = false
	else:
		art_texture.texture = null
		art_texture.visible = false
		art_placeholder.visible = true
		art_placeholder.color = Color(0.22, 0.2, 0.18, 1.0)


func _on_mouse_entered() -> void:
	# 已经处于悬停状态时不重复创建 Tween。
	if is_hovered or is_dragging or not interaction_enabled:
		return

	is_hovered = true
	set_process(true)
	z_index = HOVER_Z_INDEX
	_play_hover_sfx()
	_play_hover_tween(original_position + HOVER_OFFSET, _get_hover_scale(), 0.0, false)


func set_rest_transform(rest_position: Vector2, rest_scale: Vector2, rest_rotation_degrees: float, rest_z_index: int) -> void:
	# HandArea 每次重新布局时调用这里，更新悬停结束后要回到的扇形位置。
	original_position = rest_position
	original_scale = rest_scale
	original_rotation_degrees = rest_rotation_degrees
	original_z_index = rest_z_index

	if not is_hovered:
		z_index = original_z_index


func is_card_hovered() -> bool:
	# 给 HandArea 查询当前卡牌是否正在悬停或拖拽，避免布局动画覆盖交互动画。
	return is_hovered or is_dragging


func set_interaction_enabled(enabled: bool) -> void:
	# HandArea 处理释放结果期间可临时关闭交互，避免同一张牌重复释放。
	interaction_enabled = enabled
	mouse_filter = Control.MOUSE_FILTER_STOP if interaction_enabled else Control.MOUSE_FILTER_IGNORE


func get_rest_position() -> Vector2:
	# 返回 HandArea 布局记录的静止位置。
	return original_position


func get_rest_scale() -> Vector2:
	# 返回 HandArea 布局记录的静止缩放。
	return original_scale


func get_rest_rotation_degrees() -> float:
	# 返回 HandArea 布局记录的静止旋转角。
	return original_rotation_degrees


func get_rest_z_index() -> int:
	# 返回 HandArea 布局记录的静止层级。
	return original_z_index


func get_rest_center_global_position() -> Vector2:
	# 返回手牌原始位置附近的中心点，HandArea 用它作为箭头起点。
	var parent_canvas_item := get_parent() as CanvasItem
	var rest_center: Vector2 = original_position + CARD_SIZE * 0.5
	if parent_canvas_item == null:
		return rest_center

	return parent_canvas_item.get_global_transform_with_canvas() * rest_center


func _end_hover() -> void:
	# 已经离开悬停状态时不重复创建 Tween。
	if not is_hovered:
		return

	is_hovered = false
	set_process(false)
	_play_hover_tween(original_position, original_scale, original_rotation_degrees, true)


func _begin_drag() -> void:
	# 进入拖拽状态，停止悬停动画并让卡牌保持放大、回正和最高层级。
	if is_dragging:
		return

	if hover_tween != null and hover_tween.is_valid():
		hover_tween.kill()
		hover_tween = null

	is_dragging = true
	is_hovered = false
	set_process(true)
	z_index = DRAG_Z_INDEX
	drag_start_global_position = get_viewport().get_mouse_position()
	drag_mouse_offset = position - _get_mouse_position_in_parent()
	drag_target_position = position

	_play_drag_begin_tween()
	card_drag_started.emit(current_card_data, self, get_rest_center_global_position())


func _update_drag_position(delta: float) -> void:
	# 拖拽中用轻微平滑跟随鼠标，避免位置抖动。
	drag_target_position = _get_mouse_position_in_parent() + drag_mouse_offset
	var weight: float = clampf(delta * DRAG_LERP_SPEED, 0.0, 1.0)
	position = position.lerp(drag_target_position, weight)
	scale = DRAG_SCALE
	rotation_degrees = 0.0
	z_index = DRAG_Z_INDEX


func _release_drag() -> void:
	# 松开鼠标时只发信号，不在 CardView 内判断是否出牌。
	if not is_dragging:
		return

	if hover_tween != null and hover_tween.is_valid():
		hover_tween.kill()
		hover_tween = null

	var viewport: Viewport = get_viewport()
	if viewport == null:
		is_dragging = false
		set_process(false)
		return

	var release_global_position: Vector2 = viewport.get_mouse_position()
	var is_click: bool = drag_start_global_position.distance_to(release_global_position) <= CLICK_DRAG_THRESHOLD
	is_dragging = false
	set_process(false)

	if is_click:
		card_clicked.emit(current_card_data, self)
		if not is_inside_tree():
			return

	card_released.emit(current_card_data, self, release_global_position)


func _play_drag_begin_tween() -> void:
	# 拖拽开始只动画缩放和旋转，位置交给鼠标跟随逻辑，避免互相抢位置。
	hover_tween = create_tween()
	hover_tween.set_parallel(true)
	hover_tween.set_trans(Tween.TRANS_QUAD)
	hover_tween.set_ease(Tween.EASE_OUT)
	hover_tween.tween_property(self, "scale", DRAG_SCALE, 0.08)
	hover_tween.tween_property(self, "rotation_degrees", 0.0, 0.08)


func _play_hover_tween(target_position: Vector2, target_scale: Vector2, target_rotation_degrees: float, restore_z_index: bool) -> void:
	# 停止上一个悬停动画，保证任何时刻只有一个 Tween 在控制卡牌变换。
	if hover_tween != null and hover_tween.is_valid():
		hover_tween.kill()
		hover_tween = null

	# 使用并行动画，让位置、缩放和角度同时变化。
	hover_tween = create_tween()
	hover_tween.set_parallel(true)
	hover_tween.set_trans(Tween.TRANS_QUAD)
	hover_tween.set_ease(Tween.EASE_OUT)
	hover_tween.tween_property(self, "position", target_position, HOVER_TWEEN_TIME)
	hover_tween.tween_property(self, "scale", target_scale, HOVER_TWEEN_TIME)
	hover_tween.tween_property(self, "rotation_degrees", target_rotation_degrees, HOVER_TWEEN_TIME)

	# 离开卡牌时等回落动画完成后恢复层级，避免动画途中被其他卡牌遮挡。
	if restore_z_index:
		hover_tween.chain().tween_callback(Callable(self, "_restore_z_index"))


func _get_hover_scale() -> Vector2:
	# 基于原始缩放计算悬停缩放，避免卡牌初始 scale 不是 1 时无法正确恢复。
	return Vector2(original_scale.x * HOVER_SCALE.x, original_scale.y * HOVER_SCALE.y)


func _get_hover_keep_rect() -> Rect2:
	# 合并原始区域和悬停后的可见区域，避免卡牌上移时鼠标短暂落在两者之间导致抖动。
	var original_rect := _get_visual_rect(original_position, original_scale)
	var hover_rect := _get_visual_rect(original_position + HOVER_OFFSET, _get_hover_scale())
	return original_rect.merge(hover_rect).grow(HOVER_KEEP_PADDING)


func _get_visual_rect(target_position: Vector2, target_scale: Vector2) -> Rect2:
	# Control 以 pivot_offset 为中心缩放时，可见左上角会随缩放发生偏移。
	var visual_position := target_position + Vector2(
		pivot_offset.x * (1.0 - target_scale.x),
		pivot_offset.y * (1.0 - target_scale.y)
	)
	var visual_size := Vector2(CARD_SIZE.x * target_scale.x, CARD_SIZE.y * target_scale.y)
	return Rect2(visual_position, visual_size).abs()


func _get_mouse_position_in_parent() -> Vector2:
	# 将鼠标坐标转换到卡牌父节点坐标系，和 original_position 使用同一个空间做判断。
	var parent_canvas_item := get_parent() as CanvasItem
	if parent_canvas_item == null:
		return get_global_mouse_position()

	return parent_canvas_item.get_global_transform_with_canvas().affine_inverse() * get_viewport().get_mouse_position()


func _restore_z_index() -> void:
	# 如果回落过程中鼠标又进入卡牌，不恢复层级，避免覆盖新的悬停状态。
	if is_hovered:
		return

	z_index = original_z_index


func _set_child_mouse_filter_ignore(node: Node) -> void:
	# 所有子控件都忽略鼠标，避免插画、文字或卡框挡住 CardView 根节点的悬停/点击。
	for child in node.get_children():
		if child != self and child is Control:
			var child_control: Control = child as Control
			child_control.mouse_filter = Control.MOUSE_FILTER_IGNORE

		_set_child_mouse_filter_ignore(child)


func _get_frame_path(card_type: String, frame_path: String) -> String:
	# 数据里显式提供卡框路径时优先使用，方便单张卡牌覆盖默认样式。
	if not frame_path.is_empty():
		return frame_path

	# 没有显式卡框时，根据卡牌类型选择默认卡框；未知类型返回空路径。
	return CARD_TYPE_FRAME_PATHS.get(card_type, "")


func _get_type_label(card_type: String) -> String:
	match card_type:
		"Attack":
			return "攻击"
		"Skill":
			return "技能"
		"Power":
			return "能力"
	return card_type


func _apply_text_styles() -> void:
	var title_font: SystemFont = SystemFont.new()
	title_font.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei", "SimHei", "Arial"])
	var body_font: SystemFont = SystemFont.new()
	body_font.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei", "SimSun", "Arial"])

	for label in [cost_label, name_label, type_label]:
		if label == null:
			continue
		label.add_theme_font_override("font", title_font)
		label.add_theme_color_override("font_outline_color", Color(0.03, 0.018, 0.012, 0.95))
		label.add_theme_constant_override("outline_size", 1)

	if description_label != null:
		description_label.add_theme_font_override("font", body_font)
		description_label.add_theme_color_override("font_color", Color(0.09, 0.055, 0.035, 1))
		description_label.add_theme_color_override("font_shadow_color", Color(1, 0.86, 0.58, 0.35))
		description_label.add_theme_constant_override("shadow_offset_x", 0)
		description_label.add_theme_constant_override("shadow_offset_y", 1)


func _setup_hover_audio() -> void:
	var hover_stream: AudioStream = _load_audio_stream_or_null(CARD_HOVER_SFX_PATH)
	if hover_stream == null:
		return

	hover_audio_player = AudioStreamPlayer.new()
	hover_audio_player.name = "HoverAudioPlayer"
	hover_audio_player.stream = hover_stream
	hover_audio_player.volume_db = -8.0
	add_child(hover_audio_player)


func _play_hover_sfx() -> void:
	if hover_audio_player == null:
		return

	hover_audio_player.stop()
	hover_audio_player.play()


func _load_audio_stream_or_null(path: String) -> AudioStream:
	if path.is_empty():
		return null

	if ResourceLoader.exists(path):
		var resource: Resource = ResourceLoader.load(path)
		if resource is AudioStream:
			return resource as AudioStream

	if FileAccess.file_exists(path):
		return AudioStreamWAV.load_from_file(path)

	return null


func _load_texture_or_null(path: String) -> Texture2D:
	# 空路径直接返回空值，避免 ResourceLoader 访问无效路径。
	if path.is_empty():
		return null

	if ResourceLoader.exists(path):
		var resource := ResourceLoader.load(path)
		if resource is Texture2D:
			return resource

	if FileAccess.file_exists(path):
		var image: Image = Image.new()
		if image.load(path) == OK:
			return ImageTexture.create_from_image(image)

	return null
