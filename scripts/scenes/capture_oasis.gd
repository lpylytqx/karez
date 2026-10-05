extends Node
## 生成「绿洲随坎儿井段数生长」的对比截图：0 / 2 / 4 / 6 段各一张。
##
## 用途：直观回答「地图会不会变绿」。地图画布尺寸固定 640x360，
## 但绿洲半径 OASIS_RADIUS 会从 3.2 格长到 11.8 格（面积 13.6 倍）。
##
##   tools\Godot_v4.7.2-stable_win64.exe --path scripts res://scenes/capture_oasis.tscn

const LEVELS := [0, 2, 4, 6]
const SETTLE_FRAMES := 24

var _play: Node
var _gs: Node
var _frames := 0
var _idx := 0
var _applied := false


func _ready() -> void:
	_play = load("res://scenes/play.tscn").instantiate()
	add_child(_play)
	_gs = _play.get_node("GameState")
	# 只要地图，把 HUD 藏起来，免得面板挡住绿洲
	var hud := _play.get_node("HUDLayer/HUD")
	hud.visible = false
	print("CAPTURE oasis ready, levels = ", str(LEVELS))


func _process(_delta: float) -> void:
	_frames += 1
	if _idx >= LEVELS.size():
		print("CAPTURE oasis done")
		get_tree().quit()
		return

	if not _applied:
		var lv: int = int(LEVELS[_idx])
		# 直接把段数写进状态并广播，map_view 会重建地形
		_gs.state["karez"]["sections"] = lv
		# 让农田/建筑也跟着出现（它们的门槛看 oasis_level）
		_gs.state["resources"]["materials"]["wood"] = 300.0
		_gs.state["resources"]["materials"]["earth"] = 500.0
		_gs.state["resources"]["materials"]["tools"] = 12.0
		_gs.state_changed.emit()
		_applied = true
		_frames = 0
		return

	if _frames >= SETTLE_FRAMES:
		var lv: int = int(LEVELS[_idx])
		var img := get_viewport().get_texture().get_image()
		var path := "user://oasis_%d.png" % lv
		var err := img.save_png(path)
		print("CAPTURE oasis_%d.png  radius=%.1f  err=%s" % [
			lv, float(_gs.oasis_radius()) if _gs.has_method("oasis_radius") else -1.0, str(err)])
		_idx += 1
		_applied = false
		_frames = 0
