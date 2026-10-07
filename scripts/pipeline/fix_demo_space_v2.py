#!/usr/bin/env python -u
# -*- coding: utf-8 -*-
"""修演示导演的第二版空格问题 —— **上次的"让步"把自己绊住了**。

用户第二次反馈「走到这里按空格键没用了」。查过：不是 paused（全项目没有），
不是 battle/map_view 抢键（那几处全是鼠标事件），也不是焦点判据写错 ——
**是我上次那个"空格让给输入框"的设计本身就是错的**：

  · 它**不给任何反馈**：按了没反应，人就卡住了
  · 用户按过 H 把提示条藏了，于是连"请改用 →"这句提示都看不到
  · 录视频时**可预测**比**礼貌**重要 —— 按空格就该前进，不该有时有理有时没理

这一版改成：
  ① **空格永远前进**（`_input` 最前面接管，不再看焦点）
     代价：聊天框里打不出空格字符。但中文聊天本来不用空格，这个代价可以接受。
  ② 另加 `PageDown / N` 作为备用前进键，`PageUp / P` 备用后退键
  ③ **边界有反馈**：已是第一屏/最后一屏时，提示条亮一下并写明"按 R 从头开始"
     （上一次是**静默夹住**，按了什么都不发生 —— 这就是"卡住"的观感来源）
  ④ **F1 打进日志报当前状态**（第几屏 / 提示条可见否 / 焦点在哪），
     以后再出问题不用靠猜
"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from _root import ROOT  # noqa: E402

PLAY = ROOT / "scripts" / "scenes" / "play.gd"

OLD_INPUT = '''func _input(event: InputEvent) -> void:
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
		get_viewport().set_input_as_handled()'''

NEW_INPUT = '''func _input(event: InputEvent) -> void:
	if not _demo_on:
		return
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	# ⚠ event.keycode 是 Variant，写 := 会解析报错
	var dk: int = event.keycode

	if dk == KEY_H:
		_demo_layer.visible = not _demo_layer.visible
		get_viewport().set_input_as_handled()
		return
	if dk == KEY_R:
		_demo_go(0)
		get_viewport().set_input_as_handled()
		return
	if dk == KEY_F1:
		var fo := get_viewport().gui_get_focus_owner()
		print("[演示] 第 %d/%d 屏  提示条=%s  焦点=%s  在打字=%s"
			% [_demo_i + 1, DEMO_BEATS.size(),
			   "显示" if _demo_layer.visible else "隐藏",
			   ("无" if fo == null else fo.get_class()), str(_demo_typing())])
		get_viewport().set_input_as_handled()
		return
	# ⚠ **空格一律前进**，不再"让给输入框"。
	#   上一版写成"焦点在输入框里就让给输入框"，结果按下去**毫无反馈**，
	#   人直接卡住 —— 而用户又按过 H 把提示条藏了，连"请改用 →"都看不到。
	#   录视频时可预测比礼貌重要：按空格就该前进。
	#   代价是聊天框里打不出空格字符；中文聊天本来不用空格，可以接受。
	if dk == KEY_RIGHT or dk == KEY_SPACE or dk == KEY_PAGEDOWN or dk == KEY_N:
		_demo_step_by(1)
		get_viewport().set_input_as_handled()
	elif dk == KEY_LEFT or dk == KEY_PAGEUP or dk == KEY_P:
		_demo_step_by(-1)
		get_viewport().set_input_as_handled()


## 移动 d 屏。**到边界时给反馈**，不要静默夹住 ——
## 上一次按了没反应，用户以为是"卡住了"，其实就是已经在最后一屏。
func _demo_step_by(d: int) -> void:
	var want := _demo_i + d
	if want < 0:
		_demo_flash("已是第一屏（3 秒后自动回到第 1 屏）")
		_demo_go(0)
		return
	if want >= DEMO_BEATS.size():
		_demo_flash("**已是最后一屏**　按 R 从头开始重录，或按 ← 返回")
		return
	_demo_go(want)


## 临时把提示条亮出来并写一行字，过一会儿恢复本屏说明。
## 提示条被 H 藏起来时也会强制亮一次 —— 否则用户看不到任何反馈。
func _demo_flash(msg: String) -> void:
	if _demo_layer == null:
		return
	_demo_layer.visible = true
	if _demo_note != null:
		_demo_note.text = msg
	_demo_flash_pending += 1
	var mine := _demo_flash_pending
	await get_tree().create_timer(2.0).timeout
	# 只有"最后一次 flash"才恢复，避免连按时互相覆盖
	if mine == _demo_flash_pending:
		_demo_refresh_bar()


## 按当前屏号重画提示条上的三行字。
func _demo_refresh_bar() -> void:
	if _demo_step == null or _demo_i < 0 or _demo_i >= DEMO_BEATS.size():
		return
	var b: Dictionary = DEMO_BEATS[_demo_i]
	_demo_step.text = "演示  %02d / %d" % [_demo_i + 1, DEMO_BEATS.size()]
	_demo_title.text = str(b.get("t", ""))
	_demo_note.text = "%s　｜　空格/→ 下一屏　← 上一屏　H 隐藏　R 重来　F1 报状态"
		% str(b.get("d", ""))'''

OLD_GO_TAIL = '''	if _demo_step != null:
		_demo_step.text = "演示  %02d / %d" % [_demo_i + 1, DEMO_BEATS.size()]
		_demo_title.text = str(b.get("t", ""))
		var hint := "空格/→ 下一屏　← 上一屏　H 隐藏　R 重来"
		if _demo_typing():
			hint = "**输入框有焦点：请按 → 下一屏**　← 上一屏　H 隐藏　R 重来"
		_demo_note.text = "%s　｜　%s" % [str(b.get("d", "")), hint]'''

NEW_GO_TAIL = '''	_demo_refresh_bar()'''

OLD_VAR = "var _demo_i := 0"
NEW_VAR = "var _demo_i := 0\nvar _demo_flash_pending := 0"


def main() -> None:
    t = PLAY.read_text(encoding="utf-8")
    n = 0
    for old, new, what in (
        (OLD_INPUT, NEW_INPUT, "_input 改成空格一律前进 + 边界反馈 + F1"),
        (OLD_GO_TAIL, NEW_GO_TAIL, "_demo_go 改用 _demo_refresh_bar"),
        (OLD_VAR, NEW_VAR, "加 _demo_flash_pending 计数"),
    ):
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
    PLAY.write_text(t, encoding="utf-8")
    back = PLAY.read_text(encoding="utf-8")
    print("\n  回读校验：")
    checks = [
        ("func _demo_step_by(", "边界步进"),
        ("func _demo_flash(", "边界反馈"),
        ("func _demo_refresh_bar(", "重画提示条"),
        ("KEY_PAGEDOWN", "备用前进键"),
        ("KEY_F1", "状态上报键"),
        ("已是最后一屏", "边界文案"),
    ]
    for k, label in checks:
        print("    %-12s %s" % (label, "在 ✓" if k in back else "缺 ✗"))
    print("    旧让步逻辑 %s" % ("已清 ✓" if "空格只在没在打字时推进" not in back else "✗ 还在"))
    print("  play.gd 现在 %d 行" % len(back.splitlines()))


if __name__ == "__main__":
    main()
