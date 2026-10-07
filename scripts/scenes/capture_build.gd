extends Node
## 一次性截图工具：验证「建成后地图上到底出不出来」。
##
## 场景设计得很刻意：**坎儿井段数保持 0**。
## 马厩的门槛是 sections>=2，所以段数为 0 时它本来绝不该出现 ——
## 如果建完之后它出现了，就说明「已建成」这个条件真的生效了，
## 而不是碰巧被门槛放行。
##
## ⚠ 两套 id 必须分清（这正是被修的那个 bug 本身）：
##     place_present() 收的是 **sites.gd 的地标键**，马厩是 "stable"
##     start_build()   收的是 **numbers.json 的 building id**，马厩是 "majiu"
##   第一版测试给 place_present 传了 "majiu"，它在 PLACES 里查不到就直接返回 false，
##   看起来像"修复没生效"，其实是用错了键。下面两个都打印出来做对照。
##
##   tools\Godot_v4.7.2-stable_win64.exe --path scripts res://scenes/capture_build.tscn

const SETTLE_FRAMES := 20
const ADVANCE_DAYS := 6      # 马厩工期 2 天；2 人治水时约 3 天完工，推进 6 天留足余量
const SITE_KEY := "stable"   # sites.gd 的地标键
const BUILD_ID := "majiu"    # numbers.json 的建筑 id

var _play: Node
var _gs: Node
var _hud: Node
var _frames := 0
var _stage := 0


func _ready() -> void:
	_play = load("res://scenes/play.tscn").instantiate()
	add_child(_play)
	_gs = _play.get_node("GameState")
	_hud = _play.get_node("HUDLayer/HUD")
	_hud.visible = false          # 只看地图，别让面板挡住
	# 材料给够（这是验证脚本，不是玩法，绕过造价校验是有意的）
	_gs.state["resources"]["materials"]["wood"] = 300.0
	_gs.state["resources"]["materials"]["earth"] = 500.0
	_gs.state["resources"]["materials"]["tools"] = 12.0
	print("CAPTURE build ready  sections=%d" % int(_gs.query("karez.sections")))
	print("  地标键=%s  建筑 id=%s  翻译结果=%s" % [
		SITE_KEY, BUILD_ID, Sites.building_id_of(SITE_KEY)])
	print("  马厩门槛 = sections>=2；本用例刻意保持 0 段")
	print("  place_present(%s) 建前 = %s  ← 地图就是拿这个键来查的" % [
		SITE_KEY, str(_gs.place_present(SITE_KEY))])


func _process(_delta: float) -> void:
	_frames += 1
	match _stage:
		0:
			if _frames >= SETTLE_FRAMES:
				_shot("A_建前")
				_stage = 1
				_frames = 0
		1:
			var r: Dictionary = _gs.start_build(BUILD_ID)
			print("\n  开始建造马厩（id=%s）：ok=%s reason=%s 工期=%s 天" % [
				BUILD_ID, str(r.get("ok", false)), str(r.get("reason", "")),
				str(r.get("days", "?"))])
			_stage = 2
			_frames = 0
		2:
			# 一天一天推进，等完工
			for i in range(ADVANCE_DAYS):
				_gs.advance_day()
			var built: bool = _gs.state.get("buildings", {}).has(BUILD_ID)
			print("  推进 %d 天后：state[buildings] 里有 %s = %s" % [
				ADVANCE_DAYS, BUILD_ID, str(built)])
			print("  place_present(%s) 建后 = %s   ← 期望 true" % [
				SITE_KEY, str(_gs.place_present(SITE_KEY))])
			print("  坎儿井段数仍为 %d（没有靠门槛放行）" % int(_gs.query("karez.sections")))
			_gs.state_changed.emit()
			_stage = 3
			_frames = 0
		3:
			if _frames >= SETTLE_FRAMES:
				_shot("B_建后")
				_stage = 4
				_frames = 0
		4:
			print("CAPTURE build done")
			get_tree().quit()


func _shot(tag: String) -> void:
	var img := get_viewport().get_texture().get_image()
	var path := "user://build_%s.png" % tag
	var err := img.save_png(path)
	print("CAPTURE build_%s.png  err=%s" % [tag, str(err)])
