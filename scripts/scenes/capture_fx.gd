extends Node
## 一次性截图工具：验证新增的动态效果。
##
## 三张图：
##   A_动效      地图上应当能看到 水面光点 / 旗子 / 火苗
##   B_飘字      推进一天后，资源栏上方浮出 +N / -N
##   C_动效2     与 A 相隔约 0.4 秒 —— 对比 A 可看出旗子与光点确实在动
##               （单张截图看不出动画，必须两帧对比）
##
##   tools\Godot_v4.7.2-stable_win64.exe --path scripts res://scenes/capture_fx.tscn

const SETTLE_FRAMES := 18
const ANIM_GAP_FRAMES := 24      # 约 0.4 秒

var _play: Node
var _gs: Node
var _map: Node
var _hud: Node
var _atmo: Node
var _frames := 0
var _stage := 0


func _ready() -> void:
	_play = load("res://scenes/play.tscn").instantiate()
	add_child(_play)
	_gs = _play.get_node("GameState")
	_map = _play.get_node("MapView")
	_hud = _play.get_node("HUDLayer/HUD")
	_atmo = _play.get_node("Atmosphere")
	# 3 段：驿馆与两座巴扎都出现，旗子才有地方插
	_gs.state["karez"]["sections"] = 3
	_gs.state["resources"]["materials"]["wood"] = 200.0
	_gs.state["resources"]["materials"]["earth"] = 300.0
	_gs.state_changed.emit()
	print("CAPTURE fx ready  sections=%d" % int(_gs.query("karez.sections")))
	print("  动态帧带数量 = %d" % _atmo._sheets.size())
	print("  其中锚在地标上的 = %d" % _atmo._anchored.size())


func _process(_delta: float) -> void:
	_frames += 1
	match _stage:
		0:
			if _frames >= SETTLE_FRAMES:
				_dump_sheets()
				_shot("A_动效")
				_stage = 1
				_frames = 0
		1:
			# 推进一天：资源变化 → HUD 飘字
			_gs.advance_day()
			_stage = 2
			_frames = 0
		2:
			if _frames >= 5:      # 等飘字浮起来一点再截
				print("\n  飘字数量 = %d" % _hud._floaters.size())
				for f in _hud._floaters:
					var lb: Label = f[0]
					if lb != null and is_instance_valid(lb):
						print("    '%s'  pos=(%.0f,%.0f)" % [lb.text, lb.position.x, lb.position.y])
				_shot("B_飘字")
				_stage = 3
				_frames = 0
		3:
			if _frames >= ANIM_GAP_FRAMES:
				_shot("C_动效2")
				_stage = 4
				_frames = 0
		4:
			print("CAPTURE fx done")
			get_tree().quit()


func _dump_sheets() -> void:
	print("\n  帧带清单：")
	for s in _atmo._sheets:
		var sp: Sprite2D = s[0]
		if sp == null or not is_instance_valid(sp):
			continue
		print("    可见=%s pos=(%.0f,%.0f) frame=%d/%d hframes=%d" % [
			str(sp.visible), sp.position.x, sp.position.y,
			sp.frame, int(s[1]), sp.hframes])


func _shot(tag: String) -> void:
	var img := get_viewport().get_texture().get_image()
	var path := "user://fx_%s.png" % tag
	var err := img.save_png(path)
	print("CAPTURE fx_%s.png  err=%s" % [tag, str(err)])
