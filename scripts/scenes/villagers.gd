extends Node2D
## 把「岗位分配」画到地图上 —— 每个居民一个精灵，被派到哪个岗位就走向哪里。
##
## 为什么需要：
##   岗位系统原本只活在右侧面板的数字里。玩家改了分工，
##   看到的只是数字变了，看不到「人真的去干活了」。
##   把抽象的数字变成地图上走动的人 + 每个工作地点上方的人数，
##   是这类经营游戏最基本的反馈回路。
##
## 数据来源：GameState 的 jobs 字典。每一次 state_changed 都会调一次 sync()，
## 人数变化就增删精灵，岗位变化就换目标点（于是人就自己走过去）。

const TILE := 16.0
## RPG Maker 格式行走图：4 列 × 7 行，前 4 行是 下/左/右/上，单帧 16x16
const FRAME_COLS := 4
const SPEED := 30.0
const FRAME_DUR := 0.16
## 劳作动画：用的第几行、多久换一帧
const WORK_ROW := 5
const WORK_FRAME_DUR := 0.22
## 走到离目标多近就算到了
const ARRIVE_DIST := 2.5

## 工作地点的坐标**不写在这个文件里** —— 从 core/sites.gd 的 JOB_SITE 推导。
## 这样把建筑挪走时，工作地点和居民自动跟着挪。
const ORDER := ["water", "gather_wood", "gather_earth", "craft", "farm", "guard", "idle"]

const JOB_CN := {
	"water": "治水", "gather_wood": "采木", "gather_earth": "取土",
	"craft": "做工", "farm": "耕作", "guard": "守卫", "idle": "待命",
}

## 每个岗位一个颜色，画在居民脚下一小块 —— 让人能看出「谁在哪、在干什么」，
## 而不是只知道某个地方有几个人。
const JOB_COLOR := {
	"water":        Color(0.35, 0.68, 0.95),   # 水蓝
	"gather_wood":  Color(0.42, 0.75, 0.35),   # 木绿
	"gather_earth": Color(0.82, 0.62, 0.32),   # 土黄
	"craft":        Color(0.80, 0.52, 0.85),   # 紫
	"farm":         Color(0.95, 0.85, 0.30),   # 麦黄
	"guard":        Color(0.90, 0.38, 0.33),   # 红
	"idle":         Color(0.62, 0.62, 0.62),   # 灰
}

## 给几个居民换贴图，免得六个人长得一模一样
const SKINS := [
	"res://characters/villager_walk.png",
	"res://characters/villager_walk.png",
	"res://characters/old_kanjiang_walk.png",
	"res://characters/villager_walk.png",
	"res://characters/chuniang_walk.png",
	"res://characters/kazakh_rider_walk.png",
	"res://characters/mukam_artist_walk.png",
	"res://characters/caravan_boss_walk.png",
	"res://characters/villager_walk.png",
]

## 工作地点的**常驻图标** —— 让玩家一眼看出「这块地是干什么的」。
##
## 为什么用工具图标而不是文字：
##   文字标签会连成一片、把地图压住（前面已经吃过这个亏）；
##   图标只有 16px、彼此不会连成带，而且一眼能认出是「镢头/斧子/锹/锤/麦子/刀」。
## 文字名（「治水 2」）仍然只在悬停时出现，和人物名字牌一致。
const SITE_ICON := {
	# ⚠ 文件名是骗人的，别按名字猜：
	#   tool_mallet_01.png   实际是 tiny-town #115 —— **一把镐**（治水要的正是它）
	#   tool_pickaxe_01.png  实际是 tiny-farm #88 —— 一个问号/钩子形状，不是工具
	# 这两个名字是当初 reextract 时按目视起的，起反了。
	# 这次把六个图标逐个放大 11 倍核对过（_wip/_job_icons.png），
	# 其余五个（斧/锹/锤/麦穗/剑）都对，只有治水这一张是错的。
	"water":        "res://tiles/props/tool_mallet_01.png",   # 镐（挖竖井）
	"gather_wood":  "res://tiles/props/tool_axe_01.png",       # 斧子（伐木）
	"gather_earth": "res://tiles/props/tool_shovel_01.png",    # 铁锹（取土）
	"craft":        "res://tiles/props/tool_hammer_01.png",    # 锤子（做工）
	"farm":         "res://tiles/farmland/crop_wheat.png",     # 麦穗（耕作）
	"guard":        "res://tiles/props/item_sword_01.png",     # 剑（守卫）
}

var _game: Node = null
var _map: Node2D = null
## [{sprite, job, target, facing, step, anim_t}]
var _workers: Array = []
## 岗位 -> Label（工作地点上方的人数，悬停才显示）
var _badges: Dictionary = {}
## 岗位 -> Sprite2D（工作地点的常驻工具图标）
var _icons: Dictionary = {}
var _tex_cache := {}
var _hover_job := ""


func _ready() -> void:
	z_index = 6
	for jid in ORDER:
		var lbl := Label.new()
		lbl.add_theme_font_size_override("font_size", 12)
		# 描边让它在任何底色上都读得清（草地上尤其重要）
		lbl.add_theme_color_override("font_outline_color", Color(0.10, 0.08, 0.06))
		lbl.add_theme_constant_override("outline_size", 5)
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lbl.visible = false
		add_child(lbl)
		_badges[jid] = lbl

	# 工作地点的常驻图标（idle 没有，不需要）
	for jid in ORDER:
		if not SITE_ICON.has(jid):
			continue
		var ic := Sprite2D.new()
		ic.texture = load(str(SITE_ICON[jid]))
		ic.centered = true
		ic.z_index = 5
		add_child(ic)
		_icons[jid] = ic


func setup(game: Node, map: Node2D) -> void:
	_game = game
	_map = map
	if _game != null and not _game.state_changed.is_connected(sync):
		_game.state_changed.connect(sync)
	sync()


func _get_tex(path: String) -> Texture2D:
	if not _tex_cache.has(path):
		_tex_cache[path] = load(path)
	return _tex_cache[path]


## 工作地点的像素坐标。**中心来自 core/sites.gd**（唯一真源），
## 同一岗位的多人再按黄金角散开，避免叠成一个人。
func _workplace_pos(jid: String, idx: int) -> Vector2:
	var base: Vector2 = _game.job_xy(jid) if _game != null else Sites.job_xy(jid)
	if idx <= 0:
		return Vector2(base.x * TILE, base.y * TILE)
	var k := float(idx)
	var ang := k * 2.39996          # 黄金角，任意人数都散得均匀
	var rad := 7.0 + 4.0 * sqrt(k)
	return Vector2(base.x * TILE, base.y * TILE) + Vector2(cos(ang), sin(ang) * 0.6) * rad


func _make_worker(index: int) -> Dictionary:
	var sp := Sprite2D.new()
	sp.texture = _get_tex(SKINS[index % SKINS.size()])
	sp.hframes = FRAME_COLS
	sp.vframes = 7
	sp.centered = true
	sp.offset = Vector2(0, -4)      # 和 player.gd 一致：让脚底对齐原点
	# 从聚落中心走出来，而不是凭空出现在工地上
	sp.position = Vector2(20.0 * TILE, 16.0 * TILE)
	sp.z_index = 6

	# 脚下的工种色块。挂在精灵下，跟着一起走。
	var dot := ColorRect.new()
	dot.size = Vector2(7, 3)
	dot.position = Vector2(-3.5, 7)   # 脚底
	dot.color = JOB_COLOR["idle"]
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sp.add_child(dot)

	add_child(sp)
	return {"sprite": sp, "dot": dot, "job": "", "target": sp.position,
		"facing": 0, "step": 1, "anim_t": 0.0}


## 按当前岗位分配，对齐居民数量与各自的目标点。
func sync() -> void:
	if _game == null:
		return

	# 期望的岗位序列：[治水,治水,采木,...]。顺序稳定，人就不会乱换位置。
	var want: Array = []
	for jid in ORDER:
		for i in range(int(_game.job_count(jid))):
			want.append(jid)

	while _workers.size() > want.size():
		var w: Dictionary = _workers.pop_back()
		var sp: Sprite2D = w["sprite"]
		sp.queue_free()
	while _workers.size() < want.size():
		_workers.append(_make_worker(_workers.size()))

	# 每个岗位里数到第几个，用来算散开偏移
	var seen := {}
	for i in range(_workers.size()):
		var jid: String = str(want[i])
		var n := int(seen.get(jid, 0))
		seen[jid] = n + 1
		var w: Dictionary = _workers[i]
		if str(w["job"]) != jid:
			w["job"] = jid
			# 换岗位就换脚下的颜色，让「人去了哪」一眼可见
			var dot: ColorRect = w["dot"]
			if is_instance_valid(dot):
				dot.color = JOB_COLOR.get(jid, Color.WHITE)
		w["target"] = _workplace_pos(jid, n)

	_refresh_badges()


## 更新工作地点上方的人数标签。
## **默认全部隐藏，只在鼠标悬停到该地点时显示** —— 和人物名字牌一致的做法。
## 这样地图平时是干净的，需要查的时候把鼠标移过去就行。
func _refresh_badges() -> void:
	for jid in ORDER:
		var n := int(_game.job_count(jid)) if _game != null else 0
		var lbl: Label = _badges[jid]
		var p := _workplace_pos(jid, 0)

		# 常驻图标：不管有没有人在干活都摆着 —— 它就是「这块地是干什么的」的路牌。
		# 稍微错开一点，免得和干活的人叠在一起。
		if _icons.has(jid):
			var ic: Sprite2D = _icons[jid]
			ic.position = p + Vector2(0.0, -14.0)

		if n <= 0 or jid != _hover_job:
			lbl.visible = false
			continue
		lbl.text = "%s %d" % [JOB_CN.get(jid, jid), n]
		lbl.visible = true
		# 标签是 Control，这里手动摆位置；居中靠 size 估算
		lbl.size = Vector2(80, 20)
		lbl.position = Vector2(p.x - 40.0, p.y - 34.0)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


## 鼠标落在哪个工作地点上（返回岗位 id，没有则空串）。
## 判定区比标签本身大一圈，否则要精准指到 16px 的精灵上才显示，太难点。
func _hover_workplace() -> String:
	if _game == null:
		return ""
	var mp := get_global_mouse_position()
	for jid in ORDER:
		if int(_game.job_count(str(jid))) <= 0:
			continue
		var p := _workplace_pos(str(jid), 0)
		if Rect2(p - Vector2(40.0, 34.0), Vector2(80.0, 60.0)).has_point(mp):
			return str(jid)
	return ""


func _process(delta: float) -> void:
	# 悬停判定也要每帧跑（人数标签靠它显隐）
	var hj := _hover_workplace()
	if hj != _hover_job:
		_hover_job = hj
		_refresh_badges()

	for w in _workers:
		var sp: Sprite2D = w["sprite"]
		if not is_instance_valid(sp):
			continue
		var to: Vector2 = w["target"] - sp.position
		if to.length() > ARRIVE_DIST:
			# 走动：朝向 + 4 帧循环（列 1 站立 / 0 左步 / 2 右步）
			var dir := to.normalized()
			sp.position += dir * SPEED * delta
			w["facing"] = _dir_to_row(dir)
			w["anim_t"] = float(w["anim_t"]) + delta
			if float(w["anim_t"]) >= FRAME_DUR:
				w["anim_t"] = 0.0
				w["step"] = (int(w["step"]) + 1) % 4
			sp.frame = int(w["facing"]) * FRAME_COLS + _step_col(int(w["step"]))
		else:
			sp.position = w["target"]
			# 到了工地：干活的岗位播**劳作动画**，守卫与待命仍站着。
			#
			# 劳作帧用的是素材里**本来就有的第 5 行** —— 64x112 的图按 4 列 7 行切，
			# 代码一直只用到第 0~3 行（四个方向的走），第 4~6 行从来没被用过。
			# 放大核对过（_wip/_sheet_chuniang_walk.png）：第 5 行是弯腰前伸的姿势，
			# 正是干活的样子。**所以这个功能不需要新素材。**
			if _is_labour(str(w["job"])):
				w["anim_t"] = float(w["anim_t"]) + delta
				if float(w["anim_t"]) >= WORK_FRAME_DUR:
					w["anim_t"] = 0.0
					w["step"] = (int(w["step"]) + 1) % FRAME_COLS
				sp.frame = WORK_ROW * FRAME_COLS + int(w["step"])
			else:
				# 停下时回到站立帧
				sp.frame = int(w["facing"]) * FRAME_COLS + 1


## 会「动手」的岗位。守卫是站着看、待命是闲着，都不该播劳作动画。
const LABOUR := ["water", "gather_wood", "gather_earth", "craft", "farm"]


func _is_labour(jid: String) -> bool:
	return LABOUR.has(jid)


## 行走序列：站立1 -> 左步0 -> 站立1 -> 右步2
func _step_col(step: int) -> int:
	match step:
		0: return 1
		1: return 0
		2: return 1
		_: return 2


func _dir_to_row(v: Vector2) -> int:
	if absf(v.x) > absf(v.y):
		return 2 if v.x > 0.0 else 1
	return 0 if v.y > 0.0 else 3
