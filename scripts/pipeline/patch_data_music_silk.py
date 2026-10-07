#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""补两块新疆特色数据：木卡姆（music）与艾德莱斯绸（silk 配方 + 棉花产出）。

为什么补：
  · 目标里的「音乐」一项此前只有奏乐台的 +1 士气，**没有木卡姆这个内容本身**
  · `economy.base_prices` 里一直有 `silk: 12.0`，但既没有棉花产出、也没有织绸配方 ——
    又是「价格表有价无货」那类空账

十二木卡姆是真实的新疆古典套曲（拉克 / 且比亚特 / 木夏吾莱克 / 恰尔尕 / 潘吉尕 /
乌孜哈勒 / 艾介姆 / 乌夏克 / 巴雅特 / 纳瓦 / 斯尕 / 依拉克）。这里取前六个作为
可演奏套曲，并在 note 里写明是十二套里的六套，不假装全都做了。

「办一场晚会要有一把热瓦普」是刻意的：这样
木料 → 作坊做热瓦普 → 奏乐台办木卡姆 就成了一条完整的链，
而不是又一个"点一下加士气"的按钮。

用法：.venv\\Scripts\\python.exe scripts\\pipeline\\patch_data_music_silk.py
"""
import sys as _sys
from pathlib import Path as _Path
_sys.path.insert(0, str(_Path(__file__).resolve().parent))
from _root import ROOT  # 路径唯一解析处，不再写死盘符
import json
from pathlib import Path

P = ROOT / "data" / "numbers.json"
d = json.loads(P.read_text(encoding="utf-8"))

# ---------------------------------------------------------------------------
# 木卡姆
# ---------------------------------------------------------------------------
d["music"] = {
    "display": "木卡姆",
    "note": (
        "十二木卡姆是真实的新疆古典套曲。这里取**前六套**作为可演奏曲目 —— "
        "不假装十二套都做了。"
        "办一场的条件：奏乐台在场、木卡姆艺人在场、库里有 1 把热瓦普（不消耗）。"
        "于是 木料 → 作坊做热瓦普 → 奏乐台办木卡姆 是一条完整的链，"
        "而不是又一个「点一下加士气」的按钮。"
    ),
    "performance": {
        "action_points": 2,
        "labor": 1,
        "cooldown_days": 3,
        "requires_building": "yinletai",
        "requires_npc": "muqam_yiren",
        "needs_item": {"instrument": 1},
        "note": "热瓦普只是要在库里（不消耗）—— 用完就断弦要重做的话，玩家会不敢办。",
    },
    "suites": [
        {"id": "rak", "display": "拉克", "mood": "庄重开场",
         "effects": {"morale": 10.0, "reputation": 3.0},
         "text": "拉克是十二木卡姆的第一套，起手庄重。"},
        {"id": "chebiyat", "display": "且比亚特", "mood": "热烈",
         "effects": {"morale": 12.0, "reputation": 2.0},
         "text": "且比亚特热闹，商队最爱听这一套。"},
        {"id": "mushavrak", "display": "木夏吾莱克", "mood": "抒情",
         "effects": {"morale": 14.0, "reputation": 2.0},
         "text": "木夏吾莱克慢，适合夜里点着灯听。"},
        {"id": "chargah", "display": "恰尔尕", "mood": "明快",
         "effects": {"morale": 11.0, "reputation": 4.0},
         "text": "恰尔尕节奏明快，孩子也跟着拍手。"},
        {"id": "panjigah", "display": "潘吉尕", "mood": "开阔",
         "effects": {"morale": 13.0, "reputation": 3.0},
         "text": "潘吉尕开阔，像站在戈壁上往远处看。"},
        {"id": "uzhal", "display": "乌孜哈勒", "mood": "苍凉",
         "effects": {"morale": 16.0, "reputation": 2.0},
         "text": "乌孜哈勒苍凉。遭过灾的年份，村里人偏爱听这一套。"},
    ],
}

# ---------------------------------------------------------------------------
# 艾德莱斯绸：棉花 → 绸
# ---------------------------------------------------------------------------
d["crafts"]["recipes"].append({
    "id": "silk", "display": "织艾德莱斯绸", "building": "zuofang",
    "input": {"cotton": 4}, "output": {"silk": 1},
    "note": "棉花 4 → 绸 1。艾德莱斯绸是扎经染色织出来的，本地最拿得出手的织物。",
})
d["crafts"]["goods"]["silk"] = {"display": "艾德莱斯绸", "note": "商队出高价收。"}
d["crafts"]["goods"]["cotton"] = {"display": "棉花", "note": "秋天收，织绸用。"}
d["economy"]["base_prices"]["cotton"] = 1.6

# 棉花产出挂到农业：秋季每个农夫额外收棉花。
# 为什么是秋天：新疆的棉花就是秋天采摘（吐鲁番一带），和葡萄同期。
d["agriculture"]["cotton"] = {
    "display": "棉花",
    "season_yield": {"autumn": 2.0},
    "note": "每名农夫在秋季额外收 2 单位棉花。产在秋天是因为新疆棉花就是秋收。",
}

P.write_text(json.dumps(d, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

chk = json.loads(P.read_text(encoding="utf-8"))
m = chk["music"]
print("  已写入 numbers.json")
print("  木卡姆：%d 套可演奏" % len(m["suites"]))
for s in m["suites"]:
    print("    %-12s %-10s %-8s %s" % (s["id"], s["display"], s["mood"], s["effects"]))
print("  办一场：行动点 %d，人力 %d，冷却 %d 天，需要 %s + %s + %s" % (
    m["performance"]["action_points"], m["performance"]["labor"],
    m["performance"]["cooldown_days"], m["performance"]["requires_building"],
    m["performance"]["requires_npc"], list(m["performance"]["needs_item"])))
print("  加工配方 %d 条（新增丝绸）" % len(chk["crafts"]["recipes"]))
print("  棉花：秋季 %.0f/农夫" % chk["agriculture"]["cotton"]["season_yield"]["autumn"])
print("  JSON 有效，顶层键 %d 个" % len(chk))
