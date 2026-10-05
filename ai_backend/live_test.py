#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
真实 API 联调测试 —— 需要 ai_backend/.env 里配好可用的 DEEPSEEK_API_KEY。

与 smoke_test.py 的分工：
  smoke_test.py  不需要 Key、不联网，验证管道逻辑与兜底
  live_test.py   需要 Key、真的调 DeepSeek，验证「AI 角色是不是活的」

核心验证目标是 GDD 里那条判据：
  「关掉 AI 后这三人明显死掉」 —— 而最容易量化的一点就是
  「角色能不能记住上次答应过你什么」。

用法：
    .venv\\Scripts\\python.exe ai_backend\\live_test.py
    .venv\\Scripts\\python.exe ai_backend\\live_test.py --rounds-only   # 只跑对话，不做断言

⚠ 本脚本会把中文输出重配为 UTF-8，避免在中文 Windows 控制台崩溃。
"""

from __future__ import annotations

import argparse
import json
import sys
import urllib.error
import urllib.request
from pathlib import Path

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")
    sys.stderr.reconfigure(encoding="utf-8")

BASE = "http://127.0.0.1:8787"
TIMEOUT = 120


def post(path: str, payload: dict) -> dict:
    data = json.dumps(payload, ensure_ascii=False).encode("utf-8")
    req = urllib.request.Request(
        BASE + path, data=data,
        headers={"Content-Type": "application/json; charset=utf-8"},
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=TIMEOUT) as resp:
        return json.loads(resp.read().decode("utf-8"))


def get(path: str) -> dict:
    with urllib.request.urlopen(BASE + path, timeout=30) as resp:
        return json.loads(resp.read().decode("utf-8"))


# ---------------------------------------------------------------------------

CTX = {
    "day": 4,
    "season": "spring",
    "phase": "morning",
    "resources": {
        "water": 120, "water_capacity": 300, "silver": 45,
        "food": {"naan": 40, "grain": 30},
    },
    "karez": {"sections": 1, "flow_per_day": 60},
    "population": 6,
    "stats": {"prosperity": 8, "reputation": 11, "morale": 58, "security": 40},
}


def narrate(player_input: str, *, char="lao_kanjiang", memory=None,
            promises=None, recent=None) -> dict:
    return post("/narrate", {
        "schema_version": "1.0",
        "scene": "karez_work",
        "player_input": player_input,
        "character_id": char,
        "context": CTX,
        "memory": memory or [],
        "promises": promises or [],
        "recent": recent or [],
        "use_pro": False,
    })


def show(tag: str, r: dict) -> None:
    m = r.get("meta", {})
    print(f"  [{tag}] {m.get('latency_ms', 0):.0f}ms  "
          f"in/out {m.get('tokens_in', 0)}/{m.get('tokens_out', 0)}  "
          f"finish={m.get('finish_reason', '?')}  mode={m.get('mode', '?')}")
    print(f"    角色：{r.get('narration', '')}")
    print(f"    情绪 {r.get('emotion', '?')} / 意图 {r.get('intent', {}).get('type', '?')}")
    md = r.get("memory_append", [])
    print(f"    memory_append：{json.dumps(md, ensure_ascii=False) if md else '（空）'}")
    sd = r.get("state_delta", [])
    print(f"    state_delta：{json.dumps(sd, ensure_ascii=False) if sd else '（空）'}")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--rounds-only", action="store_true", help="只跑对话，不做断言")
    args = ap.parse_args()

    print("=" * 68)
    print("  《坎儿井》真实 API 联调测试")
    print("=" * 68)

    try:
        h = get("/health")
    except urllib.error.URLError as exc:
        print(f"\n  ✗ 连不上 AI 服务（{BASE}）：{exc}")
        print("    请先启动：.venv\\Scripts\\python.exe ai_backend\\main.py")
        return 1

    print(f"\n  /health -> mode={h['mode']}  model={h['model']}  has_key={h['has_key']}")
    if h["mode"] != "live":
        print("  ✗ 服务处于 demo 模式，本测试需要 live。请检查 ai_backend/.env 里的 Key 与 FORCE_DEMO=0")
        return 1

    fails = 0

    def check(cond: bool, label: str) -> None:
        nonlocal fails
        if cond:
            print(f"    [PASS] {label}")
        else:
            fails += 1
            print(f"    [FAIL] {label}")

    # ── 第 1 轮：玩家许下承诺 ──
    print("\n── 第 1 轮：玩家许下明确承诺 ──")
    promise_text = "等这季葡萄卖了钱，我一定给你换一套新的坎土曼，说话算话。"
    r1 = narrate(f"老坎匠，{promise_text}")
    show("承诺", r1)
    mem1 = r1.get("memory_append", [])

    # ── 第 2 轮：把承诺喂回去，看角色认不认 ──
    print("\n── 第 2 轮：带着承诺再问一次 ──")
    promise_entry = f"[第4天] 玩家承诺：{promise_text}"
    r2 = narrate(
        "我上次答应过你什么，你还记得吗？",
        memory=[promise_entry],
        promises=[promise_entry],
        recent=[f"玩家：{promise_text}"],
    )
    show("回忆", r2)
    n2 = r2.get("narration", "")

    if not args.rounds_only:
        print("\n── 断言 ──")
        check(r1.get("narration", "").strip() != "", "第 1 轮有叙事文本")
        check(r1.get("meta", {}).get("mode") == "live", "第 1 轮确实走了 live（不是兜底）")
        check(r1.get("meta", {}).get("finish_reason") == "stop",
              "第 1 轮 finish_reason=stop（没被 max_tokens 截断）")
        # 这是关键的一条：模型是否主动记账
        check(len(mem1) > 0,
              "AI 主动把承诺写进 memory_append（当前实现依赖模型自觉，实测常为空）")
        check(r2.get("narration", "").strip() != "", "第 2 轮有叙事文本")
        # 角色认出承诺：出现与「工具/坎土曼/承诺」相关的字眼
        cues = ("坎土曼", "工具", "答应", "说好", "承诺", "绸子", "记得")
        check(any(c in n2 for c in cues),
              "第 2 轮角色认出了承诺（回复里出现相关字眼）")
        # 数值纪律：不该编造数值
        for i, r in ((1, r1), (2, r2)):
            sd = r.get("state_delta", [])
            bad = [d for d in sd
                   if d.get("op") not in ("add", "sub", "set")
                   or abs(float(d.get("value", 0))) > 20]
            check(not bad, f"第 {i} 轮 state_delta 未越权（op 合法且幅度 <= 20）")

    print("\n" + "=" * 68)
    if args.rounds_only:
        print("  仅跑了对话轮次")
    elif fails == 0:
        print("  全部通过")
    else:
        print(f"  失败 {fails} 项")
    print("=" * 68)
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())
