#!/usr/bin/env python -u
# -*- coding: utf-8 -*-
"""把《作品信息表》《团队分工与贡献说明》《申报书》归位到参赛材料，并更新提交清单。

⚠ 这个动作在 shell 里用 `-c` 跑过两次都**静默失败**（输出被转义吃掉、报错被 $null 吞掉），
所以改成写文件。**要看清失败原因，就别把 stderr 丢掉。**
"""
from __future__ import annotations

import shutil
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from _root import DELIVERABLES, PACK  # noqa: E402

DOCS = [
    "《坎儿井》作品信息表.docx",
    "《坎儿井》团队分工与贡献说明.docx",
    "《坎儿井》作品申报书.docx",
    "《坎儿井》作品申报书.pdf",
]

CHECK_ROW = "| — | **作品信息表 / 团队分工说明**（填报与评审用） | ✅ 已就绪 | `06-作品信息与团队分工/` |"

SECTION = """## 二之二、作品信息与团队分工（两份必备文档）

在线填报时按《作品信息表》逐项填写；评审需要的《团队分工与贡献说明》按正式格式写成
**七段式**（团队构成 / 成员分工 / 工作模块与负责人 / 协作与开发过程 / 原创贡献声明 /
使用工具与资源 / 承诺），可直接提交或打印签字。

| 文档 | 用途 |
|---|---|
| `06-作品信息与团队分工/《坎儿井》作品信息表.docx` | 在线填报逐项对照；含 AIGC 使用情况标注 |
| `06-作品信息与团队分工/《坎儿井》团队分工与贡献说明.docx` | 评审用；末页有承诺与签字位，需打印签字 |
| `06-作品信息与团队分工/《坎儿井》作品申报书.docx / .pdf` | 作品申报书（含「十一、团队分工与贡献」一章） |

---

"""


def main() -> None:
    # ① 汇入 06
    d = PACK / "06-作品信息与团队分工"
    d.mkdir(parents=True, exist_ok=True)
    got = []
    for n in DOCS:
        src = DELIVERABLES / n
        if src.exists():
            shutil.copy2(src, d / n)
            got.append("%s (%.0f KB)" % (n, src.stat().st_size / 1024))
        else:
            print("  [缺] %s" % src)
    print("  06-作品信息与团队分工：%d 个文件" % len(got))
    for g in got:
        print("    " + g)

    # ② 同步：申报书 PDF 进 04，docx 进 90
    for n, dst in (("《坎儿井》作品申报书.pdf", PACK / "04-答辩PPT"),
                   ("《坎儿井》作品申报书.docx", PACK / "90-原始材料")):
        src = DELIVERABLES / n
        if src.exists():
            shutil.copy2(src, dst / n)
            print("  同步 %s -> %s" % (n, dst.name))

    # ③ 更新提交清单
    p = PACK / "00-提交清单.md"
    t = p.read_text(encoding="utf-8")
    if "06-作品信息与团队分工" in t:
        print("  清单已引用 06 目录，跳过")
    else:
        t = t.replace("| 6 | 学生证扫描 | ➖ 仅国际赛需要 | — |",
                      "| 6 | 学生证扫描 | ➖ 仅国际赛需要 | — |\n" + CHECK_ROW, 1)
        t = t.replace("## 三、评分细则", SECTION + "## 三、评分细则", 1)
        p.write_text(t, encoding="utf-8")
        print("  00-提交清单.md 已更新（新增条目 + 二之二 章节）")

    print("\n  参赛材料目录：")
    for q in sorted(PACK.rglob("*")):
        rel = q.relative_to(PACK).as_posix()
        if q.is_dir():
            print("    [%s]/" % rel)
        elif q.suffix.lower() in (".md", ".docx", ".pdf", ".txt"):
            print("      %-56s %7.0f KB" % (rel, q.stat().st_size / 1024))


if __name__ == "__main__":
    main()
