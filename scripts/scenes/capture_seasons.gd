extends Node
## 生成「四季对比」截图：同一片 6 段竖井的绿洲，春 / 夏 / 秋 / 冬各一张。
##
## 用途：一眼看出换季到底换了什么。冬天地表整套换雪地贴图（不是加滤镜），
## 而雪地那批贴图此前是**跑出色板**的冷灰蓝、明度全挤在 16 个色阶内，
## 看着是一块平板灰紫 —— 2026-10-06 用 make_snow.py 重做后才有了明暗层次。
##
##   tools\Godot_v4.7.2-stable_win64.exe --path scripts res://scenes/capture_seasons.tscn

const SEASONS := ["spring", "summer", "autumn", "winter"]
const SETTLE_FRAMES := 26

var _play: Node
var _gs: Node
var _frames := 0
var _idx := 0
var _applied := false


func _ready() -> void:
	_play = load("res://scenes/play.tscn").instantiate()
	add_child(_play)
	_gs = _play.get_node("GameState")
	# 只要地图，把 HUD 藏起来，免得面板挡住画面
	_play.get_node("HUDLayer/HUD").visible = false
	# 固定成 6 段竖井的成熟绿洲：四季差别在绿洲长满时最看得出来
	_gs.state["karez"]["sections"] = 6
	_gs.state["resources"]["materials"]["wood"] = 300.0
	_gs.state["resources"]["materials"]["earth"] = 500.0
	_gs.state["resources"]["materials"]["tools"] = 12.0
	print("CAPTURE seasons ready, order = ", str(SEASONS))


func _process(_delta: float) -> void:
	_frames += 1
	if _idx >= SEASONS.size():
		print("CAPTURE seasons done")
		get_tree().quit()
		return

	if not _applied:
		_gs.state["calendar"]["season"] = SEASONS[_idx]
		# 广播一次让地图重建地形（换季是真的换贴图，不只是改个 tint）
		_gs.state_changed.emit()
		_applied = true
		_frames = 0
		return

	if _frames >= SETTLE_FRAMES:
		var s: String = SEASONS[_idx]
		var img := get_viewport().get_texture().get_image()
		var path := "user://season_%s.png" % s
		var err := img.save_png(path)
		print("CAPTURE season_%s.png  err=%s" % [s, str(err)])
		_idx += 1
		_applied = false
		_frames = 0
