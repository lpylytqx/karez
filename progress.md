# 进度与待办

> 每次开工先看这一页。状态定义：`TODO` 未开始 / `WIP` 进行中 / `DONE` 已完成 / `BLOCKED` 被外部条件卡住。

最后更新：2026-10-05

---

## 当前阶段：S1（M1 闭环）

### 已完成

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

### 待你完成（我做不了的部分）

| # | 事项 | 状态 | 说明 |
|---|---|---|---|
| A | ~~装 Godot 4.4，打开 `scripts/project.godot` 确认能跑~~ | **DONE** | Godot 4.7.2 **已随仓库放在 `tools\`**，无需另装。2026-10-05 实机跑通，`capture.tscn` 可稳定出图 |
| B | 办 DeepSeek 账号，复制 `.env.example` 为 `.env` 填 Key | TODO | **唯一硬阻塞**。Key 不要发给任何人，也不要提交 |
| C | 找文化审核人，按 [03-ai-characters.md](D:\坎儿井\docs\03-ai-characters.md) 第四节过一遍 | TODO | 高风险 5 条优先 |
| D | 定美术方案（A 生成 / B 买 / C 手绘）与逻辑分辨率 | TODO | 见 [04-art-checklist.md](D:\坎儿井\docs\04-art-checklist.md) 第七节 |
| E | 确认那个旅人是谁、坎儿井为何淤塞 | TODO | 这是你的创作核心，必须你定 |

### 下一步可以让我做

| # | 事项 | 前置条件 |
|---|---|---|
| 甲 | 把 64 条事件接进 Godot（事件调度器 + 条件 DSL 求值器） | 无，随时可做 |
| 乙 | 写 S2 的坎儿井挖掘交互（点选竖井、施工进度、水流可视化） | 无 |
| 丙 | 写美术生成 prompt 模板 + 统一后处理脚本（降色到同一色板） | 你选定美术方案后 |
| 丁 | 补事件库续集：木卡姆集会链、三座古城链、旅人主线 | 你确认角色设定后 |
| 戊 | 战斗系统（回合制 + AI 指挥敌人） | S2/S3 之后 |
| 己 | 3 分钟路演逐秒脚本 + 兜底对话表 | 核心循环能演示之后 |

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
- **Godot 里实际运行。** 本机没有 Godot，也没有 .NET SDK，`.gd` 与 `.cs` 都没被真正的编译器过一遍
- **真实 API 调用。** 环境无 `DEEPSEEK_API_KEY`，所有 DeepSeek 结论来自官方文档而非线上实测
- **实际试玩手感。** 数值是算出来的，不是玩出来的
- **文化准确性。** 41 条文化断言全部标记为待审，需要人来判断
