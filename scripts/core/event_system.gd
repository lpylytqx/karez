extends Node
## 事件系统 —— 把 data/events.v1.json 的 64 条事件接进游戏。
##
## 契约来自 data/events.schema.json：
##   • 条件用 {op, path, value} 表示，多个条件之间是 AND
##   • op 支持 gte / lte / eq / neq / has / not_has / is
##   • 效果与 state_delta 同构，另支持 memory 与 flag
##   • 抽取按 weight 加权，受 repeatable / cooldown_days / max_per_game 约束
##
## 与 AI 的分工：本系统只负责「哪条事件该出现、选项改了哪些数值」，
## 文案由静态 text/outcome 兜底，live 模式下可选地交给 AI 扩写。

signal event_triggered(event: Dictionary)
signal event_resolved(event_id: String, choice_index: int, outcome: String)

const EVENTS_PATH_PRIMARY := "res://../data/events.v1.json"
const EVENTS_PATH_FALLBACK := "res://data/events.v1.json"

var events: Array = []

var _game: Node = null
var _rng := RandomNumberGenerator.new()
## id -> 最近一次触发的天数
var _last_fired: Dictionary = {}
## id -> 本局已触发次数
var _fire_count: Dictionary = {}
## id -> 已选过的选项序号数组（用于避免同一事件反复给同一个结果）
var _resolved: Dictionary = {}


func _ready() -> void:
	_rng.randomize()
	events = _load_events()


## 由场景注入 GameState 引用。不直接 /root 取，便于测试时替换。
func setup(game: Node) -> void:
	_game = game


func _load_events() -> Array:
	for p in [EVENTS_PATH_PRIMARY, EVENTS_PATH_FALLBACK]:
		if FileAccess.file_exists(p):
			var parsed = JSON.parse_string(FileAccess.get_file_as_string(p))
			if parsed is Dictionary and parsed.has("events"):
				return parsed["events"]
			if parsed is Array:
				return parsed
			push_error("events.v1.json 解析失败：%s" % p)
	push_warning("未找到 events.v1.json，事件系统将空载运行。请确认 data/ 与 scripts/ 同级。")
	return []


# ---------------------------------------------------------------------------
# 条件 DSL 求值
# ---------------------------------------------------------------------------

func check_conditions(conds: Array) -> bool:
	## 全部满足才为 true（AND）。
	for c in conds:
		if not (c is Dictionary):
			return false
		if not _check_one(c):
			return false
	return true


func _check_one(c: Dictionary) -> bool:
	var op := str(c.get("op", ""))
	var path := str(c.get("path", ""))
	var expect = c.get("value", null)
	var actual = _game.query(path)

	match op:
		"has":     return actual == true
		"not_has": return actual != true
		"gte":     return _num(actual) >= _num(expect)
		"lte":     return _num(actual) <= _num(expect)
		"eq":      return _eq(actual, expect)
		"neq":     return not _eq(actual, expect)
		"is":      return str(actual) == str(expect)
	push_warning("未知条件 op：%s（路径 %s）" % [op, path])
	return false


func _num(v) -> float:
	if v is bool:
		return 1.0 if v else 0.0
	if v is float or v is int:
		return float(v)
	return 0.0


func _eq(actual, expect) -> bool:
	if expect is bool:
		return bool(actual) == expect
	if actual == null:
		return false
	if expect is String:
		return str(actual) == expect
	return absf(_num(actual) - _num(expect)) < 0.0001


# ---------------------------------------------------------------------------
# 抽取
# ---------------------------------------------------------------------------

## 当前状态下所有可触发的事件。
func eligible_events(category: String = "") -> Array:
	var out: Array = []
	for e in events:
		if not (e is Dictionary):
			continue
		var id := str(e.get("id", ""))
		if id == "":
			continue
		if category != "" and str(e.get("category", "")) != category:
			continue

		var fired := int(_fire_count.get(id, 0))

		# 不可重复的事件只能出现一次
		if not bool(e.get("repeatable", false)) and fired > 0:
			continue

		# 整局次数上限（null 表示不限）
		var maxpg = e.get("max_per_game", null)
		if maxpg != null and fired >= int(maxpg):
			continue

		# 冷却天数
		var cd := int(e.get("cooldown_days", 0))
		if cd > 0 and _last_fired.has(id):
			if _game.get_day() - int(_last_fired[id]) < cd:
				continue

		if not check_conditions(e.get("conditions", [])):
			continue

		out.append(e)
	return out


## 按 weight 加权抽一条。category 为空表示不限类别。抽不到返回 {}。
func pick_event(category: String = "") -> Dictionary:
	var pool := eligible_events(category)
	if pool.is_empty():
		return {}

	var total := 0
	for e in pool:
		total += maxi(0, int(e.get("weight", 1)))
	if total <= 0:
		return pool[_rng.randi_range(0, pool.size() - 1)]

	var roll := _rng.randi_range(1, total)
	var acc := 0
	for e in pool:
		acc += maxi(0, int(e.get("weight", 1)))
		if roll <= acc:
			return e
	return pool[pool.size() - 1]


# ---------------------------------------------------------------------------
# 触发与结算
# ---------------------------------------------------------------------------

func trigger(event: Dictionary) -> bool:
	## 标记事件已触发（推进冷却与计数），并广播给 UI。
	if event.is_empty():
		return false
	var id := str(event.get("id", ""))
	if id == "":
		return false
	_last_fired[id] = _game.get_day()
	_fire_count[id] = int(_fire_count.get(id, 0)) + 1
	event_triggered.emit(event)
	return true


## 抽一条并直接触发。返回被触发的事件（没有可触发事件时返回 {}）。
func trigger_random(category: String = "") -> Dictionary:
	var e := pick_event(category)
	if e.is_empty():
		return {}
	trigger(e)
	return e


## 结算某个选项：应用效果、写入记忆、记录决议。
func resolve(event: Dictionary, choice_index: int) -> Dictionary:
	var choices = event.get("choices", [])
	if not (choices is Array) or choice_index < 0 or choice_index >= choices.size():
		return {"ok": false, "outcome": "", "applied": 0, "dropped": 0, "reason": "选项越界"}

	var ch: Dictionary = choices[choice_index]
	var res: Dictionary = _game.apply_effects(ch.get("effects", []))
	for m in res.get("memories", []):
		# 带上 kind：事件能明确区分「承诺/冲突/秘密」，
		# 这类记忆的重要度高于 AI 对话里推断出来的
		_game.add_memory(str(m["character"]), str(m["text"]), str(m.get("kind", "")))

	var id := str(event.get("id", ""))
	if not _resolved.has(id):
		_resolved[id] = []
	_resolved[id].append(choice_index)

	var outcome := str(ch.get("outcome", ""))
	event_resolved.emit(id, choice_index, outcome)
	return {
		"ok": true,
		"outcome": outcome,
		"applied": int(res["applied"]),
		"dropped": int(res["dropped"]),
		"reason": "",
	}


# ---------------------------------------------------------------------------
# 诊断与存档
# ---------------------------------------------------------------------------

func diagnostics() -> Dictionary:
	## 供 verify 脚本与调试面板查看事件库的可用性。
	var ok := eligible_events()
	var by_cat := {}
	for e in events:
		var c := str(e.get("category", "?"))
		by_cat[c] = int(by_cat.get(c, 0)) + 1
	return {
		"total": events.size(),
		"eligible_now": ok.size(),
		"fired_total": _fire_count.size(),
		"by_category": by_cat,
	}


func export_state() -> Dictionary:
	return {
		"last_fired": _last_fired.duplicate(true),
		"fire_count": _fire_count.duplicate(true),
		"resolved": _resolved.duplicate(true),
	}


func import_state(d: Dictionary) -> void:
	_last_fired = d.get("last_fired", {}).duplicate(true) if d.get("last_fired", null) != null else {}
	_fire_count = d.get("fire_count", {}).duplicate(true) if d.get("fire_count", null) != null else {}
	_resolved = d.get("resolved", {}).duplicate(true) if d.get("resolved", null) != null else {}


func reset() -> void:
	_last_fired.clear()
	_fire_count.clear()
	_resolved.clear()
