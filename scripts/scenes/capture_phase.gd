extends Node
## 把四个时段各截一张，用于确认昼夜光照真的生效。
##
##   tools\Godot_v4.7.2-stable_win64.exe --path scripts res://scenes/capture_phase.tscn

const PHASES := ["morning", "afternoon", "evening", "night"]

var _play: Node
var _gs: Node
var _frames := 0
var _idx := 0
var _applied := false


func _ready() -> void:
	_play = load("res://scenes/play.tscn").instantiate()
	add_child(_play)
	_gs = _play.get_node("GameState")
	# 藏掉 HUD，只要地图 —— 光照只作用于世界层，界面不该跟着变
	_play.get_node("HUDLayer/HUD").visible = false
	print("CAPTURE phase ready")


func _process(_delta: float) -> void:
	_frames += 1
	if _idx >= PHASES.size():
		print("CAPTURE phase done")
		get_tree().quit()
		return

	if not _applied:
		_gs.state["calendar"]["phase"] = str(PHASES[_idx])
		_gs.state_changed.emit()
		_applied = true
		_frames = 0
		return

	# 补间 0.6s ≈ 36 帧，等够再看
	if _frames >= 55:
		var img := get_viewport().get_texture().get_image()
		var p := "user://phase_%s.png" % str(PHASES[_idx])
		var err := img.save_png(p)
		print("CAPTURE phase_%s.png err=%s" % [str(PHASES[_idx]), str(err)])
		_idx += 1
		_applied = false
		_frames = 0
