extends Node
## 一次性截图工具：加载 map 场景，渲染若干帧后保存 viewport 截图并退出。
## 仅用于验证，不参与正式游戏。

var _frames := 0

func _ready():
	print("CAPTURE user dir: ", ProjectSettings.globalize_path("user://"))
	var map = load("res://scenes/map.tscn").instantiate()
	add_child(map)
	print("CAPTURE map added")

func _process(_delta):
	_frames += 1
	if _frames == 45:
		print("CAPTURE grabbing frame...")
		var img = get_viewport().get_texture().get_image()
		var out = "user://capture.png"
		var err = img.save_png(out)
		print("CAPTURE save result: ", err, " -> ", ProjectSettings.globalize_path(out))
		get_tree().quit()
