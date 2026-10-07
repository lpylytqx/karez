#!/usr/bin/env python -u
# -*- coding: utf-8 -*-
"""修好刚才被我自己改坏的打包脚本。

发生了什么：
  我给 rezip_clean.py 加「填报辅助材料不进包」的保险，两个锚点只匹配上了一个 ——
  **常量定义没插进去**，只有使用它的那句插进去了 → `NameError: NEVER_PACK is not defined`
  → 打包脚本中途抛异常 → **包里 10 份文档全没写进去**（文件数 1393 → 1372）。

更要紧的是：**我的回读校验没能发现它。** 我查的是「文本里有没有 `NEVER_PACK`」，
被那句"使用"满足了，于是打印了 ✓。**分不清「定义了」和「用到了」的校验等于没校验** ——
和之前 `rstr` 那次（语法合法、跑起来 NameError）是同一类错。

这次的修法：
  ① 判定用**定义语句** `NEVER_PACK = `，不是裸名字
  ② 补完后**真的把打包脚本跑一遍**，并回读压缩包里文档材料的项数（应为 10）
  ③ 脚本写成文件执行 —— pwsh 里 heredoc 传 Python 会被转义吃掉，这个坑记过多次
"""
from __future__ import annotations

import py_compile
import sys
import zipfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from _root import ROOT, PACK  # noqa: E402

RZ = ROOT / "scripts" / "pipeline" / "rezip_clean.py"

CONST = '''

# 这几个是**填报辅助材料**，只给操作者自己对照，不随包提交：
#     · 在线填报速查表 —— 填报人看着填的，评审不需要
# 打包脚本是按目录批量收 docx 的，光靠"这次没拷进去"不够，写死排除才稳。
NEVER_PACK = ("速查表", "填报")
'''


def main() -> None:
    t = RZ.read_text(encoding="utf-8")

    # ① 用**定义语句**判定（不是裸名字）
    if "NEVER_PACK = " in t:
        print("  常量已在，未重复插入")
    else:
        anchor = 'KEEP_FONT = "ark-pixel-12px-proportional-zh_hans.ttf"'
        if anchor not in t:
            print("  [X] 找不到 KEEP_FONT 锚点")
            return
        t = t.replace(anchor, anchor + CONST.rstrip("\n"), 1)
        RZ.write_text(t, encoding="utf-8")
        print("  ✓ 已插入 NEVER_PACK 常量定义")

    # ② 回读：这次判定义语句 + 使用处**都要在**
    back = RZ.read_text(encoding="utf-8")
    has_def = "NEVER_PACK = " in back
    has_use = "in NEVER_PACK" in back
    print("  回读：定义 %s　使用 %s" % ("✓" if has_def else "✗",
                                       "✓" if has_use else "✗"))
    py_compile.compile(str(RZ), doraise=True)
    print("  语法检查通过")

    # ③ 真的跑一遍
    print("\n  === 重打包 ===")
    import subprocess
    r = subprocess.run([sys.executable, str(RZ)], capture_output=True, text=True,
                       encoding="utf-8", errors="replace")
    for line in (r.stdout or "").splitlines()[:4]:
        print("    " + line)
    if r.returncode != 0:
        print("    ✗ 退出码 %d" % r.returncode)
        print((r.stderr or "")[-400:])
        return

    # ④ 回读压缩包：文档材料必须是 10 项
    zp = PACK / "05-参赛打包ZIP" / "坎儿井_参赛包.zip"
    z = zipfile.ZipFile(zp)
    names = z.namelist()
    docs = [x for x in names if "/文档材料/" in x]
    total = len([x for x in names if not x.endswith("/")])
    quick = [x for x in names if "速查表" in x]
    print("\n  === 回读压缩包 ===")
    print("    文档材料 %d 项 %s（应为 10）" % (len(docs), "✓" if len(docs) == 10 else "✗"))
    print("    总文件数 %d %s（应 ≥1393）" % (total, "✓" if total >= 1393 else "✗"))
    print("    速查表在包内 %s（应无）" % ("✗ 有！" if quick else "无 ✓"))
    for d in sorted(docs):
        print("      " + d.split("/")[-1])


if __name__ == "__main__":
    main()
