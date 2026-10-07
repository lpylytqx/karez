extends Node
## 一次性截图工具：验证镜头缩放与扩图。
##
##   A_默认档     ×1.0 —— 应当看到聚落那一带（与扩图前的视野相当），HUD 右上有档位读数
##   B_缩到最小   ×0.5 —— 整张 56x32 地图应当全进画面
##   C_放到最大   ×2.5 —— 能看清单个格子，且像素不抖（档位取值保证 32×zoom 是整数）
##   D_战斗点     镜头飞到东边新扩出来的沙漠 —— 确认新地图区域真的能用
##
##   tools\Godot_v4.7.2-stable_win64.exe --path scripts res://scenes/capture_camera.tscn

const SETTLE_FRAMES := 20
const ZOOM_WAIT := 30        # 缩放补间 0.16s ≈ 10 帧，给足余量

var _play: Node
var _map: Node
var _frames := 0
var _stage := 0


func _ready() -> void:
	_play = load("res://scenes/play.tscn").instantiate()
	add_child(_play)
	_map = _play.get_node("MapView")
	print("CAPTURE camera ready")
	print("  地图 %d x %d 格 = %d x %d px（原 40x22 = 640x352）" % [
		_map.COLS, _map.ROWS, _map.COLS * _map.TILE, _map.ROWS * _map.TILE])
	print("  面积倍数 = %.2fx" % ((_map.COLS * _map.ROWS) / float(40 * 22)))
	print("  绿洲中心 = %s（聚落实际中心应在此附近）" % str(_map.VILLAGE_CENTER))
	print("  缩放档位 = %s" % str(_play.ZOOM_STEPS))
	print("  默认档 index=%d → %.2f" % [_play.ZOOM_DEFAULT,
		_play.ZOOM_STEPS[_play.ZOOM_DEFAULT]])
	var z = _play.ZOOM_STEPS
	print("  各档物理像素/格（32×zoom，必须都是整数）: ", 
		", ".join(z.map(func(v): return "%.2f→%g" % [v, 32.0 * v])))


func _process(_delta: float) -> void:
	_frames += 1
	match _stage:
		0:
			if _frames >= SETTLE_FRAMES:
				print("\n  A：档位 index=%d zoom=%.2f 镜头=%s" % [
					_play._zoom_i, _play._cam.zoom.x, str(_play._cam.position)])
				_shot("A_默认档")
				_play._set_zoom(0)          # 0.5
				_stage = 1
				_frames = 0
		1:
			if _frames >= ZOOM_WAIT:
				print("  B：缩到最小 zoom=%.2f 镜头=%s" % [
					_play._cam.zoom.x, str(_play._cam.position)])
				_shot("B_缩到最小")
				_play._set_zoom(6)          # 2.5
				_stage = 2
				_frames = 0
		2:
			if _frames >= ZOOM_WAIT:
				print("  C：放到最大 zoom=%.2f 镜头=%s" % [
					_play._cam.zoom.x, str(_play._cam.position)])
				_shot("C_放到最大")
				# 镜头直接飞到东边新扩出来的沙漠（原地图 40 格之外）
				_play._follow = false
				_play._cam.position = Vector2(48 * 16, 22 * 16)
				_play._clamp_camera()
				_stage = 3
				_frames = 0
		3:
			if _frames >= SETTLE_FRAMES:
				print("  D：镜头移到 (48,22) 格 = %s —— 这里是原地图之外" % str(_play._cam.position))
				_shot("D_新区沙漠")
				_stage = 4
				_frames = 0
		4:
			print("CAPTURE camera done")
			get_tree().quit()


func _shot(tag: String) -> void:
	var img := get_viewport().get_texture().get_image()
	var err := img.save_png("user://cam_%s.png" % tag)
	print("CAPTURE cam_%s.png  err=%s" % [tag, str(err)])
