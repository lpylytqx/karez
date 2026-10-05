class_name Sites
extends RefCounted
## 建筑与地标的**唯一坐标真源**。
##
## 为什么要有这个文件（值得留档，因为它治的是一类反复出现的 bug）：
##
##   原先坐标分散在三处，各写各的：
##     map_view.gd   建筑画在哪
##     townfolk.gd   NPC  站在哪
##     villagers.gd  工作地点在哪
##   三张表靠我手工保持一致。结果连续出错：
##     · 为「散开」把人往上挪   -> 掌柜离驿馆 2.6 格、骑手离马厩 2.9 格
##     · 把厨房挪到村中心当灶   -> 忘了改厨娘的站位
##     · 马厩门槛 lv>=3         -> 开局没有马厩，骑手站在空沙漠里
##   每次都是「改了 A、漏了 B」。
##
##   现在改成：**这里一份坐标，另外两处从它推导。** 物理上不可能对不上。
##   建筑一挪，NPC 与工作地点自动跟着挪 —— 这正是「手动移动建造位置」的地基。
##
## 坐标单位是「格」，1 格 = 16px（见 map_view 的 TILE）。

## 所有地标与建筑的坐标。key 是 id，与 data/numbers.json 的 buildings.list 对齐。
##
## kind:
##   "building"  玩家可见、可建造、**可移动**的建筑
##   "fixed"     地景（涝坝/巴扎/晾房/灶），暂不允许移动
##   "area"      区域（竖井链、农田、树林、取土场），不是一个点，不能移动
const PLACES := {
	# ── 聚落建筑 ──
	"warehouse":    {"xy": Vector2(7.0, 15.5),  "kind": "building", "tex": "warehouse_01.png"},
	"reservoir":    {"xy": Vector2(12.0, 15.0), "kind": "fixed",    "tex": "reservoir_01.png"},
	"kitchen":      {"xy": Vector2(17.0, 15.5), "kind": "fixed",    "tex": "kitchen_01.png"},
	"bazar_red":    {"xy": Vector2(19.0, 15.5), "kind": "fixed",    "tex": "bazar_stall_red.png"},
	"bazar_blue":   {"xy": Vector2(21.0, 15.5), "kind": "fixed",    "tex": "bazar_stall_blue.png"},
	"inn":          {"xy": Vector2(26.0, 15.0), "kind": "building", "tex": "inn_01.png"},
	"grape_drying": {"xy": Vector2(30.0, 12.0), "kind": "fixed",    "tex": "grape_drying_01.png"},
	"stable":       {"xy": Vector2(31.0, 15.5), "kind": "building", "tex": "stable_01.png"},
	# ── 区域地标（不是一个点，只用来给 NPC/工作地点定位中心）──
	"shaft_chain":  {"xy": Vector2(23.0, 13.4), "kind": "area", "tex": ""},
	"fields":       {"xy": Vector2(16.5, 12.5), "kind": "area", "tex": ""},
	"forest":       {"xy": Vector2(17.0,  7.0), "kind": "area", "tex": ""},
	"dig_earth":    {"xy": Vector2( 6.5, 11.0), "kind": "area", "tex": ""},
	"workshop":     {"xy": Vector2( 9.5, 13.5), "kind": "area", "tex": ""},
	"guard_post":   {"xy": Vector2(21.5, 17.0), "kind": "area", "tex": ""},
	"camp":         {"xy": Vector2(18.5, 17.0), "kind": "area", "tex": ""},
	# ── 最西边的点缀 ──
	"watchtower":   {"xy": Vector2( 2.0, 11.0), "kind": "fixed", "tex": "watchtower_sand_01.png"},
	"shop":         {"xy": Vector2( 6.0, 12.5), "kind": "fixed", "tex": "shop_01.png"},
	"workshop_b":   {"xy": Vector2(33.0, 13.0), "kind": "fixed", "tex": "workshop_01.png"},
}

## NPC -> 他守着哪个地标。站位 = 该地标的 xy + OFFSET。
const NPC_HOME := {
	"lao_kanjiang":      "shaft_chain",
	"muqam_yiren":       "bazar_blue",
	"hasake_qishou":     "stable",
	"hanshang_zhanggui": "inn",
	"chuniang":          "kitchen",
	"shenmi_lvren":      "reservoir",
	"mafei_toumu":       "desert_den",
}

## 岗位 -> 工作地点在哪个地标。
const JOB_SITE := {
	"water":        "shaft_chain",
	"gather_wood":  "forest",
	"gather_earth": "dig_earth",
	"craft":        "workshop",
	"farm":         "fields",
	"guard":        "guard_post",
	"idle":         "camp",
}

## NPC 相对地标的偏移（格）。规则见 townfolk.gd 的注释：
## 站建筑的**左缘或右缘**，不站正前方 —— 建筑前方被底栏吃掉了，没有落脚地。
const NPC_OFFSET := {
	"lao_kanjiang":      Vector2( 0.0,  0.0),
	"muqam_yiren":       Vector2(-1.0,  0.9),
	"hasake_qishou":     Vector2(-1.5,  0.9),
	"hanshang_zhanggui": Vector2(-2.0,  0.9),
	"chuniang":          Vector2(-2.0,  0.9),
	"shenmi_lvren":      Vector2(-2.4,  0.9),
	"mafei_toumu":       Vector2( 0.0,  0.0),
}

## 沙漠里的匪巢 —— 不在 PLACES 里，单独给个坐标（村里不该有他）。
const DESERT_DEN := Vector2(35.0, 6.0)


static func place_xy(id: String) -> Vector2:
	if id == "desert_den":
		return DESERT_DEN
	var p: Dictionary = PLACES.get(id, {})
	return p.get("xy", Vector2.ZERO)


static func npc_xy(cid: String) -> Vector2:
	var home := str(NPC_HOME.get(cid, ""))
	var off: Vector2 = NPC_OFFSET.get(cid, Vector2.ZERO)
	return place_xy(home) + off


static func job_xy(jid: String) -> Vector2:
	return place_xy(str(JOB_SITE.get(jid, "camp")))


## 可移动的建筑 id（kind == "building"）。
static func movable_ids() -> Array:
	var out: Array = []
	for id in PLACES:
		if str(PLACES[id].get("kind", "")) == "building":
			out.append(str(id))
	return out
