"""
《坎儿井》AI 旁挂服务（FastAPI）。

职责边界（很重要，别让服务长大）：
  ✅ 调 DeepSeek、拼 prompt、校验模型输出、维护调用统计
  ✅ 无 Key / 失败时降级为本地预设内容
  ❌ 不保存权威游戏状态（那是 Godot 的事）
  ❌ 不做精确数值计算（只校验和清洗模型给出的意图）

启动：
    <venv>\\Scripts\\python.exe ai_backend/main.py
或：
    uvicorn ai_backend.main:app --host 127.0.0.1 --port 8787

自检：
    GET  /health         服务与配置状态
    POST /narrate        核心：叙事 + 状态增量
    GET  /characters     角色列表
    GET  /stats          调用统计与成本估算
"""

from __future__ import annotations

import json
import os
import sys
import time
from pathlib import Path
from typing import Any

# --- Windows 控制台默认 GBK，输出 emoji/生僻字符会直接抛
#     UnicodeEncodeError 并让服务崩在启动阶段，这里强制 stdout/stderr 走 UTF-8。
if sys.platform == "win32":
    for _stream in (sys.stdout, sys.stderr):
        try:
            _stream.reconfigure(encoding="utf-8")  # type: ignore[union-attr]
        except Exception:
            pass

# --- 允许 `python ai_backend/main.py` 直接运行 -------------------------------
if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

try:
    from dotenv import load_dotenv

    load_dotenv(Path(__file__).resolve().parent / ".env")
except ImportError:  # pragma: no cover
    pass

from fastapi import FastAPI  # noqa: E402
from fastapi.responses import JSONResponse  # noqa: E402
from pydantic import BaseModel, Field  # noqa: E402

from ai_backend.ai import characters as charmod  # noqa: E402
from ai_backend.ai import demo  # noqa: E402
from ai_backend.ai.client import (  # noqa: E402
    AIConfig,
    DeepSeekClient,
    parse_json_content,
)
from ai_backend.ai.validate import validate_deltas  # noqa: E402

SERVICE_VERSION = "0.1.0"
SCHEMA_VERSION = "1.0"

app = FastAPI(title="坎儿井 AI 服务", version=SERVICE_VERSION)
client = DeepSeekClient(AIConfig.from_env())

# 极简统计（进程内，不落盘）。用于开发期看成本，演示期看延迟。
STATS: dict[str, Any] = {
    "calls": 0,
    "live_ok": 0,
    "live_fail": 0,
    "demo_fallbacks": 0,
    "dropped_deltas": 0,
    "tokens_in": 0,
    "tokens_out": 0,
    "cache_hit_tokens": 0,
}

# flash 高峰价（元/百万 token），用于粗略成本估算
PRICE_CNY_PER_MTOK = {
    "flash": {"miss": 2.0, "hit": 0.04, "out": 8.0},
    "pro": {"miss": 9.0, "hit": 0.30, "out": 27.0},
}


# ---------------------------------------------------------------------------
# 请求模型
# ---------------------------------------------------------------------------

class NarrateRequest(BaseModel):
    schema_version: str = SCHEMA_VERSION
    scene: str = "idle"
    player_input: str = Field(default="", max_length=500)
    character_id: str | None = None
    context: dict[str, Any] = Field(default_factory=dict)
    memory: list[str] = Field(default_factory=list)
    promises: list[str] = Field(default_factory=list)
    recent: list[str] = Field(default_factory=list)
    use_pro: bool = False


# ---------------------------------------------------------------------------
# 路由
# ---------------------------------------------------------------------------

@app.get("/health")
def health() -> dict[str, Any]:
    info = client.health()
    return {
        "status": "ok",
        "service_version": SERVICE_VERSION,
        "schema_version": SCHEMA_VERSION,
        **info,
        "note": "" if info["mode"] == "live" else demo.demo_health_note(),
    }


@app.get("/characters")
def get_characters() -> dict[str, Any]:
    return {"characters": charmod.list_characters()}


@app.get("/stats")
def get_stats() -> dict[str, Any]:
    cfg = client.cfg
    price = PRICE_CNY_PER_MTOK["pro" if cfg.model_pro in cfg.model else "flash"]
    missed = max(0, STATS["tokens_in"] - STATS["cache_hit_tokens"])
    cost = (
        missed / 1_000_000 * price["miss"]
        + STATS["cache_hit_tokens"] / 1_000_000 * price["hit"]
        + STATS["tokens_out"] / 1_000_000 * price["out"]
    )
    return {
        **STATS,
        "estimated_cost_cny": round(cost, 4),
        "price_basis": "deepseek-flash 高峰价；空闲时段为半价",
        "note": "估算仅供参考，实际以平台账单为准",
    }


@app.post("/narrate")
def narrate(req: NarrateRequest) -> JSONResponse:
    """
    核心接口：玩家输入 → AI 叙事 + 状态增量。

    流程严格遵循 schema.json 的 validation_pipeline：
      prompt 拼装 → 调 API → 解析 JSON → 字段校验 → delta 白名单过滤
      → 任一步失败 → demo 兜底
    """
    t0 = time.perf_counter()
    STATS["calls"] += 1

    character_id = req.character_id
    system_prompt = charmod.build_system_prompt(character_id or "narrator")
    user_prompt = charmod.build_user_prompt(
        scene=req.scene,
        player_input=req.player_input,
        context=req.context,
        memory=req.memory,
        promises=req.promises,
        recent=req.recent,
    )

    result = client.chat_json_with_retry(
        system_prompt, user_prompt, use_pro=req.use_pro
    )

    if not result.ok:
        STATS["live_fail" if result.mode == "live" else "calls"] += 1
        STATS["demo_fallbacks"] += 1
        payload = demo.get_fallback(character_id, req.scene)
        payload["speaker"] = character_id
        payload["schema_version"] = SCHEMA_VERSION
        payload["meta"] = {
            **result.to_meta(),
            "mode": "demo",
            "reason": result.error or "api_unavailable",
            "latency_ms": round((time.perf_counter() - t0) * 1000, 1),
        }
        return JSONResponse(payload)

    # --- 解析 ---------------------------------------------------------------
    parsed, err = parse_json_content(result.content)
    if parsed is None:
        STATS["live_fail"] += 1
        STATS["demo_fallbacks"] += 1
        payload = demo.get_fallback(character_id, req.scene)
        payload["speaker"] = character_id
        payload["schema_version"] = SCHEMA_VERSION
        payload["meta"] = {
            **result.to_meta(),
            "mode": "demo",
            "reason": f"json_parse_failed: {err}",
        }
        return JSONResponse(payload)

    # --- 校验与清洗 ----------------------------------------------------------
    STATS["live_ok"] += 1
    STATS["tokens_in"] += result.tokens_in
    STATS["tokens_out"] += result.tokens_out
    STATS["cache_hit_tokens"] += result.cache_hit_tokens

    narration = str(parsed.get("narration") or "").strip()
    if not narration:
        STATS["demo_fallbacks"] += 1
        payload = demo.get_fallback(character_id, req.scene)
        payload["speaker"] = character_id
        payload["schema_version"] = SCHEMA_VERSION
        payload["meta"] = {**result.to_meta(), "mode": "demo", "reason": "empty_narration"}
        return JSONResponse(payload)

    clean_deltas, dropped = validate_deltas(parsed.get("state_delta"))
    STATS["dropped_deltas"] += len(dropped)

    memory_append = [
        str(m)[:120]
        for m in (parsed.get("memory_append") or [])
        if isinstance(m, (str, int, float))
    ][:3]

    suggestions = [
        str(s)[:24]
        for s in (parsed.get("suggestions") or [])
        if isinstance(s, (str, int, float))
    ][:3]

    emotion = str(parsed.get("emotion") or "").strip()

    response = {
        "schema_version": SCHEMA_VERSION,
        "narration": narration,
        "speaker": character_id,
        "emotion": emotion if emotion in charmod.EMOTIONS else "平静",
        "intent": parsed.get("intent") if isinstance(parsed.get("intent"), dict) else {},
        "state_delta": clean_deltas,
        "memory_append": memory_append,
        "suggestions": suggestions or demo.get_fallback(character_id, req.scene)["suggestions"],
        "meta": {
            **result.to_meta(),
            "mode": "live",
            "dropped_deltas": len(dropped),
            "retried": bool(result.raw.get("retried")),
            "elapsed_ms": round((time.perf_counter() - t0) * 1000, 1),
        },
    }

    if os.getenv("LOG_AI_CALLS", "1") == "1":
        _log_call(req, result, dropped, narration)

    return JSONResponse(response)


# ---------------------------------------------------------------------------
# 日志
# ---------------------------------------------------------------------------

def _log_call(
    req: NarrateRequest,
    result: Any,
    dropped: list[dict[str, Any]],
    narration: str,
) -> None:
    log_dir = Path(os.getenv("LOG_DIR", "logs"))
    log_dir.mkdir(parents=True, exist_ok=True)
    entry = {
        "ts": time.strftime("%Y-%m-%dT%H:%M:%S"),
        "scene": req.scene,
        "character": req.character_id,
        "player_input": req.player_input,
        "narration_preview": narration[:80],
        "model": result.model,
        "latency_ms": round(result.latency_ms, 1),
        "tokens_in": result.tokens_in,
        "tokens_out": result.tokens_out,
        "cache_hit_tokens": result.cache_hit_tokens,
        "finish_reason": result.finish_reason,
        "dropped_deltas": len(dropped),
    }
    with open(log_dir / "ai_calls.jsonl", "a", encoding="utf-8") as fh:
        fh.write(json.dumps(entry, ensure_ascii=False) + "\n")
    if dropped:
        with open(log_dir / "dropped_deltas.jsonl", "a", encoding="utf-8") as fh:
            fh.write(
                json.dumps({"ts": entry["ts"], "dropped": dropped}, ensure_ascii=False)
                + "\n"
            )


# ---------------------------------------------------------------------------
# 入口
# ---------------------------------------------------------------------------

def main() -> None:
    import uvicorn

    host = os.getenv("AI_HOST", "127.0.0.1")
    port = int(os.getenv("AI_PORT", "8787"))
    info = client.health()

    print("=" * 62)
    print("  《坎儿井》AI 旁挂服务")
    print("=" * 62)
    print(f"  模式      : {info['mode']}" + ("  ← 不会调用 API" if info["mode"] == "demo" else ""))
    print(f"  模型      : {info['model']}")
    print(f"  思考模式  : {info['thinking']}")
    print(f"  Base URL  : {info['base_url']}")
    print(f"  监听      : http://{host}:{port}")
    if info["mode"] == "demo":
        print()
        print("  [!]  当前为 demo 模式。若要接通真实 AI：")
        print("     1. 复制 ai_backend/.env.example 为 ai_backend/.env")
        print("     2. 填入 DEEPSEEK_API_KEY")
        print("     3. 确认 FORCE_DEMO=0")
    print("=" * 62)

    uvicorn.run(app, host=host, port=port, log_level="info")


if __name__ == "__main__":
    main()
