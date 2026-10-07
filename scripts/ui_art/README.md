# ui/ —— 界面素材

## 子目录

| 目录 | 内容 | 规格 | P0 |
|---|---|---|---|
| `panels/` | 主界面框、对话面板、事件卡边框 | 24×24 九宫格切角 | 是 |
| `icons/` | 资源图标、建筑图标、季节图标 | 16×16 / 32×32 | 是 |
| `../fonts/` | 字体（在 assets/fonts/） | — | 是 |

## 命名

```
panels/panel_main.png            九宫格（24×24，四角 8px 不可拉伸）
panels/panel_dialog.png
panels/btn_normal.png            按钮需 4 态
panels/btn_hover.png
panels/btn_pressed.png
panels/btn_disabled.png
icons/icon_water.png             资源图标：必须与 numbers.json 的资源键对应
icons/icon_silver.png
icons/icon_building_yiguan.png   建筑图标：id 与 numbers.json 一致
icons/icon_season_winter.png
```

## 资源图标清单（与 numbers.json 一一对应）

`icon_water` `icon_food` `icon_silver` `icon_wood` `icon_earth` `icon_cloth` `icon_tools`
`icon_population` `icon_prosperity` `icon_reputation`

## 九宫格怎么做

1. 出图 **24×24**，四角各留 8px 不可拉伸区域
2. 在 Godot 里用 `NinePatchRect`，`patch_margin_*` 全设 8
3. **不要出大图再缩** —— 九宫格必须原生像素尺寸，缩放会糊

## 字体（在 assets/fonts/）

| 用途 | 推荐 | 授权 |
|---|---|---|
| 中文正文 | 思源黑体 / 思源宋体 | SIL OFL，可商用 |
| 数字与英文 | 几何无衬线或像素字体 | 注意中英混排基线 |

**三个坑：**

1. **不要依赖系统默认字体。** 评审的电脑可能没有。字体必须内嵌进 Godot 项目。
2. **授权要登记**（见 [asset-licenses.md](D:\坎儿井\docs\asset-licenses.md)）。
3. **像素风慎用中文点阵字体。** 汉字笔画多，640×360 分辨率下 12px 汉字会糊。
   若 UI 中文多，建议把逻辑分辨率提到 **960×540**（见 [ART_STYLE.md](D:\坎儿井\assets\ART_STYLE.md) 第五节）。

## 配色

UI 底色 `#2B2118`（深褐，**不要纯黑**），文字 `#F0E4D0`，强调金 `#E0A43C`。
完整色板见 [ART_STYLE.md](D:\坎儿井\assets\ART_STYLE.md) 第二节。
