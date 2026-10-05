extends Control
## M1 闭环界面：极简对话 + 状态条。
##
## 这一屏的全部意义是证明「输入 → 调 AI → JSON → 状态变化 → 显示」这条管道通了。
## 不要在这里做美术。S2 之后才考虑把它换成真正的游戏界面。

@onready var _log: RichTextLabel = $Margin/Rows/LogPanel/Log
@onready var _input: LineEdit = $Margin/Rows/InputRow/Input
@onready var _send: Button = $Margin/Rows/InputRow/Send
@onready var _suggestions: HBoxContainer = $Margin/Rows/SuggestionRow
@onready var _status: Label = $Margin/Rows/StatusBar/Status
@onready var _speaker: OptionButton = $Margin/Rows/TopRow/Speaker
@onready var _next_day: Button = $Margin/Rows/TopRow/NextDay
@onready var _conn: Label = $Margin/Rows/TopRow/ConnState

var _game: Node
var _recent: Array = []
var _characters: Array = [
	{"id": "lao_kanjiang", "name": "老坎匠"},
	{"id": "muqam_yiren", "name": "木卡姆艺人"},
	{"id": "hasake_qishou", "name": "哈萨克骑手"},
	{"id": "hanshang_zhanggui", "name": "商队掌柜"},
	{"id": "chuniang", "name": "厨娘"},
	{"id": "shenmi_lvren", "name": "神秘旅人"},
	{"id": "mafei_toumu", "name": "马匪头目"},
]


func _ready() -> void:
	_game = get_node("/root/GameState")
	_game.response_received.connect(_on_response)
	_game.request_failed.connect(_on_failed)
	_game.state_changed.connect(_refresh_status)

	for c in _characters:
		_speaker.add_item(c["name"])
	_speaker.selected = 0

	_input.text_submitted.connect(_on_submit)
	_send.pressed.connect(func(): _on_submit(_input.text))
	_next_day.pressed.connect(_on_next_day)

	_log.append_text("[b]《坎儿井》M1 闭环原型[/b]\n")
	_log.append_text("[i]输入你想做的事，或直接和角色说话。[/i]\n")
	_log.append_text("[color=#888888]（当前状态栏为占位实现，M1 只验证 AI 管道是否打通）[/color]\n\n")

	_refresh_status()
	_probe_ai_service()
	_show_suggestions(["先看看第三口竖井", "问问老坎匠这井还有救吗", "派叶尔兰出去探探路"])


# ---------------------------------------------------------------------------
# 与服务连通性探测（不阻塞主流程）
# ---------------------------------------------------------------------------

func _probe_ai_service() -> void:
	var http := HTTPRequest.new()
	http.timeout = 5.0
	add_child(http)
	http.request_completed.connect(func(result, code, _h, body):
		if result == HTTPRequest.RESULT_SUCCESS and code == 200:
			var info = JSON.parse_string(body.get_string_from_utf8())
			if info is Dictionary and info.get("mode", "") == "live":
				_conn.text = "● AI 已接通（%s）" % info.get("model", "?")
				_conn.modulate = Color(0.5, 1.0, 0.6)
			else:
				_conn.text = "● demo 模式（未配置 Key，走预设内容）"
				_conn.modulate = Color(1.0, 0.85, 0.4)
		else:
			_conn.text = "● 未连接 AI 服务（离线降级）"
			_conn.modulate = Color(1.0, 0.5, 0.5)
		http.queue_free()
	)
	http.request("http://127.0.0.1:%d/health" % _ai_port())


func _ai_port() -> int:
	var p := OS.get_environment("AI_PORT")
	return int(p) if p != "" else 8787


# ---------------------------------------------------------------------------
# 交互
# ---------------------------------------------------------------------------

func _on_submit(text: String) -> void:
	var msg := text.strip_edges()
	if msg.is_empty():
		return
	_input.text = ""
	_send.disabled = true

	var cid: String = _characters[_speaker.selected]["id"]
	var cname: String = _characters[_speaker.selected]["name"]

	_log.append_text("[color=#8fd3ff]你[/color]（对%s）：%s\n" % [cname, msg])
	_recent.append("玩家：%s" % msg)

	if not _game.send(msg, cid, _recent):
		# send 返回 false 时 request_failed 已经发过信号，这里不用重复处理
		pass


func _on_next_day() -> void:
	_game.advance_day()
	_log.append_text("[color=#aaaaaa]—— 第 %d 天 ——[/color]\n" % _game.get_day())
	_refresh_status()


func _on_response(payload: Dictionary) -> void:
	_send.disabled = false
	var mode: String = str(payload.get("meta", {}).get("mode", "?"))
	var cid: String = str(payload.get("speaker", ""))
	var cname := _name_of(cid)

	_log.append_text("[b]%s[/b]：" % cname)
	_log.append_text(payload.get("narration", "（无内容）") + "\n")

	var emotion := str(payload.get("emotion", ""))
	if emotion != "":
		_log.append_text("[color=#aaaaaa]（情绪：%s）[/color]\n" % emotion)

	var meta: Dictionary = payload.get("meta", {})
	if meta.has("latency_ms"):
		var extra := ""
		if int(meta.get("dropped_deltas", 0)) > 0:
			extra += "  丢弃越权 delta %d 条" % int(meta["dropped_deltas"])
		if meta.get("mode", "") == "demo":
			extra += "  [降级原因: %s]" % str(meta.get("reason", ""))
		_log.append_text(
			"[color=#666666]   [%s · %.0fms · in %d / out %d · 命中缓存 %d]%s[/color]\n"
			% [mode, float(meta.get("latency_ms", 0)), int(meta.get("tokens_in", 0)),
			   int(meta.get("tokens_out", 0)), int(meta.get("cache_hit_tokens", 0)), extra]
		)

	var delta_count := 0
	var deltas = payload.get("state_delta", [])
	if deltas is Array:
		delta_count = deltas.size()
	if delta_count > 0:
		_log.append_text("[color=#b08cff]   → 状态变化 %d 项[/color]\n" % delta_count)

	_recent.append("%s：%s" % [cname, str(payload.get("narration", "")).substr(0, 40)])
	while _recent.size() > 8:
		_recent.pop_front()

	_log.append_text("\n")
	_log.scroll_to_line(_log.get_line_count())
	_show_suggestions(payload.get("suggestions", []))
	_refresh_status()


func _on_failed(reason: String) -> void:
	_send.disabled = false
	_log.append_text("[color=#ff8a8a]⚠ %s[/color]\n" % reason)
	_log.append_text("[color=#888888]  → 请确认 AI 服务已启动：.venv\\Scripts\\python.exe ai_backend\\main.py[/color]\n\n")
	_log.scroll_to_line(_log.get_line_count())


func _show_suggestions(items) -> void:
	if not (items is Array) or items.is_empty():
		return
	for child in _suggestions.get_children():
		child.queue_free()
	for item in items:
		var btn := Button.new()
		btn.text = str(item)
		btn.add_theme_font_size_override("font_size", 13)
		btn.pressed.connect(func():
			_input.text = str(item)
			_on_submit(str(item))
		)
		_suggestions.add_child(btn)


# ---------------------------------------------------------------------------
# 状态条
# ---------------------------------------------------------------------------

func _refresh_status() -> void:
	var s: Dictionary = _game.state
	var r: Dictionary = s["resources"]
	var st: Dictionary = s["stats"]
	var food_total := 0.0
	for k in r["food"]:
		food_total += float(r["food"][k])

	_status.text = "第 %d 天 · %s   水 %.0f/%.0f（日出水 %.0f）   粮 %.0f   银 %.0f   人 %d   繁荣 %.0f 声望 %.0f 士气 %.0f 安全 %.0f" % [
		_game.get_day(),
		_season_cn(s["calendar"]["season"]),
		float(r["water"]["current"]), float(r["water"]["capacity"]),
		float(s["karez"]["flow_per_day"]),
		food_total, float(r["silver"]), int(s["population"]),
		float(st["prosperity"]), float(st["reputation"]),
		float(st["morale"]), float(st["security"]),
	]


func _season_cn(season: String) -> String:
	return {"spring": "春", "summer": "夏", "autumn": "秋", "winter": "冬"}.get(season, season)


func _name_of(cid: String) -> String:
	for c in _characters:
		if c["id"] == cid:
			return c["name"]
	return "（旁白）" if cid == "" else cid
