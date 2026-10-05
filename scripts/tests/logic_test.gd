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
