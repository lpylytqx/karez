#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""补两块新疆特色的数据：加工（crafts）与节庆（festivals）。

为什么补这两块：
  1. `economy.base_prices` 里早就有 raisin / silk / rug / instrument / hama
     这些物产的价格，但**没有任何系统产出它们** —— 价格表是空的。
  2. 畜牧系统产出的**羊毛完全没有用处**（羊毛只是躺在 resources.products 里）。
     加上「擀毡子 / 织地毯」之后，养羊才真正有经济回报 ——
     否则畜牧的产出只是个数字，换不成钱也换不成东西。

节庆用真实的新疆节庆：诺鲁孜节（春分迎新）、葡萄熟了（秋收）、古尔邦节（宰牲待客）。
**日期是固定到季+天的**（游戏里可预期才好玩）；古尔邦节在现实中按伊斯兰历浮动，
这里为玩法固定，并在 note 里说明，不假装精确。

用法：.venv\\Scripts\\python.exe scripts\\pipeline\\patch_data_crafts_festivals.py
幂等：重复运行会覆盖这两块。
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
# 加工
# ---------------------------------------------------------------------------
d["crafts"] = {
    "display": "加工",
    "note": (
        "把原料变成值钱的成品。**作坊（zuofang）是总门槛** —— 没有作坊就只能卖原料，"
        "价格差好几倍。晾房单独管葡萄干（它有专门的 fruit_to_raisin_rate）。"
        "每条配方每天最多跑一次，原料不够就跳过（不会扣一半）。"
    ),
    "recipes": [
        {
            "id": "raisin", "display": "晾葡萄干", "building": "liangfang",
            "input": {"fruit": 4}, "output": {"raisin": 1},
            "note": "瓜果 4 → 葡萄干 1。保质期 8 天 → 120 天，是过冬的关键。",
        },
        {
            "id": "felt", "display": "擀毡子", "building": "zuofang",
            "input": {"wool": 3}, "output": {"felt": 1},
            "note": "羊毛 3 → 毡子 1。这是养羊**真正换钱**的那一步。",
        },
        {
            "id": "rug", "display": "织地毯", "building": "zuofang",
            "input": {"wool": 6, "cloth": 2}, "output": {"rug": 1},
            "note": "地毯是这里最值钱的手工，工期长、要的料也多。",
        },
        {
            "id": "instrument", "display": "做热瓦普", "building": "zuofang",
            "input": {"wood": 6, "tools": 1}, "output": {"instrument": 1},
            "note": "木料 6 + 工具 1 → 热瓦普 1。商队最认这个 —— 一把顶十几袋粮。",
        },
    ],
    "felt": {"display": "毡子", "unit": "张", "base_price": 9.0,
             "note": "擀毡是游牧的老手艺。毡子铺炕、搭毡房、卖给商队都行。"},
}

# 把新物产的价格也补进 economy.base_prices（价格表原来缺 felt）
d["economy"]["base_prices"]["felt"] = 9.0
# 羊毛本身也要有价，否则只能加工不能直接卖
d["economy"]["base_prices"]["wool"] = 2.2

# ---------------------------------------------------------------------------
# 节庆
# ---------------------------------------------------------------------------
d["festivals"] = {
    "display": "节庆",
    "note": (
        "全是真实的新疆节庆，用来给一年定几个「喘口气、也露个脸」的节点。"
        "触发方式是季 + 天固定（游戏里可预期才好玩）。"
        "⚠ 古尔邦节在现实中按伊斯兰历浮动，这里为玩法固定到秋季第 40 天，"
        "   不假装精确 —— 要的是「一年里有几个值得记住的日子」。"
    ),
    "list": [
        {
            "id": "noruz", "display": "诺鲁孜节", "season": "spring", "day": 3,
            "effects": {"morale": 12.0, "reputation": 4.0},
            "text": "春分。熬一锅诺鲁孜粥，邻里互相走动，新的一年从这天算起。",
        },
        {
            "id": "grape", "display": "葡萄熟了", "season": "autumn", "day": 12,
            "effects": {"morale": 8.0, "silver": 6.0},
            "text": "葡萄下架、晾房上架。全村一起干活，晚上在奏乐台上跳起舞来。",
        },
        {
            "id": "qurban", "display": "古尔邦节", "season": "autumn", "day": 40,
            "effects": {"morale": 15.0, "reputation": 6.0},
            "text": "宰牲待客。家里有牲口的这天最体面 —— 养牲畜的回报不只是钱。",
            "bonus_if_livestock": {"min": 5, "reputation": 4.0,
                "text": "院里牲口多，来的人也多。"},
        },
    ],
}

P.write_text(json.dumps(d, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

chk = json.loads(P.read_text(encoding="utf-8"))
c, f = chk["crafts"], chk["festivals"]
print("  已写入 numbers.json")
print("  加工配方 %d 条：" % len(c["recipes"]))
for r in c["recipes"]:
    print("    %-12s %-8s 需要 %-14s -> %s" % (
        r["id"], r["display"], ",".join(r["input"]) or "-", ",".join(r["output"])))
print("  新物产 felt 价格 %.1f，wool 价格 %.1f" % (
    chk["economy"]["base_prices"]["felt"], chk["economy"]["base_prices"]["wool"]))
print("  节庆 %d 个：" % len(f["list"]))
for x in f["list"]:
    print("    %-10s %-8s 每年 %s 第 %d 天  效果 %s" % (
        x["id"], x["display"], x["season"], x["day"], x["effects"]))
print("  JSON 有效，顶层键 %d 个" % len(chk))
