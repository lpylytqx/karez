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

## 动画帧带：每项 = [Sprite2D, 帧数, fps, 相位偏移]
var _sheets: Array = []
## 锚在地标上的动态效果：每项 = [Sprite2D, 地标 id, 相对地标中心的偏移]
## 单独记一份，是因为地标可以**被拖动**、也可能**稍后才出现**（驿馆要到第 2 段），
## 两种情况都得跟着变，否则会出现「旗子飘在空沙漠上」或者「建筑搬走了旗子还在原地」。
var _anchored: Array = []
var _time := 0.0


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
	# 锚在地标上的效果：位置跟着地标走；地标还没出现就整条藏起来。
	# （不做这个判断的话，开局就会看到一面旗子飘在空沙漠上 —— 驿馆要到第 2 段才出现。）
	for a in _anchored:
		var sp: Sprite2D = a[0]
		if sp == null or not is_instance_valid(sp):
			continue
		var sid := str(a[1])
		var off: Vector2 = a[2]
		var present: bool = _game == null or _game.place_present(sid)
		sp.visible = present
		if present:
			sp.position = _to_px(sid) + off


## 逐帧推进所有动画帧带。
##
## 用 Sprite2D 的 hframes 把一张横向帧带切成 n 帧，这里手动推 frame ——
## 比 AnimatedSprite2D + SpriteFrames 少一次资源构造，帧数也直接是除出来的，
## 加一帧只要重跑生成脚本、改一个数字。
##
## 每张带带自己的相位偏移：不做的话几处水光会**同时闪**，
## 看起来像画面故障，而不像水在动。
func _process(delta: float) -> void:
	_time += delta
	for s in _sheets:
		var sp: Sprite2D = s[0]
		if sp == null or not is_instance_valid(sp) or not sp.visible:
			continue
		sp.frame = int((_time + float(s[3])) * float(s[2])) % int(s[1])


## 铺一张动画帧带，锚在某个地标上。
## site 为空表示不锚定（位置与可见性自己管）。
func _add_sheet(path: String, n: int, site: String, off: Vector2,
		fps: float, z: int, phase := 0.0) -> Sprite2D:
	var sp := Sprite2D.new()
	var tex: Texture2D = load(path)
	if tex == null:
		push_warning("动画帧带缺失：%s" % path)
		return null
	sp.texture = tex
	sp.hframes = n
	sp.centered = true
	sp.z_index = z
	# 帧数要与贴图宽度对得上，否则会切出半帧、画面撕裂
	if tex.get_width() % n != 0:
		push_warning("帧带 %s 宽 %d 除不尽 %d 帧" % [path, tex.get_width(), n])
	sp.position = (_to_px(site) + off) if site != "" else off
	add_child(sp)
	_sheets.append([sp, n, fps, phase])
	if site != "":
		_anchored.append([sp, site, off])
	return sp


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

	_build_sheets()

	# 摆一次位置与可见性（此时还没连 state_changed，但初值要正确）
	_resync()


## 三组小动效：水面光点、旗子、火苗。
##
## 为什么这些值得做：地图此前**只有地形和建筑是静止的图像**，
## 唯一会动的是炊烟、沙尘和居民走路。水是这游戏的核心资源，
## 而涝坝的水面是死的一整块蓝 —— 加上闪烁的光点，「水还活着」才成立。
##
## ⚠ 这里的 z 与 map_view.gd 的 Z_* 常量是**耦合**的（跨文件，没法直接引用）：
##     沙尘 0 < 水光 5（要在涝坝 Z_BUILDING=4 之上）< 火苗 6 < 旗子 7 < 人物名牌 12
##   地图那边改图层时，这里要跟着一起改，否则水光会被涝坝盖住。
func _build_sheets() -> void:
	# ── 水面光点：铺在涝坝水面上 ──
	# 用相对地标中心的偏移，涝坝被拖动时自动跟着走；
	# 相位逐张错开（i * 0.41），否则几处光点会一起闪，像故障。
	var ripple_offsets := [
		Vector2(-15, -9), Vector2(3, -16), Vector2(-7, 5), Vector2(12, 1),
	]
	for i in range(ripple_offsets.size()):
		_add_sheet("res://fx/fx_ripple.png", 4, "reservoir", ripple_offsets[i],
			5.0, 5, float(i) * 0.41)

	# ── 旗子：插在驿馆与两座巴扎的屋顶上 ──
	# z 7：在建筑（1~4）与炊烟（6）之上，但在人物名牌（12）之下
	_add_sheet("res://fx/fx_flag.png", 6, "inn", Vector2(18, -34), 6.0, 7, 0.0)
	_add_sheet("res://fx/fx_flag.png", 6, "bazar_red", Vector2(9, -19), 6.0, 7, 0.7)
	_add_sheet("res://fx/fx_flag.png", 6, "bazar_blue", Vector2(9, -19), 6.0, 7, 1.4)

	# ── 火苗：灶口与营火 ──
	_add_sheet("res://fx/fx_flame.png", 4, "kitchen", Vector2(0, -5), 8.0, 6, 0.0)
	_add_sheet("res://fx/fx_flame.png", 4, "camp", Vector2(0, -3), 7.0, 6, 0.5)


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
