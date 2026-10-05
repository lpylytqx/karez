extends Node2D
## 把七个有名有姓的角色放到地图上，走过去或点他就能说话。
##
## 为什么需要：
##   原来这七个人只是底栏下拉框里的七个名字，他们不在世界里。
##   「跟不同的人交谈」因此没有空间感 —— 你在哪、他在哪、为什么找他，全都没有。
##   把人画在地图上，站位本身就带着信息：
##   老坎匠守在井口、厨娘在营火边、掌柜在驿馆门口、马匪头目在沙漠里。
##
## 两种交互都支持：
##   · 走近（28 像素内）按 E / 空格
##   · 直接点他

signal talk_requested(cid: String)

const TILE := 16.0
const NEAR_DIST := 30.0
## 顶栏常驻高度（见 hud.gd 的 _build_top）。名字牌不能跑进这个区间。
const TOP_SAFE_Y := 82.0

## id -> 贴图。马匪头目没有专属行走图，借用商队掌柜的再调成暗红。
const SKIN := {
	"lao_kanjiang":      "res://characters/old_kanjiang_walk.png",
	"muqam_yiren":       "res://characters/mukam_artist_walk.png",
	"hasake_qishou":     "res://characters/kazakh_rider_walk.png",
	"hanshang_zhanggui": "res://characters/caravan_boss_walk.png",
	"chuniang":          "res://characters/chuniang_walk.png",
	"shenmi_lvren":      "res://characters/mysterious_traveler_walk.png",
	"mafei_toumu":       "res://characters/caravan_boss_walk.png",
}

## 站位（格）。每一个都贴着对应的建筑：
##   井口(25,15) 涝坝(12,15) 营火(17,15.5) 厨房(4,13.5)
##   巴扎(19,15.5)(21,15.5) 驿馆(26,15) 马厩(31,15.5，lv>=3 才出现)
##   马匪头目放在绿洲之外的沙漠里 —— 他本来就不该在村里
##
## ⚠ 三条硬约束（都是被用户连着指正才定下来的）：
##   1. y ≤ 16.4（=262px）：底栏从 y=268 开始，人会整个人被盖住
##   2. **站建筑的左缘或右缘，不要站正前方。**
##      建筑中心在 y 15~15.5，64px 高的房子占到 y≈17（272px），
##      而底栏从 268 起 —— **根本没有「正前方」这个位置**。
##      我按「正前方」摆过一次，结果是旅人站在涝坝里、压住了水面。
##   3. **每座对应建筑必须开局就存在。** 骑手原本配的是马厩，
##      而马厩门槛是 lv>=3 —— 开局第 1 天他只能站在空沙漠里。
##      现在马厩改为开局即有（见 map_view 的 _place_props）。
const SPOT := {
	"lao_kanjiang":      Vector2(23.0, 13.4),   # 竖井链旁（他守着井，本来就不住村里）
	"muqam_yiren":       Vector2(20.0, 16.4),   # 两座巴扎摊位的接缝处 (18~22)
	"hasake_qishou":     Vector2(29.5, 16.4),   # 马厩左缘（马厩 29.5~32.5）
	"hanshang_zhanggui": Vector2(24.0, 16.4),   # 驿馆左缘（驿馆 24~28）
	"chuniang":          Vector2(15.0, 16.4),   # 灶左缘（灶 16~18）
	"shenmi_lvren":      Vector2(9.6, 16.4),    # 涝坝左缘（涝坝 10~14）
	"mafei_toumu":       Vector2(35.0, 6.0),    # 沙漠（村里不该有他）
}

## 名牌纵向偏移。除乐师外统一 -30（贴着本人头顶）。
## 厨娘(17) 与 乐师(20) 只隔 3 格 = 48px，窄于名牌宽 62px，
## 所以把乐师抬高到 -54 让两块错开。
const LABEL_DY := {
	"lao_kanjiang": -30.0, "muqam_yiren": -54.0, "hasake_qishou": -30.0,
	"hanshang_zhanggui": -30.0, "chuniang": -30.0, "shenmi_lvren": -30.0,
	"mafei_toumu": -30.0,
}

const FACE_ROW := {"lao_kanjiang": 0, "muqam_yiren": 0, "hasake_qishou": 1,
	"hanshang_zhanggui": 0, "chuniang": 0, "shenmi_lvren": 0, "mafei_toumu": 2}

const TINT := {"mafei_toumu": Color(1.0, 0.72, 0.66)}

## 名牌的两档外观。
## 平时「轻」：小字号 + 淡底衬 —— 五块牌子连在一起会成一条深色带，把地图压住
## （用户截图里就是这个观感）。
## 靠近/悬停时「亮」：字号放大、底衬加深、变绿并带上操作提示。
const FONT_IDLE := 10
const FONT_HOT := 12
const BG_IDLE := 0.28
const BG_HOT := 0.78
const W_IDLE := 62.0
const W_HOT := 78.0
const H_LBL := 18.0

## 平时是暖金（可读、不抢眼），靠近/悬停变绿提示「可以交互」
const NAME_COLOR := Color(1.0, 0.92, 0.62)
const NEAR_COLOR := Color(0.55, 1.0, 0.60)

var _player: Node2D = null
var _names: Array = []          # 全部名字，用于「谁最近」判断
## [{id, sprite, label, base}]
var _folk: Array = []
var _hover := ""
var _near := ""


func setup(player: Node2D) -> void:
	_player = player
	z_index = 7
	for cid in SPOT:
		_make_person(str(cid))
	set_process_unhandled_input(true)


func _make_person(cid: String) -> void:
	var cell := Vector2(SPOT[cid].x * TILE, SPOT[cid].y * TILE)

	var sp := Sprite2D.new()
	sp.texture = load(str(SKIN[cid]))
	sp.hframes = 4
	sp.vframes = 7
	sp.centered = true
	sp.offset = Vector2(0, -4)
	sp.position = cell
	sp.z_index = 7
	sp.frame = int(FACE_ROW.get(cid, 0)) * 4 + 1     # 站立帧
	if TINT.has(cid):
		sp.modulate = TINT[cid]
	add_child(sp)

	# 名字牌。带描边 + 半透明底衬 ——
	# ⚠ 只加描边不够：聚落这一排的名牌会压在深色的竖井口上，
	# 深色描边在深色背景上等于没有，字直接看不见了
	# （第一版实机截图里「商队掌柜」只剩「掌柜」两个字）。
	var lbl := Label.new()
	lbl.text = str(_display(cid))
	lbl.add_theme_font_size_override("font_size", FONT_IDLE)
	lbl.add_theme_color_override("font_color", NAME_COLOR)
	lbl.add_theme_color_override("font_outline_color", Color(0.08, 0.06, 0.05))
	lbl.add_theme_constant_override("outline_size", 4)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.08, 0.06, BG_IDLE)
	sb.set_corner_radius_all(3)
	sb.content_margin_left = 3.0
	sb.content_margin_right = 3.0
	lbl.add_theme_stylebox_override("normal", sb)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# ⚠ z_index 必须显式抬高，而且要关掉 z_as_relative。
	# 这不是可有可无的保险：Control 的 z_index 默认是 0，而竖井那类道具
	# 的 z_index 是 1~4 —— 名牌压在竖井口上时会被整个盖住。
	# 实机截图里「掌柜」只剩一个「巨」字，就是被竖井盖掉的结果。
	lbl.z_index = 12
	lbl.z_as_relative = false
	add_child(lbl)
	# ⚠ 必须在 add_child 之后设尺寸，而且要用 custom_minimum_size 兜住：
	# 只设 size 的话，Godot 会按文字宽度把它收回最小尺寸，
	# 结果名牌宽度随名字长短变化、位置也跟着偏 ——
	# 实机截图里「商队掌柜」因此只显示出「掌柜」两个字。
	lbl.custom_minimum_size = Vector2(W_IDLE, H_LBL)
	lbl.size = Vector2(W_IDLE, H_LBL)
	# ⚠ y 要夹在顶栏之下。顶栏是 0..78 且常驻，名字牌跑到它后面就被整个盖住 ——
	# 马匪头目站在东北沙漠 (35,6)，名牌原本落在 y=62，实机截图里被顶栏切掉一半。
	var ly: float = maxf(TOP_SAFE_Y, cell.y + float(LABEL_DY.get(cid, -34.0)))
	lbl.position = Vector2(cell.x - W_IDLE * 0.5, ly)

	_folk.append({"id": cid, "sprite": sp, "label": lbl, "base": cell})


func _display(cid: String) -> String:
	# 地图上的名牌用短名 —— 全名在下拉框和身份说明里已经有了。
	# 短名的另一个好处：名字牌宽度统一，聚落那一排五个人不会互相挤。
	match cid:
		"lao_kanjiang": return "老坎匠"
		"muqam_yiren": return "乐师"
		"hasake_qishou": return "骑手"
		"hanshang_zhanggui": return "掌柜"
		"chuniang": return "厨娘"
		"shenmi_lvren": return "旅人"
		"mafei_toumu": return "马匪"
	return cid


## 全名。左下角提示和日志用这个，地图名牌用短名。
func full_name(cid: String) -> String:
	match cid:
		"lao_kanjiang": return "老坎匠"
		"muqam_yiren": return "木卡姆艺人"
		"hasake_qishou": return "哈萨克骑手"
		"hanshang_zhanggui": return "商队掌柜"
		"chuniang": return "厨娘"
		"shenmi_lvren": return "神秘旅人"
		"mafei_toumu": return "马匪头目"
	return cid


## 点击地图上的人 -> 跟他说话。
## 用 _unhandled_input 而不是 Area2D：HUD 上的按钮会先吃掉点击，
## 所以点面板不会误触发地图上的人。
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		var hit := _pick(_mouse_world())
		if hit != "":
			talk_requested.emit(hit)
			get_viewport().set_input_as_handled()
			return
	if event is InputEventKey and event.pressed and not event.echo \
			and (event.keycode == KEY_E or event.keycode == KEY_SPACE):
		if _near != "":
			talk_requested.emit(_near)
			get_viewport().set_input_as_handled()


func _mouse_world() -> Vector2:
	return get_global_mouse_position()


## 命中测试：人的包体比 16x16 的贴图稍大一点，好点一些
func _pick(p: Vector2) -> String:
	for f in _folk:
		var c: Vector2 = f["base"]
		if Rect2(c - Vector2(9, 22), Vector2(18, 24)).has_point(p):
			return str(f["id"])
	return ""


func _process(_delta: float) -> void:
	# 悬停高亮 + 走近提示。两者共用同一套名字牌变色，
	# 让玩家看出「这些人是可以说话的」。
	var hov := _pick(get_global_mouse_position())
	var near := ""
	if _player != null and is_instance_valid(_player):
		var best := NEAR_DIST
		for f in _folk:
			var d: float = (_player.global_position - Vector2(f["base"])).length()
			if d < best:
				best = d
				near = str(f["id"])

	if hov == _hover and near == _near:
		return
	_hover = hov
	_near = near

	for f in _folk:
		var cid := str(f["id"])
		var lbl: Label = f["label"]
		var hot := (cid == near or cid == hov)
		# 两档外观。平时小字号 + 淡底衬，靠近才放大变绿 ——
		# 五块牌子都用满字号加深底衬时，会连成一条横贯地图的深色带。
		lbl.add_theme_font_size_override("font_size", FONT_HOT if hot else FONT_IDLE)
		var w := W_HOT if hot else W_IDLE
		lbl.custom_minimum_size = Vector2(w, H_LBL)
		lbl.size = Vector2(w, H_LBL)
		lbl.position.x = Vector2(f["base"]).x - w * 0.5
		var sb: StyleBoxFlat = lbl.get_theme_stylebox("normal")
		if sb is StyleBoxFlat:
			sb.bg_color = Color(0.10, 0.08, 0.06, BG_HOT if hot else BG_IDLE)
		if cid == near:
			lbl.text = "%s ◂E" % _display(cid)
			lbl.add_theme_color_override("font_color", NEAR_COLOR)
		elif cid == hov:
			lbl.text = "%s ◂点" % _display(cid)
			lbl.add_theme_color_override("font_color", NEAR_COLOR)
		else:
			lbl.text = _display(cid)
			lbl.add_theme_color_override("font_color", NAME_COLOR)
