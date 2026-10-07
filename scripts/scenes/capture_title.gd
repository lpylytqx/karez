extends Node
## 截图核对标题画面，并验证「按任意键 → 进游戏」这条跳转真的通。
##
## ⚠ 踩过的坑：`change_scene_to_file()` 会释放**当前场景**，而这个截图脚本自己
##   就是当前场景 —— 切完之后 `self` 已经被 free，`get_tree()` 变成 null，
##   脚本卡死（第一次跑就是这么卡住的）。
##   改法：探针节点挂到 `root`（不随场景切换销毁），并在闭包里**捕获 tree 引用**
##   而不是回头调 `self`。

var _title: Node


func _ready() -> void:
	var tree := get_tree()
	_title = load("res://scenes/title.tscn").instantiate()
	add_child(_title)
	for i in range(24):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	tree.root.get_viewport().get_texture().get_image().save_png("user://title_A_封面.png")
	print("  已截图 title_A_封面")

	# 探针：挂到 root 上，切场景后仍然活着
	var timer := Timer.new()
	timer.wait_time = 1.5
	timer.one_shot = true
	tree.root.add_child(timer)
	timer.timeout.connect(func() -> void:
		var p := ""
		if tree.current_scene != null:
			p = str(tree.current_scene.scene_file_path)
		print("  按空格后：current_scene = %s" % p)
		if p.ends_with("play.tscn"):
			print("  [PASS] 标题页 -> 游戏 跳转正常")
		else:
			print("  [FAIL] 没有跳到 play.tscn")
		tree.quit(0 if p.ends_with("play.tscn") else 1))
	timer.start()

	# 模拟真实按键：走 _unhandled_input，而不是直接调函数
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_SPACE
	ev.pressed = true
	Input.parse_input_event(ev)
