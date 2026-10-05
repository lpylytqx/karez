# 架构与协议说明

> 本文是 Godot 端与 Python AI 服务之间的**契约**。两端任何一方改动，必须同步更新本文。

---

## 一、进程与端口

| 组件 | 启动方式 | 地址 |
|---|---|---|
| Godot 游戏 | 打开 `scripts/project.godot` 运行 | 客户端 |
| Python AI 服务 | `python ai_backend/main.py` | `http://127.0.0.1:8787` |

AI 服务是**本机旁挂**，不对外暴露。玩家电脑上跑两个进程，Godot 启动时自动尝试拉起 Python（`OS.create_process`），失败则进入 demo 模式。

---

## 二、状态模型：谁拥有什么

**唯一真源是 Godot 内存中的 `GameState`。** Python 服务**不保存**权威状态（它是无状态的），只在单次请求内接收所需上下文。这样存档、回放、调试都只有一处。

```
GameState
├── calendar      { day, season, phase }
├── karez         { sections, channels, reservoir_level, flow_bonus }
├── resources
│   ├── water     { current, capacity, flow_per_day }
│   ├── food      { naan, grain, fruit, meat, milk }   ← 单位：份
│   ├── materials { wood, earth, cloth, tools }        ← 单位：单位
│   └── silver    (货币，单位：两)
├── population    { current, capacity, jobs{} }
├── buildings     [ { id, type, level, condition } ]
├── stats         { prosperity, reputation, morale, security }
├── characters    { id → { affinity, mood, memory[], flags{} } }
├── flags         { 任意剧情标记 }
└── seed          (随机数种子，用于复现)
```

**AI 服务收到的上下文 = 上述状态的"摘要视图"**，由 Godot 侧组装，不整包发送（省 token、防泄露、防模型乱改）。

---

## 三、接口协议

### 3.1 `GET /health`

```json
{
  "status": "ok",
  "mode": "live",
  "model": "实际使用的模型 ID",
  "has_key": true,
  "version": "0.1.0"
}
```
`mode` 为 `live`（可调 API）或 `demo`（无 Key / 无网络，走预设内容）。

---

### 3.2 `POST /narrate` —— 通用叙事与判定

**这是 M1 唯一要实现的接口。** 对话、事件生成、结算叙述都走它。

请求：
```json
{
  "schema_version": "1.0",
  "scene": "karez_work",
  "player_input": "我让老坎匠先看看第三口竖井",
  "context": {
    "day": 3,
    "season": "spring",
    "resources": { "water": 120, "water_capacity": 300, "silver": 30,
                   "food": { "naan": 20, "grain": 15, "fruit": 0, "meat": 5, "milk": 0 } },
    "karez": { "sections": 1, "flow_per_day": 55 },
    "stats": { "prosperity": 5, "reputation": 10, "morale": 60, "security": 40 }
  },
  "speaker": { "id": "lao_kanjiang", "name": "老坎匠" },
  "memory": ["第2天 玩家答应给他找好木料修井架，尚未兑现"],
  "recent": ["玩家：先看看第三口竖井", "老坎匠：这井壁的土松了。"]
}
```

响应：
```json
{
  "schema_version": "1.0",
  "narration": "老坎匠蹲在井口，捻起一把土在指间搓开……",
  "speaker": "lao_kanjiang",
  "state_delta": [
    { "op": "add", "path": "resources.water.current", "value": -20 },
    { "op": "set", "path": "karez.flow_bonus", "value": 5 }
  ],
  "memory_append": ["第3天 玩家同意先加固第三口竖井"],
  "suggestions": ["继续下挖", "先加固井壁", "问他暗渠走向"],
  "tokens": { "in": 1420, "out": 210 }
}
```

**校验规则（服务端与客户端都要做）：**
- `state_delta` 的 `op` 只允许 `add` / `sub` / `set` / `mul`
- `path` 只允许白名单前缀：`resources.`、`karez.`、`population.`、`stats.`、`flags.`、`characters.`
- 数值必须有限（拒绝 `NaN` / `Infinity`）、且单次变更幅度受夹紧（见下）
- 客户端应用 delta 时**必须再夹紧一次**（服务端可能被模型绕过）

---

### 3.3 `POST /event/generate` —— 事件生成（S5 才需要）

请求携带事件触发场景与可用事件模板 id，服务端返回从模板派生出的具体事件（含文案与选项）。
**M1–S4 阶段用不到**，事件直接用 `data/events.core.json` 里的静态内容。

### 3.4 `POST /battle/decide` —— 敌方 AI 指挥（S6 才需要）

请求携带战场快照与玩家最近 3 回合行为，返回敌方意图数组。同样是"意图"而非数值。

---

## 四、AI 输出安全的三道闸门

模型输出不可信，必须逐层过滤：

| 闸门 | 位置 | 作用 |
|---|---|---|
| 1. schema 校验 | Python 服务 | 字段缺失/类型错误 → 重试一次 → 仍失败则返回兜底内容 |
| 2. delta 白名单 | Python 服务 | 拒绝越权路径与超幅度变更 |
| 3. 客户端夹紧 | Godot | 二次校验，任何异常值裁剪到合法区间 |

**降级策略（务必实现）：**
`live 失败 → 重试 1 次 → demo 内容 → 游戏继续`。演示时哪怕断网，玩家看到的只是"今天角色话少了一点"，而不是崩溃。

---

## 五、DeepSeek 接口事实（2026-10-05 核查）

> 来源：`api-docs.deepseek.com` 各页实抓。**未经线上实测**（核查时环境无 API Key），首次接入时请用 `/health` 复核。

### 5.1 模型 ID —— GDD 写对了

| 模型 ID | 实际指向 | 用途（对应 GDD 5.1） | 并发上限 |
|---|---|---|---|
| `deepseek-flash` | DeepSeek-V4.1-Flash | 日常对话、事件、批量短内容 | 2500 |
| `deepseek-v4-pro` | DeepSeek-V4-Pro-0813 | 关键剧情、复杂多角色博弈 | 500 |

- **已停用（勿用）**：`deepseek-chat`、`deepseek-reasoner`（2026-07-24 起下线）
- **兼容旧名（勿用新代码）**：`deepseek-v4-flash`、`deepseek-v4-flash-vision-exp`（路由到 V4.1-Flash 并按 Flash 计费）
- ⚠️ 官方一处自相矛盾：2026-09-10 新闻稿称"正在淘汰 V4-Pro"，同日 Change Log 又称"应需求继续提供、计费不变"，价格页仍单列。**本项目默认走 `deepseek-flash`**，`deepseek-v4-pro` 仅作关键节点的可选升级，不做默认。

### 5.2 ⚠️ 最大的坑：思考模式默认开启

`thinking.type` **默认 `enabled`**，且默认 effort 为 `high`。对游戏对话这是灾难——**思考 token 计入 `max_tokens`**，而上限不足时表现为 **HTTP 200 但 `content` 为空 / `finish_reason="length"`**。本项目明确要求：

```python
# 游戏对话一律关闭思考模式：快、便宜、输出可控
extra_body={"thinking": {"type": "disabled"}}
```

连带影响（关闭后即可回避）：
- 思考模式下 `temperature` / `presence_penalty` / `frequency_penalty` **无效**（不报错但被忽略）
- `top_p` 仅在思考模式生效且被钳到 0.95–1.0
- 带 `tools` 时必须完整回传历史 `reasoning_content`，否则 400
- 思考内容在 `message.reasoning_content`，非 `content`

### 5.3 端点与其他事实

| 项 | 值 |
|---|---|
| OpenAI 兼容 base_url | `https://api.deepseek.com`（**文档未提及 `/v1` 后缀**） |
| 端点 | `POST /chat/completions` |
| Beta（strict 模式必需） | `https://api.deepseek.com/beta` |
| 上下文长度 | 1M |
| 最大输出 | 384K（`max_tokens` 合法区间 1–393216） |
| 默认输出上限 | 非思考 **8K** / 思考 64K / `reasoning_effort="max"` 时 128K |
| JSON 输出 | 支持，但**提示词里必须出现 "json" 字样并给格式示例** |
| 流式 | 支持，`data: [DONE]` 结束；`stream_options.include_usage` 必须与 `stream:true` 同用否则 400 |
| 上下文缓存 | **默认开启，无需改代码**；按 cache prefix unit 完全匹配才命中；`usage.prompt_cache_hit_tokens` 可查 |
| 限流 | 超并发返回 HTTP 429 |
| strict 模式 | 需 Beta base_url + 每个 function 设 `strict:true`；schema 限制：所有属性必须列入 `required`、`additionalProperties:false`，**不支持** minLength/maxLength/minItems/maxItems |

### 5.4 成本与延迟预算

| 项 | 设计目标 | 手段 |
|---|---|---|
| 单次对话延迟 | < 3 秒感知 | **关闭思考模式** + 流式输出 + 打字机效果；超 3 秒显示"正在思考"插话 |
| 单局（20 分钟）API 费用 | < 0.5 元 | 上下文缓存（固定前缀放前部）+ 批量生成 |
| 并发 | 单机不需要 | 串行请求即可 |

**人民币单价（高峰价，空闲时段为半价）** —— 高峰 = 北京时间周一至周五 9:00–12:00、14:00–18:00（不含法定节假日）：

| 模型 | 输入·缓存命中 | 输入·未命中 | 输出 |
|---|---|---|---|
| `deepseek-flash` | 0.04 元 / 1M | 2 元 / 1M | 8 元 / 1M |
| `deepseek-v4-pro` | 0.30 元 / 1M | 9 元 / 1M | 27 元 / 1M |

按此单价估算：单次对话若输入 1.5K token（其中多数命中缓存）、输出 300 token，`deepseek-flash` 成本约 **0.004 元**。GDD 里"单局 0.2–0.5 元"的估计**偏保守，实际会更低**——因为绝大部分输入是缓存命中的角色卡与设定。

**省钱的三个具体做法：**
1. **system prompt + 角色卡放最前面**，逐字不变以命中上下文缓存（缓存命中价是未命中的 1/50）。
2. **批量短内容合并成一次调用**：5 条路人评论 = 1 次请求输出 JSON 数组，而不是 5 次。
3. **事件预生成入队**：在玩家走路/过场时后台生成下一批事件，而不是等到需要时现调。

### 5.5 免费额度

官方文档**未明确**新用户赠送额度（价格页仅提及"赠送余额"存在，FAQ 页为 JS 渲染抓不到正文）。不要预设免费额度，按需充值。

---

## 六、存档格式

单文件 JSON，含 `seed`。**存档必须能完整复现**：同一 seed + 同一操作序列 = 同一结果（AI 输出也需记录进存档，重放时读记录而非重调 API）。

```
saves/slot_1.json
{
  "save_version": 1,
  "seed": 123456789,
  "state": { ...GameState... },
  "ai_log": [ { "req_hash": "...", "response": {...} } ]   ← 保证复现
}
```

---

## 七、尚未决定、但需要在动 S4 前定的事

1. **记忆存储形态**：角色记忆放存档 JSON 里（简单，但长了会膨胀）还是用 SQLite（可查询，但增加依赖）。建议先 JSON，超过约 200 条再迁移。
2. **多角色同时在场时的调用策略**：串行逐个调用（慢但稳）还是单次调用让模型扮演多人（快但易串味）。建议 M4 先串行，实测后再优化。
3. **木卡姆等文化内容的呈现边界**：AI 会不会"编"出不存在的曲目或习俗。这需要文化审核人介入（见 `docs/01-scope-and-order.md`）。
