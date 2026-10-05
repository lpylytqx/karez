extends Node
## 游戏状态与 AI 通信（GDScript 主线实现）。
##
## 职责边界（严格遵守）：
##   ✅ 持有权威状态、读取 data/numbers.json、应用 AI 返回的 state_delta
##   ✅ 向 Python 服务发 HTTP 请求，失败时静默降级为离线模式
##   ❌ 不做 prompt 拼装（那是 Python 的事）
##   ❌ 不做数值平衡调整（数值只在 numbers.json 里改）

signal response_received(payload: Dictionary)
signal request_failed(reason: String)
signal state_changed()

const DEFAULT_AI_HOST := "127.0.0.1"
const DEFAULT_AI_PORT := 8787
const SCHEMA_VERSION := "1.0"

## 设为 true 则完全跳过网络请求，直接用预设内容。
## 演示时若担心网络，把它打开即可 100% 确定不冷场。
@export var offline_mode := false

## 由场景注入。存档时一并保存事件系统的触发记录，
## 否则读档后事件冷却与次数会重置 —— 违反「存档即可复现」的纪律。
var event_system: Node = null

var numbers: Dictionary = {}
var state: Dictionary = {}
var player_character := "lao_kanjiang"

var _http: HTTPRequest
var _pending_speaker := ""
var _pending_recent: Array = []
## 本次请求的玩家原话。用于 AI 漏记承诺时的本地兜底。
var _pending_input := ""
## 最近一次日结算的产出明细，供 HUD 显示「今天为什么涨/跌」。
var _last_gain: Dictionary = {}


func _ready() -> void:
	numbers = _load_numbers()
	state = _initial_state()
	_http = HTTPRequest.new()
	_http.timeout = 60.0
	add_child(_http)
	_http.request_completed.connect(_on_request_completed)


# ---------------------------------------------------------------------------
# 数值与状态
# ---------------------------------------------------------------------------

func _load_numbers() -> Dictionary:
	for path in ["res://../data/numbers.json", "res://data/numbers.json"]:
		if FileAccess.file_exists(path):
			var text := FileAccess.get_file_as_string(path)
			var parsed = JSON.parse_string(text)
			if parsed is Dictionary:
				return parsed
			push_error("numbers.json 解析失败: %s" % path)
	push_warning("未找到 numbers.json，使用内置极简数值。请确认 data/ 目录与 scripts/ 处于同一父目录。")
	return _fallback_numbers()


func _fallback_numbers() -> Dictionary:
	return {
		"karez": {"flow_per_section": 55,
			"season_melt_multiplier": {
				"spring": 1.0, "summer": 1.4, "autumn": 0.85, "winter": 0.45},
			"season_flow_bonus": {"winter": -3}},
		"population": {"daily_consumption": {"water_per_person": 3.0, "food_per_person": 3}},
		"resources": {
			"water": {"initial": {"current": 90, "capacity": 300, "flow_per_day": 5}},
			"food": {"initial": {"naan": 40, "grain": 30, "meat": 8}},
			"materials": {"initial": {"wood": 30, "earth": 50, "tools": 4}},
			"silver": {"initial": 40},
		},
	}


func _initial_state() -> Dictionary:
	var res_cfg: Dictionary = numbers.get("resources", {})
	var food_cfg: Dictionary = res_cfg.get("food", {}).get("initial", {})
	var mat_cfg: Dictionary = res_cfg.get("materials", {}).get("initial", {})
	var water_cfg: Dictionary = res_cfg.get("water", {}).get("initial", {})

	return {
		"calendar": {"day": 1, "season": "spring", "phase": "morning"},
		# flow_per_day 初始即等于旱季残流：HUD 显示的「日出水量」从第一帧就是真实值，
		# 不必等到第一次 advance_day 之后才有数。
		"karez": {"sections": 0, "flow_per_day": float(water_cfg.get("flow_per_day", 5)), "sections_days_left": 0},
		"resources": {
			"water": {
				"current": float(water_cfg.get("current", 90)),
				"capacity": float(water_cfg.get("capacity", 300)),
				# base_flow：旱季残存渗流。不是可消耗的库存，是每日入账的一部分，
				# 所以单独存字段而不是塞进 current。开局 5 方/天。
				"base_flow": float(water_cfg.get("flow_per_day", 5)),
			},
			"food": {
				"naan": float(food_cfg.get("naan", 40)),
				"grain": float(food_cfg.get("grain", 30)),
				"fruit": float(food_cfg.get("fruit", 0)),
				"meat": float(food_cfg.get("meat", 8)),
				"milk": float(food_cfg.get("milk", 0)),
			},
			"materials": {
				"wood": float(mat_cfg.get("wood", 30)),
				"earth": float(mat_cfg.get("earth", 50)),
				"cloth": float(mat_cfg.get("cloth", 5)),
				"tools": float(mat_cfg.get("tools", 4)),
			},
			"silver": float(res_cfg.get("silver", {}).get("initial", 40)),
		},
		"population": 6,
		# 岗位分配（S3 经营骨架）。每个居民每天占一个岗位，见 numbers.json 的
		# population.jobs.list。初始：3 人治水、1 采木、1 取土、1 耕作。
		"jobs": {"water": 3, "gather_wood": 1, "gather_earth": 1, "craft": 0,
			"farm": 1, "guard": 0, "idle": 0},
		"stats": {"prosperity": 5.0, "reputation": 10.0, "morale": 55.0, "security": 40.0},
		# 建筑：id -> {level, condition}。condition 从 100 递减，低于 30 功能打折。
		"buildings": {},
		# 施工队列：同一时刻只允许一项在修（单人经营的节奏约束）
		# progress 是「工时进度」的小数累积：治水人数 / 3 每天累加，
		# 每满 1.0 就扣掉一天工期。所以派的人越多，工程越快。
		"construction": {"kind": "", "target": "", "display": "",
			"days_left": 0, "total_days": 0, "progress": 0.0},
		# 行动点：每个时段重置，用于限制点击式操作（与回合制一致）
		"action_points": 2,
		"characters": {
			"lao_kanjiang": {"affinity": 0.0, "mood": 60.0, "memory": []},
			"muqam_yiren": {"affinity": 0.0, "mood": 70.0, "memory": []},
			"hasake_qishou": {"affinity": 0.0, "mood": 65.0, "memory": []},
			"hanshang_zhanggui": {"affinity": 0.0, "mood": 60.0, "memory": []},
			"chuniang": {"affinity": 0.0, "mood": 70.0, "memory": []},
			"shenmi_lvren": {"affinity": 0.0, "mood": 55.0, "memory": []},
			"mafei_toumu": {"affinity": 0.0, "mood": 60.0, "memory": []},
		},
		"flags": {},
	}


# ---------------------------------------------------------------------------
# 与 Python 服务通信
# ---------------------------------------------------------------------------

func send(player_input: String, speaker: String = "", recent: Array = []) -> bool:
	if player_input.strip_edges().is_empty():
		return false
	if _http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		request_failed.emit("上一个请求还没回来，稍等")
		return false

	_pending_speaker = speaker
	_pending_recent = recent
	_pending_input = player_input

	if offline_mode:
		request_failed.emit("offline_mode 已开启")
		return false

	var cid := speaker if speaker != "" else player_character
	var body := {
		"schema_version": SCHEMA_VERSION,
		"scene": "karez_work",
		"player_input": player_input,
		"character_id": cid,
		"context": build_context_for_ai(speaker),
		"memory": get_memory(cid),
		# 承诺单独送一份：混在记忆大列表里模型容易忽略，
		# 而「记住上次答应过什么」是 GDD 判定 AI 是否真的活了的核心。
		"promises": get_promises(cid),
		"recent": recent,
	}
	var url := "http://%s:%d/narrate" % [_ai_host(), _ai_port()]
	var err := _http.request(
		url,
		["Content-Type: application/json"],
		HTTPClient.METHOD_POST,
		JSON.stringify(body)
	)
	if err != OK:
		request_failed.emit("HTTP 请求发起失败 (err %d)" % err)
		return false
	return true


func _ai_host() -> String:
	var from_env := OS.get_environment("AI_HOST")
	return from_env if from_env != "" else DEFAULT_AI_HOST


func _ai_port() -> int:
	var from_env := OS.get_environment("AI_PORT")
	return int(from_env) if from_env != "" else DEFAULT_AI_PORT


func _on_request_completed(
	result: int, code: int, _headers: PackedStringArray, body: PackedByteArray
) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		request_failed.emit("AI 服务无响应 (result=%d, http=%d)" % [result, code])
		return

	var text := body.get_string_from_utf8()
	var parsed = JSON.parse_string(text)
	if not (parsed is Dictionary):
		request_failed.emit("AI 服务返回的不是合法 JSON")
		return

	apply_response(parsed)


## 应用 AI 返回：先改数值，再记记忆，最后广播。
func apply_response(payload: Dictionary) -> void:
	var deltas = payload.get("state_delta", [])
	if deltas is Array:
		apply_deltas(deltas)

	var speaker := _pending_speaker if _pending_speaker != "" else player_character
	var wrote := false
	for entry in payload.get("memory_append", []):
		if entry is String and entry != "":
			add_memory(speaker, entry)
			wrote = true

	# 兜底：模型漏记时由本地补。
	# 实测（ai_backend/live_test.py）deepseek-flash 在明显的承诺场景下
	# 时而返回 ["...许诺..."]、时而返回 []。而「角色记住承诺」是 S4 的核心卖点，
	# 不能托付给模型的自觉 —— 与「LLM 不做精确算术」是同一条纪律。
	if not wrote:
		_promise_fallback(speaker)

	clamp_all()
	response_received.emit(payload)
	state_changed.emit()


## 玩家原话里含明确承诺时，本地记一条。已有同样内容则不重复记。
func _promise_fallback(speaker: String) -> void:
	if _pending_input.strip_edges() == "":
		return
	if _infer_kind(_pending_input) != "promise":
		return
	var text := "玩家承诺：%s" % _pending_input
	for existing in _memory_sorted(speaker):
		if str(existing["text"]) == text:
			return
	add_memory(speaker, text, "promise")


# ---------------------------------------------------------------------------
# state_delta 应用（白名单 + 幅度夹紧，与 Python 侧同规则）
# ---------------------------------------------------------------------------

const MAX_DELTA := 25.0
const ALLOWED_PREFIXES := [
	"resources.silver", "resources.food.", "resources.materials.",
	"resources.water.current", "stats.reputation", "stats.morale",
	"stats.security", "characters.",
]


func apply_deltas(deltas: Array) -> int:
	## 返回成功应用的条数。不合规的静默丢弃并打日志。
	var applied := 0
	for d in deltas:
		if not (d is Dictionary):
			continue
		var op: String = str(d.get("op", ""))
		var path: String = str(d.get("path", ""))
		var raw = d.get("value", null)

		if op not in ["add", "sub", "set", "mul"]:
			push_warning("丢弃 delta：非法 op %s" % op)
			continue
		if not _path_allowed(path):
			push_warning("丢弃 delta：路径不在白名单 %s" % path)
			continue
		if not (raw is float or raw is int) or raw is bool:
			push_warning("丢弃 delta：value 非数值 %s" % str(raw))
			continue

		var value := clampf(float(raw), -MAX_DELTA, MAX_DELTA)
		if not _set_path(path, op, value):
			push_warning("丢弃 delta：写入失败 %s" % path)
			continue
		applied += 1
	return applied


func _path_allowed(path: String) -> bool:
	for prefix in ALLOWED_PREFIXES:
		if path.begins_with(prefix):
			return true
	return false


func _set_path(path: String, op: String, value: float) -> bool:
	var parts := path.split(".")
	if parts.size() < 2:
		return false

	# 特殊处理：characters.<id>.affinity / .mood
	if parts[0] == "characters":
		if parts.size() != 3:
			return false
		var cid := parts[1]
		var field := parts[2]
		if not state["characters"].has(cid):
			state["characters"][cid] = {"affinity": 0.0, "mood": 60.0, "memory": []}
		var entry: Dictionary = state["characters"][cid]
		var cur := float(entry.get(field, 0.0))
		entry[field] = _apply_op(cur, op, value)
		return true

	# 通用路径
	var cursor: Dictionary = state
	for i in range(parts.size() - 1):
		var key: String = parts[i]
		if not cursor.has(key) or not (cursor[key] is Dictionary):
			cursor[key] = {}
		cursor = cursor[key]

	var leaf: String = parts[parts.size() - 1]
	var current := float(cursor.get(leaf, 0.0))
	cursor[leaf] = _apply_op(current, op, value)
	return true


func _apply_op(current: float, op: String, value: float) -> float:
	match op:
		"add": return current + value
		"sub": return current - value
		"mul": return current * value
		"set": return value
	return current


# ---------------------------------------------------------------------------
# 事件效果应用 —— 与 AI 的 state_delta 刻意分开
# ---------------------------------------------------------------------------
#
# 两条路必须分开，原因不同：
#   • AI 的 state_delta 不可信 → 路径白名单极窄、只允许数值、一律夹紧
#   • 事件效果   是我们自己写的可信内容 → 需要 karez./flags./buildings. 等路径，
#     且 flags 是布尔赋值，套 AI 那套校验会被全部丢弃
#
# 但数值仍然夹紧 —— 手写 64 条事件时，把 50 写成 500 是很容易发生的事。

const EVENT_ALLOWED_PREFIXES := [
	"resources.", "stats.", "karez.", "flags.", "buildings.",
	"characters.", "calendar.", "population",
]


## 应用事件效果。返回 {applied, dropped, memories}
func apply_effects(effects: Array) -> Dictionary:
	var applied := 0
	var dropped := 0
	var memories: Array = []

	for e in effects:
		if not (e is Dictionary):
			dropped += 1
			continue

		# memory 副作用：不碰数值，只往角色记忆里追加一条
		if e.has("memory"):
			var m = e["memory"]
			if m is Dictionary and str(m.get("character", "")) != "":
				memories.append({
					"character": str(m["character"]),
					"text": str(m.get("text", "")),
					"kind": str(m.get("kind", "")),
				})
				applied += 1
			else:
				dropped += 1
			continue

		var op := str(e.get("op", ""))
		var path := str(e.get("path", ""))
		var raw = e.get("value", null)

		if not _event_path_allowed(path):
			push_warning("事件效果丢弃：路径越界 %s" % path)
			dropped += 1
			continue

		# flags.* —— 只支持 set，值是布尔
		if path.begins_with("flags."):
			if op == "set":
				set_flag(path.substr(6), bool(raw))
				applied += 1
			else:
				push_warning("事件效果丢弃：flags 仅支持 set（%s %s）" % [op, path])
				dropped += 1
			continue

		# buildings.<id> —— set true 即建成
		if path.begins_with("buildings."):
			if op == "set" and bool(raw):
				state["buildings"][path.substr(10)] = {"level": 1, "condition": 100.0}
				applied += 1
			else:
				dropped += 1
			continue

		if op not in ["add", "sub", "set", "mul"] or not (raw is float or raw is int) or raw is bool:
			push_warning("事件效果丢弃：非法 op/value（%s %s %s）" % [op, path, str(raw)])
			dropped += 1
			continue

		var value := clampf(float(raw), -MAX_DELTA, MAX_DELTA)
		if _set_path(path, op, value):
			applied += 1
		else:
			dropped += 1

	clamp_all()
	state_changed.emit()
	return {"applied": applied, "dropped": dropped, "memories": memories}


func _event_path_allowed(path: String) -> bool:
	for prefix in EVENT_ALLOWED_PREFIXES:
		if path.begins_with(prefix):
			return true
	return path == "day"


## 客户端侧夹紧 —— 契约要求的第二道闸门。
func clamp_all() -> void:
	var water: Dictionary = state["resources"]["water"]
	water["current"] = clampf(float(water.get("current", 0.0)), 0.0, float(water.get("capacity", 300.0)))
	state["resources"]["silver"] = maxf(0.0, float(state["resources"]["silver"]))
	for key in ["prosperity", "reputation", "morale", "security"]:
		state["stats"][key] = clampf(float(state["stats"][key]), 0.0, 100.0)
	for cid in state["characters"]:
		var c: Dictionary = state["characters"][cid]
		c["affinity"] = clampf(float(c.get("affinity", 0.0)), -100.0, 100.0)
		c["mood"] = clampf(float(c.get("mood", 60.0)), 0.0, 100.0)
	state["population"] = maxi(0, int(state["population"]))
	for kind in ["food", "materials"]:
		for item in state["resources"][kind]:
			state["resources"][kind][item] = maxf(0.0, float(state["resources"][kind][item]))


# ---------------------------------------------------------------------------
# 记忆
# ---------------------------------------------------------------------------
#
# 存储格式（结构化，便于按重要度召回）：
#   {"day": int, "text": String, "kind": String, "imp": int}
# 兼容旧存档里的纯字符串条目（当作 imp=1）。
#
# 重要度来源有两处：
#   • 事件系统可显式给 kind（promise / conflict / secret ...）
#   • AI 的 memory_append 按 output_contract 是「字符串数组」，没有 kind 字段，
#     所以这里用关键词兜底识别「承诺」—— 这正是 GDD 里
#     「关掉 AI 这三人会明显死掉」那条判据最需要的行为。

const MEM_IMP := {
	"promise": 3, "bond": 3,
	"conflict": 2, "secret": 2, "discovery": 2, "favor": 2,
}

const MEM_KIND_CN := {
	"promise": "承诺", "bond": "羁绊", "conflict": "冲突",
	"secret": "秘密", "discovery": "发现", "favor": "人情",
}

const PROMISE_CUES := ["答应", "承诺", "说好", "保证", "发誓", "一言为定", "许下", "立下"]
const CONFLICT_CUES := ["翻脸", "争吵", "冲突", "得罪", "结怨"]
const SECRET_CUES := ["秘密", "别告诉", "不要外传", "只跟你说", "别声张"]

## AI 返回的记忆是纯字符串，没有 kind，用关键词推断重要度。
func _infer_kind(text: String) -> String:
	for c in PROMISE_CUES:
		if text.contains(c):
			return "promise"
	for c in CONFLICT_CUES:
		if text.contains(c):
			return "conflict"
	for c in SECRET_CUES:
		if text.contains(c):
			return "secret"
	return ""


func _norm_memory(e) -> Dictionary:
	if e is Dictionary:
		var k := str(e.get("kind", ""))
		return {
			"day": int(e.get("day", 0)),
			"text": str(e.get("text", "")),
			"kind": k,
			"imp": int(e.get("imp", MEM_IMP.get(k, 1))),
		}
	return {"day": 0, "text": str(e), "kind": "", "imp": 1}


## 按「重要度降序，其次时间降序」排。
## prompt 里写的是「按重要程度排序」，而早先的实现给的是插入顺序 —— 标签是假的。
func _memory_sorted(cid: String) -> Array:
	var c: Dictionary = state["characters"].get(cid, {})
	var out: Array = []
	for e in c.get("memory", []):
		out.append(_norm_memory(e))
	out.sort_custom(func(a, b):
		if int(a["imp"]) != int(b["imp"]):
			return int(a["imp"]) > int(b["imp"])
		return int(a["day"]) > int(b["day"])
	)
	return out


## 给 AI 的记忆文本（已按重要度排序），上限与 prompt 的接收能力一致。
func get_memory(cid: String) -> Array:
	var out: Array = []
	for e in _memory_sorted(cid).slice(0, 13):
		var k := str(e["kind"])
		var tag := ("【%s】" % MEM_KIND_CN[k]) if MEM_KIND_CN.has(k) else ""
		out.append("[第%d天]%s%s" % [int(e["day"]), tag, str(e["text"])])
	return out


## 只取「承诺」类记忆。单独成块喂给模型，比混在大列表里更容易被遵守。
func get_promises(cid: String) -> Array:
	var out: Array = []
	for e in _memory_sorted(cid):
		if str(e["kind"]) == "promise":
			out.append("[第%d天] %s" % [int(e["day"]), str(e["text"])])
	return out.slice(0, 5)


func add_memory(cid: String, text: String, kind: String = "") -> void:
	if text.strip_edges() == "":
		return
	if not state["characters"].has(cid):
		state["characters"][cid] = {"affinity": 0.0, "mood": 60.0, "memory": []}
	var mem: Array = state["characters"][cid].get("memory", [])
	var k := kind if kind != "" else _infer_kind(text)
	mem.append({
		"day": get_day(),
		"text": text,
		"kind": k,
		"imp": int(MEM_IMP.get(k, 1)),
	})
	# 上限 200 条。超出时丢「最不重要且最旧」的，而不是单纯丢最旧的 ——
	# 否则一条珍贵承诺会被后面几十条闲聊挤掉。
	while mem.size() > 200:
		_cull_memory(mem)
	state["characters"][cid]["memory"] = mem


func _cull_memory(mem: Array) -> void:
	var worst := 0
	var worst_imp := 999
	var worst_day := 999999
	for i in range(mem.size()):
		var e := _norm_memory(mem[i])
		var imp := int(e["imp"])
		var day := int(e["day"])
		if imp < worst_imp or (imp == worst_imp and day < worst_day):
			worst = i
			worst_imp = imp
			worst_day = day
	mem.remove_at(worst)


# ---------------------------------------------------------------------------
# 岗位分配（S3 经营骨架）
# ---------------------------------------------------------------------------
#
# 设计来源：numbers.json 的 population.jobs.list。每个居民每天占一个岗位，
# 「安排谁去干什么」就是这个游戏的主要决策。
#
# 第一版漏掉了这一层，结果玩家挖完第一段竖井就卡死 —— 第 2 段缺土，
# 而木/土/工具**没有任何产出途径**。数值算得明明白白：初始材料只够挖 1 段。
# 现在补上：采集给材料、耕作给粮、治水推进工程。

const JOB_IDS := ["water", "gather_wood", "gather_earth", "craft", "farm", "guard", "idle"]

const JOB_CN := {
	"water": "治水", "gather_wood": "采木", "gather_earth": "取土",
	"craft": "做工", "farm": "耕作", "guard": "守卫", "idle": "待命",
}


func job_count(id: String) -> int:
	return maxi(0, int(state.get("jobs", {}).get(id, 0)))


func total_assigned() -> int:
	var n := 0
	for j in JOB_IDS:
		n += job_count(j)
	return n


## 还没分配的人。允许为负（人口减少时），调用方据此提示玩家重排。
func unassigned() -> int:
	return int(state.get("population", 0)) - total_assigned()


## 调整某岗位人数。加人时优先消耗「待命」名额，其次才是完全没分配的人。
func assign_job(id: String, delta: int) -> bool:
	if not JOB_IDS.has(id):
		return false
	var jobs: Dictionary = state["jobs"]
	var want := job_count(id) + delta
	if want < 0:
		return false

	if delta > 0:
		var from_idle := mini(delta, job_count("idle"))
		if from_idle > 0:
			jobs["idle"] = job_count("idle") - from_idle
		var rest := delta - from_idle
		if rest > 0 and unassigned() < rest:
			# 名额不够，把刚扣掉的待命还回去，保持状态一致
			jobs["idle"] = job_count("idle") + from_idle
			return false

	jobs[id] = want
	state_changed.emit()
	return true


## 人口变动后把分配数夹到合法范围（优先削减待命以外的新增）。
func normalize_jobs() -> void:
	if not state.has("jobs"):
		state["jobs"] = {}
	var jobs: Dictionary = state["jobs"]
	for j in JOB_IDS:
		if not jobs.has(j):
			jobs[j] = 0
	# 超员就从「待命 → 守卫 → 耕作 → 取土 → 采木 → 治水」的顺序往回削，
	# 保留治水 —— 那是玩家的主线，不该被自动化悄悄砍掉
	while total_assigned() > int(state.get("population", 0)):
		var trimmed := false
		for j in ["idle", "guard", "farm", "gather_earth", "gather_wood"]:
			if job_count(j) > 0:
				jobs[j] = job_count(j) - 1
				trimmed = true
				break
		if not trimmed and job_count("water") > 0:
			jobs["water"] = job_count("water") - 1
		elif not trimmed:
			break


## 农田块数：随坎儿井段数增长 —— 水决定能种多少地，这是核心正循环。
func farmland_plots() -> int:
	var cfg: Dictionary = numbers.get("agriculture", {}).get("farmland", {})
	var per := int(cfg.get("plots_per_karez_section", 4))
	var cap_p := int(cfg.get("max_plots", 24))
	return clampi(int(state["karez"].get("sections", 0)) * per, 0, cap_p)


## 每块田每日产粮。取 agriculture.crops.wheat 的 产量/生长天数 摊到每天 ——
## 这样「一季熟一次」的设定与「每天入账一点」的玩法能对上，不另发明数值。
func food_per_plot() -> float:
	var w: Dictionary = numbers.get("agriculture", {}).get("crops", {}).get("wheat", {})
	var y := float(w.get("yield_per_plot", 35))
	var d := maxf(1.0, float(w.get("grow_days", 22)))
	return y / d


## 每日岗位结算。返回本日产出明细，供 UI 显示「今天为什么涨/跌」。
func _settle_jobs() -> Dictionary:
	normalize_jobs()
	var gain := {"wood": 0.0, "earth": 0.0, "tools": 0.0, "food": 0.0, "silver": 0.0}
	var mat: Dictionary = state["resources"]["materials"]

	var gcfg: Dictionary = numbers.get("resources", {}).get("materials", {}).get("gathering", {})
	gain["wood"] = float(gcfg.get("wood_per_labor_day", 8)) * float(job_count("gather_wood"))
	gain["earth"] = float(gcfg.get("earth_per_labor_day", 12)) * float(job_count("gather_earth"))
	mat["wood"] = float(mat.get("wood", 0.0)) + gain["wood"]
	mat["earth"] = float(mat.get("earth", 0.0)) + gain["earth"]

	# 采集的人顺带带回食物（绿洲边采野果、打猎）。
	# 初始 78 存粮只够 4.3 天，而达到粮食自给要挖到 2 段竖井 ——
	# 没有这个补充，玩家会在自给之前先饿死（60 天自动模拟确认过）。
	var gatherers := job_count("gather_wood") + job_count("gather_earth")
	gain["food"] = float(gcfg.get("food_per_labor_day", 0)) * float(gatherers)

	# 耕作：一名农夫可管 plots_per_farmer 块田。
	# ⚠ 第一版写「每块田需 1 名农夫」，配上 wheat 的 1.59 粮/田/天，
	# 就等于一个农夫连自己都养不活（人吃 3/天）—— 任何玩法都必然饿死。
	# 60 天自动模拟里就是粮一直 0、人口从 6 掉到 2。现实里一个农夫能种好几亩地。
	var per_farmer := int(numbers.get("agriculture", {}).get("farmland", {})
		.get("plots_per_farmer", 4))
	var worked := mini(farmland_plots(), job_count("farm") * per_farmer)
	gain["food"] += float(worked) * food_per_plot()
	if gain["food"] > 0.0:
		state["resources"]["food"]["grain"] = \
			float(state["resources"]["food"].get("grain", 0.0)) + gain["food"]

	# 做工：产工具。六段竖井的工具门槛是 0/1/2/3/4/6，
	# 而 gather 只产木与土 —— 没有这个岗位，工具会永远停在开局那 4 把，
	# 玩家第 6 段永远挖不动（模拟测试里就是这么卡住的）。
	var crafters := job_count("craft")
	gain["tools"] = float(crafters)
	if gain["tools"] > 0.0:
		mat["tools"] = float(mat.get("tools", 0.0)) + gain["tools"]

	# 守卫：security +5/人，上限 60（numbers.json population.jobs.list 的说明）
	if job_count("guard") > 0:
		state["stats"]["security"] = minf(60.0,
			float(state["stats"]["security"]) + 5.0 * float(job_count("guard")))

	# 待命：恢复士气
	if job_count("idle") > 0:
		state["stats"]["morale"] = minf(100.0,
			float(state["stats"]["morale"]) + 0.5 * float(job_count("idle")))

	# 银两：已建成的建筑按 income_per_guest_day 产生收入
	for bid in state.get("buildings", {}):
		var b := _building_cfg(str(bid))
		gain["silver"] += float(b.get("income_per_guest_day", 0.0))
	if gain["silver"] > 0.0:
		state["resources"]["silver"] = \
			float(state["resources"]["silver"]) + gain["silver"]

	return gain


# ---------------------------------------------------------------------------
# 给 AI 的状态摘要（不是整包状态 —— 省 token 且防模型乱改）
# ---------------------------------------------------------------------------

func build_context_for_ai(speaker: String = "") -> Dictionary:
	var ctx := {
		"day": get_day(),
		"season": state["calendar"]["season"],
		"resources": {
			"water": state["resources"]["water"]["current"],
			"water_capacity": state["resources"]["water"]["capacity"],
			"silver": state["resources"]["silver"],
			"food": state["resources"]["food"],
		},
		"karez": {
			"sections": state["karez"]["sections"],
			"flow_per_day": state["karez"]["flow_per_day"],
		},
		"population": state["population"],
		"stats": state["stats"],
	}
	if speaker != "" and state["characters"].has(speaker):
		ctx["speaker_affinity"] = state["characters"][speaker]["affinity"]
	return ctx


# ---------------------------------------------------------------------------
# 时间推进与每日结算（S2 阶段会大幅扩充）
# ---------------------------------------------------------------------------

func get_day() -> int:
	return int(state["calendar"]["day"])


## 推进一天：出水量入账、消耗扣除、施工推进、季节轮转。
## 返回完工提示（无则空串），供 UI 弹提示用。
func advance_day() -> String:
	# 顺序有讲究：
	#   1. 岗位产出（采集/耕作/守卫/待命）—— 先干活才有材料
	#   2. 施工推进 —— 完工会让 sections 加一，而 sections 直接决定当天出水量
	#   3. 水入账 / 扣粮 / 人口变动
	_last_gain = _settle_jobs()
	var finished := _tick_construction()

	var karez_cfg: Dictionary = numbers.get("karez", {})
	var sections := int(state["karez"]["sections"])
	var melt: Dictionary = karez_cfg.get("season_melt_multiplier", {})
	var season: String = state["calendar"]["season"]
	# 融水倍率作用于「竖井出水 + 旱季残流」，另外再加减季节性的基础渗流修正。
	var base_flow := float(state["resources"]["water"].get("base_flow", 0.0))
	var bonus_cfg: Dictionary = karez_cfg.get("season_flow_bonus", {})
	var season_bonus := float(bonus_cfg.get(season, 0.0)) if season in bonus_cfg else 0.0
	var flow := (sections * float(karez_cfg.get("flow_per_section", 55)) + base_flow) \
		* float(melt.get(season, 1.0)) + season_bonus

	var pop_cfg: Dictionary = numbers.get("population", {}).get("daily_consumption", {})
	var pop := int(state["population"])
	var water_need := pop * float(pop_cfg.get("water_per_person", 3.0))
	var food_need := pop * float(pop_cfg.get("food_per_person", 3))

	state["karez"]["flow_per_day"] = flow
	var water: Dictionary = state["resources"]["water"]
	water["current"] = clampf(float(water["current"]) + flow - water_need, 0.0, float(water["capacity"]))

	_consume_food(int(food_need))

	# 缺水惩罚（对应 numbers.json 的 shortage_effect）
	if float(water["current"]) <= 0.0:
		state["stats"]["morale"] = maxf(0.0, float(state["stats"]["morale"]) - 3.0)

	state["calendar"]["day"] = get_day() + 1
	# 新的一天从早晨开始，行动点回到每时段的上限。
	# 此前只有 advance_phase 会重置行动点，直接调 advance_day 就会把 AP 耗尽
	# 且永远不恢复 —— 模拟测试里表现成「材料堆成山却再也挖不动」。
	state["action_points"] = int(numbers.get("calendar", {}).get("action_points_per_phase", 2))
	_roll_season()
	_roll_population()
	clamp_all()
	state_changed.emit()
	return finished


## 人口增减。规则取自 numbers.json 的 population.growth。
func _roll_population() -> void:
	var cfg: Dictionary = numbers.get("population", {})
	var food_days := food_days_left()
	var morale := float(state["stats"]["morale"])
	var pop := int(state["population"])
	var cap := population_capacity()
	if food_days >= 5.0 and morale >= 55.0 and pop < cap:
		if randf() < 0.12:
			state["population"] = pop + 1
			normalize_jobs()
	elif food_days < 2.0 or morale < 30.0:
		if randf() < 0.08 and pop > 1:
			state["population"] = pop - 1
			normalize_jobs()


## 现有存粮还能吃几天。人口增减的判据之一。
func food_days_left() -> float:
	var total := 0.0
	for k in state["resources"]["food"]:
		total += float(state["resources"]["food"][k])
	var per := int(numbers.get("population", {}).get("daily_consumption", {})
		.get("food_per_person", 3)) * int(state["population"])
	return total / maxf(1.0, float(per))


## 人口上限。numbers.json: min(reservoir_capacity / 30, irrigated_plots * 3, housing_capacity)。
## 下限取开局人口，免得公式在「还没开田」时把容量算成 0。
func population_capacity() -> int:
	var water_cap := float(state["resources"]["water"].get("capacity", 300))
	var by_water := int(water_cap / 30.0)
	var by_farm := farmland_plots() * 3
	var cap := mini(by_water, by_farm)
	var housing := 0
	for b in numbers.get("buildings", {}).get("list", []):
		if state.get("buildings", {}).has(str(b.get("id", ""))):
			housing += int(b.get("effect", {}).get("lodging_capacity", 0))
	if housing > 0:
		cap = mini(cap, housing)
	var floor_pop := int(numbers.get("population", {}).get("initial", 6))
	return maxi(floor_pop, cap)


func _consume_food(amount: int) -> void:
	var food: Dictionary = state["resources"]["food"]
	var order := ["naan", "grain", "fruit", "meat", "milk"]
	var remaining := amount
	for key in order:
		if remaining <= 0:
			break
		var have := int(food.get(key, 0.0))
		var take: int = mini(have, remaining)
		food[key] = float(have - take)
		remaining -= take
	if remaining > 0:
		# 断粮：士气大跌
		state["stats"]["morale"] = maxf(0.0, float(state["stats"]["morale"]) - 5.0)


func _roll_season() -> void:
	var days_per_season := 0
	var cal: Dictionary = numbers.get("calendar", {})
	days_per_season = int(cal.get("days_per_season", 30))
	if days_per_season <= 0:
		return
	var idx := (get_day() - 1) / days_per_season
	var seasons: Array = cal.get("seasons", ["spring", "summer", "autumn", "winter"])
	state["calendar"]["season"] = seasons[int(idx) % seasons.size()]


# ---------------------------------------------------------------------------
# 通用取值 / 旗标 —— 供事件条件 DSL 与 UI 共用
# ---------------------------------------------------------------------------

func query(path: String):
	## 按点路径取值。找不到返回 null（DSL 侧会当作不满足）。
	## 特殊映射：schema 里写的 resources.water.flow_per_day 在状态里实际存于 karez.flow_per_day。
	match path:
		"day": return get_day()
		"season": return str(state["calendar"].get("season", "spring"))
		"phase": return str(state["calendar"].get("phase", "morning"))
		"population": return int(state["population"])
		"resources.water.flow_per_day": return float(state["karez"].get("flow_per_day", 0.0))
		"resources.water.current": return float(state["resources"]["water"].get("current", 0.0))

	if path.begins_with("flags."):
		return bool(state.get("flags", {}).get(path.substr(6), false))
	if path.begins_with("buildings."):
		return state.get("buildings", {}).has(path.substr(10))

	var parts := path.split(".")
	if parts.size() == 3 and parts[0] == "characters":
		var c: Dictionary = state["characters"].get(parts[1], {})
		return c.get(parts[2], 0.0)

	var cursor = state
	for p in parts:
		if cursor is Dictionary and cursor.has(p):
			cursor = cursor[p]
		else:
			return null
	return cursor


func has_flag(flag: String) -> bool:
	return bool(state.get("flags", {}).get(flag, false))


func set_flag(flag: String, value: bool = true) -> void:
	state["flags"][flag] = value
	state_changed.emit()


func action_points() -> int:
	return int(state.get("action_points", 0))


## 最近一次日结算的产出明细（木/土/粮/银），供 HUD 解释「今天为什么涨」。
func last_gain() -> Dictionary:
	return _last_gain


func spend_action_point(n: int = 1) -> bool:
	## 行动点不足返回 false，调用方据此拒绝操作。
	if action_points() < n:
		return false
	state["action_points"] = action_points() - n
	state_changed.emit()
	return true


## 由坎儿井段数决定的绿洲繁荣度 0~6，供地图渲染与 AI 上下文共用。
func oasis_level() -> int:
	return clampi(int(state["karez"].get("sections", 0)), 0, 6)


# ---------------------------------------------------------------------------
# 坎儿井：挖掘
# ---------------------------------------------------------------------------

func _section_cfg(index: int) -> Dictionary:
	## index 从 1 开始。越界返回 {}。
	for s in numbers.get("karez", {}).get("sections", []):
		if int(s.get("index", -1)) == index:
			return s
	return {}


func construction_idle() -> bool:
	return str(state["construction"].get("kind", "")) == ""


func next_section_index() -> int:
	return int(state["karez"].get("sections", 0)) + 1


func dig_info() -> Dictionary:
	## 下一段竖井的可行性与成本，UI 直接用它渲染按钮提示。
	var idx := next_section_index()
	var max_sections := int(numbers.get("karez", {}).get("max_sections", 6))
	var cfg := _section_cfg(idx)
	if cfg.is_empty() or idx > max_sections:
		return {"ok": false, "reason": "已挖到源段，无法再深", "index": idx,
			"display": "", "materials": {}, "days": 0, "requires_tools": 0}

	var mats: Dictionary = cfg.get("materials", {})
	var res_mats: Dictionary = state["resources"]["materials"]
	var lack: Array = []
	for k in mats:
		var have := float(res_mats.get(k, 0.0))
		if have < float(mats[k]):
			lack.append("%s差%d" % [_mat_cn(k), int(float(mats[k]) - have)])
	var need_tools := int(cfg.get("requires_tools", 0))
	var have_tools := int(float(res_mats.get("tools", 0.0)))
	if have_tools < need_tools:
		lack.append("工具差%d" % (need_tools - have_tools))

	# 这段文本会被塞进 HUD 右侧 96px 宽的标签里。超过两行就会压住它下面的按钮
	# （实机截图确认过：「第一段竖井（井口段）」折成三行、盖住了「建造」）。
	# 所以刻意写短：完整段名放顶栏的「建设:」那一格，这里只留状态与数字。
	var reason := ""
	if not construction_idle():
		reason = "施工中 剩%d天" % int(state["construction"].get("days_left", 0))
	elif not lack.is_empty():
		reason = "缺 " + " ".join(lack)

	return {
		"ok": reason == "",
		"reason": reason,
		"index": idx,
		"display": str(cfg.get("display", "")),
		"materials": mats,
		"days": int(cfg.get("days", 1)),
		"labor": int(cfg.get("labor", 0)),
		"requires_tools": need_tools,
	}


func start_dig() -> Dictionary:
	var info := dig_info()
	if not bool(info["ok"]):
		return {"ok": false, "reason": str(info["reason"])}
	if not spend_action_point(1):
		return {"ok": false, "reason": "行动点不足（每个时段 2 点）"}

	var idx: int = int(info["index"])
	var cfg := _section_cfg(idx)
	for k in cfg.get("materials", {}):
		state["resources"]["materials"][k] = maxf(
			0.0, float(state["resources"]["materials"].get(k, 0.0)) - float(cfg["materials"][k]))

	state["construction"] = {
		"kind": "karez_section",
		"target": str(idx),
		"display": str(cfg.get("display", "竖井")),
		"days_left": int(cfg.get("days", 1)),
		"total_days": int(cfg.get("days", 1)),
		"progress": 0.0,
	}
	clamp_all()
	state_changed.emit()
	return {"ok": true, "reason": "", "display": str(cfg.get("display", "")), "days": int(cfg.get("days", 1))}


# ---------------------------------------------------------------------------
# 建筑：建造
# ---------------------------------------------------------------------------

func _building_cfg(id: String) -> Dictionary:
	for b in numbers.get("buildings", {}).get("list", []):
		if str(b.get("id", "")) == id:
			return b
	return {}


func build_info(id: String) -> Dictionary:
	var cfg := _building_cfg(id)
	if cfg.is_empty():
		return {"ok": false, "reason": "未知建筑", "id": id, "display": ""}

	var mats: Dictionary = cfg.get("materials", {})
	var res_mats: Dictionary = state["resources"]["materials"]
	var lack: Array = []
	for k in mats:
		if float(res_mats.get(k, 0.0)) < float(mats[k]):
			lack.append("%s 需%d/有%d" % [_mat_cn(k), int(mats[k]), int(res_mats.get(k, 0.0))])

	var reason := ""
	if state["buildings"].has(id):
		reason = "已建成"
	elif not construction_idle():
		reason = "正在施工：%s" % str(state["construction"].get("display", ""))
	elif not lack.is_empty():
		reason = "、".join(lack)

	return {"ok": reason == "", "reason": reason, "id": id,
		"display": str(cfg.get("display", id)), "materials": mats,
		"days": int(cfg.get("days", 1)), "labor": int(cfg.get("labor", 0))}


func start_build(id: String) -> Dictionary:
	var info := build_info(id)
	if not bool(info["ok"]):
		return {"ok": false, "reason": str(info["reason"])}
	if not spend_action_point(1):
		return {"ok": false, "reason": "行动点不足"}

	var cfg := _building_cfg(id)
	for k in cfg.get("materials", {}):
		state["resources"]["materials"][k] = maxf(
			0.0, float(state["resources"]["materials"].get(k, 0.0)) - float(cfg["materials"][k]))

	state["construction"] = {
		"kind": "building",
		"target": id,
		"display": str(cfg.get("display", id)),
		"days_left": int(cfg.get("days", 1)),
		"total_days": int(cfg.get("days", 1)),
		"progress": 0.0,
	}
	clamp_all()
	state_changed.emit()
	return {"ok": true, "reason": "", "display": str(cfg.get("display", id)), "days": int(cfg.get("days", 1))}


## 施工推进一天，返回完工提示（无完工返回空串）。
##
## 速度取决于**派了多少人去治水** —— 这正是岗位分配的意义所在。
## 基准 3 人 = 每天推进 1 天工期；派 6 人就快一倍，一个人不派就完全停工。
func _tick_construction() -> String:
	if construction_idle():
		return ""
	var water := job_count("water")
	if water <= 0:
		return ""

	var c: Dictionary = state["construction"]
	c["progress"] = float(c.get("progress", 0.0)) + float(water) / 3.0
	if float(c["progress"]) < 1.0:
		return ""
	var steps := int(float(c["progress"]))
	c["progress"] = float(c["progress"]) - float(steps)
	c["days_left"] = int(c["days_left"]) - steps
	if int(c["days_left"]) > 0:
		return ""

	var kind := str(c.get("kind", ""))
	var target := str(c.get("target", ""))
	var display := str(c.get("display", ""))

	if kind == "karez_section":
		var idx := int(target)
		state["karez"]["sections"] = idx
		state["flags"]["karez_section_%d_done" % idx] = true
		if idx >= 1:
			state["flags"]["karez_first_section_done"] = true
		state["stats"]["prosperity"] = minf(100.0, float(state["stats"]["prosperity"]) + 2.0)
	elif kind == "building":
		state["buildings"][target] = {"level": 1, "condition": 100.0}
		state["stats"]["prosperity"] = minf(100.0, float(state["stats"]["prosperity"]) + 1.5)

	state["construction"] = {"kind": "", "target": "", "display": "",
		"days_left": 0, "total_days": 0, "progress": 0.0}
	return "【完工】%s 已建成" % display


# ---------------------------------------------------------------------------
# 时段推进（回合制的节奏单位）
# ---------------------------------------------------------------------------

func get_phase() -> String:
	return str(state["calendar"].get("phase", "morning"))


func advance_phase() -> Dictionary:
	## 推进一个时段；跨过 night 则结算一天。
	## 返回 {day_advanced: bool, finished: String}
	var phases: Array = numbers.get("calendar", {}).get(
		"phases_per_day", ["morning", "afternoon", "evening", "night"])
	var i := phases.find(get_phase())
	var next_i := (i + 1) % phases.size()
	state["calendar"]["phase"] = phases[next_i]
	state["action_points"] = int(numbers.get("calendar", {}).get("action_points_per_phase", 2))

	var finished := ""
	var day_advanced := false
	if next_i == 0:
		finished = advance_day()
		day_advanced = true
	state_changed.emit()
	return {"day_advanced": day_advanced, "finished": finished, "phase": str(phases[next_i])}


func _mat_cn(k: String) -> String:
	return {"wood": "木", "earth": "土", "cloth": "布", "tools": "工具"}.get(k, k)


# ---------------------------------------------------------------------------
# 存档（S3 阶段补 ai_log 以支持完整复现）
# ---------------------------------------------------------------------------

func save_to(path: String) -> bool:
	var payload := {
		"save_version": 1,
		"seed": 0,
		"state": state,
	}
	# 事件系统的触发记录一并入库，否则读档后冷却与次数会重置
	if event_system != null:
		payload["events"] = event_system.export_state()
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("存档失败：%s" % path)
		return false
	f.store_string(JSON.stringify(payload, "  "))
	f.close()
	return true


func load_from(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary) or not parsed.has("state"):
		return false
	state = parsed["state"]
	if event_system != null and parsed.has("events"):
		event_system.import_state(parsed["events"])
	clamp_all()
	state_changed.emit()
	return true
