extends Node
## 一次性截图工具：加载 play 主场景，在「初始」与「挖通 3 段竖井后」各截一张，
## 用于验证 S2 的核心可演示点 —— 绿洲是否真的随坎儿井段数生长。
##
## 只用于验证，不参与正式游戏。必须带窗口运行（headless 无法渲染）。

const OUT_DIR := "user://"

var _play: Node
var _gs: Node
var _frames := 0
var _stage := 0


func _ready() -> void:
	_play = load("res://scenes/play.tscn").instantiate()
	add_child(_play)
	_gs = _play.get_node("GameState")
	print("CAPTURE play scene added")


func _process(_delta: float) -> void:
	_frames += 1

	match _stage:
		0:
			if _frames >= 45:
				_shot("shot_A_初始.png")
				_stage = 1
				_frames = 0
		1:
			# 挖三段竖井：每段开工后推进两天完工
			_advance_story()
			_stage = 2
			_frames = 0
		2:
			if _frames >= 30:
				_dump_ui()
				_shot("shot_B_三段竖井.png")
				_stage = 3
				_frames = 0
		3:
			if _frames >= 20:
				print("CAPTURE done")
				get_tree().quit()


func _advance_story() -> void:
	# 直接改状态给足材料：走 apply_deltas 会被 MAX_DELTA 夹到 25，挖不动三段。
	# 这是截图脚本，不是玩法，绕过校验是有意的。
	_gs.state["resources"]["materials"]["wood"] = 300.0
	_gs.state["resources"]["materials"]["earth"] = 500.0
	_gs.state["resources"]["materials"]["tools"] = 10.0

	for i in range(3):
		# 行动点每时段重置，所以用 advance_phase 推进而不是直接 advance_day。
		# （直接 advance_day 不重置行动点，挖两次就用光了 —— 那是设计，不是 bug）
		_gs.state["action_points"] = 8
		var r: Dictionary = _gs.start_dig()
		var days := int(r.get("days", 2))
		print("  第 %d 次开挖 ok=%s 工期=%d" % [i + 1, str(r.get("ok", false)), days])
		for d in range(days):
			for ph in range(4):
				_gs.advance_phase()
	print("  当前段数 = %d，绿洲等级 = %d，日出水 = %.0f，第 %d 天" % [
		int(_gs.query("karez.sections")), int(_gs.oasis_level()),
		float(_gs.query("resources.water.flow_per_day")), int(_gs.query("day"))])


func _shot(name: String) -> void:
	var img := get_viewport().get_texture().get_image()
	var path := OUT_DIR + name
	var err := img.save_png(path)
	print("CAPTURE %s  err=%s  -> %s" % [name, str(err), ProjectSettings.globalize_path(path)])


## 列出 HUD 下所有可见 Control 的绝对矩形 —— 用于定位画面上多出来的东西。
func _dump_ui() -> void:
	print("── UI 可见控件 ──")
	_walk_ui(_play.get_node("HUDLayer/HUD"), 0)


func _walk_ui(n: Node, depth: int) -> void:
	for c in n.get_children():
		if c is Control and c.visible:
			var r: Rect2 = c.get_global_rect()
			print("  %s%s '%s'  pos=(%.0f,%.0f) size=(%.0f,%.0f)" % [
				"  ".repeat(depth), c.get_class(), c.name,
				r.position.x, r.position.y, r.size.x, r.size.y])
		_walk_ui(c, depth + 1)
