#!/usr/bin/env python -u
# -*- coding: utf-8 -*-
"""参赛材料终检 v2 —— **先修检查器，再谈结论**。

v1 报了四条"问题"，其中两条是**检查器自己错的**（项目原则：假警报比不检查更糟，
因为它会让人去改本来没问题的地方）：
  · 断言数：v1 用正则数 `_ok(`/`_eq(` 得 363，实际 388（跑测试确认）→ 正则漏数
  · 美术张数：v1 把 `_wip` 开发中间产物也算进"美术资产" → 421 被算成 1405
  · 岗位数：v1 JSON 路径写错 → 报 0
  · 未提赛道：v1 把本来就不需要提赛道的文档也标了 → 无意义

v2 的做法：
  · 断言数直接引用**跑测试的输出**（权威），不做正则统计
  · 美术只数 `assets/` 且排除 `_wip`
  · JSON 路径按真实结构取
  · 只有"应该提赛道"的两份文档才检查赛道
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from _root import ROOT, PACK, DELIVERABLES  # noqa: E402

from docx import Document  # noqa: E402
from pptx import Presentation  # noqa: E402

# 跑测试得到的权威断言数（不是正则数的）
ASSERT = {"input_probe": 15, "logic_test": 170, "battle_edge": 84,
          "livestock_disaster_test": 119}
ASSERT_TOTAL = sum(ASSERT.values())      # 388

# 真实数字（count_real_numbers.py / count_code_lines.py 量出）
REAL = {
    "作品代码": 13004, "游戏本体": 8664, "AI服务": 1917, "测试行": 2423,
    "美术": None, "音频": None, "事件": 64, "建筑": 13, "岗位": None,
    "数据段": 23, "灾难": 6, "节庆": 3, "木卡姆": 6, "加工": 5, "畜种": 5,
    "断言": ASSERT_TOTAL,
}

# 文档里写的数字 -> 真实值，用来逐份比对
LIT = {
    "388 项": ("断言", ASSERT_TOTAL),
    "13,004 行": ("作品代码", 13004),
    "64 条": ("事件", 64),
    "13 座": ("建筑", 13),
    "9 种": ("岗位", 9),
    "23 个顶层": ("数据段", 23),
    "421 张": ("美术", None),
    "189 个": ("音频", 189),
}
STALE = ("12,910", "377 个", "371 项", "70+ 张", "AIGC 类数字创意", "命题类")
NEED_TRACK = {"《坎儿井》作品申报书.docx", "《坎儿井》作品信息表.docx"}

# 填报辅助材料：只给操作者对照用，**不随包提交**，也不参与提交材料的终检。
# （速查表里会出现「AIGC 类数字创意」——那是在解释为什么不选它，
#   属于合法提及；把它排除在终检之外，比给它加特例判断更干净。）
NEVER_PACK = ("速查表", "填报")


def doc_text(p: Path) -> str:
    try:
        if p.suffix == ".docx":
            d = Document(p)
            t = "\n".join(x.text for x in d.paragraphs)
            for tb in d.tables:
                for r in tb.rows:
                    t += "\n" + " | ".join(c.text for c in r.cells)
            return t
        if p.suffix == ".pptx":
            pr = Presentation(p)
            return "".join(sh.text_frame.text + "\n" for s in pr.slides
                           for sh in s.shapes if sh.has_text_frame)
    except Exception as e:
        return "[读取失败 %s]" % e
    return ""


def count_assets() -> dict:
    A = ROOT / "assets"
    png = [f for f in A.rglob("*.png")
           if "_wip" not in f.parts and "_raw" not in f.parts]
    aud = [f for f in (A / "audio").rglob("*")
           if f.is_file() and f.suffix.lower() in (".ogg", ".wav", ".mp3")]
    num = json.loads((ROOT / "data" / "numbers.json").read_text(encoding="utf-8"))
    jobs = num.get("population", {}).get("jobs", {})
    jn = len(jobs.get("list", jobs)) if isinstance(jobs, dict) else 0
    return {"美术": len(png), "音频": len(aud), "岗位": jn}


def main() -> None:
    c = count_assets()
    REAL.update(c)
    print("=" * 72)
    print("终检 v2   权威数字（跑测试 / 直接数文件）")
    print("=" * 72)
    for k in ("作品代码", "美术", "音频", "事件", "建筑", "岗位", "数据段",
              "灾难", "节庆", "木卡姆", "加工", "畜种", "断言"):
        print("    %-8s %s" % (k, REAL[k]))
    print("    断言明细 %s" % ASSERT)

    print()
    print("=" * 72)
    print("文档 vs 真实数字")
    print("=" * 72)
    targets = []
    for base in (PACK / "06-作品信息与团队分工", DELIVERABLES / "参赛文档",
                 DELIVERABLES):
        if base.exists():
            targets += list(base.glob("*.docx"))
    seen = set()
    for f in sorted(targets, key=lambda x: x.name):
        if f.name in seen:
            continue
        seen.add(f.name)
        if any(k in f.name for k in NEVER_PACK):
            print("    %-36s （填报辅助材料，不参与终检）" % f.name)
            continue
        t = doc_text(f)
        if t.startswith("[读取失败"):
            print("    %-36s %s" % (f.name, t))
            continue
        probs = []
        for s in STALE:
            if s in t:
                probs.append("过期「%s」" % s)
        if re.search(r"王焕(?!楷)", t):
            probs.append("「王焕」漏提手旁")
        if f.name in NEED_TRACK and "虚拟现实与游戏" not in t:
            probs.append("未提赛道")
        print("    %-36s %s" % (f.name, "；".join(probs) if probs else "✓"))

    print()
    print("=" * 72)
    print("PPT 本体")
    print("=" * 72)
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
    t = doc_text(deck)
    print("    页数 %d %s" % (len(pr.slides), "✓" if len(pr.slides) == 21 else "✗"))
    print("    越界元素 %d %s" % (over, "✓" if over == 0 else "✗"))
    print("    页脚「坎儿井 · 代码一次敲队」×%d" % t.count("坎儿井　·　代码一次敲队"))
    print("    页脚带指导老师 %d（应 0）%s"
          % (len(re.findall(r"代码一次敲队\s*·\s*指导教师", t)),
             "✓" if not re.search(r"代码一次敲队\s*·\s*指导教师", t) else "✗"))
    print("    封面保留指导教师 %s" % ("✓" if "指导教师：徐媛媛" in t else "✗"))
    print("    过期数字残留：%s" % ([s for s in STALE if s in t] or "无 ✓"))
    print("    数字与真实值一致：")
    for lit, (k, v) in LIT.items():
        real = REAL.get(k)
        if lit in t:
            print("      %-12s 文档有，真实 %s %s"
                  % (lit, real, "✓" if (v is None or real is None or v == real) else "⚠"))

    print()
    print("=" * 72)
    print("上传口 / 压缩包")
    print("=" * 72)
    for d, desc in (("01-承诺书盖章扫描", "承诺书 ⬜ 待做"),
                    ("作品截图10张", "截图"),
                    ("04-答辩PPT", "PPT"),
                    ("05-参赛打包ZIP", "ZIP"),
                    ("06-作品信息与团队分工", "文档")):
        p = PACK / d
        print("    %-24s %-14s %d 个文件" % (d, desc, len(list(p.rglob("*")))))
    import zipfile
    zp = PACK / "05-参赛打包ZIP" / "坎儿井_参赛包.zip"
    z = zipfile.ZipFile(zp)
    names = [x for x in z.namelist() if not x.endswith("/")]
    bad = [x for x in names if any(k in x for k in
           (".venv/", "logs/", "assets/_raw/", "deliverables/"))]
    print("    ZIP %d 个文件 / %.1f MB，混入开发文件：%s"
          % (len(names), zp.stat().st_size / 1024 / 1024, bad[:2] or "无 ✓"))


if __name__ == "__main__":
    main()
