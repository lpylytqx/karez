# characters/ —— 角色

角色 id 必须与 [characters.json](D:\坎儿井\data\characters.json) 完全一致：

```
lao_kanjiang       老坎匠
muqam_yiren        木卡姆艺人
hasake_qishou      哈萨克骑手
hanshang_zhanggui  汉族商队掌柜
chuniang           厨娘
shenmi_lvren       神秘旅人
mafei_toumu        马匪头目
```

每个角色的**外形描述已经写好了**——见 characters.json 里各角色的 `portrait_spec` 字段。
不要自己重新设计外形，直接用那份描述去生成或委托。

## 子目录

| 目录 | 内容 | 规格 | P0 |
|---|---|---|---|
| `walk/` | 行走图，4 方向 × 4 帧 | 16×24 | 主角 + 老坎匠 + 厨娘（3 个） |
| `portraits/` | 立绘 | 512×512 | 全部 7 个 |
| `emotes/` | 表情小图标 | 16×16 | 21（7 角色 × 3 情绪） |
| `units/` | 战斗单位，待机 2 + 攻击 4 + 受击 2 | 16×24 | 民兵 + 马匪（2 种） |

## 命名

```
walk/lao_kanjiang_walk_4dir.png      4 方向拼在一张图（4 行 × 4 列）
portraits/lao_kanjiang_base.png      默认表情
portraits/lao_kanjiang_happy.png     高兴差分
portraits/lao_kanjiang_angry.png     不满差分
emotes/emote_angry.png               按情绪命名（7 角色共用）
units/minbing_idle_02f.png
```

## ⚠️ 立绘是唯一的例外：不做像素风

立绘走**暖色手绘风**，512×512。像素风地图 + 手绘感立绘是常见且好看的组合（参考《八方旅人》思路）。
模板见 [ART_STYLE.md](D:\坎儿井\assets\ART_STYLE.md) 第三节末尾。

## 省力技巧：行走图不用每人重画

7 个角色的行走图不必从零画 7 套。标准做法是
**同一躯体 + 换头部/服饰图层**，躯体只需 2–3 种（壮年男、青年、女性）。

这一招能省 **60% 工作量**。对单人开发来说这是必须用的技巧。

## 情绪差分与 characters.json 的对应

模型只会输出 8 种情绪（`平静 / 高兴 / 不满 / 愤怒 / 忧虑 / 兴奋 / 戒备 / 悲伤`）。
立绘差分至少要覆盖 4 种最常用的：**平静 / 高兴 / 不满 / 忧虑**。
其余情绪回落到"平静"，玩家不会察觉。

代码里的情绪枚举见 [characters.py](D:\坎儿井\ai_backend\ai\characters.py) 的 `EMOTIONS`。
