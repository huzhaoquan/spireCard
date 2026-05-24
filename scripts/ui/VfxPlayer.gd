extends Control
class_name VfxPlayer

# VfxPlayer 是一个轻量 UI 特效播放器，用于在测试场景里播放横向 sprite sheet。

# 特效序列帧贴图路径。
@export var texture_path: String = ""

# sprite sheet 中的总帧数。
@export var frame_count: int = 6

# 单帧尺寸，斩击特效默认是 128x128。
@export var frame_size: Vector2i = Vector2i(128, 128)

# 每秒播放多少帧。
@export var fps: float = 18.0

# 是否在进入场景树后自动播放，默认关闭，由代码调用 play()。
@export var auto_play_on_ready: bool = false

# 已加载的 sprite sheet 贴图。
var sprite_sheet: Texture2D

# 当前正在绘制的帧索引。
var current_frame: int = 0

# 帧计时器。
var elapsed_time: float = 0.0

# 是否正在播放。
var is_playing: bool = false

# 每一帧停留的秒数。
var seconds_per_frame: float = 1.0 / 18.0


static func play_at(parent: Node, global_position: Vector2, effect_texture_path: String) -> Control:
	# 便捷方法：创建一个 VfxPlayer，放到指定父节点下，并在全局坐标处播放。
	# 注意这里不加载 VfxPlayer.tscn，避免脚本执行时反向加载自身场景导致 Busy 报错。
	if parent == null:
		return null

	var player: Control = VfxPlayer.new()
	parent.add_child(player)
	player.call("setup", effect_texture_path)

	var player_size: Vector2 = Vector2(128.0, 128.0)
	var player_size_value: Variant = player.call("get_frame_size")
	if player_size_value is Vector2:
		player_size = player_size_value
	player.global_position = global_position - player_size * 0.5
	player.call("play")
	return player


func _ready() -> void:
	# 特效不参与鼠标交互，避免挡住卡牌。
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_apply_frame_size()
	_load_texture()
	set_process(false)

	if auto_play_on_ready:
		play()


func setup(new_texture_path: String, new_frame_count: int = 6, new_frame_size: Vector2i = Vector2i(128, 128), new_fps: float = 18.0) -> void:
	# 外部可以在播放前设置贴图路径、帧数、单帧尺寸和帧率。
	texture_path = new_texture_path
	frame_count = maxi(new_frame_count, 1)
	frame_size = new_frame_size
	fps = maxf(new_fps, 1.0)

	if frame_size.x <= 0:
		frame_size.x = 128
	if frame_size.y <= 0:
		frame_size.y = 128

	seconds_per_frame = 1.0 / fps
	current_frame = 0
	elapsed_time = 0.0
	_apply_frame_size()
	_load_texture()
	queue_redraw()


func play() -> void:
	# 从第 1 帧开始播放；贴图不存在时直接释放，不报错。
	if sprite_sheet == null:
		_load_texture()

	if sprite_sheet == null:
		queue_free()
		return

	current_frame = 0
	elapsed_time = 0.0
	is_playing = true
	visible = true
	set_process(true)
	queue_redraw()


func get_frame_size() -> Vector2:
	# 返回 Vector2 形式的单帧尺寸，方便定位到特效中心。
	return Vector2(float(frame_size.x), float(frame_size.y))


func _process(delta: float) -> void:
	# 按 fps 推进帧，播放结束后自动销毁节点。
	if not is_playing:
		return

	elapsed_time += delta
	while elapsed_time >= seconds_per_frame:
		elapsed_time -= seconds_per_frame
		current_frame += 1

		if current_frame >= frame_count:
			queue_free()
			return

		queue_redraw()


func _draw() -> void:
	# 从横向 sprite sheet 中裁切当前帧并绘制到 Control 区域。
	if sprite_sheet == null:
		return

	var draw_size: Vector2 = get_frame_size()
	var source_position: Vector2 = Vector2(float(current_frame * frame_size.x), 0.0)
	var source_rect: Rect2 = Rect2(source_position, draw_size)
	var target_rect: Rect2 = Rect2(Vector2.ZERO, draw_size)
	draw_texture_rect_region(sprite_sheet, target_rect, source_rect)


func _apply_frame_size() -> void:
	# 固定 Control 尺寸，让单帧贴图按 1:1 像素显示。
	var draw_size: Vector2 = get_frame_size()
	custom_minimum_size = draw_size
	size = draw_size
	pivot_offset = draw_size * 0.5


func _load_texture() -> void:
	# 路径为空或资源不存在时不报错，只保持空贴图。
	sprite_sheet = null
	if texture_path.is_empty():
		return

	if not ResourceLoader.exists(texture_path):
		return

	var resource: Resource = ResourceLoader.load(texture_path)
	if resource is Texture2D:
		sprite_sheet = resource as Texture2D
