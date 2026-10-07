extends Node
## 标题画面键位用例的**探针** —— 真正干活的节点。
##
## 为什么要单开一个文件、还要由另一个节点把它挂到 root 上：
##   `change_scene_to_file()` 会释放**当前场景**。如果测试逻辑写在当前场景的根节点里，
##   它自己就会被一起 free —— 现象是"Timer 不在场景树里"，或者更糟：进程卡住不退出。
##   （第一次写这个用例就踩了：把自身节点当成"可以挪走"的，但它就是旧场景本身。）
##
##   所以：探针必须**新建、挂到 root**，与旧场景无父子关系，切场景时不受影响。

var _tree: SceneTree
var _fails := 0


func _ready() -> void:
	_tree = get_tree()
	var t := Timer.new()
	t.wait_time = 1.0
	t.one_shot = true
	add_child(t)
	t.timeout.connect(_run)
	t.start()


func _ok(cond: bool, label: String) -> void:
	if cond:
		print("[键测] ✓ %s" % label)
	else:
		_fails += 1
		print("[键测] ✗ %s" % label)


func _send_key(kc: int) -> void:
	for down in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = kc
		ev.physical_keycode = kc
		ev.pressed = down
		Input.parse_input_event(ev)


func _send_mouse() -> void:
	for down in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = down
		Input.parse_input_event(ev)


func _cur() -> String:
	var s := _tree.current_scene
	return "" if s == null else s.scene_file_path


func _run() -> void:
	var c := _cur()
	print("[键测] 当前场景：%s" % c)
	if not c.ends_with("title.tscn"):
		print("[键测] ✗ 没能切到标题画面，用例无法进行")
		_tree.quit()
		return

	# ① 空格：不该进（录视频时最容易误碰的键）
	_send_key(KEY_SPACE)
	await _tree.create_timer(0.4).timeout
	_ok(_cur().ends_with("title.tscn"), "① 按空格 → 仍停在标题画面")

	# ② 鼠标左键：不该进（原来点一下就跳走）
	_send_mouse()
	await _tree.create_timer(0.4).timeout
	_ok(_cur().ends_with("title.tscn"), "② 点鼠标 → 仍停在标题画面")

	# ③ 字母键：不该进
	_send_key(KEY_A)
	await _tree.create_timer(0.4).timeout
	_ok(_cur().ends_with("title.tscn"), "③ 按 A 键 → 仍停在标题画面")

	# ④ Enter：应该进
	_send_key(KEY_ENTER)
	await _tree.create_timer(1.0).timeout
	_ok(_cur().ends_with("play.tscn"), "④ 按 Enter → 切到 play.tscn")

	print("[键测] 用例结束，失败 %d 项" % _fails)
	_tree.quit()
