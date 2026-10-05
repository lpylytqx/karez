"""
state_delta 的白名单校验与夹紧。

这是防模型幻觉的关键闸门。模型永远可能输出越权路径或荒谬数值，
这里逐条筛掉，保留合法部分——不因为一条坏 delta 丢掉整段叙事。

对应 ai_backend/schema.json 的 delta_whitelist。
"""

from __future__ import annotations

import re
from typing import Any

ALLOWED_OPS = {"add", "sub", "set", "mul"}

ALLOWED_PREFIXES = (
    "resources.silver",
    "resources.food.",
    "resources.materials.",
    "resources.water.current",
    "karez.flow_bonus",
    "karez.reservoir_level",
    "stats.reputation",
    "stats.morale",
    "stats.security",
)

# characters.<id>.affinity / .mood
CHARACTER_PATH_RE = re.compile(r"^characters\.[A-Za-z0-9_\-]+\.(affinity|mood)$")

MAX_ABS_VALUE = 25.0
MAX_ITEMS = 8

# 夹紧区间。值是 (min, max)。
#
# ⚠️ 一个必须知道的边界：water.current 的真正上限是「涝坝容量 + 明渠蓄水」，
#    这个值随建筑等级变化，只存在于 Godot 的状态里，Python 服务拿不到。
#    所以这里用哨兵上限（一个远大于任何合理容量的数），只挡住荒谬值；
#    **真正的容量夹紧必须在客户端做**（见 schema.json 的 validation_pipeline 第 5 步）。
#    现状：容量上限可能被短暂突破，由客户端下一帧夹回。这是可接受的折中，
#    但如果你希望更严格，就在 /narrate 请求里带上 water_capacity，服务端据此夹紧。
CLAMP_RANGES: dict[str, tuple[float, float]] = {
    "resources.water.current": (0.0, 999_999.0),   # 哨兵值，非真实容量
    "resources.silver": (0.0, 999_999.0),
    "stats.reputation": (0.0, 100.0),
    "stats.morale": (0.0, 100.0),
    "stats.security": (0.0, 100.0),
}

_DELTA_RE = re.compile(r"^[a-z]+\.[a-zA-Z0-9_.\-]*$")


def _path_allowed(path: str) -> bool:
    if not path or not _DELTA_RE.match(path):
        return False
    if path.startswith(ALLOWED_PREFIXES):
        return True
    return bool(CHARACTER_PATH_RE.match(path))


def _clamp_key(path: str) -> str | None:
    """找到该路径适用的夹紧键（支持通配）。"""
    if path in CLAMP_RANGES:
        return path
    if CHARACTER_PATH_RE.match(path):
        return "characters.*.affinity" if path.endswith(".affinity") else "characters.*.mood"
    return None


def _clamp_value(path: str, value: float) -> float:
    key = _clamp_key(path)
    if key is None:
        return value
    if key == "characters.*.affinity":
        return max(-100.0, min(100.0, value))
    if key == "characters.*.mood":
        return max(0.0, min(100.0, value))
    if key in CLAMP_RANGES:
        lo, hi = CLAMP_RANGES[key]
        value = max(lo, min(hi, value))
    return value


def validate_deltas(raw: Any) -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    """
    校验并清洗 state_delta。

    返回 (干净的 delta 列表, 被丢弃的记录列表)。
    丢弃记录用于日志与调试——单人项目里这是找 bug 的救生索。
    """
    if not isinstance(raw, list):
        return [], ([{"reason": "state_delta 不是数组", "item": raw}] if raw else [])

    clean: list[dict[str, Any]] = []
    dropped: list[dict[str, Any]] = []

    for item in raw[: MAX_ITEMS * 2]:  # 先截断，防模型狂刷
        if len(clean) >= MAX_ITEMS:
            dropped.append({"reason": f"超过单次上限 {MAX_ITEMS} 条", "item": item})
            continue

        if not isinstance(item, dict):
            dropped.append({"reason": "不是对象", "item": item})
            continue

        op = item.get("op")
        path = item.get("path")
        value = item.get("value")

        if op not in ALLOWED_OPS:
            dropped.append({"reason": f"非法 op: {op!r}", "item": item})
            continue

        if not isinstance(path, str) or not _path_allowed(path):
            dropped.append({"reason": f"路径不在白名单: {path!r}", "item": item})
            continue

        # set/mul 必须带值；add/sub 也必须有数值
        if not isinstance(value, (int, float)) or isinstance(value, bool):
            dropped.append({"reason": f"value 不是有限数值: {value!r}", "item": item})
            continue

        value = float(value)
        if value != value or value in (float("inf"), float("-inf")):  # NaN / Inf
            dropped.append({"reason": "value 为 NaN 或 Inf", "item": item})
            continue

        # 超幅度：截断而非丢弃（保留模型表达的意图强度）
        clamped_magnitude = max(-MAX_ABS_VALUE, min(MAX_ABS_VALUE, value))
        if clamped_magnitude != value:
            dropped.append(
                {
                    "reason": f"幅度 {value} 超上限 {MAX_ABS_VALUE}，已截断",
                    "item": item,
                    "clamped_to": clamped_magnitude,
                }
            )
            value = clamped_magnitude

        # 对 set 操作额外夹紧到合法区间
        if op == "set":
            value = _clamp_value(path, value)

        clean.append({"op": op, "path": path, "value": value})

    return clean, dropped


def apply_deltas(state: dict[str, Any], deltas: list[dict[str, Any]]) -> dict[str, Any]:
    """
    把 delta 应用到状态字典（仅用于服务端自测与日志预览）。

    ⚠️ 权威状态在 Godot 侧。这个函数存在的意义是：
    服务端能在返回前验证"这批 delta 应用后会不会把状态搞坏"，
    以及在没有 Godot 的情况下用命令行跑通闭环。
    """
    for d in deltas:
        op, path, value = d["op"], d["path"], d["value"]
        cursor: Any = state
        parts = path.split(".")
        for part in parts[:-1]:
            if not isinstance(cursor, dict):
                break
            cursor = cursor.setdefault(part, {})
        else:
            leaf = parts[-1]
            if not isinstance(cursor, dict):
                continue
            if op == "set":
                cursor[leaf] = value
            else:
                current = cursor.get(leaf, 0)
                if not isinstance(current, (int, float)) or isinstance(current, bool):
                    current = 0
                if op == "add":
                    cursor[leaf] = current + value
                elif op == "sub":
                    cursor[leaf] = current - value
                elif op == "mul":
                    cursor[leaf] = current * value
            if isinstance(cursor.get(leaf), (int, float)) and not isinstance(
                cursor.get(leaf), bool
            ):
                cursor[leaf] = _clamp_value(path, float(cursor[leaf]))
    return state
