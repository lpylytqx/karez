extends Node
## 一次性截图工具：验证「鼠标停在地标上出说明浮层、移开就消失」。
##
## 三张图：
##   A_无浮层   开局什么都不指 —— 浮层必须是隐藏的（用户要求「正常情况下隐藏」）
##   B_浮层     指着马厩 —— 出现说明
##   C_已隐藏   移开 —— 又消失
##
## 用 Input.warp_mouse 真的把光标挪过去，走的是和玩家一样的那条路径
## （_input → _pick_site → site_hovered → HUD 显示浮层），不是直接调 HUD 方法，
## 否则就测不到「悬停检测」本身。
##
##   tools\Godot_v4.7.2-stable_win64.exe --path scripts res://scenes/capture_tip.tscn

const SETTLE_FRAMES := 14
## 窗口坐标（1280x720）。HUD 的逻辑空间是 640x360，所以要乘 2 再换算。
## 马厩在地图格 (31, 15.5) 附近 → 逻辑像素约 (500, 250) → 窗口约 (1000, 500)。
const WARP_ON_BUILDING := Vector2(1000, 500)
## ⚠ 必须落在**窗口内**（1280x720）。第一版写成 (300, 900)，y 超窗口，
##    warp_mouse 直接无效、光标没动，于是「移开」那一步测不出来（浮层仍显示）。
## 这里取左上角的空沙漠（逻辑约 (60,120)）。
const WARP_EMPTY := Vector2(120, 240)

var _play: Node
var _gs: Node
var _map: Node
var _hud: Node
var _frames := 0
var _stage := 0


func _ready() -> void:
	_play = load("res://scenes/play.tscn").instantiate()
	add_child(_play)
	_gs = _play.get_node("GameState")
	_map = _play.get_node("MapView")
	_hud = _play.get_node("HUDLayer/HUD")
	# 马厩门槛是 2 段，这里直接补到 2 段让它出现在地图上
	_gs.state["karez"]["sections"] = 2
	_gs.state_changed.emit()

	print("CAPTURE tip ready")
	print("  [probe] _pick_site 命中测试（逻辑像素坐标）：")
	for probe in [Vector2(500, 248), Vector2(300, 200)]:
		print("  [probe]   %s -> '%s'" % [str(probe), _map._pick_site(probe)])


func _process(_delta: float) -> void:
	_frames += 1
	match _stage:
		0:
			if _frames >= SETTLE_FRAMES:
				Input.warp_mouse(WARP_EMPTY)
				_stage = 1
				_frames = 0
		1:
			if _frames >= SETTLE_FRAMES:
				print("\n  A 阶段：光标在空地，浮层 visible = %s  ← 期望 false" % str(_hud._tip.visible))
				_shot("A_无浮层")
				Input.warp_mouse(WARP_ON_BUILDING)
				_stage = 2
				_frames = 0
		2:
			# 多等几帧：warp_mouse 之后要等系统发出 mouse motion 事件
			if _frames >= SETTLE_FRAMES * 2:
				print("  B 阶段：光标移到马厩上，浮层 visible = %s  ← 期望 true" % str(_hud._tip.visible))
				print("    当前悬停 id = '%s'" % str(_map._hover_id))
				print("    浮层文案 = %s" % str(_hud._tip_label.text).replace("\n", " / "))
				_shot("B_浮层")
				Input.warp_mouse(WARP_EMPTY)
				_stage = 3
				_frames = 0
		3:
			if _frames >= SETTLE_FRAMES * 2:
				print("  C 阶段：光标移开，浮层 visible = %s  ← 期望 false" % str(_hud._tip.visible))
				_shot("C_已隐藏")
				_stage = 4
				_frames = 0
		4:
			print("CAPTURE tip done")
			get_tree().quit()


func _shot(tag: String) -> void:
	var img := get_viewport().get_texture().get_image()
	var path := "user://tip_%s.png" % tag
	var err := img.save_png(path)
	print("CAPTURE tip_%s.png  err=%s" % [tag, str(err)])
