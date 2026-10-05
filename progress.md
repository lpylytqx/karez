# 进度与待办

> 每次开工先看这一页。状态定义：`TODO` 未开始 / `WIP` 进行中 / `DONE` 已完成 / `BLOCKED` 被外部条件卡住。

最后更新：2026-10-05

---

## 当前阶段：S2（治水核心）—— 已可玩

### S1 / M1 已完成

| # | 事项 | 状态 | 产出 |
|---|---|---|---|
| 1 | 技术架构定案（Godot + Python 旁挂） | DONE | [00-architecture.md](D:\坎儿井\docs\00-architecture.md) |
| 2 | 建设顺序与纪律（单人无期限版） | DONE | [01-scope-and-order.md](D:\坎儿井\docs\01-scope-and-order.md) |
| 3 | 全系统数值表 | DONE | [numbers.json](D:\坎儿井\data\numbers.json)、[02-numbers 说明并入架构文档] |
| 4 | 7 套角色人设与 system prompt | DONE | [characters.json](D:\坎儿井\data\characters.json)、[03-ai-characters.md](D:\坎儿井\docs\03-ai-characters.md) |
| 5 | 事件库 64 条（超标完成，原计划 60） | DONE | [events.v1.json](D:\坎儿井\data\events.v1.json) |
| 6 | 美术资源需求表（含三种方案对比） | DONE | [04-art-checklist.md](D:\坎儿井\docs\04-art-checklist.md) |
| 7 | AI 内容契约（schema + 门禁规则） | DONE | [schema.json](D:\坎儿井\ai_backend\schema.json) |
| 8 | DeepSeek 接口封装（含思考模式坑点的处置） | DONE | [client.py](D:\坎儿井\ai_backend\ai\client.py) |
| 9 | delta 白名单与夹紧校验 | DONE | [validate.py](D:\坎儿井\ai_backend\ai\validate.py) |
| 10 | AI 旁挂服务（FastAPI，含降级） | DONE | [main.py](D:\坎儿井\ai_backend\main.py) |
| 11 | Godot 工程骨架（GDScript 主线 + C# 对照端口） | DONE | [scripts/](D:\坎儿井\scripts) |
| 12 | M1 自检脚本（38 项断言，全通过） | DONE | [smoke_test.py](D:\坎儿井\ai_backend\smoke_test.py) |
| 13 | 全项目校验器（89 项断言，全通过） | DONE | [verify.py](D:\坎儿井\ai_backend\verify.py) |
| 14 | 水平衡修正（两轮，见下方"数值修订记录"） | DONE | [numbers.json](D:\坎儿井\data\numbers.json) |
| 15 | assets/ 目录结构（25 个目录 + 分层 README） | DONE | [assets/](D:\坎儿井\assets) |
| 16 | 美术画风规范（32 色板、规格、AI 模板、命名） | DONE | [ART_STYLE.md](D:\坎儿井\assets\ART_STYLE.md) |
| 17 | 素材搜集清单（分三阶梯，T0 仅 38 张） | DONE | [05-asset-shopping-list.md](D:\坎儿井\docs\05-asset-shopping-list.md) |
| 18 | 授权登记表（图片/音频/字体/参考图/AI 生成） | DONE | [asset-licenses.md](D:\坎儿井\docs\asset-licenses.md) |
| 19 | 参考图与可商用素材源调研 | DONE | [06-reference-and-free-asset-research.md](D:\坎儿井\docs\06-reference-and-free-asset-research.md) |

### S2 已完成（2026-10-05）

| # | 事项 | 状态 | 产出 |
|---|---|---|---|
| 20 | 挖竖井交互（点击地图竖井 / 右侧按钮，按 numbers.json 扣料与工期） | DONE | [game_state.gd](D:\坎儿井\scripts\core\game_state.gd) `start_dig()` |
| 21 | 事件系统接入 64 条事件（条件 DSL + 加权抽取 + 效果应用） | DONE | [event_system.gd](D:\坎儿井\scripts\core\event_system.gd) |
| 22 | 绿洲随 `karez.sections` 生长（地形由状态驱动，不再写死） | DONE | [map_view.gd](D:\坎儿井\scripts\scenes\map_view.gd) |
| 23 | 整合场景：地图+玩家+HUD+对话+事件弹窗收进同一屏 | DONE | [play.tscn](D:\坎儿井\scripts\scenes\play.tscn) |
| 24 | HUD：资源面板 / 操作按钮 / 对话栏 / 事件卡片 | DONE | [hud.gd](D:\坎儿井\scripts\ui\hud.gd) |
| 25 | 时段推进（晨午暮夜 4 段，每段 2 行动点，跨夜结算） | DONE | `advance_phase()` |
| 26 | 建筑建造（4 种，含造价校验与工期） | DONE | `start_build()` |
| 27 | 存档纳入事件触发记录（读档不复位冷却） | DONE | `save_to()` / `load_from()` |
| 28 | 核心逻辑无头测试 79 项 | DONE | [logic_test.tscn](D:\坎儿井\scripts\tests\logic_test.tscn) |
| 29 | 自动截图验证工具（初始 vs 挖通三段对比） | DONE | [capture_play.tscn](D:\坎儿井\scripts\scenes\capture_play.tscn) |

### 待你完成（我做不了的部分）

| # | 事项 | 状态 | 说明 |
|---|---|---|---|
| A | ~~装 Godot 4.4，打开 `scripts/project.godot` 确认能跑~~ | **DONE** | Godot 4.7.2 **已随仓库放在 `tools\`**，无需另装。2026-10-05 实机跑通，`capture.tscn` 可稳定出图 |
| B | ~~办 DeepSeek 账号，复制 `.env.example` 为 `.env` 填 Key~~ | **DONE** | 已完成。Key 只写在 `ai_backend/.env` 内，该文件被 `.gitignore` 第 8 行 `**/.env` 挡住，已验证 `git status` 与 `git grep` 都搜不到 |
| C | 找文化审核人，按 [03-ai-characters.md](D:\坎儿井\docs\03-ai-characters.md) 第四节过一遍 | TODO | 高风险 5 条优先 |
| D | 定美术方案（A 生成 / B 买 / C 手绘）与逻辑分辨率 | TODO | 见 [04-art-checklist.md](D:\坎儿井\docs\04-art-checklist.md) 第七节 |
| E | 确认那个旅人是谁、坎儿井为何淤塞 | TODO | 这是你的创作核心，必须你定 |

### 下一步可以让我做

| # | 事项 | 前置条件 |
|---|---|---|
| 甲 | ~~把 64 条事件接进 Godot（事件调度器 + 条件 DSL 求值器）~~ | **DONE**（2026-10-05） |
| 乙 | ~~写 S2 的坎儿井挖掘交互（点选竖井、施工进度、水流可视化）~~ | **DONE**（2026-10-05） |
| 丙 | ~~写美术生成 prompt 模板 + 统一后处理脚本（降色到同一色板）~~ | **DONE**（postprocess.py 已在用） |
| 丁 | 补事件库续集：木卡姆集会链、三座古城链、旅人主线 | 你确认角色设定后 |
| 戊 | 战斗系统（回合制 + AI 指挥敌人） | S3 之后 |
| 己 | 3 分钟路演逐秒脚本 + 兜底对话表 | 核心循环能演示之后 ← **现已满足前置条件** |
| 庚 | **S3 经营骨架**：给已建成的建筑接产出（驿馆住宿收入、仓库仓储加成、厨房粮→馕） | 无 |
| 辛 | ~~**S4 AI 角色**：记忆召回的 prompt 拼装（现在只写入不召回）~~ | **DONE**（2026-10-05，见下） |
| 壬 | 接入音频（188 个 Kenney 音效，题材不符，需先决定是替换还是先用着） | 你定策略 |
| 癸 | 角色好感度 `affinity` 的读写（数值字段已在，但对话与事件都没真正影响它） | 无 |

### S4 已完成（2026-10-05）

| # | 事项 | 状态 | 产出 |
|---|---|---|---|
| 30 | 记忆结构化存储（`day` / `text` / `kind` / `imp`），兼容旧存档纯字符串 | DONE | `game_state.gd` |
| 31 | 记忆按**重要度**召回（prompt 里一直写着「按重要程度排序」，之前给的却是插入顺序） | DONE | `_memory_sorted()` |
| 32 | 承诺类记忆单独成块喂给模型（混在大列表里容易被忽略） | DONE | `get_promises()` + `characters.py` |
| 33 | 关键词推断重要度（AI 的 `memory_append` 是纯字符串，没有 kind 字段） | DONE | `_infer_kind()` |
| 34 | 淘汰策略改为「丢最不重要且最旧」，避免珍贵承诺被闲聊挤掉 | DONE | `_cull_memory()` |
| 35 | **本地兜底**：AI 漏记承诺时由本地补记（实测模型记账不稳定） | DONE | `_promise_fallback()` |
| 36 | 真实 API 联调测试（两轮：许承诺 → 回忆承诺） | DONE | [live_test.py](D:\坎儿井\ai_backend\live_test.py) |
| 37 | Godot 客户端端到端测试（走完整 `send()` → HTTP → DeepSeek 路径） | DONE | [live_client_test.tscn](D:\坎儿井\scripts\tests\live_client_test.tscn) |

---

## 数值修订记录

### 水平衡（两轮修正，值得记下来因为第一版和第二版都错了）

| 版本 | 初始水 | 初始残流 | 净消耗 | 缓冲天数 | 问题 |
|---|---|---|---|---|---|
| v1（初稿） | 60 | 0 | 13 方/天 | **3.3 天** | 太紧。第一段竖井工期就 2 天，玩家毫无容错，一次意外即死 |
| v2（我的第一次修正） | 130 | 18 | **0 方/天** | ∞ | **更糟**。残流等于日耗，水永不枯竭，紧迫感彻底消失 |
| **v3（现版）** | **90** | **5** | **13 方/天** | **6.9 天** | 符合设计意图的 7 天窗口；修完第一段后盈余 42/天进入舒适区 |

另新增 `karez.season_flow_bonus.winter = -3`：冬季在融水倍率之外再扣基础渗流。
效果是 4 段竖井时冬季供水降到 98 方/天，只能养 33 人——**逼玩家冬天放慢扩张**，这是后期的节奏控制手段。

> 教训：第一轮修正时我直接让残流等于日耗，把"净消耗"算成了 0，
> 那不是平衡，是把机制关掉了。校验器现在有一条专门断言"净消耗必须为正"来防这个错。

### 战斗单位

`numbers.json` 里是 5 个我方（民兵/骑手/弓手/护卫/匠人）+ 3 个敌方（马匪/狼/马匪头目）= 8 个，
与 GDD 4.4 的描述一致。我在校验器初版里误写成"6 我方 + 3 敌方"，是校验器的错，已修。

---

## 已知问题与技术债

| # | 问题 | 严重度 | 处置 |
|---|---|---|---|
| 1 | `water.current` 的容量上限只在客户端夹紧，Python 侧用哨兵值 | 低 | 可接受。要更严就在请求里带 `water_capacity` |
| 2 | `cri_illness` 事件里 `exiled_sick` 的 `deferred` 人口减少缺实现 | 中 | 事件系统落地时补（见 events.v1.json 的 design_gaps） |
| 3 | 事件库全部数值未经实测，是估值 | 中 | S2/S3 阶段必须实调，尤其是 water 与 morale |
| 4 | 税率固定 30 两，未随繁荣度浮动 | 低 | 后期再改，见 events.v1.json 的 design_gaps |
| 5 | 战斗与博弈接口（`/battle/decide`、`/event/generate`）只有设计未实现 | — | M1 用不到，S5/S6 再写 |
| 6 | C# 端口未编译验证（本机无 .NET SDK） | 中 | 你装 SDK 后跑一次 `dotnet build`，有报错告诉我 |
| 7 | 事件库 70/198 个选项无明确资源支出 | 低 | **已列出清单**（见 `verify.py` 输出）。这些选项的代价在时间/人力/人情/风险里，靠人工 review，机械判定不可靠 |
| 8 | `numbers.json` 的数值全部未经实际试玩 | **高** | 水平衡已算过，但 6.9 天是否真的"紧张而不挫败"，只有玩过才知道。S2 第一件事就是试玩 |
| 9 | `assets/` 在 Godot 工程目录之外 | 已修 | 已在 `project.godot` 加 `application/config/import_path="res://../assets"`。若日后把 assets 移进 scripts/ 内部，删掉这行 |
| 10 | ~~美术素材为零~~ **已不成立** | — | 2026-10-05 实测：正式目录已有 **183 张图**（162 张符合 32 色板，21 张立绘按 ART_STYLE 第 119 行刻意非像素风）+ **188 个音频** + **14 个字体**。真实缺口见 assets/README.md |
| 11 | AI 生成图的统一后处理脚本还没写 | 中 | 降色到 32 色板 + 最近邻缩放 + 清理半透明边缘。等你开始出图时我写，`pillow` 就够 |

---

## 阶段验收清单（M1）

- [x] 服务能启动，`/health` 返回模型与模式
- [x] `POST /narrate` 返回合法 JSON（含 narration + state_delta）
- [x] 自检脚本验证 delta 能真实修改水/粮/钱数值（且拦住越权与幻觉值）
- [x] 无 Key 时走 demo 兜底，不崩溃
- [x] **在 Godot 里实际跑一次** ← 2026-10-05 用 `tools\Godot_v4.7.2-stable_win64.exe` 实测
- [x] 断网降级路径 ← demo 模式已覆盖（服务全程未连外网）

> 前四项由 `smoke_test.py` 在无网络条件下验证通过。
> 后两项已于 2026-10-05 实机确认：`res://scenes/capture.tscn` 稳定渲出地图并保存截图，
> AI 服务 `/health` 与 `/narrate` 均 HTTP 200。

---

## 变更日志

| 日期 | 变更 |
|---|---|
| 2026-10-05 | 项目创建。架构定案、数值表、7 套角色、64 条事件、美术需求表、AI 服务与 Godot 骨架全部落地。M1 自检 38 项 + 全项目校验 89 项全通过。 |
| 2026-10-05 | 水平衡修正（60/0 → 130/18 → 90/5，两轮）；新增冬季渗流修正；新增 `verify.py` 长期校验工具；C# 端口与 GDScript 数值对齐。 |
| 2026-10-05 | **M1 实机跑通**。修 `ai_backend/main.py` 的启动崩溃：第 302 行 `print("  ⚠️ ...")` 在 GBK 控制台抛 `UnicodeEncodeError`，服务起不来。已在文件顶部加 Windows 下强制 stdout/stderr 走 UTF-8 的重配置（治本），并把该 emoji 换成 `[!]`（双保险）。补 `scripts/icon.svg`（消除 `Error opening file 'res://icon.svg'`）。文档同步：Godot 版本 4.4→4.7.2、主场景 main.tscn→map.tscn、assets 状态由「空的」更新为实测数量、M1 验收清单两项勾选。 |
| 2026-10-05 | **S2 治水核心落地**。新增 `event_system.gd`（64 条事件的条件 DSL + 加权抽取 + 效果应用）、`play.tscn/gd`（整合场景）、`hud.gd`（资源面板与事件卡片）、`tests/logic_test.tscn`（79 项断言）。`map_view.gd` 重写为「绿洲半径由 `karez.sections` 驱动」。踩到并修掉的问题见下节。 |
| 2026-10-05 | 素材补给：从仓库内已有的 Kenney `tiny-farm`/`tiny-town` 提取 51 个 tile，降色到 32 色板后归位（`tiles/farmland` 0→11、`tiles/props` 0→32、`tiles/terrain` 14→22），正式素材 183→234 张。授权登记已追加。 |
| 2026-10-05 | **接通真实 AI（S4 落地）**。`ai_backend/.env` 配好 Key 后 `/health` 返回 `mode=live`。修了记忆系统的四处问题：① `get_memory()` 返回插入顺序，而 prompt 里写的是「按重要程度排序」——标签是假的；② 只给 8 条而 prompt 能收 13 条；③ `kind` 字段被整个丢弃，承诺与闲聊无区别；④ 淘汰时只丢最旧的，珍贵承诺会被闲聊挤掉。新增 `live_test.py`（真实 API 两轮联调）与 `live_client_test.tscn`（Godot 客户端端到端）。实测老坎匠能复述出「那把松头的镢头」这类具体细节。AI 漏记承诺时由 `_promise_fallback()` 本地兜底 —— 实测 deepseek-flash 的 `memory_append` 时有时无，而记住承诺是 S4 的核心卖点。 |
| 2026-10-05 | **修美术观感（用户反馈「这图画是啥呀」）**。发现并修掉三类问题：① **沙漠底纹是墙纸** —— `desert_light_01/02` 各带一块橙黄斑块，它们是**地形过渡贴图**，被当底纹平铺 880 次后斑块等距重复，一眼看出是贴图。批量里没有纯沙漠底，故新增 `scripts/pipeline/make_sand.py` 按 32 色板程序化生成 4 张，并把原过渡贴图改用在绿洲与沙漠的交界处。② **tile 编号大面积挑错** —— 第一版照低分辨率标注图目视识别、心算 `n = row*12 + col`，结果 `crop_stage_4_ripe` 拿到木桶、`crop_harvested` 拿到石堆、`fence_wood_rail` 拿到石地板、`wall_brick_01` 拿到窗户、`rock_small_01` 拿到红果灌木。新增 `scripts/pipeline/reextract_tiles.py` 按精确编号重提 79 个 tile 并清掉 51 个错的。③ 顺带给农田加了作物多样性、给聚落加了农夫与牲畜。 |

| 2026-10-05 | **修树（用户反馈「你的树不像树」）**。放大核对后发现问题比"画得抽象"严重得多：① `tree_green_01(48x48)` / `tree_orange_01(48x48)` **根本不是树，是 tileset 碎片** —— 它们是一棵大树树冠的四分之一（左上角叶、右上角棕、左下土坡…），我按独立树摆放，绿洲就成了一坨认不出的绿块；② `tree_pink_01` / `tree_small_02` **是完全空的**（0% 不透明像素，我那个「四边透明=独立物件」的判定正好被它们骗过）；③ 密度过高（约 19 棵 48px 的树挤在 240px 见方里，必然互相压盖）；④ 树用 `centered=true` 定位，48px 的树有一半伸到格点下方，看着浮空。修法：新增 `scripts/pipeline/make_trees.py` 按色板生成 6 张（**白杨与胡杨是新疆标志树种**，胡杨尤其贴题）；`_add_tree()` 改为根部落地对齐；密度下调并加间距约束（<2.7 格就重新投点）。顺带把草地底纹也换掉 —— 它带着和沙漠同款的等距重复弧线，`make_ground.py` 一次生成 4 沙 + 6 草。 |

---

## 美术踩坑（三则，都是同一类错误）

| 现象 | 根因 | 修法 |
|---|---|---|
| 沙漠像**墙纸** | 拿**地形过渡贴图**当底纹（`desert_light_01/02` 各带一块装饰斑块） | `make_ground.py` 程序化生成纯底纹；过渡贴图改用在交界处 |
| 草地有**等距重复的浅色弧线** | 同上，`grass_*` 底图自带重复特征，平铺 880 次后显形 | 同上 |
| **树不像树**，是一坨绿块 | 把 **tileset 碎片**（大树树冠的四分之一）当成独立树；另有两张是**完全空图** | `make_trees.py` 生成完整树（橡树/白杨/胡杨）；只用已验证完整的贴图 |
| 「农田」里长的是**木桶、石堆、一张脸** | 照低分辨率标注图目视识别后**心算** `n = row*12 + col`，算错格 | 渲染放大网格、**每格标真实编号**再挑；`reextract_tiles.py` 重提 |
| 树看着**浮空 / 各飘各的** | 精灵用 `centered=true` 定位，48px 的树一半伸到格点下方 | `_add_tree()` 改根部落地（底边贴格点） |

**共同教训**：像素素材**必须按编号与尺寸核对**。
这类错误很隐蔽 —— 画面能跑、不报错、绿洲照常长大，只是「看起来怪」，
最容易被当成美术风格问题放过去。

**验证素材是否可用的两个快速检查**：
```
不透明像素占比 = 0  ->  空图（tree_pink_01 / tree_small_02 就是这样）
四边贴边 + 内部有多块互不相连的形状  ->  大概率是 tileset 碎片
```

---

## S4 记录：真实 AI 联调发现的问题

| 现象 | 根因 | 处置 |
|---|---|---|
| prompt 声称「按重要程度排序」，实际是插入顺序 | `get_memory()` 只是 `mem.slice(-8)` | 加 `imp` 字段并真正排序 |
| 承诺与闲聊在存储里没有区别 | `add_memory()` 把 `kind` 丢掉了，只存 `"[第N天] 文本"` | 改结构化存储，兼容旧格式 |
| 灌 210 条闲聊后承诺消失 | 淘汰是 `pop_front()`，只按时间丢 | 改「丢最不重要且最旧」 |
| **AI 的 `memory_append` 时有时无** | 契约只写「值得长期记住的事」，模型自由裁量；temperature=1.0 | 契约收紧 + **本地兜底**（关键记账不能托付给模型自觉） |
| 角色记不住具体细节 | 承诺混在记忆大列表里被模型忽略 | `promises` 单独成块，放在记忆之前 |
| PowerShell 调 API 中文全是乱码 | PS 5.1 的 `Invoke-RestMethod` 对无 charset 的 JSON 按 Latin-1 解码 | 改用 Python `urllib` 写测试（`live_test.py`） |

---

## S2 开发中踩到的坑（都值得记，因为都会再犯）

| 现象 | 根因 | 修法 |
|---|---|---|
| `get_path()` 整个脚本解析不过，进程既不打印也不退出 | **方法名撞上 Godot `Node` 内置方法**。`Node.get_path()` 无参，同签名覆盖失败 | 改名 `query()` |
| `Cannot infer the type of "x"` 一片红 | 项目把「从 Variant 推断类型」设为**错误**。`load()`、`Dictionary.get()`、以及任何 `Node` 上的调用都返回 Variant | `:=` 改显式类型，或改用 `=` 不做推断 |
| 三个按钮背后出现一块**圆角深色面板** | **Godot 按字体与主题边距强制控件最小高度**：Label 13→23、Button 18→24、LineEdit 16→31。我按 22px 间距排，实际 24px 高 → 相邻按钮重叠 2px，样式框连成一片 | 全 HUD 按实测最小尺寸重排（单行 23 / 双行 46 / 按钮 24） |
| 资源行显示原始 `[color=#...]` 文本 | **`Label` 不解析 BBCode**（只有 `RichTextLabel` 会） | 改纯文本 + `modulate` 表示颜色 |
| 竖井挤成一条半透明实心柱 | `well_shaft_01.png` 是 **32×32**，而我按 2 格（32px）间隔排 → 边贴边 | 竖井链改斜线排布，对角间距约 45px |
| 顶栏「建设:」后面空白 | `.get(key, 默认值)` 只在**键不存在**时用默认值；而 `_initial_state` 里 `display` 是存在的空串 | 单独判空 |
| 输入框聚焦时方向键会一边打字一边带着角色跑 | 把对话栏和行走放进同一屏的必然冲突 | `player.gd` 检测 `gui_get_focus_owner() is LineEdit` 时不响应移动 |
| 完工当天出水量不变，要等第二天 | `_tick_construction()` 原本放在 `advance_day()` 末尾，而 `sections` 在开头读 | 施工推进移到函数最前面 |

---

## 我做过与没做过的事（透明说明）

**验证过的：**
- 所有 JSON 可解析、跨文件引用一致（角色 id、事件 delta 路径与 op）
- delta 白名单能拦住越权路径 / 非法 op / NaN / 超幅度值（12 个攻击用例）
- 无 Key 时走 demo 兜底，7 个角色都有兜底台词，且兜底不改数值、不写记忆
- prompt 的静态前缀逐字稳定（上下文缓存的前提）
- 水平衡通过计算复核（净消耗、缓冲天数、四季产能、人口承载）
- GDScript 括号配对、缩进一致、函数声明完整
- GDScript / C# / Python 三处的白名单与兜底数值一致

**没验证过（我不能声称已验证）：**
- ~~**Godot 里实际运行。**~~ → **已于 2026-10-05 推翻**：Godot 4.7.2 就在仓库 `tools\` 内，
  `play.tscn` 已实机渲染截图（见 `docs/screenshots/`），79 项核心逻辑断言实机通过
- **真实 API 调用。** 环境无 `DEEPSEEK_API_KEY`，所有 DeepSeek 结论来自官方文档而非线上实测
- **实际试玩手感。** 数值是算出来的，不是玩出来的
- **文化准确性。** 41 条文化断言全部标记为待审，需要人来判断
- **音频未接入。** 188 个 Kenney 音效一个都没接进游戏，且题材不符（无新疆乐器音色）
- **S3 之后的系统全未开始。** 建筑只做到「能建成」，还没有产出逻辑
