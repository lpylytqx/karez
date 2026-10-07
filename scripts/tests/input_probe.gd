extends Node
## 输入路径探针：**用真实事件走完整输入管线**，验证镜头操作到底能不能用。
##
## 为什么必须这样测：上一轮我只用**直接调函数**（capture_camera 里调 _set_zoom）
## 验证了缩放，那证明了"缩放机制没问题"，但**完全没验证输入能不能传到 play.gd**。
## 用户实机反馈"平行移动的时候移动不了"，正是这条没被测到的路径。
##
## push_input 会把事件送进 viewport 的完整管线（_input → GUI → _unhandled_input），
## 和真人操作走的是同一条路 —— 这比"直接调函数"可信得多。
##
##   tools\Godot_v4.7.2-stable_win64.exe --path scripts res://tests/input_probe.tscn

var _pass := 0
var _fail := 0
var _play: Node
var _cam: Camera2D


func _ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  [PASS] %s" % label)
	else:
		_fail += 1
		print("  [FAIL] %s" % label)


func _section(t: String) -> void:
	print("")
	print("── %s ──" % t)


func _ready() -> void:
	print("=".repeat(64))
	print("  输入路径探针（真实事件）")
	print("=".repeat(64))
	_play = load("res://scenes/play.tscn").instantiate()
	add_child(_play)
	await get_tree().process_frame
	await get_tree().process_frame
	_cam = _play._cam

	await _p_wheel()
	await _p_middle_drag()
	await _p_left_drag()
	await _p_key_f()
	await _p_key_plus()
	await _p_playerdrag()

	print("")
	print("=".repeat(64))
	if _fail == 0:
		print("  全部通过：%d 项" % _pass)
	else:
		print("  通过 %d 项，失败 %d 项" % [_pass, _fail])
	print("=".repeat(64))
	get_tree().quit(1 if _fail > 0 else 0)


func _wheel(up: bool, at := Vector2(640, 400)) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_WHEEL_UP if up else MOUSE_BUTTON_WHEEL_DOWN
	ev.pressed = true
	ev.position = at
	ev.global_position = at
	get_viewport().push_input(ev)
	await get_tree().process_frame


func _btn(idx: int, pressed: bool, at := Vector2(640, 400)) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = idx
	ev.pressed = pressed
	ev.position = at
	ev.global_position = at
	get_viewport().push_input(ev)
	await get_tree().process_frame


## 造一个鼠标移动事件。
##
## ⚠ `button_mask` 必须显式设！真实输入里"按住左键拖动"时系统会把它置位，
##   而手搓事件不会 —— 第一版忘了设，于是「左键拖拽平移」永远测不过，
##   看起来像功能没做，其实是测试没模拟"按住"这个状态。
func _move(to: Vector2, rel: Vector2, mask := 0) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = to
	ev.global_position = to
	ev.relative = rel
	ev.button_mask = mask
	get_viewport().push_input(ev)
	await get_tree().process_frame


func _key(code: int) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	ev.pressed = true
	get_viewport().push_input(ev)
	await get_tree().process_frame


# ---------------------------------------------------------------------------

func _p_wheel() -> void:
	_section("滚轮缩放（真实滚轮事件）")
	var i0: int = _play._zoom_i
	await _wheel(true)
	_ok(_play._zoom_i == i0 + 1, "滚轮上：档位 %d → %d" % [i0, _play._zoom_i])
	await _wheel(false)
	await _wheel(false)
	_ok(_play._zoom_i == i0 - 1, "滚轮下两格：档位 %d（期望 %d）" % [_play._zoom_i, i0 - 1])
	await _wheel(true)
	_ok(_play._zoom_i == i0, "再滚回原档 %d" % _play._zoom_i)


func _p_middle_drag() -> void:
	_section("中键拖拽平移（真实鼠标事件）")
	await _btn(MOUSE_BUTTON_MIDDLE, true)
	_ok(not _play._follow, "中键按下后跟随被关掉（否则会和用户抢镜头）")
	var p0: Vector2 = _cam.position
	await _move(Vector2(600, 400), Vector2(-40, 0), MOUSE_BUTTON_MASK_MIDDLE)
	await _move(Vector2(560, 400), Vector2(-40, 0), MOUSE_BUTTON_MASK_MIDDLE)
	await get_tree().process_frame
	var dx := _cam.position.x - p0.x
	_ok(absf(dx) > 20.0, "中键拖动后镜头横向移动了 %.1f px（期望 >20，方向向右为正）" % dx)
	await _btn(MOUSE_BUTTON_MIDDLE, false)
	_ok(not _play._pan_drag, "松开中键后拖拽状态被清掉")


func _p_left_drag() -> void:
	_section("左键拖拽平移（**这是用户会本能去试的操作**）")
	_play._follow = true
	var p0: Vector2 = _cam.position
	await _btn(MOUSE_BUTTON_LEFT, true, Vector2(640, 300))
	await _move(Vector2(600, 300), Vector2(-40, 0), MOUSE_BUTTON_MASK_LEFT)
	await _move(Vector2(560, 300), Vector2(-40, 0), MOUSE_BUTTON_MASK_LEFT)
	var dx := _cam.position.x - p0.x
	print("    左键拖动后镜头位移 = %.1f px，_follow=%s" % [dx, str(_play._follow)])
	_ok(absf(dx) > 20.0, "左键拖空白地图也应当能平移（实际 %.1f px）" % dx)
	_ok(not _play._follow, "左键拖拽后自动脱离跟随")
	await _btn(MOUSE_BUTTON_LEFT, false, Vector2(560, 300))

	# 手抖：按住左键但只移动 2px（不到 5px 阈值）—— 不该进入拖拽状态，
	# 否则玩家每次点选地上的东西都会顺手把视角挪歪。
	#
	# ⚠ 断言要查 `_left_panning`，**不能查镜头位置**：跟随打开时镜头本来
	#   每帧都在朝主角插值，位置动不代表平移被触发了（第一版就是这么断言错的）。
	_play._follow = true
	await _btn(MOUSE_BUTTON_LEFT, true, Vector2(640, 300))
	await _move(Vector2(642, 300), Vector2(2, 0), MOUSE_BUTTON_MASK_LEFT)
	_ok(not _play._left_panning, "2px 的手抖没有进入拖拽状态")
	_ok(_play._follow, "手抖之后仍然在跟随（没被误判成拖动）")
	await _btn(MOUSE_BUTTON_LEFT, false, Vector2(642, 300))


func _p_key_f() -> void:
	_section("按 F 回到主角")
	_play._follow = false
	await _key(KEY_F)
	_ok(_play._follow, "F 键把跟随打开")


func _p_key_plus() -> void:
	_section("按 + / - 缩放（笔记本没有滚轮时用）")
	var i0: int = _play._zoom_i
	await _key(KEY_EQUAL)
	_ok(_play._zoom_i == i0 + 1, "+ 键放大一档（%d → %d）" % [i0, _play._zoom_i])
	await _key(KEY_MINUS)
	_ok(_play._zoom_i == i0, "- 键缩回一档（%d）" % _play._zoom_i)


func _p_playerdrag() -> void:
	_section("主角能否在屏幕上被认出来")
	var player: Node2D = _play.get_node("Player")
	_ok(player != null, "Player 节点存在")
	# 有没有一个"这是主角"的可视标记？子节点里应当有一个标记精灵/标签
	var marks := 0
	for c in player.get_children():
		var n := str(c.name)
		if n.contains("Mark") or n.contains("Arrow") or n.contains("Ring") or n.contains("Name"):
			marks += 1
	_ok(marks > 0, "主角身上有可辨认的标记（找到 %d 个）" % marks)
