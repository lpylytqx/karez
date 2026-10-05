extends Node2D
## 地图渲染 —— 绿洲随坎儿井段数生长。
##
## 这一版与之前的关键区别：地形不再由写死的几何距离决定，而是由
## GameState 的 karez.sections 决定。每挖通一段竖井，绿洲半径扩大一圈，
## 玩家能直接看到「治水」的成果 —— 这是 S2 阶段的核心可演示点。
##
## 地图规格：640x360 逻辑分辨率，16x16 tile，40x22 格。
##
## 布局约束（实机截图后修正，务必遵守）：
##   • 顶栏占 y 0..15，底栏占 y 296..360，右栏占 x 536..640 —— 这些区域不要放东西
##   • 建筑贴图不是 16x16：竖井 32x32、驿馆/涝坝 64x64、马厩/仓库 48x48
##     所以间距必须按贴图实际尺寸算，不能一律按格子数

signal shaft_pressed(index: int)

const TILE := 16
const COLS := 40
const ROWS := 22

## 段数 -> 绿洲半径（单位：格）。
const OASIS_RADIUS := [3.2, 4.8, 6.2, 7.6, 9.0, 10.4, 11.8]

const TERRAIN_TEX := {
	"desert": ["res://tiles/terrain/desert_light_01.png", "res://tiles/terrain/desert_light_02.png"],
	"sparse": ["res://tiles/terrain/grass_sparse_01.png", "res://tiles/terrain/grass_sparse_02.png"],
	"medium": ["res://tiles/terrain/grass_medium_01.png", "res://tiles/terrain/grass_medium_02.png"],
	"lush":   ["res://tiles/terrain/grass_lush_01.png", "res://tiles/terrain/grass_lush_02.png"],
}

## 竖井链：从聚落斜向北（往山里去）。
## 走斜线而不是垂直一列，是因为竖井贴图是 32x32 —— 若间隔只有 2 格（32px）
## 会边贴边连成一条实心柱子（实机截图确认过）。斜向的对角距离约 45px，能分清每一口。
const SHAFT_GX0 := 25
const SHAFT_GY0 := 15
const SHAFT_DX := -1
const SHAFT_DY := -2
const MAX_SHAFTS := 6

## 农田块（格）—— 16x16，可以紧排
const FIELD_X0 := 14
const FIELD_Y0 := 11
const FIELD_COLS := 5
const FIELD_ROWS := 3

var _game: Node = null

var _terrain_root: Node2D
var _prop_root: Node2D
var _shaft_root: Node2D

var _tex_cache := {}
var _rng := RandomNumberGenerator.new()
## [{index:int, pos:Vector2, sprite:Sprite2D}]
var _shaft_nodes: Array = []


func _ready() -> void:
	_rng.seed = 20261005
	_terrain_root = Node2D.new()
	_terrain_root.name = "Terrain"
	add_child(_terrain_root)
	_prop_root = Node2D.new()
	_prop_root.name = "Props"
	add_child(_prop_root)
	_shaft_root = Node2D.new()
	_shaft_root.name = "Shafts"
	_shaft_root.z_index = 5
	add_child(_shaft_root)
	refresh()


## 由场景注入 GameState 并订阅状态变化。
func setup(game: Node) -> void:
	_game = game
	if _game != null and not _game.state_changed.is_connected(refresh):
		_game.state_changed.connect(refresh)
	refresh()


func _get_tex(path: String) -> Texture2D:
	if not _tex_cache.has(path):
		_tex_cache[path] = load(path)
	return _tex_cache[path]


func _clear(node: Node) -> void:
	for c in node.get_children():
		c.queue_free()


# ---------------------------------------------------------------------------
# 对外：绿洲与竖井的几何
# ---------------------------------------------------------------------------

func oasis_radius() -> float:
	var lv := 0
	if _game != null:
		lv = int(_game.oasis_level())
	lv = clampi(lv, 0, OASIS_RADIUS.size() - 1)
	return float(OASIS_RADIUS[lv])


## 第 i 段竖井的格子坐标（i 从 1 开始）。
func shaft_grid(i: int) -> Vector2i:
	var k := i - 1
	return Vector2i(SHAFT_GX0 + k * SHAFT_DX, SHAFT_GY0 + k * SHAFT_DY)


## 第 i 段竖井的像素中心。
func shaft_center(i: int) -> Vector2:
	var g := shaft_grid(i)
	return Vector2(g.x * TILE + TILE * 0.5, g.y * TILE + TILE * 0.5)


## 命中测试：返回被点中的竖井段号（0 表示没点中）。
func shaft_at(world_pos: Vector2) -> int:
	for s in _shaft_nodes:
		if world_pos.distance_to(s["pos"]) <= 16.0:
			return int(s["index"])
	return 0


# ---------------------------------------------------------------------------
# 重建
# ---------------------------------------------------------------------------

func refresh() -> void:
	if _terrain_root == null:
		return
	_rng.seed = 20261005
	_clear(_terrain_root)
	_clear(_prop_root)
	_clear(_shaft_root)
	_shaft_nodes.clear()
	_build_terrain()
	_place_props()
	_build_shafts()


func _terrain_key(d: float, r: float) -> String:
	if d < r * 0.55:
		return "lush"
	elif d < r * 0.78:
		return "medium"
	elif d < r:
		return "sparse"
	return "desert"


func _build_terrain() -> void:
	var cx := COLS / 2.0
	var cy := ROWS / 2.0 + 1.0
	var r := oasis_radius()
	for y in range(ROWS):
		for x in range(COLS):
			var d := Vector2(x - cx, y - cy).length()
			var key := _terrain_key(d, r)
			# 绿洲边缘不规则化，避免出现完美的圆
			if key == "sparse" and _rng.randf() < 0.35:
				key = "desert"
			elif key == "desert" and d < r + 1.5 and _rng.randf() < 0.20:
				key = "sparse"
			var paths: Array = TERRAIN_TEX[key]
			var sp := Sprite2D.new()
			sp.texture = _get_tex(str(paths[_rng.randi() % paths.size()]))
			sp.centered = false
			sp.position = Vector2(x * TILE, y * TILE)
			_terrain_root.add_child(sp)


func _add_prop(path: String, gx: float, gy: float, z := 1) -> Sprite2D:
	var sp := Sprite2D.new()
	sp.texture = _get_tex(path)
	sp.centered = true
	sp.position = Vector2(gx * TILE, gy * TILE)
	sp.z_index = z
	_prop_root.add_child(sp)
	return sp


## 该位置是否被农田 / 聚落 / 竖井走廊占用（用于植被散布避让）。
func _is_reserved(ax: float, ay: float) -> bool:
	if ax > FIELD_X0 - 1.0 and ax < FIELD_X0 + FIELD_COLS + 1.0 \
			and ay > FIELD_Y0 - 1.0 and ay < FIELD_Y0 + FIELD_ROWS + 1.0:
		return true
	if ay > 14.0:
		return true
	if ax > 33.0:
		return true
	for i in range(1, MAX_SHAFTS + 1):
		var g := shaft_grid(i)
		if Vector2(ax - g.x, ay - g.y).length() < 1.9:
			return true
	return false


func _place_props() -> void:
	var lv := 0
	if _game != null:
		lv = int(_game.oasis_level())

	# ── 聚落（南侧一排，位置按贴图实际尺寸错开，避免相互压盖）──
	_add_prop("res://buildings/warehouse_01.png", 7, 17)     # 48x48 仓库
	_add_prop("res://buildings/reservoir_01.png", 12, 16.5)  # 64x64 涝坝
	_add_prop("res://buildings/campfire_01.png", 17, 17)     # 32x32 营火
	_add_prop("res://buildings/bazar_stall_red.png", 19, 17)
	_add_prop("res://buildings/bazar_stall_blue.png", 21, 17)
	_add_prop("res://buildings/inn_01.png", 26, 16.5)        # 64x64 驿馆
	_add_prop("res://buildings/kitchen_01.png", 4, 15)
	_add_prop("res://buildings/grape_drying_01.png", 30, 13) # 48x64 晾房

	# ── 随绿洲等级逐步出现的建筑：绿洲越大，聚落越像样 ──
	if lv >= 3:
		_add_prop("res://buildings/stable_01.png", 31, 17)   # 48x48 马厩
	if lv >= 4:
		_add_prop("res://buildings/watchtower_sand_01.png", 2, 12)
	if lv >= 5:
		_add_prop("res://buildings/shop_01.png", 6, 14)
		_add_prop("res://buildings/workshop_01.png", 33, 15)

	# ── 农田：坎儿井通水后才出现（水决定能种多少地）──
	var slots: Array = []
	for r in range(FIELD_ROWS):
		for c in range(FIELD_COLS):
			slots.append(Vector2i(FIELD_X0 + c, FIELD_Y0 + r))
	var fields := clampi(lv * 2, 0, slots.size())
	var crops := [
		"res://tiles/farmland/crop_stage_1_seedling.png",
		"res://tiles/farmland/crop_stage_2_sprout.png",
		"res://tiles/farmland/crop_stage_3_growing.png",
		"res://tiles/farmland/crop_stage_4_ripe.png",
	]
	for i in range(fields):
		var g: Vector2i = slots[i]
		_add_prop("res://tiles/farmland/soil_tilled_a.png", g.x, g.y)
		var stage := clampi(int(round(float(i) / maxf(1.0, float(fields - 1)) * 3.0)), 0, 3)
		_add_prop(str(crops[stage]), g.x, g.y, 2)

	# ── 绿洲内植被 ──
	var r := oasis_radius()
	var cx := COLS / 2.0
	var cy := ROWS / 2.0 + 1.0
	var greens := [
		"res://tiles/nature/tree_green_01.png",
		"res://tiles/nature/tree_palm_01.png",
		"res://tiles/nature/tree_small_01.png",
		"res://tiles/nature/bush_01.png",
	]
	var flowers := ["res://tiles/nature/flower_01.png", "res://tiles/nature/grass_tuft_01.png"]
	var placed := 0
	var target := int(r * 2.6)
	var guard := 0
	while placed < target and guard < 600:
		guard += 1
		var ax := _rng.randf_range(cx - r, cx + r)
		var ay := _rng.randf_range(cy - r, cy + r)
		if Vector2(ax - cx, ay - cy).length() > r * 0.95:
			continue
		if _is_reserved(ax, ay):
			continue
		if _rng.randf() < 0.25:
			_add_prop(flowers[_rng.randi() % flowers.size()], ax, ay)
		else:
			_add_prop(greens[_rng.randi() % greens.size()], ax, ay)
		placed += 1

	# ── 沙漠枯树：绿洲外的荒芜对照 ──
	for g in [Vector2i(6, 8), Vector2i(34, 7), Vector2i(20, 2), Vector2i(14, 19),
			Vector2i(3, 19), Vector2i(36, 19)]:
		_add_prop("res://tiles/nature/tree_dead_01.png", g.x, g.y)

	# ── 明渠：涝坝往东引水，末端接农田 ──
	if lv >= 1:
		for i in range(clampi(lv, 1, 4)):
			_add_prop("res://tiles/water/canal_h_green.png", 13.5 + i, 16.5, 2)


func _build_shafts() -> void:
	var sections := 0
	var in_progress := false
	if _game != null:
		sections = int(_game.query("karez.sections"))
		in_progress = not _game.construction_idle()
	var building := sections + 1 if in_progress else 0

	for i in range(1, MAX_SHAFTS + 1):
		var c := shaft_center(i)
		var sp := Sprite2D.new()
		sp.centered = true
		sp.position = c
		sp.z_index = 5

		if i <= sections:
			sp.texture = _get_tex("res://buildings/well_shaft_01.png")
		elif i == building:
			sp.texture = _get_tex("res://buildings/well_shaft_construction.png")
		else:
			sp.texture = _get_tex("res://buildings/well_shaft_01.png")
			sp.modulate = Color(1, 1, 1, 0.22)

		_shaft_root.add_child(sp)
		_shaft_nodes.append({"index": i, "pos": c, "sprite": sp})

		# 已通水的竖井旁边放一小片水，直观表示「这口井出水了」
		if i <= sections:
			_add_prop("res://tiles/water/canal_v_green.png", shaft_grid(i).x - 0.6,
				shaft_grid(i).y + 0.4, 4)

	# 下一段可挖的竖井高亮
	if building == 0 and sections < MAX_SHAFTS:
		var nxt := sections + 1
		for s in _shaft_nodes:
			if int(s["index"]) == nxt:
				var sp: Sprite2D = s["sprite"]
				sp.modulate = Color(1.0, 0.94, 0.6, 0.9)


# ---------------------------------------------------------------------------
# 点击竖井
# ---------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton \
			and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var idx := shaft_at(get_global_mouse_position())
		if idx > 0:
			shaft_pressed.emit(idx)
			get_viewport().set_input_as_handled()
