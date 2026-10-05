# 《坎儿井》项目工作区

> 从 [游戏设计大纲_坎儿井.md](C:\Users\j\Desktop\游戏设计大纲_坎儿井.md)（GDD v1.0）落地为可运行游戏。
> 项目状态：**M1 闭环已跑通** —— Godot 端能渲染地图并截图，AI 服务 `/health` 与 `/narrate` 均返回 200。

---

## 技术架构（已定）

| 层 | 技术 | 职责 |
|---|---|---|
| 表现层 | **Godot 4.7.2（2D）** | 地图、角色、建筑、UI、动画、战斗演出 |
| 状态层 | **Godot GDScript** | 所有精确数值计算（水/粮/繁荣/血量），保证确定性 |
| AI 层 | **Python + FastAPI 旁挂服务** | 调 DeepSeek、维护角色记忆、生成事件与对话 |
| 数据层 | **JSON 配置文件** | 数值表、事件库、角色卡，策划与代码解耦 |

**为什么是"Godot + Python 旁挂"而不是二选一：**
数值计算放 GDScript（零延迟、可回放、可存档），AI 调用放 Python（生态成熟、方便你和 AI 协作调试）。
两者用本机 HTTP 通信（`127.0.0.1:8787`），Godot 侧即使 AI 服务挂了，游戏仍能以降级模式运行——这一点直接决定演示会不会翻车。

```
Godot 客户端  ──HTTP POST──▶  Python AI 服务  ──▶  DeepSeek API
   ▲                                    │
   └────────── JSON: 叙事 + 状态增量 ────┘
```

**关键约定（贯穿全项目，不可违反）：**
1. **LLM 不做精确算术。** 所有数字由本地代码算，模型只输出"叙事文本 + 结构化意图"。
2. **AI 返回必须是可校验的 JSON。** 每个 schema 都有版本号，校验失败走兜底而非崩溃。
3. **AI 服务可以离线。** 无 Key / 无网络时自动降级为本地预设内容（demo 模式），演示不冷场。
4. **前端与后端不共享内存。** 一切通过显式 JSON 协议，方便你分别替换两端。

---

## 目录结构

```
D:\坎儿井\
├── README.md                     ← 你在这
├── progress.md                   ← 任务进度与待办（每次开工先看）
├── .gitignore                    ← 已锁死：.env 永不可提交
├── docs\
│   ├── 00-architecture.md        ← 架构、AI 协议、DeepSeek 接口事实
│   ├── 01-scope-and-order.md     ← 单人无期限下的建设顺序与纪律
│   ├── 03-ai-characters.md       ← 角色人设总览 + 文化审核工作清单
│   └── 04-art-checklist.md       ← 美术资源需求表（含三种方案对比）
├── data\                         ← 数值与内容的唯一真源
│   ├── numbers.json              ← 全系统数值
│   ├── characters.json           ← 7 套角色卡与 system prompt
│   ├── events.v1.json            ← 事件库 64 条
│   └── events.schema.json        ← 事件的 DSL 定义（条件/效果/选项）
├── scripts\                      ← Godot 工程根目录（用 Godot 打开这一层）
│   ├── project.godot
│   ├── core\game_state.gd        ← 权威状态、delta 门禁、存档、时间推进
│   ├── ui\main.gd                ← M1 极简界面（只为验证管道）
│   ├── scenes\map.tscn           ← 主场景（project.godot 里的 run/main_scene）
│   ├── scenes\capture.tscn       ← 一次性截图工具，仅用于验证，不参与正式游戏
│   └── csharp_port\GameState.cs  ← C# 对照端口（纯逻辑库，二选一）
└── ai_backend\                   ← Python AI 旁挂服务
    ├── main.py                   ← FastAPI 服务入口
    ├── ai\client.py              ← DeepSeek 直连封装（含思考模式处置）
    ├── ai\validate.py            ← delta 白名单与夹紧
    ├── ai\characters.py          ← prompt 拼装（静态/动态分层以命中缓存）
    ├── ai\demo.py                ← 离线兜底内容
    ├── schema.json               ← AI 输出的内容契约
    ├── smoke_test.py             ← M1 管道自检（无需 API Key）
    ├── verify.py                 ← 全项目结构与平衡校验（89 项）
    ├── requirements.txt
    └── .env.example              ← 复制为 .env 后填 Key
```

---

## 怎么跑起来

```powershell
# 1) 装依赖（虚拟环境已建好，直接装包）
#    走 pyenv_install 工具，不要直接 pip

# 2) 自检：验证项目结构与数值平衡（不需要 Key，不需要网络）
.venv\Scripts\python.exe ai_backend\verify.py

# 3) 自检：验证 AI 管道逻辑（不需要 Key）
.venv\Scripts\python.exe ai_backend\smoke_test.py

# 4) 配置密钥后才接通真实 AI
copy ai_backend\.env.example ai_backend\.env
#    编辑 .env 填入 DEEPSEEK_API_KEY，确认 FORCE_DEMO=0

# 5) 启动 AI 服务
.venv\Scripts\python.exe ai_backend\main.py
#    浏览器打开 http://127.0.0.1:8787/health 确认模式为 live

# 6) 运行游戏
#    Godot 可执行文件就在本仓库内，无需另外安装：
#      tools\Godot_v4.7.2-stable_win64.exe --path scripts
#    或用 Godot 编辑器打开 scripts\project.godot 后按 F5

# 7) 只想截一张图看画面（不需要人工操作）
#      tools\Godot_v4.7.2-stable_win64.exe --path scripts res://scenes/capture.tscn
#    输出：%APPDATA%\Godot\app_userdata\坎儿井\capture.png
```

**没配 Key 也能玩。** 未配置或断网时服务自动进入 demo 模式，返回本地预设台词，
游戏不会崩溃——这是刻意的演示容错设计（见 [00-architecture.md](D:\坎儿井\docs\00-architecture.md) 第四节）。

---

## 当前阶段目标（M1）

**只做一件事：跑通"玩家输入 → 调 AI → 拿到 JSON → 状态变化 → 界面显示"的闭环。**

不碰美术、不碰战斗、不碰多角色。M1 验收标准：

- [x] Python 服务能启动，`/health` 返回模型与模式（live / demo）
- [x] `POST /narrate` 发一句玩家输入，返回合法 JSON（含 `narration` + `state_delta`）
- [x] `state_delta` 能真实修改本地水/粮/钱数值（且拦住越权路径与幻觉数值）
- [x] 无 Key / 断网时走 demo 兜底，不崩溃
- [x] Godot 端能发出请求并渲染返回文本 ← **已用项目自带 Godot 4.7.2 实测**
- [x] 拔掉网线后游戏不崩溃 ← **demo 模式已覆盖此路径**

> 前四项由 `smoke_test.py` 在无网络条件下验证（38 项断言全通过）。
> 后两项已于 2026-10-05 用 `tools\Godot_v4.7.2-stable_win64.exe` 实机确认：
> 运行 `res://scenes/capture.tscn` 可稳定渲出地图并保存截图。
>
> **注意：Godot 可执行文件就在本仓库 `tools\` 内，无需另外安装。**
