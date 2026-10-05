extends Node
## Godot 客户端 → 真实 AI 服务的端到端测试。
##
## 与 tests/logic_test.tscn 的分工：
##   logic_test.tscn      纯本地逻辑，不需要 AI 服务
##   live_client_test.tscn 走完整的游戏客户端路径：GameState.send() → HTTP → Python → DeepSeek
##
## 为什么要单独测这一层：前面用 curl / Python 直接打 HTTP 通了，
## 并不能证明**游戏客户端**这条路通 —— 载荷结构、URL 拼接、
## 响应解析都可能与手写请求不同。
##
## 运行（需要 AI 服务已启动，且 .env 里 Key 可用）：
##   tools\Godot_v4.7.2-stable_win64.exe --headless --path scripts res://tests/live_client_test.tscn

const TIMEOUT_FRAMES := 60 * 60  # 约 60 秒（60fps 估算；无头下按帧推进）

var _game: Node
var _frames := 0
var _sent := false
var _got := false
var _failed := ""
var _payload: Dictionary = {}


func _ready() -> void:
	print("=".repeat(62))
	print("  Godot 客户端 → 真实 AI 端到端测试")
	print("=".repeat(62))

	_game = load("res://core/game_state.gd").new()
	_game.name = "GameState"
	add_child(_game)

	_game.response_received.connect(func(p):
		_got = true
		_payload = p
	)
	_game.request_failed.connect(func(reason):
		_failed = reason
	)

	# 先播一条承诺，验证「本地兜底」在真实路径上也生效
	_game.add_memory("lao_kanjiang", "答应过要修好那把松头的镢头", "promise")

	print("")
	print("  → 发送：老坎匠，我上次答应你的事，还记得吗")
	print("    携带记忆 %d 条，承诺 %d 条" % [
		_game.get_memory("lao_kanjiang").size(),
		_game.get_promises("lao_kanjiang").size(),
	])
	if not _game.send("老坎匠，我上次答应你的事，还记得吗", "lao_kanjiang", []):
		_failed = "send() 直接返回 false"


func _process(_delta: float) -> void:
	if not _sent:
		_sent = true
	_frames += 1

	if _got:
		_report()
		get_tree().quit(0)
		return
	if _failed != "":
		print("")
		print("  ✗ 请求失败：%s" % _failed)
		print("    请确认 AI 服务已启动：.venv\\Scripts\\python.exe ai_backend\\main.py")
		print("=".repeat(62))
		get_tree().quit(1)
		return
	if _frames > TIMEOUT_FRAMES:
		print("")
		print("  ✗ 超时（%d 帧）未收到响应" % TIMEOUT_FRAMES)
		print("=".repeat(62))
		get_tree().quit(1)


func _report() -> void:
	var meta: Dictionary = _payload.get("meta", {})
	print("")
	print("  ✓ 收到响应")
	print("    mode=%s  model=%s  延迟 %.0fms" % [
		str(meta.get("mode", "?")), str(meta.get("model", "?")),
		float(meta.get("latency_ms", 0))])
	print("    tokens in/out = %d/%d   finish=%s" % [
		int(meta.get("tokens_in", 0)), int(meta.get("tokens_out", 0)),
		str(meta.get("finish_reason", "?"))])
	print("")
	print("    角色回复：%s" % str(_payload.get("narration", "（空）")))
	print("    情绪：%s   意图：%s" % [
		str(_payload.get("emotion", "?")),
		str(_payload.get("intent", {}).get("type", "?"))])

	var deltas = _payload.get("state_delta", [])
	print("    state_delta：%s" % (str(deltas) if deltas.size() > 0 else "（空）"))

	print("")
	print("  ── 可信度检查 ──")
	var mode := str(meta.get("mode", ""))
	if mode == "live":
		print("    [PASS] 走的是 live 模式（真实调用了 DeepSeek）")
	else:
		print("    [FAIL] mode=%s，落到兜底了" % mode)
	if str(_payload.get("narration", "")).strip_edges() != "":
		print("    [PASS] 有叙事文本")
	else:
		print("    [FAIL] 叙事文本为空")
	if meta.get("dropped_deltas", 0) == 0:
		print("    [PASS] 没有 delta 被门禁丢弃")
	else:
		print("    [WARN] 丢弃了 %d 条 delta（说明模型给了非法数值，门禁正常工作）"
			% int(meta["dropped_deltas"]))

	print("=".repeat(62))
