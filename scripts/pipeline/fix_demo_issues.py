#!/usr/bin/env python -u
# -*- coding: utf-8 -*-
"""修演示导演的自检里暴露的两个问题。

问题一（自检截图暴露的）：**事件卡不关，把第 6~14 屏全挡住了。**
  根因：`_hud._close_pages()` 只关 4 个面板（分工/建造/畜牧/音乐），
  **不含 `_popup`（事件卡与灾难通告）** —— 这个坑项目里记过一次
  （"灾难通告卡盖住了音乐面板，因为它不在 _close_pages 里"），这次又踩。
  改法：换屏前的清理里补上 `_hud._popup.visible = false`。

问题二：**「御敌之战」横幅从第 1 屏就挂着**，而战斗要到第 6 屏才该出现。
  改法：换屏前 `_hud.hide_battle_panel()`；第 6 屏的 `_start_raid` 会再把它显示出来。

问题三（顺带）：**提示条压在游戏顶栏上**，挡住了水/粮/银的数字。
  改法：从 `(0,0,640,42)` 挪到地图下缘 `(6,224,430,40)` —— 顶栏 0~78、底栏 268~360，
  224~264 落在两者之间，不压任何 HUD 元素。
"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from _root import ROOT  # noqa: E402

PLAY = ROOT / "scripts" / "scenes" / "play.gd"

JOBS = [
    # ① 换屏前的清理：补上事件卡与战斗横幅
    ('''	if _hud != null:
		_hud._close_pages()
	get_viewport().gui_release_focus()''',
     '''	if _hud != null:
		_hud._close_pages()
		# ⚠ _close_pages() **不含** _popup（事件卡/灾难通告）—— 上一次自检里
		#   事件卡没关，把第 6~14 屏全挡住了，就是漏了这一句。
		if _hud._popup != null:
			_hud._popup.visible = false
		# 战斗横幅只有在御敌那一屏才该出现
		_hud.hide_battle_panel()
	get_viewport().gui_release_focus()''',
     "① 换屏清理补事件卡 + 战斗横幅"),

    # ② 提示条挪到地图下缘，不再压顶栏
    ('''	p.position = Vector2.ZERO
	p.size = Vector2(640, 42)''',
     '''	# 放在地图下缘：顶栏 0~78、底栏 268~360，224~264 落在两者之间
	# （上一版放在 (0,0)，把顶栏的水/粮/银数字全挡住了）
	p.position = Vector2(6, 224)
	p.size = Vector2(430, 40)''',
     "② 提示条挪到地图下缘"),

    ('''	_demo_step = _demo_label(p, Vector2(8, 3), Vector2(300, 12), "", 10,
		Color(0.878, 0.643, 0.235))
	_demo_title = _demo_label(p, Vector2(8, 15), Vector2(624, 14), "", 13,
		Color(0.941, 0.894, 0.816))
	_demo_note = _demo_label(p, Vector2(8, 30), Vector2(624, 11), "", 9,
		Color(0.710, 0.643, 0.549))''',
     '''	_demo_step = _demo_label(p, Vector2(7, 2), Vector2(200, 11), "", 9,
		Color(0.878, 0.643, 0.235))
	_demo_title = _demo_label(p, Vector2(7, 13), Vector2(416, 13), "", 12,
		Color(0.941, 0.894, 0.816))
	_demo_note = _demo_label(p, Vector2(7, 27), Vector2(416, 11), "", 8,
		Color(0.710, 0.643, 0.549))''',
     "③ 提示条内部三行位置"),
]


def main() -> None:
    t = PLAY.read_text(encoding="utf-8")
    n = 0
    for old, new, what in JOBS:
        if old not in t:
            print("  %-26s %s" % (what, "已是新写法" if new in t else "✗ 锚点没匹配上"))
            continue
        t = t.replace(old, new, 1)
        n += 1
        print("  %-26s ✓" % what)
    if n == 0:
        return
    PLAY.write_text(t, encoding="utf-8")
    back = PLAY.read_text(encoding="utf-8")
    print("\n  回读校验：")
    for k in ("_hud._popup != null", "_hud.hide_battle_panel()",
              "p.position = Vector2(6, 224)"):
        print("    %-32s %s" % (k, "在 ✓" if k in back else "缺 ✗"))
    print("  play.gd 现在 %d 行" % len(back.splitlines()))


if __name__ == "__main__":
    main()
