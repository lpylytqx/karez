# buildings/ —— 建筑

12 种建筑，必须与 [numbers.json](D:\坎儿井\data\numbers.json) 的 `buildings.list[].id` 一一对应。

## 命名（id 必须与 numbers.json 一致）

```
yiguan_stage_01.png        驿馆 建造阶段 1（脚手架/半成）
yiguan_stage_02.png
yiguan_stage_03.png
yiguan_stage_04.png        完工
majiu_stage_02.png         马厩
bazha_stage_03.png         巴扎
liangfang_stage_02.png     葡萄晾房
```

对应关系：`yiguan`(驿馆) `majiu`(马厩) `cangku`(仓库) `chufang`(厨房) `bazha`(巴扎)
`zuofang`(作坊) `liangfang`(葡萄晾房) `weijiang`(围墙) `fengsui`(烽燧)
`juzhu`(居民居所) `zhanfang`(毡房区) `yinletai`(奏乐台)

## 规格

| 建筑 | 尺寸 | 说明 |
|---|---|---|
| 小（厨房、居所、毡房） | 32×32 | 锚点在底部中心 |
| 中（马厩、仓库、作坊、晾房、烽燧） | 48×48 | — |
| 大（驿馆、巴扎、奏乐台） | 64×64 | 跨格 |
| 围墙段 | 16×16 | 直/角/门/破损 共 12 变体 |

## 三个必须做对的点

1. **建造阶段图（P0，不是可选项）。**
   建造过程本身就是主玩法（GDD 4.1），玩家要看见驿馆从地基长成房子。
   每种建筑至少 3–4 个阶段。这是"成就感"最直接的来源。
2. **涝坝要有水位分级**（4 等级 × 4 水位 = 16 变体）。
   涝坝蓄水量的可见变化，是玩家"我做到了"的最强反馈。
3. **葡萄晾房是文化识别度最高的建筑**（镂空花格墙）。
   这一栋值得多花时间，它会出现在演示视频的多个镜头里。

## 参考

建筑形制参考真实形制：生土建筑、葡萄晾房、毡房、巴扎。
**参考图放 `../_reference/`，不可直接使用**（见 [ART_STYLE.md](D:\坎儿井\assets\ART_STYLE.md) 第八节）。

建筑本体用色：生土亮 `#DFC398` / 主 `#C9A277` / 暗 `#9E7C55`，木结构 `#8B6B47`。
