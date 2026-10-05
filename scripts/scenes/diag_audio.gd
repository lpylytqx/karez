extends Node
## 诊断：背景音乐为什么不出声。
## 只听传言没用，直接把 stream 加载出来、把播放器开起来、看它的状态。

func _ready() -> void:
	print("DIAG ── 音频诊断 ──")

	var st: AudioStream = load("res://audio/muqam_theme.wav")
	if st == null:
		print("DIAG [X] load() 返回 null —— res:// 路径取不到")
		get_tree().quit()
		return
	print("DIAG [OK] load 成功，类型 = ", st.get_class())
	if st is AudioStreamWAV:
		var w := st as AudioStreamWAV
		print("DIAG     format = ", w.format, "  mix_rate = ", w.mix_rate,
			"  stereo = ", w.stereo, "  length = %.2f s" % w.get_length(),
			"  loop_mode = ", w.loop_mode)
	else:
		print("DIAG     length = %.2f s" % st.get_length())

	# 音频驱动信息：无声卡/无驱动时 Godot 会用一个 dummy 驱动，听不到任何声音
	print("DIAG ── 音频驱动 ──")
	var drv := AudioServer.get_driver_name()
	print("DIAG     driver = ", drv)
	print("DIAG     mix_rate = ", AudioServer.get_mix_rate(),
		"  output_latency = %.3f s" % AudioServer.get_output_latency())
	var bus := AudioServer.get_bus_index("Master")
	print("DIAG     Master bus volume_db = ", AudioServer.get_bus_volume_db(bus),
		"  mute = ", AudioServer.is_bus_mute(bus))

	# 真开一个播放器看它有没有在走
	var p := AudioStreamPlayer.new()
	p.stream = st
	p.volume_db = 0.0
	add_child(p)
	p.play()
	print("DIAG ── 播放器 ──")
	print("DIAG     playing = ", p.is_playing(),
		"  stream_playback = ", p.get_stream_playback() != null)
	await get_tree().create_timer(1.2).timeout
	print("DIAG     1.2s 后 playing = ", p.is_playing(),
		"  playback_position = %.3f" % p.get_playback_position())
	print("DIAG ── 诊断结束 ──")
	get_tree().quit()
