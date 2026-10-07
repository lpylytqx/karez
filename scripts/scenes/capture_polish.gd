extends Node
## 一次性截图工具：验证这一轮的四处改动。
##
##   A_新散布     沙漠灌木/绿洲草丛（原来的"绿色方块"应当消失）
##   B_涝坝低水位  水量 10% → 应取 reservoir_lv1
##   C_涝坝满水位  水量 95% → 应取 reservoir_lv4
##   D_换季闪光    强制换季 → 抓一帧色罩（验证过渡确实盖住了整屏）
##
##   tools\Godot_v4.7.2-stable_win64.exe --path scripts res://scenes/capture_polish.tscn

const SETTLE_FRAMES := 18
const FLASH_WAIT := 8        # 闪光盖上大约需要 0.35s ≈ 21 帧，这里取中途

var _play: Node
var _gs: Node
var _map: Node
var _atmo: Node
var _frames := 0
var _stage := 0


func _ready() -> void:
	_play = load("res://scenes/play.tscn").instantiate()
	add_child(_play)
	_gs = _play.get_node("GameState")
	_map = _play.get_node("MapView")
	_atmo = _play.get_node("Atmosphere")
	# 4 段：巴扎/晾房都出现；材料给够
	_gs.state["karez"]["sections"] = 4
	_gs.state["resources"]["materials"]["wood"] = 300.0
	_gs.state["resources"]["materials"]["earth"] = 400.0
	_gs.state_changed.emit()
	print("CAPTURE polish ready  sections=%d" % int(_gs.query("karez.sections")))
	print("  储水上限 = %.0f（基础 × 仓库 %.2f）" % [
		_gs.water_capacity(), _gs.facility_effect("cangku", "storage_multiplier", 1.0)])
	print("  人口上限 = %d" % _gs.population_capacity())
	print("  设施在场情况：")
	for bid in ["cangku", "chufang", "majiu", "yiguan", "bazha", "zuofang", "liangfang", "fengsui"]:
		print("    %-10s has_facility=%s" % [bid, str(_gs.has_facility(bid))])
	print("  设施效果取值：")
	print("    厨房 food_efficiency   = %.3f" % _gs.facility_effect("chufang", "food_efficiency", 1.0))
	print("    巴扎 trade_commission  = %.3f" % _gs.facility_effect("bazha", "trade_commission_rate", 0.0))
	print("    作坊 craft_efficiency  = %.3f" % _gs.facility_effect("zuofang", "craft_efficiency", 1.0))


func _process(_delta: float) -> void:
	_frames += 1
	match _stage:
		0:
			if _frames >= SETTLE_FRAMES:
				print("\n  A 阶段：水位 %.0f%% → reservoir_level=%d" % [
					_water_pct(), _gs.reservoir_level()])
				_shot("A_新散布")
				# 把水放到 10%
				_low_water(0.10)
				_stage = 1
				_frames = 0
		1:
			if _frames >= SETTLE_FRAMES:
				print("  B 阶段：水位 %.0f%% → reservoir_level=%d（期望 1）" % [
					_water_pct(), _gs.reservoir_level()])
				_shot("B_涝坝低水位")
				_low_water(0.95)
				_stage = 2
				_frames = 0
		2:
			if _frames >= SETTLE_FRAMES:
				print("  C 阶段：水位 %.0f%% → reservoir_level=%d（期望 4）" % [
					_water_pct(), _gs.reservoir_level()])
				_shot("C_涝坝满水位")
				# 强制换季：直接改 season 再广播，play.gd 会放闪光
				_gs.state["calendar"]["season"] = "winter"
				_gs.state_changed.emit()
				_stage = 3
				_frames = 0
		3:
			if _frames >= FLASH_WAIT:
				print("  D 阶段：换季后色罩 visible=%s alpha=%.2f" % [
					str(_play._fade.visible), _play._fade.color.a])
				_shot("D_换季闪光")
				_stage = 4
				_frames = 0
		4:
			print("CAPTURE polish done")
			get_tree().quit()


func _water_pct() -> float:
	var w: Dictionary = _gs.state["resources"]["water"]
	return 100.0 * float(w["current"]) / maxf(1.0, float(w["capacity"]))


func _low_water(ratio: float) -> void:
	var w: Dictionary = _gs.state["resources"]["water"]
	w["current"] = float(w["capacity"]) * ratio
	_gs.state_changed.emit()
	_map.refresh()


func _shot(tag: String) -> void:
	var img := get_viewport().get_texture().get_image()
	var err := img.save_png("user://polish_%s.png" % tag)
	print("CAPTURE polish_%s.png  err=%s" % [tag, str(err)])
