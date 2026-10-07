"""往 numbers.json 里补两块数据：畜牧（livestock）与灾难（disasters）。

为什么用脚本改 JSON 而不是手写：这两块数据结构深（嵌套字典 + 数组），
手写容易漏键、逗号错位；而且这个文件是 UTF-8 中文，用脚本按 utf-8 读写
才能保证不出现"PowerShell 按 GBK 回写导致乱码"那类事故。

用法：<venv>/python patch_data_livestock_disasters.py
幂等：重复运行会覆盖这两块，不会重复追加。
"""
import sys as _sys
from pathlib import Path as _Path
_sys.path.insert(0, str(_Path(__file__).resolve().parent))
from _root import ROOT  # 路径唯一解析处，不再写死盘符
import json
from pathlib import Path

R = ROOT
P = R / "data" / "numbers.json"
d = json.loads(P.read_text(encoding="utf-8"))

# ---------------------------------------------------------------------------
# 一、畜牧（livestock）
# ---------------------------------------------------------------------------
d["livestock"] = {
    "display": "畜牧",
    "note": (
        "牲畜不是凭空来的：要派人去草原抓野畜、或等商队贩卖。"
        "每头每天吃草料，按畜种产出（毛/奶/蛋/皮），养够天数会自己繁殖。"
        "牧人照看才有全额产出——没人管时产出减半、繁殖停止。"
        "灾难会成批冻死、病死它们，这是'过冬'压力线的一部分。"
    ),
    "base_capacity": 6,
    "capacity_note": "基础 6 头；马厩 +15，羊圈/畜栏另有加成。超出上限时不再繁殖。",
    "feed_per_head_per_day": 0.5,
    "feed_name": "草料",
    "untended_output_multiplier": 0.5,
    "max_per_species": 40,
    "species": {
        "sheep": {
            "display": "阿勒泰细毛羊", "short": "羊", "value": 9.0,
            "feed": 1.0, "breed_days": 7, "breed_chance": 0.45,
            "products": {"wool": 0.55, "milk": 0.25},
            "slaughter": {"meat": 6.0},
            "cold_hardiness": 0.75,
            "desc": "新疆细毛羊。毛是织地毯、擀毡子的原料，奶能喝，肉能宰——一头羊就是一个会走路的小仓库。",
        },
        "goat": {
            "display": "绒山羊", "short": "山羊", "value": 7.0,
            "feed": 0.7, "breed_days": 6, "breed_chance": 0.55,
            "products": {"wool": 0.35, "milk": 0.45},
            "slaughter": {"meat": 5.0},
            "cold_hardiness": 0.9,
            "desc": "绒山羊。耐旱耐粗饲，坡上石缝里的草它都吃得到；山羊绒是值钱货。",
        },
        "camel": {
            "display": "双峰驼", "short": "驼", "value": 30.0,
            "feed": 1.6, "breed_days": 16, "breed_chance": 0.2,
            "products": {"wool": 0.3, "milk": 0.6},
            "slaughter": {"meat": 14.0},
            "cold_hardiness": 0.95,
            "desc": "双峰驼。驮货走远路的本事没有别的牲口能替；驼奶、驼绒都是稀罕物，养得慢。",
        },
        "donkey": {
            "display": "库车驴", "short": "驴", "value": 14.0,
            "feed": 1.1, "breed_days": 12, "breed_chance": 0.3,
            "products": {},
            "slaughter": {"meat": 8.0},
            "labor": 0.5,
            "cold_hardiness": 0.85,
            "desc": "库车驴。个头小、脾气犟，但驮土运木离不了它——一头驴抵半个劳力。",
        },
        "chicken": {
            "display": "吐鲁番鸡", "short": "鸡", "value": 3.0,
            "feed": 0.2, "breed_days": 4, "breed_chance": 0.7,
            "products": {"egg": 0.8},
            "slaughter": {"meat": 2.0},
            "cold_hardiness": 0.5,
            "desc": "吐鲁番鸡。吃剩饭、下蛋快、繁殖也快，是最便宜的肉蛋来源；一场寒潮就能冻没一半。",
        },
    },
    "jobs": {
        "herd": {
            "display": "放牧", "output": "照看牲畜，决定产出与繁殖是否满额",
            "per_herder_capacity": 8,
            "note": "1 个牧人照看 8 头；人手不足时超出的部分按'没人管'算（产出减半、不繁殖）。",
        },
    },
    "catch": {
        "display": "派人抓野畜", "labor_per_head": 2.0, "days": 1,
        "base_chance": 0.42, "tools_bonus": 0.06, "danger_display": "轻",
        "note": (
            "派人去草原牧场抓野畜：耗人力与干粮，成功率和队伍规模、工具、"
            "以及你去过几次有关。抓回来的是活畜，直接进栏。"
            "失败不扣人，只白费一趟人工——这是刻意的：失败要疼，但不该劝退。"
        ),
    },
    "wild": {
        "argali": {
            "display": "盘羊", "to": "sheep", "difficulty": 1.0, "count": [1, 2],
            "desc": "天山盘羊。犄角盘成一圈，耐寒耐走，抓回来就是好种羊。",
        },
        "goitered": {
            "display": "鹅喉羚", "to": "goat", "difficulty": 0.85, "count": [1, 2],
            "desc": "鹅喉羚。跑得极快，得下套子；抓到的多是幼羚，好驯。",
        },
        "wild_ass": {
            "display": "蒙古野驴", "to": "donkey", "difficulty": 1.15, "count": [1, 1],
            "desc": "蒙古野驴。倔，得围住耗它体力才套得上。",
        },
        "wild_camel": {
            "display": "野驼", "to": "camel", "difficulty": 1.6, "count": [1, 1],
            "desc": "野驼。极难近身，抓一头够吹一年——但多半是白跑一趟。",
        },
    },
    "products": {
        "wool": {"display": "羊毛", "unit": "斤", "base_price": 2.2,
                 "note": "擀毡、织毯、卖钱。加工作坊可增值。"},
        "egg": {"display": "禽蛋", "unit": "枚", "base_price": 0.8},
        "milk": {"display": "奶", "unit": "碗", "base_price": 1.4},
    },
    "winter_note": "冬季草料消耗 +30%（牲畜要靠膘过冬，吃不饱就掉膘、冻死）。",
    "winter_feed_multiplier": 1.3,
}

# ---------------------------------------------------------------------------
# 二、灾难（disasters）
# ---------------------------------------------------------------------------
d["disasters"] = {
    "display": "灾难",
    "note": (
        "每一种灾难都有明确的触发条件（季节 / 水位 / 人口密度 / 建筑），"
        "所以它不是「随机捣乱」，而是可以被预判、被准备的。"
        "玩家能用建筑（烽燧预警、仓库储粮、围墙挡沙、驿馆与居所隔离疫病）"
        "和各种储备把损失压下去——这是把'过冬'这条压力线具体化。"
    ),
    "enabled": True,
    "roll": {
        "per_day": True,
        "note": "每天结算时按季节筛出候选、各自掷骰；同时最多只会有一种灾难在发作。",
        "cooldown_days": 5,
        "cooldown_note": "刚遭过灾之后至少 5 天不会再遭，避免连续打击把玩家打死。",
    },
    "list": [
        {
            "id": "sandstorm", "display": "沙暴", "seasons": ["spring", "summer"],
            "base_chance": 0.17, "warn_building": "fengsui", "warn_text": "烽燧报信",
            "screen": "sand", "log_color": "#e8c07a",
            "effects": {"water_loss": 10.0, "morale": -5.0, "livestock_loss": 0.10,
                        "building_wear": 6.0},
            "mitigation": {"fengsui": 0.5},
            "desc": "黄风压过来，天变成土色。井口要先盖毡子，羊群要赶回圈——没准备的，人和牲口一起遭罪。",
        },
        {
            "id": "drought", "display": "大旱", "seasons": ["summer"],
            "base_chance": 0.15, "warn_building": "fengsui", "warn_text": "老人看云色不对",
            "screen": "heat", "log_color": "#e8a35a",
            "duration_days": 6, "flow_multiplier": 0.45,
            "effects": {"morale": -4.0, "farm_yield_mult": 0.6},
            "mitigation": {},
            "desc": "整月不见雨，坎儿井的出水量往下掉。这时候涝坝里存的那点水就是命。",
        },
        {
            "id": "flood", "display": "融雪洪水", "seasons": ["spring"],
            "base_chance": 0.12, "warn_building": "weijiang", "warn_text": "围墙拦得住",
            "screen": "water", "log_color": "#7fc4e8",
            "effects": {"water_gain": 45.0, "farm_destroy": 0.45, "building_wear": 10.0,
                        "morale": -3.0},
            "mitigation": {"weijiang": 0.35},
            "desc": "天山雪水一天之内全下来。水一下子多了，可它冲的是你的地——渠和墙都得顶住。",
        },
        {
            "id": "cold_snap", "display": "寒潮", "seasons": ["winter", "autumn"],
            "base_chance": 0.22, "warn_building": "cangku", "warn_text": "仓库里有存粮",
            "screen": "cold", "log_color": "#a8d0ff",
            "effects": {"livestock_loss": 0.30, "morale": -6.0, "food_loss": 12.0,
                        "population_loss_chance": 0.18},
            "mitigation": {"cangku": 0.3},
            "desc": "一夜之间河面封冻。牲畜掉膘、幼畜先倒，柴和粮不够的人家最难熬。",
        },
        {
            "id": "plague", "display": "瘟疫", "seasons": ["spring", "summer", "autumn", "winter"],
            "base_chance": 0.08, "warn_building": "yiguan", "warn_text": "驿馆能隔离",
            "screen": "sick", "log_color": "#b8d8a0",
            "effects": {"population_loss_chance": 0.35, "livestock_loss": 0.18,
                        "morale": -8.0},
            "mitigation": {"yiguan": 0.4, "juzhu": 0.25},
            "desc": "先是一个人拉肚子，第二天一圈人躺下。人畜都会传——这时候最不该做的就是聚在一起。",
        },
        {
            "id": "locust", "display": "蝗灾", "seasons": ["summer", "autumn"],
            "base_chance": 0.12, "warn_building": "chicken_note", "warn_text": "鸡群能吃掉一片",
            "screen": "locust", "log_color": "#d8c46a",
            "effects": {"farm_destroy": 0.65, "morale": -5.0},
            "mitigation": {},
            "desc": "天边一片沙沙响的云。蝗虫过处只剩秆子——放鸡进去能救回一小片，但救不了全部。",
        },
    ],
}

P.write_text(json.dumps(d, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

# ---- 自检 ----
chk = json.loads(P.read_text(encoding="utf-8"))
lv, ds = chk["livestock"], chk["disasters"]
print("  已写入 numbers.json")
print(f"  畜牧：{len(lv['species'])} 个畜种、{len(lv['wild'])} 种野畜、{len(lv['products'])} 种畜产")
for k, v in lv["species"].items():
    print(f"    {k:<8} {v['display']:<8} 价{v['value']:<6} 饲料{v['feed']:<5} "
          f"繁殖{v['breed_days']}天/{v['breed_chance']} 产出{list(v['products'].keys())}")
print(f"  灾难：{len(ds['list'])} 种")
for c in ds["list"]:
    print(f"    {c['id']:<10} {c['display']:<6} {','.join(c['seasons']):<28} "
          f"基础概率{c['base_chance']} 效果{list(c['effects'].keys())}")
print(f"  JSON 有效，顶层键 {len(chk)} 个")
