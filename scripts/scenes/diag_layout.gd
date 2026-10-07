extends Node
## 一次性诊断：打印视口尺寸与事件卡各控件实际矩形。
##
## 起因：事件卡加了左侧插画后，文字被切在屏幕右缘。
## 怀疑是坐标空间搞错了（HUD 是 640x360 逻辑空间被 2 倍拉伸，还是 1280x720？），
## 直接量出来，不靠目测。
##
## ⚠ 用 _process 帧计数 + quit()，**不要在 _ready 里 await** ——
##    本工程其余截图脚本都是这个写法；之前用 await 那版会挂住不退出。

var _play: Node
var _hud: Node
var _frames := 0
var _done := false


func _ready() -> void:
	_play = load("res://scenes/play.tscn").instantiate()
	add_child(_play)
	_hud = _play.get_node("HUDLayer/HUD")

	print("── 尺寸 ──")
	print("  get_viewport().size           = ", get_viewport().size)
	print("  get_visible_rect().size       = ", get_viewport().get_visible_rect().size)
	print("  window_get_size               = ", DisplayServer.window_get_size())
	print("  viewport_width/height 设置    = ",
		ProjectSettings.get_setting("display/window/size/viewport_width"), " x ",
		ProjectSettings.get_setting("display/window/size/viewport_height"))
	print("  stretch/mode                  = ",
		ProjectSettings.get_setting("display/window/stretch/mode"))
	print("  content_scale_* (运行时)      = ",
		get_window().content_scale_size, "  mode=", get_window().content_scale_mode)
	print("  HUD size                      = ", _hud.size)


func _process(_delta: float) -> void:
	_frames += 1
	if _done:
		return
	# 第 2 帧弹事件卡，第 6 帧量尺寸（留几帧让容器完成布局）
	if _frames == 2:
		_hud.show_event({
			"category": "manage", "title": "布局诊断",
			"text": "这一段用来诊断文字有没有被切掉。它足够长，会换行到第二行甚至第三行，"
				+ "以便看清 RichTextLabel 的实际可用宽度与右边界落在哪里，"
				+ "以及它和卡片右边缘、屏幕右边缘之间的关系。",
			"choices": [{"text": "选项一"}, {"text": "选项二"}],
		})
	elif _frames >= 8:
		print("\n── 事件卡控件矩形（绝对坐标）──")
		_dump(_hud, 0)
		_done = true
		get_tree().quit()


func _dump(n: Node, depth: int) -> void:
	for c in n.get_children():
		if c is Control and c.visible:
			var r: Rect2 = c.get_global_rect()
			var extra := ""
			if c is RichTextLabel:
				extra = "  [文本宽=%d 行数=%d 字符=%d]" % [
					int(c.size.x), c.get_line_count(), c.get_total_character_count()]
			if c is TextureRect:
				extra = "  [tex=%s]" % ("有" if c.texture != null else "无")
			print("  %s%s '%s'  pos=(%.0f,%.0f) size=(%.0f,%.0f)%s" % [
				"  ".repeat(depth), c.get_class(), c.name,
				r.position.x, r.position.y, r.size.x, r.size.y, extra])
		_dump(c, depth + 1)
