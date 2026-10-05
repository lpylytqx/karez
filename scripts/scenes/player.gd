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
