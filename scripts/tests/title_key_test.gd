extends Node
## 标题画面键位用例的**入口**：只负责两件事 ——
##   ① 把探针**新建并挂到 root**（不是复用自己！）；
##   ② 切到标题画面，把测试现场交出去。
##
## ⚠ 别把测试逻辑写在本文件里。本节点就是"当前场景"，`change_scene_to_file()`
##   会把它连着旧场景一起释放 —— 第一次写这个用例就是这么翻车的：
##   症状是 `Unable to start the timer because it's not inside the scene tree`。
##   正确的分工：入口用完就走，探针留在 root 上跑。

const PROBE := "res://tests/title_key_probe.gd"


func _ready() -> void:
	var tree := get_tree()
	var probe := Node.new()
	probe.name = "TitleKeyProbe"
	probe.set_script(load(PROBE))
	# ⚠ 必须 deferred：_ready 期间 root 正在挂它自己的子节点，
	#   直接 add_child 会被引擎拒绝（"Parent node is busy setting up children"）。
	#   挂子节点与切场景按入队顺序执行，所以探针一定在场景切换前就位。
	tree.root.add_child.call_deferred(probe)
	tree.change_scene_to_file.call_deferred("res://scenes/title.tscn")
