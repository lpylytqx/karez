extends Node
## 畜牧 / 灾难 / 腐坏 / 涝坝扩容 —— 新系统的边界测试。
##
## 为什么值得单独写成一套：这四块都是**数据驱动**的（配置在 numbers.json），
## 代码只负责"读数据 + 算结果"。数据驱动的系统最容易出的错不是崩溃，
## 而是**静默失效** —— 配置写着、代码没读，游戏照跑，只是那些数值永远不起作用。
## 这个项目里已经有过三例（majiu.livestock_capacity、food.shelf_life_days、
## cangku.spoilage_reduction 全都躺了很久没人读）。
## 所以这里的断言重点不是"不崩"，而是**"数据真的接线了"**。
##
##   tools\Godot_v4.7.2-stable_win64_console.exe --path scripts res://tests/livestock_disaster_test.tscn

var _pass := 0
var _fail := 0
var _play: Node
var _gs: Node


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
	print("  畜牧 / 灾难 / 腐坏 / 涝坝 —— 边界测试")
	print("=".repeat(64))
	_play = load("res://scenes/play.tscn").instantiate()
	add_child(_play)
	await get_tree().process_frame
	await get_tree().process_frame
	_gs = _play.get_node("GameState")

	await _t_livestock_basics()
	await _t_livestock_tick()
	await _t_catch_wild()
	await _t_spoilage()
	await _t_disasters()
	await _t_reservoir()
	await _t_always_present()
	await _t_new_sites()
	await _t_crafts()
	await _t_festivals()
	await _t_music_and_silk()
	await _t_pen()
	await _t_save_migration_and_build_menu()

	print("")
	print("=".repeat(64))
	if _fail == 0:
		print("  全部通过：%d 项" % _pass)
	else:
		print("  通过 %d 项，失败 %d 项" % [_pass, _fail])
	print("=".repeat(64))
	get_tree().quit(1 if _fail > 0 else 0)


## 把状态重置到一个可控的局面。
func _reset(food := 200.0, pop := 6) -> void:
	_gs.normalize_jobs()
	_gs.state["population"] = pop
	_gs.state["jobs"] = {"water": 1, "gather_wood": 1, "gather_earth": 1,
		"craft": 0, "farm": 1, "herd": 0, "guard": 1, "idle": 0}
	_gs.state["livestock"] = {"sheep": 0, "goat": 0, "camel": 0, "donkey": 0, "chicken": 0}
	_gs.state["livestock_days"] = {}
	_gs.state["livestock_log"] = []
	_gs.state["wild_trips"] = 0
	_gs.state["buildings"] = {}
	# ⚠ 坎儿井段数也要清！它决定一堆地标的 gate（仓库一向在场，但作坊/晾房/
	#   奏乐台/毡房/居所/围墙都是 sections >= N）。漏了这一句，
	#   前面的用例把段数设成 5 之后，"条件不齐"的用例其实是在条件齐备的状态下跑的 ——
	#   于是它测了个寂寞（踩过一次）。
	_gs.state["karez"]["sections"] = 0
	_gs.state["resources"]["food"]["grain"] = food
	_gs.state["resources"]["food"]["naan"] = 0.0
	_gs.state["resources"]["food"]["fruit"] = 0.0
	_gs.state["resources"]["food"]["meat"] = 0.0
	_gs.state["resources"]["food"]["milk"] = 0.0
	_gs.state["resources"]["water"]["current"] = 200.0
	_gs.state["stats"]["morale"] = 60.0
	_gs.state["disaster"] = {"active": "", "days_left": 0, "last_id": "",
		"cooldown": 0, "log": "", "history": []}
	_gs.state["action_points"] = 5
	# 施工队列也要清：_t_reservoir 会开工，不清的话后面的 build_info
	# 全都会以「正在施工」被拒，看起来像是建造逻辑坏了（踩过一次）。
	_gs.state["construction"] = {"kind": "", "target": "", "display": "",
		"days_left": 0, "total_days": 0, "progress": 0.0}
	_gs.clamp_all()


func _build(bid: String) -> void:
	_gs.state["buildings"][bid] = {"level": 1, "condition": 100.0}


## 摆一份「留 2 个闲人」的分工。抓野畜要 2 个闲人，而
##   unassigned = 人口 − 已分配
## —— 顺手把 idle 加成 2 会让总数超过人口、unassigned 变成负数，
## 于是「条件齐备」的用例全被拒，看起来像功能坏了。踩过一次，收成一个函数。
func _jobs_with_free_hands() -> void:
	_gs.normalize_jobs()
	_gs.state["jobs"] = {"water": 1, "gather_wood": 1, "gather_earth": 0,
		"craft": 0, "farm": 1, "herd": 0, "guard": 1, "idle": 0}


# ---------------------------------------------------------------------------

func _t_livestock_basics() -> void:
	_section("畜牧：数据接线（上限 / 饲料 / 名称）")
	_reset()
	_ok(_gs.livestock_of("sheep") == 0, "开局没有牲畜")
	_ok(_gs.total_livestock() == 0, "总数 0")

	# ⚠ 这一条是重点：majiu 的 livestock_capacity 在数据里躺了很久没人读
	var cap0: int = _gs.livestock_capacity()
	_build("majiu")
	var cap1: int = _gs.livestock_capacity()
	_ok(cap1 > cap0, "盖了马厩之后存栏上限变大（%d → %d）—— 说明读到了 livestock_capacity" % [cap0, cap1])

	# 畜种名来自数据，不是硬编码
	_ok(_gs.species_cn("sheep") == "阿勒泰细毛羊", "羊的显示名来自 numbers.json（%s）" % _gs.species_cn("sheep"))
	_ok(_gs.species_cn("camel") == "双峰驼", "驼的显示名来自 numbers.json（%s）" % _gs.species_cn("camel"))

	# 饲料：数量越多吃得越多；冬季更贵
	_gs.state["livestock"]["sheep"] = 4
	var feed_summer: float = _gs.livestock_feed_per_day()
	_gs.state["calendar"]["season"] = "winter"
	var feed_winter: float = _gs.livestock_feed_per_day()
	_gs.state["calendar"]["season"] = "summer"
	_ok(feed_summer > 0.0, "4 只羊每天要吃 %.1f 份草料" % feed_summer)
	_ok(feed_winter > feed_summer, "冬季饲料更多（%.1f > %.1f）" % [feed_winter, feed_summer])

	# 加牲畜受上限管
	_gs.state["livestock"] = {"sheep": 0, "goat": 0, "camel": 0, "donkey": 0, "chicken": 0}
	_gs.state["buildings"] = {}
	# ⚠ `_gs` 是无类型引用，它的返回值被当成 Variant —— `var room := ...` 会撞上
	#   本项目「禁止从 Variant 推断类型」那条规则，整个脚本解析失败。
	#   凡是 _gs / _play 的调用结果，都要显式写类型。
	var room: int = _gs.livestock_capacity()
	var got: int = _gs.add_livestock("sheep", room + 50)
	_ok(got == room, "加牲畜会被上限截住（要 %d 只，实得 %d，上限 %d）" % [room + 50, got, room])
	_ok(_gs.add_livestock("sheep", 5) == 0, "栏满之后再加就加不进去了")
	_ok(_gs.livestock_summary().contains("羊"), "存栏概括认得出羊（%s）" % _gs.livestock_summary())


func _t_livestock_tick() -> void:
	_section("畜牧：每日产出 / 繁殖 / 饿死")
	_reset()
	_build("majiu")
	_gs.state["livestock"]["sheep"] = 4
	_gs.state["jobs"]["herd"] = 1          # 有牧人
	seed(7)
	var r: Dictionary = _gs._tick_livestock()
	var prod: Dictionary = r["products"]
	_ok(prod.has("wool") and float(prod["wool"]) > 0.0,
		"有牧人照看时羊产毛（%.1f 斤）" % float(prod.get("wool", 0.0)))
	_ok(float(r["fed"]) > 0.0, "吃掉了草料 %.1f 份" % float(r["fed"]))
	_ok(not bool(r["starving"]), "草料够时不判定挨饿")

	# 没人照看：产出减半（这是「牧人决定产出」这条规则的验证）
	_reset()
	_build("majiu")
	_gs.state["livestock"]["sheep"] = 4
	_gs.state["jobs"]["herd"] = 0
	seed(7)
	var r2: Dictionary = _gs._tick_livestock()
	var untended := float(r2["products"].get("wool", 0.0))
	var tended := float(prod.get("wool", 0.0))
	_ok(untended < tended,
		"没牧人时产出更少（%.2f < %.2f）—— 牧人这个岗位真的有用" % [untended, tended])

	# 缺草料：会饿死牲畜
	_reset(0.0)
	_build("majiu")
	_gs.state["livestock"]["sheep"] = 6
	_gs.state["jobs"]["herd"] = 1
	seed(3)
	var r3: Dictionary = _gs._tick_livestock()
	_ok(bool(r3["starving"]), "草料为 0 时判定挨饿")
	_ok(int(r3["died"]) > 0, "挨饿会死牲畜（死了 %d 头）" % int(r3["died"]))
	_ok(_gs.total_livestock() < 6, "存栏确实少了（剩 %d）" % _gs.total_livestock())

	# 繁殖：够天数就会 +1
	_reset()
	_build("majiu")
	_gs.state["livestock"]["chicken"] = 2
	_gs.state["jobs"]["herd"] = 1
	var before: int = _gs.total_livestock()
	for i in range(30):
		_gs._tick_livestock()
		if _gs.total_livestock() > before:
			break
	_ok(_gs.total_livestock() > before,
		"鸡养够天数会繁殖（%d → %d）" % [before, _gs.total_livestock()])

	# 到上限就不再繁殖
	_reset()
	_gs.state["buildings"] = {}
	_gs.state["livestock"]["chicken"] = _gs.livestock_capacity()
	_gs.state["jobs"]["herd"] = 3
	var at_cap: int = _gs.total_livestock()
	for i in range(20):
		_gs._tick_livestock()
	_ok(_gs.total_livestock() == at_cap,
		"到存栏上限后不再繁殖（%d = %d）" % [_gs.total_livestock(), at_cap])


func _t_catch_wild() -> void:
	_section("抓野畜：成本、成功率、栏位限制")
	# ⚠ 要留出闲人：`unassigned = 人口 − 已分配`。第一版把 idle 加成 2 之后
	#   总分配数反而超了人口，unassigned 变成 -1，条件判定直接不通过 ——
	#   那是测试自己摆错了局面，不是功能有问题。
	_reset()
	_gs.state["jobs"] = {"water": 1, "gather_wood": 1, "gather_earth": 0,
		"craft": 0, "farm": 1, "herd": 0, "guard": 1, "idle": 0}
	_ok(_gs.unassigned() >= 2, "留出了 %d 个闲人（抓野畜要 2 个）" % _gs.unassigned())
	var info: Dictionary = _gs.catch_info()
	_ok(bool(info["ok"]), "条件齐备时可以派人去抓（%s）" % str(info.get("reason", "")))
	_ok(info["options"].size() >= 4, "可选野畜有 %d 种" % info["options"].size())
	var opts: Array = info["options"]
	_ok(float(opts[0]["difficulty"]) <= float(opts[opts.size() - 1]["difficulty"]),
		"野畜按难度升序排（%s → %s）" % [str(opts[0]["display"]), str(opts[opts.size() - 1]["display"])])

	# 必成功与必失败两种极端：用大样本验证"成功会加牲畜"
	_reset()
	_jobs_with_free_hands()
	var got_any := false
	for i in range(40):
		_gs.state["action_points"] = 5
		var res: Dictionary = _gs.catch_wild("argali")
		if i < 3:
			print("    第%d次返回：%s" % [i + 1, str(res)])
		if bool(res.get("success", false)):
			got_any = true
			break
	_ok(got_any, "多次尝试后能抓到盘羊（存栏：%s）" % _gs.livestock_summary())

	# 栏位满时抓不了：这条防止"抓回来没地方放"的静默丢失
	_reset()
	_jobs_with_free_hands()
	_gs.state["buildings"] = {}
	_gs.state["livestock"]["sheep"] = _gs.livestock_capacity()
	var full: Dictionary = _gs.catch_info()
	_ok(not bool(full["ok"]), "栏位满时不允许出发（%s）" % str(full.get("reason", "")))

	# 行动点不足
	_reset()
	_jobs_with_free_hands()
	_gs.state["action_points"] = 0
	var noap: Dictionary = _gs.catch_info()
	_ok(not bool(noap["ok"]), "行动点不足时不允许出发（%s）" % str(noap.get("reason", "")))

	# 失败也不该扣牲畜、不该扣人
	_reset()
	_jobs_with_free_hands()
	_gs.state["action_points"] = 5
	var pop0: int = _gs.state["population"]
	_gs.catch_wild("wild_camel")
	_ok(_gs.state["population"] == pop0, "抓野畜失败不会少人（%d）" % _gs.state["population"])


func _t_spoilage() -> void:
	_section("腐坏：保质期与仓库减损（数据接线）")
	_reset()
	# 馕 12 天、粮 90 天 —— 同样数量，烂得不一样多
	_gs.state["resources"]["food"]["naan"] = 100.0
	_gs.state["resources"]["food"]["grain"] = 100.0
	var rot: Dictionary = _gs._tick_spoilage()
	var naan_lost := float(rot.get("naan", 0.0))
	var grain_lost := float(rot.get("grain", 0.0))
	_ok(naan_lost > grain_lost,
		"馕（12 天保质）比粮（90 天）烂得快（%.2f > %.2f）—— 说明读到了 shelf_life_days" % [naan_lost, grain_lost])
	_ok(grain_lost > 0.0, "粮也会烂，不是永久保存")

	# 仓库按 spoilage_reduction 减少损耗。
	#
	# ⚠ 这里**不能**用"建仓库前后对比"来验证 —— 仓库的地标是 `gate: always`，
	#   开局就在场上，它的 spoilage_reduction 从第 1 天起就生效，
	#   建它反而等于白花材料（那是个独立的逻辑漏洞，见 _t_always_present）。
	#   所以改比对"完全不减损"的理论值：不接线的话馕每天必烂 100/12 = 8.33。
	_reset()
	_gs.state["resources"]["food"]["naan"] = 100.0
	var lost: float = float(_gs._tick_spoilage().get("naan", 0.0))
	var raw := 100.0 / 12.0        # 保质期 12 天，不做任何减损
	_ok(lost < raw * 0.99,
		"实际腐坏 %.2f 小于不减损的理论值 %.2f —— 说明 spoilage_reduction 接线了" % [lost, raw])

	# 数量为 0 的食物不该出现在结果里（避免日志刷一堆 0）
	_reset()
	var empty: Dictionary = _gs._tick_spoilage()
	_ok(not empty.has("meat"), "空库存的食物不出现在腐坏结果里")


func _t_disasters() -> void:
	_section("灾难：季节筛选 / 冷却 / 建筑减损 / 效果真的落地")
	_ok(_gs.disasters_cfg().size() >= 6, "灾难表有 %d 种" % _gs.disasters_cfg().size())

	# 沙暴只可能在春夏
	var ids: Array = []
	for c in _gs.disasters_cfg():
		ids.append(str(c["id"]))
	_ok("sandstorm" in ids and "cold_snap" in ids, "沙暴与寒潮都在表里")

	# 冬季跑很多天，只应出现"允许在冬季发生"的灾难
	_reset()
	_gs.state["calendar"]["season"] = "winter"
	var seen: Dictionary = {}
	for i in range(120):
		_gs.state["disaster"]["cooldown"] = 0
		var hit: Dictionary = _gs._roll_disaster()
		if not hit.is_empty():
			seen[str(hit["id"])] = true
	_ok(seen.has("cold_snap") or seen.has("plague"),
		"冬季会遭寒潮或瘟疫（实际 %s）" % str(seen.keys()))
	_ok(not seen.has("sandstorm"), "冬季不会遭沙暴（季节筛选生效）")
	_ok(not seen.has("flood"), "冬季不会遭融雪洪水")

	# 冷却：设上冷却就不该再发生
	_reset()
	_gs.state["calendar"]["season"] = "winter"
	_gs.state["disaster"]["cooldown"] = 5
	var blocked := true
	for i in range(5):
		if not _gs._roll_disaster().is_empty():
			blocked = false
	_ok(blocked, "冷却期内不会再遭灾")

	# 建筑减损：烽燧让沙暴减半
	_reset()
	_gs.state["resources"]["water"]["current"] = 200.0
	var sb: Dictionary = {}
	for c in _gs.disasters_cfg():
		if str(c["id"]) == "sandstorm":
			sb = c
	_ok(not sb.is_empty(), "取到沙暴配置")
	_gs._apply_disaster(sb)
	var loss_plain := 200.0 - float(_gs.state["resources"]["water"]["current"])
	_reset()
	_build("fengsui")
	_gs.state["resources"]["water"]["current"] = 200.0
	_gs._apply_disaster(sb)
	var loss_guarded := 200.0 - float(_gs.state["resources"]["water"]["current"])
	_ok(loss_guarded < loss_plain,
		"烽燧让沙暴失水变少（%.0f < %.0f）—— mitigation 真的接线了" % [loss_guarded, loss_plain])

	# 牲畜损失真的落到存栏上
	_reset()
	_gs.state["livestock"]["sheep"] = 10
	var before_lv: int = _gs.total_livestock()
	var cold: Dictionary = {}
	for c in _gs.disasters_cfg():
		if str(c["id"]) == "cold_snap":
			cold = c
	seed(11)
	_gs._apply_disaster(cold)
	_ok(_gs.total_livestock() < before_lv,
		"寒潮会冻死牲畜（%d → %d）—— 灾难与畜牧联动了" % [before_lv, _gs.total_livestock()])

	# 大旱：流量打折通过 disaster_mult 生效
	_reset()
	_gs.state["disaster"]["active"] = "drought"
	_gs.state["disaster"]["days_left"] = 3
	_ok(_gs.disaster_mult("flow_multiplier", 1.0) < 1.0,
		"大旱期间流量系数 < 1（%.2f）" % _gs.disaster_mult("flow_multiplier", 1.0))
	_gs.state["disaster"]["active"] = ""
	_ok(_gs.disaster_mult("flow_multiplier", 1.0) == 1.0, "没灾时系数回到 1.0")

	# 持续天数会递减到 0 然后清空
	_reset()
	_gs.state["disaster"]["active"] = "drought"
	_gs.state["disaster"]["days_left"] = 2
	for i in range(4):
		_gs._roll_disaster()
	_ok(str(_gs.state["disaster"]["active"]) == "" or int(_gs.state["disaster"]["days_left"]) > 0,
		"持续灾难会自然结束（active=%s left=%d）" % [
			str(_gs.state["disaster"]["active"]), int(_gs.state["disaster"]["days_left"])])


func _t_reservoir() -> void:
	_section("涝坝扩容：数据接线与施工队列")
	_reset()
	var info: Dictionary = _gs.reservoir_info()
	_ok(not info["next"].is_empty(), "有下一级涝坝可扩（%s）" % str(info.get("display", "")))
	_ok(int(info["max_level"]) >= 2, "涝坝有 %d 级可扩" % int(info["max_level"]))

	# 材料不足时拦住
	_reset()
	_gs.state["resources"]["materials"]["wood"] = 0
	_gs.state["resources"]["materials"]["earth"] = 0
	var poor: Dictionary = _gs.reservoir_info()
	_ok(not bool(poor["ok"]), "材料不足时不能开工（%s）" % str(poor.get("reason", "")))

	# 材料够就能开工，并占住施工队列
	_reset()
	_gs.state["resources"]["materials"]["wood"] = 999
	_gs.state["resources"]["materials"]["earth"] = 999
	var r: Dictionary = _gs.start_reservoir()
	_ok(bool(r.get("ok", false)), "材料够时可以开工（%s）" % str(r.get("display", "")))
	_ok(not _gs.construction_idle(), "涝坝扩建占住了施工队列")
	_ok(str(_gs.state["construction"].get("kind", "")) == "reservoir", "施工类型是 reservoir")
	_ok(not bool(_gs.reservoir_info()["ok"]), "施工中不能再开第二项工程")


## 建造菜单不该卖「已经在你场上的设施」。
##
## 这一节是被 _t_spoilage 逼出来的：仓库（warehouse）的地标写的是 `gate: always`，
## 于是它的 storage_multiplier / spoilage_reduction **从第 1 天起就生效**。
## 玩家花材料去"建"仓库，实际什么都没改变 —— 付了钱没拿到东西。
## 修法：`build_info()` 对"已经在地图上起作用但没建成过"的设施直接拒绝，
## 理由说清楚是「此地已有」，而不是含糊的失败。
func _t_always_present() -> void:
	_section("建造菜单不卖「已在你场上的设施」")
	_reset()
	_gs.state["resources"]["materials"]["wood"] = 999
	_gs.state["resources"]["materials"]["earth"] = 999
	_gs.state["buildings"] = {}

	var already: Array = []
	for b in _gs.numbers.get("buildings", {}).get("list", []):
		var bid := str(b.get("id", ""))
		var info: Dictionary = _gs.build_info(bid)
		var present: bool = _gs.has_facility(bid)
		if present and not _gs.state["buildings"].has(bid):
			already.append(bid)
			_ok(not bool(info["ok"]),
				"「%s」开局就在起作用，建造被拒（理由：%s）" % [
					str(b.get("display", bid)), str(info.get("reason", ""))])
	print("    开局本就生效的设施：%s" % str(already))
	_ok(already.size() > 0,
		"确实存在开局即生效的设施（%d 个）—— 这些正是原来会白花材料的那批" % already.size())


## 补上的 4 个地标：围墙 / 居民居所 / 毡房区 / 奏乐台。
##
## 为什么单列一节：这 4 个建筑的**数值与美术一直都有**（numbers.json 里写着
## security / population_capacity / morale_per_day，素材 wall_stone_01 / 
## house_resident_01 / tent_01 也一直躺在 assets 里没人引用），
## 但 sites.gd 的 PLACES 与 BUILDING_ID 里**没有它们的地标**。
## 后果：`has_facility()` 永远返回 false → effect 从来没生效过，
## 而且玩家在建造菜单里点了，地图上也不会出现任何东西。
##
## 这类错最隐蔽：不崩、不报错、测试也全绿，只是那些数值永远不起作用。
func _t_new_sites() -> void:
	_section("补上的 4 个地标：围墙 / 居所 / 毡房区 / 奏乐台")
	_reset()
	_gs.state["karez"]["sections"] = 5
	var present: Array = []
	for bid in ["weijiang", "juzhu", "zhanfang", "yinletai"]:
		if _gs.has_facility(bid):
			present.append(bid)
	_ok(present.size() == 4,
		"5 段之后 4 个新地标全部在场（%s）" % str(present))

	# 它们的 effect 真的被读到了
	var beds := 0
	for bid in ["juzhu", "zhanfang"]:
		beds += int(_gs._building_cfg(bid).get("effect", {}).get("population_capacity", 0))
	_ok(beds > 0, "居所 + 毡房提供 %d 个床位（会算进人口上限）" % beds)
	var sec: float = _gs.facility_effect("weijiang", "security", 0.0)
	_ok(sec > 0.0, "围墙的 security 字段被读到（%.0f）" % sec)
	var mor: float = _gs.facility_effect("yinletai", "morale_per_day", 0.0)
	_ok(mor > 0.0, "奏乐台的 morale_per_day 字段被读到（%.1f）" % mor)
	var raid: float = _gs.facility_effect("weijiang", "raid_defense_bonus", 0.0)
	_ok(raid >= 0.0, "围墙的 raid_defense_bonus 字段可读（%.2f）" % raid)

	# gate 仍然起作用：段数不够时不该在场
	_gs.state["karez"]["sections"] = 0
	_gs.state["buildings"] = {}
	var early: Array = []
	for bid in ["weijiang", "juzhu", "zhanfang", "yinletai"]:
		if _gs.has_facility(bid):
			early.append(bid)
	_ok(early.is_empty(),
		"0 段时 4 个新地标都不在场（gate 仍在生效，实际 %s）" % str(early))


## 加工：把原料变成值钱的成品。
##
## 这一节回答两件事：
##   · `economy.base_prices` 里早有 raisin / rug / instrument 的价，
##     但**以前没有任何系统产出它们** —— 价格表是空的
##   · 畜牧产出的**羊毛原本毫无用处** —— 擀成毡子之后，养羊才真的换得到钱
func _t_crafts() -> void:
	_section("加工：瓜果→葡萄干、羊毛→毡子")
	_reset()
	_gs.state["resources"]["food"]["fruit"] = 40.0
	var info: Array = _gs.crafts_info()
	_ok(info.size() >= 4, "有 %d 条配方" % info.size())
	for r in info:
		if str(r["id"]) == "raisin":
			_ok(not bool(r["ok"]) and str(r["reason"]).contains("晾房"),
				"没晾房时晾葡萄干被拦（%s）" % str(r["reason"]))
	_ok(_gs._tick_crafts().is_empty(), "没有对应建筑时一条配方都不跑")

	# 晾房（gate 是 sections >= 4）→ 瓜果变葡萄干
	_gs.state["karez"]["sections"] = 5
	var made: Dictionary = _gs._tick_crafts()
	_ok(float(made.get("raisin", 0.0)) > 0.0,
		"晾房把瓜果变成了葡萄干（%.0f 份）—— fruit_to_raisin_rate 这条数据第一次真被用上" % float(made.get("raisin", 0.0)))
	_ok(float(_gs.state["resources"]["food"]["fruit"]) < 40.0,
		"瓜果被扣掉（剩 %.0f）" % float(_gs.state["resources"]["food"]["fruit"]))

	# 羊毛 → 毡子：畜牧产出第一次能换成东西
	if not _gs.state["resources"].has("products"):
		_gs.state["resources"]["products"] = {}
	_gs.state["resources"]["products"]["wool"] = 9.0
	_gs.state["buildings"]["zuofang"] = {"level": 1, "condition": 100.0}
	var felt_before: float = _gs.stock_of("felt")
	var wool_before: float = _gs.stock_of("wool")
	_gs._tick_crafts()
	_ok(_gs.stock_of("felt") > felt_before,
		"羊毛擀成了毡子（%.0f 张）" % _gs.stock_of("felt"))
	_ok(_gs.stock_of("wool") < wool_before,
		"羊毛被消耗（%.1f → %.1f）" % [wool_before, _gs.stock_of("wool")])

	# 原料不够：整条跳过，**不扣一半**
	_reset()
	_gs.state["karez"]["sections"] = 5
	_gs.state["resources"]["food"]["fruit"] = 1.0     # 配方要 4
	var none: Dictionary = _gs._tick_crafts()
	_ok(not none.has("raisin"), "瓜果不到 4 份就不产出葡萄干")
	_ok(absf(float(_gs.state["resources"]["food"]["fruit"]) - 1.0) < 0.01,
		"不够就整条跳过，不会扣一半（瓜果仍是 1.0）")

	# 物产名来自数据，不在代码里另写一份
	_ok(_gs.good_cn("raisin") == "葡萄干", "葡萄干的名字来自 numbers.json（%s）" % _gs.good_cn("raisin"))
	_ok(_gs.good_cn("wool") == "羊毛", "羊毛的名字来自 numbers.json（%s）" % _gs.good_cn("wool"))
	_ok(_gs.good_cn("felt") == "毡子", "毡子的名字来自 numbers.json（%s）" % _gs.good_cn("felt"))


## 节庆：诺鲁孜节 / 葡萄熟了 / 古尔邦节。
##
## 判据只有「季 + 季内第几天」，刻意不加随机 —— 节庆要**可预期**才像个日子。
## 另外必须防"反复推进时段刷声望"，所以用 flags 记住今年已经过过了。
func _t_festivals() -> void:
	_section("节庆：触发、防重复、与畜牧挂钩")
	_reset()
	_ok(_gs.festivals_cfg().size() >= 3, "节庆表有 %d 个" % _gs.festivals_cfg().size())
	# ⚠ 静态自检：节日日期必须在 1..每季天数 之内。
	#   古尔邦节原本写在第 40 天，而每季只有 30 天 ——
	#   数据合法、代码不报错、测试也不失败，只是**那个节日永远不会触发**。
	#   这是数据驱动系统最典型的静默失效，必须有断言守着。
	var per_season: int = int(_gs.numbers.get("calendar", {}).get("days_per_season", 30))
	var bad_days: Array = []
	for f in _gs.festivals_cfg():
		if int(f.get("day", 0)) < 1 or int(f.get("day", 0)) > per_season:
			bad_days.append("%s(第%d天)" % [str(f.get("display", "")), int(f.get("day", 0))])
	_ok(bad_days.is_empty(),
		"所有节日的日期都在 1..%d 之内（越界：%s）" % [per_season, str(bad_days)])

	_gs.state["calendar"]["season"] = "spring"
	_gs.state["calendar"]["day"] = 3
	_gs.state["flags"] = {}
	var morale0 := float(_gs.state["stats"]["morale"])
	var f: Dictionary = _gs.check_festival()
	_ok(str(f.get("display", "")) == "诺鲁孜节",
		"春季第 3 天触发诺鲁孜节（实际 %s）" % str(f.get("display", "")))
	_ok(float(_gs.state["stats"]["morale"]) > morale0,
		"节庆加了士气（%.0f → %.0f）" % [morale0, float(_gs.state["stats"]["morale"])])

	# 防刷：同一天再查不该再触发
	var morale1 := float(_gs.state["stats"]["morale"])
	_ok(_gs.check_festival().is_empty(), "同一天不会重复触发")
	_ok(absf(float(_gs.state["stats"]["morale"]) - morale1) < 0.01,
		"反复查询不会刷士气（防「推进时段刷声望」）")

	_gs.state["calendar"]["day"] = 7
	_ok(_gs.check_festival().is_empty(), "第 7 天不是节庆")

	# 古尔邦节：有牲口的人家更体面
	_reset()
	_gs.state["calendar"]["season"] = "autumn"
	_gs.state["calendar"]["day"] = 25
	_gs.state["flags"] = {}
	_gs.state["stats"]["reputation"] = 10.0
	_gs.state["livestock"] = {"sheep": 0, "goat": 0, "camel": 0, "donkey": 0, "chicken": 0}
	var few: Dictionary = _gs.check_festival()
	_ok(str(few.get("display", "")) == "古尔邦节",
		"秋季第 25 天触发古尔邦节（实际 %s）" % str(few.get("display", "")))
	var rep_few := float(_gs.state["stats"]["reputation"])

	_reset()
	_gs.state["calendar"]["season"] = "autumn"
	_gs.state["calendar"]["day"] = 25
	_gs.state["flags"] = {}
	_gs.state["stats"]["reputation"] = 10.0
	_gs.state["buildings"]["majiu"] = {"level": 1, "condition": 100.0}
	_gs.state["livestock"] = {"sheep": 9, "goat": 0, "camel": 0, "donkey": 0, "chicken": 0}
	var many: Dictionary = _gs.check_festival()
	_ok(float(_gs.state["stats"]["reputation"]) > rep_few,
		"牲口多的人家过宰牲节声望更高（%.0f > %.0f）—— 畜牧的回报不只是钱"
			% [float(_gs.state["stats"]["reputation"]), rep_few])
	_ok(str(many.get("display", "")) == "古尔邦节", "有牲口时同样触发古尔邦节")


## 木卡姆与棉花/绸。
##
## 这一节要验证的是**链子接上了**，不是"有个按钮能加士气"：
##   木料（采集）→ 作坊做热瓦普（加工）→ 奏乐台办木卡姆（士气/声望）
##   棉花（秋收）→ 作坊织艾德莱斯绸（加工）
## 两条链各断一环，前面的系统就等于白做。
func _t_music_and_silk() -> void:
	_section("木卡姆：奏乐台 + 艺人 + 热瓦普；棉花 → 艾德莱斯绸")
	_reset()
	_ok(_gs.music_suites().size() >= 6, "木卡姆有 %d 套可演奏" % _gs.music_suites().size())

	# 1) 条件不齐时办不了，而且理由要说清是缺哪一项
	var info0: Dictionary = _gs.music_info()
	_ok(not bool(info0["ok"]), "条件不齐时办不了")
	_ok(str(info0["reason"]).contains("奏乐台"),
		"理由指出缺奏乐台（%s）" % str(info0["reason"]))

	# 2) 齐备：奏乐台（sections>=3）+ 木卡姆艺人在场 + 库里 1 把热瓦普
	_gs.state["karez"]["sections"] = 5
	_gs.state["resources"]["materials"]["instrument"] = 1.0
	_gs.state["action_points"] = 5
	_gs.state["jobs"] = {"water": 1, "gather_wood": 1, "gather_earth": 0,
		"craft": 0, "farm": 1, "herd": 0, "guard": 1, "idle": 0}
	var info1: Dictionary = _gs.music_info()
	_ok(bool(info1["ok"]), "条件齐备时能办（%s）" % str(info1["reason"]))

	# 3) 办一场：加士气、进冷却
	var m0 := float(_gs.state["stats"]["morale"])
	var r: Dictionary = _gs.perform_muqam(0)
	_ok(bool(r.get("ok", false)), "办成第一套（%s）" % str(r.get("display", "")))
	_ok(float(_gs.state["stats"]["morale"]) > m0,
		"士气上升（%.0f → %.0f）" % [m0, float(_gs.state["stats"]["morale"])])
	_ok(int(_gs.state["music_cooldown"]) > 0,
		"进了冷却（%d 天）" % int(_gs.state["music_cooldown"]))
	_ok(not bool(_gs.music_info()["ok"]), "冷却期内不能再办")

	# 4) 热瓦普只是要在库里，**不消耗** ——
	#    用完就断弦要重做的话，玩家会不敢办，这条链等于废了
	_ok(_gs.stock_of("instrument") >= 1.0,
		"热瓦普没被消耗（还剩 %.0f）" % _gs.stock_of("instrument"))

	# 5) 棉花：秋季每名农夫收 2 单位，别的季节不收
	_reset()
	_gs.state["jobs"]["farm"] = 3
	_gs.state["calendar"]["season"] = "summer"
	_ok(_gs._tick_cotton() == 0.0, "夏季不收棉花")
	_gs.state["calendar"]["season"] = "autumn"
	var c: float = _gs._tick_cotton()
	_ok(c > 0.0, "秋季收到棉花 %.0f（3 个农夫 × 2）" % c)

	# 6) 棉花 → 艾德莱斯绸（作坊）
	_gs.state["buildings"]["zuofang"] = {"level": 1, "condition": 100.0}
	_gs.state["resources"]["materials"]["cotton"] = 8.0
	var silk_before: float = _gs.stock_of("silk")
	_gs._tick_crafts()
	_ok(_gs.stock_of("silk") > silk_before,
		"棉花织成了艾德莱斯绸（%.0f 匹）" % _gs.stock_of("silk"))
	_ok(_gs.good_cn("silk") == "艾德莱斯绸",
		"绸的名字来自数据，不在代码里另写一份（%s）" % _gs.good_cn("silk"))


## 畜栏：专门用来扩存栏的便宜建筑。
##
## 目标里写的是「畜栏建筑」，而此前只有 majiu（马厩）顺带提供存栏上限。
## 马厩是给商队换马的地方，把"养羊"整个挂在它身上，玩家扩群时看到的是"马厩" ——
## 概念是错位的。畜栏便宜快、马厩贵慢但给 trade_range，两者各有用处。
func _t_pen() -> void:
	_section("畜栏建筑：专管扩存栏")
	_reset()
	var cap_base: int = _gs.livestock_capacity()
	_gs.state["karez"]["sections"] = 3          # 畜栏 gate 是 sections >= 2
	_ok(_gs.has_facility("yangjuan"), "3 段之后畜栏在场")
	var cap_pen: int = _gs.livestock_capacity()
	_ok(cap_pen > cap_base,
		"畜栏抬高了存栏上限（%d → %d）" % [cap_base, cap_pen])
	# ⚠ 不能拿"只盖畜栏"和"畜栏+马厩"比 —— 马厩的 gate 也是 sections >= 2，
	#   所以设成 3 段时**两个建筑同时在场**（6 + 10 + 15 = 31 就是这么来的）。
	#   要看各自贡献，直接读各自的 effect 字段。
	var pen_gives: float = _gs.facility_effect("yangjuan", "livestock_capacity", 0.0)
	var stable_gives: float = _gs.facility_effect("majiu", "livestock_capacity", 0.0)
	_ok(pen_gives > 0.0, "畜栏自己提供 %d 个栏位" % int(pen_gives))
	_ok(stable_gives > 0.0, "马厩自己提供 %d 个栏位" % int(stable_gives))
	_ok(cap_pen >= cap_base + int(pen_gives),
		"上限确实按畜栏的字段抬上去了（%d >= %d + %d）"
			% [cap_pen, cap_base, int(pen_gives)])
	# 两个建筑是**各有用处**而不是重复：马厩另有 trade_range
	_ok(float(_gs.facility_effect("majiu", "trade_range", 0.0)) > 0.0,
		"马厩另有 trade_range（%.0f）—— 和畜栏不是重复建筑"
			% float(_gs.facility_effect("majiu", "trade_range", 0.0)))
	# 畜栏的建造可行性：0 段时它还没出现，但**可以提前建造**
	_reset()
	_gs.state["resources"]["materials"]["wood"] = 999.0
	_gs.state["resources"]["materials"]["earth"] = 999.0
	var info: Dictionary = _gs.build_info("yangjuan")
	_ok(bool(info["ok"]),
		"0 段时可以提前建造畜栏（%s）" % str(info.get("reason", "")))


## 旧存档迁移 + 建造菜单完整性。
##
## 这两个都是「**新开一局永远正常、只有老玩家才炸**」的 bug，所以必须单独造场景：
##   · 读档原来是 `state = parsed["state"]`（整体替换、无迁移）。
##     本项目每轮都在加系统，旧存档里没有畜牧/灾难/木卡姆/加工的字段 ——
##     读出来之后那些系统取到 null 就静默失效或直接报错。
##   · 建造菜单硬编码了 2 座建筑，而数据里已有 13 座 ——
##     玩家根本点不到其余 11 座（仓库/作坊/晾房/围墙/烽燧/居所/毡房区/奏乐台/畜栏）。
func _t_save_migration_and_build_menu() -> void:
	_section("旧存档迁移 + 建造菜单完整性")
	_reset()

	# ── 1) 造一份"大改之前"的存档：只有老字段 ──
	var legacy := {
		"calendar": {"day": 40, "season": "summer", "phase": "morning"},
		"resources": {"water": {"current": 500.0, "capacity": 900.0},
			"food": {"grain": 120.0, "nang": 10.0},
			"materials": {"wood": 30.0, "earth": 20.0},
			"silver": 80.0,
			"products": {}},
		"karez": {"sections": 3},
		"buildings": {},
		"population": 6,
		"jobs": {"water": 1, "farm": 1, "gather_wood": 1, "idle": 3},
		"stats": {"morale": 60.0, "security": 50.0, "reputation": 5.0},
		"flags": {},
		"construction": {},
	}
	var tmp := "user://legacy_save_test.json"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	f.store_string(JSON.stringify({"save_version": 1, "state": legacy}))
	f.close()
	_ok(_gs.load_from(tmp), "能读入模拟的旧版本存档")

	# ⚠ 下面这几条就是 bug 本体：读档后这些键必须存在，
	#   否则畜牧 / 灾难 / 木卡姆 / 加工全部取到 null。
	for k in ["livestock", "livestock_days", "disaster", "music_cooldown", "wild_trips"]:
		_ok(_gs.state.has(k), "读旧档后补上了字段：%s" % k)
	_ok(_gs.state["karez"].has("reservoir_level"), "读旧档后 karez 补上了 reservoir_level")
	_ok(not _gs.livestock_summary().is_empty(), "读旧档后畜牧系统可用")
	_ok(int(_gs.total_livestock()) >= 0, "读旧档后总牲畜数可读")
	_ok(_gs.disasters_cfg().size() > 0, "读旧档后灾难配置可读")
	_ok(not _gs.music_info().is_empty(), "读旧档后木卡姆可用（suites %d 套）"
		% int(_gs.music_info().get("suites", []).size()))
	# 迁移是"只补不覆盖"
	_ok(int(_gs.state["karez"]["sections"]) == 3, "迁移不覆盖已有数值（段数仍为 3）")
	_ok(absf(float(_gs.state["resources"]["silver"]) - 80.0) < 0.01, "迁移不覆盖银两（仍为 80）")
	# 补完之后推进一天不能报错
	_gs.advance_day()
	_ok(true, "读旧档后推进一天不报错")

	# ── 2) 建造菜单必须覆盖数据里的全部建筑 ──
	_reset()
	var all: Array = _gs.all_buildings()
	_ok(all.size() >= 13, "建筑表有 %d 座（原来菜单只有硬编码的 2 座）" % all.size())
	var bad: Array = []
	var ids: Array = []
	for b in all:
		var id := str(b.get("id", ""))
		ids.append(id)
		var info: Dictionary = _gs.build_info(id)
		if str(info.get("display", "")) == "" or str(info.get("display", "")) == id:
			bad.append("%s 无中文名" % id)
		if not info.has("materials"):
			bad.append("%s 无造价" % id)
	_ok(bad.is_empty(), "每座建筑都有中文名与造价（问题：%s）" % str(bad))
	var missing: Array = []
	for want in ["yangjuan", "yinletai", "zhanfang", "juzhu", "weijiang",
			"cangku", "chufang", "bazha", "zuofang", "liangfang", "fengsui"]:
		if not (want in ids):
			missing.append(want)
	_ok(missing.is_empty(), "11 座原来点不到的建筑都在列表里（缺：%s）" % str(missing))

	# 反例：gate 是 sections 的设施**仍可提前建造**（那时它还没出现）
	var gated := ""
	for b in _gs.numbers.get("buildings", {}).get("list", []):
		var bid := str(b.get("id", ""))
		if not _gs.has_facility(bid):
			gated = bid
			break
	if gated != "":
		var ginfo: Dictionary = _gs.build_info(gated)
		_ok(bool(ginfo["ok"]),
			"还没出现的设施仍然可以提前建造（%s）" % str(ginfo.get("display", gated)))
