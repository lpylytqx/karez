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
## ── 御敌之战 ──
signal battle_requested                       # 玩家主动点「御敌」
signal battle_auto_requested                  # 自动布阵
signal battle_clear_requested                 # 全部收回候补池
signal battle_fight_requested                 # 开战
signal battle_close_requested                 # 结束、打扫战场
signal catch_requested(wild_index: int)        # 派人抓第 N 种野畜（索引对应面板上的按钮）
signal reservoir_requested                     # 扩建涝坝
signal muqam_requested(suite_index: int)       # 在奏乐台办第 N 套木卡姆

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

## 可建造的建筑。
##
## ⚠ 这里**只列「建成后会在地图上出现」的建筑**。判断标准很简单：
##    造完之后玩家能不能看见变化？看不见的就不要放进菜单。
##
## 仓库(cangku) 与 厨房(chufang) 曾经在这个列表里，已移除，原因是它们是**假建造**：
##   · 两者的门槛都是 gate=always —— 地图从第 1 天就画着它们了
##     （见 sites.gd：村子再惨，水和存粮的地方总得有）
##   · 于是玩家花掉材料「建」的，是一栋早就画在那儿的房子，**画面上没有任何变化**
##   · 而且 numbers.json 里这两个 id 既没有 income_per_guest_day 也没有
##     lodging_capacity，建成后除了 +1.5 繁荣度之外没有任何实际效果
## 玩家反馈「建完以后地图也没有显示呀」正是这么来的。
## 现在留在菜单里的两个，建成即刻出现在地图上（place_present 会把「已建成」算作出现条件）。
## 建造菜单每页几行。
##
## 原来菜单是一个硬编码的 2 座建筑常量（驿馆、马厩），而数据里有 13 座 ——
## 仓库/作坊/晾房/围墙/烽燧/居所/毡房区/奏乐台/畜栏**都没出现在菜单里**。
## 现在改成从 numbers.json 取（game_state.all_buildings()）。
## 右栏可视高度只有约 168px，13 行放不下，所以分页，每页 5 行。
const BUILD_PAGE_SIZE := 5

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

## ── 建筑说明浮层（鼠标停在地标上时出现，离开就消失）──
##
## 文案来自 core/sites.gd 的 PLACES[id]["desc"]，不是写在这里 ——
## 这样「地标是什么、有什么用」和地标的坐标/门槛放在同一处，
## 加一个地标不会漏掉它的说明。
var _tip: Panel
var _tip_label: Label
## 镜头档位读数（由 play.gd 的 _set_zoom 调 set_zoom_readout 更新）。
var _zoom_readout: Label

## ── 战斗面板 ──
## 布阵/交战时出现的横幅。放在顶栏**下方**（y=84），不占地图中央 ——
## 战场在屏幕中央，面板压上去就看不见敌我了（用户要的正是"看得见对战过程"）。
var _battle_panel: Panel
var _battle_title: Label
var _battle_status: Label
var _battle_auto: Button
var _battle_clear: Button
var _battle_fight: Button
var _battle_close: Button
## 浮层宽度（640x360 逻辑空间里的像素）。两行文案在这个宽度下不会折行。
const TIP_W := 216.0
const TIP_LINE_H := 15.0

## ── 数值飘字 ──
##
## 资源变化时在资源栏上方浮出一个「+42 水」「-18 粮」，向上飘并淡出。
##
## 为什么值得做：此前推进一天之后，数字是**悄悄变的** ——
## 玩家得自己盯着一堆数字、回忆上一刻是多少，才知道今天到底涨了什么跌了什么。
## 飘字把「这一天发生了什么」直接摆在眼前。
var _floaters: Array = []       # 每项 = [Label, 已存活秒数]
var _prev_res: Dictionary = {}  # 上一次的资源快照，用来算差值
const FLOAT_LIFE := 1.5
const FLOAT_RISE := 26.0
## 飘字从资源栏**下方**起浮，而不是压在资源栏上。
##
## ⚠ 第一版放在 y=30（正好压在资源行上），实机截图里「水 90/300」被糊成了
##   「水5242 水 90/300」—— 飘字盖住了它要说明的那个数字，完全读不出来。
##   顶栏占到 y=78，所以从 104 起、往上飘 26px，正好停在栏边淡出。
const FLOAT_TOP := 104.0

## ── 事件卡插画 ──
##
## 为什么事件插画用 AI 生图，而地形贴图坚决不用：
##   地形贴图要 16px 网格精确、34 色板精确、形状可控。试过「SDXL 出 1024 大图 →
##   最近邻降采样强制像素网格」：网格确实出来了，但**细节在贴图尺寸下会塌成一团
##   颜色涂抹**，而且模型不遵守形制约束（prompt 写明「平顶、不要瓦顶」，它照样画
##   中式翘檐瓦顶）。过程化生成在这三件事上完胜。
##
##   但插画反过来：**不受像素网格约束、要的就是手绘感**，显示尺寸也够大（200x240），
##   这正是扩散模型擅长的位置（与立绘同理，见 ART_STYLE.md：像素风只约束地图与 UI）。
##   生成脚本 scripts/pipeline/make_event_art.py（本地 ComfyUI + SDXL 1.0）。
const EVENT_ART_DIR := "res://events/"
const EVENT_ART_FALLBACK := "manage"
## 事件分类 -> 插画名。分类来自 events.v1.json 的 category 字段。
const EVENT_ART_BY_CATEGORY := {
	"manage": "manage", "explore": "explore",
	"diplomacy": "diplomacy", "crisis": "crisis",
}
## 插画区尺寸。改这里要同步改 make_event_art.py 的 CARD_W / CARD_H。
##
## ⚠ HUD 的坐标空间是 **640x360 逻辑像素**（再 2 倍拉伸到 1280x720 窗口），
##    不是 1280x720。第一版按 760 宽排版，直接超出屏幕 180px、文字被切在右缘 ——
##    布局数字必须按 640x360 算。用 scripts/scenes/diag_layout.tscn 可以量实际矩形。
const EVENT_ART_W := 150
const EVENT_ART_H := 200

var _popup_art: TextureRect
var _art_cache: Dictionary = {}

var _build_menu: Panel
## 建造菜单的分页状态与控件（列表由数据驱动，见 BUILD_PAGE_SIZE）
var _build_btns: Array = []
var _build_page := 0
var _build_hint: Label
var _build_prev: Button
var _build_next: Button

## 分工面板（S3）。每行是一个岗位：标签 + 「−」「＋」两个按钮。
var _job_panel: Panel
## ── 畜牧页 ──
var _animal_panel: Panel
var _animal_title: Label
var _animal_body: Label
var _wild_buttons: Array = []
var _reservoir_btn: Button
## 由 play.gd 注入的"取畜牧信息"回调。HUD 不直接碰 GameState。
var _animal_refresh: Callable = Callable()
## ── 木卡姆页 ──
var _music_panel: Panel
var _music_title: Label
var _music_body: Label
var _suite_buttons: Array = []
var _music_refresh: Callable = Callable()
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
	_build_tip()        # 浮层要先于弹窗建，这样事件弹窗压在它上面
	_build_battle_panel()
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

	# ── 镜头档位读数 ──
	# 放在顶栏**下方**（顶栏常驻占到 y=78），而不是硬塞进顶栏 ——
	# 顶栏三行都已经很满，塞进去会把「分工概览」和「该干什么」挤掉。
	# 位置在右上角：那一带是空白沙漠，不会挡住聚落。
	_zoom_readout = _make_label(p, Vector2(356, 82), Vector2(276, 16), "")
	_zoom_readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_zoom_readout.add_theme_font_size_override("font_size", 11)
	# 压暗一点：它是常驻提示，不该跟正文抢注意力
	_zoom_readout.modulate = Color(0.88, 0.82, 0.72, 0.66)
	_hint.modulate = Color(1.0, 0.9, 0.55)


func _build_right() -> void:
	# 右侧功能栏。**默认隐藏**，用顶栏的「功能」按钮开关 ——
	# 平时把整张地图留给玩家，需要时再拉出来，这样才像游戏而不是调试工具。
	#
	# 宽度给到 208：分工/建造这些页要在一行里放「名称 + − + ＋」，
	# 104 宽的窄栏放不下 —— 第一版就是因此把面板浮在地图正中间，挡住了半张图。
	_right = _make_panel(Rect2(432, 82, 208, 232), Color(0.13, 0.10, 0.07, 0.93))
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

	# 御敌：手动开一场（低治安时每过一天也会自己触发，见 play.gd）
	# ⚠ 这一行原本是「御敌」独占 200 宽。右栏已经排到 y=230（面板高 232），
	#   再加按钮就溢出到屏幕外了 —— 所以把这一行拆成两个 98 宽的按钮，
	#   腾出「畜牧」入口而不加高面板。
	var bbat := _make_button(p, Rect2(4, 206, 98, 24), "御敌")
	bbat.pressed.connect(func(): battle_requested.emit())
	var bherd := _make_button(p, Rect2(106, 206, 98, 24), "畜牧")
	bherd.pressed.connect(func(): _toggle_animal_panel())

	_build_panel()
	_build_job_panel()
	_build_animal_panel()
	_build_music_panel()


## 木卡姆页 —— 覆盖在右侧功能栏上（与分工/建造/畜牧同一个模式）。
##
## 入口是**点地图上的奏乐台**（map_view 的 site_pressed 信号），
## 而不是右栏再加一个按钮：右栏已经排到 230/232，塞不下了；
## 而且"点那个台子办一场"本来就是玩家会先试的动作。
##
## 布局同样压进可视区（右栏实际只有约 168px 可用）：
##   标题 2 / 说明 18 / 六套曲目 2 列 × 3 行 56~126 / 返回 132
func _build_music_panel() -> void:
	_music_panel = Panel.new()
	_music_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_music_panel.position = Vector2.ZERO
	_music_panel.size = _right.size
	_music_panel.add_theme_stylebox_override("panel",
		_panel_style(Color(0.15, 0.11, 0.13, 0.99)))
	_music_panel.visible = false
	_right.add_child(_music_panel)

	var p: Panel = _music_panel
	_music_title = _make_label(p, Vector2(6, 2), Vector2(196, 16), "木卡姆")
	_music_title.modulate = Color(0.98, 0.86, 0.72)

	_music_body = _make_label(p, Vector2(6, 18), Vector2(196, 34), "")
	_music_body.autowrap_mode = TextServer.AUTOWRAP_OFF
	_music_body.modulate = Color(0.88, 0.82, 0.72)

	_suite_buttons.clear()
	for i in range(6):
		var col := i % 2
		var row := i / 2
		var b := _make_button(p, Rect2(6 + col * 100, 56 + row * 24, 96, 22), "—")
		b.visible = false
		var idx := i
		b.pressed.connect(func() -> void: muqam_requested.emit(int(idx)))
		_suite_buttons.append(b)

	var back := _make_button(p, Rect2(6, 132, 196, 22), "返回")
	back.pressed.connect(func(): _toggle_music_panel())


func _toggle_music_panel() -> void:
	if _music_panel == null:
		return
	var show := not _music_panel.visible
	_close_pages()
	if _right != null:
		_right.visible = true
	_music_panel.visible = show
	if show:
		refresh_music_panel()


## 刷新木卡姆页。info 由 play.gd 从 GameState.music_info() 取来后传入 ——
## 与畜牧页同一条分工：界面只渲染，逻辑在 core。
func refresh_music_panel(info := {}) -> void:
	if _music_panel == null or not _music_panel.visible:
		return
	var d: Dictionary = info
	if d.is_empty() and _music_refresh.is_valid():
		d = _music_refresh.call()
	if d.is_empty():
		return
	var suites: Array = d.get("suites", [])
	_music_title.text = "木卡姆　已办 %d 场" % int(d.get("played", 0))
	# ⚠ GDScript **没有** Python 那种切片语法（`s[:52]` 会直接解析失败，
	#   而且是整个文件挂掉）。要截断只能用 substr()。
	if bool(d.get("ok", false)):
		_music_body.text = "%s\n（点一套曲子开场）" % str(d.get("note", "")).substr(0, 40)
	else:
		_music_body.text = "办不了：%s" % str(d.get("reason", "")).substr(0, 44)
	for i in range(_suite_buttons.size()):
		var b: Button = _suite_buttons[i]
		if i >= suites.size():
			b.visible = false
			continue
		var s: Dictionary = suites[i]
		b.visible = true
		b.text = "%s %s" % [str(s.get("display", "")), str(s.get("mood", ""))]
		b.tooltip_text = str(s.get("text", ""))
		b.disabled = not bool(d.get("ok", false))


func set_music_source(cb: Callable) -> void:
	_music_refresh = cb
	refresh_music_panel()


## 畜牧页 —— 覆盖在右侧功能栏上（与分工页/建造页同一个模式）。
##
## 它要回答三个问题，而且是**按玩家的决策顺序**排的：
##   1. 我现在有什么（存栏、每天吃多少草料、每天产出什么）
##   2. 能干什么（派人抓野畜，按难度升序列出；扩建涝坝）
##   3. 为什么干不了（栏位满 / 闲人不够 / 行动点不够 / 材料不够，直接写在按钮上）
## 第 3 条是这个面板存在的主要理由：这个游戏里"点了没反应"是最坏的体验。
##
## ⚠ 布局必须压进**可视区**：右栏是 232 高（82..314），但底部日志栏从 ~250 起
##   把它盖住了，实际只有约 168px 可用。第一版按 232 排，结果第 4 个野畜按钮
##   被切掉、「扩建涝坝/返回」完全看不见 —— 截图核对才发现的。
##   所以野畜做成 2×2 网格，总高收到 158。
func _build_animal_panel() -> void:
	_animal_panel = Panel.new()
	_animal_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_animal_panel.position = Vector2.ZERO
	_animal_panel.size = _right.size
	_animal_panel.add_theme_stylebox_override("panel",
		_panel_style(Color(0.14, 0.13, 0.09, 0.99)))
	_animal_panel.visible = false
	_right.add_child(_animal_panel)

	var p: Panel = _animal_panel
	_animal_title = _make_label(p, Vector2(6, 2), Vector2(196, 16), "畜牧")
	_animal_title.modulate = Color(0.98, 0.88, 0.62)

	_animal_body = _make_label(p, Vector2(6, 18), Vector2(196, 34), "")
	# ⚠ 关掉自动换行：开了之后正文会自己撑成三行、压到下面的按钮上，
	#   而且 Label 高度是固定的，第三行直接被裁掉（截图里看到的正文与按钮重叠）。
	#   改成自己控制的两行，行数就永远是 2 —— 布局才是可预测的。
	_animal_body.autowrap_mode = TextServer.AUTOWRAP_OFF
	_animal_body.modulate = Color(0.88, 0.84, 0.70)

	# 抓野畜：2×2 网格，按难度升序（野畜表就 4 种）
	_wild_buttons.clear()
	for i in range(4):
		var col := i % 2
		var row := i / 2
		var b := _make_button(p, Rect2(6 + col * 100, 56 + row * 24, 96, 22), "—")
		b.visible = false
		var wid := i
		b.pressed.connect(func() -> void: catch_requested.emit(int(wid)))
		_wild_buttons.append(b)

	_reservoir_btn = _make_button(p, Rect2(6, 106, 196, 22), "扩建涝坝")
	_reservoir_btn.pressed.connect(func(): reservoir_requested.emit())

	var back := _make_button(p, Rect2(6, 132, 96, 22), "返回")
	back.pressed.connect(func(): _toggle_animal_panel())
	var refresh := _make_button(p, Rect2(106, 132, 96, 22), "刷新")
	refresh.pressed.connect(func(): refresh_animal_panel())


func _toggle_animal_panel() -> void:
	if _animal_panel == null:
		return
	var show := not _animal_panel.visible
	_close_pages()
	if _right != null:
		_right.visible = true
	_animal_panel.visible = show
	if show:
		refresh_animal_panel()


## 刷新畜牧页。info 由 play.gd 从 GameState.catch_info() 取来后传入 ——
## HUD 不直接碰 GameState，保持"界面只渲染、逻辑在 core"这条分工。
func refresh_animal_panel(info := {}) -> void:
	if _animal_panel == null or not _animal_panel.visible:
		return
	var d: Dictionary = info
	if d.is_empty() and _animal_refresh != null:
		d = _animal_refresh.call()
	if d.is_empty():
		return
	var live: String = str(d.get("livestock", "空栏"))
	var feed: float = float(d.get("feed", 0.0))
	var cap: int = int(d.get("capacity", 0))
	var herd: int = int(d.get("herders", 0))
	_animal_title.text = "畜牧　%s" % live
	var prod: Dictionary = d.get("products", {})
	var plist: Array = []
	for k in prod:
		var amt := float(prod[k])
		if amt > 0.01:
			# 名字由 core 侧译好（play.gd 传 products_cn），HUD 不再自己维护一份对照表 ——
			# 两处各写一套正是这类界面反复出错的原因（第一版这里显示的是 wool/milk/egg）
			plist.append("%s%.1f" % [str(d.get("products_cn", {}).get(k, "")), amt])
	_animal_body.text = "上限 %d　牧人 %d　草料 %.1f/天\n日收 %s" % [
		cap, herd, feed, ("无（先派人抓野畜）" if plist.is_empty() else " ".join(plist))]

	var opts: Array = d.get("options", [])
	for i in range(_wild_buttons.size()):
		var b: Button = _wild_buttons[i]
		if i >= opts.size():
			b.visible = false
			continue
		var o: Dictionary = opts[i]
		b.visible = true
		# 96px 宽：文案压到 8 个字以内，难度只留数字
		b.text = "抓%s %s" % [str(o.get("display", "")), str(o.get("hint", ""))]
		b.disabled = not bool(o.get("ok", false))
	# 扩建涝坝
	if _reservoir_btn != null:
		_reservoir_btn.text = str(d.get("reservoir_text", "扩建涝坝"))
		_reservoir_btn.disabled = not bool(d.get("reservoir_ok", false))


## 让 play.gd 注入"怎么取畜牧信息"，避免 HUD 直接依赖 GameState。
func set_animal_source(cb: Callable) -> void:
	_animal_refresh = cb
	refresh_animal_panel()


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
	if _animal_panel != null:
		_animal_panel.visible = false
	if _music_panel != null:
		_music_panel.visible = false


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

	var btitle := _make_label(_build_menu, Vector2(6, 2), Vector2(196, 15), "── 建造 ──")
	btitle.modulate = Color(0.98, 0.86, 0.72)
	_build_hint = _make_label(_build_menu, Vector2(6, 16), Vector2(196, 13), "")
	_build_hint.modulate = Color(0.82, 0.76, 0.66)
	_build_hint.add_theme_font_size_override("font_size", 11)

	_build_btns.clear()
	for i in range(BUILD_PAGE_SIZE):
		var btn := _make_button(_build_menu, Rect2(4, 30 + i * 22, 200, 21), "—")
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var slot := i
		btn.pressed.connect(func() -> void: _on_build_slot(slot))
		_build_btns.append(btn)

	_build_prev = _make_button(_build_menu, Rect2(4, 143, 62, 21), "上一页")
	_build_prev.pressed.connect(func() -> void:
		_build_page -= 1
		_refresh_build_menu())
	_build_next = _make_button(_build_menu, Rect2(70, 143, 62, 21), "下一页")
	_build_next.pressed.connect(func() -> void:
		_build_page += 1
		_refresh_build_menu())
	var back := _make_button(_build_menu, Rect2(136, 143, 68, 21), "返回")
	back.pressed.connect(_close_pages)


## 按数据刷新建造菜单当前页。
##
## 判据只从 `game_state.build_info()` 取 —— 能不能建、缺什么、为什么不能，
## 全在 core 里算好了，HUD 只负责显示。这样"该不该能建"只有一处定义。
func _refresh_build_menu() -> void:
	if _build_menu == null or _game == null:
		return
	var all: Array = _game.all_buildings()
	_build_page = clampi(_build_page, 0, maxi(0, int(ceil(float(all.size()) / BUILD_PAGE_SIZE)) - 1))
	var start := _build_page * BUILD_PAGE_SIZE
	for i in range(_build_btns.size()):
		var btn: Button = _build_btns[i]
		var idx := start + i
		if idx >= all.size():
			btn.visible = false
			continue
		var id := str(all[idx].get("id", ""))
		var info: Dictionary = _game.build_info(id)
		btn.visible = true
		var parts: Array = []
		for k in info.get("materials", {}):
			parts.append("%s%d" % [_mat_cn(str(k)), int(info["materials"][k])])
		var cost := ("　" + " ".join(parts)) if not parts.is_empty() else ""
		var ok := bool(info.get("ok", false))
		btn.text = "  %s%s" % [str(info.get("display", id)), cost]
		btn.disabled = not ok
		btn.tooltip_text = ("建造 %s" % str(info.get("display", id))) if ok \
			else str(info.get("reason", ""))
	var pages := maxi(1, int(ceil(float(all.size()) / BUILD_PAGE_SIZE)))
	_build_hint.text = "共 %d 座　第 %d/%d 页（灰＝现在建不了，鼠标停上看原因）" \
		% [all.size(), _build_page + 1, pages]
	if _build_prev != null:
		_build_prev.disabled = _build_page <= 0
	if _build_next != null:
		_build_next.disabled = _build_page >= pages - 1


func _on_build_slot(slot: int) -> void:
	if _game == null:
		return
	var all: Array = _game.all_buildings()
	var idx := _build_page * BUILD_PAGE_SIZE + slot
	if idx < 0 or idx >= all.size():
		return
	build_requested.emit(str(all[idx].get("id", "")))
	_build_menu.visible = false


func _on_build_pressed() -> void:
	if _right != null and not _right.visible:
		_right.visible = true
	if _build_menu != null:
		_build_menu.visible = true
		_refresh_build_menu()
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

## ── 地标说明浮层 ──
##
## 平时隐藏，鼠标停到地图上的地标才出现，离开立刻消失（由 play.gd
## 把 map_view 的 site_hovered / site_unhovered 接到 show_site_tip / hide_site_tip）。
##
## 为什么浮层放在 HUD 而不是地图里：浮层属于界面 —— 字体、配色、边距都应该跟
## 顶栏/面板一致；地图只负责回答「光标现在在哪个地标上」。
func _build_tip() -> void:
	_tip = Panel.new()
	_tip.visible = false
	# 绝不能吃掉鼠标事件，否则浮层下面那格就点不到了
	_tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip.add_theme_stylebox_override("panel", _panel_style(Color(0.13, 0.10, 0.07, 0.97)))
	add_child(_tip)

	_tip_label = Label.new()
	_tip_label.position = Vector2(8, 5)
	_tip_label.add_theme_font_size_override("font_size", 12)
	_tip_label.modulate = Color(0.94, 0.89, 0.81)
	# 文案里自己带换行（sites.gd 的 desc 就是两句：是什么 / 有什么用），
	# 所以不用 autowrap —— 让换行位置由文案决定，比按宽度自动折行可控。
	_tip_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_tip.add_child(_tip_label)


## 显示某个地标的说明。site_id 不存在或没写 desc 就什么都不做（保持隐藏）。
func show_site_tip(site_id: String) -> void:
	if _tip == null or _tip_label == null:
		return
	var p: Dictionary = Sites.PLACES.get(site_id, {})
	var text := str(p.get("desc", ""))
	if text.strip_edges() == "":
		hide_site_tip()
		return

	_tip_label.text = text
	# 高度按行数算，而不是问 Label 要最小尺寸 ——
	# autowrap 关掉时 Label 的最小高度不含换行，量不准。
	var lines := text.split("\n").size()
	var h := TIP_LINE_H * float(lines) + 12.0
	_tip.size = Vector2(TIP_W, h)
	_tip_label.size = Vector2(TIP_W - 16.0, h - 10.0)

	# 贴着光标右下角，并夹在屏幕内（HUD 坐标空间是 640x360，不是窗口的 1280x720）
	var m := get_local_mouse_position()
	var sz := size
	var pos := m + Vector2(14, 14)
	pos.x = clampf(pos.x, 4.0, maxf(4.0, sz.x - TIP_W - 4.0))
	pos.y = clampf(pos.y, 4.0, maxf(4.0, sz.y - h - 4.0))
	_tip.position = pos
	_tip.visible = true


func hide_site_tip() -> void:
	if _tip != null:
		_tip.visible = false


## 更新镜头读数。由 play.gd 在缩放/平移/回跟时调用。
##
## ⚠ 要把**跟随状态**一起显示：原来只显示倍数，玩家看到"×1.00"根本不知道
##   自己是不是还跟在主角身上 —— 用户实机就是这个困惑（「我也跟不了啊」）。
func set_zoom_readout(z: float, following := true) -> void:
	if _zoom_readout == null:
		return
	# ⚠ 第一版这里写的是「镜头 ×%.2f　滚轮缩放 · 中键平移 · F 跟随」，
	#   整串约 250px，而标签只有 160px 宽 —— 右对齐时两端都被裁掉，
	#   实机截图里只看得见中间一截。现在标签放宽到 276px，文案也去掉冗余前缀。
	#
	# 平移方式改成「拖动」（不再写"中键"）：中键在笔记本触控板上根本不存在，
	# 左边/中键拖动都支持之后，写"中键"反而把能用的操作说窄了。
	var state := "跟随中" if following else "已脱离 · 按 F 回主角"
	_zoom_readout.text = "×%.2f　%s　滚轮缩放 · 拖动平移" % [z, state]


## ── 战斗横幅 ──
##
## 位置刻意放在**顶栏下方**（y=84）：战场在屏幕正中，面板压上去就看不见敌我了 ——
## 而"直观看到对战过程"正是这个功能的目的。
func _build_battle_panel() -> void:
	_battle_panel = Panel.new()
	_battle_panel.position = Vector2(110, 84)
	_battle_panel.size = Vector2(420, 62)
	_battle_panel.visible = false
	# 面板上有按钮，必须能接收点击（不能像说明浮层那样 MOUSE_FILTER_IGNORE）
	_battle_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_battle_panel.add_theme_stylebox_override("panel",
		_panel_style(Color(0.16, 0.12, 0.09, 0.96)))
	add_child(_battle_panel)

	_battle_title = _make_label(_battle_panel, Vector2(8, 2), Vector2(404, 20), "")
	_battle_title.add_theme_font_size_override("font_size", 13)
	_battle_title.modulate = Color(0.98, 0.90, 0.74)
	_battle_status = _make_label(_battle_panel, Vector2(8, 21), Vector2(404, 17), "")
	_battle_status.add_theme_font_size_override("font_size", 11)
	_battle_status.modulate = Color(0.88, 0.83, 0.72)

	_battle_auto = _make_button(_battle_panel, Rect2(8, 38, 96, 22), "自动布阵")
	_battle_auto.pressed.connect(func(): battle_auto_requested.emit())
	_battle_clear = _make_button(_battle_panel, Rect2(108, 38, 96, 22), "全部收回")
	_battle_clear.pressed.connect(func(): battle_clear_requested.emit())
	_battle_fight = _make_button(_battle_panel, Rect2(208, 38, 96, 22), "开战")
	_battle_fight.pressed.connect(func(): battle_fight_requested.emit())
	_battle_close = _make_button(_battle_panel, Rect2(308, 38, 96, 22), "结束")
	_battle_close.pressed.connect(func(): battle_close_requested.emit())


## 显示战斗横幅。deploying=true 时给「自动布阵 / 全部收回 / 开战」，false 时只给「结束」。
func show_battle_panel(title: String, status: String, deploying: bool) -> void:
	if _battle_panel == null:
		return
	_battle_title.text = title
	_battle_status.text = status
	if _battle_auto != null:
		_battle_auto.visible = deploying
	if _battle_clear != null:
		_battle_clear.visible = deploying
	if _battle_fight != null:
		_battle_fight.visible = deploying
	if _battle_close != null:
		_battle_close.visible = not deploying
	_battle_panel.visible = true


func update_battle_panel(status: String) -> void:
	if _battle_status != null:
		_battle_status.text = status


func hide_battle_panel() -> void:
	if _battle_panel != null:
		_battle_panel.visible = false


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

	# 卡片加宽为插画腾出左侧一列。文字区整体右移，宽度收窄 —— 保证不压到字。
	# 坐标全部按 640x360 逻辑空间算（见 EVENT_ART_W 的注释）。
	var card := Panel.new()
	card.position = Vector2(20, 30)
	card.size = Vector2(600, 300)
	card.add_theme_stylebox_override("panel", _panel_style(Color(0.16, 0.12, 0.09, 0.98)))
	_popup.add_child(card)

	# ── 左侧插画 ──
	_popup_art = TextureRect.new()
	_popup_art.position = Vector2(10, 26)
	_popup_art.size = Vector2(EVENT_ART_W, EVENT_ART_H)
	_popup_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_popup_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_popup_art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	card.add_child(_popup_art)

	# 插画右侧一条 1px 竖线，把图和文分开（不然接缝糊在一起看不出是两栏）
	var rule := ColorRect.new()
	rule.position = Vector2(10 + EVENT_ART_W + 7, 26)
	rule.size = Vector2(1, EVENT_ART_H)
	rule.color = Color(0.74, 0.57, 0.32, 0.35)
	card.add_child(rule)

	var text_x := 10 + EVENT_ART_W + 17          # 177
	var text_w := 600 - text_x - 12              # 411

	_popup_title = _make_label(card, Vector2(text_x, 8), Vector2(text_w, 16), "")
	_popup_title.add_theme_font_size_override("font_size", 12)
	_popup_title.modulate = Color(1.0, 0.86, 0.45)

	_popup_text = RichTextLabel.new()
	_popup_text.position = Vector2(text_x, 28)
	_popup_text.size = Vector2(text_w, 148)
	_popup_text.bbcode_enabled = true
	_popup_text.add_theme_font_size_override("normal_font_size", 12)
	card.add_child(_popup_text)

	_popup_choices = VBoxContainer.new()
	_popup_choices.position = Vector2(text_x, 182)
	_popup_choices.size = Vector2(text_w, 110)
	_popup_choices.add_theme_constant_override("separation", 3)
	card.add_child(_popup_choices)


## 这一条事件该配哪张插画。
##
## 优先级：**季节 > 时段 > 事件分类**。
## 冬天排在最前是因为雪景与其余三季的差别最大，认季节比认分类更有辨识度；
## 夜里排第二，篝火那张的氛围与白天完全不同。
func _event_art_name(event: Dictionary) -> String:
	var season := ""
	var phase := ""
	if _game != null:
		season = str(_game.query("season"))
		phase = str(_game.query("phase"))
	if season == "winter":
		return "winter"
	if phase == "night":
		return "night"
	return str(EVENT_ART_BY_CATEGORY.get(str(event.get("category", "")), EVENT_ART_FALLBACK))


## 取插画贴图，带缓存（事件卡会反复开关，每次 load 没必要）。
## 找不到就返回 null —— 卡片照常显示，只是左侧留白，绝不能因为缺张图就崩。
func _event_art_tex(name: String) -> Texture2D:
	if _art_cache.has(name):
		return _art_cache[name]
	var t = load(EVENT_ART_DIR + name + ".png")
	if t == null:
		push_warning("事件插画缺失：%s%s.png（卡片会留白，不影响游玩）" % [EVENT_ART_DIR, name])
		return null
	_art_cache[name] = t
	return t



## 显示一张「通告」卡：外形与事件卡一致，但没有选项、只有一个「知道了」。
##
## 为什么需要它：灾难发生时**必须有画面** —— 只写日志的话，玩家很容易整场都
## 没注意到自己遭了灾，只看到顶栏数字莫名变了。
## 但灾难不是「事件库」里的一条（它由 disaster 系统掷骰产生），
## 送进 `_events.resolve()` 会因为找不到定义而结算失败 ——
## 所以走这条**不带结算**的通告路径。
func show_notice(title: String, text: String, art_name: String) -> void:
	if _popup == null:
		return
	_popup_event = {}
	_popup_title.text = title
	_popup_text.text = text
	if _popup_art != null:
		var tex := _event_art_tex(art_name)
		_popup_art.texture = tex
		_popup_art.visible = tex != null
	for c in _popup_choices.get_children():
		c.queue_free()
	var b := Button.new()
	b.text = "  知道了"
	b.add_theme_font_size_override("font_size", 12)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.pressed.connect(func() -> void: _popup.visible = false)
	_popup_choices.add_child(b)
	_popup.visible = true


func show_event(event: Dictionary) -> void:
	if event.is_empty():
		append_log("[color=#999999]（当前没有可触发的事件）[/color]")
		return
	_popup_event = event
	_popup_title.text = "【%s】%s" % [str(event.get("category", "")), str(event.get("title", ""))]
	_popup_text.text = str(event.get("text", ""))
	# 左侧插画：按 季节/时段/分类 取图。取不到就让 _popup_art 留空，不影响卡片其余部分。
	if _popup_art != null:
		var tex := _event_art_tex(_event_art_name(event))
		_popup_art.texture = tex
		_popup_art.visible = tex != null

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
	_update_floaters(w, food, float(_game.query("resources.silver")))


## 比较资源快照，给变化的部分生成飘字。
func _update_floaters(water: float, food: float, silver: float) -> void:
	if _prev_res.is_empty():
		# 第一帧只记基线、不飘字，否则开局会凭空冒出几个大数字
		_prev_res = {"water": water, "food": food, "silver": silver}
		return
	# 量级差得远的不要混在一行显示，所以按资源分别给一个起点 x
	var entries := [
		["water", water, "水", Color(0.56, 0.78, 0.84), 8.0],
		["food", food, "粮", Color(0.88, 0.64, 0.24), 74.0],
		["silver", silver, "银", Color(0.94, 0.89, 0.81), 140.0],
	]
	for e in entries:
		var key := str(e[0])
		var now := float(e[1])
		var was := float(_prev_res.get(key, now))
		var d := now - was
		_prev_res[key] = now
		# 变化不足 1 的不飘：否则每天都会冒出「+0 银」这种东西，很快就满屏噪音
		if absf(d) < 0.5:
			continue
		var txt := "%s%d %s" % ["+" if d > 0.0 else "", int(round(d)), str(e[2])]
		# 减少用赭红（色板的火焰山系），增加用该资源自己的颜色
		var col: Color = e[3] if d > 0.0 else Color(0.79, 0.44, 0.29)
		_spawn_float(txt, Vector2(float(e[4]), FLOAT_TOP), col)


func _spawn_float(text: String, at: Vector2, col: Color) -> void:
	var lb := Label.new()
	lb.text = text
	lb.position = at
	lb.add_theme_font_size_override("font_size", 12)
	# 描边：飘字是浮在**地形上**的，沙地是浅色、草地是中间调，
	# 没有深色描边的话米白/金色数字会在沙地上糊掉。加了描边就不挑底色。
	lb.add_theme_constant_override("outline_size", 5)
	lb.add_theme_color_override("font_outline_color", Color(0.12, 0.09, 0.07, 0.9))
	lb.modulate = col
	# 绝不能吃鼠标事件 —— 它就浮在地图上方，挡住点击就麻烦了
	lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(lb)
	_floaters.append([lb, 0.0])


func _process(delta: float) -> void:
	if _floaters.is_empty():
		return
	var keep: Array = []
	for f in _floaters:
		var lb: Label = f[0]
		if lb == null or not is_instance_valid(lb):
			continue
		var age := float(f[1]) + delta
		if age >= FLOAT_LIFE:
			lb.queue_free()
			continue
		var t := age / FLOAT_LIFE
		lb.position.y -= FLOAT_RISE * delta / FLOAT_LIFE
		var c: Color = lb.modulate
		c.a = 1.0 - t * t        # 后段淡得快一点，收尾干净
		lb.modulate = c
		keep.append([lb, age])
	_floaters = keep


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
