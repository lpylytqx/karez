extends Node
## 战斗系统的边界用例测试（不是截图工具，是找 bug 用的）。
##
## 为什么值得单独写：截图只证明了"顺利打完一场"这一条路径。
## 真正会出问题的是**不顺利的那些**：人少、全灭、中途收场、连续触发、低人口。
## 每一节都是一个"如果这里有 bug，玩家会看到什么"的假设。
##
##   tools\Godot_v4.7.2-stable_win64.exe --path scripts res://tests/battle_edge.tscn

var _pass := 0
var _fail := 0
var _play: Node
var _gs: Node
var _battle: Node


func _ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  [PASS] %s" % label)
	else:
		_fail += 1
		print("  [FAIL] %s" % label)


func _section(t: String) -> void:
	print("")
	print("── %s ──" % t)


func _ready() -> void:
	print("=".repeat(64))
	print("  战斗系统边界用例")
	print("=".repeat(64))
	_play = load("res://scenes/play.tscn").instantiate()
	add_child(_play)
	_gs = _play.get_node("GameState")
	_battle = _play.get_node("Battle")

	await get_tree().process_frame
	await get_tree().process_frame

	await _t_small_force()
	await _t_zero_placed()
	await _t_double_start()
	await _t_close_mid_fight()
	await _t_double_finish()
	await _t_save_load_mid_battle()
	await _t_population_floor()
	await _t_config_from_data()
	await _t_only_assault_choice_starts_battle()
	await _t_deploy_interaction()
	await _t_troops()
	await _t_raid_scales()

	print("")
	print("=".repeat(64))
	if _fail == 0:
		print("  全部通过：%d 项" % _pass)
	else:
		print("  通过 %d 项，失败 %d 项" % [_pass, _fail])
	print("=".repeat(64))
	get_tree().quit(1 if _fail > 0 else 0)


## 等到战斗打完（或超时）。
##
## ⚠ 超时必须按**真实时间**算，不能按帧数。
##   第一版写的是"最多等 900 帧"，假设 60fps；但这台机器不锁帧（实测约 250fps），
##   900 帧只有 2~3 秒游戏时间，而 1 人对 6 人光走近就要 6 秒多 ——
##   于是测试报"卡在交战阶段"，其实战斗正常、只是没等够。
##   游戏逻辑全部走 delta（与帧率无关），所以这里也跟着用时间。
const FIGHT_MAX_SECONDS := 90.0


func _fight_until_done(_max_frames := 0) -> bool:
	var t0 := Time.get_ticks_msec()
	while (Time.get_ticks_msec() - t0) < int(FIGHT_MAX_SECONDS * 1000.0):
		if _battle.current_phase() == 3:      # RESULT
			return true
		if _battle.current_phase() == 0:      # IDLE（被收场了）
			return false
		await get_tree().process_frame
	return false


func _reset_pop(p: int, security := 30.0) -> void:
	_battle.finish()
	_gs.state["population"] = p
	_gs.state["stats"]["security"] = security
	_gs.state["resources"]["food"]["grain"] = 100.0
	_gs.state["resources"]["silver"] = 40.0
	_gs.normalize_jobs()


# ---------------------------------------------------------------------------

func _t_small_force() -> void:
	_section("以少打多：1 人对 6 人（应当会输，且代价落到数值上）")
	_reset_pop(2)
	_battle.start(_roster_of(1), 6)
	_ok(_battle.current_phase() == 1, "开局进入布阵阶段")
	_battle.auto_deploy()
	_ok(_battle._placed_count() == 1, "自动布阵放下了 1 人")
	_battle.begin_fight()
	var done := await _fight_until_done()
	_ok(done, "战斗能结束（不会卡在交战阶段）")
	# 阵型快照必须在**开战时**存，不能结算时现算 ——
	# 结算时人已经死光，现算会得到「未布阵」，日志就没法回答
	# "这一仗用什么阵打的"。
	_ok(_battle._formation_snapshot != "", "阵型快照已记录（%s）" % _battle._formation_snapshot)
	_ok(not _battle._formation_snapshot.contains("未布阵"),
		"阵型快照不是「未布阵」（说明它是开战时存的，不是结算时现算的）")
	var r: Dictionary = _battle._result
	_ok(not bool(r.get("win", true)), "1 打 6 判定为败（实际 %s）" % str(r.get("win")))
	_ok(float(r.get("food_lost", 0.0)) > 0.0, "战败被抢粮（%.0f 份）" % float(r.get("food_lost", 0.0)))
	_ok(int(_gs.state["population"]) >= 1, "人口不会被打成 0（实际 %d）" % int(_gs.state["population"]))


func _t_zero_placed() -> void:
	_section("一个人都不放就开战（等于弃守）")
	_reset_pop(4)
	_battle.start(_roster_of(3), 2)
	_ok(_battle._placed_count() == 0, "布阵阶段确实一个人也没放")
	var ok: bool = _battle.begin_fight()
	_ok(ok, "开战返回 true —— 应当自动补上人手，而不是拒绝开战")
	_ok(_battle._placed_count() > 0, "自动补了 %d 人" % _battle._placed_count())
	await _fight_until_done()


func _t_double_start() -> void:
	_section("连续触发两次来袭")
	_reset_pop(5)
	_battle.start(_roster_of(3), 2)
	var n1: int = _battle._enemy_count
	_battle.start(_roster_of(3), 5)          # 第二次应当被忽略
	_ok(_battle._enemy_count == n1, "第二次 start 被忽略（敌军数仍为 %d）" % _battle._enemy_count)
	_ok(_battle._units.size() <= 6, "单位数没有被翻倍（实际 %d）" % _battle._units.size())
	_battle.finish()


func _t_close_mid_fight() -> void:
	_section("交战中直接收场（finish）")
	_reset_pop(5)
	_battle.start(_roster_of(3), 4)
	_battle.auto_deploy()
	_battle.begin_fight()
	for i in range(20):
		await get_tree().process_frame
	_ok(_battle.current_phase() == 2, "确实在交战阶段")
	_battle.finish()
	_ok(_battle.current_phase() == 0, "收场后回到 IDLE")
	_ok(_battle._units.is_empty(), "单位列表已清空")
	# 等待几帧让 queue_free 生效，再数战场上还有没有残留的节点。
	# ⚠ 数**所有子节点**，不能只数 Sprite2D —— 战斗节点下的一切都是每场临时建的，
	#   收场后就该一个不剩。只数 Sprite2D 会漏掉 Label（区域标题/候补读数），
	#   而漏掉的那类正是退出时 Godot 报 "ObjectDB instances were leaked" 的来源。
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	var kids := _battle.get_child_count()
	_ok(kids == 0, "收场后战场上不该剩任何子节点（实际 %d 个）" % kids)
	if kids > 0:
		for c in _battle.get_children():
			print("      残留：%s (%s)" % [c.name, c.get_class()])


func _t_double_finish() -> void:
	_section("结算不会被算两次（人口不会被扣两遍）")
	_reset_pop(6)
	_battle.start(_roster_of(2), 6)
	_battle.auto_deploy()
	_battle.begin_fight()
	await _fight_until_done()
	var pop_after := int(_gs.state["population"])
	var silver_after := float(_gs.query("resources.silver"))
	# 再调一次 finish：不该再改任何数值
	_battle.finish()
	_ok(int(_gs.state["population"]) == pop_after, "人口没变（%d）" % pop_after)
	_ok(is_equal_approx(float(_gs.query("resources.silver")), silver_after),
		"银两没变（%.1f）" % silver_after)


func _t_save_load_mid_battle() -> void:
	_section("战斗中存档再读档（读档应当把战斗掐掉）")
	_reset_pop(5)
	_battle.start(_roster_of(3), 3)
	_battle.auto_deploy()
	_battle.begin_fight()
	for i in range(30):
		await get_tree().process_frame
	_ok(_battle._units.size() > 0, "交战中有 %d 个单位" % _battle._units.size())
	_ok(_battle.current_phase() == 2, "确实在交战阶段")

	# 走 play.gd 的真实读档入口（不是直接调 _gs.load_from），
	# 这样才测得到"读档时顺手把战斗掐掉"这段逻辑。
	var path := str(_play.SAVE_PATH)
	_gs.save_to(path)
	_play._on_load()
	await get_tree().process_frame
	await get_tree().process_frame
	_ok(_battle.current_phase() == 0, "读档后战斗被中止（阶段 = %d）" % _battle.current_phase())
	_ok(_battle._units.is_empty(), "读档后战场单位已清空（%d 个）" % _battle._units.size())
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _t_population_floor() -> void:
	_section("人口只剩 1 人时再来袭")
	_reset_pop(1)
	var fighters := clampi(1 - 1, 1, 6)
	_ok(fighters == 1, "能上阵人数被夹到 1（clampi 下限）")
	_battle.start(_roster_of(fighters), 4)
	_ok(_battle.current_phase() == 1, "仍然能打（不会因为没人而崩）")
	_battle.auto_deploy()
	_battle.begin_fight()
	await _fight_until_done()
	_ok(int(_gs.state["population"]) >= 1, "打完之后人口仍 >= 1（实际 %d）" % int(_gs.state["population"]))


func _t_config_from_data() -> void:
	_section("战斗数值来自 numbers.json 而不是硬编码")
	_reset_pop(4)
	var b: Dictionary = _gs.numbers.get("battle", {})
	_ok(not b.is_empty(), "numbers.json 里有 battle 段")
	var f: Dictionary = b.get("fighter", {})
	var r: Dictionary = b.get("raider", {})
	_ok(_battle._fighter_hp == float(f.get("hp", -1.0)),
		"村勇血量取自数据（%.1f）" % _battle._fighter_hp)
	_ok(_battle._fighter_atk == float(f.get("attack", -1.0)),
		"村勇攻击取自数据（%.1f）" % _battle._fighter_atk)
	_ok(_battle._raider_hp == float(r.get("hp", -1.0)),
		"马匪血量取自数据（%.1f）" % _battle._raider_hp)
	_ok(_battle._step_time == float(b.get("step_seconds", -1.0)),
		"每拍间隔取自数据（%.2fs）" % _battle._step_time)
	# 改数据之后重新 setup 应当生效 —— 这才证明它是"读数据"而不是"抄了个相同的常量"
	var hp_bak: float = float(f.get("hp", 3.0))
	f["hp"] = 9.0
	_battle.setup(_gs)
	_ok(_battle._fighter_hp == 9.0, "改数据后重新 setup 生效（血量 = %.1f）" % _battle._fighter_hp)
	f["hp"] = hp_bak
	_battle.setup(_gs)
	_ok(_battle._fighter_hp == hp_bak, "改回后恢复（血量 = %.1f）" % _battle._fighter_hp)


func _t_only_assault_choice_starts_battle() -> void:
	_section("只有「迎战」那个选项会开打")
	_reset_pop(5)
	var ev: Dictionary = _events_node().find_event("cri_raid_night")
	_ok(not ev.is_empty(), "找得到「火光从东边来」这条事件")
	var choices: Array = ev.get("choices", [])
	_ok(choices.size() >= 3, "它有 %d 个选项" % choices.size())
	_ok(bool(choices[0].get("battle", false)), "选项 0（迎战）带 battle 标记")
	_ok(not bool(choices[1].get("battle", true)), "选项 1（谈判）没有 battle 标记")
	_ok(not bool(choices[2].get("battle", true)), "选项 2（放弃外院）没有 battle 标记")

	# 选「谈判」：不该开战
	_battle.finish()
	_play._on_event_resolved("cri_raid_night", 1, "")
	for i in range(60):
		await get_tree().process_frame
	_ok(_battle.current_phase() == 0, "选「谈判」不会开战（阶段 = %d）" % _battle.current_phase())

	# 选「迎战」：应当开战（_on_event_resolved 里有 0.7s 延迟，所以要多等）
	_play._on_event_resolved("cri_raid_night", 0, "")
	var started := false
	for i in range(240):
		await get_tree().process_frame
		if _battle.current_phase() != 0:
			started = true
			break
	_ok(started, "选「迎战」会开战（阶段 = %d）" % _battle.current_phase())
	_battle.finish()


## 来袭人数必须**跟随能上阵的人数**。
##
## 为什么专门钉这一条：原来是 `2 + 天数/8`，第 1 天固定 2 人。
## 实测 5 打 2 连打三场都是"胜，0 阵亡" —— 兵种强不强、阵型摆得好不好
## **一点都看不出来**。人数差 2.5 倍时什么战术都归零，所以这个公式坏掉
## 等于把兵种和布阵两个系统一起废掉，必须有断言守着。
func _t_raid_scales() -> void:
	_section("来袭人数跟随我方人数（否则兵种/阵型都看不出来）")

	_reset_pop(6)
	_gs.state["jobs"] = {"water": 1, "gather_wood": 1, "gather_earth": 1,
		"craft": 0, "farm": 1, "guard": 2, "idle": 0}
	_gs.normalize_jobs()
	_battle.finish()
	_play._start_raid(false)
	var e_many: int = _battle._enemy_count
	var my: int = _battle._pool
	_ok(my == 5, "我方 5 人能上阵（实际 %d）" % my)
	_ok(e_many >= 4, "我方 5 人时来犯 >= 4（实际 %d）—— 不是写死的 2 人" % e_many)
	_battle.finish()

	# 人少时来犯也跟着少（说明是跟随，不是常量）
	_reset_pop(3)
	_gs.state["jobs"] = {"water": 1, "gather_wood": 0, "gather_earth": 0,
		"craft": 0, "farm": 1, "guard": 1, "idle": 0}
	_gs.normalize_jobs()
	_play._start_raid(false)
	var e_few: int = _battle._enemy_count
	var my_few: int = _battle._pool
	_ok(my_few == 2, "我方 2 人能上阵（实际 %d）" % my_few)
	_ok(e_few < e_many, "我方人少时来犯也少（%d < %d）—— 说明跟着人数走" % [e_few, e_many])
	_ok(e_few >= 2, "来犯不会少于下限 2（实际 %d）" % e_few)
	_battle.finish()
##
## 这一节要回答的是「兵种到底有没有用」：
##   · 岗位映射来自 numbers.json，不是硬编码在代码里
##   · 名单由分工推出，同一份分工结果一致（可复现）
##   · 盾卫血厚、弓手射程远 —— 数值真的分开读了，不是共用一套
##   · 自动布阵把弓手放在盾卫**后面**，这是「兵种 + 自由站位」能成立的关键
func _t_troops() -> void:
	_section("兵种：岗位决定、数值独立、自动布阵分前后")

	_ok(_gs.troop_of_job("guard") == "shield", "守卫 -> 盾卫")
	_ok(_gs.troop_of_job("gather_wood") == "archer", "采木 -> 弓手")
	_ok(_gs.troop_of_job("gather_earth") == "archer", "取土 -> 弓手")
	_ok(_gs.troop_of_job("farm") == "militia", "耕作 -> 乡勇")
	_ok(_gs.troop_of_job("idle") == "levy", "待命 -> 平民")

	_reset_pop(6)
	_gs.state["jobs"] = {"water": 1, "gather_wood": 1, "gather_earth": 1,
		"craft": 0, "farm": 1, "guard": 2, "idle": 0}
	_gs.normalize_jobs()
	var r1: Array = _gs.battle_roster(5)
	var r2: Array = _gs.battle_roster(5)
	_ok(r1.size() == 5, "留 1 人看家 -> 5 人能上阵（实际 %d）" % r1.size())
	_ok(r1 == r2, "同一份分工每次推出的名单一致（可复现）")
	_ok(r1.count("shield") == 2, "2 个守卫 -> 2 个盾卫（实际 %d）" % r1.count("shield"))
	_ok(r1.count("archer") == 2, "2 个采集 -> 2 个弓手（实际 %d）" % r1.count("archer"))

	# 数值必须各自独立：盾卫血厚、弓手射程远
	_battle.start(_roster_of(2, "shield") + _roster_of(2, "archer"), 2)
	_ok(_battle._pool == 4, "4 人候补（实际 %d）" % _battle._pool)
	_battle.auto_deploy()
	_ok(_battle._placed_count() == 4, "自动布阵把 4 人都放上去")
	var shield_u: Dictionary = {}
	var archer_u: Dictionary = {}
	for i in _battle._placed_indices():
		var u: Dictionary = _battle._units[i]
		var tid := str(u.get("troop", ""))
		if tid == "shield" and shield_u.is_empty():
			shield_u = u
		elif tid == "archer" and archer_u.is_empty():
			archer_u = u
	_ok(not shield_u.is_empty() and not archer_u.is_empty(), "盾卫与弓手都上场了")
	if not shield_u.is_empty() and not archer_u.is_empty():
		var sh: float = float(shield_u["hp"])
		var ah: float = float(archer_u["hp"])
		var sr: float = float(shield_u["range"])
		var ar2: float = float(archer_u["range"])
		var sx: float = float(shield_u["pos"].x)
		var ax: float = float(archer_u["pos"].x)
		_ok(sh > ah, "盾卫血比弓手厚（%.1f > %.1f）" % [sh, ah])
		_ok(ar2 > sr, "弓手射程比盾卫远（%.0f > %.0f）" % [ar2, sr])
		_ok(ax < sx, "自动布阵把弓手放在盾卫后面（弓 %.0f < 盾 %.0f）" % [ax, sx])
		# ⚠ 光"在后面"不够 —— 必须在**射程之内**。
		#   第一版间距 64px 而弓手射程 52，弓手够不到正在和盾卫交手的敌人，
		#   摆法对比探针实测那套默认阵平均阵亡 2.17 人（是全员压前线的几十倍）。
		_ok(sx - ax < ar2,
			"自动布阵的间距小于弓手射程（%.0f < %.0f）—— 否则弓手够不到敌人" % [sx - ax, ar2])
	_battle.finish()


## 造一份 N 人的兵种名单。老测试只关心人数、不关心兵种，所以默认全乡勇 ——
## 兵种本身的断言在 _t_troops 里单独做。
func _roster_of(n: int, troop := "militia") -> Array:
	var out: Array = []
	for i in range(maxi(0, n)):
		out.append(troop)
	return out


func _events_node() -> Node:
	return _play.get_node("EventSystem")


## 布阵交互（**自由站位**）：放人 / 拖动 / 拖回收 / 越界放回 / 摆形状 / 清空。
##
## 这一节被玩家实机反馈逼着重写过两次：
##   ① 「点击只能收回人，我无法放人，也拖不动人」→ 那时没有拖动
##   ② 「阵型是固定的，我不要固定的」→ 那时是 6 个固定槽位
## 现在是自由站位区，所以断言也改成"点哪儿站哪儿 / 能拖 / 能摆出不同形状"。
func _t_deploy_interaction() -> void:
	_section("布阵交互（自由站位）：放人 / 拖动 / 收回 / 越界 / 形状")
	_reset_pop(5)
	_battle.start(_roster_of(3), 2)
	_ok(_battle._pool == 3, "开局候补 3 人")
	_ok(_battle._placed_count() == 0, "开局 0 人上阵")

	var dr: Rect2 = _battle._deploy_rect()
	var pr: Rect2 = _battle._pool_rect()
	var p1: Vector2 = dr.position + Vector2(20, 20)
	var p3: Vector2 = dr.position + Vector2(84, 32)

	# 1. 在布阵区里点一下 → 放人；**站在我点的那一点**（不吸附格子）
	_ok(_battle._place_at(p1), "在布阵区点一下就能放人")
	_ok(_battle._placed_count() == 1 and _battle._pool == 2,
		"上阵 1、候补 2（实际 %d / %d）" % [_battle._placed_count(), _battle._pool])
	var u0: int = _battle._placed_indices()[0]
	var home: Vector2 = _battle._units[u0]["pos"]
	_ok(home.distance_to(p1) < 1.0, "人站在我点的那一点（自由站位，位置不被吸附到格点）")

	# 2. 抓得到人
	_ok(_battle._unit_at(home) == u0, "命中测试抓得到这个人")

	# 3. 拖到区内别处 → 就站那儿
	_battle._begin_drag(u0, home)
	_ok(_battle._dragging == u0, "进入拖动状态")
	_battle._units[u0]["pos"] = p3
	_battle._end_drag(p3)
	_ok(Vector2(_battle._units[u0]["pos"]).distance_to(p3) < 1.0, "松手落在区内 → 就站那儿")
	_ok(_battle._placed_count() == 1, "拖动不改变上阵人数")

	# 4. 拖到候补框 → 收回
	_battle._begin_drag(u0, p3)
	_battle._units[u0]["pos"] = pr.position + pr.size * 0.5
	_battle._end_drag(pr.position)
	_ok(_battle._pool == 3, "拖到候补框 → 收回（候补回到 %d）" % _battle._pool)
	_ok(_battle._placed_count() == 0, "上阵回到 0 人")

	# 5. 往北/南拖出区（x 仍在区内）→ **夹回区内最近处**，不丢人、也不"等于没拖"
	_battle._place_at(p1)
	var u1: int = _battle._placed_indices()[0]
	var home1: Vector2 = _battle._units[u1]["pos"]
	_battle._begin_drag(u1, home1)
	_battle._units[u1]["pos"] = Vector2(home1.x, -900)      # 飞出北边
	_battle._end_drag(Vector2(-900, -900))
	var landed: Vector2 = _battle._units[u1]["pos"]
	_ok(_battle._placed_count() == 1, "越界拖动不会把人弄丢")
	_ok(dr.has_point(landed), "越界落点被夹回布阵区内（%.0f, %.0f）" % [landed.x, landed.y])
	_ok(absf(landed.y - (dr.position.y + 8.0)) < 1.5, "夹到了最近的那条边（北边）")

	# 6. 往**西**拖出区 → 收回候补池。
	#    这条规则是被实机日志改出来的：日志里两次「拖动 → 区域外：放回原位」，
	#    玩家是想收回或想站得更靠后，但没精确落进那个 32x40 的小候补框，
	#    结果"人弹回去"，体感就是拖不动。现在往西一律算收回。
	var p5: int = _battle._pool
	var west := Vector2(dr.position.x - 40.0, landed.y)
	_battle._begin_drag(u1, landed)
	_battle._units[u1]["pos"] = west
	_battle._end_drag(west)
	_ok(_battle._pool == p5 + 1,
		"往西拖出区 → 收回（候补 %d → %d）" % [p5, _battle._pool])
	_ok(_battle._placed_count() == 0, "上阵回到 0 人")

	# 7. 右键 = 收回
	_battle._place_at(p1)
	var u2: int = _battle._placed_indices()[0]
	var p4: int = _battle._pool
	_battle._take_out(u2)
	_ok(_battle._pool == p4 + 1, "收回一个人 → 候补 +1")
	_ok(_battle._placed_count() == 0, "上阵 0 人")

	# 7. **自由站位真的能摆出不同形状**（这是这一轮改动的核心目的）
	_battle.clear_deploy()
	_battle._place_at(dr.position + Vector2(12, 12))
	_battle._place_at(dr.position + Vector2(12, 66))
	var vertical: String = _battle._formation_text()
	_battle.clear_deploy()
	_battle._place_at(dr.position + Vector2(12, 12))
	_battle._place_at(dr.position + Vector2(96, 12))
	var horizontal: String = _battle._formation_text()
	print("    纵排 = %s" % vertical)
	print("    横排 = %s" % horizontal)
	_ok(vertical != horizontal,
		"同样两个人，纵排与横排的阵型描述不同（形状真的能变）")

	# 8. 自动布阵给一个起点；清空能全收回
	_battle.clear_deploy()
	_battle.auto_deploy()
	_ok(_battle._placed_count() == 3, "自动布阵把 3 个人都放上去（实际 %d）" % _battle._placed_count())
	_ok(_battle._pool == 0, "候补清零")
	_battle.clear_deploy()
	_ok(_battle._placed_count() == 0 and _battle._pool == 3, "全部收回 → 0 上阵 / 3 候补")
	_ok(_battle._pool_label.text.contains("3"), "候补区读数跟着更新（%s）" % _battle._pool_label.text)
	_battle.finish()
