extends Control
## 游戏 HUD —— 资源面板、操作按钮、对话栏、事件弹窗。
##
## 布局按 640x360 逻辑分辨率精确定位（canvas_items 拉伸会把整块放大到窗口）：
##   顶栏   y   0..14   天/季/时段 · 行动点 · 坎儿井进度 · 对话对象
##   右侧   x 548..640  操作按钮（挖竖井 / 建造 / 推进 / 事件 / 存档）
##   底栏   y 296..360  资源行 · 对话日志 · 输入行
##
## 字体用方舟像素 12px —— 640x360 下用矢量字体会糊成一团，
## 点阵字体是像素分辨率下读中文的唯一可靠选择。

signal dig_requested
signal build_requested(building_id: String)
signal next_phase_requested
signal event_requested
signal save_requested
signal load_requested
signal say_requested(text: String, speaker_id: String)

const FONT_PATH := "res://fonts/ark-12px/ark-pixel-12px-proportional-zh_hans.ttf"

const CHARACTERS := [
	{"id": "lao_kanjiang", "name": "老坎匠"},
	{"id": "muqam_yiren", "name": "木卡姆艺人"},
	{"id": "hasake_qishou", "name": "哈萨克骑手"},
	{"id": "hanshang_zhanggui", "name": "商队掌柜"},
	{"id": "chuniang", "name": "厨娘"},
	{"id": "shenmi_lvren", "name": "神秘旅人"},
	{"id": "mafei_toumu", "name": "马匪头目"},
]

const BUILDINGS := [
	{"id": "yiguan", "name": "驿馆"},
	{"id": "majiu", "name": "马厩"},
	{"id": "cangku", "name": "仓库"},
	{"id": "chufang", "name": "厨房"},
]

var _game: Node = null
var _events: Node = null

var _top: Label
var _res: Label
var _log: RichTextLabel
var _input: LineEdit
var _speaker: OptionButton
var _dig_btn: Button
var _dig_hint: Label
var _conn: Label
var _info: Label

var _popup: Control
var _popup_title: Label
var _popup_text: RichTextLabel
var _popup_choices: VBoxContainer
var _popup_event: Dictionary = {}

var _build_menu: Panel

## 分工面板（S3）。每行是一个岗位：标签 + 「−」「＋」两个按钮。
var _job_panel: Panel
var _job_rows: Dictionary = {}
var _job_free: Label
## 上一条日志文本，用于抑制连续重复（连点失败按钮时不刷屏）
var _last_log := ""


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_theme()
	_build_top()
	_build_right()
	_build_bottom()
	_build_popup()


func _apply_theme() -> void:
	var f = load(FONT_PATH)
	if f == null:
		push_warning("像素字体未找到，回退默认字体（中文在 640x360 下会糊）")
		return
	var th := Theme.new()
	th.default_font = f
	th.default_font_size = 12
	theme = th


func _panel_style(bg: Color, border := Color(0.55, 0.42, 0.28)) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(0)
	sb.content_margin_left = 3
	sb.content_margin_right = 3
	sb.content_margin_top = 1
	sb.content_margin_bottom = 1
	return sb


func _make_panel(rect: Rect2, bg: Color) -> Panel:
	var p := Panel.new()
	p.position = rect.position
	p.size = rect.size
	p.add_theme_stylebox_override("panel", _panel_style(bg))
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(p)
	return p


func _make_label(parent: Node, pos: Vector2, size: Vector2, txt := "") -> Label:
	var l := Label.new()
	l.position = pos
	l.size = size
	l.text = txt
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", 12)
	parent.add_child(l)
	return l


func _make_button(parent: Node, rect: Rect2, txt: String) -> Button:
	var b := Button.new()
	b.position = rect.position
	b.size = rect.size
	b.text = txt
	b.add_theme_font_size_override("font_size", 12)
	parent.add_child(b)
	return b


# ---------------------------------------------------------------------------
# 顶栏 / 右侧 / 底栏
# ---------------------------------------------------------------------------

func _build_top() -> void:
	# ⚠ Godot 会按字体与主题边距强制控件最小高度，写 13 也会被撑到 23。
	# 所有布局都按「Label≈23 / Button≈24 / LineEdit≈31」实测值排，
	# 否则相邻控件会重叠 —— 实机截图里三个按钮就这么连成过一块深色方块。
	#
	# 顶栏两行：第一行是时间与进度，第二行是资源。
	var p := _make_panel(Rect2(0, 0, 640, 52), Color(0.13, 0.10, 0.07, 0.90))
	_top = _make_label(p, Vector2(4, 1), Vector2(440, 23), "第 1 天")

	_speaker = OptionButton.new()
	_speaker.position = Vector2(450, 1)
	_speaker.size = Vector2(112, 24)
	_speaker.add_theme_font_size_override("font_size", 12)
	for c in CHARACTERS:
		_speaker.add_item(str(c["name"]))
	_speaker.selected = 0
	p.add_child(_speaker)

	_conn = _make_label(p, Vector2(566, 1), Vector2(72, 23), "AI 探测中")
	_res = _make_label(p, Vector2(4, 27), Vector2(632, 23), "")


func _build_right() -> void:
	# 高度按实测最小尺寸累加：单行标签 23、双行标签 46、按钮 24。
	# 面板 244 高，内容排到 226 —— 早先给双行标签 32 高，第二行会被下沿切掉。
	var p := _make_panel(Rect2(536, 56, 104, 244), Color(0.13, 0.10, 0.07, 0.85))

	_dig_btn = _make_button(p, Rect2(4, 2, 96, 24), "挖竖井")
	_dig_btn.pressed.connect(func(): dig_requested.emit())

	_dig_hint = _make_label(p, Vector2(4, 28), Vector2(96, 46), "")
	_dig_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dig_hint.modulate = Color(0.85, 0.78, 0.60)

	# 每 26px 一个按钮（24 高 + 2 间隙）
	var bbuild := _make_button(p, Rect2(4, 76, 96, 24), "建造 ▾")
	bbuild.pressed.connect(_on_build_pressed)

	var bjob := _make_button(p, Rect2(4, 102, 96, 24), "分工 ▾")
	bjob.pressed.connect(_on_job_pressed)

	var bnext := _make_button(p, Rect2(4, 128, 96, 24), "推进时段")
	bnext.pressed.connect(func(): next_phase_requested.emit())

	var bev := _make_button(p, Rect2(4, 154, 96, 24), "查看事件")
	bev.pressed.connect(func(): event_requested.emit())

	var bsave := _make_button(p, Rect2(4, 180, 46, 24), "存档")
	bsave.pressed.connect(func(): save_requested.emit())
	var bload := _make_button(p, Rect2(54, 180, 46, 24), "读档")
	bload.pressed.connect(func(): load_requested.emit())

	# 底部这块显示实时信息：今天产出了多少
	_info = _make_label(p, Vector2(4, 208), Vector2(96, 36), "")
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.modulate = Color(0.72, 0.66, 0.55)

	_build_panel()
	_build_job_panel()


## 分工面板 —— S3 的核心界面。没有它，玩家碰不到岗位系统。
func _build_job_panel() -> void:
	_job_panel = Panel.new()
	_job_panel.position = Vector2(300, 40)
	_job_panel.size = Vector2(228, 232)
	_job_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.16, 0.12, 0.09, 0.97)))
	_job_panel.visible = false
	add_child(_job_panel)

	_make_label(_job_panel, Vector2(6, 2), Vector2(216, 23), "── 分工（每个人占一个岗位）──")

	# 每行：岗位名 + 人数 + ─ / ＋ 两个按钮
	var y := 26.0
	for jid in ["water", "gather_wood", "gather_earth", "craft", "farm", "guard", "idle"]:
		_job_rows[jid] = _make_label(_job_panel, Vector2(6, y), Vector2(120, 23), "")
		var minus := _make_button(_job_panel, Rect2(128, y + 1, 26, 22), "−")
		minus.pressed.connect(_on_job_delta.bind(str(jid), -1))
		var plus := _make_button(_job_panel, Rect2(156, y + 1, 26, 22), "＋")
		plus.pressed.connect(_on_job_delta.bind(str(jid), 1))
		y += 25.0

	_job_free = _make_label(_job_panel, Vector2(6, y + 2), Vector2(216, 23), "")
	_job_free.modulate = Color(1.0, 0.85, 0.45)


func _on_job_pressed() -> void:
	_toggle_job_panel()


func _toggle_job_panel() -> void:
	if _job_panel == null:
		return
	_job_panel.visible = not _job_panel.visible
	if _job_panel.visible:
		_refresh_jobs()


## 供场景在开局时自动弹出 —— 用户实机反馈「不知道怎么派人」，
## 说明这个面板藏得太深：按钮在那儿，但没有任何东西提示必须点它。
func open_job_panel() -> void:
	if _job_panel != null and not _job_panel.visible:
		_toggle_job_panel()


func _on_job_delta(jid: String, delta: int) -> void:
	if _game == null:
		return
	if not _game.assign_job(jid, delta):
		append_log("[color=#ffd479]没有空闲人手了 —— 先从别的岗位撤一个人。[/color]")
	_refresh_jobs()


func _refresh_jobs() -> void:
	if _game == null or _job_panel == null:
		return
	for jid in _job_rows:
		var n: int = _game.job_count(str(jid))
		var lbl: Label = _job_rows[jid]
		lbl.text = "%s　%d 人" % [_job_cn(str(jid)), n]
		lbl.modulate = Color(1, 1, 1) if n > 0 else Color(0.55, 0.5, 0.45)
	var free: int = _game.unassigned()
	if free > 0:
		_job_free.text = "还有 %d 人没安排" % free
		_job_free.modulate = Color(1.0, 0.6, 0.5)
	elif free < 0:
		_job_free.text = "人手不足，请减少岗位"
		_job_free.modulate = Color(1.0, 0.5, 0.5)
	else:
		_job_free.text = "全部 %d 人已分配" % int(_game.query("population"))
		_job_free.modulate = Color(0.65, 0.95, 0.65)


func _job_cn(jid: String) -> String:
	return {"water": "治水", "gather_wood": "采木", "gather_earth": "取土",
		"craft": "做工", "farm": "耕作", "guard": "守卫", "idle": "待命"}.get(jid, jid)


func _build_panel() -> void:
	# 用内嵌 Panel 而不是 PopupMenu：Godot 4 里 PopupMenu 是 Window，
	# 挂进 Control 后会在视口里渲染出一块深色残留（实机截图确认过）。
	# 内嵌面板还能顺便把造价写在按钮上，比原生菜单更有用。
	_build_menu = Panel.new()
	_build_menu.position = Vector2(420, 60)
	_build_menu.size = Vector2(112, 116)
	_build_menu.add_theme_stylebox_override("panel", _panel_style(Color(0.16, 0.12, 0.09, 0.97)))
	_build_menu.visible = false
	add_child(_build_menu)

	_make_label(_build_menu, Vector2(6, 2), Vector2(100, 13), "── 选择建筑 ──")

	var y := 18.0
	for b in BUILDINGS:
		var info: Dictionary = _game.build_info(str(b["id"])) if _game != null else {}
		var cost := ""
		if not info.is_empty():
			var parts: Array = []
			for k in info.get("materials", {}):
				parts.append("%s%d" % [_mat_cn(str(k)), int(info["materials"][k])])
			cost = " " + " ".join(parts)
		var btn := _make_button(_build_menu, Rect2(5, y, 102, 18),
			"%s%s" % [str(b["name"]), cost])
		btn.pressed.connect(func():
			build_requested.emit(str(b["id"]))
			_build_menu.visible = false
		)
		y += 21.0


func _on_build_pressed() -> void:
	if _build_menu != null:
		_build_menu.visible = not _build_menu.visible


func _build_bottom() -> void:
	# 84 高 = 日志 48（正好 3 行）+ 输入行 31 + 边距。资源行在顶栏第二行。
	# 日志给 40 会只显示 2.5 行 —— 最上面那行被切掉半截，实机截图里很难看。
	# 48 是 3×16 的整数倍，不出现半行。
	var p := _make_panel(Rect2(0, 276, 640, 84), Color(0.11, 0.085, 0.06, 0.94))

	_log = RichTextLabel.new()
	_log.position = Vector2(4, 2)
	_log.size = Vector2(632, 48)
	_log.bbcode_enabled = true
	_log.scroll_following = true
	_log.scroll_active = false
	_log.add_theme_font_size_override("normal_font_size", 12)
	_log.add_theme_font_size_override("bold_font_size", 12)
	_log.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(_log)

	_input = LineEdit.new()
	_input.position = Vector2(4, 52)
	_input.size = Vector2(556, 31)
	_input.placeholder_text = "说点什么…（回车）"
	_input.add_theme_font_size_override("font_size", 12)
	p.add_child(_input)

	var send := _make_button(p, Rect2(564, 54, 68, 26), "发送")
	send.pressed.connect(_on_send)
	_input.text_submitted.connect(func(_t): _on_send())

	_input.grab_focus()


func _on_send() -> void:
	var t := _input.text.strip_edges()
	if t == "":
		return
	_input.text = ""
	var cid := str(CHARACTERS[_speaker.selected]["id"])
	say_requested.emit(t, cid)


func speaker_id() -> String:
	return str(CHARACTERS[_speaker.selected]["id"])


func speaker_name() -> String:
	return str(CHARACTERS[_speaker.selected]["name"])


# ---------------------------------------------------------------------------
# 事件弹窗
# ---------------------------------------------------------------------------

func _build_popup() -> void:
	_popup = Control.new()
	_popup.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_popup.visible = false
	_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_popup)

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.55)
	_popup.add_child(dim)

	var card := Panel.new()
	card.position = Vector2(60, 40)
	card.size = Vector2(520, 280)
	card.add_theme_stylebox_override("panel", _panel_style(Color(0.16, 0.12, 0.09, 0.98)))
	_popup.add_child(card)

	_popup_title = _make_label(card, Vector2(8, 6), Vector2(504, 16), "")
	_popup_title.add_theme_font_size_override("font_size", 12)
	_popup_title.modulate = Color(1.0, 0.86, 0.45)

	_popup_text = RichTextLabel.new()
	_popup_text.position = Vector2(8, 24)
	_popup_text.size = Vector2(504, 120)
	_popup_text.bbcode_enabled = true
	_popup_text.add_theme_font_size_override("normal_font_size", 12)
	card.add_child(_popup_text)

	_popup_choices = VBoxContainer.new()
	_popup_choices.position = Vector2(8, 148)
	_popup_choices.size = Vector2(504, 124)
	_popup_choices.add_theme_constant_override("separation", 3)
	card.add_child(_popup_choices)


func show_event(event: Dictionary) -> void:
	if event.is_empty():
		append_log("[color=#999999]（当前没有可触发的事件）[/color]")
		return
	_popup_event = event
	_popup_title.text = "【%s】%s" % [str(event.get("category", "")), str(event.get("title", ""))]
	_popup_text.text = str(event.get("text", ""))

	for c in _popup_choices.get_children():
		c.queue_free()

	var choices: Array = event.get("choices", [])
	for i in range(choices.size()):
		var ch: Dictionary = choices[i]
		var b := Button.new()
		var hint := str(ch.get("hint", ""))
		b.text = "  %s%s" % [str(ch.get("text", "？")), ("（%s）" % hint) if hint != "" else ""]
		b.add_theme_font_size_override("font_size", 12)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(_on_choice.bind(i))
		_popup_choices.add_child(b)

	_popup.visible = true


func _on_choice(index: int) -> void:
	if _popup_event.is_empty() or _events == null:
		return
	var res: Dictionary = _events.resolve(_popup_event, index)
	_popup.visible = false
	if bool(res["ok"]):
		append_log("[color=#b08cff]▸ %s[/color]" % str(res["outcome"]))
		append_log("[color=#666666]  应用效果 %d 项，丢弃 %d 项[/color]"
			% [int(res["applied"]), int(res["dropped"])])
	else:
		append_log("[color=#ff8a8a]事件结算失败：%s[/color]" % str(res["reason"]))
	_popup_event = {}


func popup_visible() -> bool:
	return _popup != null and _popup.visible


# ---------------------------------------------------------------------------
# 对外接口
# ---------------------------------------------------------------------------

func setup(game: Node, events: Node) -> void:
	_game = game
	_events = events
	if _game != null and not _game.state_changed.is_connected(refresh):
		_game.state_changed.connect(refresh)
	refresh()


func append_log(text: String) -> void:
	if _log == null:
		return
	# 连续重复的同一条提示只记一次。玩家连点「挖竖井」而材料不够时，
	# 会把同一句「缺 土差12」刷满整个日志框（实机截图里就是这样）。
	if text == _last_log:
		return
	_last_log = text
	_log.append_text(text + "\n")


func append_narration(speaker: String, text: String, emotion := "") -> void:
	var em := ("　[i]（%s）[/i]" % emotion) if emotion != "" else ""
	_log.append_text("[b][color=#ffd479]%s[/color][/b]：%s%s\n" % [speaker, text, em])


func set_conn(text: String, color: Color) -> void:
	if _conn == null:
		return
	_conn.text = text
	_conn.modulate = color


func set_input_enabled(on: bool) -> void:
	if _input != null:
		_input.editable = on


func refresh() -> void:
	if _game == null:
		return
	var season: String = {"spring": "春", "summer": "夏", "autumn": "秋", "winter": "冬"}.get(
		str(_game.query("season")), "?")
	var phase: String = {"morning": "晨", "afternoon": "午", "evening": "暮", "night": "夜"}.get(
		str(_game.query("phase")), "?")
	var sections := int(_game.query("karez.sections"))
	var flow := float(_game.query("resources.water.flow_per_day"))

	# 施工字段的空串要单独判：.get(k, 默认值) 只在「键不存在」时生效，
	# 而 _initial_state 里 display 是存在的空字符串，所以早先这里显示成「建设:」后面空白。
	var building := str(_game.state["construction"].get("display", ""))
	if building == "":
		building = "空闲"
	# 顶栏第一行加上「分工概览」：不让玩家必须打开面板才知道谁在干什么。
	# 之前只有「坎儿井 2/6　建设:空闲」，玩家根本看不出耕作的只有 1 个人。
	var js := ""
	for jid in ["water", "gather_wood", "gather_earth", "craft", "farm", "guard", "idle"]:
		var n: int = _game.job_count(jid)
		if n > 0:
			js += "%s%d " % [_job_cn(jid), n]
	_top.text = "第%d天 %s·%s  坎儿井 %d/6   %s  %s" % [
		int(_game.query("day")), season, phase, sections, building, js.strip_edges(),
	]

	var w := float(_game.query("resources.water.current"))
	var wc := float(_game.query("resources.water.capacity"))
	var food := 0.0
	for k in _game.state["resources"]["food"]:
		food += float(_game.state["resources"]["food"][k])
	var m: Dictionary = _game.state["resources"]["materials"]

	# ⚠ Label 不解析 BBCode —— 早先这里拼了 [color=...]，实机截图里
	# 那串标记被原样显示了出来。改成纯文本 + modulate 表示告警色。
	#
	# 告警优先级：饿死 > 渴死。「粮只够 N 天」比「缺水」更紧急，
	# 而且要把「点什么」一起说出来 —— 只说缺什么，玩家不知道怎么办。
	var shortage := flow < float(int(_game.query("population"))) * 3.0
	var food_days: float = _game.food_days_left()
	var warn := ""
	if food_days < 2.0:
		warn = "   【粮只够 %.0f 天 — 点「分工」加耕作】" % food_days
	elif shortage:
		warn = "   ← 缺水，入不敷出"
	_res.text = "水 %.0f/%.0f (入%.0f)  粮 %.0f  银 %.0f  人 %d  木 %.0f 土 %.0f 具 %.0f  士气 %.0f%s" % [
		w, wc, flow, food, float(_game.query("resources.silver")),
		int(_game.query("population")),
		float(m.get("wood", 0)), float(m.get("earth", 0)),
		float(m.get("tools", 0)), float(_game.query("stats.morale")),
		warn,
	]
	_res.modulate = Color(1.0, 0.68, 0.6) if (shortage or food_days < 2.0) else Color(1, 1, 1)

	# 右栏底部：显示「昨天产出了什么」+ 田块进度。
	# 这是玩家判断分工是否合理的唯一依据 —— 没有它，岗位分配就是盲猜。
	var sec := int(_game.query("karez.sections"))
	var g: Dictionary = _game.last_gain()
	var plots_n: int = _game.farmland_plots()
	if g.is_empty():
		_info.text = "田 %d 块\n井 %d/6" % [plots_n, sec]
	else:
		_info.text = "田 %d 块 井 %d/6\n昨产 木%.0f 土%.0f 粮%.0f" % [
			plots_n, sec, float(g.get("wood", 0.0)),
			float(g.get("earth", 0.0)), float(g.get("food", 0.0))]
	_info.modulate = Color(0.72, 0.66, 0.55)

	if _job_panel != null and _job_panel.visible:
		_refresh_jobs()

	_refresh_dig()


func _refresh_dig() -> void:
	var info: Dictionary = _game.dig_info()
	if bool(info["ok"]):
		_dig_btn.disabled = false
		_dig_btn.text = "挖第%d段" % int(info["index"])
		# 两行以内：材料明细比冗长的段名有用，段名放按钮上
		var mats: Dictionary = info["materials"]
		var parts: Array = []
		for k in mats:
			parts.append("%s%d" % [_mat_cn(str(k)), int(mats[k])])
		_dig_hint.text = "工期 %d 天\n消耗 %s" % [int(info["days"]), " ".join(parts)]
		_dig_hint.modulate = Color(0.65, 0.95, 0.65)
	else:
		_dig_btn.disabled = true
		# 禁用态按钮文字会被压暗，写「挖竖井」看着像空按钮；
		# 直接写清为什么不能点，玩家一眼就懂
		var c: Dictionary = _game.state["construction"]
		_dig_btn.text = "施工中…" if str(c.get("kind", "")) != "" else "材料不足"
		# 把「缺什么」翻译成「该点哪个岗位」——
		# 只显示「缺 土差12」的话，玩家不知道去哪补（用户实机反馈过这一点）
		var r := str(info["reason"])
		if r.begins_with("缺 "):
			var tips: Array = []
			if r.contains("土"):
				tips.append("取土")
			if r.contains("木"):
				tips.append("采木")
			if r.contains("工具"):
				tips.append("做工")
			if tips.is_empty():
				_dig_hint.text = r
			else:
				_dig_hint.text = "%s\n点「分工」派人%s" % [r, "/".join(tips)]
		else:
			_dig_hint.text = r
		_dig_hint.modulate = Color(1.0, 0.62, 0.5)


func _mat_cn(k: String) -> String:
	return {"wood": "木", "earth": "土", "cloth": "布", "tools": "具"}.get(k, k)
