#!/usr/bin/env python -u
# -*- coding: utf-8 -*-
"""参赛材料终检 —— 一次把所有该核的东西核一遍。

分四类：
  A. 上传口完整性（对照 官网《作品提交流程使用说明》）
  B. 文档信息一致性（赛道 / 团队 / 姓名用字 / 日期）
  C. **文档里的数字与真实文件对得上吗** —— 这是本项目最常出错的一类
     （「数据里有、文档不更新」，已发生过十余次）
  D. PPT 本体（页数 / 页码 / 页脚 / 越界 / 过期数字）
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from _root import ROOT, PACK, DELIVERABLES, SCREENSHOTS  # noqa: E402

from docx import Document  # noqa: E402
from pptx import Presentation  # noqa: E402

DOCS = PACK / "06-作品信息与团队分工"
TRACK = "虚拟现实与游戏"
STALE = ["AIGC 类数字创意", "命题类", "371 项", "425.9 MB", "5453"]
NAMES = ["李鹏宇", "王焕楷", "李云天", "徐媛媛", "李中岩"]


def doc_text(p: Path) -> str:
    if p.suffix == ".docx":
        d = Document(p)
        t = "\n".join(x.text for x in d.paragraphs)
        for tb in d.tables:
            for r in tb.rows:
                t += "\n" + " | ".join(c.text for c in r.cells)
        return t
    if p.suffix == ".pptx":
        pr = Presentation(p)
        t = ""
        for s in pr.slides:
            for sh in s.shapes:
                if sh.has_text_frame:
                    t += sh.text_frame.text + "\n"
        return t
    if p.suffix == ".md":
        return p.read_text(encoding="utf-8")
    return ""


def real_numbers() -> dict:
    """从**真实文件**里数出来的数字，用来对照文档。"""
    n = {}
    num = json.loads((ROOT / "data" / "numbers.json").read_text(encoding="utf-8"))
    n["数据段"] = len(num)
    ev = json.loads((ROOT / "data" / "events.v1.json").read_text(encoding="utf-8"))
    evs = ev.get("events", ev) if isinstance(ev, dict) else ev
    n["事件"] = len(evs)
    n["建筑"] = len(num.get("buildings", {}).get("list", num.get("buildings", {})))
    n["岗位"] = len(num.get("jobs", {}).get("list", num.get("jobs", {})))
    dis = num.get("disasters", {})
    n["灾难"] = len(dis.get("list", dis))
    fest = num.get("festivals", {})
    n["节庆"] = len(fest.get("list", fest))
    mus = num.get("music", {})
    n["木卡姆"] = len(mus.get("suites", mus.get("list", [])) or [])
    cra = num.get("crafts", {})
    n["加工"] = len(cra.get("recipes", cra.get("list", [])) or [])
    liv = num.get("livestock", {})
    n["畜种"] = len(liv.get("species", liv.get("list", [])) or [])
    n["美术PNG"] = len([f for f in (ROOT / "assets").rglob("*.png")
                        if "_raw" not in str(f)])
    n["音频"] = len([f for f in (ROOT / "assets" / "audio").rglob("*")
                     if f.suffix in (".ogg", ".wav", ".mp3")])
    # 断言数：数测试脚本里的断言函数调用
    total = 0
    detail = {}
    for name in ("logic_test", "battle_edge", "livestock_disaster_test", "input_probe"):
        f = ROOT / "scripts" / "tests" / (name + ".gd")
        if f.exists():
            c = len(re.findall(r"^\s*_ok\(|^\s*_eq\(|^\s*_assert", f.read_text(encoding="utf-8"), re.M))
            detail[name] = c
            total += c
    n["断言"] = total
    n["断言明细"] = detail
    return n


def main() -> None:
    print("=" * 74)
    print("A. 上传口完整性")
    print("=" * 74)
    slots = [
        ("01-承诺书盖章扫描", "承诺书（系统生成→打印→盖公章）", "⬜ 待做"),
        ("作品截图10张", "作品截图（≤10 张）", "✅"),
        ("04-答辩PPT", "答辩 PPT / 视频 二选一", "✅"),
        ("05-参赛打包ZIP", "参赛打包 ZIP（≤10GB）", "✅"),
        ("06-作品信息与团队分工", "作品/团队文档", "✅"),
    ]
    for d, desc, st in slots:
        p = PACK / d
        cnt = len(list(p.rglob("*"))) if p.exists() else 0
        print("  %-6s %-32s %-28s %d 个文件" % (st, d, desc, cnt))
    shots = sorted((PACK / "作品截图10张").glob("*.jpg"))
    print("  作品截图 %d 张 %s" % (len(shots), "✓（≤10）" if len(shots) <= 10 else "✗ 超了"))

    print()
    print("=" * 74)
    print("B. 文档信息一致性")
    print("=" * 74)
    files = []
    for pat in ("06-作品信息与团队分工/*.docx", "04-答辩PPT/*.pdf",
                "参赛文档/*.docx"):
        pass
    for base in (DOCS, PACK / "06-作品信息与团队分工",
                 DELIVERABLES / "参赛文档"):
        if base.exists():
            files += list(base.glob("*.docx"))
    files += list(DELIVERABLES.glob("*.docx")) + list(DELIVERABLES.glob("*.pptx"))
    seen = set()
    for f in sorted(files, key=lambda x: x.name):
        if f.name in seen:
            continue
        seen.add(f.name)
        t = doc_text(f)
        if not t:
            continue
        probs = []
        if TRACK not in t and "游戏" not in f.name:
            probs.append("未提赛道")
        for s in STALE:
            if s in t:
                probs.append("过期表述「%s」" % s)
        if re.search(r"王焕(?!楷)", t):
            probs.append("「王焕」漏提手旁")
        print("  %-40s %s" % (f.name, "；".join(probs) if probs else "✓"))

    print()
    print("=" * 74)
    print("C. 文档里的数字 vs 真实文件")
    print("=" * 74)
    n = real_numbers()
    print("  真实数据：")
    for k in ("数据段", "事件", "建筑", "岗位", "灾难", "节庆", "木卡姆", "加工",
              "畜种", "美术PNG", "音频", "断言"):
        print("    %-10s %s" % (k, n[k]))
    print("    断言明细 %s" % n["断言明细"])
    print()
    # 拿申报书正文比
    props = DOCS / "《坎儿井》作品申报书.docx"
    if props.exists():
        t = doc_text(props)
        checks = [
            ("388 项", "断言总数 %d" % n["断言"], n["断言"] == 388),
            ("64 条", "事件 %d" % n["事件"], n["事件"] == 64),
            ("13 座", "建筑 %d" % n["建筑"], n["建筑"] == 13),
            ("23 个顶层", "数据段 %d" % n["数据段"], n["数据段"] == 23),
            ("419 张", "美术 %d" % n["美术PNG"], abs(n["美术PNG"] - 419) < 40),
        ]
        for lit, real, ok in checks:
            in_doc = lit in t
            print("    申报书写「%-12s」实际 %-14s 文档%s %s"
                  % (lit, real, "有" if in_doc else "无",
                     "✓" if (in_doc and ok) else "⚠ 对不上"))

    print()
    print("=" * 74)
    print("D. PPT 本体")
    print("=" * 74)
    deck = DELIVERABLES / "坎儿井_完整版.pptx"
    pr = Presentation(deck)
    W, H = pr.slide_width, pr.slide_height
    over = 0
    for s in pr.slides:
        for sh in s.shapes:
            try:
                if sh.left + (sh.width or 0) > W + 10000 or \
                   sh.top + (sh.height or 0) > H + 10000:
                    over += 1
            except Exception:
                pass
    txt = doc_text(deck)
    print("    页数 %d（应 21）%s" % (len(pr.slides), "✓" if len(pr.slides) == 21 else "✗"))
    print("    越界元素 %d %s" % (over, "✓" if over == 0 else "✗"))
    print("    页脚「坎儿井 · 代码一次敲队」×%d" % txt.count("坎儿井　·　代码一次敲队"))
    print("    页脚带指导老师的行 %d（应 0）%s"
          % (len(re.findall(r"代码一次敲队\s*·\s*指导教师", txt)),
             "✓" if not re.search(r"代码一次敲队\s*·\s*指导教师", txt) else "✗"))
    print("    封面保留「指导教师：徐媛媛」：%s"
          % ("是 ✓" if "指导教师：徐媛媛" in txt else "否 ✗"))
    for s in STALE:
        if s in txt:
            print("    ⚠ PPT 里有过期表述「%s」" % s)
    print("    「AIGC」出现 %d 次（应只在 AI 使用说明里，PPT 应为 0）" % txt.count("AIGC"))

    print()
    print("=" * 74)
    print("E. 压缩包")
    print("=" * 74)
    import zipfile
    zp = PACK / "05-参赛打包ZIP" / "坎儿井_参赛包.zip"
    z = zipfile.ZipFile(zp)
    names = [x for x in z.namelist() if not x.endswith("/")]
    print("    文件数 %d  大小 %.1f MB  顶层 %s"
          % (len(names), zp.stat().st_size / 1024 / 1024,
             sorted({x.split("/")[0] for x in names})))
    bad = [x for x in names if any(k in x for k in
           (".venv/", "logs/", "assets/_raw/", "dsh-image-gen/", "deliverables/"))]
    print("    混入开发文件：%s" % (bad[:3] if bad else "无 ✓"))
    print("    包内 PPT：%s" % [x.split("/")[-1] for x in names if x.lower().endswith(".pptx")])


if __name__ == "__main__":
    main()
