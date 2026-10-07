extends Node
## 摆法对比探针：**同一批兵、同一个敌人，只换摆法，跑多遍看结果差异**。
##
## 为什么做这个：前面我一次次请玩家"打两场对比给我看"，但那是把验证的活推给他，
## 而且只跑一场的话，伤害是 0.8~1.25 随机的，单次结果说明不了问题。
## 这里由我自己跑：每种摆法跑多遍、用同一组随机种子，才能公平对比。
##
## 加速手段：把 `_step_time` 从 0.62s 压到 0.015s，一场从十几秒变成半秒。
## **只压探针这一份实例**（直接改 Battle 节点的私有字段），不写回 numbers.json，
## 所以游戏本身的节奏一点没动。
##
##   tools\Godot_v4.7.2-stable_win64_console.exe --path scripts res://tests/formation_probe.tscn

const RUNS := 6                       # 每种摆法跑几遍
const ROSTER := ["shield", "shield", "archer", "archer", "militia"]
const ENEMIES := 4
const FAST_STEP := 0.015
const FIGHT_MAX_SECONDS := 30.0

var _play: Node
var _battle: Node


func _ready() -> void:
	print("=".repeat(70))
	print("  摆法对比：同样 %d 人 %s，同样来犯 %d 人，只换摆法，各跑 %d 遍" % [
		ROSTER.size(), _join(ROSTER), ENEMIES, RUNS])
	print("=".repeat(70))
	_play = load("res://scenes/play.tscn").instantiate()
	add_child(_play)
	await get_tree().process_frame
	await get_tree().process_frame
	_battle = _play.get_node("Battle")

	var cases := [
		{"name": "A 自动布阵（盾前 / 弓后）", "build": Callable(self, "_f_auto")},
		{"name": "B 全员压最前线", "build": Callable(self, "_f_push")},
		{"name": "C 弓手丢到射程外（反例）", "build": Callable(self, "_f_wrong")},
		{"name": "D 一字纵队（同一竖线）", "build": Callable(self, "_f_column")},
	]

	var rows: Array = []
	for c in cases:
		var r: Dictionary = await _run_case(c)
		rows.append(r)

	print("")
	print("%-30s %-8s %-10s %s" % ["摆法", "胜率", "平均阵亡", "阵型读数"])
	print("-".repeat(70))
	for r in rows:
		print("%-30s %-8s %-10s %s" % [
			r["name"],
			"%d/%d" % [r["wins"], RUNS],
			"%.2f" % r["avg_lost"],
			r["shape"]])

	print("")
	var best: Dictionary = rows[0]
	var worst: Dictionary = rows[0]
	for r in rows:
		if float(r["avg_lost"]) < float(best["avg_lost"]):
			best = r
		if float(r["avg_lost"]) > float(worst["avg_lost"]):
			worst = r
	print("  阵亡最少：%s（%.2f 人）" % [best["name"], best["avg_lost"]])
	print("  阵亡最多：%s（%.2f 人）" % [worst["name"], worst["avg_lost"]])
	var delta := float(worst["avg_lost"]) - float(best["avg_lost"])
	print("  差距：%.2f 人" % delta)
	if delta < 0.4:
		print("  → 差距太小：摆法对结果影响很弱，兵种没有真正接进交手逻辑，需要继续查")
	else:
		print("  → 差距明显：摆法确实影响结果")
	print("=".repeat(70))
	get_tree().quit(0)


func _join(a: Array) -> String:
	var parts: Array = []
	for x in a:
		parts.append(str(x))
	return ",".join(parts)


func _run_case(c: Dictionary) -> Dictionary:
	var wins := 0
	var lost_sum := 0
	var shape := ""
	var lost_list: Array = []
	for k in range(RUNS):
		# 同一种子给所有摆法用同一组 —— 否则随机性会盖过摆法带来的差异
		seed(1000 + k)
		_battle.finish()
		_battle.start(ROSTER.duplicate(), ENEMIES)
		_battle._step_time = FAST_STEP
		_battle.clear_deploy()
		var build: Callable = c["build"]
		build.call()
		shape = _battle._formation_text()
		_battle.begin_fight()
		var ok := await _wait_done()
		if not ok:
			print("    第 %d 遍没打完（超时）" % (k + 1))
			continue
		var res: Dictionary = _battle._result
		if bool(res.get("win", false)):
			wins += 1
		var l := int(res.get("lost", 0))
		lost_sum += l
		lost_list.append(l)
	print("  %-30s 阵亡序列 %s" % [c["name"], str(lost_list)])
	_battle.finish()
	return {
		"name": c["name"],
		"wins": wins,
		"avg_lost": float(lost_sum) / float(maxi(1, RUNS)),
		"shape": shape,
	}


func _wait_done() -> bool:
	var t0 := Time.get_ticks_msec()
	while _battle.current_phase() == 2:      # 2 = FIGHT
		if (Time.get_ticks_msec() - t0) > int(FIGHT_MAX_SECONDS * 1000.0):
			return false
		await get_tree().process_frame
	return true


# ── 四种摆法 ──────────────────────────────────────────────────────────────
# 布阵区东边界 = 靠敌一侧；敌军从东边来，所以 x 越大越靠前。

func _f_auto() -> void:
	_battle.auto_deploy()


func _f_push() -> void:
	# 全员站在最前线：谁先挨打这件事被摊平，等于没有纵深
	var r: Rect2 = _battle._deploy_rect()
	for i in range(ROSTER.size()):
		_battle._place_at(Vector2(r.position.x + r.size.x - 12.0,
			r.position.y + 12.0 + float(i) * 16.0))


func _f_wrong() -> void:
	# 对照组：**复现"弓手站到射程之外"这个失败摆法** —— 也就是第一版自动布阵
	# 摆出来的样子（弓手在 64px 之后，而射程只有 52）。
	# 留着它当反例，以后谁再把间距拉大，这张表立刻会难看。
	var r: Rect2 = _battle._deploy_rect()
	var front := r.position.x + r.size.x - 12.0
	var far := front - 64.0
	_battle._roster = ["archer", "archer", "militia", "shield", "shield"]
	_battle._pool = _battle._roster.size()
	for i in range(ROSTER.size()):
		# 名单前两个是弓手 -> 丢到射程外；其余贴身站前线
		var x := far if i < 2 else front
		_battle._place_at(Vector2(x, r.position.y + 12.0 + float(i) * 18.0))


func _f_column() -> void:
	# 一字纵队：所有人同一条竖线上排开（纵深拉满、横展 0），
	# 敌人只能一个个接上，人数优势被自己抹掉
	var r: Rect2 = _battle._deploy_rect()
	for i in range(ROSTER.size()):
		_battle._place_at(Vector2(r.position.x + r.size.x - 12.0 - float(i) * 15.0,
			r.position.y + r.size.y * 0.5))
