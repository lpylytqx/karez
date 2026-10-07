extends Node
## 一次性截图工具：走完整场御敌之战。
##
##   A_布阵前   镜头应当已经飞到东边战场并放大，地面有 6 个布阵空位
##   B_布阵后   自动布阵之后，我方（村民）站到西侧格子上
##   C_交战中   敌军（马匪）入场、双方交手、血条可见
##   D_战果     胜负横幅
##
##   tools\Godot_v4.7.2-stable_win64.exe --path scripts res://scenes/capture_battle.tscn

const SETTLE := 24
const FLY_WAIT := 60          # 镜头飞行 0.55s ≈ 33 帧
const FIGHT_POLL := 900       # 最多等 15 秒让战斗打完

var _play: Node
var _gs: Node
var _battle: Node
var _frames := 0
var _stage := 0
var _fight_frames := 0


func _ready() -> void:
	_play = load("res://scenes/play.tscn").instantiate()
	add_child(_play)
	_gs = _play.get_node("GameState")
	_battle = _play.get_node("Battle")
	# 给一个能打起来的环境：6 人、低治安（会由来袭判定命中）
	_gs.state["population"] = 6
	_gs.state["karez"]["sections"] = 4
	_gs.state["stats"]["security"] = 30.0
	_gs.state_changed.emit()
	print("CAPTURE battle ready  pop=%d security=%.0f day=%d" % [
		int(_gs.query("population")), float(_gs.query("stats.security")),
		int(_gs.query("day"))])
	print("  战场中心 = %s（格 %.1f, %.1f）—— 在原地图 40 格之外" % [
		str(_battle.ARENA_CENTER),
		_battle.ARENA_CENTER.x / 16.0, _battle.ARENA_CENTER.y / 16.0])
	print("  布阵槽位 %d 个，最多上阵 %d 人" % [
		_battle.SLOT_COLS * _battle.SLOT_ROWS, _battle.MAX_FIGHTERS])


func _process(_delta: float) -> void:
	_frames += 1
	match _stage:
		0:
			if _frames >= SETTLE:
				_play._start_raid(false)
				print("\n  已触发：phase=%d（1=布阵）预计上阵 %d 人对 %d 人" % [
					_battle.current_phase(),
					int((_gs.query("population")) - 1), _battle._enemy_count])
				_stage = 1
				_frames = 0
		1:
			# 等镜头真的飞到位再截图 —— 用**帧数**等不可靠：
			# 实测 60 帧时补间才走到 46%（1.46/2.00），直接截会拍到飞行途中。
			# 所以按 zoom 的实际值轮询。
			if _play._cam.zoom.x >= 1.95 or _frames > 240:
				print("  A：镜头 = %s  zoom=%.2f  俯视战场（期望 zoom=2.00）" % [
					str(_play._cam.position), _play._cam.zoom.x])
				_shot("A_布阵前")
				_battle.auto_deploy()
				print("  B：自动布阵后 已布 %d 人，剩余 %d 人" % [
					_battle._placed_count(), _battle._pool])
				_stage = 2
				_frames = 0
		2:
			if _frames >= SETTLE:
				_shot("B_布阵后")
				var ok: bool = _battle.begin_fight()
				print("  C：开战 begin_fight=%s  phase=%d（2=交战）" % [
					str(ok), _battle.current_phase()])
				_stage = 3
				_frames = 0
				_fight_frames = 0
		3:
			_fight_frames += 1
			# 打到一半抓一张（敌军已经入场）
			if _fight_frames == 150:
				print("  交战中：我方存活 %d，敌方存活 %d" % [
					_battle._living(0).size(), _battle._living(1).size()])
				_shot("C_交战中")
			if _battle.current_phase() == 3 or _fight_frames > FIGHT_POLL:
				print("  D：战斗结束 phase=%d（3=战果）  我方存活 %d  敌方存活 %d" % [
					_battle.current_phase(), _battle._living(0).size(),
					_battle._living(1).size()])
				print("    战果 = %s" % str(_battle._result))
				_stage = 4
				_frames = 0
		4:
			if _frames >= SETTLE:
				_shot("D_战果")
				_stage = 5
				_frames = 0
		5:
			print("CAPTURE battle done")
			get_tree().quit()


func _shot(tag: String) -> void:
	var img := get_viewport().get_texture().get_image()
	var err := img.save_png("user://bt_%s.png" % tag)
	print("CAPTURE bt_%s.png  err=%s" % [tag, str(err)])
