#!/usr/bin/env python -u
# -*- coding: utf-8 -*-
"""给 play.gd 加「演示导演」模式 —— 录视频时按一下键就跳到下一屏。

为什么需要：录一份 3 分钟的演示视频，不可能顺着游戏时间慢慢玩到第 15 天触发御敌、
或者等一个沙暴。展示线索是**分屏**的，每屏对应一个要展示的点，按一下就该到下一屏。

用法：Godot_v4.7.2-stable_win64.exe --path scripts -- --demo
      空格 / →   下一屏       ←   上一屏
      H          隐藏提示条    R   从第一屏重来

实现方式：和已有的 `--battle` 走同一套命令行开关（`_has_cli_flag`），
在 `_ready` 里挂上，`_unhandled_input` 最前面拦键。

⚠ 两个 GDScript 老坑，这里都绕开了：
  · `event.keycode` 是 Variant，写 `var k := event.keycode` 会**解析报错** → 显式写 `var k: int = ...`
  · 状态路径一律走 `_demo_put()`（路径不存在就跳过），**宁可少设一个值也不要整块崩**
"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from _root import ROOT  # noqa: E402

PLAY = ROOT / "scripts" / "scenes" / "play.gd"

DEMO = '''

# ══════════════════════════════════════════════════════════════════════════
#  演示导演（录视频用）　　命令行加 --demo 启动
# ══════════════════════════════════════════════════════════════════════════
#
#  录一份 3 分钟的演示视频，不可能顺着游戏时间慢慢玩到第 15 天触发御敌、
#  或者等一场沙暴。展示线索本来就是**分屏**的：一屏一个要展示的点。
#  这个模式把整条线索摆好，按一下键就跳到下一屏。
#
#      空格 / →   下一屏　　　←   上一屏
#      H          隐藏提示条　　R   从第一屏重来
#
#  用法：Godot_v4.7.2-stable_win64.exe --path scripts -- --demo
#        （也可以双击 启动_演示模式.bat）
#
#  ⚠ 和 --battle 一样，它只改**内存里的状态**，不写存档。演示完别点「存档」。
# ══════════════════════════════════════════════════════════════════════════

const DEMO_BEATS := [
	{"t": "开局：一段井都没挖", "d": "沙地、枯树、破驿站 —— 不挖井就活不过第一周", "m": "_demo_b01"},
	{"t": "六段竖井全部挖通", "d": "出水 → 人口 → 绿洲，这是唯一的因果链", "m": "_demo_b02"},
	{"t": "九个岗位，抢的是同一批人", "d": "多派一人挖井，就少一人种地", "m": "_demo_b03"},
	{"t": "建造：十三座建筑", "d": "每座都对应一种真实的丝路生计", "m": "_demo_b04"},
	{"t": "AI 事件卡：多个选项，各有后果", "d": "选项上的代价真的会结算到资源与关系", "m": "_demo_b05"},
	{"t": "御敌之战：自由布阵", "d": "整片布阵区随便站；兵种由岗位决定", "m": "_demo_b06"},
	{"t": "御敌之战：开打", "d": "半自动交手，每 0.62 秒一拍", "m": "_demo_b07"},
	{"t": "畜牧：抓野畜与产出", "d": "五个真实畜种，各有饲料与繁殖周期", "m": "_demo_b08"},
	{"t": "十二木卡姆", "d": "要有人、有场地、有乐器，才办得起来", "m": "_demo_b09"},
	{"t": "灾难通告", "d": "插画由本地 SDXL 生成，六种灾难各有对策建筑", "m": "_demo_b10"},
	{"t": "冬季：地表换雪、树池凋尽", "d": "四季真的会换，不是一张贴图", "m": "_demo_b11"},
	{"t": "春季：绿洲回来", "d": "同一张地图，玩家自己一点点改出来的", "m": "_demo_b12"},
	{"t": "镜头可放可缩", "d": "滚轮缩放、按住左键拖动平移、F 回到主角", "m": "_demo_b13"},
	{"t": "收尾：整片绿洲", "d": "从一段淤塞的坎儿井，到一座丝路重镇", "m": "_demo_b14"},
]

var _demo_on := false
var _demo_i := 0
var _demo_layer: CanvasLayer
var _demo_title: Label
var _demo_step: Label
var _demo_note: Label


func _maybe_start_demo() -> void:
	if not _has_cli_flag("--demo"):
		return
	_demo_on = true
	_build_demo_ui()
	# 等 HUD 完成一次布局，否则第一屏的状态推下去会被覆盖
	await get_tree().create_timer(0.45).timeout
	_demo_go(0)
	print("[演示] --demo 生效：共 %d 屏。空格/→ 下一屏，← 上一屏，H 隐藏提示条，R 重来。"
		% DEMO_BEATS.size())


func _build_demo_ui() -> void:
	_demo_layer = CanvasLayer.new()
	_demo_layer.layer = 30
	add_child(_demo_layer)

	var p := Panel.new()
	p.position = Vector2.ZERO
	p.size = Vector2(640, 42)
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.06, 0.045, 0.03, 0.88)
	st.border_color = Color(0.878, 0.643, 0.235, 0.85)
	st.border_width_bottom = 1
	p.add_theme_stylebox_override("panel", st)
	_demo_layer.add_child(p)

	_demo_step = _demo_label(p, Vector2(8, 3), Vector2(300, 12), "", 10,
		Color(0.878, 0.643, 0.235))
	_demo_title = _demo_label(p, Vector2(8, 15), Vector2(624, 14), "", 13,
		Color(0.941, 0.894, 0.816))
	_demo_note = _demo_label(p, Vector2(8, 30), Vector2(624, 11), "", 9,
		Color(0.710, 0.643, 0.549))


func _demo_label(parent: Node, pos: Vector2, size: Vector2, text: String,
		sz: int, col: Color) -> Label:
	var l := Label.new()
	l.position = pos
	l.size = size
	l.text = text
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", col)
	l.add_theme_font_override("font",
		load("res://fonts/ark-12px/ark-pixel-12px-proportional-zh_hans.ttf"))
	parent.add_child(l)
	return l


## 跳到第 i 屏。越界自动夹住。
func _demo_go(i: int) -> void:
	if not _demo_on:
		return
	_demo_i = clampi(i, 0, DEMO_BEATS.size() - 1)
	var b: Dictionary = DEMO_BEATS[_demo_i]
	# 换屏前先关掉所有弹窗面板、交还焦点 —— 否则底部输入框会吃掉空格键
	if _hud != null:
		_hud._close_pages()
	get_viewport().gui_release_focus()
	var m: String = str(b.get("m", ""))
	if m != "" and has_method(m):
		call(m)
	if _demo_step != null:
		_demo_step.text = "演示  %02d / %d" % [_demo_i + 1, DEMO_BEATS.size()]
		_demo_title.text = str(b.get("t", ""))
		_demo_note.text = "%s　｜　空格/→ 下一屏　← 上一屏　H 隐藏　R 重来" % str(b.get("d", ""))
	if _hud != null:
		_hud.append_log("[color=#e8c79a]【演示 %02d】%s[/color]"
			% [_demo_i + 1, str(b.get("t", ""))])


## 安全地设一个状态值：**路径不存在就跳过**并返回 false，绝不抛异常。
## 为什么必须这样：屏与屏之间字段名可能有出入，路径写死一旦对不上就会整块崩 ——
## 录视频时最怕的就是这个。宁可这一屏少设一个值，也不要崩。
func _demo_put(path: Array, v) -> bool:
	var cur = _game.state
	for i in range(path.size() - 1):
		if not (cur is Dictionary) or not cur.has(path[i]):
			return false
		cur = cur[path[i]]
	if not (cur is Dictionary) or not cur.has(path[-1]):
		return false
	cur[path[-1]] = v
	return true


## 直接摆镜头（不走补间）—— 录视频要的是"按一下就到位"。
func _demo_cam(zi: int) -> void:
	_follow = false
	_zoom_i = clampi(zi, 0, ZOOM_STEPS.size() - 1)
	var z := float(ZOOM_STEPS[_zoom_i])
	_cam.zoom = Vector2(z, z)
	if _player != null:
		_cam.position = _player.position + Vector2(0, -10)
	_clamp_camera()
	_readout()


func _demo_feed() -> void:
	# 给足材料，否则建造/畜牧面板是空的，录出来不好看
	_demo_put(["resources", "materials", "wood"], 240.0)
	_demo_put(["resources", "materials", "earth"], 300.0)
	_demo_put(["resources", "materials", "metal"], 60.0)
	_demo_put(["resources", "currency"], 220.0)


func _demo_b01() -> void:
	_demo_put(["karez", "sections"], 0)
	_demo_put(["population"], 3)
	_demo_put(["calendar", "day"], 1)
	_demo_put(["calendar", "season"], "spring")
	_game.clamp_all()
	_game.state_changed.emit()
	_demo_cam(2)


func _demo_b02() -> void:
	_demo_put(["karez", "sections"], 6)
	_demo_put(["population"], 12)
	_demo_put(["calendar", "season"], "summer")
	_demo_feed()
	_game.clamp_all()
	_game.state_changed.emit()
	_demo_cam(2)


func _demo_b03() -> void:
	_demo_put(["population"], 12)
	_demo_put(["jobs"], {"water": 2, "farm": 2, "gather_wood": 1, "gather_earth": 1,
		"trade": 1, "guard": 1, "cook": 1, "craft": 1, "music": 1, "idle": 1})
	_game.clamp_all()
	_game.state_changed.emit()
	if _hud != null:
		_hud.open_job_panel()
	_demo_cam(2)


func _demo_b04() -> void:
	_demo_feed()
	_game.clamp_all()
	_game.state_changed.emit()
	if _hud != null:
		_hud._on_build_pressed()
	_demo_cam(2)


func _demo_b05() -> void:
	_demo_feed()
	if _hud != null:
		_hud.event_requested.emit()
	_demo_cam(2)


func _demo_b06() -> void:
	_demo_put(["population"], 8)
	_demo_put(["karez", "sections"], 6)
	_demo_put(["stats", "security"], 28.0)
	_demo_feed()
	_demo_put(["jobs"], {"water": 1, "farm": 1, "gather_wood": 1, "gather_earth": 1,
		"guard": 2, "idle": 2})
	_game.clamp_all()
	_game.state_changed.emit()
	_start_raid(true)


func _demo_b07() -> void:
	if _battle != null and _battle.has_method("begin_fight"):
		_battle.begin_fight()


func _demo_b08() -> void:
	if _hud != null:
		_hud._toggle_animal_panel()
	_demo_cam(2)


func _demo_b09() -> void:
	_demo_feed()
	_demo_put(["population"], 12)
	_game.clamp_all()
	_game.state_changed.emit()
	if _hud != null:
		_hud._toggle_music_panel()
	_demo_cam(2)


func _demo_b10() -> void:
	if _hud != null:
		_hud.show_notice("沙暴", "黄风压过来，天在成土色。井口要先盖毡子，"
			+ "羊群要赶回圈 —— 没准备的人，牲口一天就少一截。",
			"disaster_sandstorm")


func _demo_b11() -> void:
	_demo_put(["karez", "sections"], 6)
	_demo_put(["population"], 12)
	_demo_put(["calendar", "season"], "winter")
	_game.clamp_all()
	_game.state_changed.emit()
	_demo_cam(2)


func _demo_b12() -> void:
	_demo_put(["calendar", "season"], "spring")
	_game.clamp_all()
	_game.state_changed.emit()
	_demo_cam(2)


func _demo_b13() -> void:
	_demo_cam(ZOOM_STEPS.size() - 1)


func _demo_b14() -> void:
	_demo_cam(1)
'''

# 输入拦截块：插在 _unhandled_input 的最前面
KEY_BLOCK = '''	# ── 演示导演：最先拦键，否则会被下面的缩放/平移吃掉 ──
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


def main() -> None:
    t = PLAY.read_text(encoding="utf-8")
    if "_maybe_start_demo()" in t:
        print("  已装过演示导演，跳过")
        return

    # ① _ready 里挂上
    anchor = "\t_maybe_start_demo_battle()"
    if anchor not in t:
        print("  [X] 找不到 _maybe_start_demo_battle() 调用点")
        return
    t = t.replace(anchor, anchor + "\n\t_maybe_start_demo()", 1)
    print("  ✓ _ready 里挂上 _maybe_start_demo()")

    # ② _unhandled_input 最前面拦键
    i = t.index("func _unhandled_input(event: InputEvent) -> void:")
    j = t.index("\n", i) + 1
    t = t[:j] + KEY_BLOCK + t[j:]
    print("  ✓ _unhandled_input 最前面加拦键块")

    # ③ 追加演示导演全部代码
    t = t.rstrip("\n") + "\n" + DEMO
    PLAY.write_text(t, encoding="utf-8")
    back = PLAY.read_text(encoding="utf-8")
    print("  ✓ 追加演示导演代码（%d 屏）" % back.count('"m": "_demo_b'))
    print("\n  回读校验：")
    for k in ("_maybe_start_demo()", "const DEMO_BEATS", "func _demo_go(",
              "func _demo_put(", "KEY_SPACE"):
        print("    %-22s %s" % (k, "在 ✓" if k in back else "缺 ✗"))
    print("    play.gd 现在 %d 行" % len(back.splitlines()))


if __name__ == "__main__":
    main()
