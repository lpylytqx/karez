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
##   "fixed"     地景，暂不允许移动
##   "area"      区域（竖井链、农田、树林、取土场），不是一个点，不能移动
##
## gate —— **什么时候出现在地图上**：
##   {"kind": "always"}              开局就有
##   {"kind": "sections", "n": N}    坎儿井通到第 N 段才出现
##   {"kind": "threat"}              治安 < 40 或 第 12 天之后才出现
## ⚠ 角色的出现条件**不单独写** —— 他跟着自己那座地标走
##   （见 game_state.characters_present）。所以「地点按需出现」和
##   「人物按需出现」共用同一张表，不可能对不上。
## 每个地标的 `desc` 是**鼠标悬停时显示的说明**，两行：
##   第一行：这是什么
##   第二行：对你当前有什么作用
##
## ⚠ 第二行必须写**代码里真的生效的**，不能照 numbers.json 的 effect 抄。
##   实测：numbers.json 的 19 个建筑 effect 字段里**只有 3 个被代码读取**
##   （yiguan 的 lodging_capacity / income_per_guest_day、weijiang 的 security），
##   其余全都没接 —— 照抄就会在游戏里对玩家撒谎。
##   所以还没接的写「（待实装）」，接入之后再改这一行。
const PLACES := {
	# ── 开局就该有的：村子再惨，水和存粮的地方总得有 ──
	"warehouse":    {"xy": Vector2(7.0, 15.5),  "kind": "building", "tex": "warehouse_01.png",
		"gate": {"kind": "always"},
		"desc": "堆放粮食与木石的库房。\n当前：储水上限 ×1.5（300 → 450 方）"},
	# 涝坝有**四档贴图**，按当下水位换（tex_levels）。原单图 reservoir_01.png 已弃用。
	"reservoir":    {"xy": Vector2(12.0, 15.0), "kind": "fixed",
		"tex": "reservoir_lv4.png",
		"tex_levels": ["reservoir_lv1.png", "reservoir_lv2.png",
			"reservoir_lv3.png", "reservoir_lv4.png"],
		"gate": {"kind": "always"},
		"desc": "涝坝——坎儿井的蓄水池，把水存下来过冬。\n当前：水位一眼可读；每 30 方容量供 1 人"},
	"kitchen":      {"xy": Vector2(17.0, 15.5), "kind": "fixed",    "tex": "kitchen_01.png",
		"gate": {"kind": "always"},
		"desc": "吊锅当灶，驿站吃饭的地方。\n当前：日耗粮 ÷1.15（省下一成半）"},
	# ── 村子活过来之后才陆续出现 ──
	"stable":       {"xy": Vector2(31.0, 15.5), "kind": "building", "tex": "stable_01.png",
		"gate": {"kind": "sections", "n": 2},
		"desc": "饲养牲畜、为商队备马换乘。\n当前：每日 +2 两银；治安 +5/天"},
	"inn":          {"xy": Vector2(26.0, 15.0), "kind": "building", "tex": "inn_01.png",
		"gate": {"kind": "sections", "n": 2},
		"desc": "接待商队过夜的驿馆，驿站的门面。\n当前：每日 +1.5 两银；住宿上限 12 人"},
	"bazar_red":    {"xy": Vector2(19.0, 15.5), "kind": "fixed",    "tex": "bazar_stall_red.png",
		"gate": {"kind": "sections", "n": 3},
		"desc": "巴扎摊位——商队与居民交易的地方。\n当前：每日按抽成率进账银两"},
	"bazar_blue":   {"xy": Vector2(21.0, 15.5), "kind": "fixed",    "tex": "bazar_stall_blue.png",
		"gate": {"kind": "sections", "n": 3},
		"desc": "巴扎摊位——商队与居民交易的地方。\n当前：每日按抽成率进账银两"},
	"grape_drying": {"xy": Vector2(30.0, 12.0), "kind": "fixed",    "tex": "grape_drying_01.png",
		"gate": {"kind": "sections", "n": 4},
		"desc": "葡萄晾房——晾成葡萄干，能存到明年。\n当前：秋季食物产出 +25%"},
	"watchtower":   {"xy": Vector2( 2.0, 11.0), "kind": "fixed",    "tex": "watchtower_sand_01.png",
		"gate": {"kind": "threat"},
		"desc": "烽燧——发现敌情就点烟报信。\n当前：治安 +10/天"},
	"shop":         {"xy": Vector2( 6.0, 12.5), "kind": "fixed",    "tex": "shop_01.png",
		"gate": {"kind": "sections", "n": 5},
		"desc": "临街的商铺。\n当前：无额外效果（待实装）"},
	"workshop_b":   {"xy": Vector2(33.0, 13.0), "kind": "fixed",    "tex": "workshop_01.png",
		"gate": {"kind": "sections", "n": 5},
		"desc": "作坊——加工木器与织物。\n当前：做工产工具 ×1.2"},
	# ── 区域地标：地本身一直在，只是有没有人在那干活 ──
	"shaft_chain":  {"xy": Vector2(27.0, 10.0), "kind": "area", "tex": "", "gate": {"kind": "always"}},   # 井线中段(见 map_view 的 SHAFT_POS)
	"fields":       {"xy": Vector2(16.5, 12.5), "kind": "area", "tex": "", "gate": {"kind": "always"}},
	"forest":       {"xy": Vector2(17.0,  7.0), "kind": "area", "tex": "", "gate": {"kind": "always"}},
	"dig_earth":    {"xy": Vector2( 6.5, 11.0), "kind": "area", "tex": "", "gate": {"kind": "always"}},
	"workshop":     {"xy": Vector2( 9.5, 13.5), "kind": "area", "tex": "", "gate": {"kind": "always"}},
	"guard_post":   {"xy": Vector2(21.5, 17.0), "kind": "area", "tex": "", "gate": {"kind": "always"}},
	# 营火：从 "area" 改成 "fixed" 并给它贴图 ——
	#   它本来是个**没有画面的空区域**（待命的人按 JOB_SITE 聚到这里，地图上却什么也看不见），
	#   而 assets/buildings/campfire_01.png 这张图**之前没有任何脚本引用**，一直躺在素材里没人用。
	#   两件事凑一起正好：让它显形。
	#   kind 用 "fixed" 而不是 "building"：营火是地景，不该被拖走。
	"camp":         {"xy": Vector2(18.5, 17.0), "kind": "fixed", "tex": "campfire_01.png",
		"gate": {"kind": "always"},
		"desc": "营火——闲下来的居民聚在这儿歇脚。\n当前：待命的人在这里恢复士气"},
	# 沙漠匪巢：村里不该有他，但地点一直在那儿
	"desert_den":   {"xy": Vector2(35.0,  6.0), "kind": "area", "tex": "", "gate": {"kind": "threat"}},
	# ── 补齐 numbers.json 里剩下 4 个建筑的地标 ──
	#
	# 这 4 个建筑（围墙 / 居民居所 / 毡房区 / 奏乐台）的数值与美术**一直都有**，
	# 但 sites.gd 里没有对应地标 —— 后果是 `has_facility()` 永远返回 false，
	# 它们的 effect（security / population_capacity / morale_per_day）**从来没生效过**，
	# 而且玩家在建造菜单里点了也看不到任何东西出现在地图上。
	# 素材也一直是躺着的（wall_stone_01 / house_resident_01 / tent_01 都没被引用）。
	# 两件凑一起：给它们位置。
	"weijiang":     {"xy": Vector2(23.0, 18.5), "kind": "fixed", "tex": "wall_stone_01.png",
		"gate": {"kind": "sections", "n": 4},
		"desc": "围墙——挡住风沙与来犯的骑手。\n当前：治安 +8/天；御敌时减损"},
	"juzhu":        {"xy": Vector2(13.5, 18.5), "kind": "building", "tex": "house_resident_01.png",
		"gate": {"kind": "sections", "n": 3},
		"desc": "居民居所——人多了得有地方住。\n当前：住宿上限 +8 人"},
	"zhanfang":     {"xy": Vector2(35.5, 15.5), "kind": "fixed", "tex": "tent_01.png",
		"gate": {"kind": "sections", "n": 3},
		"desc": "毡房区——过路牧民搭的帐篷，慢慢成了半定居的邻居。\n当前：住宿上限 +6；与哈萨克部落亲和"},
	# 奏乐台的美术是新生成的（assets/buildings/yinletai_01.png）—— 现有素材里
	# 没有任何一张能当乐器台用，拿巴扎摊位糊上去就该在游戏里对玩家撒谎了。
	"yinletai":     {"xy": Vector2(26.0, 18.0), "kind": "fixed", "tex": "yinletai_01.png",
		"gate": {"kind": "sections", "n": 3},
		"desc": "奏乐台——木卡姆在这里响起。\n当前：士气 +1/天；巴扎更吸引商队"},
	# 畜栏：专管扩存栏的便宜建筑。素材是新画的 ——
	# assets/buildings/fence_wood_01.png **名字像栅栏、实际是房子墙面碎片**，
	# 直接拿它当畜栏就是又一次「贴图名字与内容对不上」（栽过 9 次，用前先看图）。
	"yangjuan":     {"xy": Vector2(33.0, 18.0), "kind": "fixed", "tex": "yangjuan_01.png",
		"gate": {"kind": "sections", "n": 2},
		"desc": "畜栏——圈住牲畜的地方。\n当前：存栏上限 +10"},
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

## PLACES 的 key  →  numbers.json 的 building id。
##
## ⚠ 这张表是必须的，它修的是一类「两套命名各写各的」的死 bug：
##     实测 data/numbers.json 的 12 个 building id 与 PLACES 的 20 个 key
##     **交集为空** —— 一个都不重合：
##         numbers.json: yiguan / majiu / cangku / chufang / bazha / …
##         sites.gd:     inn    / stable / warehouse / kitchen / bazar_red / …
##     两者指的是同一样东西，但名字不一样。后果：
##         建造写 state["buildings"]["majiu"]
##         地图查 state["buildings"].has("stable")   <- 永远 false
##     => 玩家花材料建了马厩，地图上什么也没出现。玩家反馈的原话是
##        「建完以后地图也没有显示呀，建到哪里去了」。状态其实写进去了，只是没人查得到。
##
## 为什么不干脆把 sites.gd 的 key 改成 numbers.json 的 id：
##     这些 key 还被 NPC_HOME（角色守着哪个地标）、JOB_SITE（岗位在哪干活）
##     以及 map_view / townfolk / villagers 引用着，改名的爆炸半径大。
##     加一张**显式翻译表**改动最小，而且把「这里有两套命名」这件事写明白了 ——
##     比继续靠两套命名各写各的安全。
##
## bazar_red / bazar_blue 都对应 bazha：numbers.json 里巴扎是一栋，
## 地图上是两个摊位。建成巴扎时两个摊位一起出现，符合预期。
const BUILDING_ID := {
	"inn":           "yiguan",
	"stable":        "majiu",
	"warehouse":     "cangku",
	"kitchen":       "chufang",
	"bazar_red":     "bazha",
	"bazar_blue":    "bazha",
	"workshop_b":    "zuofang",
	"grape_drying":  "liangfang",
	"watchtower":    "fengsui",
	# 补齐剩下 4 个建筑：地标键与 building id 同名。
	# ⚠ 之前缺的正是这 4 条 —— 于是 has_facility("weijiang"/"juzhu"/…) 永远 false，
	#   它们的 effect 从来没生效过，建造菜单点了也看不到东西出现在地图上。
	"weijiang":      "weijiang",
	"juzhu":         "juzhu",
	"zhanfang":      "zhanfang",
	"yinletai":      "yinletai",
	"yangjuan":      "yangjuan",
}


## 这个地标对应哪个 numbers.json building id。没有对应的（地景/区域）返回 ""。
static func building_id_of(site_key: String) -> String:
	return str(BUILDING_ID.get(site_key, ""))


## numbers.json 的 building id → 它在哪个/哪些 PLACES 键上。
##
## 注意巴扎：data 里是**一栋**（bazha），地图上是**两个摊位**（bazar_red / bazar_blue）。
## 所以这里的值是数组 —— 判断「巴扎在地图上出现没有」时，
## 两个摊位任意一个存在就算存在。写成一对一会在这种地方悄悄判错。
static func sites_of_building(building_id: String) -> Array:
	var out: Array = []
	for site_key in BUILDING_ID:
		if str(BUILDING_ID[site_key]) == building_id:
			out.append(str(site_key))
	return out


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
