#!/usr/bin/env python -u
# -*- coding: utf-8 -*-
"""标题画面改成「按 Enter 键开始」—— **只认 Enter**，别的键与鼠标都不认。

原来写的是「按任意键开始」，实现上也是任何按键 / 鼠标 / 手柄按钮都放行。
录演示视频时这很要命：鼠标一动、误碰一个键就跳进游戏了，得重来。

改两处：
  · 文案：「按任意键开始」→「按 Enter 键开始」
  · 输入：只认 KEY_ENTER / KEY_KP_ENTER（主键盘与小键盘的回车都收），
    鼠标与手柄按钮不再放行

顺带把文件头的注释一起改掉 —— 注释写着"按任意键"而代码不是，下次读的人会被误导。
"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from _root import ROOT  # noqa: E402

T = ROOT / "scripts" / "scenes" / "title.gd"

OLD_INPUT = '''func _unhandled_input(event: InputEvent) -> void:
	if _started:
		return
	var go := false
	if event is InputEventKey and event.pressed and not event.echo:
		go = true
	elif event is InputEventMouseButton and event.pressed:
		go = true
	elif event is InputEventJoypadButton and event.pressed:
		go = true
	if not go:
		return
	_started = true
	get_tree().change_scene_to_file(PLAY_SCENE)'''

NEW_INPUT = '''func _unhandled_input(event: InputEvent) -> void:
	if _started:
		return
	# ⚠ **只认 Enter**（主键盘与小键盘的回车都收），鼠标与手柄按钮不放行。
	#   原来这里是「任意键 / 点鼠标 / 手柄按钮都进游戏」——
	#   录演示视频时鼠标一动、误碰一个键就跳走了，只能重来。
	#   文案与实现必须一致：屏幕上写「按 Enter 键开始」，那就只有 Enter 能用。
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	# ⚠ event.keycode 是 Variant，写 := 会解析报错
	var k: int = event.keycode
	if k != KEY_ENTER and k != KEY_KP_ENTER:
		return
	_started = true
	get_tree().change_scene_to_file(PLAY_SCENE)'''

JOBS = [
    (OLD_INPUT, NEW_INPUT, "输入：只认 Enter"),
    ('## 标题画面：启动先看到封面，按任意键进游戏。',
     '## 标题画面：启动先看到封面，**按 Enter 键**进游戏。', "文件头注释"),
    ('## 按任意键 / 点鼠标 → 切到 play.tscn。',
     '## 只有 Enter 能进 —— 鼠标与手柄按钮都不放行（录视频时误碰会跳走）。', "文件头注释②"),
    ('\t_hint.text = "按任意键开始"', '\t_hint.text = "按 Enter 键开始"', "提示文案"),
]


def main() -> None:
    t = T.read_text(encoding="utf-8")
    n = 0
    for old, new, what in JOBS:
        if old in t:
            t = t.replace(old, new, 1)
            n += 1
            print("  ✓ %s" % what)
        elif new in t:
            print("  - %s 已是新写法" % what)
        else:
            print("  ✗ %s 锚点没匹配上" % what)
    if n == 0:
        return
    T.write_text(t, encoding="utf-8")
    back = T.read_text(encoding="utf-8")
    print("\n  回读校验：")
    print("    文案「按 Enter 键开始」  %s" % ("✓" if "按 Enter 键开始" in back else "✗"))
    print("    只认 KEY_ENTER          %s" % ("✓" if "KEY_ENTER" in back else "✗"))
    print("    旧文案已清              %s" % ("✓" if "按任意键开始" not in back else "✗ 还在"))
    print("    鼠标/手柄放行已清        %s"
          % ("✓" if "InputEventMouseButton" not in back
             and "InputEventJoypadButton" not in back else "✗ 还在"))
    print("    title.gd 现在 %d 行" % len(back.splitlines()))


if __name__ == "__main__":
    main()
