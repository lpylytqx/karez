#!/usr/bin/env python -u
# -*- coding: utf-8 -*-
"""修演示导演"空格失效"—— 用户实机反馈：「走到这里以后再点空格就没用了」。

根因（看截图就能定位）：**焦点在底部的聊天输入框里**。
截图里输入框有光标、还留着他打的「你好」。Godot 里被焦点的 `LineEdit` 会先吃掉键事件
（它当成打字），事件**传不到 `_unhandled_input`** —— 而我把演示拦截挂在了那里，
所以空格被吞了。

两处改：
  ① 拦截从 `_unhandled_input` 挪到 **`_input`** —— `_input` 在 GUI 处理之前跑，
     东西还没被任何 Control 消费掉。
  ② 光挪位置还不够：真在打字时，空格**应该**让给输入框。
     所以判据改成「**焦点不在输入框里**才用空格推进」；
     而 `→ / ← / H / R` 这几个打字用不到的键**永远生效**。
     提示条也改成写明这一点。

顺带：每换一屏都会 `gui_release_focus()` —— 所以即使焦点跑进输入框，
**按一下 `→` 之后空格就又能用了**。
"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from _root import ROOT  # noqa: E402

PLAY = ROOT / "scripts" / "scenes" / "play.gd"

BLOCK_IN_UNHANDLED = '''	# ── 演示导演：最先拦键，否则会被下面的缩放/平移吃掉 ──
	if _demo_on and event is InputEventKey and event.pressed and not event.echo:
		# ⚠ event.keycode 是 Variant，写 := 会解析报错
		var dk: int = event.keycode
		if dk == KEY_SPACE or dk == KEY_RIGHT:
			_demo_go(_demo_i + 1)
			get_viewport().set_input_as_handled()
			return
		elif dk == KEY_LEFT:
			_demo_go(_demo_i - 1)
			get_viewport().set_input_as_handled()
			return
		elif dk == KEY_H:
			_demo_layer.visible = not _demo_layer.visible
			get_viewport().set_input_as_handled()
			return
		elif dk == KEY_R:
			_demo_go(0)
			get_viewport().set_input_as_handled()
			return

'''

NEW_INPUT = '''

## 演示导演的按键处理。
##
## ⚠ **必须挂在 `_input` 而不是 `_unhandled_input`。**
##   用户实机反馈过「点空格没用了」—— 原因是那时焦点在底部聊天输入框里，
##   被焦点的 `LineEdit` 会把空格当成打字先吃掉，事件根本传不到 `_unhandled_input`，
##   而演示拦截挂在那里就收不到键。`_input` 在 GUI 处理**之前**跑，抢得到。
##
## ⚠ 但也不能一刀切全抢：真在打字时，空格该归输入框。
##   所以判据是「**焦点不在输入框里**才用空格推进」，而
##   `→ / ← / H / R` 这些打字用不到的键**永远生效**。
func _input(event: InputEvent) -> void:
	if not _demo_on:
		return
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	# ⚠ event.keycode 是 Variant，写 := 会解析报错
	var dk: int = event.keycode

	var next := dk == KEY_RIGHT
	var prev := dk == KEY_LEFT
	# 空格只在没在打字时推进
	if dk == KEY_SPACE and not _demo_typing():
		next = true
	if dk == KEY_H:
		_demo_layer.visible = not _demo_layer.visible
		get_viewport().set_input_as_handled()
		return
	if dk == KEY_R:
		_demo_go(0)
		get_viewport().set_input_as_handled()
		return
	if next:
		_demo_go(_demo_i + 1)
		get_viewport().set_input_as_handled()
	elif prev:
		_demo_go(_demo_i - 1)
		get_viewport().set_input_as_handled()


## 焦点是不是在某个可输入的框里（底部聊天输入框）。是的话空格要留给它。
func _demo_typing() -> bool:
	var fo := get_viewport().gui_get_focus_owner()
	return fo is LineEdit or fo is TextEdit
'''

OLD_HINT = '''		_demo_note.text = "%s　｜　空格/→ 下一屏　← 上一屏　H 隐藏　R 重来" % str(b.get("d", ""))'''
NEW_HINT = '''		var hint := "空格/→ 下一屏　← 上一屏　H 隐藏　R 重来"
		if _demo_typing():
			hint = "**输入框有焦点：请按 → 下一屏**　← 上一屏　H 隐藏　R 重来"
		_demo_note.text = "%s　｜　%s" % [str(b.get("d", "")), hint]'''


def main() -> None:
    t = PLAY.read_text(encoding="utf-8")
    n = 0

    # ① 把旧拦截块从 _unhandled_input 里删掉
    if BLOCK_IN_UNHANDLED in t:
        t = t.replace(BLOCK_IN_UNHANDLED, "", 1)
        n += 1
        print("  ✓ 从 _unhandled_input 移除旧拦截")
    else:
        print("  - _unhandled_input 里没有旧拦截（或已改过）")

    # ② 加 _input 版本（放在 _unhandled_input 定义之前）
    if "func _input(event: InputEvent) -> void:" not in t:
        anchor = "func _unhandled_input(event: InputEvent) -> void:"
        if anchor not in t:
            print("  [X] 找不到 _unhandled_input 锚点")
            return
        t = t.replace(anchor, NEW_INPUT.strip("\n") + "\n\n\n" + anchor, 1)
        n += 1
        print("  ✓ 新增 _input 拦截（GUI 之前）")
    else:
        print("  - 已有 _input")

    # ③ 提示条写明输入框有焦点时的替代键
    if OLD_HINT in t:
        t = t.replace(OLD_HINT, NEW_HINT, 1)
        n += 1
        print("  ✓ 提示条加上「输入框有焦点时按 →」")

    if n == 0:
        print("  没有可见改动")
        return
    PLAY.write_text(t, encoding="utf-8")
    back = PLAY.read_text(encoding="utf-8")
    print("\n  回读校验：")
    checks = [
        ("func _input(event", "新拦截函数"),
        ("func _demo_typing()", "焦点判据"),
        ("输入框有焦点：请按 → 下一屏", "提示条文案"),
    ]
    for k, label in checks:
        print("    %-14s %s" % (label, "在 ✓" if k in back else "缺 ✗"))
    # _unhandled_input 里不该再有演示拦截
    i = back.index("func _unhandled_input(event: InputEvent) -> void:")
    seg = back[i:i + 700]
    print("    %-14s %s" % ("旧拦截已清",
          "✓" if "演示导演：最先拦键" not in seg else "✗ 还在"))


if __name__ == "__main__":
    main()
