"""
DeepSeek 调用封装（直连 HTTP，不走 SDK）。

设计要点（全部来自 2026-10-05 官方文档核查）：
  1. base_url = https://api.deepseek.com，端点 POST /chat/completions，
     官方文档未提及 /v1 后缀，所以这里不拼 /v1。
  2. ⚠️ 思考模式默认开启（thinking.type = enabled，effort = high）。
     游戏对话必须显式关闭，否则：思考 token 计入 max_tokens，
     上限不足时表现为「HTTP 200 但 content 为空 / finish_reason=length」。
     本模块默认 disabled。
  3. JSON 模式要求提示词里出现 "json" 字样并给格式示例 —— 见 prompts.py。
  4. 上下文缓存默认开启、无需配置。把逐字不变的前缀（世界观+契约+角色卡）
     放最前面即可命中，命中价是未命中价的 1/50。
  5. 非流式请求可能持续返回空行；流式返回 ": keep-alive" 注释。都要容忍。
"""

from __future__ import annotations

import json
import os
import time
from dataclasses import dataclass, field
from typing import Any

import httpx


# ----------------------------------------------------------------------------
# 配置
# ----------------------------------------------------------------------------

@dataclass
class AIConfig:
    api_key: str = ""
    model: str = "deepseek-flash"
    model_pro: str = "deepseek-v4-pro"
    base_url: str = "https://api.deepseek.com"
    thinking: str = "disabled"          # disabled | enabled
    max_tokens: int = 2048
    temperature: float = 1.0
    timeout: float = 60.0
    force_demo: bool = False

    @classmethod
    def from_env(cls) -> "AIConfig":
        return cls(
            api_key=os.getenv("DEEPSEEK_API_KEY", "").strip(),
            model=os.getenv("DEEPSEEK_MODEL", "deepseek-flash").strip(),
            model_pro=os.getenv("DEEPSEEK_MODEL_PRO", "deepseek-v4-pro").strip(),
            base_url=os.getenv("DEEPSEEK_BASE_URL", "https://api.deepseek.com").strip().rstrip("/"),
            thinking=os.getenv("DEEPSEEK_THINKING", "disabled").strip().lower(),
            max_tokens=int(os.getenv("DEEPSEEK_MAX_TOKENS", "2048")),
            temperature=float(os.getenv("DEEPSEEK_TEMPERATURE", "1.0")),
            timeout=float(os.getenv("DEEPSEEK_TIMEOUT", "60")),
            force_demo=os.getenv("FORCE_DEMO", "0").strip() in ("1", "true", "yes"),
        )

    @property
    def has_key(self) -> bool:
        return bool(self.api_key) and self.api_key.startswith("sk-") is not False

    @property
    def is_live(self) -> bool:
        """能否真正调 API。"""
        return self.has_key and not self.force_demo


# ----------------------------------------------------------------------------
# 结果容器
# ----------------------------------------------------------------------------

@dataclass
class AIResult:
    ok: bool
    content: str = ""
    mode: str = "demo"                  # live | demo
    model: str = ""
    latency_ms: float = 0.0
    tokens_in: int = 0
    tokens_out: int = 0
    cache_hit_tokens: int = 0
    finish_reason: str = ""
    error: str = ""
    reasoning: str = ""
    raw: dict[str, Any] = field(default_factory=dict)

    def to_meta(self) -> dict[str, Any]:
        return {
            "mode": self.mode,
            "model": self.model,
            "latency_ms": round(self.latency_ms, 1),
            "tokens_in": self.tokens_in,
            "tokens_out": self.tokens_out,
            "cache_hit_tokens": self.cache_hit_tokens,
            "finish_reason": self.finish_reason,
            "error": self.error,
        }


# ----------------------------------------------------------------------------
# 客户端
# ----------------------------------------------------------------------------

class DeepSeekClient:
    """同步客户端。游戏是单机串行请求，不需要 async。"""

    def __init__(self, config: AIConfig | None = None) -> None:
        self.cfg = config or AIConfig.from_env()
        self._client: httpx.Client | None = None

    # -- 生命周期 ------------------------------------------------------------

    def _get_client(self) -> httpx.Client:
        if self._client is None:
            self._client = httpx.Client(
                base_url=self.cfg.base_url,
                timeout=httpx.Timeout(self.cfg.timeout, connect=15.0),
                headers={
                    "Authorization": f"Bearer {self.cfg.api_key}",
                    "Content-Type": "application/json",
                },
            )
        return self._client

    def close(self) -> None:
        if self._client is not None:
            self._client.close()
            self._client = None

    def health(self) -> dict[str, Any]:
        return {
            "has_key": self.cfg.has_key,
            "force_demo": self.cfg.force_demo,
            "mode": "live" if self.cfg.is_live else "demo",
            "model": self.cfg.model,
            "model_pro": self.cfg.model_pro,
            "base_url": self.cfg.base_url,
            "thinking": self.cfg.thinking,
            "max_tokens": self.cfg.max_tokens,
        }

    # -- 核心调用 ------------------------------------------------------------

    def chat_json(
        self,
        system_prompt: str,
        user_prompt: str,
        *,
        use_pro: bool = False,
        max_tokens: int | None = None,
        retry_hint: str = "",
    ) -> AIResult:
        """
        请求 JSON 输出。返回 AIResult，失败不抛异常（由调用方走 demo 兜底）。

        参数 use_pro: 关键剧情节点可切到 deepseek-v4-pro。
        """
        if not self.cfg.is_live:
            return AIResult(ok=False, mode="demo", error="no_api_key_or_forced_demo")

        model = self.cfg.model_pro if use_pro else self.cfg.model
        payload: dict[str, Any] = {
            "model": model,
            "messages": [
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": user_prompt + retry_hint},
            ],
            "response_format": {"type": "json_object"},
            "max_tokens": max_tokens or self.cfg.max_tokens,
            "stream": False,
        }

        # 思考模式：disabled 时不传该字段（官方默认 enabled，必须显式关闭）
        if self.cfg.thinking == "disabled":
            payload["thinking"] = {"type": "disabled"}
        else:
            payload["thinking"] = {"type": "enabled"}

        # temperature 仅在思考模式关闭时有效；开启时官方会忽略（不报错）
        if self.cfg.thinking == "disabled":
            payload["temperature"] = self.cfg.temperature

        started = time.perf_counter()
        try:
            resp = self._get_client().post("/chat/completions", json=payload)
            latency = (time.perf_counter() - started) * 1000

            if resp.status_code != 200:
                return AIResult(
                    ok=False, mode="live", model=model, latency_ms=latency,
                    error=f"HTTP {resp.status_code}: {resp.text[:300]}",
                )

            data = resp.json()
            choice = (data.get("choices") or [{}])[0]
            message = choice.get("message") or {}
            content = (message.get("content") or "").strip()
            reasoning = (message.get("reasoning_content") or "").strip()
            finish = choice.get("finish_reason") or ""
            usage = data.get("usage") or {}

            # 已知坑：思考模式 + max_tokens 不足 → 200 但 content 为空
            if not content:
                hint = ""
                if finish == "length":
                    hint = (
                        f"（finish_reason=length，输出被截断。"
                        f"reasoning_content 长度={len(reasoning)}，"
                        f"说明思考 token 吃掉了额度。请确认 DEEPSEEK_THINKING=disabled "
                        f"或调高 DEEPSEEK_MAX_TOKENS）"
                    )
                else:
                    hint = "（官方承认 JSON 模式偶发返回空 content，重试通常可解）"
                return AIResult(
                    ok=False, mode="live", model=model, latency_ms=latency,
                    finish_reason=finish, reasoning=reasoning,
                    tokens_in=usage.get("prompt_tokens", 0),
                    tokens_out=usage.get("completion_tokens", 0),
                    error=f"empty_content{hint}",
                )

            return AIResult(
                ok=True, content=content, mode="live", model=model,
                latency_ms=latency, finish_reason=finish, reasoning=reasoning,
                tokens_in=usage.get("prompt_tokens", 0),
                tokens_out=usage.get("completion_tokens", 0),
                cache_hit_tokens=usage.get("prompt_cache_hit_tokens", 0),
            )

        except httpx.TimeoutException:
            return AIResult(
                ok=False, mode="live", model=model,
                latency_ms=(time.perf_counter() - started) * 1000,
                error=f"timeout after {self.cfg.timeout}s",
            )
        except httpx.HTTPError as exc:
            return AIResult(
                ok=False, mode="live", model=model,
                latency_ms=(time.perf_counter() - started) * 1000,
                error=f"network: {type(exc).__name__}: {exc}",
            )
        except (ValueError, KeyError) as exc:
            return AIResult(
                ok=False, mode="live", model=model,
                latency_ms=(time.perf_counter() - started) * 1000,
                error=f"malformed_response: {type(exc).__name__}: {exc}",
            )

    def chat_json_with_retry(
        self, system_prompt: str, user_prompt: str, *, use_pro: bool = False
    ) -> AIResult:
        """按 schema.json 的 validation_pipeline：失败重试一次，加更强的格式提示。"""
        first = self.chat_json(system_prompt, user_prompt, use_pro=use_pro)
        if first.ok:
            return first

        if not self.cfg.is_live:
            return first

        retry_hint = (
            "\n\n【重要】上一次的回复无法解析。请只输出一个合法的 json 对象，"
            "不要有任何其他文字，不要用 ``` 包裹。"
        )
        second = self.chat_json(
            system_prompt, user_prompt, use_pro=use_pro, retry_hint=retry_hint
        )
        for attr in ("tokens_in", "tokens_out", "cache_hit_tokens"):
            setattr(second, attr, getattr(second, attr) + getattr(first, attr))
        second.raw["retried"] = True
        return second


def parse_json_content(content: str) -> tuple[dict[str, Any] | None, str]:
    """
    容错解析模型返回的 JSON。
    返回 (解析结果, 错误信息)。模型偶尔会裹 ```json 或加前后缀，这里都剥掉。
    """
    text = (content or "").strip()
    if not text:
        return None, "empty content"

    if text.startswith("```"):
        lines = text.splitlines()
        lines = [ln for ln in lines if not ln.strip().startswith("```")]
        text = "\n".join(lines).strip()

    try:
        parsed = json.loads(text)
    except json.JSONDecodeError:
        start, end = text.find("{"), text.rfind("}")
        if start == -1 or end <= start:
            return None, "no json object found"
        try:
            parsed = json.loads(text[start : end + 1])
        except json.JSONDecodeError as exc:
            return None, f"json decode failed: {exc}"

    if not isinstance(parsed, dict):
        return None, f"expected json object, got {type(parsed).__name__}"
    return parsed, ""
