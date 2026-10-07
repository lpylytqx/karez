extends CharacterBody2D
## 主角（驿丞）：4 方向移动 + 行走动画。
## 行走图为 RPG Maker 格式：4 列 × 7 行，前 4 行是 down/left/right/up，
## 每行 4 帧：列 0 左步、列 1 站立、列 2 右步、列 3 站立。

const SPEED := 70.0
const FRAME_DUR := 0.16

@onready var sprite: Sprite2D = $Sprite

var facing := 0   # 0 down, 1 left, 2 right, 3 up
var anim_t := 0.0
var step := 1     # 当前列：1 = 站立，0/2 = 迈步

## ── 主角标记 ──
##
## 为什么必须有：主角和村民在 16px 下几乎一模一样，玩家认不出哪个是自己
## （用户实机原话：「主角是谁呀？我也跟不了啊」）——
## 认不出主角，"按 F 回到主角"这句话对他就是空的。
##
## 做法是头顶一个**会轻轻上下浮动**的小箭头 + 身份名。
## 用 Polygon2D 画箭头而不是打「▼」字符：项目用的像素字体不一定有那个码位，
## 画几何图形是必然能渲染的，不赌字体。
const MARK_COLOR := Color(1.0, 0.86, 0.42)
const MARK_NAME := "驿丞"
var _mark: Polygon2D = null
var _mark_t := 0.0


func _ready() -> void:
	sprite.texture = load("res://characters/player_yicheng_walk.png")
	sprite.hframes = 4
	sprite.vframes = 7
	# 角色在 16×16 格内，让脚底对齐碰撞原点
	sprite.centered = true
	sprite.offset = Vector2(0, -4)
	# 地图节点在 Player 之后动态添加，必须抬高 z_index 才不会被地形/景物遮住
	z_index = 10
	_set_frame(1, facing)
	_build_mark()


func _build_mark() -> void:
	_mark = Polygon2D.new()
	_mark.name = "PlayerMark"      # 取个能自查的名字（测试会按名字找它）
	# 向下的三角，尖端朝下指着人物
	_mark.polygon = PackedVector2Array([
		Vector2(-5, -6), Vector2(5, -6), Vector2(0, 0)])
	_mark.color = MARK_COLOR
	_mark.position = Vector2(0, -24)
	# z_as_relative 关掉 + 显式 z_index：下面那些地形的 z 是 1~5，
	# 不显式抬高的话箭头会被地形/道具盖住（townfolk 的名牌踩过同一个坑）
	_mark.z_index = 14
	_mark.z_as_relative = false
	add_child(_mark)

	var lb := Label.new()
	lb.name = "PlayerName"
	lb.text = MARK_NAME
	lb.add_theme_font_size_override("font_size", 11)
	lb.add_theme_color_override("font_color", MARK_COLOR)
	# 描边：标记会压在各种地形上（浅色沙地尤其），没有描边会糊在底色里
	lb.add_theme_constant_override("outline_size", 4)
	lb.add_theme_color_override("font_outline_color", Color(0.12, 0.09, 0.07, 0.9))
	lb.size = Vector2(48, 16)
	lb.position = Vector2(-24, -42)
	lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lb.z_index = 14
	lb.z_as_relative = false
	add_child(lb)


func _process(delta: float) -> void:
	if _mark == null:
		return
	# 上下轻浮（约 0.9 秒一个来回）。完全不动的话，它会被当成画面上的一个污点；
	# 一直在动才读得出「这是标记，指的是这个人」。
	_mark_t += delta
	_mark.position.y = -24.0 + sin(_mark_t * 3.5) * 1.8

func _physics_process(delta: float) -> void:
	# 输入框获得焦点时，方向键应留给文字光标，不能让角色跟着跑。
	# 把对话栏和行走放在同一屏之后，这是必然出现的冲突。
	if get_viewport().gui_get_focus_owner() is LineEdit:
		velocity = Vector2.ZERO
		step = 1
		anim_t = 0.0
		_set_frame(1, facing)
		return

	var v := Vector2.ZERO
	v.x = Input.get_axis("ui_left", "ui_right")
	v.y = Input.get_axis("ui_up", "ui_down")
	# WASD 支持（用物理键码，不受输入法状态影响）
	if Input.is_physical_key_pressed(KEY_A):
		v.x = -1.0
	elif Input.is_physical_key_pressed(KEY_D):
		v.x = 1.0
	if Input.is_physical_key_pressed(KEY_W):
		v.y = -1.0
	elif Input.is_physical_key_pressed(KEY_S):
		v.y = 1.0

	if v != Vector2.ZERO:
		facing = _dir_to_row(v)
		velocity = v.normalized() * SPEED
		move_and_slide()
		anim_t += delta
		if anim_t >= FRAME_DUR:
			anim_t = 0.0
			# 迈步序列：站立1 → 左步0 → 站立1 → 右步2 → 循环
			match step:
				1: step = 0
				0: step = 1
				_: step = 2
		_set_frame(step, facing)
	else:
		velocity = Vector2.ZERO
		step = 1
		anim_t = 0.0
		_set_frame(1, facing)

func _set_frame(col: int, row: int) -> void:
	sprite.frame = row * 4 + col

func _dir_to_row(v: Vector2) -> int:
	if absf(v.x) > absf(v.y):
		return 2 if v.x > 0.0 else 1
	return 0 if v.y > 0.0 else 3
