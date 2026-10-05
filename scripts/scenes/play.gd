extends Node2D
## 主场景 —— 把地图、玩家、HUD、AI 对话、事件系统接成一个可玩循环。
##
## 这个场景取代了之前「地图场景」与「对话控制台」两个互不相干的孤立场景。
## 玩家在绿洲上走动，点竖井挖井，推进时段，和角色对话，遇事件做抉择 ——
## 全部发生在同一屏里，状态变化即时反映到地图与 HUD 上。

const SAVE_PATH := "user://karez_save.json"

## 每 N 天最多自动触发一次事件，避免天天弹窗。
const EVENT_MIN_GAP_DAYS := 2
## 跨天时自动触发事件的概率
const EVENT_CHANCE := 0.65

var _game: Node
var _events: Node
var _map: Node2D
var _villagers: Node2D
var _townfolk: Node2D
var _player: CharacterBody2D
var _hud: Control

var _recent: Array = []
var _last_event_day := -99

const NAME_OF := {
	"lao_kanjiang": "老坎匠",
	"muqam_yiren": "木卡姆艺人",
	"hasake_qishou": "哈萨克骑手",
	"hanshang_zhanggui": "商队掌柜",
	"chuniang": "厨娘",
	"shenmi_lvren": "神秘旅人",
	"mafei_toumu": "马匪头目",
}


func _ready() -> void:
	randomize()

	_game = $GameState
	_events = $EventSystem
	_map = $MapView
	_villagers = $Villagers
	_townfolk = $Townfolk
	_player = $Player
	_hud = $HUDLayer/HUD

	# 事件系统要能写进存档，先互相认领
	_game.event_system = _events

	_events.setup(_game)
	_map.setup(_game)
	# 居民要在状态层之后初始化：它靠 state_changed 信号跟随分工变化
	_villagers.setup(_game, _map)
	# 地图上的七个角色：点他 / 走近按 E，都会切到底栏并用那个人开始对话
	_townfolk.setup(_player, _game)
	_townfolk.talk_requested.connect(_on_talk_to)
	_hud.setup(_game, _events)

	_hud.dig_requested.connect(_on_dig)
	_hud.build_requested.connect(_on_build)
	_hud.next_phase_requested.connect(_on_next_phase)
	_hud.event_requested.connect(_on_event_manual)
	_hud.save_requested.connect(_on_save)
	_hud.load_requested.connect(_on_load)
	_hud.say_requested.connect(_on_say)
	_map.shaft_pressed.connect(_on_shaft_pressed)

	_game.response_received.connect(_on_response)
	_game.request_failed.connect(_on_failed)

	# 教程必须塞进日志的 3 行里 —— 写多了会被顶掉，玩家只看到后半截
	_hud.append_log("[b]《坎儿井》[/b] 水只够 7 天、粮只够 4 天 —— 挖通竖井才能活。")
	_hud.append_log("[color=#8fd3ff]①[/color]顶栏按「功能」挖井、派人　[color=#8fd3ff]②[/color]这里选「对谁说」，再打字")
	_hud.append_log("[color=#8fd3ff]③[/color]「推进时段」×4 = 过一天。看顶栏第三行的提示。")

	# 右侧功能栏默认隐藏，地图整片留给玩家。但首次启动要把分工页拉出来 ——
	# 用户实机反馈「不知道该怎么派人」，说明光有按钮不够。
	# 教程在底栏，所以底栏也先开着；玩家随时可以用「对话」按钮收起。
	_hud.show_bottom_panel()
	_hud.open_job_panel()

	_probe_ai()


func _process(_delta: float) -> void:
	# 事件弹窗打开时冻结角色，避免选选项时人还在走
	if _player != null and _hud != null:
		_player.set_physics_process(not _hud.popup_visible())


# ---------------------------------------------------------------------------
# AI 服务连通性
# ---------------------------------------------------------------------------

## 地图上点了某个人 / 走近按了 E —— 切到那个人并打开对话栏。
## 下拉框和地图是同一个入口的两种走法，所以要互相同步：
## 在地图上点了厨娘，底栏的「对谁说」也要跟着变成厨娘。
func _on_talk_to(cid: String) -> void:
	_hud.focus_speaker(cid)
	_hud.show_bottom_panel()


func _probe_ai() -> void:
	var http := HTTPRequest.new()
	http.timeout = 5.0
	add_child(http)
	http.request_completed.connect(func(result, code, _h, body):
		if result == HTTPRequest.RESULT_SUCCESS and code == 200:
			var info = JSON.parse_string(body.get_string_from_utf8())
			if info is Dictionary and str(info.get("mode", "")) == "live":
				_hud.set_conn("● AI 在线", Color(0.5, 1.0, 0.6))
			else:
				_hud.set_conn("● demo", Color(1.0, 0.85, 0.4))
		else:
			_hud.set_conn("● 离线", Color(1.0, 0.5, 0.5))
		http.queue_free()
	)
	http.request("http://127.0.0.1:%d/health" % _ai_port())


func _ai_port() -> int:
	var p := OS.get_environment("AI_PORT")
	return int(p) if p != "" else 8787


# ---------------------------------------------------------------------------
# 操作
# ---------------------------------------------------------------------------

func _on_dig() -> void:
	var r: Dictionary = _game.start_dig()
	if bool(r["ok"]):
		_hud.append_log("[color=#9fe08a]开工：%s（工期 %d 天）[/color]"
			% [str(r["display"]), int(r["days"])])
	else:
		_hud.append_log("[color=#ff8a8a]%s[/color]" % str(r["reason"]))


func _on_shaft_pressed(index: int) -> void:
	var info: Dictionary = _game.dig_info()
	if int(info["index"]) == index and bool(info["ok"]):
		_on_dig()
	elif int(info["index"]) == index:
		_hud.append_log("[color=#ffd479]%s[/color]" % str(info["reason"]))
	else:
		_hud.append_log("[color=#999999]第 %d 段竖井：%s[/color]"
			% [index, "已通水" if index <= int(_game.query("karez.sections")) else "还没轮到"])


func _on_build(id: String) -> void:
	var r: Dictionary = _game.start_build(id)
	if bool(r["ok"]):
		_hud.append_log("[color=#9fe08a]开工建造：%s（%d 天）[/color]"
			% [str(r["display"]), int(r["days"])])
	else:
		_hud.append_log("[color=#ff8a8a]建造失败：%s[/color]" % str(r["reason"]))


func _on_next_phase() -> void:
	var r: Dictionary = _game.advance_phase()
	if str(r["finished"]) != "":
		_hud.append_log("[color=#ffd479]%s[/color]" % str(r["finished"]))
	if bool(r["day_advanced"]):
		_hud.append_log("[color=#aaaaaa]—— 第 %d 天 · %s ——[/color]"
			% [_game.get_day(), _season_cn(str(_game.query("season")))])
		_maybe_event()


func _on_event_manual() -> void:
	var e: Dictionary = _events.trigger_random()
	if e.is_empty():
		_hud.append_log("[color=#999999]当前没有符合条件的事件（64 条里都还不到触发时机）。[/color]")
		return
	_hud.show_event(e)


func _maybe_event() -> void:
	var day: int = _game.get_day()
	if day - _last_event_day < EVENT_MIN_GAP_DAYS:
		return
	if randf() > EVENT_CHANCE:
		return
	var e: Dictionary = _events.trigger_random()
	if e.is_empty():
		return
	_last_event_day = day
	_hud.show_event(e)


func _on_save() -> void:
	var ok: bool = _game.save_to(SAVE_PATH)
	_hud.append_log("[color=#9fe08a]已存档[/color]" if ok else "[color=#ff8a8a]存档失败[/color]")


func _on_load() -> void:
	var ok: bool = _game.load_from(SAVE_PATH)
	_hud.append_log("[color=#9fe08a]已读档[/color]" if ok else "[color=#ff8a8a]没有找到存档[/color]")


# ---------------------------------------------------------------------------
# 对话
# ---------------------------------------------------------------------------

func _on_say(text: String, speaker_id: String) -> void:
	_hud.append_log("[color=#8fd3ff]你[/color]（对%s）：%s" % [_name_of(speaker_id), text])
	_recent.append("玩家：%s" % text)
	while _recent.size() > 8:
		_recent.pop_front()
	_hud.set_input_enabled(false)
	if not _game.send(text, speaker_id, _recent):
		_hud.set_input_enabled(true)


func _on_response(payload: Dictionary) -> void:
	_hud.set_input_enabled(true)
	var cid := str(payload.get("speaker", ""))
	var name := _name_of(cid)
	_hud.append_narration(name, str(payload.get("narration", "…")), str(payload.get("emotion", "")))
	_recent.append("%s：%s" % [name, str(payload.get("narration", "")).substr(0, 40)])
	while _recent.size() > 8:
		_recent.pop_front()


func _on_failed(reason: String) -> void:
	_hud.set_input_enabled(true)
	_hud.append_log("[color=#ff8a8a]⚠ %s[/color]" % reason)
	_hud.append_log("[color=#888888]  对话需要 AI 服务；其余功能（挖井/建造/推进/事件）离线均可用。[/color]")


func _name_of(cid: String) -> String:
	if cid == "":
		return "旁白"
	return str(NAME_OF.get(cid, cid))


func _season_cn(s: String) -> String:
	return {"spring": "春", "summer": "夏", "autumn": "秋", "winter": "冬"}.get(s, s)
