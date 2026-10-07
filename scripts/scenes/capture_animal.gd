extends Node
## 截图核对：畜牧页 + 灾难日志。
##
## 为什么必须截图：面板这种东西"逻辑对"和"看得见"是两件事 ——
## 宽度不够会截断、按钮会叠、字会被裁。项目里已经有过一次
## 「镜头读数两端被裁掉、实机只看得见中间一截」，所以一律看图确认。
##
##   tools\Godot_v4.7.2-stable_win64_console.exe --path scripts res://scenes/capture_animal.tscn

var _play: Node
var _gs: Node


func _ready() -> void:
	_play = load("res://scenes/play.tscn").instantiate()
	add_child(_play)
	await get_tree().process_frame
	await get_tree().process_frame
	_gs = _play.get_node("GameState")
	# 关掉底部输入框与开场提示，让右栏成为画面主角
	if _play._hud._bottom != null:
		_play._hud._bottom.visible = true

	# ── A：有牲畜的畜牧页 ──
	_gs.state["population"] = 6
	_gs.state["jobs"] = {"water": 1, "gather_wood": 1, "gather_earth": 0,
		"craft": 0, "farm": 1, "herd": 2, "guard": 1, "idle": 0}
	_gs.state["buildings"]["majiu"] = {"level": 1, "condition": 100.0}
	_gs.state["livestock"] = {"sheep": 5, "goat": 2, "camel": 0, "donkey": 1, "chicken": 4}
	_gs.state["resources"]["food"]["grain"] = 60.0
	# ⚠ 治安要调高：低治安会触发每日来袭判定，战斗横幅会**盖住畜牧页**，
	#   拍出来的图看不清面板本身（第一版就是这样）。
	_gs.state["stats"]["security"] = 75.0
	_gs.state["calendar"]["day"] = 1
	if _play._battle.is_active():
		_play._battle.finish()
		_play._hud.hide_battle_panel()
	_gs.state_changed.emit()
	_play._hud._toggle_animal_panel()
	await get_tree().process_frame
	await get_tree().process_frame
	await _shot("animal_A_有牲畜")

	# ── B：空栏（看"抓野畜"这条入口） ──
	_gs.state["livestock"] = {"sheep": 0, "goat": 0, "camel": 0, "donkey": 0, "chicken": 0}
	_gs.state["jobs"]["herd"] = 0
	_gs.state["stats"]["security"] = 75.0
	_gs.state_changed.emit()
	_play._hud.refresh_animal_panel(_play._animal_panel_data())
	await get_tree().process_frame
	await _shot("animal_B_空栏")

	# ── C：灾难日志 ──
	_gs.state["livestock"] = {"sheep": 5, "goat": 2, "camel": 0, "donkey": 1, "chicken": 4}
	_gs.state["jobs"]["herd"] = 2
	# 手动落一次沙暴，再走一天的结算，看日志里报不报
	var sb: Dictionary = {}
	for c in _gs.disasters_cfg():
		if str(c["id"]) == "sandstorm":
			sb = c
	seed(5)
	_gs._apply_disaster(sb)
	_gs.state["disaster"]["log"] = "%s：%s" % [str(sb.get("display", "")), "失水 10 方　士气 -5　牲畜 -1 头"]
	_gs.state["disaster"]["last_id"] = "sandstorm"
	_play._last_disaster_report = ""
	_play._report_daily_events()
	await get_tree().process_frame
	await _shot("animal_C_灾难日志")

	# ── D：牲畜画在地图上（马厩旁边） ──
	# 镜头必须挪过去：默认镜头在村子中心，马厩在 (31, 15.5) 格 = (496, 248) px，
	# 默认视野 x 160..480 正好差一点切在边上（第一版就拍了个空）。
	_gs.state["karez"]["sections"] = 3          # 让马厩的地标出现
	_gs.state["livestock"] = {"sheep": 9, "goat": 6, "camel": 2, "donkey": 3, "chicken": 7}
	_gs.state["jobs"]["herd"] = 2
	_gs.state_changed.emit()
	await get_tree().process_frame
	_play._follow = false
	_play._cam.position = Vector2(496.0 - 60.0, 248.0)
	await get_tree().process_frame
	await get_tree().process_frame
	await _shot("animal_D_牧场")

	# ── E：木卡姆页（点奏乐台弹出的那个） ──
	# ⚠ 先把灾难通告卡关掉：它不属于 _close_pages() 管的子页，
	#   不关的话它会一直盖在木卡姆页上面（第一版拍出来就是一片空白）。
	if _play._hud._popup != null:
		_play._hud._popup.visible = false
	_gs.state["karez"]["sections"] = 5            # 奏乐台 gate 是 sections >= 3
	_gs.state["resources"]["materials"]["instrument"] = 2.0
	_gs.state["action_points"] = 5
	_gs.state["stats"]["security"] = 75.0
	_gs.state_changed.emit()
	await get_tree().process_frame
	_play._hud._toggle_music_panel()
	_play._hud.refresh_music_panel(_play._music_panel_data())
	await get_tree().process_frame
	await get_tree().process_frame
	await _shot("animal_E_木卡姆")
	get_tree().quit(0)


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("user://%s.png" % name)
	print("  已截图 %s" % name)
	await get_tree().process_frame
