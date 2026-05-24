extends Node2D

# BattleActorView 是通用战斗角色显示节点，只负责播放角色/怪物动画。
# 它不包含血量、伤害、AI、回合或战斗结算逻辑。

# 每一帧的固定尺寸。
const FRAME_SIZE: Vector2i = Vector2i(128, 128)

# 动画行索引。
const ROW_IDLE: int = 0
const ROW_ATTACK: int = 1
const ROW_HIT: int = 2
const ROW_DEATH: int = 3

# 各行动画帧数。
const IDLE_FRAME_COUNT: int = 4
const ATTACK_FRAME_COUNT: int = 6
const HIT_FRAME_COUNT: int = 3
const DEATH_FRAME_COUNT: int = 5

# 默认播放速度。
const IDLE_FPS: float = 5.0
const ACTION_FPS: float = 10.0
const DEATH_FPS: float = 8.0

# 每帧重新对齐时保留的底部像素，避免脚底贴死帧边缘。
const FRAME_BOTTOM_PADDING: int = 6

# 用 alpha 判断一帧里的有效主体区域。
const ALPHA_BOUNDS_THRESHOLD: int = 16

# HP 条平滑变化时间。
const HP_TWEEN_TIME: float = 0.25
# 是否水平翻转，用于让玩家和敌人朝向彼此。
@export var horizontal_flip: bool = false

# 角色总表路径，可在编辑器中预填，也可以通过 setup() 传入。
@export var sprite_sheet_path: String = ""

# 当前 HP 和最大 HP，只负责显示，不做伤害结算。
@export var current_hp: int = 30
@export var max_hp: int = 30

# 当前格挡值，只负责 UI 展示。
@export var current_block: int = 0

# 实际播放动画的 AnimatedSprite2D。
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

# 角色上方的 HP UI。
@onready var status_ui: Control = $StatusUI
@onready var hp_bar: ProgressBar = $StatusUI/HPBar
@onready var hp_label: Label = $StatusUI/HPLabel
@onready var block_badge: Control = $StatusUI/BlockBadge
@onready var block_diamond: ColorRect = $StatusUI/BlockBadge/BlockDiamond
@onready var block_label: Label = $StatusUI/BlockBadge/BlockLabel

# 记录当前是否已经成功创建动画资源。
var has_valid_sprite_frames: bool = false

# HP 变化 Tween 只保留一个，避免连续扣血时多个 Tween 抢 value。
var hp_tween: Tween
var block_tween: Tween
var shake_tween: Tween


func _ready() -> void:
	# 进入场景时应用编辑器里配置的翻转和贴图路径。
	animated_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_apply_horizontal_flip()
	_setup_status_ui_layout()
	_setup_hp_bar_style()
	_setup_block_badge_style()
	_apply_hp_immediate()
	_update_block_label()

	if not sprite_sheet_path.is_empty():
		setup(sprite_sheet_path)

	# 非循环动画播完后，统一在这里决定是否回到 idle。
	if not animated_sprite.animation_finished.is_connected(_on_animation_finished):
		animated_sprite.animation_finished.connect(_on_animation_finished)


func setup(new_sprite_sheet_path: String) -> void:
	# 根据传入的 sprite sheet 路径自动创建 idle / attack / hit / death 动画。
	sprite_sheet_path = new_sprite_sheet_path

	# 如果外部在节点进入场景树前调用 setup()，先记录路径，等 _ready() 后再创建动画。
	if not is_node_ready():
		return

	has_valid_sprite_frames = false

	var sheet_texture: Texture2D = _load_texture_or_null(sprite_sheet_path)
	if sheet_texture == null:
		# 图片不存在或加载失败时清空动画，避免运行时报错。
		animated_sprite.sprite_frames = SpriteFrames.new()
		return

	var sprite_frames: SpriteFrames = SpriteFrames.new()
	_setup_animation(sprite_frames, "idle", sheet_texture, ROW_IDLE, IDLE_FRAME_COUNT, IDLE_FPS, true)
	_setup_animation(sprite_frames, "attack", sheet_texture, ROW_ATTACK, ATTACK_FRAME_COUNT, ACTION_FPS, false)
	_setup_animation(sprite_frames, "hit", sheet_texture, ROW_HIT, HIT_FRAME_COUNT, ACTION_FPS, false)
	_setup_animation(sprite_frames, "death", sheet_texture, ROW_DEATH, DEATH_FRAME_COUNT, DEATH_FPS, false)

	animated_sprite.sprite_frames = sprite_frames
	_apply_horizontal_flip()
	has_valid_sprite_frames = true
	play_idle()


func play_idle() -> void:
	# 播放待机循环动画。
	_play_animation("idle")


func play_attack() -> void:
	# 播放攻击动画，播放完成后自动回到 idle。
	_play_animation("attack")


func play_hit() -> void:
	# 播放受击动画，播放完成后自动回到 idle。
	_play_hit_shake()
	_play_animation("hit")


func play_death() -> void:
	# 播放死亡动画，播放完成后停在死亡最后一帧。
	_play_animation("death")


func set_horizontal_flip(enabled: bool) -> void:
	# 外部代码可以调用这个方法切换朝向。
	horizontal_flip = enabled
	_apply_horizontal_flip()


func set_visual_scale(new_visual_scale: Vector2) -> void:
	# 只缩放角色精灵，不缩放上方 HP UI。
	if animated_sprite == null:
		return

	animated_sprite.scale = new_visual_scale


func setup_hp(new_current_hp: int, new_max_hp: int) -> void:
	# 初始化 HP 显示，常用于创建角色时设置初始生命值。
	max_hp = maxi(new_max_hp, 1)
	current_hp = clampi(new_current_hp, 0, max_hp)
	_apply_hp_immediate()


func set_hp(new_current_hp: int, new_max_hp: int = -1) -> void:
	# 更新 HP 显示；ProgressBar 使用 Tween 平滑变化。
	if new_max_hp > 0:
		max_hp = new_max_hp

	max_hp = maxi(max_hp, 1)
	current_hp = clampi(new_current_hp, 0, max_hp)
	_update_hp_label()

	if hp_bar == null:
		return

	hp_bar.max_value = float(max_hp)

	if hp_tween != null and hp_tween.is_valid():
		hp_tween.kill()
		hp_tween = null

	hp_tween = create_tween()
	hp_tween.set_trans(Tween.TRANS_QUAD)
	hp_tween.set_ease(Tween.EASE_OUT)
	hp_tween.tween_property(hp_bar, "value", float(current_hp), HP_TWEEN_TIME)


func set_block(new_block: int) -> void:
	# 更新血条左侧的蓝色菱形格挡徽章。
	current_block = maxi(new_block, 0)
	_update_block_label()


func play_block_gain() -> void:
	if block_badge == null:
		return

	if block_tween != null and block_tween.is_valid():
		block_tween.kill()
		block_tween = null

	block_badge.scale = Vector2(1.14, 1.14)
	block_badge.modulate = Color(1.12, 1.22, 1.32, 1.0)
	block_tween = create_tween()
	block_tween.set_parallel(true)
	block_tween.set_trans(Tween.TRANS_BACK)
	block_tween.set_ease(Tween.EASE_OUT)
	block_tween.tween_property(block_badge, "scale", Vector2.ONE, 0.22)
	block_tween.tween_property(block_badge, "modulate", Color(1, 1, 1, 1), 0.22)


func _setup_animation(
	sprite_frames: SpriteFrames,
	animation_name: String,
	sheet_texture: Texture2D,
	row_index: int,
	frame_count: int,
	fps: float,
	loop_enabled: bool
) -> void:
	# 从固定行里按列切出帧图，并重新做底部锚点对齐，减少生成帧中心不一致造成的抖动。
	sprite_frames.add_animation(animation_name)
	sprite_frames.set_animation_speed(animation_name, fps)
	sprite_frames.set_animation_loop(animation_name, loop_enabled)

	var sheet_image: Image = sheet_texture.get_image()
	for frame_index in range(frame_count):
		var frame_texture: Texture2D = _create_aligned_frame_texture(sheet_image, row_index, frame_index)
		sprite_frames.add_frame(animation_name, frame_texture)


func _play_animation(animation_name: String) -> void:
	# 没有有效动画时直接忽略，避免缺资源时报错。
	if not has_valid_sprite_frames:
		return

	if animated_sprite.sprite_frames == null:
		return

	if not animated_sprite.sprite_frames.has_animation(animation_name):
		return

	animated_sprite.play(animation_name)


func _on_animation_finished() -> void:
	# attack / hit 播完后回到 idle；death 播完后停在死亡最后一帧。
	if animated_sprite.animation == "death":
		animated_sprite.stop()
		var death_last_frame: int = maxi(DEATH_FRAME_COUNT - 1, 0)
		animated_sprite.frame = death_last_frame
		return

	if animated_sprite.animation == "attack" or animated_sprite.animation == "hit":
		play_idle()


func _apply_horizontal_flip() -> void:
	# AnimatedSprite2D 自带 flip_h，直接使用它实现水平翻转。
	if animated_sprite == null:
		return

	animated_sprite.flip_h = horizontal_flip


func _apply_hp_immediate() -> void:
	# 立即刷新 HP 条，初始化时不需要 Tween。
	max_hp = maxi(max_hp, 1)
	current_hp = clampi(current_hp, 0, max_hp)

	if hp_bar != null:
		hp_bar.min_value = 0.0
		hp_bar.max_value = float(max_hp)
		hp_bar.value = float(current_hp)

	_update_hp_label()


func _update_hp_label() -> void:
	# 文本显示当前 HP / 最大 HP。
	if hp_label == null:
		return

	hp_label.text = "%d / %d" % [current_hp, max_hp]


func _update_block_label() -> void:
	if block_badge == null or block_label == null:
		return

	block_badge.visible = current_block > 0
	block_label.text = str(current_block)


func _setup_status_ui_layout() -> void:
	if status_ui != null:
		status_ui.position = Vector2(-122.0, -198.0)
		status_ui.size = Vector2(244.0, 58.0)

	if hp_bar != null:
		hp_bar.position = Vector2(38.0, 22.0)
		hp_bar.size = Vector2(190.0, 24.0)

	if hp_label != null:
		hp_label.position = Vector2(38.0, 22.0)
		hp_label.size = Vector2(190.0, 24.0)
		hp_label.add_theme_font_size_override("font_size", 15)
		hp_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.82, 1.0))
		hp_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
		hp_label.add_theme_constant_override("shadow_offset_x", 1)
		hp_label.add_theme_constant_override("shadow_offset_y", 1)

	if block_badge != null:
		block_badge.position = Vector2(2.0, 15.0)
		block_badge.size = Vector2(36.0, 36.0)
		block_badge.pivot_offset = Vector2(18.0, 18.0)

	if block_diamond != null:
		block_diamond.position = Vector2(9.0, 9.0)
		block_diamond.size = Vector2(18.0, 18.0)
		block_diamond.pivot_offset = Vector2(9.0, 9.0)

	if block_label != null:
		block_label.position = Vector2(0.0, 0.0)
		block_label.size = Vector2(36.0, 36.0)
		block_label.z_index = 1
		block_label.add_theme_font_size_override("font_size", 15)


func _setup_hp_bar_style() -> void:
	# Godot 默认 ProgressBar 是灰色主题，这里给 HP 条单独设置暗底和红色填充。
	if hp_bar == null:
		return

	var background_style: StyleBoxFlat = StyleBoxFlat.new()
	background_style.bg_color = Color(0.055, 0.04, 0.038, 0.96)
	background_style.border_color = Color(0.72, 0.50, 0.27, 0.88)
	background_style.border_width_left = 3
	background_style.border_width_top = 3
	background_style.border_width_right = 3
	background_style.border_width_bottom = 3
	background_style.corner_radius_top_left = 5
	background_style.corner_radius_top_right = 5
	background_style.corner_radius_bottom_left = 5
	background_style.corner_radius_bottom_right = 5

	var fill_style: StyleBoxFlat = StyleBoxFlat.new()
	fill_style.bg_color = Color(0.84, 0.10, 0.075, 1.0)
	fill_style.border_color = Color(1.0, 0.28, 0.18, 0.45)
	fill_style.border_width_top = 1
	fill_style.corner_radius_top_left = 3
	fill_style.corner_radius_top_right = 3
	fill_style.corner_radius_bottom_left = 3
	fill_style.corner_radius_bottom_right = 3

	hp_bar.add_theme_stylebox_override("background", background_style)
	hp_bar.add_theme_stylebox_override("fill", fill_style)


func _setup_block_badge_style() -> void:
	# 格挡徽章保持小号原生菱形，避免生成贴图遮挡角色或血条。
	if block_diamond == null:
		return

	block_diamond.visible = true
	block_diamond.color = Color(0.10, 0.38, 0.86, 0.96)


func _play_hit_shake() -> void:
	if animated_sprite == null:
		return

	if shake_tween != null and shake_tween.is_valid():
		shake_tween.kill()
		shake_tween = null

	animated_sprite.position = Vector2.ZERO
	shake_tween = create_tween()
	shake_tween.set_trans(Tween.TRANS_SINE)
	shake_tween.set_ease(Tween.EASE_IN_OUT)
	shake_tween.tween_property(animated_sprite, "position", Vector2(-9.0, 0.0), 0.045)
	shake_tween.tween_property(animated_sprite, "position", Vector2(8.0, 0.0), 0.06)
	shake_tween.tween_property(animated_sprite, "position", Vector2(-5.0, 0.0), 0.05)
	shake_tween.tween_property(animated_sprite, "position", Vector2.ZERO, 0.06)


func _create_aligned_frame_texture(sheet_image: Image, row_index: int, frame_index: int) -> Texture2D:
	# 把单帧主体从原始格子里找出来，重新水平居中并贴到底部锚点。
	var source_rect: Rect2i = Rect2i(
		Vector2i(frame_index * FRAME_SIZE.x, row_index * FRAME_SIZE.y),
		FRAME_SIZE
	)
	var frame_image: Image = Image.create_empty(FRAME_SIZE.x, FRAME_SIZE.y, false, Image.FORMAT_RGBA8)
	frame_image.fill(Color(0, 0, 0, 0))

	if sheet_image == null or sheet_image.get_width() <= 0 or sheet_image.get_height() <= 0:
		return ImageTexture.create_from_image(frame_image)

	var content_rect: Rect2i = _get_content_rect(sheet_image, source_rect)
	if content_rect.size.x <= 0 or content_rect.size.y <= 0:
		return ImageTexture.create_from_image(frame_image)

	var target_x: int = int(round(float(FRAME_SIZE.x - content_rect.size.x) * 0.5))
	var target_y: int = FRAME_SIZE.y - content_rect.size.y - FRAME_BOTTOM_PADDING
	target_y = maxi(target_y, 0)

	frame_image.blit_rect(sheet_image, content_rect, Vector2i(target_x, target_y))
	return ImageTexture.create_from_image(frame_image)


func _get_content_rect(sheet_image: Image, source_rect: Rect2i) -> Rect2i:
	# 扫描 alpha，得到当前帧内真正有像素的包围盒。
	var min_x: int = source_rect.position.x + source_rect.size.x
	var min_y: int = source_rect.position.y + source_rect.size.y
	var max_x: int = source_rect.position.x - 1
	var max_y: int = source_rect.position.y - 1

	for y in range(source_rect.position.y, source_rect.position.y + source_rect.size.y):
		for x in range(source_rect.position.x, source_rect.position.x + source_rect.size.x):
			var pixel_color: Color = sheet_image.get_pixel(x, y)
			if int(round(pixel_color.a * 255.0)) <= ALPHA_BOUNDS_THRESHOLD:
				continue

			min_x = mini(min_x, x)
			min_y = mini(min_y, y)
			max_x = maxi(max_x, x)
			max_y = maxi(max_y, y)

	if max_x < min_x or max_y < min_y:
		return Rect2i(source_rect.position, Vector2i.ZERO)

	return Rect2i(
		Vector2i(min_x, min_y),
		Vector2i(max_x - min_x + 1, max_y - min_y + 1)
	)


func _load_texture_or_null(texture_path: String) -> Texture2D:
	# 优先使用 Godot 已导入资源；如果刚复制进项目还没导入，则直接从 PNG 创建 ImageTexture。
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
