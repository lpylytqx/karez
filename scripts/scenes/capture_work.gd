extends Node
## 劳作动画连拍：同一个干活的人连拍若干帧，拼起来看「动得像不像在干活」。
##
##   tools\Godot_v4.7.2-stable_win64.exe --path scripts res://scenes/capture_work.tscn
##
## 为什么不能用单张截图：动画的问题永远是「有没有动、动得像不像」，
## 一张静图既证明不了动，也判断不了像不像。

const SHOTS := 8
const STEP_FRAMES := 4          # 每 4 帧抓一张（约 0.067s），一个劳作拍 0.34s 正好覆盖

var _play: Node
var _gs: Node
var _n := 0
var _frames := 0
var _warm := 0


func _ready() -> void:
	_play = load("res://scenes/play.tscn").instantiate()
	add_child(_play)
	_gs = _play.get_node("GameState")
	_play.get_node("HUDLayer/HUD").visible = false
	# 推一点进度，让居民都走到工地上（开局他们还在路上）
	for i in 6:
		_gs.advance_phase()
	print("CAPTURE work ready")


func _process(_delta: float) -> void:
	# 先等居民走到位：60 帧 ≈ 1 秒，配合 advance_phase 已经够
	_warm += 1
	if _warm < 90:
		return

	_frames += 1
	if _frames < STEP_FRAMES:
		return
	_frames = 0

	var img := get_viewport().get_texture().get_image()
	img.save_png("user://work_%02d.png" % _n)
	print("CAPTURE work_%02d.png" % _n)
	_n += 1
	if _n >= SHOTS:
		print("CAPTURE work done")
		get_tree().quit()
