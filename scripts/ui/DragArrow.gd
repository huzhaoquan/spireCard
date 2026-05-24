extends Control

# DragArrow 只负责绘制拖拽箭头，不参与卡牌逻辑和鼠标事件。

# 箭头主线颜色。
const ARROW_COLOR: Color = Color(0.95, 0.18, 0.12, 0.86)

# 箭头暗色描边，让轨迹在深色背景上更清楚。
const OUTLINE_COLOR: Color = Color(0.05, 0.02, 0.01, 0.7)

# 箭头线宽。
const LINE_WIDTH: float = 5.0

# 箭头头部长度。
const HEAD_LENGTH: float = 22.0

# 箭头头部半宽。
const HEAD_HALF_WIDTH: float = 10.0

# 当前箭头起点和终点，坐标基于本 Control。
var start_position: Vector2 = Vector2.ZERO
var end_position: Vector2 = Vector2.ZERO


func _ready() -> void:
	# 箭头不接收鼠标，避免挡住卡牌拖拽。
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func set_points(new_start_position: Vector2, new_end_position: Vector2) -> void:
	# 更新箭头端点并请求重绘。
	start_position = new_start_position
	end_position = new_end_position
	queue_redraw()


func _draw() -> void:
	# 距离太短时不绘制，避免卡牌刚开始拖拽时箭头闪烁成一团。
	var direction: Vector2 = end_position - start_position
	if direction.length() < 16.0:
		return

	var points: PackedVector2Array = _get_curve_points()
	draw_polyline(points, OUTLINE_COLOR, LINE_WIDTH + 4.0, true)
	draw_polyline(points, ARROW_COLOR, LINE_WIDTH, true)
	_draw_arrow_head(points)


func _get_curve_points() -> PackedVector2Array:
	# 使用二次贝塞尔曲线，让箭头有轻微弧度。
	var points: PackedVector2Array = PackedVector2Array()
	var midpoint: Vector2 = (start_position + end_position) * 0.5
	var lift: float = minf(90.0, start_position.distance_to(end_position) * 0.2)
	var control: Vector2 = midpoint + Vector2(0.0, -lift)
	var segment_count: int = 18

	for index in range(segment_count + 1):
		var t: float = float(index) / float(segment_count)
		var a: Vector2 = start_position.lerp(control, t)
		var b: Vector2 = control.lerp(end_position, t)
		points.append(a.lerp(b, t))

	return points


func _draw_arrow_head(points: PackedVector2Array) -> void:
	# 根据曲线末端方向绘制箭头头部。
	if points.size() < 2:
		return

	var tip: Vector2 = points[points.size() - 1]
	var previous: Vector2 = points[points.size() - 2]
	var direction: Vector2 = (tip - previous).normalized()
	var normal: Vector2 = Vector2(-direction.y, direction.x)
	var base: Vector2 = tip - direction * HEAD_LENGTH

	var outline_head: PackedVector2Array = PackedVector2Array([
		tip,
		base + normal * (HEAD_HALF_WIDTH + 3.0),
		base - normal * (HEAD_HALF_WIDTH + 3.0)
	])
	var fill_head: PackedVector2Array = PackedVector2Array([
		tip,
		base + normal * HEAD_HALF_WIDTH,
		base - normal * HEAD_HALF_WIDTH
	])

	draw_colored_polygon(outline_head, OUTLINE_COLOR)
	draw_colored_polygon(fill_head, ARROW_COLOR)
