extends Node
## 季节色调对比：固定「午」（中性光），只换季节 —— 这样变量只有一个。
## （四时段的对比见 docs/screenshots/S4_昼夜四时段.png，那是固定春季换时段。）
##
##   tools\Godot_v4.7.2-stable_win64.exe --path scripts res://scenes/capture_phase.tscn

const SEASONS := ["spring", "summer", "autumn", "winter"]

var _play: Node
var _gs: Node
var _frames := 0
var _idx := 0
var _applied := false


func _ready() -> void:
	_play = load("res://scenes/play.tscn").instantiate()
	add_child(_play)
	_gs = _play.get_node("GameState")
	_play.get_node("HUDLayer/HUD").visible = false
	print("CAPTURE season ready")


func _process(_delta: float) -> void:
	_frames += 1
	if _idx >= SEASONS.size():
		print("CAPTURE season done")
		get_tree().quit()
		return

	if not _applied:
		# 固定中性时段，只变季节
		_gs.state["calendar"]["phase"] = "afternoon"
		_gs.state["calendar"]["season"] = str(SEASONS[_idx])
		_gs.state_changed.emit()
		_applied = true
		_frames = 0
		return

	if _frames >= 55:
		var img := get_viewport().get_texture().get_image()
		var p := "user://season_%s.png" % str(SEASONS[_idx])
		var err := img.save_png(p)
		print("CAPTURE season_%s.png err=%s" % [str(SEASONS[_idx]), str(err)])
		_idx += 1
		_applied = false
		_frames = 0
