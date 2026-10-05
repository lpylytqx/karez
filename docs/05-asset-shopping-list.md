# 素材搜集清单

> **不要一次搜齐。** 按阶梯来：T0 搜完就能在 Godot 里看到活的画面，T1 能演完整循环，T2 才是完整游戏。
> 每张图的具体规格、色板、命名规则见 [ART_STYLE.md](D:\坎儿井\assets\ART_STYLE.md)。
> 各目录放什么见 [assets/README.md](D:\坎儿井\assets\README.md)。

---

## 阶梯概览

| 阶梯 | 张数 | 搜完能做到什么 | 建议耗时 |
|---|---|---|---|
| **T0** | **38** | 在 Godot 里铺出一片会变绿的绿洲，一个能走路的角色，一条会流的水渠 | 先搜这个，一周内 |
| T1 | +136 | 能演完整的 3 分钟路演（治水→经营→对话→战斗） | 接着搜 |
| T2 | +331 | 完整游戏 | 后期慢慢补 |

**你现在只需要关心 T0 那 38 张。**

---

## T0 —— 先搜这 38 张

### 1. 绿洲三态（最重要，8 张）

**为什么先搜这个**：绿洲从荒漠中"生长"出来是本作最重要的视觉表达。
三档浓度的草地拼在一起，就能直接看出画面好不好看。

| 序号 | 名称 | 规格 | 数量 | 搜索关键词 |
|---|---|---|---|---|
| 1 | 沙漠地表 | 16×16 | 2 变体 | `pixel art sand tile seamless 16x16` |
| 2 | 绿洲草地·贫 | 16×16 | 2 变体 | `pixel art sparse grass tile seamless` |
| 3 | 绿洲草地·中 | 16×16 | 2 变体 | `pixel art grass tile seamless top down` |
| 4 | 绿洲草地·茂 | 16×16 | 2 变体 | `pixel art lush grass tile seamless` |

### 2. 水（6 张）

**水是核心资源，必须一眼可读。** 静态水面会显得很"死"，一定要带动画。

| 序号 | 名称 | 规格 | 数量 | 搜索关键词 |
|---|---|---|---|---|
| 5 | 明渠段（直/弯） | 16×16 | 2 | `pixel art water canal tile top down` |
| 6 | 涝坝水面 | 16×16，6 帧循环 | 1 组 | `pixel art water animation 6 frames tileset` |
| 7 | 涝坝蓄水池本体 | 48×48，4 水位 | 4 | `pixel art water reservoir pond asset` |
| 8 | 坎儿井竖井井口 | 32×32 | 1 | `pixel art well shaft entrance top down` |

### 3. 坎儿井与水渠建筑（4 张）

| 序号 | 名称 | 规格 | 数量 | 搜索关键词 |
|---|---|---|---|---|
| 9 | 竖井井口施工中 | 32×32 | 1 | `pixel art construction site hole dirt` |
| 10 | 明渠交叉口 | 16×16 | 1 | `pixel art irrigation channel cross tile` |
| 11 | 涝坝升级状态 | 48×48 | 1 | `pixel art stone pool water` |

### 4. 驿站核心建筑（6 张）

**只需搜最核心的几栋。** 建造阶段图先不搜，等游戏能跑了再补。

| 序号 | 名称 | 规格 | 数量 | 搜索关键词 |
|---|---|---|---|---|
| 12 | 驿馆 | 64×64 | 1 | `pixel art caravanserai inn building top down` |
| 13 | 马厩 | 48×48 | 1 | `pixel art stable barn building top down` |
| 14 | 仓库 | 48×48 | 1 | `pixel art warehouse storehouse building` |
| 15 | 厨房 | 32×32 | 1 | `pixel art kitchen hut building top down` |
| 16 | 居民居所 | 32×32 | 1 | `pixel art small house mud brick top down` |
| 17 | 葡萄晾房 | 48×64 | 1 | `pixel art drying house mud brick building` |

### 5. 角色（5 张）

**只搜 1 个能走的角色就行。** 其余角色等系统跑通再说。

| 序号 | 名称 | 规格 | 数量 | 搜索关键词 |
|---|---|---|---|---|
| 18 | 主角·驿丞 行走图 | 16×24，4 方向 × 4 帧 | 1 套 | `pixel art character sprite sheet 4 direction walk` |
| 19 | 老坎匠 行走图 | 16×24 | 1 套 | `pixel art old man character sprite walk` |
| 20 | 老坎匠 立绘 | 512×512 | 1 | 见 ART_STYLE 第三节的立绘模板 |
| 21 | 厨娘 立绘 | 512×512 | 1 | 同上 |
| 22 | 通用居民行走图 | 16×24 | 1 套 | `pixel art villager npc sprite sheet` |

### 6. UI 基础（9 张）

| 序号 | 名称 | 规格 | 数量 | 搜索关键词 |
|---|---|---|---|---|
| 23 | 面板九宫格 | 24×24 切角 | 1 | `pixel art ui panel frame 9 slice` |
| 24 | 按钮 4 态 | 32×16 拉伸 | 4 | `pixel art button ui states normal hover` |
| 25 | 图标：水 | 16×16 | 1 | `pixel art water drop icon 16x16` |
| 26 | 图标：食物 | 16×16 | 1 | `pixel art bread food icon 16x16` |
| 27 | 图标：银两 | 16×16 | 1 | `pixel art coin money icon 16x16` |
| 28 | 图标：木材 | 16×16 | 1 | `pixel art wood log icon 16x16` |
| 29 | 图标：土石 | 16×16 | 1 | `pixel art stone rock icon 16x16` |
| 30 | 图标：人力 | 16×16 | 1 | `pixel art people population icon 16x16` |
| 31 | 图标：繁荣/声望 | 16×16 | 2 | `pixel art star reputation icon` |

**T0 合计 = 38 张。**

---

## T1 —— 演完整 3 分钟路演需要（+136）

| 类别 | 补什么 | 数量 | 搜索关键词 |
|---|---|---|---|
| 地形扩展 | 戈壁碎石、土路/石板路、雪山山麓 | 12 | `pixel art gravel rock tile` / `pixel art stone path tile` / `pixel art snow mountain tile` |
| 农田 | 田地底 + 4 种作物 × 3 阶段 | 12 | `pixel art farm crop growth stages tileset` |
| 树木道具 | 胡杨、白杨、灌木、杂草 | 10 | `pixel art desert tree poplar` / `pixel art shrub bush tile` |
| 建筑阶段图 | 驿馆/马厩/仓库/厨房/居所 各 4 阶段 | 20 | `pixel art building construction stages` |
| 剩余建筑 | 巴扎、作坊、围墙、烽燧 | 14 | `pixel art market stall` / `pixel art workshop` / `pixel art wall segment` / `pixel art watchtower` |
| 剩余角色 | 5 个角色的行走图（共 80 帧） | 5 套 | 见各角色外形描述 |
| 全部立绘 | 7 个角色立绘 + 3 情绪差分 | 21 | 用立绘模板 |
| 战斗单位 | 民兵 + 马匪（待机/攻击/受击） | 16 | `pixel art battle unit sprite attack idle` |
| 特效 | 水流循环、挖掘扬尘 | 12 | `pixel art dust effect animation` / `pixel art water splash sprite` |
| UI 扩展 | 对话面板、资源条、建筑图标 | 20 | `pixel art dialog box ui` |
| 音频 | 主题曲（原创）、环境音 4 种、音效 10 种 | 15 | 见 [audio/README.md](D:\坎儿井\assets\audio\README.md) |

---

## T2 —— 完整游戏（+331）

等做到 S5/S6 再搜。现在**不要碰**，否则会做很多用不上的图。

主要内容：悬崖自动拼接、遗迹残垣、全部 12 栋建筑完整阶段、毡房区、奏乐台、
地表小道具、全部战斗单位、完整 UI 套件、战斗特效、沙暴、节庆光效、完整音频套件。

完整明细见 [04-art-checklist.md](D:\坎儿井\docs\04-art-checklist.md) 第二节。

---

## 搜集渠道与策略

| 阶梯 | 推荐渠道 |
|---|---|
| **T0** | **购买/下载一套完整的像素素材包**（itch.io 上有大量 CC0 或付费的完整沙漠/绿洲 tileset）。一套包里的素材天然风格统一，比零散搜图省十倍的后续调整工作 |
| T1 | 同上补齐 + AI 生成补充（需过统一后处理） |
| T2 | 委托画师定制，保证统一性 |

### ✅ 已核实的可直接用来源（详见调研报告）

完整清单见 [06-reference-and-free-asset-research.md](D:\坎儿井\docs\06-reference-and-free-asset-research.md)。速查：

| 用途 | 来源 | 授权 | 备注 |
|---|---|---|---|
| 像素素材基底 | **Ninja Adventure Asset Pack**（itch.io） | **CC0** | 50+ 角色 / tileset / UI / 100+ 音效 / 37 音乐 / 字体，可作项目基底 |
| 像素素材基底 | **Kenney**（kenney.nl/assets） | **CC0** | 官方原话"even in commercial projects"，无需署名 |
| 沙漠地形 | OpenGameArt 的 CC0 沙漠 tileset | CC0 | 只看 CC0 分类 |
| 色板 | **Lospec** 调色板 | 多为 CC0 | 颜色数值本身不受版权保护，用来统一全项目色板 |
| 音效底库 | **Sonniss #GameAudioGDC** | 免版税·可商用·**免署名**·无项目数限制 | 7.47 GB / 347+ 文件，下载一次基本够用 |
| 音效补充 | **Freesound**（筛 CC0） | CC0 / CC BY | **必须排除 CC BY-NC** |
| 音效补充 | **Mixkit** | 自有许可，明确允许用于 Video games | 可商用免署名，禁原样再分发 |
| 像素中文字体 | **方舟像素字体** / **缝合像素字体** | SIL OFL 1.1 | 见下方避坑 |
| 中文正文字体 | **思源黑体 / 思源宋体** | SIL OFL 1.1 | 最稳的选择 |
| 唐代纹样素材 | **The Met Open Access** | **CC0** | 49.2 万张公有领域图，含丝织品，可商用 |
| 真实形制参考 | Wikimedia Commons 各分类页 | **逐文件看协议** | 分类页本身不授权 |

### ⚠️ 四个可直接害到你的坑（已核实）

| 坑 | 真相 | 对策 |
|---|---|---|
| **Zpix（最像素）** | 中文网上都说"免费商用"——**已过期**。作者仓库写明商用 **USD $1000**（单产品） | **改用方舟像素 / 缝合像素**（均 SIL OFL 1.1）。搜"像素中文字体 免费商用"第一个出来的就是它，最容易踩 |
| **站酷字体** | "站酷字体全部免费商用"**已过期**。站酷高端黑、站酷酷黑体仍免费商用，但字库主页已以付费字体为默认列表 | 用前逐个确认具体那一个 |
| **BBC Sound Effects** | 仅限个人 / 教育 / 研究 | **本项目不可用** |
| **LPC（Liberated Pixel Cup）** | CC BY-SA 3.0 / GPL 3.0，**具传染性** | 会要求你的整个作品也开源，闭源项目必须避开 |

### 其他已核实的注意点

- **ZapSplat** 的旧地址 `zapsplat.com/license-type/` 已 404，新地址是 `/license-type/standard-license/`。Basic 免费账号可商用但**必须署名**。
- **Pixabay** 只有 **2019-01-09 之前**发布的素材才是真 CC0。
- **CraftPix** 可用（免费素材可商用、可修改、无需署名），但 **2026 新增"禁止用于 AI 训练"条款**，且禁转售源文件。
- **game-icons.net** 是 **CC BY 3.0**，需署名。
- **阿里巴巴普惠体 / MiSans / HarmonyOS Sans / OPPO Sans** 厂商自有许可，可免费商用，但**不是 OFL**。MiSans 允许嵌入但需注明使用了 MiSans；HarmonyOS Sans 条款社区有争议，求稳用思源系。

### 两块找不到的短板（不要用图库凑数）

| 类别 | 情况 | 对策 |
|---|---|---|
| **新疆产艾德莱斯绸**可商用实拍图 | 可商用的 atlas/ikat 图绝大多数是**乌兹别克（马尔吉兰）/ 塔吉克**产地 | **绝不可标成"新疆艾德莱斯"**——构成地域误导。改用 AI 生成并如实标注来源 |
| **维吾尔族手鼓（dap）**可授权图集 | 无专属 Commons 分类；Hartenberger 收藏站无授权说明 | 用 The Met 的 CC0 藏品，或 AI 生成 |
| **唐代西域铜器**开放授权来源 | Met / Commons 的样本远少于织物与陶瓷 | 用织物纹样代替，或后期再找 |

### 关于参考图的一条形制知识（影响地图美术方向）

**交河故城的生土建筑是"减法建筑"**——从台地上掏出来的，不是一栋栋独立房子。
像素表现应该是**层叠高差 + 密集院墙**，而不是孤立的小屋。搜参考图时按这个方向找。

### ⚠️ 关于"搜素材包"这件事的强烈建议

**T0 阶段别去一张张搜散图。** 去找一套完整的像素素材包，原因：

1. **风格天然统一** —— 散图拼在一起光影方向、色温、线条粗细都会打架，返工成本极高
2. **规格天然一致** —— 素材包内部的 16×16 是同一个 16×16
3. **省时间** —— 一套包可能有 500+ 素材，覆盖你 T0 和 T1 的大部分需求
4. **授权清晰** —— 正规素材包有明确的商用许可

**已核实的两个 CC0 起点**：Ninja Adventure Asset Pack（itch.io）、Kenney（kenney.nl/assets）。
两者都是 CC0，可商用、免署名，能直接当项目基底。先下这两个，再看缺口补什么。

### 如果坚持自己搜/生成

- **每张图搜完后立刻降色到 ART_STYLE.md 的 32 色板**，不要等到最后统一处理
- **同一天出图**，隔几天再出风格一定会漂
- 参考图放 `assets/_reference/`，**绝不可直接使用**

---

## 搜集时请同时登记授权

每引入一个素材，立刻在 [asset-licenses.md](D:\坎儿井\docs\asset-licenses.md) 写一行：

```
文件路径 | 来源 URL | 授权类型 | 授权证明文件 | 录入日期
```

**AI 生成的图也要记**（工具、日期、prompt）。赛事被质询时这就是你的凭据。
事后补记会痛苦十倍——**边搜边记。**
