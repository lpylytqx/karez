extends Control
## 标题画面：启动先看到封面，**按 Enter 键**进游戏。
##
## 为什么补这个：原来 `main_scene` 直接指向 play.tscn —— 双击就掉进游戏里，
## 玩家没有"这是哪款游戏"的第一眼。展示和评审时这一眼很重要。
##
## 坐标全按 640x360 逻辑空间（与游戏其余部分一致），封面按 contain 铺满。
## 只有 Enter 能进 —— 鼠标与手柄按钮都不放行（录视频时误碰会跳走）。

const PLAY_SCENE := "res://scenes/play.tscn"
## ⚠ 注意：res://ui/ 是 **HUD 脚本目录**，不是 assets/ui ——
##   项目根是 scripts/，美术靠 junction 暴露（见 scripts/tiles 等）。
##   这里用专门加的 ui_art junction，别再写成 res://ui/。
const COVER := "res://ui_art/cover_title_640x360.png"

var _hint: Label
var _t := 0.0
var _started := false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var bg := TextureRect.new()
	bg.texture = load(COVER)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(bg)

	# 底部渐暗条，保证提示语在任何底图上都读得清
	var shade := ColorRect.new()
	shade.color = Color(0.10, 0.08, 0.06, 0.55)
	shade.position = Vector2(0, 306)
	shade.size = Vector2(640, 54)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	_hint = Label.new()
	_hint.text = "按 Enter 键开始"
	_hint.add_theme_font_size_override("font_size", 15)
	_hint.add_theme_color_override("font_color", Color(0.95, 0.90, 0.80))
	_hint.add_theme_color_override("font_shadow_color", Color(0.08, 0.06, 0.04))
	_hint.add_theme_constant_override("shadow_offset_x", 1)
	_hint.add_theme_constant_override("shadow_offset_y", 1)
	_hint.position = Vector2(0, 322)
	_hint.size = Vector2(640, 22)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hint)

	# 若 AI 服务没连上，在这一页就说清楚 —— 免得玩家以为是游戏坏了
	var offline := Label.new()
	offline.text = "AI 服务未连接时游戏仍可完整游玩（对话走预设兜底）"
	offline.add_theme_font_size_override("font_size", 9)
	offline.add_theme_color_override("font_color", Color(0.72, 0.66, 0.58))
	offline.position = Vector2(0, 341)
	offline.size = Vector2(640, 14)
	offline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	offline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(offline)


func _process(delta: float) -> void:
	# 提示语呼吸式明灭，让人知道该动手了
	_t += delta
	if _hint != null:
		_hint.modulate.a = 0.55 + 0.45 * absf(sin(_t * 1.8))


func _unhandled_input(event: InputEvent) -> void:
	if _started:
		return
	# ⚠ **只认 Enter**（主键盘与小键盘的回车都收），鼠标与手柄按钮不放行。
	#   原来这里是「任意键 / 点鼠标 / 手柄按钮都进游戏」——
	#   录演示视频时鼠标一动、误碰一个键就跳走了，只能重来。
	#   文案与实现必须一致：屏幕上写「按 Enter 键开始」，那就只有 Enter 能用。
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	# ⚠ event.keycode 是 Variant，写 := 会解析报错
	var k: int = event.keycode
	if k != KEY_ENTER and k != KEY_KP_ENTER:
		return
	_started = true
	get_tree().change_scene_to_file(PLAY_SCENE)
