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
	# 四档底纹全部用「程序化生成的纯地面」（scripts/pipeline/make_ground.py）。
	#
	# 为什么不用现成的：那批素材里没有纯地面底纹。
	#   · desert_light_01/02 各带一块橙黄装饰斑块，是**地形过渡贴图**
	#   · grass_sparse/medium/lush 带等距重复的浅色弧线
	# 16x16 的小块平铺 40x22 = 880 次之后，这些特征都会变成肉眼可见的**墙纸**
	# —— 一眼看出是贴图而不是地面（实机截图确认过）。
	"desert": ["res://tiles/terrain/sand_base_01.png", "res://tiles/terrain/sand_base_02.png",
		"res://tiles/terrain/sand_base_03.png", "res://tiles/terrain/sand_ripple_01.png"],
	"sparse": ["res://tiles/terrain/grass_sparse_base_01.png", "res://tiles/terrain/grass_sparse_base_02.png"],
	"medium": ["res://tiles/terrain/grass_medium_base_01.png", "res://tiles/terrain/grass_medium_base_02.png"],
	"lush":   ["res://tiles/terrain/grass_lush_base_01.png", "res://tiles/terrain/grass_lush_base_02.png"],
	# 绿洲与沙漠交界处用过渡贴图，让边界不那么生硬
	"edge":   ["res://tiles/terrain/desert_light_01.png", "res://tiles/terrain/desert_light_02.png"],
}

## 竖井链：从聚落斜向北（往山里去）。
## 走斜线而不是垂直一列，是因为竖井贴图是 32x32 —— 若间隔只有 2 格（32px）
## 会边贴边连成一条实心柱子（实机截图确认过）。斜向的对角距离约 45px，能分清每一口。
const SHAFT_GX0 := 25
const SHAFT_GY0 := 15
const SHAFT_DX := -1
const SHAFT_DY := -2
const MAX_SHAFTS := 6

## 农田块（格）—— 16x16，可以紧排。
## 6x4 = 24 格，正好等于 agriculture.farmland.max_plots，画出来的和算出来的一致。
const FIELD_X0 := 14
const FIELD_Y0 := 10
const FIELD_COLS := 6
const FIELD_ROWS := 4

var _game: Node = null
## 可拖动建筑：id -> Sprite2D，以及正在拖的那个
var _prop_nodes: Dictionary = {}
var _draggable: Array = []
var _drag_id := ""
var _drag_off := Vector2.ZERO
var _drag_moved := false

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


# ---------------------------------------------------------------------------
# 拖拽移动建筑
# ---------------------------------------------------------------------------
#
# 只有 sites.gd 里 kind == "building" 的能拖（仓库 / 马厩 / 驿馆）。
# 松开鼠标时吸附到 0.5 格，然后调 game_state.move_site() 写进 state ——
# NPC 与居民的位置都从 state 推导，所以会自动重新定位，不需要在这里管。
#
# 为什么用 _unhandled_input：HUD 上的按钮与面板会先吃掉点击，
# 所以拖面板不会误拖到地图上的建筑。

## 鼠标点在哪座可移动建筑上（按贴图实际大小做包围盒）
func _pick_building(p: Vector2) -> String:
	for id in _draggable:
		var sp: Sprite2D = _prop_nodes.get(str(id), null)
		if sp == null or not is_instance_valid(sp) or sp.texture == null:
			continue
		var half := Vector2(sp.texture.get_width(), sp.texture.get_height()) * 0.5
		if Rect2(sp.position - half, half * 2.0).has_point(p):
			return str(id)
	return ""


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

	# 分两步：先把每格的地形类型算出来，再贴图。
	# 之所以要两步，是为了让沙漠格能看见邻居 —— 紧贴绿洲的那圈沙漠改用过渡贴图，
	# 边界就不会是一条生硬的直边。（desert_light_* 本来就是干这个用的。）
	var keys: Array = []
	for y in range(ROWS):
		var row: Array = []
		for x in range(COLS):
			var d := Vector2(x - cx, y - cy).length()
			var key := _terrain_key(d, r)
			# 绿洲边缘不规则化，避免出现完美的圆
			if key == "sparse" and _rng.randf() < 0.35:
				key = "desert"
			elif key == "desert" and d < r + 1.5 and _rng.randf() < 0.20:
				key = "sparse"
			row.append(key)
		keys.append(row)

	for y in range(ROWS):
		for x in range(COLS):
			var key: String = str(keys[y][x])
			if key == "desert" and _touches_land(keys, x, y):
				key = "edge"
			var paths: Array = TERRAIN_TEX[key]
			var sp := Sprite2D.new()
			sp.texture = _get_tex(str(paths[_rng.randi() % paths.size()]))
			sp.centered = false
			sp.position = Vector2(x * TILE, y * TILE)
			_terrain_root.add_child(sp)


## 四邻中是否有非沙漠格（用于判断该不该用交界过渡贴图）。
func _touches_land(keys: Array, x: int, y: int) -> bool:
	for off in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var nx := x + int(off.x)
		var ny := y + int(off.y)
		if nx < 0 or ny < 0 or nx >= COLS or ny >= ROWS:
			continue
		var k := str(keys[ny][nx])
		if k != "desert" and k != "edge":
			return true
	return false


func _add_prop(path: String, gx: float, gy: float, z := 1) -> Sprite2D:
	var sp := Sprite2D.new()
	sp.texture = _get_tex(path)
	sp.centered = true
	sp.position = Vector2(gx * TILE, gy * TILE)
	sp.z_index = z
	_prop_root.add_child(sp)
	return sp


## 树：按「根部落地」对齐 —— 精灵底边贴在格点上。
## 用 centered=true 会让 48px 的树有一半伸到格点下方，看着像浮在半空；
## 而且树越大偏得越多，一片树就会显得各飘各的。
func _add_tree(path: String, gx: float, gy: float) -> void:
	var sp := Sprite2D.new()
	var tex := _get_tex(path)
	sp.texture = tex
	sp.centered = false
	sp.position = Vector2(roundf(gx * TILE - tex.get_width() * 0.5),
		roundf(gy * TILE - tex.get_height()))
	sp.z_index = 3
	_prop_root.add_child(sp)


## 灌木/花草：贴地的小物件，按格点居中即可。
func _add_ground(path: String, gx: float, gy: float) -> void:
	var sp := Sprite2D.new()
	var tex := _get_tex(path)
	sp.texture = tex
	sp.centered = false
	sp.position = Vector2(roundf(gx * TILE - tex.get_width() * 0.5),
		roundf(gy * TILE - tex.get_height() * 0.5))
	sp.z_index = 2
	_prop_root.add_child(sp)


## 该位置是否被农田 / 聚落 / 竖井走廊占用（用于植被散布避让）。
func _is_reserved(ax: float, ay: float) -> bool:
	if ax > FIELD_X0 - 1.0 and ax < FIELD_X0 + FIELD_COLS + 1.0 \
			and ay > FIELD_Y0 - 1.0 and ay < FIELD_Y0 + FIELD_ROWS + 1.0:
		return true
	if ay > 13.0:
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

	# ── 地标与建筑：坐标**全部来自 core/sites.gd**，这里不再写任何数字 ──
	#
	# 为什么改成循环：原先地图把坐标写在这、NPC 站位写在 townfolk、
	# 工作地点写在 villagers —— 三张表靠手工保持一致，结果连续出错
	# （为散开把人挪走、把厨房挪走忘了改厨娘、马厩门槛 lv>=3 骑手没地标）。
	# 现在只有 sites.gd 一份坐标，NPC 与工作地点从它推导，
	# 「建筑一挪、人和工作地点自动跟着挪」也就成立了。
	# ⚠ 这一排不能低于 y≈272：底栏从 y=276 开始盖住地图。
	for id in Sites.PLACES:
		var p: Dictionary = Sites.PLACES[id]
		var tex := str(p.get("tex", ""))
		var kind := str(p.get("kind", ""))
		if tex == "" or kind == "area":
			continue
		# 随绿洲等级出现的点缀建筑
		if id == "watchtower" and lv < 4:
			continue
		if (id == "shop" or id == "workshop_b") and lv < 5:
			continue
		var xy: Vector2 = _game.site_xy(id) if _game != null else p["xy"]
		var sp := _add_prop("res://buildings/%s" % tex, xy.x, xy.y)
		# 可移动的建筑留个引用，供拖拽时改位置
		if kind == "building":
			_prop_nodes[id] = sp
			_draggable.append(str(id))

	# ── 农田：坎儿井通水后才出现（水决定能种多少地）──
	var slots: Array = []
	for r in range(FIELD_ROWS):
		for c in range(FIELD_COLS):
			slots.append(Vector2i(FIELD_X0 + c, FIELD_Y0 + r))
	# 田块数与数值层用同一个来源 —— 否则画面上 12 块田、数值上按 24 块产粮，
	# 玩家看到的和算出来的对不上（这是作图与数值脱节的典型，之前就出过）。
	var fields := clampi(int(_game.farmland_plots()) if _game != null else 0,
		0, slots.size())
	# 每块地一种作物，按地块顺序推进生长阶段 —— 一眼能看出「这片地在长东西」。
	# 只用番茄一条线会显得单调，所以掺了胡萝卜/茄子/玉米/卷心菜。
	var crop_lines: Array = [
		["crop_stage_1_seedling", "crop_stage_2_sprout", "crop_stage_3_growing", "crop_stage_4_ripe"],
		["crop_stage_1_seedling", "crop_stage_2_sprout", "crop_carrot"],
		["crop_stage_1_seedling", "crop_stage_2_sprout", "crop_eggplant"],
		["crop_stage_1_seedling", "crop_stage_2_sprout", "crop_corn"],
		["crop_stage_1_seedling", "crop_stage_2_sprout", "crop_cabbage"],
		["crop_stage_1_seedling", "crop_stage_2_sprout", "crop_wheat"],
	]
	for i in range(fields):
		var g: Vector2i = slots[i]
		_add_prop("res://tiles/farmland/soil_tilled_a.png", g.x, g.y)
		var line: Array = crop_lines[i % crop_lines.size()]
		var t := float(i) / maxf(1.0, float(maxi(1, fields - 1)))
		var stage := clampi(int(round(t * float(line.size() - 1))), 0, line.size() - 1)
		_add_prop("res://tiles/farmland/%s.png" % str(line[stage]), g.x, g.y, 2)

	# ── 聚落里的活物与杂物：让画面不至于空得像布景 ──
	if lv >= 1:
		_add_prop("res://tiles/props/animal_chicken_01.png", 18.5, 14.5)
		_add_prop("res://tiles/props/person_farmer_01.png", 15.5, 14.5)
	if lv >= 2:
		_add_prop("res://tiles/props/animal_sheep_01.png", 23, 14.5)
		_add_prop("res://tiles/props/barrel_wood_01.png", 9, 14.2)
	if lv >= 3:
		_add_prop("res://tiles/props/animal_donkey_01.png", 27, 14.5)
		_add_prop("res://tiles/props/crate_wood_01.png", 12, 14.2)
	if lv >= 4:
		_add_prop("res://tiles/props/basket_01.png", 21.5, 14.2)
		_add_prop("res://tiles/props/sunflower_01.png", 5, 12)

	# ── 绿洲内植被 ──
	#
	# ⚠ 只用「完整的树」。nature 目录里有几张看着像树、实际不是的图：
	#   · tree_green_01(48x48) / tree_orange_01(48x48) 是**图块碎片** ——
	#     它们其实是「一棵大树树冠的四分之一」（左上角叶、右上角棕、左下土坡…），
	#     第一版当独立树来摆，绿洲就成了一坨认不出的绿块（实机截图确认过）。
	#   · tree_pink_01 / tree_small_02 是**完全空的**（0% 不透明像素）。
	# 现在用程序化生成的橡树/白杨/胡杨（scripts/pipeline/make_trees.py），
	# 加上素材里真正完整的 tree_small_01 与 tiny-town 的四张 16x16。
	var big_trees := [
		"res://tiles/nature/tree_euphrates_01.png",   # 胡杨（金黄）
		"res://tiles/nature/tree_euphrates_02.png",
		"res://tiles/nature/tree_oak_01.png",         # 圆冠阔叶
		"res://tiles/nature/tree_small_01.png",       # 32x32 小圆树
	]
	var small_trees := [
		"res://tiles/nature/tree_poplar_01.png",      # 白杨（新疆杨）
		"res://tiles/nature/tree_poplar_02.png",
		"res://tiles/terrain/tree_green_01.png",
		"res://tiles/terrain/tree_green_02.png",
		"res://tiles/terrain/tree_autumn_01.png",
		"res://tiles/terrain/tree_autumn_02.png",
	]
	var shrubs := [
		"res://tiles/nature/bush_01.png",
		"res://tiles/nature/flower_01.png",
		"res://tiles/nature/grass_tuft_01.png",
	]

	var r := oasis_radius()
	var cx := COLS / 2.0
	var cy := ROWS / 2.0 + 1.0

	# 树的密度大幅下调：48px 的树挤在 240px 见方的区域里必然互相压盖。
	# 并且加**间距约束** —— 不满足距离就重新投点，而不是硬放下去。
	var placed_at: Array = []
	var placed := 0
	var target := maxi(3, int(r * 1.05))
	var guard := 0
	while placed < target and guard < 900:
		guard += 1
		var ax := _rng.randf_range(cx - r, cx + r)
		var ay := _rng.randf_range(cy - r, cy + r)
		if Vector2(ax - cx, ay - cy).length() > r * 0.88:
			continue
		if _is_reserved(ax, ay):
			continue
		var pos := Vector2(ax, ay)
		var too_close := false
		for p in placed_at:
			if pos.distance_to(p) < 2.7:
				too_close = true
				break
		if too_close:
			continue
		placed_at.append(pos)
		if _rng.randf() < 0.45:
			_add_ground(str(small_trees[_rng.randi() % small_trees.size()]), ax, ay)
		else:
			_add_tree(str(big_trees[_rng.randi() % big_trees.size()]), ax, ay)
		placed += 1

	# 灌木花草单独撒一层，用很小的间距，专门填补树之间的空隙
	for i in range(int(r * 2.4)):
		var ax := _rng.randf_range(cx - r * 0.92, cx + r * 0.92)
		var ay := _rng.randf_range(cy - r * 0.92, cy + r * 0.92)
		if _is_reserved(ax, ay):
			continue
		_add_ground(str(shrubs[_rng.randi() % shrubs.size()]), ax, ay)

	# ── 沙漠枯树：绿洲外的荒芜对照（也是完整贴图，48x48）──
	for g in [Vector2i(6, 8), Vector2i(34, 7), Vector2i(20, 2), Vector2i(14, 19),
			Vector2i(3, 19), Vector2i(36, 19)]:
		_add_tree("res://tiles/nature/tree_dead_01.png", g.x, g.y)

	# ── 明渠：涝坝往东引水，末端接农田 ──
	if lv >= 1:
		for i in range(clampi(lv, 1, 4)):
			_add_prop("res://tiles/water/canal_h_green.png", 13.5 + i, 15, 2)


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
	# ── 拖拽可移动建筑（仓库/马厩/驿馆）──
	# 放在最前面：拖拽优先级高于「点竖井」，
	# 否则在建筑与竖井重叠处按下会被竖井抢走。
	if _handle_drag(event):
		return

	if event is InputEventMouseButton \
			and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var idx := shaft_at(get_global_mouse_position())
		if idx > 0:
			shaft_pressed.emit(idx)
			get_viewport().set_input_as_handled()


## 返回 true 表示这次事件已被拖拽消费掉。
func _handle_drag(event: InputEvent) -> bool:
	var mp := get_global_mouse_position()

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var id := _pick_building(mp)
			if id == "":
				return false
			_drag_id = id
			_drag_moved = false
			var sp: Sprite2D = _prop_nodes[id]
			_drag_off = sp.position - mp
			get_viewport().set_input_as_handled()
			return true
		if _drag_id != "":
			# 松手：吸附到 0.5 格后写进 state
			var sp: Sprite2D = _prop_nodes.get(_drag_id, null)
			if sp != null and is_instance_valid(sp):
				var g := Vector2(roundf(sp.position.x / TILE * 2.0) * 0.5,
					roundf(sp.position.y / TILE * 2.0) * 0.5)
				_game.move_site(_drag_id, g)
			_drag_id = ""
			get_viewport().set_input_as_handled()
			return true
		return false

	if event is InputEventMouseMotion and _drag_id != "":
		var sp: Sprite2D = _prop_nodes.get(_drag_id, null)
		if sp != null and is_instance_valid(sp):
			# 拖动中只搬精灵；松手才提交，免得每帧广播 state_changed
			sp.position = mp + _drag_off
			_drag_moved = true
			get_viewport().set_input_as_handled()
			return true
	return false
