#!/usr/bin/env python -u
# -*- coding: utf-8 -*-
"""给演示导演加自检开关 --demo-shot：自动走完所有屏并逐屏截图。

为什么非加不可：这个项目上已经吃过三次「看着对、其实错」的亏。
演示导演要改 14 次游戏状态、开 4 个面板、还要起战斗 —— **只靠读代码是无法确认它不崩的**，
必须真的走一遍。

跑法：
    Godot_v4.7.2-stable_win64_console.exe --path scripts \\
        res://scenes/play.tscn -- --demo --demo-shot

跑完在 user:// 下留 14 张 demo_NN.png，并打印每一屏的标题；最后一屏走完自动退出。
"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from _root import ROOT  # noqa: E402

PLAY = ROOT / "scripts" / "scenes" / "play.gd"

FN = '''

## 自检：走一遍全部屏并逐屏截图（--demo-shot）。**只在自检时用，录制时不要加这个参数。**
func _demo_autorun() -> void:
	await get_tree().create_timer(1.2).timeout
	for i in range(DEMO_BEATS.size()):
		_demo_go(i)
		await get_tree().create_timer(1.1).timeout
		var img := get_viewport().get_texture().get_image()
		img.save_png("user://demo_%02d.png" % (i + 1))
		print("[演示] 第 %02d 屏  %s" % [i + 1, str(DEMO_BEATS[i].get("t", ""))])
	print("[演示] %d 屏全部走完，无异常" % DEMO_BEATS.size())
	get_tree().quit()
'''


def main() -> None:
    t = PLAY.read_text(encoding="utf-8")
    if "_demo_autorun" in t:
        print("  已装过自检开关，跳过")
        return
    t = t.rstrip("\n") + "\n" + FN

    anchor = '''	print("[演示] --demo 生效：共 %d 屏。空格/→ 下一屏，← 上一屏，H 隐藏提示条，R 重来。"
		% DEMO_BEATS.size())'''
    if anchor not in t:
        print("  [X] 找不到 _maybe_start_demo 的结尾锚点")
        return
    t = t.replace(anchor, anchor + '''

	if _has_cli_flag("--demo-shot"):
		_demo_autorun()''', 1)

    PLAY.write_text(t, encoding="utf-8")
    back = PLAY.read_text(encoding="utf-8")
    print("  回读校验：")
    for k in ("func _demo_autorun()", '_has_cli_flag("--demo-shot")', "_demo_autorun()"):
        print("    %-32s %s" % (k, "在 ✓" if k in back else "缺 ✗"))
    print("    play.gd 现在 %d 行" % len(back.splitlines()))


if __name__ == "__main__":
    main()
