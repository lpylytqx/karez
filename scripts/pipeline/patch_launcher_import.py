#!/usr/bin/env python -u
# -*- coding: utf-8 -*-
"""给启动器加「首次运行自动导入素材」这一步。

为什么需要：`.tscn` 里存的是**导入后**的资源路径（`.godot/imported/*.ctex`）。
把 `.godot/` 缓存排除出参赛包能省 90 MB，但 Godot **直接运行时不会自动重建它** ——
实测会报 `Unable to open file: res://.godot/imported/…ctex`，贴图加载失败。
（`--import` 是编辑器侧的导入流程，普通运行不带。）

所以让启动器自己处理：**没有 .godot 就先跑一次 --import，再启动**。
这样包保持 183 MB，首次运行多花十几秒。

⚠ 编码按项目约定：**.bat 一律 GBK + CRLF**（中文 Windows 的 cmd 默认代码页 936，
UTF-8 的 bat 会乱码）。
"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from _root import ROOT  # noqa: E402

STEP = (
    'if not exist "%~dp0scripts\\.godot" (\r\n'
    '    echo [首次运行] 正在导入素材，约需 10-40 秒，请稍候 ...\r\n'
    '    "%~dp0tools\\Godot_v4.7.2-stable_win64_console.exe" '
    '--path "%~dp0scripts" --headless --import >nul 2>&1\r\n'
    '    echo            导入完成。\r\n'
    '    echo.\r\n'
    ')\r\n'
)

TARGETS = {
    "启动游戏.bat": ('start "" "%GODOT%" --path "%~dp0scripts"',
                     'start "" "%GODOT%" --path "%~dp0scripts"'),
    "启动_御敌演示.bat": ('start "" "%GODOT%" --path "%~dp0scripts" -- --battle',
                          'start "" "%GODOT%" --path "%~dp0scripts" -- --battle'),
}


def main() -> None:
    for name, (needle, _) in TARGETS.items():
        p = ROOT / name
        if not p.exists():
            print("  [缺] %s" % name)
            continue
        raw = p.read_bytes()
        try:
            txt = raw.decode("gbk")
            enc = "gbk"
        except UnicodeDecodeError:
            txt = raw.decode("utf-8", errors="ignore")
            enc = "utf-8"
        if ".godot" in txt:
            print("  %s 已有导入步骤，跳过（编码 %s）" % (name, enc))
            continue
        # 统一成 CRLF 再插
        t = txt.replace("\r\n", "\n").replace("\r", "\n")
        if needle not in t:
            print("  [警告] %s 里找不到启动行，跳过" % name)
            continue
        t = t.replace(needle, STEP.replace("\r\n", "\n") + needle, 1)
        out = t.replace("\n", "\r\n")
        p.write_bytes(out.encode(enc if enc == "gbk" else "utf-8"))
        print("  已给 %s 加上首次运行导入步骤（%s / CRLF）" % (name, enc))

    # 运行说明里也提一句
    d = ROOT / "参赛材料" / "05-参赛打包ZIP"
    print("\n  提示：参赛包需重新打包才会带上改动（rezip_clean.py）")


if __name__ == "__main__":
    main()
