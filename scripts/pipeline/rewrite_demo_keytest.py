#!/usr/bin/env python -u
# -*- coding: utf-8 -*-
"""重写键位边界用例，断言**新**行为。

⚠ 为什么必须重写：上一版用例断言的是「输入框有焦点 + 空格 → **不该**推进」，
  而那正是这次要改掉的设计。用例不改就会**报假警** —— 项目原则：
  检查器的假警报比没有检查更糟，因为它会训练人忽略这条结果。

新用例断言四件事：
  ① 输入框有焦点 + 空格 → **应该推进**（这就是"空格卡住"的那个 fix）
  ② 输入框有焦点 + →   → 应该推进
  ③ 最后一屏 + 空格     → 不推进，但**提示条要亮出来并写明「已是最后一屏」**
  ④ 最后一屏 + ←        → 退回上一屏
"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from _root import ROOT  # noqa: E402

PLAY = ROOT / "scripts" / "scenes" / "play.gd"

OLD_START = "func _demo_keytest() -> void:"
OLD_END = "func _demo_send_key(kc: int) -> void:"

NEW_TEST = '''func _demo_keytest() -> void:
	await get_tree().create_timer(1.0).timeout
	var le := _demo_find_line_edit(_hud)
	if le == null:
		print("[键测] ✗ 在 HUD 里找不到 LineEdit，用例无法进行")
		get_tree().quit()
		return
	le.grab_focus()
	print("[键测] 焦点已塞进输入框（%s）开始" % le.get_class())

	# ① 输入框有焦点 + 空格 → 现在**应该**推进
	#    （上一版这里是"不该推进"，那正是用户报的"空格没用了"）
	var a := _demo_i
	_demo_send_key(KEY_SPACE)
	await get_tree().process_frame
	print("[键测] ① 输入框有焦点 + 空格 → 屏 %d（应为 %d）%s"
		% [_demo_i, a + 1, "  ✓" if _demo_i == a + 1 else "  ✗ 空格仍然没生效"])

	# ② 输入框有焦点 + →
	le.grab_focus()
	var b := _demo_i
	_demo_send_key(KEY_RIGHT)
	await get_tree().process_frame
	print("[键测] ② 输入框有焦点 + → → 屏 %d（应为 %d）%s"
		% [_demo_i, b + 1, "  ✓" if _demo_i == b + 1 else "  ✗"])

	# ③ 跳到最后一屏，按空格 → 不推进，但要有反馈
	_demo_go(DEMO_BEATS.size() - 1)
	await get_tree().process_frame
	if _demo_layer != null:
		_demo_layer.visible = false   # 先藏起来，验证"被藏起来也会强制亮"
	var last := _demo_i
	_demo_send_key(KEY_SPACE)
	await get_tree().create_timer(0.15).timeout
	var note := ""
	if _demo_note != null:
		note = _demo_note.text
	var bar_on := _demo_layer != null and _demo_layer.visible
	print("[键测] ③ 最后一屏 + 空格 → 屏 %d（应仍为 %d）%s；提示条亮起 %s；提示语含边界说明 %s"
		% [last, last, "  ✓" if _demo_i == last else "  ✗ 不该推进",
		   "✓" if bar_on else "✗", "✓" if "最后一屏" in note else "✗"])

	# ④ 最后一屏 + ←
	var c := _demo_i
	_demo_send_key(KEY_LEFT)
	await get_tree().process_frame
	print("[键测] ④ 最后一屏 + ← → 屏 %d（应为 %d）%s"
		% [_demo_i, c - 1, "  ✓" if _demo_i == c - 1 else "  ✗"])

	print("[键测] 用例结束：①空格修好了 ②③④ 边界有反馈、能退回")
	get_tree().quit()


'''

NEW_SEND = '''func _demo_send_key(kc: int) -> void:'''


def main() -> None:
    t = PLAY.read_text(encoding="utf-8")
    i = t.find(OLD_START)
    j = t.find(OLD_END)
    if i < 0 or j < 0 or j <= i:
        print("  ✗ 找不到 _demo_keytest 的起止位置（i=%d j=%d）" % (i, j))
        return
    t = t[:i] + NEW_TEST + t[j:]
    PLAY.write_text(t, encoding="utf-8")
    back = PLAY.read_text(encoding="utf-8")
    print("  用例已重写。回读校验：")
    for k, label in (("空格仍然没生效", "新断言①"),
                     ("最后一屏", "边界断言"),
                     ("func _demo_send_key(", "发键函数在")):
        print("    %-12s %s" % (label, "在 ✓" if k in back else "缺 ✗"))
    print("    旧断言已清 %s"
          % ("✓" if "不该进阶" not in back and "不该推进（空格归输入框）" not in back else "⚠"))
    print("  play.gd 现在 %d 行" % len(back.splitlines()))


if __name__ == "__main__":
    main()
