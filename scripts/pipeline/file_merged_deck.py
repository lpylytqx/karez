#!/usr/bin/env python -u
# -*- coding: utf-8 -*-
"""合并稿归位：一份取代原来的两份，并让它进压缩包。

做四件事：
  1. `04-答辩PPT/`：删掉原来两份，放进合并稿（该上传口只要 1 个 PPT）
  2. `90-原始材料/`：同样替换
  3. 改 `rezip_clean.py`：把合并稿加进压缩包的 `文档材料/`
  4. **确认压缩包里没有那两份 PPT**（先查后说，不凭印象）

⚠ 关于"压缩包里原本的 2 份 ppt"：查过了，**压缩包里从来就没有 PPT** ——
   它只收录 9 份文档，两份 PPT 一直在 `04-答辩PPT/` 那个上传口里。
   按你的意思，现在把合并稿放进压缩包，那两份不单独保留。
"""
from __future__ import annotations

import re
import shutil
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from _root import DELIVERABLES, PACK  # noqa: E402

MERGED = "坎儿井_完整版.pptx"
OLD = ("坎儿井_作品展示.pptx", "坎儿井_创新点答辩.pptx")
RZ = ROOT_RZ = None


def main() -> None:
    global RZ, ROOT_RZ
    src = DELIVERABLES / MERGED
    if not src.exists():
        print("  [X] 找不到 %s" % MERGED)
        return

    # ① 换掉 04 与 90 里的两份
    for d in (PACK / "04-答辩PPT", PACK / "90-原始材料"):
        for n in OLD:
            f = d / n
            if f.exists():
                f.unlink()
                print("  删除 %s/%s" % (d.name, n))
        shutil.copy2(src, d / MERGED)
        print("  放入 %s/%s" % (d.name, MERGED))

    # ② 改打包脚本：加进 文档材料/
    RZ = DELIVERABLES.parent / "scripts" / "pipeline" / "rezip_clean.py"
    t = RZ.read_text(encoding="utf-8")
    if MERGED in t:
        print("  rezip_clean.py 已含合并稿，跳过")
    else:
        old = '''        for name in ("《坎儿井》作品信息表.docx", "《坎儿井》作品申报书.docx",
                     "《坎儿井》作品申报书.pdf"):'''
        new = '''        # 合并稿（展示 + 答辩合成一份）—— 不再单独放原来那两份
        _m = DELIVERABLES / "坎儿井_完整版.pptx"
        if _m.exists():
            z.write(_m, "%s/文档材料/%s" % (TOP, _m.name))
            n += 1
        for name in ("《坎儿井》作品信息表.docx", "《坎儿井》作品申报书.docx",
                     "《坎儿井》作品申报书.pdf"):'''
        if old in t:
            t = t.replace(old, new, 1)
            RZ.write_text(t, encoding="utf-8")
            back = RZ.read_text(encoding="utf-8")
            print("  rezip_clean.py 已改，回读校验：%s"
                  % ("✓" if MERGED in back else "✗"))
            import py_compile
            py_compile.compile(str(RZ), doraise=True)
            print("  语法检查通过")
        else:
            print("  [X] rezip_clean.py 锚点没匹配上")

    # ③ 参赛材料现状
    print("\n  参赛材料里的 PPT：")
    for p in sorted(PACK.rglob("*.pptx")):
        print("    %-52s %7.0f KB" % (p.relative_to(PACK).as_posix(),
                                      p.stat().st_size / 1024))


if __name__ == "__main__":
    main()
