extends Node
## 诊断：底栏第一行文字为什么被遮挡。
## 不猜，把底栏里每个 Control 的实际矩形、字号、文本都打出来，
## 再和底栏自己的矩形对照 —— 超出上边界的那个就是被切的那个。

var _play: Node


func _ready() -> void:
	_play = load("res://scenes/play.tscn").instantiate()
	add_child(_play)
	# 等一帧让 HUD 建好
	await get_tree().process_frame
	await get_tree().process_frame

	var hud: Control = _play.get_node("HUDLayer/HUD")
	if hud.has_method("show_bottom_panel"):
		hud.show_bottom_panel()
	await get_tree().process_frame

	print("DIAG ── 底栏内容 ──")
	for child in hud.get_children():
		_dump(child, hud, 0)

	print("DIAG ── 结束 ──")
	get_tree().quit()


func _dump(node: Node, hud: Control, depth: int) -> void:
	if node is Control:
		var c := node as Control
		if not c.visible:
			return
		var txt := ""
		if c is Label:
			txt = (c as Label).text.replace("\n", " ⏎ ")
		elif c is Button:
			txt = (c as Button).text
		elif c is LineEdit:
			txt = "[" + (c as LineEdit).placeholder_text + "]"
		elif c is OptionButton:
			txt = "[下拉]"
		var r := c.get_global_rect()
		# 不过滤 —— 底栏整块 y 296..360，任何落在这附近的都要看到，
		# 尤其是"上边缘探出面板之外"的那一行（那才是被切的那个）。
		if c is Label or c is Button or c is LineEdit or c is OptionButton:
			var flag := ""
			if r.position.y < 300.0 and r.position.y + r.size.y > 260.0:
				flag = "   ⚠ 探出面板上边界"
			if r.position.y + r.size.y > 360.0:
				flag = "   ⚠ 超出画面底边"
			if r.size.y < 16.0:
				flag += "   ⚠ 高度不足"
			print("DIAG   %-12s x=%4.0f y=%4.0f w=%4.0f h=%3.0f  %s%s" % [
				c.get_class(), r.position.x, r.position.y, r.size.x, r.size.y, txt, flag])
	for ch in node.get_children():
		_dump(ch, hud, depth + 1)
