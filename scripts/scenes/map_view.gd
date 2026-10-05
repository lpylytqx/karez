extends Node2D
## S2 地图渲染：中心绿洲，树木/建筑/石头点缀，向外过渡到沙漠。
## 640x360 逻辑分辨率，16x16 tiles，40x22 格。

const TILE := 16
const COLS := 40
const ROWS := 22

const TERRAIN_TEX := {
	"desert":   ["res://tiles/terrain/desert_light_01.png", "res://tiles/terrain/desert_light_02.png"],
	"sparse":   ["res://tiles/terrain/grass_sparse_01.png", "res://tiles/terrain/grass_sparse_02.png"],
	"medium":   ["res://tiles/terrain/grass_medium_01.png", "res://tiles/terrain/grass_medium_02.png"],
	"lush":     ["res://tiles/terrain/grass_lush_01.png", "res://tiles/terrain/grass_lush_02.png"],
}

var tex_cache := {}

func _ready():
	_build_terrain()
	_place_objects()

func _get_tex(path: String) -> Texture2D:
	if not tex_cache.has(path):
		tex_cache[path] = load(path)
	return tex_cache[path]

func _terrain_key(d: float) -> String:
	if d < 4.5: return "lush"
	elif d < 7.0: return "medium"
	elif d < 9.5: return "sparse"
	return "desert"

func _build_terrain():
	var cx := COLS / 2.0
	var cy := ROWS / 2.0
	for y in range(ROWS):
		for x in range(COLS):
			var d = Vector2(x - cx, y - cy).length()
			var key = _terrain_key(d)
			if randf() < 0.12:
				key = "desert" if key == "sparse" else key
			var paths = TERRAIN_TEX[key]
			var sp := Sprite2D.new()
			sp.texture = _get_tex(paths[randi() % paths.size()])
			sp.centered = false
			sp.position = Vector2(x * TILE, y * TILE)
			sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			add_child(sp)

func _add_sprite(path: String, gx: int, gy: int, centered := false):
	var sp := Sprite2D.new()
	sp.texture = _get_tex(path)
	sp.centered = centered
	sp.position = Vector2(gx * TILE, gy * TILE)
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sp)

func _place_objects():
	# 中心绿洲：绿树、棕榈、灌木
	_add_sprite("res://tiles/nature/tree_green_01.png", 17, 7, true)
	_add_sprite("res://tiles/nature/tree_palm_01.png", 23, 7, true)
	_add_sprite("res://tiles/nature/tree_green_01.png", 20, 14, true)
	_add_sprite("res://tiles/nature/tree_palm_01.png", 15, 13, true)
	_add_sprite("res://tiles/nature/flower_01.png", 19, 10, true)
	_add_sprite("res://tiles/nature/flower_01.png", 22, 12, true)
	_add_sprite("res://tiles/nature/bush_01.png", 18, 11, true)
	_add_sprite("res://tiles/nature/bush_01.png", 22, 10, true)
	# 中草过渡：石头、灌木
	_add_sprite("res://tiles/nature/rock_01.png", 13, 10, true)
	_add_sprite("res://tiles/nature/rock_01.png", 27, 12, true)
	_add_sprite("res://tiles/nature/bush_01.png", 14, 15, true)
	_add_sprite("res://tiles/nature/bush_01.png", 26, 9, true)
	# 沙漠边缘：枯树、石头
	_add_sprite("res://tiles/nature/tree_dead_01.png", 8, 11, true)
	_add_sprite("res://tiles/nature/tree_dead_01.png", 31, 10, true)
	_add_sprite("res://tiles/nature/tree_dead_01.png", 20, 2, true)
	_add_sprite("res://tiles/nature/tree_dead_01.png", 20, 19, true)
	# 建筑（放在绿洲南侧）
	_add_sprite("res://buildings/inn_01.png", 18, 12, false)
	_add_sprite("res://buildings/stable_01.png", 26, 15, false)
	_add_sprite("res://buildings/well_shaft_01.png", 12, 14, false)
