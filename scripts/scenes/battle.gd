extends Node2D
## 御敌之战：**来袭 → 镜头飞过去 → 布阵 → 自动交手 → 胜负结算**。
##
## 设计取舍（先说清楚，免得后面越做越像另一款游戏）
##   · 战场就在**世界地图上**（东边新扩出来的沙漠），不是另开一个界面 ——
##     用户要的是"跳转到敌军攻来的地方的放大图"，所以是镜头飞过去，不是切场景。
##   · 布阵是**点格子放人**，不是自由拖拽：5 个人、6 个位，格子的信息量已经够，
##     自由拖拽在 16px 的格子上既难点准、也看不出阵型。
##   · 交手是**自动**的：玩家在布阵阶段已经做完决策，打起来再操作就变成动作游戏了。
##     玩家要看的是"我的安排管不管用"。
##
## 与其它系统的接口：
##   · 上游（play.gd）调 start()，并把镜头交给它（fly_to）
##   · 它通过信号回报进展，HUD 只负责显示

signal started(roster_summary: String, enemies: int)
signal deploy_changed(placed: int, total: int)
signal phase_changed(phase: int)
signal ended(result: Dictionary)

enum Phase { IDLE, DEPLOY, FIGHT, RESULT }

const PHASE_NAME := {
	Phase.IDLE: "待命", Phase.DEPLOY: "布阵",
	Phase.FIGHT: "交战", Phase.RESULT: "战果",
}

## 战场中心（世界像素）。选在东边新扩出来的沙漠 —— 原地图的村落在 x<40 格，
## 这里 x≈46 格，是"敌军从东边来"的那条路。
const ARENA_CENTER := Vector2(46.0 * 16.0, 17.0 * 16.0)
const ARENA_W := 224.0
const ARENA_H := 112.0

## 布阵槽位：2 行 × 3 列，在西侧（我方靠西、敌方从东来）
const MAX_FIGHTERS := 6
## ── 战斗数值的**默认值** ──
## 实际取值来自 numbers.json 的 battle 段（见 _load_config）；
## 这些常量只是兜底：万一数据缺了字段，也不至于把战斗跑成 0 伤害或瞬移。
const DEF_STEP_TIME := 0.62      # 每拍移动/攻击一次
const DEF_MOVE_PER_STEP := 11.0
const DEF_ATTACK_RANGE := 20.0
const ENEMY_SPAWN_X := 118.0     # 相对战场中心的东侧入场点
const DEF_ENEMY_DEPLOY := 1.6    # 敌军入场走位时间

## 生效中的数值（setup 时从数据里读一次）
var _step_time := DEF_STEP_TIME
var _move_per_step := DEF_MOVE_PER_STEP
var _attack_range := DEF_ATTACK_RANGE
var _enemy_deploy_time := DEF_ENEMY_DEPLOY
var _fighter_hp := 3.0
var _fighter_atk := 3.0
var _raider_hp := 2.4
var _raider_atk := 2.4
var _reward: Dictionary = {}

var _game: Node = null
var _phase: int = Phase.IDLE

var _units: Array = []           # 每项见 _make_unit
var _pool: int = 0               # 还没放上阵的人手（= _roster.size()，同步维护）
## 还没上阵的人**按兵种排队**。放人时从队首取 —— 于是"我手上还有什么兵"是确定的，
## 玩家可以据此决定先放谁、放哪儿。
##
## 为什么不用"一个人一个 id"：战场上看不出来谁是谁，队列里只要兵种就够；
## 候补区读数也只要"盾 2 弓 1 乡 2"这种概括。
var _roster: Array = []
## 兵种表（numbers.json 的 battle.troops.list）
var _troops: Dictionary = {}
## 敌方人数上限（numbers.json 的 battle.max_enemies）。
## 写死 6 会压平难度曲线：来袭人数公式到了后期会算出 7~8 人。
var _max_enemies := 8
## 开战那一刻的阵型快照。
##
## ⚠ 必须**开战时存**，不能再结算时现算：结算时人已经死光了，
##   `_placed_indices()` 过滤掉阵亡者之后就是空的，日志会打出「未布阵」——
##   而"这一仗到底用什么阵打的"正是我最需要从日志里知道的事。
var _formation_snapshot := ""
## 开战时**已上阵的兵种构成**快照（「盾1 弓2 乡2」）。
## 同样必须开战时拍：结算时候补队列和人物都已变样。
var _roster_snapshot := ""
var _enemy_count := 0
var _step_t := 0.0
var _spawn_t := 0.0
var _result: Dictionary = {}
var _white: ImageTexture = null
var _floor: Sprite2D = null
## 战场中线。**必须留引用** —— 第一版建完就不管了，_clear() 里没有它，
## 于是每打一场就在战场上多留一条中线，越打越多（边界测试数出 4 个残留精灵）。
var _midline: Sprite2D = null
var _ui_root: Node2D = null


func setup(game: Node) -> void:
	_game = game
	_white = ImageTexture.create_from_image(Image.create(1, 1, false, Image.FORMAT_RGBA8))
	_load_config()


## 从 numbers.json 的 `battle` 段读战斗数值。
##
## 为什么搬出代码：原来 HP/攻击力/每拍间隔这些都硬写在 battle.gd 里，
## 要调平衡就得改代码 —— 而项目里其它数值一律在 numbers.json，这是唯一的例外。
## 缺字段一律退回 DEF_* 兜底，数据不完整时战斗仍要能跑。
func _load_config() -> void:
	var b: Dictionary = {}
	if _game != null and _game.numbers != null:
		b = _game.numbers.get("battle", {})
	_step_time = float(b.get("step_seconds", DEF_STEP_TIME))
	_move_per_step = float(b.get("move_per_step", DEF_MOVE_PER_STEP))
	_attack_range = float(b.get("attack_range", DEF_ATTACK_RANGE))
	_enemy_deploy_time = float(b.get("enemy_deploy_seconds", DEF_ENEMY_DEPLOY))
	var f: Dictionary = b.get("fighter", {})
	var r: Dictionary = b.get("raider", {})
	_fighter_hp = float(f.get("hp", 3.0))
	_fighter_atk = float(f.get("attack", 3.0))
	_raider_hp = float(r.get("hp", 2.4))
	_raider_atk = float(r.get("attack", 2.4))
	# 敌方人数上限也走数据：原来是写死的 6，而来袭人数公式会算出 7~8，
	# 写死的话后期限流、难度曲线直接压平。默认 8。
	_max_enemies = maxi(1, int(b.get("max_enemies", 8)))
	# 兵种表：每个兵种的血/攻/射程/速度都在这儿，`_make_fighter` 按 id 取
	var tr: Dictionary = b.get("troops", {})
	_troops = tr.get("list", {})
	_reward = b.get("reward", {})


## 兵种配置。查不到就返回空字典（调用处会退回默认值）。
func _troop_cfg(troop_id: String) -> Dictionary:
	var c = _troops.get(troop_id, {})
	return c if c is Dictionary else {}


## 兵种显示名（「盾卫」这种）。日志和候补区读数都用它。
func _troop_name(troop_id: String) -> String:
	var c := _troop_cfg(troop_id)
	return str(c.get("display", troop_id))


## 取一条战斗奖励数值，缺了就返回兜底值。
func _reward_num(key: String, fallback: float) -> float:
	return float(_reward.get(key, fallback))


func is_active() -> bool:
	return _phase == Phase.DEPLOY or _phase == Phase.FIGHT


func current_phase() -> int:
	return _phase


# ---------------------------------------------------------------------------
# 开始 / 布阵
# ---------------------------------------------------------------------------

## 开一场御敌之战。
##   roster  —— 兵种 id 的名单，一个人一项（由 play.gd 按**当前分工**推出来）。
##              名单里的顺序就是放人时从候补区取人的顺序。
##   enemies —— 来犯人数
func start(roster: Array, enemies: int) -> void:
	if is_active():
		return
	_clear()
	# 名单为空（理论上不会，play.gd 至少给一个）时兜底一个乡勇，
	# 否则会开出一场"零人可布阵"的死局
	_roster = roster.duplicate() if not roster.is_empty() else ["militia"]
	if _roster.size() > MAX_FIGHTERS:
		_roster.resize(MAX_FIGHTERS)
	_pool = _roster.size()
	_enemy_count = clampi(enemies, 1, _max_enemies)
	_phase = Phase.DEPLOY
	_step_t = 0.0
	_spawn_t = 0.0
	_result = {}

	_build_arena()
	_build_zone_areas()
	emit_signal("started", roster_summary(), _enemy_count)
	emit_signal("phase_changed", _phase)
	emit_signal("deploy_changed", 0, _pool)


## 候选名单的概括，给 HUD 显示（「盾 1 弓 2 乡 2」）。
func roster_summary() -> String:
	return _compose_summary(_roster)


## 按兵种统计一份名单，拼成「盾 1 弓 2 乡 2」。
## 兵种的显示顺序固定（盾→乡→平民→弓），不按数量排 ——
## 否则人数一变顺序就跳，读起来反而慢。
func _compose_summary(list: Array) -> String:
	if list.is_empty():
		return "无"
	var parts: Array = []
	for tid in ["shield", "militia", "levy", "archer"]:
		var n := 0
		for t in list:
			if str(t) == tid:
				n += 1
		if n > 0:
			parts.append("%s%d" % [_troop_name(tid), n])
	return " ".join(parts)


func _build_arena() -> void:
	# 战场地面：踩实的土地（半透明深色）+ 一条中线，让"两军对峙"读得出来
	_floor = _rect(Vector2(ARENA_W, ARENA_H), Color(0.24, 0.17, 0.11, 0.34))
	_floor.position = ARENA_CENTER
	_floor.z_index = 6
	add_child(_floor)
	var mid := _rect(Vector2(1, ARENA_H - 16.0), Color(0.85, 0.78, 0.62, 0.18))
	mid.position = ARENA_CENTER
	mid.z_index = 7
	add_child(mid)
	_midline = mid


## ── 我方布阵区（自由站位）──
##
## 从"6 个固定槽位"改过来的。玩家的反馈原话：「阵型是固定的，但是我不要固定的」。
## 他说得对：六个格子里挪来挪去只是排列组合，摆不出自己的形状 ——
## 散开、扎堆、一字排开、楔形、压上去，这些一个都表达不了。
##
## 改成自由站位之后，阵型**真的影响战果**：
##   交手逻辑本来就是「找最近的敌人、够得着就打」，所以
##   谁站得靠前谁先接战、站得散会被逐个击破、扎堆则集火。
## 站位不吸附网格 —— 要吸也该吸到"人"身上，不是吸到格子。
##
## 区域选在战场西半边（敌军从东边来）。东边界给到很靠前的位置，
## 允许玩家主动压上去：「往前站换先手」是一个真实的取舍。
const DEPLOY_ZONE_OFFSET := Vector2(-112, -42)
const DEPLOY_ZONE_SIZE := Vector2(116, 84)

## 候补区：没上阵的人待在这儿。把人拖进去就等于收回。
const POOL_ZONE_OFFSET := Vector2(-156, -20)
const POOL_ZONE_SIZE := Vector2(32, 40)

## 抓人时的判定半径。给得比人物本体（16px）略大，缩放下才点得准。
const GRAB_RADIUS := 12.0

var _deploy_zone: Sprite2D = null
var _deploy_label: Label = null
var _pool_zone: Sprite2D = null
var _pool_label: Label = null
## 正在拖动的单位在 _units 里的下标（-1 = 没在拖）
var _dragging := -1
## 拖起来之前的位置：落在区域外就放回这里，不惩罚玩家
var _drag_home := Vector2.ZERO
## 光标与单位位置之间的偏移，拖动时保持手感不变
var _drag_off := Vector2.ZERO


func _deploy_rect() -> Rect2:
	return Rect2(ARENA_CENTER + DEPLOY_ZONE_OFFSET, DEPLOY_ZONE_SIZE)


func _pool_rect() -> Rect2:
	return Rect2(ARENA_CENTER + POOL_ZONE_OFFSET, POOL_ZONE_SIZE)


## 画一块半透明区域，返回它的精灵。
func _build_zone(rect: Rect2, col: Color) -> Sprite2D:
	var sp := _rect(rect.size, col)
	sp.position = rect.position + rect.size * 0.5     # _rect 是居中摆放
	sp.z_index = 7
	add_child(sp)
	return sp


## 区域上的一行小字（布阵区标题 / 候补区读数）。
## above=true 放区域上方，false 放下方 —— 候补区紧挨在布阵区左边，
## 两个标签都放上面会撞在一起。
func _make_zone_label(rect: Rect2, above: bool) -> Label:
	var lb := Label.new()
	lb.position = rect.position + Vector2(-14, -16 if above else rect.size.y + 1)
	lb.size = Vector2(rect.size.x + 28, 15)
	lb.add_theme_font_size_override("font_size", 10)
	lb.add_theme_color_override("font_color", Color(0.95, 0.90, 0.72))
	# 描边：它压在沙地上，没描边会糊成一团
	lb.add_theme_constant_override("outline_size", 4)
	lb.add_theme_color_override("font_outline_color", Color(0.12, 0.09, 0.07, 0.9))
	lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lb.z_index = 13
	lb.z_as_relative = false
	add_child(lb)
	return lb


func _build_zone_areas() -> void:
	var dr := _deploy_rect()
	_deploy_zone = _build_zone(dr, Color(0.30, 0.38, 0.54, 0.20))
	_deploy_label = _make_zone_label(dr, true)
	_deploy_label.text = "我方布阵区 · 随便站"

	var pr := _pool_rect()
	_pool_zone = _build_zone(pr, Color(0.34, 0.44, 0.30, 0.30))
	# 候补区读数放**下方**：它和布阵区横向紧挨着，两个标题都放上面会撞在一起
	_pool_label = _make_zone_label(pr, false)
	_update_pool_label()


## 拖动中的落点反馈。
##
## 为什么需要：只让人跟着光标走，玩家判断不出"松手会怎样" ——
## 实机日志里第一次拖动就是 `拖动 → 空地：放回原位`，因为当时落点没有任何提示。
## 现在：落在区里 → 布阵区亮；往西拖（会收回）→ 候补区亮。
##
## ⚠ 亮灯规则必须和 `_end_drag` 的判定**完全一致**，否则提示说"会落这"、实际落别处。
func _update_drop_hint() -> void:
	var to_pool := false
	var in_zone := false
	if _dragging >= 0:
		var u: Dictionary = _units[_dragging]
		var x: float = u["pos"].x
		to_pool = x < _deploy_rect().position.x
		in_zone = not to_pool
	if _deploy_zone != null and is_instance_valid(_deploy_zone):
		_deploy_zone.modulate = Color(1.55, 1.45, 1.0) if in_zone else Color(1, 1, 1)
	if _pool_zone != null and is_instance_valid(_pool_zone):
		_pool_zone.modulate = Color(1.7, 1.35, 1.0) if to_pool else Color(1, 1, 1)


func _update_pool_label() -> void:
	if _pool_label != null and is_instance_valid(_pool_label):
		# 候补区显示的是**兵种构成**而不仅仅是一个人数 ——
		# 玩家要据此决定"先放谁、放哪儿"，只知道还剩 3 个人是不够的。
		_pool_label.text = "候补 %d：%s" % [_pool, _compose_summary(_roster)]
	if _deploy_label != null and is_instance_valid(_deploy_label):
		_deploy_label.text = "我方布阵区 · 随便站（拖到左边收回）"


func _emit_deploy() -> void:
	_update_pool_label()
	emit_signal("deploy_changed", _placed_count(), _placed_count() + _pool)


## 布阵动作打一行日志。
##
## 为什么值得打：布阵是**纯交互**，出了问题（拖不动、人丢了、位置不对）
## 我在日志里什么都看不到 —— 只能等玩家描述，而"描述手感"这件事很容易丢信息。
## 打上之后，玩家实机操作完，我直接看日志就知道他点了什么、结果如何。
## 频率也够低（全是人手点的），不会刷屏。
func _note(msg: String) -> void:
	print("[布阵] %s" % msg)


## 已上阵的单位下标（我方、活着）。
func _placed_indices() -> Array:
	var out: Array = []
	for i in range(_units.size()):
		var u: Dictionary = _units[i]
		if u.is_empty() or int(u["side"]) != 0 or not bool(u["alive"]):
			continue
		out.append(i)
	return out


func _placed_count() -> int:
	return _placed_indices().size()


## 光标下是哪个"我方已上阵的人"（抓起来拖用）。没有返回 -1。
## 半径比人物本体略大：16px 的人在缩放下按精确尺寸很难点中。
func _unit_at(mp: Vector2) -> int:
	var best := -1
	var bd := GRAB_RADIUS
	for i in _placed_indices():
		var d: float = mp.distance_to(_units[i]["pos"])
		if d < bd:
			bd = d
			best = i
	return best


## 已上阵的人各自的兵种（顺序同 _placed_indices）。
func _placed_troops() -> Array:
	var out: Array = []
	for i in _placed_indices():
		out.append(str(_units[i].get("troop", "militia")))
	return out


## 阵型的人话描述，打日志用。
##
## 自由站位之后"前排/后排"这种格子概念没了，改成描述**形状**：
## 最前沿离敌军多远、队伍纵深、横向铺开多宽。
## 玩家说"我这样摆结果不对"时，我据此能还原他摆的是什么阵。
func _formation_text() -> String:
	var idx := _placed_indices()
	if idx.is_empty():
		return "未布阵"
	var min_x := INF
	var max_x := -INF
	var min_y := INF
	var max_y := -INF
	for i in idx:
		var p: Vector2 = _units[i]["pos"]
		min_x = minf(min_x, p.x)
		max_x = maxf(max_x, p.x)
		min_y = minf(min_y, p.y)
		max_y = maxf(max_y, p.y)
	# 敌军列阵在中心以东 46px 处
	var enemy_line := ARENA_CENTER.x + 46.0
	return "最前沿距敌 %.0f　纵深 %.0f　横展 %.0f" % [
		enemy_line - max_x, max_x - min_x, max_y - min_y]


## 把坐标夹进布阵区（留出半个身位，免得人贴边贴一半露在外面）。
func _clamp_to_deploy(pos: Vector2) -> Vector2:
	var r := _deploy_rect()
	var m := 8.0
	return Vector2(
		clampf(pos.x, r.position.x + m, r.position.x + r.size.x - m),
		clampf(pos.y, r.position.y + m, r.position.y + r.size.y - m))


## 把一个单位挪到某处（自由站位，只管落点）。
func _move_unit(unit_idx: int, pos: Vector2) -> void:
	if unit_idx < 0 or unit_idx >= _units.size() or _units[unit_idx].is_empty():
		return
	var u: Dictionary = _units[unit_idx]
	u["pos"] = pos
	_sync_unit(u)


## 释放一个单位的节点并把它的位置在 _units 里空出来。
func _free_unit(unit_idx: int) -> void:
	if unit_idx < 0 or unit_idx >= _units.size():
		return
	var u: Dictionary = _units[unit_idx]
	if u.is_empty():
		return
	for k in ["sprite", "bar", "bar_bg"]:
		var n = u.get(k)
		if n != null and is_instance_valid(n):
			n.queue_free()
	_units[unit_idx] = {}


## 从候补池在某处放一个人（自由站位，落点会被夹进布阵区）。
## 放的是**队首那个兵种** —— 想先摆弓手就先把前面的放掉，或者先放完再拖。
func _place_at(pos: Vector2) -> bool:
	if _phase != Phase.DEPLOY or _pool <= 0 or _roster.is_empty():
		return false
	var troop := str(_roster.pop_front())
	_pool = _roster.size()
	var p := _clamp_to_deploy(pos)
	var idx := _units.size()
	_units.append(_make_fighter(p, troop))
	_note("放人 → %s (%.0f, %.0f)　上阵 %d，候补 %d（%s）" % [
		_troop_name(troop), p.x, p.y, _placed_count(), _pool, _compose_summary(_roster)])
	_emit_deploy()
	return true


## 把一个人收回候补池（队列末尾）。
##
## ⚠ 必须**同时**维护 `_roster` 和 `_pool`。曾经有个分支只写了 `_pool += 1`
##   而没把人塞回队列，于是两者脱钩：候补显示还有人，但 `_place_at` 从空队列取，
##   直接放不上去。凡是"收回"都走这一个函数，不再各处手写。
func _return_to_pool(unit_idx: int) -> void:
	if unit_idx < 0 or unit_idx >= _units.size() or _units[unit_idx].is_empty():
		return
	var troop := str(_units[unit_idx].get("troop", "militia"))
	_free_unit(unit_idx)
	_roster.append(troop)
	_pool = _roster.size()
	_note("收回 %s　上阵 %d，候补 %d" % [_troop_name(troop), _placed_count(), _pool])


## 把一个人收回候补池。兵种回到队列**末尾**（不插队，免得收回再放就换了顺序）。
func _take_out(unit_idx: int) -> void:
	_return_to_pool(unit_idx)


func _begin_drag(unit_idx: int, mp: Vector2) -> void:
	_dragging = unit_idx
	var u: Dictionary = _units[unit_idx]
	var up: Vector2 = u["pos"]
	_drag_home = up
	_drag_off = up - mp
	# 手上的人抬高一层，压在别人上面，看得出"这在手上"
	var sp: Sprite2D = u["sprite"]
	if sp != null and is_instance_valid(sp):
		sp.z_index = 12
	_sync_unit(u)
	_update_drop_hint()


## 松手。三种结果：
##   落进布阵区        → 就站那儿
##   拖到布阵区**以西** → 收回候补池
##   其它越界          → 夹进布阵区最近的一点
##
## ⚠ 后两条都是被**实机日志**改出来的。日志里出现过两次：
##       [布阵] 拖动 → 区域外：放回原位
##   玩家是往左拖（多半想收回，或想站得更靠后），但没精确落进那个 32x40 的
##   小候补框里，就被判成"区域外"、把人弹回原位 —— 体感就是"拖不动"。
##   现在往西一律算收回（候补框就在西边，不必精确命中），其余越界一律夹进区里。
##   **核心原则：不会再出现"拖了等于没拖"。**
##
## 落点判定用**人当前所在的位置**（不是光标位置）—— 拖动时人跟着光标走、
## 但带一个抓取偏移 `_drag_off`，用光标判定会和玩家看到的落点差半个身位。
func _end_drag(_mp: Vector2) -> void:
	if _dragging < 0:
		return
	var u: Dictionary = _units[_dragging]
	var sp: Sprite2D = u["sprite"]
	if sp != null and is_instance_valid(sp):
		sp.z_index = 9
	var p: Vector2 = u["pos"]
	if p.x < _deploy_rect().position.x:
		_return_to_pool(_dragging)
	else:
		var dropped := _clamp_to_deploy(p)
		_move_unit(_dragging, dropped)
		# 打**夹回之后**的坐标：日志是排查用的，打原始值会让我看到 -900 这种数
		_note("拖动 → (%.0f, %.0f)　%s" % [dropped.x, dropped.y, _formation_text()])
	_dragging = -1
	_update_drop_hint()
	_emit_deploy()


## 自动布阵：**按兵种分前后**摆 —— 盾卫顶最前、弓手压最后、乡勇居中。
##
## 这不只是"一个不错的起点"，它同时是**兵种玩法的示范**：
## 弓手射程 52、盾卫只有 20，盾卫不站前面、弓手就没法安心输出。
## 玩家按一次就能看出"原来该这么摆"，然后可以推翻重摆。
func auto_deploy() -> void:
	if _phase != Phase.DEPLOY:
		return
	var r := _deploy_rect()
	# 两条线：近战（盾卫/乡勇/平民）在最前，弓手紧贴其后。
	#
	# ⚠ 间距**必须小于弓手射程**。第一版把弓手放在 64px 之后，
	#   而弓手射程只有 52 —— 结果弓手够不到正在和盾卫交手的敌人，只能挪过去，
	#   等它到位前排已经挨完打了。摆法对比探针实测：
	#       间距 64（旧）：自动布阵平均阵亡 **2.17** 人
	#       全员压前线    ：0.00 人
	#   也就是说那个"聪明的默认阵"是四组里最烂的一组。现在间距 20px，
	#   弓手能越过前排开火（射程 52 覆盖前排外扩 32px）。
	var lane_x := [r.position.x + r.size.x - 14.0,
		r.position.x + r.size.x - 34.0]
	# 兵种该站哪条线：0 = 近战线，1 = 弓手线
	var lane_of := {"shield": 0, "militia": 0, "levy": 0, "archer": 1}
	# 依次取人：近战先、弓手后。
	# （用 sort_custom + lambda 也能做，但为一张 4 行的表不值得冒 lambda 的类型风险。）
	var ordered: Array = []
	for want in ["shield", "militia", "levy", "archer"]:
		for t in _roster:
			if str(t) == want:
				ordered.append(want)
	var lane_used := [0, 0]
	for i in range(ordered.size()):
		var tid := str(ordered[i])
		var li: int = clampi(int(lane_of.get(tid, 0)), 0, lane_x.size() - 1)
		var slot := int(lane_used[li])
		lane_used[li] = slot + 1
		var y := r.position.y + 12.0 + float(slot) * 18.0
		y = clampf(y, r.position.y + 10.0, r.position.y + r.size.y - 10.0)
		# 从真实队列里摘掉这一个（不经过 _place_at，因为要指定兵种）
		var at := _roster.find(tid)
		if at < 0:
			continue
		_roster.remove_at(at)
		_pool = _roster.size()
		_units.append(_make_fighter(Vector2(float(lane_x[li]), y), tid))
	_note("自动布阵 → 上阵 %d，候补 %d　%s" % [_placed_count(), _pool, _formation_text()])
	_emit_deploy()


## 所有人回候补池，重新摆。
func clear_deploy() -> void:
	if _phase != Phase.DEPLOY:
		return
	for i in _placed_indices():
		_take_out(i)
	_note("全部收回 → 上阵 0，候补 %d" % _pool)
	_emit_deploy()


## 开战。至少要有一个人才打得起来 —— 一个人都不放等于弃守。
func begin_fight() -> bool:
	if _phase != Phase.DEPLOY:
		return false
	if _placed_count() <= 0:
		auto_deploy()
		if _placed_count() <= 0:
			return false
	_phase = Phase.FIGHT
	_step_t = 0.0
	_spawn_t = 0.0
	_formation_snapshot = _formation_text()
	# 兵种构成也要快照：结算时人和候补都可能已经变了，现算会说假话
	_roster_snapshot = _compose_summary(_placed_troops())
	_note("开战 → 上阵 %d 人（%s）vs 来犯 %d 人（阵型 %s）" % [
		_placed_count(), _roster_snapshot, _enemy_count, _formation_snapshot])
	# 敌军从东侧入场
	for i in range(_enemy_count):
		var y := ARENA_CENTER.y - 24.0 + float(i) * (48.0 / maxf(1.0, float(_enemy_count - 1)))
		var u := _make_enemy(Vector2(ARENA_CENTER.x + ENEMY_SPAWN_X, y))
		_units.append(u)
	emit_signal("phase_changed", _phase)
	return true


# ---------------------------------------------------------------------------
# 单位
# ---------------------------------------------------------------------------

func _make_fighter(pos: Vector2, troop_id := "militia") -> Dictionary:
	var c := _troop_cfg(troop_id)
	var tint := Color(1, 1, 1)
	var ta: Array = c.get("tint", [])
	if ta.size() >= 3:
		tint = Color(float(ta[0]), float(ta[1]), float(ta[2]))
	var u := _make_unit(pos, 0, "res://characters/villager_walk.png", 4, 7,
		tint, _num_from(c, "attack", _fighter_atk), _num_from(c, "hp", _fighter_hp))
	# 每单位自己的射程与速度：弓手射程 52、盾卫 20；这是"兵种"能成立的根本
	u["troop"] = troop_id
	u["range"] = _num_from(c, "range", DEF_ATTACK_RANGE)
	u["speed"] = _num_from(c, "speed", DEF_MOVE_PER_STEP)
	return u


## 马匪的配置（numbers.json 的 battle.raider）。
func _raider_cfg() -> Dictionary:
	if _game == null or _game.numbers == null:
		return {}
	var c = _game.numbers.get("battle", {}).get("raider", {})
	return c if c is Dictionary else {}


## 从字典里取一个数，缺了用兜底值。字典值可能是 Variant，
## 所以这里显式 float() —— 本项目禁止从 Variant 推断类型。
func _num_from(d: Dictionary, key: String, fallback: float) -> float:
	return float(d.get(key, fallback))


func _make_enemy(pos: Vector2) -> Dictionary:
	var u := _make_unit(pos, 1, "res://characters/raider_walk.png", 4, 4,
		Color(1, 1, 1), _raider_atk, _raider_hp, 1)
	u["troop"] = "raider"
	u["range"] = _num_from(_raider_cfg(), "range", DEF_ATTACK_RANGE)
	u["speed"] = _num_from(_raider_cfg(), "speed", DEF_MOVE_PER_STEP)
	# 入场用：从东侧 spawn_x 走进来，停在 hold_x。
	# ⚠ 这两个字段必须在建单位时写进字典 —— 第一版在 _process 里直接读，
	#   但 _make_enemy 从没设过它们，运行时取到 null 会静默算成 0，
	#   表现为"敌军一入场就瞬移到地图最西边"。
	u["_spawn_x"] = pos.x
	u["_hold_x"] = ARENA_CENTER.x + 46.0
	return u


func _make_unit(pos: Vector2, side: int, sheet: String, hf: int, vf: int,
		tint: Color, atk: float, hp: float, facing := 1) -> Dictionary:
	var sp := Sprite2D.new()
	sp.texture = load(sheet)
	sp.hframes = hf
	sp.vframes = vf
	sp.centered = true
	# 与 player.gd 一致：角色在 16x16 格里，脚底对齐碰撞原点
	sp.offset = Vector2(0, -4)
	sp.position = pos
	sp.z_index = 9
	sp.modulate = tint
	add_child(sp)

	# 血条：底 + 填充，各是一个缩放的 1x1 白块
	var bg := _rect(Vector2(14, 3), Color(0.10, 0.08, 0.06, 0.85))
	bg.position = pos + Vector2(0, -18)
	bg.z_index = 10
	add_child(bg)
	var bar := _rect(Vector2(12, 1), Color(0.45, 0.84, 0.45))
	bar.position = pos + Vector2(0, -18)
	bar.z_index = 11
	add_child(bar)

	var u := {
		"side": side, "hp": hp, "max_hp": hp, "atk": atk,
		"sprite": sp, "bar": bar, "bar_bg": bg,
		"pos": pos, "facing": facing, "walk_t": 0.0, "flash": 0.0, "alive": true,
	}
	_sync_unit(u)
	return u


func _sync_unit(u: Dictionary) -> void:
	var sp: Sprite2D = u["sprite"]
	if sp == null or not is_instance_valid(sp):
		return
	sp.position = u["pos"]
	var row := 1 if int(u["facing"]) == 1 else 2
	var col := int(u["walk_t"]) % 4
	sp.frame = row * sp.hframes + col
	var bg: Sprite2D = u["bar_bg"]
	var bar: Sprite2D = u["bar"]
	if bg != null and is_instance_valid(bg):
		bg.position = u["pos"] + Vector2(0, -18)
	if bar != null and is_instance_valid(bar):
		bar.position = u["pos"] + Vector2(0, -18)
		var ratio: float = clampf(float(u["hp"]) / maxf(0.01, float(u["max_hp"])), 0.0, 1.0)
		bar.scale = Vector2(12.0 * ratio, 1.0)
		# 血条左对齐：从左边缩短，而不是从中间缩
		bar.position += Vector2(-6.0 * (1.0 - ratio), 0)


func _rect(size: Vector2, col: Color) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = _white
	s.centered = true
	s.scale = size
	s.modulate = col
	return s


# ---------------------------------------------------------------------------
# 交手
# ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	# 攻击闪白衰减（放在 process 里，交战停顿时也能正常褪回）
	for u in _units:
		if u.is_empty():
			continue
		if float(u.get("flash", 0.0)) > 0.0:
			u["flash"] = maxf(0.0, float(u["flash"]) - delta * 4.0)
			var sp: Sprite2D = u["sprite"]
			if sp != null and is_instance_valid(sp):
				var a := float(u["flash"])
				sp.modulate = Color(1.0 + a, 0.7 + a * 0.3, 0.7, 1.0)

	if _phase != Phase.FIGHT:
		return

	# 入场：敌军先走完位，再开始交手（否则第一拍就贴脸，看不清谁是谁）
	if _spawn_t < _enemy_deploy_time:
		_spawn_t += delta
		var ease := clampf(_spawn_t / _enemy_deploy_time, 0.0, 1.0)
		for u in _units:
			if u.is_empty() or int(u["side"]) != 1:
				continue
			var fx: float = float(u["_spawn_x"])
			u["pos"] = Vector2(fx - (fx - float(u["_hold_x"])) * ease, float(u["pos"].y))
			u["walk_t"] = int(_spawn_t * 8.0)
			_sync_unit(u)
		return

	_step_t += delta
	if _step_t < _step_time:
		return
	_step_t = 0.0
	_do_step()


func _do_step() -> void:
	var living_f := _living(0)
	var living_e := _living(1)
	if living_f.is_empty() or living_e.is_empty():
		_finish()
		return

	for side in [0, 1]:
		var mine := _living(side)
		# ⚠ foes 必须在**每一次攻击后**重新取，而且取的必须是"另一方的存活者"。
		#   第一版写的是 `living_e if side == 0 else living_f` 再在循环里
		#   `foes = _living(1 - side)` —— 对 side=1 来说 `1-side=0` 是对的，
		#   但那两个初始变量是**步首的快照**，用快照就会出现"打已经倒下的人"。
		#   统一成步内实时查询，少一个出错的地方。
		for u in mine:
			if not bool(u["alive"]):
				continue
			var foes := _living(1 - side)
			if foes.is_empty():
				break
			var target: Dictionary = _nearest(u, foes)
			var d: float = float(u["pos"].distance_to(target["pos"]))
			# ⚠ 射程与速度**取每个单位自己的**，不再用统一的 _attack_range / _move_per_step ——
			#   弓手射程 52、盾卫 20，共用一套常量的话"兵种"就只剩血攻差异，
			#   而射程差正是弓手能站在盾卫身后输出的原因。
			var my_range: float = float(u.get("range", _attack_range))
			var my_speed: float = float(u.get("speed", _move_per_step))
			if d <= my_range:
				_attack(u, target)
			else:
				var dir: Vector2 = (target["pos"] - u["pos"]).normalized()
				u["facing"] = 1 if dir.x < 0.0 else 2
				u["pos"] = u["pos"] + dir * my_speed
				u["walk_t"] = int(u["walk_t"]) + 1
				_sync_unit(u)
	_sync_all()

	# ⚠ 步末**必须再判一次**：最后一名敌人是在这一拍中途倒下的，
	#   只靠步首那次检查的话，得等下一拍才结算 ——
	#   而这一拍之后已经没人可打，玩家看到的是"敌人全躺下了、战斗却还没结束"。
	#   （第一版就是这个毛病：phase 一直停在 2、战果是空的。）
	if _living(0).is_empty() or _living(1).is_empty():
		_finish()


func _attack(attacker: Dictionary, target: Dictionary) -> void:
	var dmg: float = float(attacker["atk"]) * randf_range(0.8, 1.25)
	target["hp"] = float(target["hp"]) - dmg
	attacker["flash"] = 1.0
	attacker["facing"] = 1 if float(target["pos"].x) < float(attacker["pos"].x) else 2
	if float(target["hp"]) <= 0.0:
		_kill(target)
	_sync_unit(target)


func _kill(u: Dictionary) -> void:
	u["alive"] = false
	u["hp"] = 0.0
	var sp: Sprite2D = u["sprite"]
	if sp != null and is_instance_valid(sp):
		# 倒阵：压扁 + 变暗，比直接消失更能读出"这个人倒下了"
		sp.modulate = Color(0.45, 0.38, 0.34, 0.75)
		sp.scale = Vector2(1.0, 0.5)
	for k in ["bar", "bar_bg"]:
		var n: Sprite2D = u[k]
		if n != null and is_instance_valid(n):
			n.visible = false


func _living(side: int) -> Array:
	var out: Array = []
	for u in _units:
		if u.is_empty():
			continue
		if int(u["side"]) == side and bool(u["alive"]):
			out.append(u)
	return out


func _nearest(u: Dictionary, list: Array) -> Dictionary:
	var best: Dictionary = list[0]
	var bd := INF
	for o in list:
		var d: float = float(u["pos"].distance_to(o["pos"]))
		if d < bd:
			bd = d
			best = o
	return best


func _sync_all() -> void:
	for u in _units:
		if not u.is_empty():
			_sync_unit(u)


# ---------------------------------------------------------------------------
# 结算
# ---------------------------------------------------------------------------

func _finish() -> void:
	_phase = Phase.RESULT
	var my_lost := 0
	for u in _units:
		if u.is_empty():
			continue
		if int(u["side"]) == 0 and not bool(u["alive"]):
			my_lost += 1
	var foes_left := _living(1).size()
	var win := foes_left == 0

	_result = {
		"win": win,
		"lost": my_lost,
		"enemies_left": foes_left,
		"enemies_total": _enemy_count,
	}
	# 战果打到 stdout。
	#
	# ⚠ 这一段是补出来的：原先胜负只写进 HUD 面板，**stdout 里什么都没有** ——
	#   于是"换个阵型打，结果有没有不同"这个问题，我在日志里根本看不到答案，
	#   而这正是玩家最想验证的事。现在每场都留一行：胜负 / 阵亡 / 残敌 / 当时的阵型。
	print("[战果] %s　我方 %s 阵亡 %d／%d　敌方残 %d／%d　阵型 %s" % [
		"胜" if win else "败", _roster_snapshot, my_lost, _placed_count() + my_lost,
		foes_left, _enemy_count, _formation_snapshot])
	# ── 结算落到数值层 ──
	if _game != null:
		var pop := int(_game.state["population"])
		# 阵亡：真的减人口（这是这场战斗最主要的代价）
		_game.state["population"] = maxi(1, pop - my_lost)
		_game.normalize_jobs()
		if win:
			# 守住：缴获 + 士气 + 治安
			var loot := _reward_num("loot_base", 6.0) \
				+ _reward_num("loot_per_enemy", 3.0) * float(_enemy_count)
			_game.state["resources"]["silver"] = \
				float(_game.state["resources"]["silver"]) + loot
			_game.state["stats"]["morale"] = minf(100.0,
				float(_game.state["stats"]["morale"]) + _reward_num("morale_win", 6.0))
			_game.state["stats"]["security"] = minf(60.0,
				float(_game.state["stats"]["security"]) + _reward_num("security_win", 8.0))
			_result["loot"] = loot
		else:
			# 失守：士气与治安大跌，抢走一部分存粮
			_game.state["stats"]["morale"] = maxf(0.0,
				float(_game.state["stats"]["morale"]) + _reward_num("morale_lose", -12.0))
			_game.state["stats"]["security"] = maxf(0.0,
				float(_game.state["stats"]["security"]) + _reward_num("security_lose", -15.0))
			var ratio := _reward_num("food_plunder_ratio", 0.3)
			var f: Dictionary = _game.state["resources"]["food"]
			var taken := 0.0
			for k in ["grain", "naan", "fruit", "meat", "milk"]:
				var have := float(f.get(k, 0.0))
				var t := floorf(have * ratio)
				f[k] = have - t
				taken += t
			_result["food_lost"] = taken
		_game.clamp_all()
		_game.state_changed.emit()
	emit_signal("ended", _result)
	emit_signal("phase_changed", _phase)


## 打扫战场，恢复常态（由 play.gd 在玩家点「结束」后调用）。
func finish() -> void:
	_clear()
	_phase = Phase.IDLE
	emit_signal("phase_changed", _phase)


func _clear() -> void:
	for u in _units:
		if u.is_empty():
			continue
		for k in ["sprite", "bar", "bar_bg"]:
			var n = u.get(k)
			if n != null and is_instance_valid(n):
				n.queue_free()
	_units.clear()
	if _floor != null and is_instance_valid(_floor):
		_floor.queue_free()
	_floor = null
	if _midline != null and is_instance_valid(_midline):
		_midline.queue_free()
	_midline = null
	if _deploy_zone != null and is_instance_valid(_deploy_zone):
		_deploy_zone.queue_free()
	_deploy_zone = null
	if _deploy_label != null and is_instance_valid(_deploy_label):
		_deploy_label.queue_free()
	_deploy_label = null
	if _pool_zone != null and is_instance_valid(_pool_zone):
		_pool_zone.queue_free()
	_pool_zone = null
	if _pool_label != null and is_instance_valid(_pool_label):
		_pool_label.queue_free()
	_pool_label = null
	_dragging = -1
	_formation_snapshot = ""
	_roster_snapshot = ""


# ---------------------------------------------------------------------------
# 布阵阶段的点击
# ---------------------------------------------------------------------------

## ── 布阵交互（自由站位）──
##
##   左键点布阵区里的空地  → 从候补池在那儿放一个人
##   左键点候补区          → 放一个人到布阵区西侧
##   左键**按住人拖动**    → 人跟着光标走；松手时
##                            落在布阵区内 → 就站那儿
##                            拖到候补框   → 收回候补池
##                            落到区外     → 放回原位（不惩罚）
##   右键点人              → 收回候补池（明确的"移除"手势）
##
## 手法的演变（三次，每次都是玩家实机反馈逼出来的）：
##   ① 只有"点空位放人 / 点已有人收回"，**没有拖动** → "我拖动不了人"
##   ② 加了 6 个固定槽位上的拖动 → "阵型是固定的，我不要固定的"
##   ③ 现在是**一片自由站位区**：散开 / 扎堆 / 一字排开 / 压上去，随便摆
func _unhandled_input(event: InputEvent) -> void:
	if _phase != Phase.DEPLOY:
		return

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		var mp := get_global_mouse_position()

		# 右键：把人收回候补池。一个明确的"移除"手势 ——
		# 左键不再承担删除职责（更早那版就是左键点谁删谁，玩家一点就掉人）。
		if mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT:
			var ri := _unit_at(mp)
			if ri >= 0:
				_take_out(ri)
				_emit_deploy()
				get_viewport().set_input_as_handled()
			return

		if mb.button_index != MOUSE_BUTTON_LEFT:
			return

		if mb.pressed:
			# 抓到人就拖；没抓到就当成"往这儿放一个人"
			var ui := _unit_at(mp)
			if ui >= 0:
				_begin_drag(ui, mp)
				get_viewport().set_input_as_handled()
				return
			if _deploy_rect().has_point(mp):
				_place_at(mp)
				get_viewport().set_input_as_handled()
				return
			if _pool_rect().has_point(mp):
				var dr := _deploy_rect()
				_place_at(Vector2(dr.position.x + 14.0, dr.position.y + 20.0))
				get_viewport().set_input_as_handled()
				return
		else:
			if _dragging >= 0:
				_end_drag(mp)
				get_viewport().set_input_as_handled()
				return

	if event is InputEventMouseMotion and _dragging >= 0:
		var u: Dictionary = _units[_dragging]
		u["pos"] = get_global_mouse_position() + _drag_off
		_sync_unit(u)
		# 落点反馈用的是**和松手判定同一套**的规则，否则提示说"会落这"、实际落别处
		_update_drop_hint()
		get_viewport().set_input_as_handled()
