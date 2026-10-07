extends Node2D
## 主场景 —— 把地图、玩家、HUD、AI 对话、事件系统接成一个可玩循环。
##
## 这个场景取代了之前「地图场景」与「对话控制台」两个互不相干的孤立场景。
## 玩家在绿洲上走动，点竖井挖井，推进时段，和角色对话，遇事件做抉择 ——
## 全部发生在同一屏里，状态变化即时反映到地图与 HUD 上。

const SAVE_PATH := "user://karez_save.json"

## 每 N 天最多自动触发一次事件，避免天天弹窗。
const EVENT_MIN_GAP_DAYS := 2
## 跨天时自动触发事件的概率
const EVENT_CHANCE := 0.65

var _game: Node
var _events: Node
var _map: Node2D
var _villagers: Node2D
var _townfolk: Node2D
## 气氛粒子（灶上的炊烟 + 沙尘）
var _atmo: Node2D
## 昼夜光照。CanvasModulate 只影响同一个 Canvas 里的东西 ——
## HUD 挂在独立的 CanvasLayer 上，所以界面**不会**跟着变暗。
var _daylight: CanvasModulate

## 四个时段的光色。数值偏克制 —— 目的是「让时段有区别」，
## 不是做写实光照；像素画压太暗会糊成一团，看不出画的是什么。
const PHASE_LIGHT := {
	"morning":   Color(1.00, 0.97, 0.91),   # 晨：清冷里带一点暖
	"afternoon": Color(1.00, 1.00, 1.00),   # 午：中性，全亮
	"evening":   Color(1.00, 0.83, 0.68),   # 暮：暖橙，斜阳
	"night":     Color(0.56, 0.61, 0.88),   # 夜：冷蓝，压暗但不压死
}

## 四季的色调。与 PHASE_LIGHT **逐通道相乘**，所以两层叠在一起用。
## 数字都很克制 —— 像素画压太狠会糊成一团；这里的目标是
## 「一眼看出换季了」，不是写实光照。
##
## 注意：现在只是**调色**，还没有雪。冬天想要真正下雪得另做雪地贴图，
## 那是一件独立的事（见 docs 的美化清单）。
const SEASON_TINT := {
	"spring": Color(1.00, 1.00, 1.00),   # 春：不加色，让新绿自己说话
	"summer": Color(1.07, 1.02, 0.89),   # 夏：亮而偏暖，日头毒
	"autumn": Color(1.10, 0.94, 0.74),   # 秋：金黄，收获色
	"winter": Color(0.84, 0.89, 1.04),   # 冬：偏冷偏灰蓝，肃杀
}
## 换季时那一闪的颜色。
##
## ⚠ 与 SEASON_TINT 分开写、不能复用：那个是「逐通道相乘」的**调色**（数值都接近 1），
## 拿它当不透明色罩会几乎看不见。这个要的是能盖住画面的实色。
const SEASON_FLASH := {
	"spring": Color(0.85, 0.90, 0.72),   # 春：嫩绿
	"summer": Color(0.95, 0.88, 0.66),   # 夏：暖黄
	"autumn": Color(0.88, 0.66, 0.32),   # 秋：金
	"winter": Color(0.83, 0.89, 0.94),   # 冬：霜白
}
var _player: CharacterBody2D
var _hud: Control

## ── 御敌之战 ──
var _battle: Node2D
## 上一次见到的是第几天。用来检测"过了一天"，好做每日的来袭判定。
var _last_day := -1
## 这场战斗是不是由「火光从东边来」那条事件触发的（决定战果文案）
var _raid_from_event := false

## 换季色罩（全屏）。平时隐藏，只在换季那一瞬间出现。
var _fade: ColorRect
var _fade_tween: Tween
## 上一帧的季节，用来检测「换季了」。
## 初值为空串，这样**开局第一次**不会误触发一次闪屏。
var _last_season := ""

var _recent: Array = []
var _last_event_day := -99

const NAME_OF := {
	"lao_kanjiang": "老坎匠",
	"muqam_yiren": "木卡姆艺人",
	"hasake_qishou": "哈萨克骑手",
	"hanshang_zhanggui": "商队掌柜",
	"chuniang": "厨娘",
	"shenmi_lvren": "神秘旅人",
	"mafei_toumu": "马匪头目",
}


func _ready() -> void:
	randomize()

	_game = $GameState
	_events = $EventSystem
	_map = $MapView
	_villagers = $Villagers
	_townfolk = $Townfolk
	_atmo = $Atmosphere
	_player = $Player
	_daylight = $DayLight
	_hud = $HUDLayer/HUD

	# 事件系统要能写进存档，先互相认领
	_game.event_system = _events

	_events.setup(_game)
	_map.setup(_game)
	# 居民要在状态层之后初始化：它靠 state_changed 信号跟随分工变化
	_villagers.setup(_game, _map)
	# 地图上的七个角色：点他 / 走近按 E，都会切到底栏并用那个人开始对话
	_townfolk.setup(_player, _game)
	_atmo.setup(_game, _map)
	_townfolk.talk_requested.connect(_on_talk_to)
	_hud.setup(_game, _events)

	# ── 换季色罩：放在最上层 CanvasLayer，才盖得住地图与 HUD ──
	# mouse_filter 必须是 IGNORE：它平时不可见，但一旦吃掉鼠标就没法操作了。
	var fade_layer := CanvasLayer.new()
	fade_layer.layer = 20
	add_child(fade_layer)
	_fade = ColorRect.new()
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.color = Color(1, 1, 1, 0.0)
	_fade.visible = false
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_layer.add_child(_fade)

	# ── 镜头 ──
	# 挂在 Play（世界层的父节点）下，这样它只影响世界，不影响 HUD 的 CanvasLayer。
	_cam = Camera2D.new()
	_cam.zoom = Vector2.ONE * float(ZOOM_STEPS[ZOOM_DEFAULT])
	_cam.position = _player.position if _player != null else Vector2.ZERO
	add_child(_cam)
	_cam.make_current()
	_clamp_camera()
	# 让 HUD 一开始就显示正确的档位与跟随状态
	_readout()

	# 昼夜光照跟着时段走
	if not _game.state_changed.is_connected(_apply_phase_light):
		_game.state_changed.connect(_apply_phase_light)
	_apply_phase_light()

	_start_music()

	# 演示入口：带 --battle 启动就直接开到御敌战场（见 启动_御敌演示.bat）
	_maybe_start_demo_battle()
	_maybe_start_demo()

	_hud.dig_requested.connect(_on_dig)
	_hud.build_requested.connect(_on_build)
	_hud.next_phase_requested.connect(_on_next_phase)
	_hud.event_requested.connect(_on_event_manual)
	_hud.save_requested.connect(_on_save)
	_hud.load_requested.connect(_on_load)
	_hud.say_requested.connect(_on_say)
	_map.shaft_pressed.connect(_on_shaft_pressed)
	_map.site_pressed.connect(_on_site_pressed)
	# 鼠标停在地图上某个地标上 → 显示它的说明浮层；移开 → 收起。
	# 文案与「门槛/坐标」同源，都在 core/sites.gd 的 PLACES[id]["desc"] 里。
	_map.site_hovered.connect(_hud.show_site_tip)
	_map.site_unhovered.connect(_hud.hide_site_tip)

	# ── 战斗系统 ──
	_battle = $Battle
	_battle.setup(_game)
	_battle.started.connect(_on_battle_started)
	_battle.deploy_changed.connect(_on_battle_deploy)
	_battle.ended.connect(_on_battle_ended)
	_hud.battle_auto_requested.connect(func() -> void: _battle.auto_deploy())
	_hud.battle_clear_requested.connect(func() -> void: _battle.clear_deploy())
	_hud.battle_fight_requested.connect(func() -> void: _battle.begin_fight())
	_hud.battle_close_requested.connect(_on_battle_close)
	_hud.battle_requested.connect(_on_battle_manual)
	# ── 畜牧 / 涝坝 ──
	_hud.catch_requested.connect(_on_catch_requested)
	_hud.reservoir_requested.connect(_on_reservoir_requested)
	# HUD 不直接碰 GameState：把"怎么取畜牧信息"注入进去（界面只渲染，逻辑在 core）
	_hud.set_animal_source(func() -> Dictionary: return _animal_panel_data())
	# ── 木卡姆 ──
	_hud.muqam_requested.connect(_on_muqam_requested)
	_hud.set_music_source(func() -> Dictionary: return _music_panel_data())
	# 事件系统结算后看一眼：如果是"火光从东边来"，就该打起来了
	if not _events.event_resolved.is_connected(_on_event_resolved):
		_events.event_resolved.connect(_on_event_resolved)
	# 每日的低治安来袭判定
	if not _game.state_changed.is_connected(_check_daily_raid):
		_game.state_changed.connect(_check_daily_raid)

	_game.response_received.connect(_on_response)
	_game.request_failed.connect(_on_failed)

	# 教程必须塞进日志的 3 行里 —— 写多了会被顶掉，玩家只看到后半截
	_hud.append_log("[b]《坎儿井》[/b] 水只够 7 天、粮只够 4 天 —— 挖通竖井才能活。")
	_hud.append_log("[color=#8fd3ff]①[/color]顶栏按「功能」挖井、派人　[color=#8fd3ff]②[/color]这里选「对谁说」，再打字")
	_hud.append_log("[color=#8fd3ff]③[/color]「推进时段」×4 = 过一天。看顶栏第三行的提示。")

	# 右侧功能栏默认隐藏，地图整片留给玩家。但首次启动要把分工页拉出来 ——
	# 用户实机反馈「不知道该怎么派人」，说明光有按钮不够。
	# 教程在底栏，所以底栏也先开着；玩家随时可以用「对话」按钮收起。
	# ⚠ 不再自动弹底栏。
	# 原来开局会 show_bottom_panel() + open_job_panel() 做引导，
	# 但用户截图确认**底栏压住了地图最下面一排**（聚落、居民都在那儿），
	# 等于一开局就看不全村子 —— 与「主地图不能被挡住」这条硬要求冲突。
	# 现在两个面板都默认隐藏，由顶栏的「功能」「对话」按钮开关；
	# 该做什么改用顶栏第三行那句话提示（那里本来就写着「点哪里」）。
	_hud.refresh()

	_probe_ai()


## ── 镜头（缩放与平移）──
##
## 为什么需要：地图这一轮从 40x22 扩到 56x32（面积 2 倍），一屏再也装不下 ——
## 没有镜头就只能看到村子那一角，新扩出来的沙漠永远看不见。
##
## 缩放用**离散档位**而不是连续值。像素画在非整数缩放下会抖：
## 一格是 16 逻辑 px、在窗口里是 32 物理 px，乘 0.7 变成 22.4，
## 相邻像素会随机多一个少一个，边缘一直在闪。
## 档位全取 0.25 的倍数，保证 32×zoom 始终是整数（16/24/32/40/48/64/80/96）。
const ZOOM_STEPS := [0.5, 0.75, 1.0, 1.25, 1.5, 2.0, 2.5, 3.0]
## 默认 1.0：正好看到聚落那一带（约 40x22 格），和扩图之前的视野基本一致；
## 想看到整张地图就往下滚一档（0.5 时 1280x720 世界像素，整张 896x512 全进画面）。
const ZOOM_DEFAULT := 2
var _cam: Camera2D
var _zoom_i := ZOOM_DEFAULT
## 镜头是否跟随主角。中键拖拽平移时会自动关掉（否则会跟用户抢镜头），
## 按 F 或双击再打开。
var _follow := true
var _pan_drag := false
## 左键拖拽平移用。_left_from 是按下时的屏幕位置，
## 要越过阈值才认作"拖拽"（否则一次手抖的点击也会把镜头带走）。
var _left_from := Vector2.ZERO
var _left_panning := false
## 上一次报过的灾难日志。同一场灾只报一次，不然连续几天都在刷同一行。
var _last_disaster_report := ""


func _process(delta: float) -> void:
	# 事件弹窗打开时冻结角色，避免选选项时人还在走
	if _player != null and _hud != null:
		_player.set_physics_process(not _hud.popup_visible())
	# 镜头平滑跟随主角
	if _cam != null and _follow and _player != null:
		var target := _player.position + Vector2(0, -10)
		_cam.position = _cam.position.lerp(target, clampf(delta * 7.0, 0.0, 1.0))
		_clamp_camera()


## 把镜头夹在地图范围内，免得滚到地图外看见空白。
func _clamp_camera() -> void:
	if _cam == null or _map == null:
		return
	var vp := get_viewport_rect().size / _cam.zoom
	var world := Vector2(float(_map.COLS) * float(_map.TILE),
		float(_map.ROWS) * float(_map.TILE))
	var half := vp * 0.5
	var p := _cam.position
	# 视口比地图还大的时候居中，否则夹在边界内
	p.x = world.x * 0.5 if world.x <= vp.x else clampf(p.x, half.x, world.x - half.x)
	p.y = world.y * 0.5 if world.y <= vp.y else clampf(p.y, half.y, world.y - half.y)
	_cam.position = p


## 镜头读数。跟随状态要一起说，否则玩家不知道按 F 有什么用。
func _readout() -> void:
	if _hud != null and _hud.has_method("set_zoom_readout"):
		_hud.set_zoom_readout(float(ZOOM_STEPS[_zoom_i]), _follow)


func _set_zoom(i: int) -> void:
	_zoom_i = clampi(i, 0, ZOOM_STEPS.size() - 1)
	if _cam == null:
		return
	var z := float(ZOOM_STEPS[_zoom_i])
	# 用补间过渡，但**终值一定落在档位上** —— 否则又回到非整数缩放
	var tw := create_tween()
	tw.tween_property(_cam, "zoom", Vector2(z, z), 0.16)
	_clamp_camera()
	_readout()


## 演示导演的按键处理。
##
## ⚠ **必须挂在 `_input` 而不是 `_unhandled_input`。**
##   用户实机反馈过「点空格没用了」—— 原因是那时焦点在底部聊天输入框里，
##   被焦点的 `LineEdit` 会把空格当成打字先吃掉，事件根本传不到 `_unhandled_input`，
##   而演示拦截挂在那里就收不到键。`_input` 在 GUI 处理**之前**跑，抢得到。
##
## ⚠ 但也不能一刀切全抢：真在打字时，空格该归输入框。
##   所以判据是「**焦点不在输入框里**才用空格推进」，而
##   `→ / ← / H / R` 这些打字用不到的键**永远生效**。
func _input(event: InputEvent) -> void:
	if not _demo_on:
		return
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	# ⚠ event.keycode 是 Variant，写 := 会解析报错
	var dk: int = event.keycode

	if dk == KEY_H:
		_demo_layer.visible = not _demo_layer.visible
		get_viewport().set_input_as_handled()
		return
	if dk == KEY_R:
		_demo_go(0)
		get_viewport().set_input_as_handled()
		return
	if dk == KEY_F1:
		var fo := get_viewport().gui_get_focus_owner()
		print("[演示] 第 %d/%d 屏  提示条=%s  焦点=%s  在打字=%s"
			% [_demo_i + 1, DEMO_BEATS.size(),
			   "显示" if _demo_layer.visible else "隐藏",
			   ("无" if fo == null else fo.get_class()), str(_demo_typing())])
		get_viewport().set_input_as_handled()
		return
	# ⚠ **空格一律前进**，不再"让给输入框"。
	#   上一版写成"焦点在输入框里就让给输入框"，结果按下去**毫无反馈**，
	#   人直接卡住 —— 而用户又按过 H 把提示条藏了，连"请改用 →"都看不到。
	#   录视频时可预测比礼貌重要：按空格就该前进。
	#   代价是聊天框里打不出空格字符；中文聊天本来不用空格，可以接受。
	if dk == KEY_RIGHT or dk == KEY_SPACE or dk == KEY_PAGEDOWN or dk == KEY_N:
		_demo_step_by(1)
		get_viewport().set_input_as_handled()
	elif dk == KEY_LEFT or dk == KEY_PAGEUP or dk == KEY_P:
		_demo_step_by(-1)
		get_viewport().set_input_as_handled()


## 移动 d 屏。**到边界时给反馈**，不要静默夹住 ——
## 上一次按了没反应，用户以为是"卡住了"，其实就是已经在最后一屏。
func _demo_step_by(d: int) -> void:
	var want := _demo_i + d
	if want < 0:
		_demo_flash("已是第一屏（3 秒后自动回到第 1 屏）")
		_demo_go(0)
		return
	if want >= DEMO_BEATS.size():
		_demo_flash("**已是最后一屏**　按 R 从头开始重录，或按 ← 返回")
		return
	_demo_go(want)


## 临时把提示条亮出来并写一行字，过一会儿恢复本屏说明。
## 提示条被 H 藏起来时也会强制亮一次 —— 否则用户看不到任何反馈。
func _demo_flash(msg: String) -> void:
	if _demo_layer == null:
		return
	_demo_layer.visible = true
	if _demo_note != null:
		_demo_note.text = msg
	_demo_flash_pending += 1
	var mine := _demo_flash_pending
	await get_tree().create_timer(2.0).timeout
	# 只有"最后一次 flash"才恢复，避免连按时互相覆盖
	if mine == _demo_flash_pending:
		_demo_refresh_bar()


## 按当前屏号重画提示条上的三行字。
func _demo_refresh_bar() -> void:
	if _demo_step == null or _demo_i < 0 or _demo_i >= DEMO_BEATS.size():
		return
	var b: Dictionary = DEMO_BEATS[_demo_i]
	_demo_step.text = "演示  %02d / %d" % [_demo_i + 1, DEMO_BEATS.size()]
	_demo_title.text = str(b.get("t", ""))
	_demo_note.text = ("%s　｜　空格/→ 下一屏　← 上一屏　H 隐藏　R 重来　F1 报状态"
		% str(b.get("d", "")))


## 焦点是不是在某个可输入的框里（底部聊天输入框）。是的话空格要留给它。
func _demo_typing() -> bool:
	var fo := get_viewport().gui_get_focus_owner()
	return fo is LineEdit or fo is TextEdit


func _unhandled_input(event: InputEvent) -> void:
	# ── 滚轮缩放 ──
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_set_zoom(_zoom_i + 1)
			get_viewport().set_input_as_handled()
			return
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_set_zoom(_zoom_i - 1)
			get_viewport().set_input_as_handled()
			return
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			_pan_drag = true
			_follow = false
			_readout()
			get_viewport().set_input_as_handled()
			return

	# ── 左键拖拽平移 ──
	#
	# ⚠ 这一条是**补出来**的，也是用户报「平行移动移动不了」的真正原因：
	#   原先只做了**中键**拖拽，而笔记本触控板根本没有中键 ——
	#   就算有，大家本能去试的也是左键拖拽。实测（tests/input_probe）证明
	#   "只有中键可用" 在实机上等于 "平移动不了"。
	#
	# 为什么放在 _unhandled_input 里是安全的：只有**没被消费掉**的左键事件
	# 才会传到这里 —— 点竖井、拖建筑、点 NPC、点战场槽位都在各自的节点里
	# 先消费掉了。所以加这一条不会影响任何既有操作。
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_left_from = event.position
			_left_panning = false
			return
		if _left_panning:
			_left_panning = false
			get_viewport().set_input_as_handled()
			return
		return

	if event is InputEventMouseMotion:
		var mev := event as InputEventMouseMotion
		# 左键拖动：先要越过 5px 阈值才算"拖拽"，否则一次手抖的点击也会把镜头带走
		if (mev.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			if not _left_panning:
				if mev.position.distance_to(_left_from) <= 5.0:
					return
				_left_panning = true
				_follow = false
				_readout()
			_cam.position -= mev.relative / _cam.zoom
			_clamp_camera()
			get_viewport().set_input_as_handled()
			return
		# 中键拖动
		if _pan_drag:
			# relative 是屏幕像素，除以 zoom 才是世界像素 —— 否则缩放越大拖得越"慢"
			_cam.position -= mev.relative / _cam.zoom
			_clamp_camera()
			get_viewport().set_input_as_handled()
			return

	if event is InputEventMouseButton and not event.pressed \
			and event.button_index == MOUSE_BUTTON_MIDDLE:
		_pan_drag = false
		return

	# ── 键盘：F 跟随主角；+/- 缩放（笔记本没有滚轮时用）──
	if event is InputEventKey and event.pressed and not event.echo:
		# ⚠ 必须先转成 InputEventKey 再取键码：event 声明为 InputEvent，
		#   即使前面 is 判断过，GDScript 也**不会**窄化类型 ——
		#   直接写 `var k := event.physical_keycode` 会撞上本项目
		#   「禁止从 Variant 推断类型」那条规则，整个脚本解析失败。
		var kev := event as InputEventKey
		var k: int = kev.physical_keycode
		if k == KEY_F:
			_follow = true
			_readout()
			get_viewport().set_input_as_handled()
		elif k == KEY_EQUAL or k == KEY_KP_ADD:
			_set_zoom(_zoom_i + 1)
			get_viewport().set_input_as_handled()
		elif k == KEY_MINUS or k == KEY_KP_SUBTRACT:
			_set_zoom(_zoom_i - 1)
			get_viewport().set_input_as_handled()


# ---------------------------------------------------------------------------
# AI 服务连通性
# ---------------------------------------------------------------------------

## 地图上点了某个人 / 走近按了 E —— 切到那个人并打开对话栏。
## 下拉框和地图是同一个入口的两种走法，所以要互相同步：
## 在地图上点了厨娘，底栏的「对谁说」也要跟着变成厨娘。
func _on_talk_to(cid: String) -> void:
	_hud.focus_speaker(cid)
	_hud.show_bottom_panel()


## 按当前时段给整张地图上光。CanvasModulate 只作用于世界这一层，
## HUD 在独立 CanvasLayer 上，所以界面不受影响。
##
## 为什么值得做：游戏本来就有 晨/午/暮/夜 四时段，但改时段画面毫无变化 ——
## 「过了半天」这件事玩家感觉不到。上光之后，推进时段本身就有了反馈。
func _apply_phase_light() -> void:
	if _daylight == null or _game == null:
		return
	var ph := str(_game.query("calendar.phase"))
	var se := str(_game.query("calendar.season"))
	var c: Color = PHASE_LIGHT.get(ph, Color.WHITE)
	var s: Color = SEASON_TINT.get(se, Color.WHITE)
	# 时段 × 季节，逐通道相乘 —— 于是「冬夜」自然比「夏夜」更冷更暗
	var target := Color(c.r * s.r, c.g * s.g, c.b * s.b, 1.0)
	# 用补间而不是直接赋值：时段切换是「天慢慢暗下来」，不是啪一下关灯。
	var tw := create_tween()
	tw.tween_property(_daylight, "color", target, 0.6)

	# ── 换季：闪一下 ──
	# 放在这个函数里，是因为它已经挂在 state_changed 上了，不必再接一根线。
	# 但**必须在换季时把地形重建也一起盖住** —— 四季是同一帧全部换掉的
	# （地形、植被、光色一起变），看起来像画面闪了下故障，而不像"入冬了"。
	if _last_season != "" and _last_season != se:
		_play_season_flash(se)
	_last_season = se


## 换季过渡：整屏按季节色调闪一下，把「贴图整套瞬间换掉」这件事盖过去。
##
## 节奏是**快进慢出**（0.35 秒盖上、0.9 秒退开）：盖得干脆才像换季，
## 慢慢淡入会像画面被染色。
## 灾难的画面表现。用和换季闪光同一个 _fade 层。
##
## 为什么值得做：灾难只写在日志里的话，玩家很容易整场都没注意到自己遭了灾，
## 只看到顶栏数字莫名其妙变了。**画面是"这件事发生了"的第一通知。**
##
## 与换季闪光的差别是刻意的：换季**快进快出**（干脆），灾难**慢压慢退**
## （0.5 秒压上、1.6 秒退开）—— 要的是"天压下来了"那种感觉。
const DISASTER_FLASH := {
	"sand":   Color(0.82, 0.62, 0.30),   # 沙暴：土黄压过来
	"heat":   Color(0.88, 0.52, 0.22),   # 大旱：灼橙
	"water":  Color(0.32, 0.58, 0.78),   # 洪水：浊蓝
	"cold":   Color(0.62, 0.78, 0.95),   # 寒潮：冷青
	"sick":   Color(0.52, 0.68, 0.38),   # 瘟疫：病绿
	"locust": Color(0.70, 0.64, 0.26),   # 蝗灾：枯黄
}


## 灾难 id → 它该用哪种画面色调。数据里没写就返回 ""（用兜底色）。
func _disaster_screen_of(did: String) -> String:
	var c := _disaster_by_id(did)
	return str(c.get("screen", "")) if not c.is_empty() else ""


func _disaster_by_id(did: String) -> Dictionary:
	if did == "":
		return {}
	for c in _game.disasters_cfg():
		if str(c.get("id", "")) == did:
			return c
	return {}


func _play_disaster_flash(screen: String) -> void:
	if _fade == null:
		return
	var col: Color = DISASTER_FLASH.get(screen, Color(0.70, 0.40, 0.30))
	_fade.color = Color(col.r, col.g, col.b, 0.0)
	_fade.visible = true
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_property(_fade, "color:a", 0.55, 0.5)
	_fade_tween.tween_property(_fade, "color:a", 0.0, 1.6)
	_fade_tween.tween_callback(func() -> void:
		if _fade != null:
			_fade.visible = false)


func _play_season_flash(season: String) -> void:
	if _fade == null:
		return
	var col: Color = SEASON_FLASH.get(season, Color(0.90, 0.85, 0.70))
	_fade.color = Color(col.r, col.g, col.b, 0.0)
	_fade.visible = true
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_property(_fade, "color:a", 0.82, 0.35)
	_fade_tween.tween_property(_fade, "color:a", 0.0, 0.90)
	_fade_tween.tween_callback(func() -> void:
		if _fade != null:
			_fade.visible = false)


# ---------------------------------------------------------------------------
# 御敌之战
# ---------------------------------------------------------------------------
#
# 三个入口，都汇到 _start_raid()：
#   ① 事件「火光从东边来」(cri_raid_night) 结算后 —— 剧情驱动的来袭
#   ② 每日判定：治安太低时可能被打 —— 玩法驱动的来袭
#   ③ HUD 功能栏的「御敌」按钮 —— 玩家自己做主（也方便演示与测试）

## 人数上限就是布阵槽位数，再多没地方站。
const BATTLE_MAX_FIGHTERS := 6

## 开战前的人口，用来在战果里说清"这一仗到底影响了几个人"。
var _pop_before_battle := 0


## ── 演示入口：直接把游戏开到御敌布阵 ──
##
## 用法（见 启动_御敌演示.bat）：
##     Godot_v4.7.2-stable_win64.exe --path scripts -- --battle
##
## 为什么要有它：正常触发一场御敌要满足「治安 < 45 且掷骰命中」或者推进到第 15 天
## 遇上「火光从东边来」，演示和验收时没人愿意先玩十几分钟。
## 带这个参数启动就跳过前置，直接给一个能打的局面 + 跳到战场。
##
## ⚠ 它只改**内存里的状态**，不写存档。演示完别点「存档」，否则会把演示局面存下去。
func _maybe_start_demo_battle() -> void:
	if not _has_cli_flag("--battle"):
		return
	_game.state["population"] = 6
	_game.state["karez"]["sections"] = 4
	_game.state["stats"]["security"] = 30.0
	_game.state["resources"]["materials"]["wood"] = 200.0
	_game.state["resources"]["materials"]["earth"] = 300.0
	# 给一份**覆盖到三种兵种**的分工，否则演示里看不到兵种差异：
	# 守卫 2 → 盾卫×2、采集 2 → 弓手×2、其余 → 乡勇
	_game.state["jobs"] = {"water": 1, "gather_wood": 1, "gather_earth": 1,
		"craft": 0, "farm": 1, "guard": 2, "idle": 0}
	_game.clamp_all()
	_game.state_changed.emit()
	# 等一帧再开打：_ready 里刚建好的 HUD 面板需要先完成一次布局
	await get_tree().create_timer(0.35).timeout
	_start_raid(true)
	print("[演示] --battle 生效：已进入御敌布阵  phase=%d  我方 %s vs 敌方 %d 人" % [
		_battle.current_phase(), _battle.roster_summary(), _battle._enemy_count])
	_hud.append_log("[color=#e8c79a]【演示】已直接进入御敌布阵。"
		+ "布阵区里随便站：点空地放人 / 按住人拖动 / 拖到左边候补框收回。摆好再点「开战」。[/color]")


## 命令行里有没有这个参数。先看 `--` 之后的用户参数（推荐传法），再退回全量参数 ——
## 后者是为了兼容不带 `--` 直接写的情况。
func _has_cli_flag(flag: String) -> bool:
	for a in OS.get_cmdline_user_args():
		if str(a) == flag:
			return true
	for a in OS.get_cmdline_args():
		if str(a) == flag:
			return true
	return false


func _on_battle_manual() -> void:
	_start_raid(false)


## 事件结算后的钩子。**判据是选项上的 battle 标记，不是事件 id。**
##
## ⚠ 这里原来写的是 `if event_id != "cri_raid_night": return` —— 看着能用，
##   但那条件件有三个选项：迎战 / 先派人谈判 / 放弃外院。
##   按 id 判断的话，选"谈判"（花银两买平安）和"放弃外院"（拆木料止损）
##   也会照样打起来 —— 玩家的选择被无视了。
##   数据里本来就给"迎战"那一项打了 battle 标记，按标记走才对。
func _on_event_resolved(event_id: String, choice_index: int, _outcome: String) -> void:
	var ev: Dictionary = _events.find_event(event_id)
	if ev.is_empty():
		return
	var choices: Array = ev.get("choices", [])
	if choice_index < 0 or choice_index >= choices.size():
		return
	var ch: Dictionary = choices[choice_index]
	if not bool(ch.get("battle", false)):
		return
	# 等弹窗收起来再开打，否则玩家还在看事件卡、镜头已经飞走了
	await get_tree().create_timer(0.7).timeout
	_start_raid(true)


## 每日的低治安来袭判定。
##
## 为什么要有它：只靠事件触发的话，玩家可以把治安一直放着不管而永不挨打 ——
## 「守卫」这个岗位就失去了意义。治安低于 45 时每过一天掷一次骰子，
## 于是"不设防"变成一件有代价的事。
func _check_daily_raid() -> void:
	var d := int(_game.query("day"))
	if d == _last_day:
		return
	_last_day = d
	if _battle.is_active() or _battle.current_phase() != 0:
		return
	var sec := float(_game.query("stats.security"))
	if sec >= 45.0:
		return
	if randf() < 0.28:
		_start_raid(false)


func _start_raid(from_event: bool) -> void:
	if _battle == null or _battle.is_active():
		return
	_raid_from_event = from_event
	var pop := int(_game.query("population"))
	_pop_before_battle = pop
	# ── 能上阵的人是**按分工**算出来的 ──
	# 留 1 个看家，其余按各自岗位转成兵种：守卫→盾卫、采集→弓手、其余→乡勇/平民。
	# 于是"分工面板里怎么派人"直接决定战场上有什么兵 —— 这是兵种这个系统的意义所在。
	var roster: Array = _game.battle_roster(maxi(1, pop - 1))
	if roster.is_empty():
		roster = ["militia"]
	# ── 来袭人数：跟随**能上阵的人数**，再加天数增长 ──
	#
	# ⚠ 原来是 `2 + 天数/8`，第 1 天固定 2 人。后果是 5 打 2 纯碾压 ——
	#   加了兵种、做了自由站位，实测连打三场都是"胜，0 阵亡"，
	#   兵种强不强、阵型摆得好不好**一点都看不出来**。
	#   人数差 2.5 倍时，什么战术都归零。
	#   现在人数跟着走，5 人上阵就来 4 个，天数越大越多（上限见 numbers.json）。
	var raid: Dictionary = _game.numbers.get("battle", {}).get("raid", {})
	var per_days: int = maxi(1, int(raid.get("per_days", 8)))
	var enemies := roster.size() + int(raid.get("offset", -1)) \
		+ int(int(_game.query("day")) / per_days)
	enemies = clampi(enemies, int(raid.get("clamp_min", 2)), int(raid.get("clamp_max", 8)))
	_battle.start(roster, enemies)
	# 镜头飞到东边战场并放大 —— 用户要的"跳转到敌军攻来的地方的放大图"。
	#
	# ⚠ 瞄准点要比战场中心**再高 44px**：战斗横幅压在顶栏下方（y=84~146），
	#   如果镜头正对战场中心，第一排人就正好落在横幅底下（实机截图确认过）。
	#   把镜头往上挪，战场在画面上就整体下移，两排人都落在横幅之下。
	_fly_to(_battle.ARENA_CENTER + Vector2(0, -44), 5)      # 档位 5 = ×2.0


## 把镜头平滑送到某处并切到指定档位。
## 过程中必须关掉跟随，否则 _process 里每帧都会把镜头拽回主角身上。
func _fly_to(target: Vector2, zoom_i: int) -> void:
	if _cam == null:
		return
	_follow = false
	_zoom_i = clampi(zoom_i, 0, ZOOM_STEPS.size() - 1)
	var z := float(ZOOM_STEPS[_zoom_i])
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_cam, "position", target, 0.55)
	tw.tween_property(_cam, "zoom", Vector2(z, z), 0.55)
	_readout()


func _on_battle_started(roster_summary: String, enemies: int) -> void:
	_hud.show_battle_panel("御敌之战　来犯 %d 人　我方 %s" % [enemies, roster_summary],
		"布阵区里随便站：点空地放人 · 按住人拖动 · 拖到左边框收回", true)


func _on_battle_deploy(placed: int, total: int) -> void:
	_hud.update_battle_panel(
		"已布阵 %d / %d　自由站位：点空地放人 · 按住人拖动 · 拖到左边候补框收回（或右键）" % [placed, total])


func _on_battle_ended(result: Dictionary) -> void:
	var win := bool(result.get("win", false))
	var lost := int(result.get("lost", 0))
	var msg := ""
	if win:
		msg = "击退来犯！缴获 %.0f 两" % float(result.get("loot", 0.0))
		if lost > 0:
			msg += "　阵亡 %d 人" % lost
	else:
		msg = "失守。存粮被抢 %.0f 份" % float(result.get("food_lost", 0.0))
		if lost > 0:
			msg += "　阵亡 %d 人" % lost
	_hud.show_battle_panel("战果：" + ("胜" if win else "败"), msg, false)
	# 除了横幅，再往底栏日志里写一条**能算清账**的：
	# 参战多少人、倒了几个、人口从几变几、缴获/被抢多少。
	# 横幅只给结论，日志给"这一仗到底影响了我什么" —— 玩家要的是后者。
	var pop_now := int(_game.query("population"))
	var parts: Array = [
		"御敌%s" % ("得胜" if win else "失利"),
		"出战 %d 人" % _pop_before_battle,
		"阵亡 %d 人" % lost,
		"人口 %d → %d" % [_pop_before_battle, pop_now],
	]
	if win:
		parts.append("缴获 %.0f 两" % float(result.get("loot", 0.0)))
	else:
		parts.append("被抢粮 %.0f 份" % float(result.get("food_lost", 0.0)))
	parts.append("士气 %.0f" % float(_game.query("stats.morale")))
	parts.append("治安 %.0f" % float(_game.query("stats.security")))
	_hud.append_log("[color=%s]%s[/color]" % [
		"#9fe08a" if win else "#ff8a8a", "　".join(parts)])


func _on_battle_close() -> void:
	if _battle != null:
		_battle.finish()
	_hud.hide_battle_panel()
	# 镜头回到主角身上
	_follow = true
	_zoom_i = ZOOM_DEFAULT
	if _cam != null:
		var z := float(ZOOM_STEPS[_zoom_i])
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(_cam, "zoom", Vector2(z, z), 0.45)
		if _hud != null and _hud.has_method("set_zoom_readout"):
			_hud.set_zoom_readout(z, _follow)


## 背景音乐。
##
## 这段音乐是**团队自己合成的**（scripts/pipeline/make_muqam.py），
## 没有采任何现成录音 —— 所以不存在授权问题。为什么必须自己造：
## 木卡姆是活态非遗，演出者具名、录音走商业发行；
## 实测维基共享 Category:Muqam 只有 5 个文件且全是照片，
## Freesound 用 CC0 过滤搜 muqam/dutar/rawap 是 0 条。
## **免费 CC 这条路是空的** —— 是供给问题，不是法律问题。
##
## 合成抓的是木卡姆的调式特征：中立三度（约 350 音分，
## 比西方小三度高 50、比大三度低 50），实测确认落在两者正中间。
##
## ⚠ 它在作品说明里必须如实写成「团队按木卡姆调式特征编程合成」，
##    **不能写成「木卡姆演奏录音」** —— 那是不实陈述。
##
## 循环用「播完再播」而不是设 loop_mode：WAV 的循环要靠 .import 设置，
## 在 headless 下不可靠；finished 信号接一下更稳，也不依赖导入配置。
func _start_music() -> void:
	var music := AudioStreamPlayer.new()
	music.name = "Music"
	var st: AudioStream = load("res://audio/muqam_theme.wav")
	if st == null:
		return
	music.stream = st
	# -12dB 实测偏轻（用户反馈"没听到"）。合成曲本身均方根只有 0.109，
	# 比一般成品音乐轻，所以这里要往上给；-5dB 才是正常背景乐的音量。
	music.volume_db = -5.0
	music.bus = "Master"
	add_child(music)
	music.finished.connect(func() -> void: music.play())
	music.play()
	# 打一行日志：以后判断"音乐到底起没起"，看日志比听可靠
	print("MUSIC 开始播放  driver=%s  时长=%.1fs  音量=%.1fdB  playing=%s"
		% [AudioServer.get_driver_name(), st.get_length(),
			music.volume_db, str(music.is_playing())])


func _probe_ai() -> void:
	var http := HTTPRequest.new()
	http.timeout = 5.0
	add_child(http)
	http.request_completed.connect(func(result, code, _h, body):
		if result == HTTPRequest.RESULT_SUCCESS and code == 200:
			var info = JSON.parse_string(body.get_string_from_utf8())
			if info is Dictionary and str(info.get("mode", "")) == "live":
				_hud.set_conn("● AI 在线", Color(0.5, 1.0, 0.6))
			else:
				_hud.set_conn("● demo", Color(1.0, 0.85, 0.4))
		else:
			_hud.set_conn("● 离线", Color(1.0, 0.5, 0.5))
		http.queue_free()
	)
	http.request("http://127.0.0.1:%d/health" % _ai_port())


func _ai_port() -> int:
	var p := OS.get_environment("AI_PORT")
	return int(p) if p != "" else 8787


# ---------------------------------------------------------------------------
# 操作
# ---------------------------------------------------------------------------

func _on_dig() -> void:
	var r: Dictionary = _game.start_dig()
	if bool(r["ok"]):
		_hud.append_log("[color=#9fe08a]开工：%s（工期 %d 天）[/color]"
			% [str(r["display"]), int(r["days"])])
	else:
		_hud.append_log("[color=#ff8a8a]%s[/color]" % str(r["reason"]))


func _on_shaft_pressed(index: int) -> void:
	var info: Dictionary = _game.dig_info()
	if int(info["index"]) == index and bool(info["ok"]):
		_on_dig()
	elif int(info["index"]) == index:
		_hud.append_log("[color=#ffd479]%s[/color]" % str(info["reason"]))
	else:
		_hud.append_log("[color=#999999]第 %d 段竖井：%s[/color]"
			% [index, "已通水" if index <= int(_game.query("karez.sections")) else "还没轮到"])


func _on_build(id: String) -> void:
	var r: Dictionary = _game.start_build(id)
	if bool(r["ok"]):
		_hud.append_log("[color=#9fe08a]开工建造：%s（%d 天）[/color]"
			% [str(r["display"]), int(r["days"])])
	else:
		_hud.append_log("[color=#ff8a8a]建造失败：%s[/color]" % str(r["reason"]))


func _on_next_phase() -> void:
	var r: Dictionary = _game.advance_phase()
	if str(r["finished"]) != "":
		_hud.append_log("[color=#ffd479]%s[/color]" % str(r["finished"]))
	if bool(r["day_advanced"]):
		_hud.append_log("[color=#aaaaaa]—— 第 %d 天 · %s ——[/color]"
			% [_game.get_day(), _season_cn(str(_game.query("season")))])
		_report_daily_events()
		_maybe_event()


## 畜牧页要显示的一切。集中在这里算，HUD 只负责画。
func _animal_panel_data() -> Dictionary:
	var info: Dictionary = _game.catch_info()
	var opts: Array = []
	for o in info.get("options", []):
		var d: Dictionary = o
		opts.append({
			"display": str(d.get("display", "")),
			"hint": "%.1f" % float(d.get("difficulty", 1.0)),
			"ok": bool(info["ok"]),
			"wild": str(d.get("id", "")),
		})
	# 理论日产出（假设满额照看），用来告诉玩家"养这些能拿到什么"。
	# ⚠ 名字在这里就译好（products_cn）：HUD 只管画，
	#   两处各维护一份中英对照表一定会有一处落后（第一版界面显示的是 wool/milk/egg）。
	var prod: Dictionary = {}
	var prod_cn: Dictionary = {}
	for sid in _game.LIVESTOCK_IDS:
		var n: int = _game.livestock_of(sid)
		if n <= 0:
			continue
		var cfg: Dictionary = _game._species_cfg(sid)
		var p: Dictionary = cfg.get("products", {})
		for pk in p:
			prod[pk] = float(prod.get(pk, 0.0)) + float(p[pk]) * float(n)
			prod_cn[pk] = _product_cn(str(pk))
	var ri: Dictionary = _game.reservoir_info()
	var rtext := "扩建涝坝"
	if ri["next"].is_empty():
		rtext = "涝坝已到顶"
	elif bool(ri["ok"]):
		rtext = "扩建涝坝（%s，%d 天）" % [str(ri.get("display", "")), int(ri.get("days", 0))]
	else:
		rtext = "扩建涝坝 ✕ %s" % str(ri.get("reason", ""))
	return {
		"livestock": _game.livestock_summary(),
		"feed": _game.livestock_feed_per_day(),
		"capacity": _game.livestock_capacity(),
		"herders": _game.job_count("herd"),
		"products": prod,
		"products_cn": prod_cn,
		"options": opts,
		"reservoir_text": rtext,
		"reservoir_ok": bool(ri["ok"]),
	}


func _product_cn(k: String) -> String:
	var m := {"wool": "羊毛", "egg": "禽蛋", "milk": "奶"}
	return str(m.get(k, k))


## ── 木卡姆 ──

## 点了地图上的地标。目前只有奏乐台有交互，其余保持"悬停看说明"。
func _on_site_pressed(site_id: String) -> void:
	if site_id == "yinletai":
		_hud._toggle_music_panel()
		_hud.refresh_music_panel(_music_panel_data())


func _music_panel_data() -> Dictionary:
	var info: Dictionary = _game.music_info()
	info["note"] = "点一套曲子开场。每场 2 行动点，办完歇 3 天。"
	return info


func _on_muqam_requested(idx: int) -> void:
	var r: Dictionary = _game.perform_muqam(idx)
	if bool(r.get("ok", false)):
		_hud.append_log("[color=#ffd479]木卡姆《%s》：%s[/color]"
			% [str(r.get("display", "")), "　".join(r.get("lines", []))])
		_hud.append_log("[color=#c8b8a0]  %s[/color]" % str(r.get("text", "")))
	else:
		_hud.append_log("[color=#ff8a8a]办不了：%s[/color]" % str(r.get("reason", "")))
	_hud.refresh_music_panel(_music_panel_data())


func _on_catch_requested(wild_index: int) -> void:
	var info: Dictionary = _game.catch_info()
	var opts: Array = info.get("options", [])
	if wild_index < 0 or wild_index >= opts.size():
		return
	var d: Dictionary = opts[wild_index]
	var res: Dictionary = _game.catch_wild(str(d.get("id", "")))
	if not bool(res.get("ok", false)):
		_hud.append_log("[color=#ffd479]%s[/color]" % str(res.get("reason", "去不了")))
	else:
		var col := "#9fe08a" if bool(res.get("success", false)) else "#c8b89a"
		_hud.append_log("[color=%s]%s[/color]" % [col, str(res.get("text", ""))])
	_hud.refresh_animal_panel(_animal_panel_data())


func _on_reservoir_requested() -> void:
	var r: Dictionary = _game.start_reservoir()
	if bool(r.get("ok", false)):
		_hud.append_log("[color=#9fe08a]开工：%s（%d 天）[/color]"
			% [str(r.get("display", "")), int(r.get("days", 0))])
	else:
		_hud.append_log("[color=#ff8a8a]%s[/color]" % str(r.get("reason", "开不了工")))
	_hud.refresh_animal_panel(_animal_panel_data())


## 把当天发生的灾难 / 畜牧 / 腐坏摊在日志里。
##
## 为什么必须报：这三样都是"每天悄悄发生"的。不报，玩家只会看到顶栏数字莫名变了，
## 却不知道是羊没喂饱、粮烂了、还是遭了灾 —— 这个游戏里
## **"看不懂为什么变了"比"变差了"更劝退**。
func _report_daily_events() -> void:
	var g: Dictionary = _game.last_gain()
	# 灾难：只在日志内容变了的时候报一次，避免同一场灾报好几天
	var d: Dictionary = _game.state.get("disaster", {})
	var dlog := str(d.get("log", ""))
	if dlog != "" and dlog != _last_disaster_report:
		_last_disaster_report = dlog
		_hud.append_log("[color=#ff9f5a]【灾】%s[/color]" % dlog)
		var did := str(d.get("last_id", ""))
		var dcfg := _disaster_by_id(did)
		_play_disaster_flash(_disaster_screen_of(did))
		# 通告卡：把灾难的插画与说明摊开给玩家看。
		# 插画由本地 ComfyUI + SDXL 生成（scripts/pipeline/make_disaster_art.py）。
		if not dcfg.is_empty():
			_hud.show_notice("【灾】%s" % str(dcfg.get("display", "")),
				str(dcfg.get("desc", "")), "disaster_%s" % did)
	# 畜牧
	var herd: Dictionary = g.get("herd", {})
	var born := int(herd.get("born", 0))
	var died := int(herd.get("died", 0))
	var prods: Dictionary = herd.get("products", {})
	var plist: Array = []
	for k in prods:
		if float(prods[k]) > 0.01:
			plist.append("%s %.1f" % [_product_cn(str(k)), float(prods[k])])
	if not plist.is_empty() or born > 0 or died > 0 or bool(herd.get("starving", false)):
		var msg := "畜牧："
		if not plist.is_empty():
			msg += "收 %s" % "、".join(plist)
		if born > 0:
			msg += "　新生 %d 头" % born
		if died > 0:
			msg += "　死了 %d 头" % died
		if bool(herd.get("starving", false)):
			msg += "　草料不足"
		_hud.append_log("[color=#b8d8a0]%s[/color]" % msg)
	# 腐坏：只报有体感的量，免得每天刷一行"烂了 0.3 份"
	var rot: Dictionary = g.get("spoilage", {})
	var total_rot := 0.0
	for k in rot:
		total_rot += float(rot[k])
	if total_rot >= 1.0:
		_hud.append_log("[color=#c8b08a]存粮腐坏 %.0f 份（盖仓库能压住）[/color]" % total_rot)
	# 加工：把"羊毛变成了毡子"这种事说出来 ——
	# 不说的话畜牧产物进了库玩家也不知道它换成了什么
	var crafted: Dictionary = g.get("crafts", {})
	if not crafted.is_empty():
		var clist: Array = []
		for k in crafted:
			clist.append("%s%.0f" % [_game.good_cn(str(k)), float(crafted[k])])
		_hud.append_log("[color=#c8d8a0]加工：%s[/color]" % "　".join(clist))
	# 节庆：用【节】而不是 emoji —— 项目的像素字体不保证有 emoji 码位
	var fest := str(g.get("festival", ""))
	if fest != "":
		_hud.append_log("[color=#ffd479]【节】%s　%s[/color]"
			% [fest, str(g.get("festival_text", ""))])


func _on_event_manual() -> void:
	var e: Dictionary = _events.trigger_random()
	if e.is_empty():
		_hud.append_log("[color=#999999]当前没有符合条件的事件（64 条里都还不到触发时机）。[/color]")
		return
	_hud.show_event(e)


func _maybe_event() -> void:
	var day: int = _game.get_day()
	if day - _last_event_day < EVENT_MIN_GAP_DAYS:
		return
	if randf() > EVENT_CHANCE:
		return
	var e: Dictionary = _events.trigger_random()
	if e.is_empty():
		return
	_last_event_day = day
	_hud.show_event(e)


## 存档。战斗中允许存 —— 但读档会把战斗掐掉（见 _on_load）。
func _on_save() -> void:
	var ok: bool = _game.save_to(SAVE_PATH)
	_hud.append_log("[color=#9fe08a]已存档[/color]" if ok else "[color=#ff8a8a]存档失败[/color]")


## 读档。
##
## ⚠ 必须把正在进行的战斗掐掉。战斗**不在存档里**（它是场景节点，不是 state），
## 于是读档后会出现最糟的一种情况：数值被打回了存档那一刻，而战场上那批单位
## 还按读档前的样子在打，打完之后再往读档后的数值上扣一次人口与粮 ——
## 玩家看到的是"读档了但架还在打，而且奖励/损失算在了旧局面上"。
## 边界测试就是在这里发现战斗阶段仍是 2、单位仍挂着 6 个。
func _on_load() -> void:
	var ok: bool = _game.load_from(SAVE_PATH)
	if ok and _battle != null and _battle.current_phase() != 0:
		_battle.finish()
		_hud.hide_battle_panel()
		_follow = true
		_hud.append_log("[color=#e8c79a]战斗已中止（读档回到未发生之前）[/color]")
	_hud.append_log("[color=#9fe08a]已读档[/color]" if ok else "[color=#ff8a8a]没有找到存档[/color]")


# ---------------------------------------------------------------------------
# 对话
# ---------------------------------------------------------------------------

func _on_say(text: String, speaker_id: String) -> void:
	_hud.append_log("[color=#8fd3ff]你[/color]（对%s）：%s" % [_name_of(speaker_id), text])
	_recent.append("玩家：%s" % text)
	while _recent.size() > 8:
		_recent.pop_front()
	_hud.set_input_enabled(false)
	if not _game.send(text, speaker_id, _recent):
		_hud.set_input_enabled(true)


func _on_response(payload: Dictionary) -> void:
	_hud.set_input_enabled(true)
	var cid := str(payload.get("speaker", ""))
	var name := _name_of(cid)
	_hud.append_narration(name, str(payload.get("narration", "…")), str(payload.get("emotion", "")))
	_recent.append("%s：%s" % [name, str(payload.get("narration", "")).substr(0, 40)])
	while _recent.size() > 8:
		_recent.pop_front()


func _on_failed(reason: String) -> void:
	_hud.set_input_enabled(true)
	_hud.append_log("[color=#ff8a8a]⚠ %s[/color]" % reason)
	_hud.append_log("[color=#888888]  对话需要 AI 服务；其余功能（挖井/建造/推进/事件）离线均可用。[/color]")


func _name_of(cid: String) -> String:
	if cid == "":
		return "旁白"
	return str(NAME_OF.get(cid, cid))


func _season_cn(s: String) -> String:
	return {"spring": "春", "summer": "夏", "autumn": "秋", "winter": "冬"}.get(s, s)


# ══════════════════════════════════════════════════════════════════════════
#  演示导演（录视频用）　　命令行加 --demo 启动
# ══════════════════════════════════════════════════════════════════════════
#
#  录一份 3 分钟的演示视频，不可能顺着游戏时间慢慢玩到第 15 天触发御敌、
#  或者等一场沙暴。展示线索本来就是**分屏**的：一屏一个要展示的点。
#  这个模式把整条线索摆好，按一下键就跳到下一屏。
#
#      空格 / →   下一屏　　　←   上一屏
#      H          隐藏提示条　　R   从第一屏重来
#
#  用法：Godot_v4.7.2-stable_win64.exe --path scripts -- --demo
#        （也可以双击 启动_演示模式.bat）
#
#  ⚠ 和 --battle 一样，它只改**内存里的状态**，不写存档。演示完别点「存档」。
# ══════════════════════════════════════════════════════════════════════════

const DEMO_BEATS := [
	{"t": "新疆与坎儿井", "d": "干旱区、两千年、国家级非遗 + 世界灌溉工程遗产", "m": "_demo_p01"},
	{"t": "这是什么游戏", "d": "先看一眼成品：一座丝路驿站的完整形态", "m": "_demo_p02"},
	{"t": "开局：一段井都没挖", "d": "沙地、枯树、破驿站 —— 不挖井就活不过第一周", "m": "_demo_b01"},
	{"t": "六段竖井全部挖通", "d": "出水 → 人口 → 绿洲，这是唯一的因果链", "m": "_demo_b02"},
	{"t": "九个岗位，抢的是同一批人", "d": "多派一人挖井，就少一人种地", "m": "_demo_b03"},
	{"t": "建造：十三座建筑", "d": "每座都对应一种真实的丝路生计", "m": "_demo_b04"},
	{"t": "AI 事件卡：多个选项，各有后果", "d": "选项上的代价真的会结算到资源与关系", "m": "_demo_b05"},
	{"t": "御敌之战：自由布阵", "d": "整片布阵区随便站；兵种由岗位决定", "m": "_demo_b06"},
	{"t": "御敌之战：开打", "d": "半自动交手，每 0.62 秒一拍", "m": "_demo_b07"},
	{"t": "畜牧：抓野畜与产出", "d": "五个真实畜种，各有饲料与繁殖周期", "m": "_demo_b08"},
	{"t": "十二木卡姆", "d": "要有人、有场地、有乐器，才办得起来", "m": "_demo_b09"},
	{"t": "灾难通告", "d": "插画由本地 SDXL 生成，六种灾难各有对策建筑", "m": "_demo_b10"},
	{"t": "冬季：地表换雪、树池凋尽", "d": "四季真的会换，不是一张贴图", "m": "_demo_b11"},
	{"t": "春季：绿洲回来", "d": "同一张地图，玩家自己一点点改出来的", "m": "_demo_b12"},
	{"t": "镜头可放可缩", "d": "滚轮缩放、按住左键拖动平移、F 回到主角", "m": "_demo_b13"},
	{"t": "收尾：整片绿洲", "d": "从一段淤塞的坎儿井，到一座丝路重镇", "m": "_demo_b14"},
]

var _demo_on := false
var _demo_i := 0
var _demo_flash_pending := 0
var _demo_layer: CanvasLayer
var _demo_title: Label
var _demo_step: Label
var _demo_note: Label


func _maybe_start_demo() -> void:
	if not _has_cli_flag("--demo"):
		return
	_demo_on = true
	_build_demo_ui()
	# 等 HUD 完成一次布局，否则第一屏的状态推下去会被覆盖
	await get_tree().create_timer(0.45).timeout
	_demo_go(0)
	print("[演示] --demo 生效：共 %d 屏。空格/→ 下一屏，← 上一屏，H 隐藏提示条，R 重来。"
		% DEMO_BEATS.size())

	if _has_cli_flag("--demo-shot"):
		_demo_autorun()

	if _has_cli_flag("--demo-keytest"):
		_demo_keytest()


func _build_demo_ui() -> void:
	_demo_layer = CanvasLayer.new()
	_demo_layer.layer = 30
	add_child(_demo_layer)

	var p := Panel.new()
	# 放在地图下缘：顶栏 0~78、底栏 268~360，224~264 落在两者之间
	# （上一版放在 (0,0)，把顶栏的水/粮/银数字全挡住了）
	p.position = Vector2(6, 224)
	p.size = Vector2(430, 40)
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.06, 0.045, 0.03, 0.88)
	st.border_color = Color(0.878, 0.643, 0.235, 0.85)
	st.border_width_bottom = 1
	p.add_theme_stylebox_override("panel", st)
	_demo_layer.add_child(p)

	_demo_step = _demo_label(p, Vector2(7, 2), Vector2(200, 11), "", 9,
		Color(0.878, 0.643, 0.235))
	_demo_title = _demo_label(p, Vector2(7, 13), Vector2(416, 13), "", 12,
		Color(0.941, 0.894, 0.816))
	_demo_note = _demo_label(p, Vector2(7, 27), Vector2(416, 11), "", 8,
		Color(0.710, 0.643, 0.549))


func _demo_label(parent: Node, pos: Vector2, size: Vector2, text: String,
		sz: int, col: Color) -> Label:
	var l := Label.new()
	l.position = pos
	l.size = size
	l.text = text
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", col)
	l.add_theme_font_override("font",
		load("res://fonts/ark-12px/ark-pixel-12px-proportional-zh_hans.ttf"))
	parent.add_child(l)
	return l


## 跳到第 i 屏。越界自动夹住。
func _demo_go(i: int) -> void:
	if not _demo_on:
		return
	_demo_i = clampi(i, 0, DEMO_BEATS.size() - 1)
	var b: Dictionary = DEMO_BEATS[_demo_i]
	# 换屏前先关掉所有弹窗面板、交还焦点 —— 否则底部输入框会吃掉空格键
	if _hud != null:
		_hud._close_pages()
		# ⚠ _close_pages() **不含** _popup（事件卡/灾难通告）—— 上一次自检里
		#   事件卡没关，把第 6~14 屏全挡住了，就是漏了这一句。
		if _hud._popup != null:
			_hud._popup.visible = false
		# 战斗横幅只有在御敌那一屏才该出现
		_hud.hide_battle_panel()
	get_viewport().gui_release_focus()
	var m: String = str(b.get("m", ""))
	if m != "" and has_method(m):
		call(m)
	_demo_refresh_bar()
	if _hud != null:
		_hud.append_log("[color=#e8c79a]【演示 %02d】%s[/color]"
			% [_demo_i + 1, str(b.get("t", ""))])


## 安全地设一个状态值：**路径不存在就跳过**并返回 false，绝不抛异常。
## 为什么必须这样：屏与屏之间字段名可能有出入，路径写死一旦对不上就会整块崩 ——
## 录视频时最怕的就是这个。宁可这一屏少设一个值，也不要崩。
func _demo_put(path: Array, v) -> bool:
	var cur = _game.state
	for i in range(path.size() - 1):
		if not (cur is Dictionary) or not cur.has(path[i]):
			return false
		cur = cur[path[i]]
	if not (cur is Dictionary) or not cur.has(path[-1]):
		return false
	cur[path[-1]] = v
	return true


## 直接摆镜头（不走补间）—— 录视频要的是"按一下就到位"。
func _demo_cam(zi: int) -> void:
	_follow = false
	_zoom_i = clampi(zi, 0, ZOOM_STEPS.size() - 1)
	var z := float(ZOOM_STEPS[_zoom_i])
	_cam.zoom = Vector2(z, z)
	if _player != null:
		_cam.position = _player.position + Vector2(0, -10)
	_clamp_camera()
	_readout()


## ── 前置屏 ①：新疆与坎儿井 ──
## 画面用「缩到最小的荒漠全景」，让"极端干旱区"这句话有画面托着。
func _demo_p01() -> void:
	_demo_put(["karez", "sections"], 0)
	_demo_put(["population"], 3)
	_demo_put(["calendar", "day"], 1)
	_demo_put(["calendar", "season"], "summer")
	_demo_put(["stats", "morale"], 50.0)
	_game.clamp_all()
	_game.state_changed.emit()
	# 0 号档 = 0.5 倍，整张 40x22 的地图都在画面里，大半是沙
	_demo_cam(0)


## ── 前置屏 ②：这是什么游戏 ──
## 先给观众看「成品是什么样」，第 3 屏再回到一片荒地 —— 先预告、再正片。
func _demo_p02() -> void:
	_demo_put(["karez", "sections"], 6)
	_demo_put(["population"], 12)
	_demo_feed()
	_demo_put(["calendar", "season"], "autumn")
	_game.clamp_all()
	_game.state_changed.emit()
	_demo_cam(1)


func _demo_feed() -> void:
	# 给足材料，否则建造/畜牧面板是空的，录出来不好看
	_demo_put(["resources", "materials", "wood"], 240.0)
	_demo_put(["resources", "materials", "earth"], 300.0)
	_demo_put(["resources", "materials", "metal"], 60.0)
	_demo_put(["resources", "currency"], 220.0)


func _demo_b01() -> void:
	_demo_put(["karez", "sections"], 0)
	_demo_put(["population"], 3)
	_demo_put(["calendar", "day"], 1)
	_demo_put(["calendar", "season"], "spring")
	_game.clamp_all()
	_game.state_changed.emit()
	_demo_cam(2)


func _demo_b02() -> void:
	_demo_put(["karez", "sections"], 6)
	_demo_put(["population"], 12)
	_demo_put(["calendar", "season"], "summer")
	_demo_feed()
	_game.clamp_all()
	_game.state_changed.emit()
	_demo_cam(2)


func _demo_b03() -> void:
	_demo_put(["population"], 12)
	_demo_put(["jobs"], {"water": 2, "farm": 2, "gather_wood": 1, "gather_earth": 1,
		"trade": 1, "guard": 1, "cook": 1, "craft": 1, "music": 1, "idle": 1})
	_game.clamp_all()
	_game.state_changed.emit()
	if _hud != null:
		_hud.open_job_panel()
	_demo_cam(2)


func _demo_b04() -> void:
	_demo_feed()
	_game.clamp_all()
	_game.state_changed.emit()
	if _hud != null:
		_hud._on_build_pressed()
	_demo_cam(2)


func _demo_b05() -> void:
	_demo_feed()
	if _hud != null:
		_hud.event_requested.emit()
	_demo_cam(2)


func _demo_b06() -> void:
	_demo_put(["population"], 8)
	_demo_put(["karez", "sections"], 6)
	_demo_put(["stats", "security"], 28.0)
	_demo_feed()
	_demo_put(["jobs"], {"water": 1, "farm": 1, "gather_wood": 1, "gather_earth": 1,
		"guard": 2, "idle": 2})
	_game.clamp_all()
	_game.state_changed.emit()
	_start_raid(true)


func _demo_b07() -> void:
	if _battle != null and _battle.has_method("begin_fight"):
		_battle.begin_fight()


func _demo_b08() -> void:
	if _hud != null:
		_hud._toggle_animal_panel()
	_demo_cam(2)


func _demo_b09() -> void:
	_demo_feed()
	_demo_put(["population"], 12)
	_game.clamp_all()
	_game.state_changed.emit()
	if _hud != null:
		_hud._toggle_music_panel()
	_demo_cam(2)


func _demo_b10() -> void:
	if _hud != null:
		_hud.show_notice("沙暴", "黄风压过来，天在成土色。井口要先盖毡子，"
			+ "羊群要赶回圈 —— 没准备的人，牲口一天就少一截。",
			"disaster_sandstorm")


func _demo_b11() -> void:
	_demo_put(["karez", "sections"], 6)
	_demo_put(["population"], 12)
	_demo_put(["calendar", "season"], "winter")
	_game.clamp_all()
	_game.state_changed.emit()
	_demo_cam(2)


func _demo_b12() -> void:
	_demo_put(["calendar", "season"], "spring")
	_game.clamp_all()
	_game.state_changed.emit()
	_demo_cam(2)


func _demo_b13() -> void:
	_demo_cam(ZOOM_STEPS.size() - 1)


func _demo_b14() -> void:
	_demo_cam(1)


## 自检：走一遍全部屏并逐屏截图（--demo-shot）。**只在自检时用，录制时不要加这个参数。**
func _demo_autorun() -> void:
	await get_tree().create_timer(1.2).timeout
	for i in range(DEMO_BEATS.size()):
		_demo_go(i)
		await get_tree().create_timer(1.1).timeout
		var img := get_viewport().get_texture().get_image()
		img.save_png("user://demo_%02d.png" % (i + 1))
		print("[演示] 第 %02d 屏  %s" % [i + 1, str(DEMO_BEATS[i].get("t", ""))])
	print("[演示] %d 屏全部走完，无异常" % DEMO_BEATS.size())
	get_tree().quit()


## 键位边界用例：把焦点塞进聊天输入框，再发**真实按键事件**看空格走不走。
## 这个用例是为了重现用户实机反馈的「点空格没用了」而写的。
func _demo_keytest() -> void:
	await get_tree().create_timer(1.0).timeout
	var le := _demo_find_line_edit(_hud)
	if le == null:
		print("[键测] ✗ 在 HUD 里找不到 LineEdit，用例无法进行")
		get_tree().quit()
		return
	le.grab_focus()
	print("[键测] 焦点已塞进输入框（%s）开始" % le.get_class())

	# ① 输入框有焦点 + 空格 → 现在**应该**推进
	#    （上一版这里是"不该推进"，那正是用户报的"空格没用了"）
	var a := _demo_i
	_demo_send_key(KEY_SPACE)
	await get_tree().process_frame
	print("[键测] ① 输入框有焦点 + 空格 → 屏 %d（应为 %d）%s"
		% [_demo_i, a + 1, "  ✓" if _demo_i == a + 1 else "  ✗ 空格仍然没生效"])

	# ② 输入框有焦点 + →
	le.grab_focus()
	var b := _demo_i
	_demo_send_key(KEY_RIGHT)
	await get_tree().process_frame
	print("[键测] ② 输入框有焦点 + → → 屏 %d（应为 %d）%s"
		% [_demo_i, b + 1, "  ✓" if _demo_i == b + 1 else "  ✗"])

	# ③ 跳到最后一屏，按空格 → 不推进，但要有反馈
	_demo_go(DEMO_BEATS.size() - 1)
	await get_tree().process_frame
	if _demo_layer != null:
		_demo_layer.visible = false   # 先藏起来，验证"被藏起来也会强制亮"
	var last := _demo_i
	_demo_send_key(KEY_SPACE)
	await get_tree().create_timer(0.15).timeout
	var note := ""
	if _demo_note != null:
		note = _demo_note.text
	var bar_on := _demo_layer != null and _demo_layer.visible
	print("[键测] ③ 最后一屏 + 空格 → 屏 %d（应仍为 %d）%s；提示条亮起 %s；提示语含边界说明 %s"
		% [last, last, "  ✓" if _demo_i == last else "  ✗ 不该推进",
		   "✓" if bar_on else "✗", "✓" if "最后一屏" in note else "✗"])

	# ④ 最后一屏 + ←
	var c := _demo_i
	_demo_send_key(KEY_LEFT)
	await get_tree().process_frame
	print("[键测] ④ 最后一屏 + ← → 屏 %d（应为 %d）%s"
		% [_demo_i, c - 1, "  ✓" if _demo_i == c - 1 else "  ✗"])

	print("[键测] 用例结束：①空格修好了 ②③④ 边界有反馈、能退回")
	get_tree().quit()


func _demo_send_key(kc: int) -> void:
	var ev := InputEventKey.new()
	ev.keycode = kc
	ev.physical_keycode = kc
	ev.pressed = true
	Input.parse_input_event(ev)
	var up := InputEventKey.new()
	up.keycode = kc
	up.physical_keycode = kc
	up.pressed = false
	Input.parse_input_event(up)


func _demo_find_line_edit(n: Node) -> LineEdit:
	if n == null:
		return null
	if n is LineEdit:
		return n
	for c in n.get_children():
		var r := _demo_find_line_edit(c)
		if r != null:
			return r
	return null
