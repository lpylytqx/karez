#!/usr/bin/env python -u
# -*- coding: utf-8 -*-
"""把展示稿里比例不匹配的截图换成**按框比例裁好的**版本。

改 4 处：
  · 第 2 页底部横带（框 9.8:1）→ 用整幅宽的绿洲横带
  · 第 4 页画面墙 4 张（每格 2.66:1）
  · 第 7 页三张卡片图（每张 1.65:1）
  · 第 9 页右下（2.42:1）

**大图页不换**（封面 / 第 5 页战斗 / 第 10 页收尾）—— 那些地方 HUD 清晰可读，
正是"这是真跑起来的游戏"的证据，不能裁。

每次替换都回读校验。
"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from _root import ROOT  # noqa: E402

F = ROOT / "scripts" / "pipeline" / "build_showcase.py"

JOBS = [
    ('SHOTS = ROOT / "docs" / "screenshots"',
     'SHOTS = ROOT / "docs" / "screenshots"\n'
     '# 按图片框比例裁好的截图（make_deck_crops.py 生成）—— 16:9 直接塞进超宽框会缩小留白\n'
     'CROPS = ROOT / "deliverables" / "assets" / "crops"',
     "常量 CROPS"),

    ('''    fit_box(s, SHOTS / "S10_deck_A_绿洲全景.png",
            Inches(1.10), Inches(5.96), Inches(10.4), Inches(1.06), frame=False)''',
     '''    fit_box(s, CROPS / "p2_绿洲横带.png",
            Inches(1.10), Inches(5.96), Inches(10.4), Inches(1.06), frame=False)''',
     "第 2 页横带"),

    ('''        (SHOTS / "S9_animal_A_有牲畜.png", "畜牧页", "抓野畜、养牲口、擀毡织毯"),
        (SHOTS / "S9_animal_E_木卡姆.png", "木卡姆", "奏乐台 + 艺人 + 热瓦普，才能办一场"),
        (SHOTS / "S10_deck_D_御敌布阵.png", "御敌之战", "自由布阵，兵种由岗位决定"),
        (SHOTS / "S9_animal_C_灾难日志.png", "灾难通告", "插画由本地 SDXL 生成"),''',
     '''        (CROPS / "p4_畜牧.png", "畜牧页", "抓野畜、养牲口、擀毡织毯"),
        (CROPS / "p4_木卡姆.png", "木卡姆", "奏乐台 + 艺人 + 热瓦普，才能办一场"),
        (CROPS / "p4_御敌.png", "御敌之战", "自由布阵，兵种由岗位决定"),
        (CROPS / "p4_灾难.png", "灾难通告", "插画由本地 SDXL 生成"),''',
     "第 4 页画面墙"),

    ('''        fit_box(s, [SHOTS / "S9_animal_E_木卡姆.png",
                    SHOTS / "S9_animal_A_有牲畜.png",
                    SHOTS / "S10_deck_C_事件卡.png"][i],''',
     '''        fit_box(s, [CROPS / "p7_木卡姆.png",
                    CROPS / "p7_畜牧.png",
                    CROPS / "p7_事件卡.png"][i],''',
     "第 7 页卡片图"),

    ('''    fit_box(s, SHOTS / "S11_建造菜单.png", Inches(8.30), Inches(5.28),
            Inches(4.0), Inches(1.65))''',
     '''    fit_box(s, CROPS / "p9_建造.png", Inches(8.30), Inches(5.28),
            Inches(4.0), Inches(1.65))''',
     "第 9 页右下"),
]


def main() -> None:
    t = F.read_text(encoding="utf-8")
    ok = 0
    for old, new, what in JOBS:
        if old not in t:
            print("  %-16s ✗ 锚点没匹配上" % what)
            continue
        t = t.replace(old, new, 1)
        ok += 1
        print("  %-16s ✓" % what)
    F.write_text(t, encoding="utf-8")

    back = F.read_text(encoding="utf-8")     # ★ 回读校验
    print("  回读校验：CROPS 引用 %d 处（应 ≥ 9）" % back.count("CROPS /"))
    import py_compile
    py_compile.compile(str(F), doraise=True)
    print("  语法检查通过；共改 %d 处" % ok)


if __name__ == "__main__":
    main()
