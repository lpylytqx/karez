extends Node
## 核心逻辑无头测试：数值加载、路径取值、挖井流程、事件 DSL、存档回环。
## 运行：
##   tools\Godot_v4.7.2-stable_win64.exe --headless --path scripts res://tests/logic_test.tscn
## 退出码 0 表示全通过，1 表示有失败。

var _pass := 0
var _fail := 0
var _game: Node
var _events: Node


func _ready() -> void:
	print("=".repeat(64))
	print("  《坎儿井》核心逻辑测试")
	print("=".repeat(64))

	_game = load("res://core/game_state.gd").new()
	_game.name = "GameState"
	add_child(_game)
	_events = load("res://core/event_system.gd").new()
	_events.name = "EventSystem"
	add_child(_events)
	_events.setup(_game)

	_test_numbers()
	_test_paths()
	_test_flags()
	_test_dig_flow()
	_test_event_dsl()
	_test_event_select()
	_test_event_resolve()
	_test_memory()
	_test_s3_loop()
	_test_move_site()
	_test_npc_sprite_follows()
	_test_building_visibility()
	_test_facilities()
	_test_save_roundtrip()

	print("=".repeat(64))
	if _fail == 0:
		print("  全部通过：%d 项" % _pass)
	else:
		print("  通过 %d 项，失败 %d 项" % [_pass, _fail])
	print("=".repeat(64))
	get_tree().quit(1 if _fail > 0 else 0)


# ---------------------------------------------------------------------------

func _ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  [PASS] %s" % label)
	else:
		_fail += 1
		print("  [FAIL] %s" % label)


func _eq(a, b, label: String) -> void:
	if a == b:
		_pass += 1
		print("  [PASS] %s  (= %s)" % [label, str(a)])
	else:
		_fail += 1
		print("  [FAIL] %s  期望 %s，实际 %s" % [label, str(b), str(a)])


func _section(t: String) -> void:
	print("")
	print("── %s ──" % t)


# ---------------------------------------------------------------------------

func _test_numbers() -> void:
	_section("数值表加载")
	_ok(_game.numbers is Dictionary and not _game.numbers.is_empty(), "numbers.json 已加载")
	_ok(_game.numbers.has("karez"), "含 karez 段")
	_eq(int(_game.numbers.get("karez", {}).get("max_sections", 0)), 6, "max_sections")
	_eq(int(_game.numbers.get("calendar", {}).get("days_per_season", 0)), 30, "days_per_season")
	_eq(int(_game.numbers.get("buildings", {}).get("list", []).size()) > 0, true, "建筑表非空")


func _test_paths() -> void:
	_section("通用路径取值 get_path")
	_eq(_game.query("day"), 1, "day")
	_eq(_game.query("season"), "spring", "season")
	_eq(_game.query("phase"), "morning", "phase")
	_eq(int(_game.query("population")), 6, "population")
	_eq(float(_game.query("resources.water.current")), 90.0, "resources.water.current")
	_eq(float(_game.query("resources.water.flow_per_day")), 5.0, "flow_per_day 映射到 karez")
	_eq(int(_game.query("karez.sections")), 0, "karez.sections")
	_eq(float(_game.query("stats.morale")), 55.0, "stats.morale")
	_eq(_game.query("flags.view_flag"), false, "未设置的 flag 返回 false")
	_eq(_game.query("buildings.yiguan"), false, "未建的建筑返回 false")
	_eq(_game.query("不存在的路径"), null, "未知路径返回 null")
	_eq(float(_game.query("characters.lao_kanjiang.mood")), 60.0, "角色 mood")


func _test_flags() -> void:
	_section("旗标")
	_game.set_flag("test_flag", true)
	_eq(_game.query("flags.test_flag"), true, "设置后可读到 true")
	_game.set_flag("test_flag", false)
	_eq(_game.query("flags.test_flag"), false, "可改回 false")


func _test_dig_flow() -> void:
	_section("挖井流程")
	_eq(_game.oasis_level(), 0, "初始绿洲等级 0")

	# 工期速度取决于治水人数：基准 3 人 = 每天推进 1 天，才与 numbers.json 的 days 对得上。
	# 默认分配是 2 人治水（为了留出耕作的人手），这里显式补到 3 人做确定性验证。
	_game.assign_job("farm", -1)
	_game.assign_job("water", 1)
	_eq(_game.job_count("water"), 3, "治水补到 3 人（基准速度）")

	var info: Dictionary = _game.dig_info()
	_ok(bool(info["ok"]), "开局可挖第一段（木30≥12 土50≥25 工具4≥0）")
	_eq(int(info["index"]), 1, "目标段 = 1")
	_eq(int(info["days"]), 2, "工期 2 天")

	var wood0 := float(_game.query("resources.materials.wood"))
	var earth0 := float(_game.query("resources.materials.earth"))
	var r: Dictionary = _game.start_dig()
	_ok(bool(r["ok"]), "start_dig 成功")
	_eq(float(_game.query("resources.materials.wood")), wood0 - 12.0, "木料扣除 12")
	_eq(float(_game.query("resources.materials.earth")), earth0 - 25.0, "土料扣除 25")
	_eq(_game.construction_idle(), false, "进入施工状态")
	_eq(int(_game.query("construction.days_left")), 2, "剩余 2 天")

	# 施工中不允许再挖
	_ok(not bool(_game.dig_info()["ok"]), "施工期间不可再挖")
	# 理由文案要短：这段文字要塞进 HUD 右侧 96px 宽的标签，超过两行会压住按钮
	var reason := str(_game.dig_info()["reason"])
	_eq(reason.contains("施工中"), true, "拒绝理由指出正在施工（%s）" % reason)
	_ok(reason.length() <= 10, "理由足够短（%d 字）" % reason.length())

	# 推进两天
	var m1: String = _game.advance_day()
	_eq(m1, "", "第 1 天无完工")
	_eq(int(_game.query("karez.sections")), 0, "段数仍为 0")
	var m2: String = _game.advance_day()
	_ok(m2.contains("完工"), "第 2 天完工，提示：%s" % m2)
	_eq(int(_game.query("karez.sections")), 1, "段数变为 1")
	_eq(_game.query("flags.karez_section_1_done"), true, "旗标 karez_section_1_done 置位")
	_eq(_game.query("flags.karez_first_section_done"), true, "旗标 karez_first_section_done 置位")
	_eq(_game.construction_idle(), true, "回到空闲")
	_eq(_game.oasis_level(), 1, "绿洲等级升到 1")

	# 出水应随段数上升
	var flow := float(_game.query("resources.water.flow_per_day"))
	_ok(flow > 5.0, "日出水量上升（%.1f 方/天）" % flow)

	# 行动点
	_section("行动点")
	var ap: int = _game.action_points()
	_ok(ap >= 0, "行动点可读（当前 %d）" % ap)


func _test_event_dsl() -> void:
	_section("事件条件 DSL")
	_eq(_events.check_conditions([]), true, "空条件视为满足")
	_eq(_events.check_conditions([{"op": "eq", "path": "karez.sections", "value": 0}]), false,
		"sections 现为 1，不等于 0 → 不满足")
	_eq(_events.check_conditions([{"op": "gte", "path": "karez.sections", "value": 1}]), true, "gte 满足")
	_eq(_events.check_conditions([{"op": "lte", "path": "karez.sections", "value": 0}]), false, "lte 不满足")
	_eq(_events.check_conditions([{"op": "is", "path": "season", "value": "spring"}]), true, "is 枚举相等")
	_eq(_events.check_conditions([{"op": "is", "path": "season", "value": "winter"}]), false, "is 枚举不等")
	_eq(_events.check_conditions([{"op": "has", "path": "flags.karez_section_1_done"}]), true, "has 已置位的旗标")
	_eq(_events.check_conditions([{"op": "has", "path": "flags.不存在"}]), false, "has 未置位的旗标")
	_eq(_events.check_conditions([{"op": "not_has", "path": "flags.不存在"}]), true, "not_has 未置位")
	_eq(_events.check_conditions([{"op": "neq", "path": "karez.sections", "value": 0}]), true, "neq 满足")
	# AND 语义
	_eq(_events.check_conditions([
		{"op": "gte", "path": "karez.sections", "value": 1},
		{"op": "is", "path": "season", "value": "spring"},
	]), true, "多条件 AND 全满足")
	_eq(_events.check_conditions([
		{"op": "gte", "path": "karez.sections", "value": 1},
		{"op": "is", "path": "season", "value": "winter"},
	]), false, "多条件 AND 有一个不满足")


func _test_event_select() -> void:
	_section("事件抽取")
	var d: Dictionary = _events.diagnostics()
	_eq(int(d["total"]), 64, "事件库 64 条")
	_ok(int(d["eligible_now"]) > 0, "当前有 %d 条可触发" % int(d["eligible_now"]))
	print("      类别分布：%s" % str(d["by_category"]))

	# 抽 20 次，全部必须是可触发集合内的
	var ids := {}
	for i in range(20):
		var e: Dictionary = _events.pick_event()
		if not e.is_empty():
			ids[str(e.get("id", ""))] = true
	_ok(ids.size() > 0, "20 次抽取命中 %d 个不同事件" % ids.size())

	# 类别过滤
	var manage: Dictionary = _events.pick_event("manage")
	if not manage.is_empty():
		_eq(str(manage.get("category", "")), "manage", "按类别过滤生效")
	else:
		_ok(true, "当前无 manage 类可触发（跳过）")

	# 触发计数与 max_per_game
	var e1: Dictionary = _events.pick_event()
	if not e1.is_empty():
		var id := str(e1.get("id", ""))
		var before: int = _events.eligible_events().size()
		_events.trigger(e1)
		var after: int = _events.eligible_events().size()
		_ok(after <= before, "触发后可选事件数不增（%d → %d）" % [before, after])
		var maxpg = e1.get("max_per_game", null)
		if maxpg != null and int(maxpg) <= 1:
			var still: Array = _events.eligible_events().filter(func(x): return str(x.get("id", "")) == id)
			_eq(still.size(), 0, "max_per_game=1 的事件触发后不再可选")
	else:
		_ok(false, "应当能抽到事件")


func _test_event_resolve() -> void:
	_section("事件结算与效果应用")

	# 直接构造一条效果齐全的事件，绕开抽取的不确定性
	var ev := {
		"id": "test_effect_event",
		"category": "manage",
		"title": "测试",
		"choices": [{
			"text": "测试选项",
			"effects": [
				{"op": "add", "path": "stats.morale", "value": 3},
				{"op": "sub", "path": "resources.silver", "value": 5},
				{"op": "set", "path": "flags.test_event_flag", "value": true},
				{"op": "set", "path": "buildings.yiguan", "value": true},
				{"memory": {"character": "lao_kanjiang", "text": "测试记忆条目"}},
			],
			"outcome": "测试结果文本",
		}],
	}

	var morale0 := float(_game.query("stats.morale"))
	var silver0 := float(_game.query("resources.silver"))
	var mem0: Array = _game.get_memory("lao_kanjiang")

	var res: Dictionary = _events.resolve(ev, 0)
	_ok(bool(res["ok"]), "resolve 成功")
	_eq(int(res["applied"]), 5, "5 条效果全部生效")
	_eq(int(res["dropped"]), 0, "无丢弃")
	_eq(float(_game.query("stats.morale")), morale0 + 3.0, "士气 +3")
	_eq(float(_game.query("resources.silver")), silver0 - 5.0, "银 -5")
	_eq(_game.query("flags.test_event_flag"), true, "flags 布尔赋值生效")
	_eq(_game.query("buildings.yiguan"), true, "buildings 布尔赋值生效")
	_eq(_game.get_memory("lao_kanjiang").size(), mem0.size() + 1, "记忆追加 1 条")
	_eq(str(res["outcome"]), "测试结果文本", "outcome 透传")

	# 越界路径必须被丢弃
	var bad := {"id": "bad", "choices": [{"effects": [
		{"op": "set", "path": "内部机密.密码", "value": 1},
		{"op": "set", "path": "stats.morale", "value": 9999},   # 会被夹到 MAX_DELTA
	]}]}
	var r2: Dictionary = _events.resolve(bad, 0)
	_eq(int(r2["dropped"]), 1, "越界路径被丢弃")
	_eq(int(r2["applied"]), 1, "合法路径仍生效")

	# 选项越界
	var r3: Dictionary = _events.resolve(ev, 99)
	_eq(bool(r3["ok"]), false, "选项越界被拒绝")

	# 存档接口
	var st: Dictionary = _events.export_state()
	_ok(st.has("fire_count") and st.has("resolved"), "export_state 结构正确")
	_events.reset()
	_eq(_events.export_state()["fire_count"].size(), 0, "reset 清空计数")
	_events.import_state(st)
	_ok(_events.export_state()["fire_count"].size() > 0, "import_state 恢复计数")


func _test_memory() -> void:
	_section("记忆系统：重要度与承诺召回")
	# 用一个前面测试没碰过的角色，避免相互干扰
	var cid := "chuniang"

	# 关键词兜底：AI 的 memory_append 按 output_contract 是纯字符串，没有 kind 字段
	_game.add_memory(cid, "你答应过要给她带一匹喀什的绸子")
	var mem: Array = _game.get_memory(cid)
	_eq(mem.size(), 1, "写入 1 条记忆")
	_ok(str(mem[0]).contains("【承诺】"), "关键词「答应」被识别为承诺并打上标签")

	# 显式 kind 优先于关键词推断。
	# 注意这里不能断言它排在 [0] —— 承诺 imp3 会排在秘密 imp2 前面，排序是对的。
	_game.add_memory(cid, "她提过老家的杏花开在三月", "secret")
	var has_secret := false
	for m in _game.get_memory(cid):
		if str(m).contains("【秘密】"):
			has_secret = true
	_ok(has_secret, "显式 kind=secret 生效（打上【秘密】标签）")

	# 排序：承诺(imp3) 必须排在 秘密(imp2) 与普通(imp1) 之前
	_game.add_memory(cid, "今天天气不错")
	_game.add_memory(cid, "又聊了两句闲话")
	var ordered: Array = _game.get_memory(cid)
	_ok(str(ordered[0]).contains("【承诺】"), "承诺排第 1 位（重要度优先）")
	_ok(str(ordered[1]).contains("【秘密】"), "秘密排第 2 位")

	# 只取承诺
	var pr: Array = _game.get_promises(cid)
	_eq(pr.size(), 1, "get_promises 只返回承诺类")
	_ok(str(pr[0]).contains("绸子"), "承诺内容正确")
	_ok(not str(pr[0]).contains("天气"), "闲聊不在承诺列表里")

	# 淘汰策略：灌 210 条闲聊，承诺必须活下来
	for i in range(210):
		_game.add_memory(cid, "闲聊 %d" % i)
	var after: Array = _game.get_memory(cid)
	_ok(str(after[0]).contains("【承诺】"), "灌入 210 条闲聊后，承诺仍排在最前")
	_eq(int(_game.state["characters"][cid]["memory"].size()), 200, "记忆条数被压到上限 200")
	_eq(_game.get_promises(cid).size(), 1, "承诺未被淘汰")

	# 兜底：AI 漏记承诺时由本地补记。
	# 实测 deepseek-flash 的 memory_append 时有时无，而「记住承诺」是核心卖点。
	var cid2 := "shenmi_lvren"
	_game._pending_speaker = cid2
	_game._pending_input = "我保证三天之内把货送到你手上"
	_game.apply_response({"narration": "……", "memory_append": []})
	_eq(_game.get_promises(cid2).size(), 1, "AI 漏记承诺时，本地兜底补记")

	_game.apply_response({"narration": "……", "memory_append": []})
	_eq(_game.get_promises(cid2).size(), 1, "重复触发不产生重复记忆")

	var cid3 := "hasake_qishou"
	_game._pending_speaker = cid3
	_game._pending_input = "今天风挺大"
	_game.apply_response({"narration": "……", "memory_append": []})
	_eq(_game.get_memory(cid3).size(), 0, "非承诺内容不触发兜底")

	# AI 自己记了就不该再兜底
	var cid4 := "muqam_yiren"
	_game._pending_speaker = cid4
	_game._pending_input = "我答应下次带你去喀什"
	_game.apply_response({"narration": "……", "memory_append": ["玩家答应带艺人去喀什"]})
	_eq(_game.get_memory(cid4).size(), 1, "AI 已记账时不重复兜底")

	# 旧存档兼容：纯字符串条目要能读（存档格式变更是单机项目最容易翻车的地方）
	_game.state["characters"][cid]["memory"] = ["这是旧格式的字符串记忆"]
	var legacy: Array = _game.get_memory(cid)
	_eq(legacy.size(), 1, "旧格式字符串条目可读")
	_ok(str(legacy[0]).contains("旧格式"), "旧格式内容正确")


func _test_s3_loop() -> void:
	_section("S3 经营骨架：岗位分配与资源循环")

	var g: Node = load("res://core/game_state.gd").new()
	add_child(g)

	_eq(g.job_count("water"), 2, "开局 2 人治水（留 2 人耕作，否则养不活 6 口人）")
	_eq(g.total_assigned(), 6, "6 人全部分配")
	_eq(g.unassigned(), 0, "没有闲置人口")
	_eq(g.assign_job("gather_wood", 1), false, "人手全占满时不能再加岗位")
	_eq(g.assign_job("water", -1), true, "可以先从治水撤 1 人")
	_eq(g.unassigned(), 1, "撤下 1 人后出现闲置")
	_eq(g.assign_job("gather_wood", 1), true, "把闲置的人派去采木")
	_eq(g.unassigned(), 0, "再次满员")
	_eq(g.job_count("gather_wood"), 2, "采木变为 2 人")

	# 农田：田块数随坎儿井段数增长（核心正循环）
	_eq(g.farmland_plots(), 0, "0 段竖井 -> 0 块田")
	_ok(g.food_per_plot() > 1.0, "每块田每天产粮 %.2f" % g.food_per_plot())

	# 采集产出真的入账
	var bw := float(g.query("resources.materials.wood"))
	var be := float(g.query("resources.materials.earth"))
	g.advance_day()
	_ok(float(g.query("resources.materials.wood")) > bw, "采木岗位让木料增加")
	_ok(float(g.query("resources.materials.earth")) > be, "取土岗位让土料增加")

	# 治水人数为 0 时工程完全停工 —— 这是岗位分配的意义
	var g2: Node = load("res://core/game_state.gd").new()
	add_child(g2)
	while g2.job_count("water") > 0:
		g2.assign_job("water", -1)
	g2.start_dig()
	var dl0 := int(g2.query("construction.days_left"))
	for i in range(5):
		g2.advance_day()
	_eq(int(g2.query("construction.days_left")), dl0, "无人治水时工期完全不推进（%d 天）" % dl0)

	# ── 自动模拟：用「朴素分配」打 60 天，看能不能活下来并挖通几段 ──
	#
	# ⚠ 必须先固定随机种子。模拟里会掷人口增长（_roll_population 用 randf），
	# 不固定的话每次跑出来的段数都不一样 —— 这个断言一度时过时不过，
	# 变成一条「看运气」的测试。不稳定的测试比没有测试更糟：
	# 它让人分不清「这轮改动搞坏了」和「这轮运气不好」。
	seed(20261005)

	var s: Node = load("res://core/game_state.gd").new()
	add_child(s)
	var dead_day := -1
	for day in range(1, 61):
		var pop := int(s.query("population"))
		var plots: int = s.farmland_plots()
		# 朴素但合理的策略：
		#   1. 先按「够吃」定农夫数（一名农夫管 4 块田）
		#   2. 留 2 人治水保证工程推进
		#   3. 缺工具就派 1 人做工
		#   4. 余下的人平分去采木取土
		var per_farmer := 4
		var eat := 3.0
		var need_food := float(pop) * eat
		var per_plot: float = s.food_per_plot()
		var farmers := int(ceil(need_food / (per_plot * float(per_farmer))))
		farmers = clampi(farmers, 0, maxi(0, int(ceil(float(plots) / float(per_farmer)))))
		var tools_now := float(s.query("resources.materials.tools"))
		var crafters := 1 if tools_now < 8.0 else 0
		var water := mini(2, pop)

		var rest := maxi(0, pop - farmers - crafters - water)
		var woodg := int(ceil(float(rest) / 2.0))
		var earthg := rest - woodg

		var want := {
			"water": water, "farm": farmers, "craft": crafters,
			"gather_wood": woodg, "gather_earth": earthg,
		}
		# 人类不够时按重要性往回削：先砍采木，再砍做工，再砍耕作，最后保治水
		var need := 0
		for k in want:
			need += int(want[k])
		for j in ["gather_wood", "gather_earth", "craft", "farm"]:
			while need > pop and int(want[j]) > 0:
				want[j] = int(want[j]) - 1
				need -= 1
		while need > pop and int(want["water"]) > 1:
			want["water"] = int(want["water"]) - 1
			need -= 1

		for j in ["water", "gather_wood", "gather_earth", "craft", "farm", "guard", "idle"]:
			var cur: int = s.job_count(j)
			var tgt := int(want.get(j, 0))
			if tgt > cur:
				s.assign_job(j, tgt - cur)
			elif tgt < cur:
				s.assign_job(j, tgt - cur)

		if s.construction_idle() and bool(s.dig_info()["ok"]):
			s.start_dig()
		s.advance_day()

		var food := float(s.query("resources.food.grain")) \
			+ float(s.query("resources.food.naan")) \
			+ float(s.query("resources.food.meat"))
		if day == 1 or day % 10 == 0:
			print("    第%2d天  段%d  水%3.0f  粮%3.0f  木%3.0f  土%3.0f  具%2.0f  人%d" % [
				day, int(s.query("karez.sections")), float(s.query("resources.water.current")),
				food, float(s.query("resources.materials.wood")),
				float(s.query("resources.materials.earth")), tools_now, pop])
		if int(s.query("population")) <= 0:
			dead_day = day
			break

	_eq(dead_day, -1, "60 天内没有团灭")
	_ok(int(s.query("karez.sections")) >= 3,
		"自动模拟能挖通至少 3 段竖井（实际 %d 段）" % int(s.query("karez.sections")))


func _test_move_site() -> void:
	_section("移动建筑：坐标进 state，NPC 与工作地点自动跟随")

	var g: Node = load("res://core/game_state.gd").new()
	add_child(g)

	# 默认坐标来自 sites.gd
	_eq(g.site_xy("inn"), Vector2(26, 15), "驿馆默认在 (26,15)")
	_ok(g.npc_xy("hanshang_zhanggui") != Vector2.ZERO, "掌柜有默认站位")

	# 可移动 / 不可移动
	_eq(g.move_site("inn", Vector2(10, 8)), true, "驿馆可移动")
	_eq(g.move_site("reservoir", Vector2(10, 8)), false, "涝坝不可移动（fixed）")
	_eq(g.move_site("shaft_chain", Vector2(10, 8)), false, "竖井链不可移动（area）")

	# 移动后坐标真的变了
	_eq(g.site_xy("inn"), Vector2(10, 8), "驿馆移到 (10,8)")

	# ⭐ 核心：NPC 跟着走
	var zhang_before: Vector2 = g.npc_xy("hanshang_zhanggui")
	_eq(zhang_before, Vector2(10, 8) + Sites.NPC_OFFSET["hanshang_zhanggui"],
		"掌柜跟着驿馆走到了新位置")
	_ok(zhang_before.x < 20.0, "新位置确实在左半边（%.1f）" % zhang_before.x)

	# 越界会被夹住
	g.move_site("inn", Vector2(-50, 999))
	var clamped: Vector2 = g.site_xy("inn")
	_ok(clamped.x >= 1.0 and clamped.x <= 38.0, "x 被夹在 1~38（%.1f）" % clamped.x)
	_ok(clamped.y <= 17.0, "y 被夹在 17 以内（%.1f）—— 再往下会被底栏吃掉" % clamped.y)

	# 存档回环：移过的位置要能存下来
	var s: Node = load("res://core/game_state.gd").new()
	add_child(s)
	s.move_site("inn", Vector2(14, 9))
	_eq(s.save_to("user://_test_sites.json"), true, "存档成功")
	s.move_site("inn", Vector2(30, 15))
	_eq(s.load_from("user://_test_sites.json"), true, "读档成功")
	_eq(s.site_xy("inn"), Vector2(14, 9), "移过的驿馆坐标被还原")


## ⭐ 这条测的是「精灵真的被搬走了」，不是「坐标重算了一遍」。
##
## 上一版只测了 g.npc_xy()，而那是每次调用现算的，当然对；
## 结果 townfolk 写了 resync_positions() 却没接到 state_changed 上，
## 实机表现就是「建筑动了、居民动了，只有 NPC 钉在原地」——
## 用户发现的。测试盲区在这里，所以补上这条。
func _test_npc_sprite_follows() -> void:
	_section("拖动建筑后：NPC 精灵真的会重摆")

	var g: Node = load("res://core/game_state.gd").new()
	add_child(g)
	# 掌柜需要坎儿井 >= 2 段才在场（角色按需出现），先推进到那时
	_eq(g.character_present("hanshang_zhanggui"), false, "0 段时掌柜还不在场")
	g.state["karez"]["sections"] = 2
	_eq(g.character_present("hanshang_zhanggui"), true, "2 段后掌柜出现")

	var tf: Node2D = load("res://scenes/townfolk.gd").new()
	add_child(tf)
	tf.setup(null, g)

	var zhang: Sprite2D = null
	for f in tf._folk:
		if str(f["id"]) == "hanshang_zhanggui":
			zhang = f["sprite"]
	_ok(zhang != null, "找得到掌柜的精灵")
	if zhang == null:
		return
	_ok(zhang.position.x > 300.0, "掌柜原本在右半边（%.1f）" % zhang.position.x)
	_ok(g.state_changed.is_connected(tf._sync_presence),
		"townfolk 已接上 state_changed（这就是上一版漏掉的那根线）")

	# 把驿馆拖到左边
	g.move_site("inn", Vector2(10, 8))

	_ok(zhang.position.x < 200.0,
		"掌柜的精灵被搬到了左半边（%.1f）—— 说明他真的跟着走" % zhang.position.x)


## 建造 → 地图显示 的连通性。
##
## 这一节防的是一类特别隐蔽的 bug：**两套 id 命名各写各的**。
##   data/numbers.json 的建筑 id 是 yiguan / majiu / cangku / chufang …
##   core/sites.gd 的地标键是      inn    / stable / warehouse / kitchen …
## 实测两者**交集为空** —— 指的是同一样东西，但名字完全不一样。
## 于是「建造写 state[buildings][majiu]、地图查 state[buildings][stable]」，
## 永远对不上：玩家花材料建完，地图上什么也不出现。
##
## 这类错误不报错、不崩、不影响别的系统，只是**没反应** ——
## 玩家的原话是「建完以后地图也没有显示呀，建到哪里去了」。
## 所以必须写成断言，靠人眼是发现不了的。
func _test_building_visibility() -> void:
	_section("建造 → 地图显示 的连通性")

	# 翻译表必须覆盖「既能在建造菜单里造、又在地图上有地标」的每个建筑
	var pairs := [
		{"site": "inn", "bid": "yiguan"},
		{"site": "stable", "bid": "majiu"},
		{"site": "warehouse", "bid": "cangku"},
		{"site": "kitchen", "bid": "chufang"},
	]
	for p in pairs:
		_eq(Sites.building_id_of(str(p["site"])), str(p["bid"]),
			"sites.gd 的 %s 翻译成 numbers.json 的 %s" % [str(p["site"]), str(p["bid"])])

	# 反向：sites.gd 里每个 building 类地标都必须能翻译出 id，
	# 否则那个建筑一旦可建造，就会重演「建了不显示」
	for id in Sites.PLACES:
		var pl: Dictionary = Sites.PLACES[id]
		if str(pl.get("kind", "")) != "building":
			continue
		_ok(Sites.building_id_of(str(id)) != "",
			"可移动建筑 %s 有对应的 numbers.json id" % str(id))

	# 每个**会上地图**的地标都必须有悬停说明文案。
	# 漏一个的后果是：鼠标停上去浮层是空白的，玩家以为功能坏了。
	# 判据用 tex != "" ：有贴图的才会被画出来、也才有可能被鼠标指到；
	# 区域地标（竖井链/农田/树林…）没有贴图，不参与悬停。
	for id in Sites.PLACES:
		var pl2: Dictionary = Sites.PLACES[id]
		if str(pl2.get("tex", "")) == "":
			continue
		_ok(str(pl2.get("desc", "")).strip_edges() != "",
			"地标 %s 有悬停说明文案" % str(id))

	# 端到端：马厩门槛是 sections>=2。把段数压到 0，它本该绝不出现；
	# 只有在「建成」之后才该出现 —— 这就把两个条件彻底分开了。
	var sections_bak := int(_game.query("karez.sections"))
	var had_majiu: bool = _game.state.get("buildings", {}).has("majiu")

	_game.state["karez"]["sections"] = 0
	_game.state["buildings"].erase("majiu")
	_eq(_game.place_present("stable"), false, "0 段且未建成时，马厩不出现")

	_game.state["buildings"]["majiu"] = {"level": 1, "condition": 100.0}
	_eq(_game.place_present("stable"), true,
		"建成马厩后（坎儿井段数仍为 0），它出现在地图上")

	# 还原现场，别影响后面的用例
	if not had_majiu:
		_game.state["buildings"].erase("majiu")
	_game.state["karez"]["sections"] = sections_bak


## 建筑效果接线。
##
## 防的是「数据里定义了效果、代码却没人读」这类问题 ——
## 在本轮之前，numbers.json 的 19 个建筑 effect 字段里**只有 3 个**被读过，
## 也就是说地图上画着十来个纯装饰的设施，玩家花了材料却什么也不发生。
##
## 这类问题不报错、不崩、不影响别的系统，玩起来只是"感觉没什么用"，
## 所以必须写成断言，靠玩很难系统性发现。
func _test_facilities() -> void:
	_section("建筑效果接线")

	var sections_bak := int(_game.query("karez.sections"))
	var water_bak: Dictionary = _game.state["resources"]["water"].duplicate(true)
	var buildings_bak: Dictionary = _game.state["buildings"].duplicate(true)

	# 仓库门槛是 always，开局就在场 → 储水上限 ×1.5
	_ok(_game.has_facility("cangku"), "仓库开局就在场（gate=always）")
	_eq(int(_game.water_capacity()), 450, "储水上限 = 基础 300 × 仓库 1.5")

	# 人口上限 = min(容量÷30, 田块×3) + 床位。
	_game.state["karez"]["sections"] = 4
	var cap_water: int = _game.population_capacity()
	_ok(cap_water >= 15,
		"4 段时人口上限 >=15（450÷30），实际 %d" % cap_water)

	# 床位是**加成**：把段数压到 0（水与田都不给容量），看驿馆能不能把上限抬起来。
	# ⚠ 两处都踩过坑，所以测试必须自己控制环境：
	#   ① 不能用 4 段测 —— 4 段时驿馆本来就按 gate 出现了，已经算进床位，再加一次看不出差别；
	#   ② 不能直接读 cap0 —— 前面的 60 天自动模拟会建东西并留在 state 里，
	#      驿馆留在里面的话，0 段也照样算 12 个床位。所以先把 buildings 清空。
	_game.state["karez"]["sections"] = 0
	_game.state["buildings"] = {}
	var cap0: int = _game.population_capacity()
	_game.state["buildings"]["yiguan"] = {"level": 1, "condition": 100.0}
	var cap1: int = _game.population_capacity()
	_ok(cap1 > cap0,
		"0 段时建驿馆能把人口上限抬起来：%d → %d（旧公式方向相反，会把它压低）" % [cap0, cap1])
	_eq(cap1, 12, "0 段 + 驿馆 = 12 个床位")

	# 厨房 → 省粮
	# ⚠ 显式写 float：_game 在测试里是无类型引用，facility_effect 的返回值被当成
	#   Variant，用 := 会撞上本项目「禁止从 Variant 推断类型」那条规则、直接解析失败。
	var fe: float = _game.facility_effect("chufang", "food_efficiency", 1.0)
	_ok(fe > 1.0, "厨房 food_efficiency 被读到（%.2f）" % fe)

	# 不在场的设施必须返回**中性值**，否则等于「没建也有加成」
	var zuo: float = _game.facility_effect("zuofang", "craft_efficiency", 1.0)
	_eq(zuo, 1.0, "作坊不在场时 craft_efficiency 返回中性 1.0")

	# 水位分档 1..4
	_game.state["resources"]["water"]["current"] = 0.0
	_eq(_game.reservoir_level(), 1, "水量 0 → 水位 1 档")
	_game.state["resources"]["water"]["current"] = \
		float(_game.state["resources"]["water"]["capacity"]) * 0.5
	_eq(_game.reservoir_level(), 3, "水量半满 → 水位 3 档")
	_game.state["resources"]["water"]["current"] = \
		float(_game.state["resources"]["water"]["capacity"])
	_eq(_game.reservoir_level(), 4, "水量满 → 水位 4 档（不能溢出成 5）")

	# 还原现场
	_game.state["karez"]["sections"] = sections_bak
	_game.state["resources"]["water"] = water_bak
	_game.state["buildings"] = buildings_bak
	_game.clamp_all()


func _test_save_roundtrip() -> void:
	_section("存档回环")
	var path := "user://test_save.json"
	var sections0 := int(_game.query("karez.sections"))
	var silver0 := float(_game.query("resources.silver"))

	_ok(_game.save_to(path), "save_to 成功")
	_ok(FileAccess.file_exists(path), "存档文件已生成")

	# 改乱状态
	_game.apply_deltas([{"op": "set", "path": "resources.silver", "value": 7}])
	_eq(float(_game.query("resources.silver")), 7.0, "故意改动银两")

	_ok(_game.load_from(path), "load_from 成功")
	_eq(int(_game.query("karez.sections")), sections0, "段数已还原")
	_eq(float(_game.query("resources.silver")), silver0, "银两已还原")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
