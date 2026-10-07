extends Node
## 补拍参赛用的截图 —— 换成**中景**取景。
##
## 为什么要重拍：上一版全在「最小缩放」下拍，绿洲只占画面一角，
## 周围一大片空沙地，于是：
##   · 整张偏灰（空沙地拉低了对比度，实测事件卡那张对比度只有 9，糊成一片）
##   · 事件卡压在空沙地上、几乎读不出内容
## 中景让绿洲与建筑充满画面，颜色和可读性都回来了。
##
## 用法：Godot_v4.7.2-stable_win64_console.exe --path scripts res://scenes/capture_submit.tscn

var _play: Node
var _gs: Node


func _ready() -> void:
	_play = load("res://scenes/play.tscn").instantiate()
	add_child(_play)
	await get_tree().process_frame
	await get_tree().process_frame
	_gs = _play.get_node("GameState")

	# 统一先把局面推到"建设完成"的样子：六段井、满水位、人口与治安都好看
	_gs.state["karez"]["sections"] = 6
	_gs.state["karez"]["reservoir_level"] = 3
	_gs.state["resources"]["water"]["current"] = 2400.0
	_gs.state["resources"]["food"]["grain"] = 180.0
	_gs.state["resources"]["food"]["nang"] = 60.0
	_gs.state["resources"]["silver"] = 160.0
	_gs.state["population"] = 8
	_gs.state["stats"]["morale"] = 82.0
	_gs.state["stats"]["security"] = 84.0
	_gs.state["calendar"]["season"] = "autumn"
	_gs.state["calendar"]["phase"] = "afternoon"
	_gs.state_changed.emit()
	await _wait_flash()

	# 关掉自动跟随，自己摆机位（中景：绿洲充满画面）
	_play._follow = false

	# ── A 绿洲全景（中景）──
	_play._set_zoom(2)
	_play._cam.position = Vector2(300.0, 190.0)
	await _wait_flash()
	await _shot("sub_A_绿洲中景")

	# ── B 事件卡（中景，村庄在卡片后面）──
	var e: Dictionary = _play._events.trigger_random()
	if e.is_empty():
		_play._hud.show_notice("【事件】商队到了", "一支从东边来的商队想在驿站歇脚，要谈食宿与草料。", "manage")
	else:
		_play._hud.show_event(e)
	await _wait_flash()
	await _shot("sub_B_事件卡中景")
	if _play._hud._popup != null:
		_play._hud._popup.visible = false

	# ── C 冬季雪景（四季表现，用真实游戏画面而不是白底对比图）──
	_gs.state["calendar"]["season"] = "winter"
	_gs.state["calendar"]["phase"] = "morning"
	_gs.state_changed.emit()
	await _play._map.refresh()
	await _wait_flash()
	await _shot("sub_C_冬季雪景")

	# ── D 春季 · 花与绿意（另一季，做对照）──
	_gs.state["calendar"]["season"] = "spring"
	_gs.state_changed.emit()
	await _play._map.refresh()
	await _wait_flash()
	await _shot("sub_D_春季花木")

	# ── E 畜牧页（中景取景）──
	_gs.state["calendar"]["season"] = "summer"
	_gs.state["livestock"] = {"sheep": 9, "goat": 5, "camel": 2, "donkey": 3, "chicken": 7}
	_gs.state_changed.emit()
	await _play._map.refresh()
	await _wait_flash()
	_play._hud.set_animal_source(func() -> Dictionary: return _play._animal_panel_data())
	_play._hud._toggle_animal_panel()
	await _wait_flash()
	await _shot("sub_E_畜牧中景")

	get_tree().quit(0)


## 等换季色罩完全淡出。
## ⚠ 必须等**墙上时间**：色罩是 0.9 秒淡出，而 _settle 等的是帧数，
##   本机约 200fps，等 20 帧只有 0.1 秒 —— 截图会拍在色罩还盖着的时候，
##   整张图糊成一片纯色。这正是参赛图颜色奇怪的真正原因。
func _wait_flash() -> void:
	await get_tree().create_timer(1.6).timeout
	await _settle(6)


func _settle(frames := 8) -> void:
	for i in range(frames):
		await get_tree().process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://%s.png" % name)
	print("  已截图 %s" % name)
	await get_tree().process_frame
