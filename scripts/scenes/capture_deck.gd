extends Node
## 为答辩 PPT 补拍一组当前版本的实机截图。
##
## 为什么不能用旧截图：地图在「镜头缩放 + 扩图」那一轮从 40x22 格扩到了 56x32 格，
## S6/S7 那些绿洲截图是扩图**之前**的画面 —— 拿去做 PPT 就是在展示一个不存在的版本。
## 所以关键的几张一律重拍。
##
##   tools\Godot_v4.7.2-stable_win64_console.exe --path scripts res://scenes/capture_deck.tscn

var _play: Node
var _gs: Node


func _ready() -> void:
	_play = load("res://scenes/play.tscn").instantiate()
	add_child(_play)
	await get_tree().process_frame
	await get_tree().process_frame
	_gs = _play.get_node("GameState")
	# 不让低治安触发来袭横幅，把画面留给要展示的东西
	_gs.state["stats"]["security"] = 78.0

	# ── A 绿洲全景：挖通六段 + 满水位 ──
	_gs.state["karez"]["sections"] = 6
	_gs.state["karez"]["reservoir_level"] = 3
	_gs.state["resources"]["water"]["current"] = 2400.0
	_gs.state["stats"]["morale"] = 70.0
	_gs.state["stats"]["security"] = 78.0
	_gs.state["season"] = "summer"
	_gs.state["calendar"]["season"] = "autumn"
	_gs.state_changed.emit()
	await _wait_flash()
	_play._follow = false
	_play._cam.position = Vector2(320.0, 200.0)
	_play._set_zoom(0)          # 缩到最小，看整片绿洲
	await _settle(30)
	await _shot("deck_A_绿洲全景")

	# ── B 分工面板 ──
	_play._hud.open_job_panel()
	await _settle()
	await _shot("deck_B_分工面板")
	_play._hud._close_pages()

	# ── C 事件卡（带插画）──
	var e: Dictionary = _play._events.trigger_random()
	if not e.is_empty():
		_play._hud.show_event(e)
	else:
		_play._hud.show_notice("【事件】商队到了", "一支从东边来的商队想在驿站歇脚，要谈食宿与草料。", "manage")
	await _settle()
	await _shot("deck_C_事件卡")
	if _play._hud._popup != null:
		_play._hud._popup.visible = false

	# ── D 御敌之战：自由布阵阶段 ──
	_gs.state["population"] = 6
	_gs.state["jobs"] = {"water": 1, "gather_wood": 1, "gather_earth": 1,
		"craft": 0, "farm": 1, "herd": 0, "guard": 2, "idle": 0}
	_gs.state_changed.emit()
	await _wait_flash()
	_play._start_raid(false)
	# ⚠ 必须等**墙上时间**：镜头飞抵是 0.55 秒的补间，而本机跑 250fps ——
	#   按帧数等（早前写 _settle(20)）只等了 0.08 秒，拍到的还是村子。
	#   这条坑在别处踩过（截图脚本等镜头飞到位），记在这里。
	await get_tree().create_timer(1.8).timeout
	if _play._battle.is_active():
		_play._battle.auto_deploy()
	await _settle(10)
	await _shot("deck_D_御敌布阵")

	# ── E 建造菜单（分页，数据驱动的 13 座）──
	_play._battle.finish()
	await get_tree().create_timer(0.6).timeout
	_gs.state["resources"]["materials"]["wood"] = 200.0
	_gs.state["resources"]["materials"]["earth"] = 200.0
	_gs.state["action_points"] = 8
	_gs.state_changed.emit()
	await _wait_flash()
	_play._hud._on_build_pressed()
	await _settle()
	await _shot("deck_E_建造菜单")
	# 第 3 页：应当看到最后 3 座（围墙/烽燧/居所…）
	_play._hud._build_page = 2
	_play._hud._refresh_build_menu()
	await _settle()
	await _shot("deck_F_建造菜单第3页")
	get_tree().quit(0)


## 等换季色罩淡完 —— 必须等**墙上时间**，色罩 0.9 秒淡出，
## 而 _settle 等帧数（本机约 200fps，20 帧只有 0.1 秒），
## 否则截图会拍在色罩还盖着的时候、整张糊成一片纯色。
func _wait_flash() -> void:
	await get_tree().create_timer(1.6).timeout
	await _settle(6)


func _settle(frames := 8) -> void:
	for i in range(frames):
		await get_tree().process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("user://%s.png" % name)
	print("  已截图 %s" % name)
	await get_tree().process_frame
