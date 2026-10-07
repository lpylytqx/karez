#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""把 pipeline 下各脚本里写死的 `D:\\坎儿井` 换成从 _root 解析（修正版）。

⚠ 前面失败两次，原因都是**用 PowerShell 的 `-c` 传正则**：反斜杠被吃掉一层，
正则永远匹配不上，于是"跑成功但一个没改"。写正则必须写成文件，别走 shell 命令行。

规则（改完先 py_compile，过了才落盘）：
  1. `Path(r"D:\\坎儿井")` → `ROOT`，并在文件头插入 _root 导入
  2. 残留的 `"D:\\坎儿井\\xxx"` → `str(ROOT / "xxx")`
幂等：已导入 _root 的跳过。
"""
from __future__ import annotations

import py_compile
import re
import sys
import tempfile
from pathlib import Path

PIPE = Path(__file__).resolve().parent

HEADER = (
    "import sys as _sys\n"
    "from pathlib import Path as _Path\n"
    "_sys.path.insert(0, str(_Path(__file__).resolve().parent))\n"
    "from _root import ROOT  # 路径唯一解析处，不再写死盘符\n"
)

# 这些是**正则**：源码里写 \\ 表示匹配一个反斜杠
PATH_CALL = re.compile(r'Path\(\s*r"D:\\坎儿井"\s*\)')
LITERAL = re.compile(r'"D:\\坎儿井((?:\\[^"]*)?)"')


def patch(src: str) -> str:
    out = PATH_CALL.sub("ROOT", src)

    def _lit(m: re.Match) -> str:
        tail = (m.group(1) or "").strip("\\")
        return ('str(ROOT / "%s")' % tail.replace("\\", "/")) if tail else "str(ROOT)"

    return LITERAL.sub(_lit, out)


def main() -> None:
    changed, kept, skipped = [], [], []
    for p in sorted(PIPE.glob("*.py")):
        if p.name in ("_root.py", "fix_paths2.py", "refactor_hardcoded_paths.py"):
            continue
        src = p.read_text(encoding="utf-8")
        if "from _root import" in src:
            skipped.append(p.name)
            continue
        if "坎儿井" not in src:
            skipped.append(p.name)
            continue
        out = patch(src)
        if out == src:
            kept.append(p.name)
            continue
        lines = out.splitlines(True)
        ins = 0
        for i, ln in enumerate(lines):
            if ln.startswith(("import ", "from ")):
                ins = i
                break
        lines.insert(ins, HEADER)
        out = "".join(lines)
        try:
            with tempfile.NamedTemporaryFile("w", suffix=".py", delete=False,
                                             encoding="utf-8") as f:
                f.write(out)
                tmp = f.name
            py_compile.compile(tmp, doraise=True)
            p.write_text(out, encoding="utf-8")
            changed.append(p.name)
        except py_compile.PyCompileError as e:
            kept.append(p.name)
            print("    ! %s 语法不过：%s" % (p.name, str(e).splitlines()[-1][:70]))
    print("  已改 %d 个：%s" % (len(changed), changed))
    print("  无写死路径 %d 个" % len(kept))
    print("  已改过跳过 %d 个" % len(skipped))


if __name__ == "__main__":
    sys.exit(main())
