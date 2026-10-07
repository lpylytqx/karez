#!/usr/bin/env python -u
# -*- coding: utf-8 -*-
"""给演示导演加两个**前置屏**，让讲解稿能按「文化 → 游戏简介 → 细节」的顺序讲。

用户指出的结构问题：原稿一上来就是「第 1 屏 开局：一段井都没挖」，
等于**直接进细节、没有交代背景**。正确的讲解顺序应该是：

    ① 新疆文化 —— 坎儿井是什么、为什么值得做成游戏   ← 需要一屏大漠全景
    ② 游戏简介 —— 这是一款什么游戏                   ← 需要一屏绿洲全貌
    ③ 逐屏细节 —— 原来的 14 屏

加的两屏（用画面本身把两段话托住）：

    屏 1「新疆与坎儿井」  0 段竖井 + 缩到最小（0.5×）→ 满屏荒漠，
                          讲「年降水不足 20 毫米」最有画面感
    屏 2「这是什么游戏」  6 段竖井 + 人口 12 + 资源足，中景绿洲全貌
                          → 先给观众一个「成品长什么样」，
                            然后第 3 屏再回到一片荒地开局（先预告、再正片）

加完是 **16 屏**。原来 14 屏的编号整体后移两位。
"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from _root import ROOT  # noqa: E402

PLAY = ROOT / "scripts" / "scenes" / "play.gd"

OLD_HEAD = '''const DEMO_BEATS := [
	{"t": "开局：一段井都没挖", "d": "沙地、枯树、破驿站 —— 不挖井就活不过第一周", "m": "_demo_b01"},'''

NEW_HEAD = '''const DEMO_BEATS := [
	{"t": "新疆与坎儿井", "d": "干旱区、两千年、国家级非遗 + 世界灌溉工程遗产", "m": "_demo_p01"},
	{"t": "这是什么游戏", "d": "先看一眼成品：一座丝路驿站的完整形态", "m": "_demo_p02"},
	{"t": "开局：一段井都没挖", "d": "沙地、枯树、破驿站 —— 不挖井就活不过第一周", "m": "_demo_b01"},'''

NEW_FNS = '''

## ── 前置屏 ①：新疆与坎儿井 ──
## 画面用「缩到最小的荒漠全景」，让"极端干旱区"这句话有画面托着。
func _demo_p01() -> void:
	_demo_put(["karez", "sections"], 0)
	_demo_put(["population"], 3)
	_demo_put(["calendar", "day"], 1)
	_demo_put(["calendar", "season"], "summer")
	_demo_put(["stats", "morale"], 50.0)
	_game.clamp_all()
	_game.state_changed.emit()
	# 0 号档 = 0.5 倍，整张 40x22 的地图都在画面里，大半是沙
	_demo_cam(0)


## ── 前置屏 ②：这是什么游戏 ──
## 先给观众看「成品是什么样」，第 3 屏再回到一片荒地 —— 先预告、再正片。
func _demo_p02() -> void:
	_demo_put(["karez", "sections"], 6)
	_demo_put(["population"], 12)
	_demo_feed()
	_demo_put(["calendar", "season"], "autumn")
	_game.clamp_all()
	_game.state_changed.emit()
	_demo_cam(1)
'''


def main() -> None:
    t = PLAY.read_text(encoding="utf-8")
    n = 0
    if "_demo_p01" in t:
        print("  已有前置屏，跳过")
        return
    if OLD_HEAD in t:
        t = t.replace(OLD_HEAD, NEW_HEAD, 1)
        n += 1
        print("  ✓ DEMO_BEATS 头部插入两屏")
    else:
        print("  ✗ DEMO_BEATS 头部锚点没匹配上")
        return

    anchor = "\n\nfunc _demo_feed() -> void:"
    if anchor not in t:
        print("  ✗ 找不到 _demo_feed 锚点")
        return
    t = t.replace(anchor, NEW_FNS + anchor, 1)
    n += 1
    print("  ✓ 插入 _demo_p01 / _demo_p02")

    PLAY.write_text(t, encoding="utf-8")
    back = PLAY.read_text(encoding="utf-8")
    print("\n  回读校验：")
    # ⚠ 判"定义了"而不是"出现过" —— 上次就是这里栽的
    for k, label in (("func _demo_p01() -> void:", "屏①定义"),
                     ("func _demo_p02() -> void:", "屏②定义"),
                     ('"m": "_demo_p01"', "屏①挂进列表"),
                     ('"m": "_demo_p02"', "屏②挂进列表"),
                     ("_demo_cam(0)", "屏①用最小缩放")):
        print("    %-12s %s" % (label, "✓" if k in back else "✗"))
    print("    BEATS 条数 %d（应为 16）" % back.count('"m": "_demo_'))


if __name__ == "__main__":
    main()
