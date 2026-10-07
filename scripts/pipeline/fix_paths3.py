#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""接 fix_paths2 的第二轮：处理「头文件插到了 from __future__ 之前」的那 12 个。

第一轮的插入规则是"插到第一个 import 之前"，但 `from __future__ import annotations`
**必须是文件里第一条语句**，插到它前面就直接语法错 —— 好在那轮有 py_compile 把关，
错的一个都没落盘（安全网有用）。

这轮改成：**先跳过 docstring 与 `from __future__`，再插到第一条真正的 import 前。**
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
PATH_CALL = re.compile(r'Path\(\s*r"D:\\坎儿井"\s*\)')
LITERAL = re.compile(r'"D:\\坎儿井((?:\\[^"]*)?)"')


def insert_at(lines: list[str]) -> int:
    """返回该插入的下标：跳过 shebang / 编码行 / docstring / from __future__。"""
    i = 0
    n = len(lines)
    if i < n and lines[i].startswith("#!"):
        i += 1
    if i < n and "coding" in lines[i] and lines[i].lstrip().startswith("#"):
        i += 1
    # 模块 docstring
    while i < n and not lines[i].strip():
        i += 1
    if i < n and lines[i].lstrip().startswith(('"""', "'''")):
        q = lines[i].lstrip()[:3]
        if lines[i].count(q) >= 2 and len(lines[i].strip()) > 3:
            i += 1
        else:
            i += 1
            while i < n and q not in lines[i]:
                i += 1
            i += 1
    # from __future__
    while i < n and not lines[i].strip():
        i += 1
    while i < n and lines[i].startswith("from __future__"):
        i += 1
        while i < n and (lines[i].startswith((" ", "\t", ")")) or not lines[i].strip()):
            i += 1
    return i


def patch(src: str) -> str:
    out = PATH_CALL.sub("ROOT", src)

    def _lit(m: re.Match) -> str:
        tail = (m.group(1) or "").strip("\\")
        return ('str(ROOT / "%s")' % tail.replace("\\", "/")) if tail else "str(ROOT)"

    return LITERAL.sub(_lit, out)


def main() -> None:
    changed, fail, skipped = [], [], []
    for p in sorted(PIPE.glob("*.py")):
        if p.name in ("_root.py", "fix_paths2.py", "fix_paths3.py",
                      "refactor_hardcoded_paths.py"):
            continue
        src = p.read_text(encoding="utf-8")
        if "from _root import" in src:
            skipped.append(p.name)
            continue
        out = patch(src)
        if out == src:
            skipped.append(p.name)
            continue
        lines = out.splitlines(True)
        lines.insert(insert_at(lines), HEADER)
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
            fail.append(p.name)
            print("    ! %s：%s" % (p.name, str(e).splitlines()[-1][:70]))
    print("  已改 %d 个：%s" % (len(changed), changed))
    print("  仍失败 %d 个：%s" % (len(fail), fail))
    print("  跳过 %d 个" % len(skipped))


if __name__ == "__main__":
    sys.exit(main())
