extends Node2D
## 气氛粒子：灶上的炊烟 + 沙漠里飘的沙尘。
##
## 为什么用 CPUParticles2D 而不是 GPUParticles2D：
## 这是像素画。CPU 粒子直接拿贴图当粒子，能保证**一个粒子就是一个像素块**；
## GPU 粒子要走 shader，默认会做插值与混合，出来是软边光晕，跟像素画冲突。
##
## 用 _rng 固定种子的理由同地表撒物：粒子参数里如果有随机初速，
## 每次重建都换一套数值会让烟「跳」一下。这里主要是为了可复现。
##
## 昼夜光照（play.gd 的 CanvasModulate）会把粒子一起染色 —— 这是想要的：
## 夜里的炊烟本来就该偏冷。

var _game: Node = null
var _map: Node2D = null

var _smoke: CPUParticles2D = null
var _dust: Array[CPUParticles2D] = []


func setup(game: Node, map: Node2D) -> void:
	_game = game
	_map = map
	_build()
	if _game != null and not _game.state_changed.is_connected(_resync):
		_game.state_changed.connect(_resync)


func _resync() -> void:
	# 灶的位置可能被拖动（虽然现在 fixed，但坐标本来就在 state 里），
	# 地表撒物与绿洲尺寸都会随状态变，所以每次状态变化都重摆一次。
	if _smoke != null and is_instance_valid(_smoke):
		_smoke.position = _to_px("kitchen") + Vector2(0, -14)


func _to_px(id: String) -> Vector2:
	if _game != null:
		return _game.site_xy(id) * 16.0
	return Vector2.ZERO


func _grad(pts: Array) -> Gradient:
	var g := Gradient.new()
	var offs := PackedFloat32Array()
	var cols := PackedColorArray()
	for p in pts:
		offs.append(float(p[0]))
		cols.append(p[1])
	g.offsets = offs
	g.colors = cols
	return g


func _build() -> void:
	# ── 炊烟：从灶口升起，越飘越淡越大 ──
	_smoke = CPUParticles2D.new()
	_smoke.texture = load("res://tiles/fx/particle_smoke.png")
	# 烟要在建筑之上（建筑 z 1~4），但在人物名牌（z 12）之下
	_smoke.z_index = 6
	_smoke.position = _to_px("kitchen") + Vector2(0, -14)
	_smoke.amount = 24
	_smoke.lifetime = 3.6
	_smoke.emitting = true
	_smoke.direction = Vector2(0, -1)
	_smoke.spread = 14.0
	_smoke.initial_velocity_min = 5.0
	_smoke.initial_velocity_max = 10.0
	# 轻微向上加速 + 往东偏：沙漠里常有一丝侧风，直上直下反而假
	_smoke.gravity = Vector2(3.0, -2.5)
	_smoke.scale_amount_min = 0.6
	_smoke.scale_amount_max = 0.85
	var sc := Curve.new()
	sc.add_point(Vector2(0.0, 0.55))
	sc.add_point(Vector2(0.35, 1.0))
	sc.add_point(Vector2(1.0, 2.2))
	_smoke.scale_amount_curve = sc
	# ⚠ 第一版 alpha 只到 0.62，实机放大后几乎看不见（截图确认）。
	# 像素画里烟要读得出来，就得比直觉上更实一点 —— 提到 0.88。
	_smoke.color_ramp = _grad([
		[0.0, Color(1, 1, 1, 0.0)],
		[0.14, Color(1, 1, 1, 0.88)],
		[0.55, Color(1, 1, 1, 0.46)],
		[1.0, Color(1, 1, 1, 0.0)],
	])
	add_child(_smoke)

	# ── 沙尘：两条横向的飘带，一高一低、一快一慢，
	#    免得看着像一整块匀速平移的贴纸 ──
	_dust.append(_make_dust(Vector2(320, 92), Vector2(-1, 0), 9.0, 20.0, 10, "res://tiles/fx/particle_dust_a.png"))
	_dust.append(_make_dust(Vector2(320, 138), Vector2(-1, 0), 5.0, 13.0, 7, "res://tiles/fx/particle_dust_b.png"))
	_dust.append(_make_dust(Vector2(320, 250), Vector2(1, 0), 4.0, 11.0, 6, "res://tiles/fx/particle_dust_b.png"))
	for d in _dust:
		add_child(d)


func _make_dust(at: Vector2, dir: Vector2, vmin: float, vmax: float,
		amt: int, tex: String) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.texture = load(tex)
	# 沙尘在建筑之下（z 1~4），否则会飘在屋顶上像故障
	p.z_index = 0
	p.position = at
	p.amount = amt
	p.lifetime = 26.0
	p.emitting = true
	p.direction = dir
	p.spread = 6.0
	p.initial_velocity_min = vmin
	p.initial_velocity_max = vmax
	p.gravity = Vector2.ZERO
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	# 略宽于地图（640），从左/右边界外飘进来才不会有「凭空出现」
	p.emission_rect_extents = Vector2(360, 26)
	p.color_ramp = _grad([
		[0.0, Color(1, 1, 1, 0.0)],
		[0.10, Color(1, 1, 1, 0.75)],
		[0.90, Color(1, 1, 1, 0.75)],
		[1.0, Color(1, 1, 1, 0.0)],
	])
	return p
