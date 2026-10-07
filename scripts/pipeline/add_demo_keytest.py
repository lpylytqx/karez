#!/usr/bin/env python -u
# -*- coding: utf-8 -*-
"""给演示导演加键位边界用例 --demo-keytest。

**为什么要专门写这个**：用户实机反馈「点空格没用了」，根因是焦点在聊天输入框里、
被 LineEdit 先吃掉。这种问题**只读代码或只跑正常路径是发现不了的** ——
必须把焦点真的塞进输入框，再发**真实按键事件**，看它到底走不走。

项目规矩：没指明具体 bug 时，先写边界用例把真问题逼出来，不凭猜改代码。
这个用例就是那条规矩的产物。

三步验证：
  ① 焦点在输入框 + 空格 → **不该**推进（空格归输入框）
  ② 焦点在输入框 + →  → **该**推进（方向键打字用不到）
  ③ 换屏会释放焦点，之后 + 空格 → **该**能推进（"按一下 → 就恢复"）

跑法：
    Godot_v4.7.2-stable_win64_console.exe --path scripts \\
        res://scenes/play.tscn -- --demo --demo-keytest
"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from _root import ROOT  # noqa: E402

PLAY = ROOT / "scripts" / "scenes" / "play.gd"

FN = '''

## 键位边界用例：把焦点塞进聊天输入框，再发**真实按键事件**看空格走不走。
## 这个用例是为了重现用户实机反馈的「点空格没用了」而写的。
func _demo_keytest() -> void:
	await get_tree().create_timer(1.0).timeout
	var le := _demo_find_line_edit(_hud)
	if le == null:
		print("[键测] ✗ 在 HUD 里找不到 LineEdit，用例无法进行")
		get_tree().quit()
		return
	le.grab_focus()
	print("[键测] 焦点已塞进输入框（%s，visible=%s）" % [le.get_class(), str(le.visible)])

	var a := _demo_i
	_demo_send_key(KEY_SPACE)
	await get_tree().process_frame
	print("[键测] ① 输入框有焦点 + 空格 → 屏 %d（应仍为 %d）%s"
		% [_demo_i, a, "  ✓" if _demo_i == a else "  ✗ 不该推进"])

	_demo_send_key(KEY_RIGHT)
	await get_tree().process_frame
	print("[键测] ② 输入框有焦点 + → → 屏 %d（应为 %d）%s"
		% [_demo_i, a + 1, "  ✓" if _demo_i == a + 1 else "  ✗ 该推进却没动"])

	var b := _demo_i
	_demo_send_key(KEY_LEFT)
	await get_tree().process_frame
	var c := _demo_i
	_demo_send_key(KEY_SPACE)
	await get_tree().process_frame
	print("[键测] ③ 回到第 %d 屏后 + 空格 → 屏 %d（应为 %d）%s"
		% [c, _demo_i, c + 1, "  ✓" if _demo_i == c + 1 else "  ✗ 空格仍未生效"])
	print("[键测] 用例结束（上一屏编号 %d → %d）" % [b, c])
	get_tree().quit()


## 发一次真实的按下+抬起。走 Input.parse_input_event，和玩家按键是**同一条链路** ——
## 直接调 _demo_go() 是验证不了焦点问题的。
func _demo_send_key(kc: int) -> void:
	var ev := InputEventKey.new()
	ev.keycode = kc
	ev.physical_keycode = kc
	ev.pressed = true
	Input.parse_input_event(ev)
	var up := InputEventKey.new()
	up.keycode = kc
	up.physical_keycode = kc
	up.pressed = false
	Input.parse_input_event(up)


func _demo_find_line_edit(n: Node) -> LineEdit:
	if n == null:
		return null
	if n is LineEdit:
		return n
	for c in n.get_children():
		var r := _demo_find_line_edit(c)
		if r != null:
			return r
	return null
'''


def main() -> None:
    t = PLAY.read_text(encoding="utf-8")
    if "_demo_keytest" in t:
        print("  已装过键位用例，跳过")
        return
    t = t.rstrip("\n") + "\n" + FN
    anchor = '''	if _has_cli_flag("--demo-shot"):
		_demo_autorun()'''
    if anchor not in t:
        print("  [X] 找不到 --demo-shot 锚点")
        return
    t = t.replace(anchor, anchor + '''

	if _has_cli_flag("--demo-keytest"):
		_demo_keytest()''', 1)
    PLAY.write_text(t, encoding="utf-8")
    back = PLAY.read_text(encoding="utf-8")
    print("  回读校验：")
    for k in ("func _demo_keytest()", "func _demo_send_key(", "func _demo_find_line_edit(",
              '_has_cli_flag("--demo-keytest")'):
        print("    %-30s %s" % (k, "在 ✓" if k in back else "缺 ✗"))
    print("    play.gd 现在 %d 行" % len(back.splitlines()))


if __name__ == "__main__":
    main()
