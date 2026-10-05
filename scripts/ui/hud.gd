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

## 对话对象。hint 是这个人的一句话身份 —— 玩家要能看出「换个人有什么用」。
## 数据与 data/characters.json 的人设对应，只是压缩到一行能放下的长度。
const CHARACTERS := [
	{"id": "lao_kanjiang", "name": "老坎匠",
		"hint": "七十岁匠人，一生挖过十一条坎儿井 —— 问井、土质、水脉"},
	{"id": "muqam_yiren", "name": "木卡姆艺人",
		"hint": "民间乐师，走遍南北道 —— 问士气、人心、各地传闻"},
	{"id": "hasake_qishou", "name": "哈萨克骑手",
		"hint": "草原青年，骑术精湛 —— 问探路、草原、马匹"},
	{"id": "hanshang_zhanggui", "name": "商队掌柜",
		"hint": "走丝路三十年 —— 问物价、买卖、商队何时来"},
	{"id": "chuniang", "name": "厨娘",
		"hint": "掌驿站伙食，消息最灵通 —— 问粮食、谁欠谁、谁跟谁不好"},
	{"id": "shenmi_lvren", "name": "神秘旅人",
		"hint": "身份不明的过客，什么都看在眼里 —— 问主线"},
	{"id": "mafei_toumu", "name": "马匪头目",
		"hint": "沙漠马匪头目，手下二三十人 —— 谈判和威胁都在这"},
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
## 顶栏第三行：当前该做什么。把「缺什么」翻译成「点哪里」，并显示昨日产出。
var _hint: Label
## 「对谁说」那一行的身份说明，让玩家看出换个人有什么用
var _who_hint: Label
## 是否已经把「怎么选对话对象」讲过一遍
## 下拉框里当前列着谁（id）。与 _speaker 的选项一一对应 ——
## 不能用 CHARACTERS[_speaker.selected]，因为列表是动态的（角色按需出现）。
var _speaker_ids: Array = []
## 是否已经把「怎么选对话对象」讲过一遍
var _speaker_explained := false


## 按 game_state.characters_present() 重建「对谁说」列表。
## 判断只在 game_state 那一处，这里不写任何条件。
func _rebuild_speaker_list() -> void:
	if _speaker == null or _game == null:
		return
	var present: Array = _game.characters_present()
	# 列表没变就不动 —— 否则每次 state_changed 都会重置玩家正在做的选择
	if present == _speaker_ids:
		return
	var keep := ""
	if _speaker.selected >= 0 and _speaker.selected < _speaker_ids.size():
		keep = str(_speaker_ids[_speaker.selected])
	_speaker_ids = present
	_speaker.clear()
	for cid in present:
		_speaker.add_item(_char_name(str(cid)))
	var idx: int = _speaker_ids.find(keep)
	_speaker.selected = maxi(0, idx)
	_on_speaker_changed_no_log(int(_speaker.selected))


func _char_name(cid: String) -> String:
	for c in CHARACTERS:
		if str(c["id"]) == cid:
			return str(c["name"])
	return cid


func _char_hint(cid: String) -> String:
	for c in CHARACTERS:
		if str(c["id"]) == cid:
			return str(c.get("hint", ""))
	return ""
## 右侧功能栏与底栏。**默认隐藏**，用顶栏的「功能」「对话」按钮开关。
var _right: Panel
var _bottom: Panel

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


## 面板样式。像素 UI 的经典做法：**金边 + 圆角 + 投影**。
##
## 改之前只有 1px 的暗棕边（0.55,0.42,0.28），在深棕底（0.13,0.10,0.07）上
## 几乎没有对比 —— 所以面板看着就是几块平贴的深色方块，像调试工具而不是游戏界面。
## 现在：
##   · 边框提到 2px 且换成暖金，面板从地图上「抬」得起来
##   · 圆角 3px，去掉生硬的直角
##   · 加一层投影，让面板有厚度（否则像直接画在沙地上）
func _panel_style(bg: Color, border := Color(0.74, 0.57, 0.32)) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(3)
	sb.shadow_color = Color(0.0, 0.0, 0.0, 0.45)
	sb.shadow_size = 3
	sb.shadow_offset = Vector2(0, 2)
	sb.content_margin_left = 4
	sb.content_margin_right = 4
	sb.content_margin_top = 2
	sb.content_margin_bottom = 2
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
	# 所有布局都按「Label≈23 / Button≈24 / LineEdit≈31」实测值排。
	#
	# 顶栏三行，**常驻不隐藏** —— 它是玩家唯一的全局视野：
	#   row1  天数/季节/坎儿井/分工概览 + 两个面板开关
	#   row2  资源
	#   row3  当前该做什么（随状态变化，把「缺什么」翻译成「点哪里」）
	# 右侧栏与底栏默认隐藏，地图整片留给玩家。
	var p := _make_panel(Rect2(0, 0, 640, 78), Color(0.13, 0.10, 0.07, 0.90))
	_top = _make_label(p, Vector2(4, 1), Vector2(398, 23), "第 1 天")

	var bmenu := _make_button(p, Rect2(404, 1, 56, 24), "功能")
	bmenu.pressed.connect(func(): _toggle_right_panel())
	var blog := _make_button(p, Rect2(462, 1, 56, 24), "对话")
	blog.pressed.connect(func(): _toggle_bottom_panel())
	_conn = _make_label(p, Vector2(520, 1), Vector2(116, 23), "AI 探测中")

	_res = _make_label(p, Vector2(4, 27), Vector2(632, 23), "")
	_hint = _make_label(p, Vector2(4, 53), Vector2(632, 23), "")
	_hint.modulate = Color(1.0, 0.9, 0.55)


func _build_right() -> void:
	# 右侧功能栏。**默认隐藏**，用顶栏的「功能」按钮开关 ——
	# 平时把整张地图留给玩家，需要时再拉出来，这样才像游戏而不是调试工具。
	#
	# 宽度给到 208：分工/建造这些页要在一行里放「名称 + − + ＋」，
	# 104 宽的窄栏放不下 —— 第一版就是因此把面板浮在地图正中间，挡住了半张图。
	_right = _make_panel(Rect2(432, 82, 208, 206), Color(0.13, 0.10, 0.07, 0.93))
	_right.visible = false
	var p: Panel = _right

	_dig_btn = _make_button(p, Rect2(4, 2, 200, 24), "挖竖井")
	_dig_btn.pressed.connect(func(): dig_requested.emit())

	_dig_hint = _make_label(p, Vector2(4, 28), Vector2(200, 46), "")
	_dig_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dig_hint.modulate = Color(0.85, 0.78, 0.60)

	# 每 26px 一个按钮（24 高 + 2 间隙）
	var bbuild := _make_button(p, Rect2(4, 76, 200, 24), "建造 ▾")
	bbuild.pressed.connect(_on_build_pressed)

	var bjob := _make_button(p, Rect2(4, 102, 200, 24), "分工 ▾")
	bjob.pressed.connect(_on_job_pressed)

	var bnext := _make_button(p, Rect2(4, 128, 200, 24), "推进时段")
	bnext.pressed.connect(func(): next_phase_requested.emit())

	var bev := _make_button(p, Rect2(4, 154, 200, 24), "查看事件")
	bev.pressed.connect(func(): event_requested.emit())

	var bsave := _make_button(p, Rect2(4, 180, 98, 24), "存档")
	bsave.pressed.connect(func(): save_requested.emit())
	var bload := _make_button(p, Rect2(106, 180, 98, 24), "读档")
	bload.pressed.connect(func(): load_requested.emit())

	_build_panel()
	_build_job_panel()


## 分工页 —— S3 的核心界面。它铺在右侧功能栏的位置上，**不浮在地图中间**：
## 第一版把它做成浮层面板，正好挡住半张地图（用户实机反馈过）。
func _build_job_panel() -> void:
	_job_panel = Panel.new()
	_job_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_job_panel.position = Vector2.ZERO
	_job_panel.size = _right.size
	_job_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.16, 0.12, 0.09, 0.99)))
	_job_panel.visible = false
	_right.add_child(_job_panel)

	_make_label(_job_panel, Vector2(6, 2), Vector2(196, 23), "── 分工（每人占一个岗位）──")

	# 每行：岗位名 + 人数 + − / ＋ 两个按钮。
	# 面板 206 高：标题 23 + 7 行 × 22 + 底部 23 = 200，放得下。
	var y := 26.0
	for jid in ["water", "gather_wood", "gather_earth", "craft", "farm", "guard", "idle"]:
		_job_rows[jid] = _make_label(_job_panel, Vector2(6, y), Vector2(120, 22), "")
		var minus := _make_button(_job_panel, Rect2(130, y, 32, 22), "−")
		minus.pressed.connect(_on_job_delta.bind(str(jid), -1))
		var plus := _make_button(_job_panel, Rect2(166, y, 32, 22), "＋")
		plus.pressed.connect(_on_job_delta.bind(str(jid), 1))
		y += 22.0

	var back := _make_button(_job_panel, Rect2(4, y + 2, 60, 22), "返回")
	back.pressed.connect(_close_pages)
	_job_free = _make_label(_job_panel, Vector2(68, y + 2), Vector2(134, 22), "")
	_job_free.modulate = Color(1.0, 0.85, 0.45)


func _on_job_pressed() -> void:
	if _right != null and not _right.visible:
		_right.visible = true
	if _job_panel != null:
		_build_menu.visible = false
		_job_panel.visible = true
		_refresh_jobs()


## 关掉所有子页，回到「行动」主列表。子页铺在右侧栏上，所以必须能退回来。
func _close_pages() -> void:
	if _job_panel != null:
		_job_panel.visible = false
	if _build_menu != null:
		_build_menu.visible = false


## 供场景在开局时自动弹出 —— 用户实机反馈「不知道怎么派人」。
## 现在它会连同右侧功能栏一起打开，而不是浮在地图上。
func open_job_panel() -> void:
	if _right != null:
		_right.visible = true
	_on_job_pressed()


func _on_job_delta(jid: String, delta: int) -> void:
	if _game == null:
		return
	if not _game.assign_job(jid, delta):
		_job_free.text = "没人了 — 先从别的岗位撤"
		_job_free.modulate = Color(1.0, 0.45, 0.4)
		return
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


## 建造页 —— 同样铺在右侧功能栏上，不浮在地图中间。
func _build_panel() -> void:
	# 用内嵌 Panel 而不是 PopupMenu：Godot 4 里 PopupMenu 是 Window，
	# 挂进 Control 后会在视口里渲染出一块深色残留（实机截图确认过）。
	_build_menu = Panel.new()
	_build_menu.position = Vector2.ZERO
	_build_menu.size = _right.size
	_build_menu.add_theme_stylebox_override("panel", _panel_style(Color(0.16, 0.12, 0.09, 0.99)))
	_build_menu.visible = false
	_right.add_child(_build_menu)

	_make_label(_build_menu, Vector2(6, 2), Vector2(196, 23), "── 选择建筑 ──")

	var y := 28.0
	for b in BUILDINGS:
		var info: Dictionary = _game.build_info(str(b["id"])) if _game != null else {}
		var cost := ""
		if not info.is_empty():
			var parts: Array = []
			for k in info.get("materials", {}):
				parts.append("%s%d" % [_mat_cn(str(k)), int(info["materials"][k])])
			cost = " " + " ".join(parts)
		var btn := _make_button(_build_menu, Rect2(4, y, 200, 24),
			"%s%s" % [str(b["name"]), cost])
		btn.pressed.connect(func():
			build_requested.emit(str(b["id"]))
			_build_menu.visible = false
		)
		y += 26.0

	var back := _make_button(_build_menu, Rect2(4, y + 2, 60, 24), "返回")
	back.pressed.connect(_close_pages)


func _on_build_pressed() -> void:
	if _right != null and not _right.visible:
		_right.visible = true
	if _build_menu != null:
		_build_menu.visible = true
	if _job_panel != null:
		_job_panel.visible = false


## 右侧功能栏的开关。默认隐藏 —— 平时整张地图留给玩家。
func _toggle_right_panel() -> void:
	if _right == null:
		return
	_right.visible = not _right.visible
	if _right.visible:
		_close_pages()
	else:
		_close_pages()


## 底栏（日志 + 对话输入）的开关。默认隐藏。
func _toggle_bottom_panel() -> void:
	if _bottom == null:
		return
	_bottom.visible = not _bottom.visible
	if _bottom.visible:
		_explain_speaker_once()
		if _input != null:
			_input.grab_focus()


## 供场景在开局时把底栏打开（教程在里面）。
func show_bottom_panel() -> void:
	if _bottom != null:
		_bottom.visible = true
	# 把「对谁说」那一行的身份提示先填上，否则开局是一行空白
	_on_speaker_changed_no_log(int(_speaker.selected))


## 从地图上点了某个人过来。把下拉框切到那个人并说明一句 ——
## 地图和下拉框是同一个入口的两种走法，必须互相同步，否则玩家会以为点了没反应。
func focus_speaker(cid: String) -> void:
	for i in range(CHARACTERS.size()):
		if str(CHARACTERS[i]["id"]) == cid:
			if _speaker != null and _speaker.selected != i:
				_speaker.selected = i
			_on_speaker_changed(i)
			return


## 只更新提示，不写日志 —— 开局时日志要留给教程
func _on_speaker_changed_no_log(idx: int) -> void:
	if idx < 0 or idx >= CHARACTERS.size():
		return
	var c: Dictionary = CHARACTERS[idx]
	if _who_hint != null:
		_who_hint.text = str(c.get("hint", ""))
	if _input != null:
		_input.placeholder_text = "跟%s说点什么…（回车）" % str(c["name"])


func _build_bottom() -> void:
	# 84 高 = 日志 48（正好 3 行）+ 输入行 31 + 边距。
	# 日志给 40 会只显示 2.5 行 —— 最上面那行被切掉半截，实机截图里很难看。
	# **默认隐藏**，用顶栏的「对话」按钮开关。
	# 92 高 = 日志 40（2.5 行）+ 对谁说行 22 + 输入行 22 + 边距。
	# 不能再高了：底栏从 y=268 起，聚落那一排建筑（y 208..272）会被切掉下半截，
	# 站在聚落里的人也跟着看不见（第一版 108 高时就是这样）。
	_bottom = _make_panel(Rect2(0, 268, 640, 92), Color(0.11, 0.085, 0.06, 0.95))
	_bottom.visible = false
	var p: Panel = _bottom

	_log = RichTextLabel.new()
	_log.position = Vector2(4, 2)
	# ⚠ 高度从 40 收到 30：不是随便收的，是底栏只有 92px，而下面两行的
	# **主题最小高度**比我原先设的 22 大得多（LineEdit 31 / OptionButton 25）。
	# 实测（diag_bottom）输入框原本落在 y=336..367，**探出画面 7px**。
	# 三行按真实最小高度重排：日志 30 + 身份行 25 + 输入行 31 + 间距 6 = 92 ✓
	_log.size = Vector2(632, 30)
	_log.bbcode_enabled = true
	_log.scroll_following = true
	_log.scroll_active = false
	_log.add_theme_font_size_override("normal_font_size", 12)
	_log.add_theme_font_size_override("bold_font_size", 12)
	_log.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(_log)

	# 「对谁说」——原来只有一个光秃秃的下拉框，玩家以为是在切换自己的人物。
	# 现在加了标签 + 这个人的一句话身份，切换的意义一眼可见。
	_make_label(p, Vector2(4, 34), Vector2(52, 22), "对谁说")

	_speaker = OptionButton.new()
	_speaker.position = Vector2(58, 34)
	_speaker.size = Vector2(104, 22)
	_speaker.add_theme_font_size_override("font_size", 12)
	# 选项不在这里写死 —— 由 _rebuild_speaker_list() 按「当前在场的角色」填。
	# 角色是按需出现的（game_state.characters_present），
	# 所以不能无条件把七个人都列出来。
	_speaker.selected = 0
	_speaker.item_selected.connect(_on_speaker_changed)
	p.add_child(_speaker)

	_who_hint = _make_label(p, Vector2(168, 34), Vector2(468, 22), "")
	_who_hint.modulate = Color(0.78, 0.82, 0.62)

	_input = LineEdit.new()
	_input.position = Vector2(4, 61)
	# 高度写 24，但实际会被主题最小值(31)撑到 31 —— 位置按 31 算过才不会再探出画面
	_input.size = Vector2(552, 24)
	_input.placeholder_text = "说点什么…（回车发送）"
	_input.add_theme_font_size_override("font_size", 12)
	p.add_child(_input)

	var send := _make_button(p, Rect2(560, 61, 76, 24), "发送")
	send.pressed.connect(_on_send)
	_input.text_submitted.connect(func(_t): _on_send())
	# 底栏默认隐藏，这里不能抢焦点 —— 否则方向键会被输入框吃掉，
	# 玩家开局就发现角色走不动。点「对话」按钮时才 grab_focus。


## 切换对话对象。要让玩家明白「换个人 = 换一套知识和性格」，
## 所以除了更新占位符，还在日志里落一条说明。
func _on_speaker_changed(idx: int) -> void:
	_on_speaker_changed_no_log(idx)
	if idx < 0 or idx >= CHARACTERS.size():
		return
	var c: Dictionary = CHARACTERS[idx]
	append_log("[color=#9fd4a0]—— 现在跟「%s」说话。%s[/color]" % [
		str(c["name"]), str(c.get("hint", ""))])


## 底栏第一次打开时，把「对谁说」这件事讲一遍。
func _explain_speaker_once() -> void:
	if _speaker_explained:
		return
	_speaker_explained = true
	var c: Dictionary = CHARACTERS[maxi(0, _speaker.selected)]
	append_log("[color=#8fd3ff]这里可以选跟谁说话[/color] —— 同一个问题，七个人给你的答案完全不同。")
	append_log("[color=#888888]当前：%s（%s）[/color]" % [
		str(c["name"]), str(c.get("hint", ""))])


func _on_send() -> void:
	var t := _input.text.strip_edges()
	if t == "":
		return
	_input.text = ""
	var cid := ""
	if _speaker.selected >= 0 and _speaker.selected < _speaker_ids.size():
		cid = str(_speaker_ids[_speaker.selected])
	if cid == "":
		return
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
	# 「对谁说」的名单要跟着角色出现情况变 —— 放在 refresh 里，
	# 它本来就订阅了 state_changed，不用再接一根线。
	_rebuild_speaker_list()
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

	# 右侧栏底部：显示「昨天产出了什么」+ 田块进度。
	# 这是玩家判断分工是否合理的唯一依据 —— 没有它，岗位分配就是盲猜。
	var sec := int(_game.query("karez.sections"))
	var g: Dictionary = _game.last_gain()
	var plots_n: int = _game.farmland_plots()
	var daily := ""
	if not g.is_empty():
		daily = "　昨产 木%.0f 土%.0f 粮%.0f" % [
			float(g.get("wood", 0.0)), float(g.get("earth", 0.0)), float(g.get("food", 0.0))]

	# 顶栏第三行是玩家唯一常驻的「该干什么」提示。
	# 缺料时直接给出处（「点功能派人取土」），而不是只报「缺土」——
	# 只说缺什么、不说去哪补，玩家只能干瞪眼（用户实机反馈过）。
	var tip := ""
	var info_d: Dictionary = _game.dig_info()
	if not _game.construction_idle():
		tip = "施工中：%s 剩 %d 天（治水 %d 人）" % [
			str(_game.state["construction"].get("display", "")),
			int(_game.state["construction"].get("days_left", 0)),
			int(_game.job_count("water"))]
		if int(_game.job_count("water")) <= 0:
			tip += "　【没人治水，工期不会走】"
	elif bool(info_d["ok"]):
		tip = "可开工：%s（工期 %d 天）—— 按「功能」开挖" % [
			str(info_d["display"]), int(info_d["days"])]
	else:
		tip = "不能开挖：%s" % str(info_d["reason"])
	_hint.text = "田 %d 块 井 %d/6%s　│　%s" % [plots_n, sec, daily, tip]

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
