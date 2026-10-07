extends Node
## 一次性截图工具：验证事件卡的**插画 + 文字布局**。
##
## 重点看两件事：
##   1. 左侧插画有没有显示、比例对不对
##   2. 文字有没有被压到 / 溢出卡片（用户明确要求过：加图不能遮挡已有文字）
## 顺带验证 季节/时段 的取图优先级（冬天该出雪景、夜里该出篝火）。
##
##   tools\Godot_v4.7.2-stable_win64.exe --path scripts res://scenes/capture_event.tscn

const SETTLE_FRAMES := 22

## (用例名, 事件, 季节覆盖, 时段覆盖) —— 覆盖为空表示不改
const CASES := [
	["A_经营", {
		"category": "manage", "title": "葡萄压弯了枝",
		"text": "葡萄结得比预想的多，竹筐都不够用。但熟透的葡萄放不过五天。晾房还没砌完，晒干需要更多柴火。",
		"choices": [
			{"text": "先吃鲜的，办个聚会", "hint": "士气"},
			{"text": "抓紧砌晾房，做成葡萄干", "hint": "长远"},
			{"text": "全卖了，换现钱", "hint": "逐利"},
		],
	}, "spring", "morning"],

	["B_危机", {
		"category": "crisis", "title": "沙暴来了",
		"text": "风在半个时辰里从无到有。天变成了土黄色，太阳成了一个模糊的白点。沙子打得人睁不开眼。有人喊：明渠！",
		"choices": [
			{"text": "全员去保明渠", "hint": "保命线"},
			{"text": "先保房屋和库房", "hint": "务实"},
			{"text": "让所有人进屋里躲", "hint": "人命优先"},
		],
	}, "summer", "afternoon"],

	["C_冬天", {
		"category": "manage", "title": "水怎么分",
		"text": "棉田和瓜田都要水，但井里出的水只够浇一片。种棉能过冬，种瓜能换钱。两边的人已经在地头吵起来了，各说各的理。",
		"choices": [
			{"text": "先保棉田", "hint": "务实"},
			{"text": "先保瓜田", "hint": "逐利"},
			{"text": "按人头平均分", "hint": "公允"},
			{"text": "定下水规，按月轮换", "hint": "制度化"},
		],
	}, "winter", "morning"],

	["D_夜里外交", {
		"category": "diplomacy", "title": "掌柜的开价",
		"text": "陈守业把算盘放在桌上，说他要三十匹布，出价每匹三两。他知道你的布好，也知道你缺钱。他的手指一直按在算珠上没动。",
		"choices": [
			{"text": "接受三两", "hint": "务实"},
			{"text": "坚持四两", "hint": "强硬"},
			{"text": "问他别家给什么价", "hint": "试探"},
			{"text": "只卖十匹，剩下的留着", "hint": "保守"},
		],
	}, "autumn", "night"],
]

var _play: Node
var _gs: Node
var _hud: Node
var _frames := 0
var _idx := 0
var _applied := false


func _ready() -> void:
	_play = load("res://scenes/play.tscn").instantiate()
	add_child(_play)
	_gs = _play.get_node("GameState")
	_hud = _play.get_node("HUDLayer/HUD")
	print("CAPTURE event ready, cases = ", CASES.size())


func _process(_delta: float) -> void:
	_frames += 1
	if _idx >= CASES.size():
		print("CAPTURE event done")
		get_tree().quit()
		return

	if not _applied:
		var case: Array = CASES[_idx]
		# 季节/时段覆盖：验证取图优先级，也让四张不同插画都露一次面
		_gs.state["calendar"]["season"] = str(case[2])
		_gs.state["calendar"]["phase"] = str(case[3])
		_gs.state_changed.emit()
		_hud.show_event(case[1] as Dictionary)
		_applied = true
		_frames = 0
		return

	if _frames >= SETTLE_FRAMES:
		var name: String = str((CASES[_idx] as Array)[0])
		var img := get_viewport().get_texture().get_image()
		var path := "user://event_%s.png" % name
		var err := img.save_png(path)
		print("CAPTURE event_%s.png  err=%s" % [name, str(err)])
		_idx += 1
		_applied = false
		_frames = 0
