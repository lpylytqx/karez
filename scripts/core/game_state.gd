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
	_ensure_sites()
	_http = HTTPRequest.new()
	_http.timeout = 60.0
	add_child(_http)
	_http.request_completed.connect(_on_request_completed)


# ---------------------------------------------------------------------------
# 建筑坐标（可移动）
# ---------------------------------------------------------------------------
#
# 默认值来自 core/sites.gd 的 PLACES；拖拽移动后写进 state["sites"]，
# 于是自动进存档。map_view / townfolk / villagers 三处都从这里取坐标，
# 所以**移动一座建筑，NPC 与工作地点跟着挪是自动的**，不需要各自改。

## 把 sites.gd 的默认坐标灌进 state（已有的不动，保留玩家拖过的位置）。
func _ensure_sites() -> void:
	var s: Dictionary = state.get("sites", {})
	for id in Sites.PLACES:
		if not s.has(id):
			var xy: Vector2 = Sites.PLACES[id]["xy"]
			s[id] = [xy.x, xy.y]   # 存成数组：存档走 JSON，Vector2 不友好
	state["sites"] = s


## 取某地标的当前坐标（格）。没被移动过就是 sites.gd 里的默认值。
func site_xy(id: String) -> Vector2:
	var s: Dictionary = state.get("sites", {})
	if s.has(id):
		var v = s[id]
		if v is Array and v.size() >= 2:
			return Vector2(float(v[0]), float(v[1]))
	return Sites.place_xy(id)


## 移动一座建筑。**只有 kind == "building" 的能移**（仓库/马厩/驿馆）。
## 移动后广播 state_changed，地图重画、NPC 与居民自己走过去。
func move_site(id: String, grid: Vector2) -> bool:
	if not Sites.movable_ids().has(id):
		return false
	# 夹在地图内，并且不能低于 y=17 —— 再往下就被底栏吃掉
	var g := Vector2(clampf(grid.x, 1.0, 38.0), clampf(grid.y, 1.0, 17.0))
	state["sites"][id] = [g.x, g.y]
	state_changed.emit()
	return true


## NPC 站位 = 他守着的地标 + 偏移。地标一动，他自动跟着动。
func npc_xy(cid: String) -> Vector2:
	var home := str(Sites.NPC_HOME.get(cid, ""))
	var off: Vector2 = Sites.NPC_OFFSET.get(cid, Vector2.ZERO)
	return site_xy(home) + off


## 工作地点 = 该岗位对应的地标。地标一动，工地与居民自动跟着动。
func job_xy(jid: String) -> Vector2:
	return site_xy(str(Sites.JOB_SITE.get(jid, "camp")))


# ---------------------------------------------------------------------------
# 地点与角色按需出现
# ---------------------------------------------------------------------------
#
# 为什么：一个只剩 6 口人、水够撑 7 天、粮够撑 4 天的村子，
# 不该有一个「专职掌伙食的厨娘」，也不该有驿馆、巴扎、晾房、商铺 ——
# 那些建筑预设了村子已经在正常运转。
#
# 规则只有一条：
#   地标按 sites.gd 的 gate 出现；**角色的出现条件不单独写，跟着他的地标走。**
# 所以「地点按需出现」与「人物按需出现」共用同一张表，不可能对不上。
#
# ⚠ 判断只写在这里。地图（map_view）、NPC（townfolk）、底栏「对谁说」（hud）
#    都调 place_present() / characters_present()，不许各自判断 ——
#    「两处各写一套」正是前面坐标三张表反复出错的根因。

## 界面上的固定顺序（与 data/characters.json 一致），免得下拉框顺序乱跳。
const CHAR_ORDER := ["lao_kanjiang", "muqam_yiren", "hasake_qishou",
	"hanshang_zhanggui", "chuniang", "shenmi_lvren", "mafei_toumu"]


## 某个 numbers.json 建筑是否**正在地图上起作用**。
##
## 判据是「它在地图上出现没有」，而**不是**「玩家有没有点建造」——
## 因为有些设施开局就摆在那儿（灶、仓库），有些随坎儿井进度冒出来（巴扎、作坊、晾房）。
## 统一成一句话：**地图上看得见的，就是正在起作用的。**
##
## 在此之前，numbers.json 里 19 个 effect 字段只有 3 个被读过 ——
## 也就是说地图上画着十来个设施，其中大多数是纯装饰。这个函数是接上它们的入口。
func has_facility(building_id: String) -> bool:
	for site_key in Sites.sites_of_building(building_id):
		if place_present(site_key):
			return true
	return false


## 取某个建筑的效果字段值。建筑不在场就返回默认值 —— 于是调用处可以直接写
##     facility_effect("chufang", "food_efficiency", 1.0)
## 而不必自己先判断存在性。默认值一律取「无效果」的中性值（×1、+0）。
func facility_effect(building_id: String, key: String, neutral: float) -> float:
	if not has_facility(building_id):
		return neutral
	var cfg := _building_cfg(building_id)
	if cfg.is_empty():
		return neutral
	return float(cfg.get("effect", {}).get(key, neutral))


## 储水上限。基础容量 ×（仓库的 storage_multiplier）。
##
## 仓库的 `storage_multiplier: 1.5` 此前没人读，所以容量恒为开局那 300 方 ——
## 而人口上限公式里有「容量 ÷ 30」这一项，于是人口从第 1 段起就永远卡在 10。
## 把仓库接上之后，建了仓库容量变 450，人口上限跟着抬到 15，深挖坎儿井才重新有意义。
func water_capacity() -> float:
	var base := float(state["resources"]["water"].get("base_capacity", 300.0))
	return base * facility_effect("cangku", "storage_multiplier", 1.0)


## 涝坝的水位档位 1..4（只用来挑贴图）。
##
## ⚠ 与 numbers.json 的 `karez.reservoir.levels` **不是一回事**：
##     那个是「涝坝的容量升级」（花材料挖大，450/900/1600/2600），
##     这个是「**当下**水有多少」，每天都在变。两者混用会把画面和数值搞反。
##
## 按 当前水量 ÷ 容量 四等分。水是这游戏的核心资源，
## 让它在画面上能一眼读出来（满 / 半 / 快干），比读顶栏数字直观得多。
func reservoir_level() -> int:
	var w: Dictionary = state["resources"]["water"]
	var cap := maxf(1.0, float(w.get("capacity", 300.0)))
	var ratio := clampf(float(w.get("current", 0.0)) / cap, 0.0, 1.0)
	return clampi(int(ratio * 4.0) + 1, 1, 4)


## 岗位 → 兵种 id（numbers.json 的 battle.troops.by_job）。缺省给乡勇。
##
## 兵种不是战场上凭空来的，而是**居民原本在干什么**决定的：
## 守卫→盾卫、采集→弓手、其余→乡勇，待命的人→平民。
## 于是"分工面板里怎么派人"直接决定战场上有什么兵 —— 这是兵种系统的意义所在。
func troop_of_job(job_id: String) -> String:
	var t: Dictionary = numbers.get("battle", {}).get("troops", {})
	var m: Dictionary = t.get("by_job", {})
	return str(m.get(job_id, "militia"))


## 上阵取人的**优先顺序**（不是 JOB_IDS 的顺序）。
##
## 为什么单独排一遍：名额有限（人口 − 1）时，取人顺序决定谁上场。
## 按 JOB_IDS 的顺序取会把**守卫排在最后**——守卫被截掉、盾卫上不了场，
## 而守卫本该是最先上阵的。所以：守卫 → 采集（弓手）→ 耕作 → 做工 → 治水 → 待命。
## 治水放在后面是刻意的：那是玩家的主线，不该因为打仗被抽空。
const BATTLE_DRAFT_ORDER := [
	"guard", "gather_wood", "gather_earth", "farm", "craft", "trade", "water", "idle",
]


## 这场战斗能上阵的兵种名单：按 BATTLE_DRAFT_ORDER 取人，一个人一项。
## 顺序固定，所以同一份分工每次推出的名单完全一样 —— 可复现、可写断言。
## limit 是能上阵的人数上限（一般 = 人口 − 1，留一个看家）。
func battle_roster(limit: int) -> Array:
	var out: Array = []
	for j in BATTLE_DRAFT_ORDER:
		for i in range(job_count(j)):
			if out.size() >= limit:
				return out
			out.append(troop_of_job(j))
	return out


## 这个地标此刻该不该出现在地图上。
func place_present(id: String) -> bool:
	var p: Dictionary = Sites.PLACES.get(id, {})
	if p.is_empty():
		return false
	# ── 玩家自己建成的建筑，建好就该出现在地图上 ──
	#
	# ⚠ 这一条修的是「两套状态 + 两套命名」叠加出来的死 bug：
	#     · state["buildings"]  记录**实际建成了什么**（键是 numbers.json 的 building id）
	#       —— 银两收入(_settle_jobs)、人口上限(population_capacity) 都读它
	#     · gate                决定**地图上什么时候出现**（键是 sites.gd 的 PLACES key）
	#   两者不仅互不相干，连 id 命名都不一样（majiu vs stable）。
	#   所以必须先经 Sites.building_id_of() 翻译再查，直接 has(id) 永远查不到。
	#
	# 用**或**关系（gate 满足 或 已建成），是纯增量：
	# 所有原本该出现的东西仍按原时间出现，只是「建成」也成了一个出现条件。
	var built_id := Sites.building_id_of(id)
	if built_id != "" and state.get("buildings", {}).has(built_id):
		return true
	var g: Dictionary = p.get("gate", {})
	match str(g.get("kind", "always")):
		"sections":
			return int(state.get("karez", {}).get("sections", 0)) >= int(g.get("n", 0))
		"threat":
			return float(state.get("stats", {}).get("security", 60.0)) < 40.0 \
				or get_day() >= 12
		_:
			return true


## 当前该出现在世界里的角色。跟着各自守着的地标走。
func characters_present() -> Array:
	var out: Array = []
	for cid in CHAR_ORDER:
		if place_present(str(Sites.NPC_HOME.get(cid, ""))):
			out.append(cid)
	return out


## 某个角色此刻在不在场 —— 也是一处判断，别在别处再写一遍条件。
func character_present(cid: String) -> bool:
	return characters_present().has(cid)


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
			"water": {"initial": {"current": 90, "capacity": 300, "base_capacity": 300,
				"flow_per_day": 5}},
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
		"karez": {"sections": 0, "flow_per_day": float(water_cfg.get("flow_per_day", 5)),
			"sections_days_left": 0, "reservoir_level": 0},
		"resources": {
			"water": {
				"current": float(water_cfg.get("current", 90)),
				"capacity": float(water_cfg.get("capacity", 300)),
				# base_capacity：**没有仓库时的**储水上限。
				# capacity 由 clamp_all() 从它派生（×仓库的 storage_multiplier），
				# 所以这里两个都存：base 是常量，capacity 是算出来的结果。
				"base_capacity": float(water_cfg.get("capacity", 300)),
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
		# population.jobs.list。
		# 默认给 2 人耕作 —— 1 个农夫只能养活 2 个人，配上 6 人口就是必死的开局。
		# 初始分配不该是个陷阱：玩家可以自己调，但起点必须是能活的。
		"jobs": {"water": 2, "gather_wood": 1, "gather_earth": 1, "craft": 0,
			"farm": 2, "herd": 0, "guard": 0, "idle": 0},
		# 畜牧：存栏、繁殖计时、外出抓野畜的次数、最近损失
		"livestock": {"sheep": 0, "goat": 0, "camel": 0, "donkey": 0, "chicken": 0},
		"livestock_days": {},
		"livestock_log": [],
		"wild_trips": 0,
		# 木卡姆：办过一场之后要歇几天（防止反复刷士气）
		"music_cooldown": 0,
		# 灾难：正在发作的是什么、还剩几天、冷却、最近日志
		"disaster": {"active": "", "days_left": 0, "last_id": "",
			"cooldown": 0, "log": "", "history": []},
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
	# 储水上限先由 base_capacity ×（仓库扩容）算出来，再拿它夹 current。
	# ⚠ 顺序不能反：先夹再算的话，仓库一建成立刻用旧上限夹一次，
	#   多出来的水会在那一帧被砍掉。
	water["capacity"] = water_capacity()
	water["current"] = clampf(float(water.get("current", 0.0)), 0.0, float(water["capacity"]))
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

const JOB_IDS := ["water", "gather_wood", "gather_earth", "craft", "farm", "herd", "guard", "idle"]

const JOB_CN := {
	"water": "治水", "gather_wood": "采木", "gather_earth": "取土",
	"craft": "做工", "farm": "耕作", "herd": "放牧", "guard": "守卫", "idle": "待命",
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
		for j in ["idle", "guard", "herd", "farm", "gather_earth", "gather_wood"]:
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

	# ── 已建成的设施：把 numbers.json 的 effect 字段接上 ──
	#
	# 统一判据 has_facility()：「**地图上看得见的，就是正在起作用的**」。
	# 在此之前那 19 个 effect 字段只有 3 个被读过 —— 地图上画着十来个纯装饰的设施，
	# 玩家花了材料、看着它们在那儿，却什么也不发生。
	#
	# 数值一律取得小：设施是辅助，主线仍然是岗位分工。每个字段的解释都写在下面，
	# 有推断成分的（巴扎抽成、晾房的等效实现）明确标出来，方便日后推翻。
	var pop := int(state["population"])

	# 马厩（trade_range / livestock_capacity）→ 商队换乘费 + 马队巡逻
	if has_facility("majiu"):
		gain["silver"] += 2.0
		state["resources"]["silver"] = float(state["resources"]["silver"]) + 2.0
		state["stats"]["security"] = minf(60.0, float(state["stats"]["security"]) + 5.0)

	# 巴扎（trade_commission_rate）→ 集市抽成
	# 解释：每人每天在集市经手 3 两的交易，按抽成率入账（6 人时约 1.4 两/天）。
	# ⚠ 「3 两」是推断值，不是原数据里有的 —— 要调就改这一个数。
	var commission := facility_effect("bazha", "trade_commission_rate", 0.0)
	if commission > 0.0:
		var cut := float(maxi(1, pop)) * 3.0 * commission
		gain["silver"] += cut
		state["resources"]["silver"] = float(state["resources"]["silver"]) + cut

	# 烽燧（security）→ 看见敌情就能提前报信，直接给治安
	var tower_sec := facility_effect("fengsui", "security", 0.0)
	if tower_sec > 0.0:
		state["stats"]["security"] = minf(60.0,
			float(state["stats"]["security"]) + tower_sec)

	# 作坊（craft_efficiency）→ 做工效率
	# ⚠ numbers.json 里这个字段原本是 1.0 —— 那等于「建了作坊没有任何变化」，
	#   显然是填错的中性值，已改成 1.2（见 progress.md 的这一条）。
	var craft_eff := facility_effect("zuofang", "craft_efficiency", 1.0)
	if craft_eff > 1.0 and crafters > 0:
		var extra_tools := float(crafters) * (craft_eff - 1.0)
		gain["tools"] += extra_tools
		mat["tools"] = float(mat.get("tools", 0.0)) + extra_tools

	# 葡萄晾房（fruit_to_raisin_rate）→ 秋季把易坏的瓜果晒成葡萄干
	# ⚠ 现在**没有腐坏系统**（resources.food 的 shelf_life_days 定义了但没人读），
	#   所以「晒干能多存」这件事在数值上无处体现。这里用等效实现：
	#   秋季食物产出 ×(1 + 转化率)，含义是「本来会烂掉的那部分被晒干救回来了」。
	#   将来做了腐坏系统，把这一段换成真正的 fruit → 葡萄干 转化。
	if str(state["calendar"].get("season", "")) == "autumn":
		var raisin := facility_effect("liangfang", "fruit_to_raisin_rate", 0.0)
		if raisin > 0.0 and gain["food"] > 0.0:
			# ⚠ 必须显式写 float：gain["food"] 是 Dictionary 取值、类型是 Variant，
			# 本项目把「从 Variant 推断类型」设成错误，用 := 会直接解析失败。
			var extra_food: float = float(gain["food"]) * raisin
			gain["food"] += extra_food
			state["resources"]["food"]["fruit"] = \
				float(state["resources"]["food"].get("fruit", 0.0)) + extra_food

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
	#
	# 灾难与畜牧插在「干活之前」，顺序也是刻意的：
	#   灾难先落（大旱当天就让流量和田产下水），再结算岗位产出，
	#   然后牲畜吃料（吃的是粮，和人口抢同一份），最后才烂存粮。
	#   如果反过来，灾难当天就白挨一天、牲畜也会先按好天算一遍产出。
	var disaster_hit := _roll_disaster()
	var festival_hit := check_festival()
	_last_gain = _settle_jobs()
	var finished := _tick_construction()
	var herd_report := _tick_livestock()
	var rot := _tick_spoilage()
	# 加工放在畜牧与腐坏之后：羊毛是畜牧当天产的，先产再擀毡才说得通
	var crafted := _tick_crafts()
	var cotton := _tick_cotton()
	_last_gain["herd"] = herd_report
	_last_gain["spoilage"] = rot
	_last_gain["crafts"] = crafted
	_last_gain["cotton"] = cotton
	_last_gain["festival"] = (str(festival_hit.get("display", "")) if not festival_hit.is_empty() else "")
	_last_gain["festival_text"] = (str(festival_hit.get("text", "")) if not festival_hit.is_empty() else "")
	_last_gain["disaster"] = (str(disaster_hit.get("display", "")) if not disaster_hit.is_empty() else "")
	# 田产受灾难影响（大旱的 farm_yield_mult）
	var farm_mult := disaster_mult("farm_yield_mult", 1.0)
	if farm_mult != 1.0 and _last_gain.has("food"):
		_last_gain["food"] = float(_last_gain["food"]) * farm_mult

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
	# 大旱期间出水量打折。系数取自当前发作的灾难（没有灾就是 1.0）——
	# 调用处不判断有没有灾，这样加新灾难时不用改这里。
	flow *= disaster_mult("flow_multiplier", 1.0)

	var pop_cfg: Dictionary = numbers.get("population", {}).get("daily_consumption", {})
	var pop := int(state["population"])
	var water_need := pop * float(pop_cfg.get("water_per_person", 3.0))
	# 厨房（food_efficiency）→ 同样的粮能多养人。
	# 1.15 的意思是「省下一成半」：日耗 = 人数×3 ÷ 1.15。
	# 取整用 round 而不是 int，否则 1.15 这种小系数会被 int 直接抹平、厨房白建。
	var food_eff := facility_effect("chufang", "food_efficiency", 1.0)
	var food_need := int(round(float(pop) * float(pop_cfg.get("food_per_person", 3))
		/ maxf(0.1, food_eff)))

	state["karez"]["flow_per_day"] = flow
	var water: Dictionary = state["resources"]["water"]
	water["current"] = clampf(float(water["current"]) + flow - water_need, 0.0, float(water["capacity"]))

	_consume_food(int(food_need))

	# 缺水惩罚（对应 numbers.json 的 shortage_effect）
	if float(water["current"]) <= 0.0:
		state["stats"]["morale"] = maxf(0.0, float(state["stats"]["morale"]) - 3.0)

	state["calendar"]["day"] = get_day() + 1
	# 木卡姆冷却按天递减（和灾难冷却同一个模式：冷却期只递减、不叠加）
	if int(state.get("music_cooldown", 0)) > 0:
		state["music_cooldown"] = int(state["music_cooldown"]) - 1
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


## 人口上限 = min(水能供的人数, 田能养的人数) **+ 居所类设施提供的床位**。
##
## ⚠ 这里原本是 `min(..., housing)` —— 把住宿当成**上限**。方向是反的：
##   450 方水本该供 15 人，一建驿馆（本该让人有地方住、住得更多）
##   上限反而掉到 12。实测断言「4 段时人口上限 ≥15」就是被这一条卡成 12 的。
##   住宿是「多出来的床位」，应当是**加成**。
##
## 床位来自两个字段：驿馆的 lodging_capacity、居所/毡房区的 population_capacity。
## 判据用 has_facility()，与其它设施一致 —— 地图上看得见的就算数。
func population_capacity() -> int:
	# ⚠ 直接问 water_capacity()，**不要**读 state 里存的 capacity ——
	#   那个值只有 clamp_all() 跑过才是最新的。建好仓库到下一次 clamp 之间，
	#   人口上限会短暂地按旧容量算（实测：仓库已建、容量 450，上限却还按 300 算出 10）。
	#   派生值当场算，就没有"过期"这一说。
	var water_cap := water_capacity()
	var by_water := int(water_cap / 30.0)
	var by_farm := farmland_plots() * 3
	var cap := mini(by_water, by_farm)

	var beds := 0
	for b in numbers.get("buildings", {}).get("list", []):
		var bid := str(b.get("id", ""))
		if not has_facility(bid):
			continue
		var eff: Dictionary = b.get("effect", {})
		beds += int(eff.get("lodging_capacity", 0))
		beds += int(eff.get("population_capacity", 0))

	var floor_pop := int(numbers.get("population", {}).get("initial", 6))
	return maxi(floor_pop, cap + beds)


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


## 全部建筑的**有序列表**（来自 numbers.json，不在代码里另写一份）。
##
## 补这个的直接原因：HUD 的建造菜单原来硬编码了 2 座建筑（驿馆、马厩），
## 而数据里已经有 13 座 —— 于是仓库 / 作坊 / 晾房 / 围墙 / 烽燧 / 居所 /
## 毡房区 / 奏乐台 / 畜栏**全都没出现在菜单里，玩家根本点不到**。
## 又一次「数据里有、代码不读」的静默失效（本项目第 10 次）。
func all_buildings() -> Array:
	var b: Dictionary = numbers.get("buildings", {})
	var a = b.get("list", [])
	return a if a is Array else []


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
	elif has_facility(id):
		# ⚠ 地标本来就在场上（gate 已经满足，例如仓库是 `gate: always`）。
		#   它的 effect 从第一天起就生效了 —— 再"建"一次只是白花材料，
		#   付了钱什么都没变。这类设施不该出现在可建造列表里。
		#   （gate 是 sections 的设施仍可提前建造：那时 place_present 还没满足，
		#     建好反而让它提前出现 —— 这一条不该把那种情况也堵上。）
		reason = "此地已有（已在起作用）"
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
# ---------------------------------------------------------------------------
# 畜牧
# ---------------------------------------------------------------------------
#
# 数据在 numbers.json 的 livestock 段。这里只做三件事：算上限、结算产出与繁殖、
# 把"抓野畜"变成一个真实行动。
#
# ⚠ 接线的意义：`majiu.effect.livestock_capacity: 15` 在数据里躺了很久，
#   从来没有任何代码读过它 —— 马厩此前只有 trade_range 一个用处。
#   接上之后，马厩才真的是"畜牧"类建筑。

const LIVESTOCK_IDS := ["sheep", "goat", "camel", "donkey", "chicken"]
## 掉牲畜的优先顺序：先死最不值钱的。玩家会心疼鸡，但不会像丢一头驼那样疼。
const LIVESTOCK_LOSS_ORDER := ["chicken", "goat", "sheep", "donkey", "camel"]


func livestock_of(sid: String) -> int:
	return maxi(0, int(state.get("livestock", {}).get(sid, 0)))


func total_livestock() -> int:
	var n := 0
	for sid in LIVESTOCK_IDS:
		n += livestock_of(sid)
	return n


## 牲畜存栏上限 = 基础 + 各建筑给的 livestock_capacity（马厩 15）。
## 到顶就不再繁殖 —— 所以想扩群就得先盖栏。
func livestock_capacity() -> int:
	var base := int(numbers.get("livestock", {}).get("base_capacity", 6))
	var bonus := 0
	for b in numbers.get("buildings", {}).get("list", []):
		var bid := str(b.get("id", ""))
		if not has_facility(bid):
			continue
		bonus += int(b.get("effect", {}).get("livestock_capacity", 0))
	return maxi(0, base + bonus)


## 牧人能照看多少头。超出的部分按"没人管"算：产出减半、不繁殖。
func tended_capacity() -> int:
	var per := int(numbers.get("livestock", {}).get("jobs", {})
		.get("herd", {}).get("per_herder_capacity", 8))
	return job_count("herd") * per


func _species_cfg(sid: String) -> Dictionary:
	var c = numbers.get("livestock", {}).get("species", {}).get(sid, {})
	return c if c is Dictionary else {}


func species_cn(sid: String) -> String:
	return str(_species_cfg(sid).get("display", sid))


## 存栏概括（「羊4 鸡2」）。HUD 与日志共用。
func livestock_summary() -> String:
	var parts: Array = []
	for sid in LIVESTOCK_IDS:
		var n := livestock_of(sid)
		if n > 0:
			parts.append("%s%d" % [str(_species_cfg(sid).get("short", sid)), n])
	return "空栏" if parts.is_empty() else " ".join(parts)


## 每天要吃掉多少草料（折算成粮）。冬季 +30%：牲畜要靠膘过冬。
##
## 刻意让草料和人的口粮抢同一份粮 —— 这就是「养多少牲口」的取舍所在：
## 多养一头羊，人就少吃一份。
func livestock_feed_per_day() -> float:
	var per := float(numbers.get("livestock", {}).get("feed_per_head_per_day", 0.5))
	var total := 0.0
	for sid in LIVESTOCK_IDS:
		total += float(livestock_of(sid)) * float(_species_cfg(sid).get("feed", 1.0))
	total *= per
	if str(state["calendar"].get("season", "")) == "winter":
		total *= float(numbers.get("livestock", {}).get("winter_feed_multiplier", 1.3))
	return total


## 按数量扣牲畜。返回实际死了几头。
func lose_livestock(n: int, reason := "") -> int:
	if n <= 0:
		return 0
	var killed := 0
	for sid in LIVESTOCK_LOSS_ORDER:
		if killed >= n:
			break
		var have := livestock_of(sid)
		if have <= 0:
			continue
		var take := mini(have, n - killed)
		state["livestock"][sid] = have - take
		killed += take
	if killed > 0 and reason != "":
		var log: Array = state["livestock_log"]
		log.append("损失 %d 头（%s）" % [killed, reason])
		if log.size() > 12:
			log.pop_front()
	return killed


## 加牲畜（抓野畜、商队购买都走这里）。
func add_livestock(sid: String, n: int) -> int:
	if n <= 0 or not (sid in LIVESTOCK_IDS):
		return 0
	var room := maxi(0, livestock_capacity() - total_livestock())
	var add := mini(n, room)
	if add <= 0:
		return 0
	state["livestock"][sid] = livestock_of(sid) + add
	state_changed.emit()
	return add


## 每天的畜牧结算：吃料 → 产出 → 繁殖 → 饿死。返回明细给 HUD / 日志。
func _tick_livestock() -> Dictionary:
	var out := {"fed": 0.0, "need": 0.0, "starving": false,
		"products": {}, "born": 0, "died": 0}
	var total := total_livestock()
	if total <= 0:
		return out
	var need := livestock_feed_per_day()
	out["need"] = need
	var food: Dictionary = state["resources"]["food"]
	var have := float(food.get("grain", 0.0))
	var ratio := 1.0
	if have < need:
		ratio = have / maxf(0.001, need)
		out["starving"] = true
	var eaten := minf(have, need)
	food["grain"] = maxf(0.0, have - eaten)
	out["fed"] = eaten

	# 产出：有人照看才满额。畜牧产出单独记在 resources.products，
	# 不混进 food —— 羊毛不是吃的，混进去会把"还能吃几天"算歪。
	if not state["resources"].has("products"):
		state["resources"]["products"] = {}
	var products: Dictionary = state["resources"]["products"]
	var tended := tended_capacity()
	var untended_mult := float(numbers.get("livestock", {})
		.get("untended_output_multiplier", 0.5))
	var walking := 0
	for sid in LIVESTOCK_IDS:
		var n := livestock_of(sid)
		if n <= 0:
			continue
		var looked_after := clampi(tended - walking, 0, n)
		walking += n
		var prod: Dictionary = _species_cfg(sid).get("products", {})
		for i in range(n):
			var eff: float = 1.0 if i < looked_after else untended_mult
			for pk in prod:
				var amt := float(prod[pk]) * eff * ratio
				products[pk] = float(products.get(pk, 0.0)) + amt
				out["products"][pk] = float(out["products"].get(pk, 0.0)) + amt

	# 繁殖：吃得饱 + 有牧人 + 没到上限
	var cap := livestock_capacity()
	var days: Dictionary = state["livestock_days"]
	for sid in LIVESTOCK_IDS:
		var n := livestock_of(sid)
		if n <= 0 or total_livestock() >= cap or ratio < 0.999 or tended <= 0:
			days[sid] = 0
			continue
		var d := int(days.get(sid, 0)) + 1
		if d >= int(_species_cfg(sid).get("breed_days", 8)):
			days[sid] = 0
			if randf() < float(_species_cfg(sid).get("breed_chance", 0.4)):
				state["livestock"][sid] = n + 1
				out["born"] = int(out["born"]) + 1
		else:
			days[sid] = d

	# 饿到掉膘：缺口越大死得越多
	if ratio < 0.7:
		var want := int(ceil(float(total) * (0.7 - ratio) * 0.5))
		out["died"] = lose_livestock(want, "缺草料")
	clamp_all()
	return out


# ---------------------------------------------------------------------------
# 抓野畜：把「派人出去」变成一个真实行动
# ---------------------------------------------------------------------------

## 抓野畜的可行性、成本与成功率。UI 直接用它渲染按钮提示。
func catch_info() -> Dictionary:
	var cfg: Dictionary = numbers.get("livestock", {}).get("catch", {})
	var wild: Dictionary = numbers.get("livestock", {}).get("wild", {})
	# 目标按难度升序：先给玩家能成的，别一上来就让他去套野驼
	var options: Array = []
	for wid in wild:
		var w: Dictionary = wild[wid]
		options.append({"id": wid, "display": str(w.get("display", wid)),
			"to": str(w.get("to", "sheep")), "difficulty": float(w.get("difficulty", 1.0)),
			"desc": str(w.get("desc", ""))})
	options.sort_custom(func(a, b): return float(a["difficulty"]) < float(b["difficulty"]))
	var labor := int(cfg.get("labor_per_head", 2))
	var ap := int(cfg.get("days", 1))
	var room := maxi(0, livestock_capacity() - total_livestock())
	var reason := ""
	if room <= 0:
		reason = "栏位已满（先盖马厩或扩栏）"
	elif unassigned() < labor:
		reason = "需要 %d 个闲人（当前 %d）" % [labor, unassigned()]
	elif action_points() < ap:
		reason = "行动点不足（需要 %d）" % ap
	return {"ok": reason == "", "reason": reason, "options": options,
		"labor": labor, "action_points": ap, "room": room,
		"base_chance": float(cfg.get("base_chance", 0.42)),
		"trips": int(state.get("wild_trips", 0)),
		"note": str(cfg.get("note", ""))}


## 派人去抓野畜。返回结果字典，含成功与否、抓到了什么、给玩家的话。
##
## 成功率随"去过几次"上升：这是给玩家的耐心奖励，也避免纯运气。
## 失败不扣人 —— 只白费一趟人工。失败要疼，但不该劝退。
func catch_wild(wild_id: String) -> Dictionary:
	var info := catch_info()
	if not bool(info["ok"]):
		return {"ok": false, "reason": str(info["reason"])}
	var wild: Dictionary = numbers.get("livestock", {}).get("wild", {})
	if not wild.has(wild_id):
		return {"ok": false, "reason": "没有这种野畜"}
	var w: Dictionary = wild[wild_id]
	if not spend_action_point(int(info["action_points"])):
		return {"ok": false, "reason": "行动点不足"}
	var trips := int(state.get("wild_trips", 0))
	state["wild_trips"] = trips + 1
	# 每去过一次 +4%，难度越高越难
	var chance := float(info["base_chance"]) + 0.04 * float(trips)
	chance += 0.06 * float(state["resources"]["materials"].get("tools", 0.0)) * 0.2
	chance = clampf(chance / maxf(0.4, float(w.get("difficulty", 1.0))), 0.05, 0.9)
	var cn := str(w.get("display", wild_id))
	if randf() >= chance:
		state_changed.emit()
		return {"ok": true, "success": false, "display": cn,
			"text": "跑了一整天，%s 没套上。人没事，白费一趟人工。" % cn}
	var cnt_range: Array = w.get("count", [1, 1])
	var n := randi_range(int(cnt_range[0]), int(cnt_range[1]))
	var got := add_livestock(str(w.get("to", "sheep")), n)
	state_changed.emit()
	if got <= 0:
		return {"ok": true, "success": false, "display": cn,
			"text": "套到了 %s，可是栏里没地方放，只好放了。" % cn}
	return {"ok": true, "success": true, "display": cn, "count": got,
		"species": str(w.get("to", "sheep")),
		"text": "套到了 %d 头%s，赶回栏里。" % [got, cn]}


# ---------------------------------------------------------------------------
# 食物腐坏
# ---------------------------------------------------------------------------
#
# 数据也早就有：每个 food item 的 shelf_life_days、仓库的 spoilage_reduction、
# 晾房的 fruit_to_raisin_rate —— 同样从来没人读过。
#
# 设计意图：让"囤一堆粮"不再是万能的解。馕能放 12 天、粮能放 90 天、瓜果最短命，
# 所以晾房把鲜果变葡萄干才有意义：葡萄干能放到明年，鲜果几天就烂。

## 每天的腐坏结算。返回 {食物id: 烂掉的数量}。
func _tick_spoilage() -> Dictionary:
	var out := {}
	var food: Dictionary = state["resources"]["food"]
	var items: Dictionary = numbers.get("resources", {}).get("food", {}).get("items", {})
	# 仓库的 spoilage_reduction 是"少烂多少"的比例；没有仓库就是 0
	var keep := 1.0 - clampf(facility_effect("cangku", "spoilage_reduction", 0.0), 0.0, 0.95)
	for k in food.keys():
		var cfg = items.get(k, {})
		if not (cfg is Dictionary) or cfg.is_empty():
			continue
		var life := float(cfg.get("shelf_life_days", 0))
		var amt := float(food[k])
		if life <= 0.0 or amt <= 0.0:
			continue
		var lost := amt * (1.0 / life) * keep
		if lost <= 0.0:
			continue
		food[k] = maxf(0.0, amt - lost)
		out[k] = lost
	return out


# ---------------------------------------------------------------------------
# 灾难
# ---------------------------------------------------------------------------
#
# 数据在 numbers.json 的 disasters 段。核心设计：**每一种都能被预判、被准备**。
# 候选按季节筛 → 掷骰 → 命中后按 mitigation 里的建筑把损失打折。
# 于是"盖烽燧/仓库/围墙/驿馆"这些建筑终于不只是加数值，而是在防具体的天灾。

func disasters_cfg() -> Array:
	var a = numbers.get("disasters", {}).get("list", [])
	return a if a is Array else []


## 正在发作、且带持续天数的灾难（如大旱）。没有就返回 {}。
func active_disaster() -> Dictionary:
	var did := str(state.get("disaster", {}).get("active", ""))
	if did == "":
		return {}
	for c in disasters_cfg():
		if str(c.get("id", "")) == did:
			return c
	return {}


## 灾难期间的系数（大旱的 flow_multiplier / farm_yield_mult）。
## 没灾就返回 neutral —— 调用处不需要判断有没有灾。
func disaster_mult(key: String, neutral: float) -> float:
	var c := active_disaster()
	if c.is_empty() or not c.has(key):
		return neutral
	return float(c.get(key, neutral))


## 每天掷一次灾难。返回命中的配置；没命中返回 {}。
func _roll_disaster() -> Dictionary:
	var dcfg: Dictionary = numbers.get("disasters", {})
	if not bool(dcfg.get("enabled", true)):
		return {}
	var roll_cfg: Dictionary = dcfg.get("roll", {})
	var st: Dictionary = state["disaster"]

	# 1) 冷却（刚遭过灾不再遭，避免连击把人打死）
	if int(st.get("cooldown", 0)) > 0:
		st["cooldown"] = int(st["cooldown"]) - 1
		state["disaster"] = st
		return {}

	# 2) 正在发作的先递减；没结束就今天不掷新的
	if str(st.get("active", "")) != "":
		var left := int(st.get("days_left", 0)) - 1
		if left > 0:
			st["days_left"] = left
			state["disaster"] = st
			return {}
		st["active"] = ""
		st["days_left"] = 0
		state["disaster"] = st

	# 3) 按季节筛候选
	var season := str(state["calendar"].get("season", "spring"))
	var pool: Array = []
	for c in disasters_cfg():
		var seasons: Array = c.get("seasons", [])
		if seasons.is_empty() or (season in seasons):
			pool.append(c)
	if pool.is_empty():
		return {}

	# 4) 逐个掷骰，取第一个命中的。顺序固定 → 同一种子可复现。
	for c in pool:
		if randf() >= float(c.get("base_chance", 0.1)):
			continue
		var detail := _apply_disaster(c)
		st = state["disaster"]
		st["last_id"] = str(c.get("id", ""))
		# ⚠ 只有**带持续天数**的灾难才算"正在发作"。
		#   寒潮/沙暴这类是瞬发的：如果把它们的 id 写进 active，
		#   第二天会走进"active 递减"那条分支、白扣一天，而且 HUD 会显示
		#   「寒潮（剩 0 天）」这种说不通的读数。隔天用 last_id 展示即可。
		var dur := int(c.get("duration_days", 0))
		st["active"] = str(c.get("id", "")) if dur > 0 else ""
		st["days_left"] = dur
		st["cooldown"] = int(roll_cfg.get("cooldown_days", 5))
		st["log"] = "%s：%s" % [str(c.get("display", "")), "　".join(detail["lines"])]
		var hist: Array = st["history"]
		hist.append(st["log"])
		if hist.size() > 20:
			hist.pop_front()
		state["disaster"] = st
		return c
	return {}


## 落一次灾难的全部后果。返回人话明细（写进日志、也给 HUD 显示）。
func _apply_disaster(c: Dictionary) -> Dictionary:
	var eff: Dictionary = c.get("effects", {})
	var mit: Dictionary = c.get("mitigation", {})
	# 有对应建筑就把效果乘下来：0.5 = 减半
	var soften := 1.0
	var softened_by: Array = []
	for bid in mit:
		if has_facility(bid):
			soften *= (1.0 - float(mit[bid]))
			softened_by.append(bid)
	var lines: Array = []
	var res: Dictionary = state["resources"]
	var water: Dictionary = res["water"]
	if eff.has("water_loss"):
		var loss := float(eff["water_loss"]) * soften
		water["current"] = maxf(0.0, float(water["current"]) - loss)
		lines.append("失水 %.0f 方" % loss)
	if eff.has("water_gain"):
		var gain := float(eff["water_gain"])
		water["current"] = minf(float(water["capacity"]), float(water["current"]) + gain)
		lines.append("进水 %.0f 方" % gain)
	if eff.has("food_loss"):
		var fl := float(eff["food_loss"]) * soften
		_consume_food(int(round(fl)))
		lines.append("损粮 %.0f 份" % fl)
	if eff.has("farm_destroy"):
		var ratio := float(eff["farm_destroy"]) * soften
		var destroyed := 0.0
		for k in ["grain", "fruit"]:
			var amt := float(res["food"].get(k, 0.0))
			var cut := amt * ratio
			res["food"][k] = maxf(0.0, amt - cut)
			destroyed += cut
		lines.append("庄稼被毁 %.0f 份" % destroyed)
	if eff.has("livestock_loss"):
		var want := int(round(float(total_livestock()) * float(eff["livestock_loss"]) * soften))
		var killed := lose_livestock(want, str(c.get("display", "")))
		if killed > 0:
			lines.append("牲畜 -%d 头" % killed)
	if eff.has("building_wear"):
		var wear := float(eff["building_wear"]) * soften
		var n_b := 0
		for bid in state["buildings"].keys():
			var b: Dictionary = state["buildings"][bid]
			b["condition"] = maxf(0.0, float(b.get("condition", 100)) - wear)
			n_b += 1
		if n_b > 0:
			lines.append("建筑受损 -%.0f（%d 座）" % [wear, n_b])
	if eff.has("morale"):
		state["stats"]["morale"] = clampf(
			float(state["stats"]["morale"]) + float(eff["morale"]), 0.0, 100.0)
		lines.append("士气 %+.0f" % float(eff["morale"]))
	if eff.has("security"):
		state["stats"]["security"] = clampf(
			float(state["stats"]["security"]) + float(eff["security"]), 0.0, 100.0)
		lines.append("治安 %+.0f" % float(eff["security"]))
	if eff.has("population_loss_chance"):
		var ch := float(eff["population_loss_chance"]) * soften
		var pop := int(state["population"])
		if pop > 1 and randf() < ch:
			var dead := mini(pop - 1, maxi(1, int(round(float(pop) * 0.15))))
			state["population"] = pop - dead
			normalize_jobs()
			lines.append("人口 -%d" % dead)
	if not softened_by.is_empty():
		lines.append("（%s 挡住了大半）" % "、".join(softened_by))
	clamp_all()
	return {"lines": lines, "softened_by": softened_by}


# ---------------------------------------------------------------------------
# 涝坝扩容
# ---------------------------------------------------------------------------
#
# karez.reservoir.levels 的数据也一直在，没人读。接上之后，涝坝（储水上限）
# 从"建仓库顺带"变成一条可以主动投资的路：旱季之前把水囤起来。

## 下一级涝坝扩建的成本与效果。UI 直接用它渲染。
func reservoir_info() -> Dictionary:
	var kc: Dictionary = numbers.get("karez", {})
	var lv: Array = kc.get("reservoir", {}).get("levels", [])
	var cur := int(state["karez"].get("reservoir_level", 0))
	if cur >= lv.size():
		return {"ok": false, "reason": "涝坝已扩到顶（%d 级）" % lv.size(),
			"level": cur, "max_level": lv.size(), "next": {}}
	var nxt: Dictionary = lv[cur]
	var mats: Dictionary = nxt.get("materials", {})
	var have_mats: Dictionary = state["resources"]["materials"]
	var lack: Array = []
	for k in mats:
		var have := float(have_mats.get(k, 0.0))
		if have < float(mats[k]):
			lack.append("%s 缺 %d" % [_mat_cn(k), int(float(mats[k]) - have)])
	var reason := ""
	if not construction_idle():
		reason = "施工中（先完成当前的工程）"
	elif not lack.is_empty():
		reason = "　".join(lack)
	return {"ok": reason == "", "reason": reason, "level": cur,
		"max_level": lv.size(), "next": nxt,
		"display": str(nxt.get("display", "涝坝扩建")),
		"materials": mats, "days": int(nxt.get("days", 2)),
		"capacity": float(nxt.get("capacity", 0.0))}


## 开始扩建涝坝。走和挖井/盖房同一条施工队列（同一时刻只允许一项工程）。
func start_reservoir() -> Dictionary:
	var info := reservoir_info()
	if not bool(info["ok"]):
		return {"ok": false, "reason": str(info["reason"])}
	var nxt: Dictionary = info["next"]
	var mats: Dictionary = nxt.get("materials", {})
	var rc: Dictionary = state["resources"]["materials"]
	for k in mats:
		rc[k] = float(rc.get(k, 0.0)) - float(mats[k])
	state["construction"] = {
		"kind": "reservoir", "target": "reservoir",
		"display": str(nxt.get("display", "涝坝扩建")),
		"days_left": int(nxt.get("days", 2)), "total_days": int(nxt.get("days", 2)),
		"progress": 0.0,
	}
	clamp_all()
	state_changed.emit()
	return {"ok": true, "display": str(nxt.get("display", "涝坝扩建")),
		"days": int(nxt.get("days", 2))}


# ---------------------------------------------------------------------------
# 加工：把原料变成值钱的成品
# ---------------------------------------------------------------------------
#
# 数据在 numbers.json 的 crafts 段。补它的直接动机有两个：
#   · 价格表里早就有 raisin / rug / instrument 的价，但**没有任何系统产出它们**
#   · 畜牧产出的**羊毛原本毫无用处** —— 擀成毡子、织成地毯，养羊才真的换得到钱

## 某个物产的库存。原料可能来自 food / materials / products 三处，
## 调用处不该关心它存在哪儿。
func stock_of(good: String) -> float:
	var res: Dictionary = state["resources"]
	for bucket in ["food", "materials", "products"]:
		var b: Dictionary = res.get(bucket, {})
		if b.has(good):
			return float(b[good])
	return 0.0


## 物产的显示名。名字只从数据里取，不在代码里再写一份对照表 ——
## 「两处各写一套」正是这个项目里反复出错的地方。
func good_cn(good: String) -> String:
	var res_cfg: Dictionary = numbers.get("resources", {})
	for bucket in ["food", "materials"]:
		var items: Dictionary = res_cfg.get(bucket, {}).get("items", {})
		if items.has(good):
			return str(items[good].get("display", good))
	var lv: Dictionary = numbers.get("livestock", {}).get("products", {})
	if lv.has(good):
		return str(lv[good].get("display", good))
	var crafts: Dictionary = numbers.get("crafts", {})
	var goods: Dictionary = crafts.get("goods", {})
	if goods.has(good):
		return str(goods[good].get("display", good))
	return good


## numbers.json 建筑 id → 中文名。
func _building_cn(bid: String) -> String:
	var c := _building_cfg(bid)
	return str(c.get("display", bid)) if not c.is_empty() else bid


func craft_recipes() -> Array:
	var c: Dictionary = numbers.get("crafts", {})
	var a = c.get("recipes", [])
	return a if a is Array else []


## 每条配方的可行性。UI 与日志共用 —— **判据只写这一处**。
func crafts_info() -> Array:
	var out: Array = []
	for r in craft_recipes():
		var bid := str(r.get("building", ""))
		var need_b := bid != "" and not has_facility(bid)
		var inp: Dictionary = r.get("input", {})
		var lack: Array = []
		for k in inp:
			var have := stock_of(str(k))
			if have + 0.0001 < float(inp[k]):
				lack.append("%s %d/%d" % [good_cn(str(k)), int(have), int(float(inp[k]))])
		var reason := ""
		if need_b:
			reason = "需要%s" % _building_cn(bid)
		elif not lack.is_empty():
			reason = "缺 " + "、".join(lack)
		out.append({"id": str(r.get("id", "")), "display": str(r.get("display", "")),
			"ok": reason == "", "reason": reason,
			"input": inp, "output": r.get("output", {})})
	return out


## 扣某个物产（按 food → materials → products 依次扣，扣不够就从下一处继续）。
func _take_good(good: String, amount: float) -> void:
	var res: Dictionary = state["resources"]
	var left := amount
	for bucket in ["food", "materials", "products"]:
		if left <= 0.0:
			break
		var b: Dictionary = res.get(bucket, {})
		if not b.has(good):
			continue
		var take := minf(left, maxf(0.0, float(b[good])))
		b[good] = maxf(0.0, float(b[good]) - take)
		left -= take


## 加某个物产。已有归属就加到原处；新成品统一进 materials（不占食物配额）。
func _give_good(good: String, amount: float) -> void:
	var res: Dictionary = state["resources"]
	for bucket in ["food", "materials", "products"]:
		var b: Dictionary = res.get(bucket, {})
		if b.has(good):
			b[good] = float(b[good]) + amount
			return
	if not res.has("materials"):
		res["materials"] = {}
	res["materials"][good] = float(res["materials"].get(good, 0.0)) + amount


## 每天的加工结算。返回 {产出id: 数量}，供日志显示。
##
## 原料不够就整条跳过（不扣一半）—— 半成品对玩家没有意义，
## 而且"扣了料却没出货"是这类系统里最容易让人恼火的 bug。
func _tick_crafts() -> Dictionary:
	var made: Dictionary = {}
	for r in craft_recipes():
		var bid := str(r.get("building", ""))
		if bid != "" and not has_facility(bid):
			continue
		var inp: Dictionary = r.get("input", {})
		var enough := true
		for k in inp:
			if stock_of(str(k)) + 0.0001 < float(inp[k]):
				enough = false
				break
		if not enough:
			continue
		for k in inp:
			_take_good(str(k), float(inp[k]))
		var outp: Dictionary = r.get("output", {})
		for k in outp:
			_give_good(str(k), float(outp[k]))
			made[k] = float(made.get(k, 0.0)) + float(outp[k])
	return made


# ---------------------------------------------------------------------------
# 节庆
# ---------------------------------------------------------------------------
#
# 数据在 numbers.json 的 festivals 段：诺鲁孜节 / 葡萄熟了 / 古尔邦节。
# 判据只有「季 + 季内第几天」，刻意不加随机 —— 节庆要**可预期**才像个日子。

func festivals_cfg() -> Array:
	var f: Dictionary = numbers.get("festivals", {})
	var a = f.get("list", [])
	return a if a is Array else []


## 今天是不是节庆。是就落效果并返回配置（含 text 与 lines），否则返回 {}。
##
## 用 flags 记住"今年这个节已经过过了"：advance_day 之外的任何路径调进来
## 都不会重复加士气 —— 否则玩家反复推进时段就能刷声望。
func check_festival() -> Dictionary:
	var season := str(state["calendar"].get("season", ""))
	var day := get_day()
	var flags: Dictionary = state["flags"]
	for f in festivals_cfg():
		if str(f.get("season", "")) != season:
			continue
		var in_season := ((day - 1) % 30) + 1
		if int(f.get("day", 0)) != in_season:
			continue
		var key := "festival_%s_%d" % [str(f.get("id", "")), day]
		if bool(flags.get(key, false)):
			return {}
		flags[key] = true
		var eff: Dictionary = f.get("effects", {})
		var lines: Array = []
		if eff.has("morale"):
			state["stats"]["morale"] = clampf(
				float(state["stats"]["morale"]) + float(eff["morale"]), 0.0, 100.0)
			lines.append("士气 %+.0f" % float(eff["morale"]))
		if eff.has("reputation"):
			state["stats"]["reputation"] = maxf(0.0,
				float(state["stats"]["reputation"]) + float(eff["reputation"]))
			lines.append("声望 %+.0f" % float(eff["reputation"]))
		if eff.has("silver"):
			state["resources"]["silver"] = float(state["resources"]["silver"]) + float(eff["silver"])
			lines.append("银两 %+.0f" % float(eff["silver"]))
		# 有牲口的人家在宰牲节更体面 —— 养牲畜的回报不只是钱
		var bonus: Dictionary = f.get("bonus_if_livestock", {})
		if not bonus.is_empty() and total_livestock() >= int(bonus.get("min", 0)):
			if bonus.has("reputation"):
				state["stats"]["reputation"] = maxf(0.0,
					float(state["stats"]["reputation"]) + float(bonus["reputation"]))
				lines.append("声望 %+.0f（牲口多）" % float(bonus["reputation"]))
		clamp_all()
		return {"id": str(f.get("id", "")), "display": str(f.get("display", "")),
			"text": str(f.get("text", "")), "lines": lines}
	return {}


# ---------------------------------------------------------------------------
# 木卡姆
# ---------------------------------------------------------------------------
#
# 数据在 numbers.json 的 music 段。它的价值不在"加士气"，
# 而在于**把三条已有系统串成一条链**：
#     木料（采集）→ 作坊做热瓦普（加工）→ 奏乐台办木卡姆（士气/声望）
# 而不是又一个「点一下加数值」的按钮。

func music_suites() -> Array:
	var m: Dictionary = numbers.get("music", {})
	var a = m.get("suites", [])
	return a if a is Array else []


## 办一场木卡姆的可行性 + 每套曲目。UI 与逻辑共用这一份判据（判据只写一处）。
func music_info() -> Dictionary:
	var m: Dictionary = numbers.get("music", {})
	var p: Dictionary = m.get("performance", {})
	var lack: Array = []
	var bid := str(p.get("requires_building", ""))
	if bid != "" and not has_facility(bid):
		lack.append("需要%s" % _building_cn(bid))
	var npc := str(p.get("requires_npc", ""))
	if npc != "" and not character_present(npc):
		# 名字也来自数据，不在代码里再写一张人名表
		lack.append("需要%s在场" % str(p.get("requires_npc_display", npc)))
	var items: Dictionary = p.get("needs_item", {})
	for k in items:
		if stock_of(str(k)) + 0.0001 < float(items[k]):
			lack.append("库里没有%s" % good_cn(str(k)))
	var cd := int(state.get("music_cooldown", 0))
	if cd > 0:
		lack.append("刚办过，歇 %d 天" % cd)
	if action_points() < int(p.get("action_points", 2)):
		lack.append("行动点不足（要 %d）" % int(p.get("action_points", 2)))
	if unassigned() < int(p.get("labor", 1)):
		lack.append("需要 %d 个闲人" % int(p.get("labor", 1)))
	var suites: Array = []
	for s in music_suites():
		suites.append({"id": str(s.get("id", "")), "display": str(s.get("display", "")),
			"mood": str(s.get("mood", "")), "text": str(s.get("text", "")),
			"effects": s.get("effects", {})})
	return {"ok": lack.is_empty(), "reason": "；".join(lack), "suites": suites,
		"cooldown": cd, "note": str(p.get("note", "")),
		"played": int(state["flags"].get("muqam_played", 0))}


## 办一场木卡姆。返回结果，供日志与 UI 用。
func perform_muqam(index: int) -> Dictionary:
	var info := music_info()
	if not bool(info["ok"]):
		return {"ok": false, "reason": str(info["reason"])}
	var suites: Array = info["suites"]
	if index < 0 or index >= suites.size():
		return {"ok": false, "reason": "没有这一套"}
	var s: Dictionary = suites[index]
	var p: Dictionary = numbers.get("music", {}).get("performance", {})
	if not spend_action_point(int(p.get("action_points", 2))):
		return {"ok": false, "reason": "行动点不足"}
	var eff: Dictionary = s.get("effects", {})
	var lines: Array = []
	if eff.has("morale"):
		state["stats"]["morale"] = clampf(
			float(state["stats"]["morale"]) + float(eff["morale"]), 0.0, 100.0)
		lines.append("士气 %+.0f" % float(eff["morale"]))
	if eff.has("reputation"):
		state["stats"]["reputation"] = maxf(0.0,
			float(state["stats"]["reputation"]) + float(eff["reputation"]))
		lines.append("声望 %+.0f" % float(eff["reputation"]))
	state["music_cooldown"] = int(p.get("cooldown_days", 3))
	state["flags"]["muqam_played"] = int(state["flags"].get("muqam_played", 0)) + 1
	clamp_all()
	state_changed.emit()
	return {"ok": true, "display": str(s.get("display", "")), "text": str(s.get("text", "")),
		"lines": lines, "count": int(state["flags"]["muqam_played"])}


## 棉花：新疆的棉花是秋收。每名农夫在秋季额外收 N 单位。
##
## 为什么不塞进 _settle_jobs：那边结算的是"每块田产多少粮"，
## 而棉花是**按人头**算的（每个农夫自己去摘）。两件事量纲不同，
## 混在一起以后谁都读不懂这条规则。单开一个 tick，规则和数据对得上。
func _tick_cotton() -> float:
	var cfg: Dictionary = numbers.get("agriculture", {}).get("cotton", {})
	var y: Dictionary = cfg.get("season_yield", {})
	var season := str(state["calendar"].get("season", ""))
	if not y.has(season):
		return 0.0
	var amount := float(job_count("farm")) * float(y[season])
	if amount <= 0.0:
		return 0.0
	_give_good("cotton", amount)
	return amount


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


## 把存档里**缺失**的字段补成默认值（只补不覆盖）。
##
## 为什么必须做：`load_from` 原来是 `state = parsed["state"]` —— **整体替换、没有迁移**。
## 而本项目每一轮都在加系统（畜牧 / 灾难 / 加工 / 节庆 / 木卡姆 / 畜栏…），
## 玩家跨版本存档时，旧存档里根本没有 `livestock`、`disaster`、`music_cooldown`、
## `products` 这些键 —— 读出来以后，那些系统的代码取到 null 就**静默失效或直接报错**。
##
## 这个 bug 的隐蔽之处：新开一局永远正常，**只有读旧档才炸**，
## 而测试里从来不读旧档。所以测试也补了一条"模拟旧版本存档"的用例。
func _merge_defaults(dst: Dictionary, defaults: Dictionary) -> void:
	for k in defaults:
		if not dst.has(k):
			dst[k] = defaults[k]
		elif dst[k] is Dictionary and defaults[k] is Dictionary:
			_merge_defaults(dst[k], defaults[k])


func load_from(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary) or not parsed.has("state"):
		return false
	if not (parsed["state"] is Dictionary):
		return false
	state = parsed["state"]
	# ⚠ 迁移在前、事件在后：先把缺的字段补齐，后面的代码才敢直接取键。
	_merge_defaults(state, _initial_state())
	if event_system != null and parsed.has("events"):
		event_system.import_state(parsed["events"])
	clamp_all()
	state_changed.emit()
	return true
