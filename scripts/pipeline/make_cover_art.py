#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""出《坎儿井》游戏封面用的关键插画（本地 ComfyUI + SDXL）。

分工（这条规矩在项目里已经定死了）：
  · **画面**交给本地 SDXL —— 要的是手绘感、不受像素网格约束
  · **中文标题**用真字体排版 —— 绝不让扩散模型写字（写出来必然是错字或鬼画符）

所以这个脚本只出"不带文字"的底图，标题由 make_game_cover.py 用 PIL 叠上去。

比例按出图路由规则：16:9 无文字配图 → 本地 SDXL 宽屏 1344x768。

用法：.venv\\Scripts\\python.exe scripts\\pipeline\\make_cover_art.py [张数]
"""
from __future__ import annotations

import sys as _sys
from pathlib import Path as _Path
_sys.path.insert(0, str(_Path(__file__).resolve().parent))
from _root import ROOT  # 路径唯一解析处，不再写死盘符
import json
import random
import sys
import time
import urllib.request
from pathlib import Path

HOST = "http://127.0.0.1:8188"
OUT = Path(str(ROOT / "dsh-image-gen/cover"))
W, H = 1344, 768

POSITIVE = (
    "cinematic wide key art of a Turpan karez oasis village at golden hour, "
    "ancient mud-brick houses with flat roofs clustered around a circular stone "
    "irrigation pool reflecting a warm sky, rows of tall narrow Xinjiang poplars, "
    "grape trellises heavy with fruit, irrigation channels crossing the sand, "
    "snow-capped Tianshan mountains far on the horizon, dramatic layered clouds, "
    "warm ochre amber and terracotta palette with deep teal shadow accents, "
    "painterly digital illustration, rich texture, epic establishing shot, "
    "highly detailed, no text, no letters, no watermark, no signature"
)
NEGATIVE = (
    "text, letters, words, watermark, signature, logo, ui, frame, border, "
    "blurry, lowres, jpeg artifacts, deformed, extra limbs, people, faces, "
    "modern buildings, cars, power lines, cartoon outline, flat colors"
)


def workflow(seed: int) -> dict:
    return {
        "3": {"class_type": "KSampler", "inputs": {
            "seed": seed, "steps": 28, "cfg": 7.0, "sampler_name": "dpmpp_2m",
            "scheduler": "karras", "denoise": 1.0, "model": ["4", 0],
            "positive": ["6", 0], "negative": ["7", 0], "latent_image": ["5", 0]}},
        "4": {"class_type": "CheckpointLoaderSimple",
              "inputs": {"ckpt_name": "sd_xl_base_1.0.safetensors"}},
        "5": {"class_type": "EmptyLatentImage",
              "inputs": {"width": W, "height": H, "batch_size": 1}},
        "6": {"class_type": "CLIPTextEncode",
              "inputs": {"text": POSITIVE, "clip": ["4", 1]}},
        "7": {"class_type": "CLIPTextEncode",
              "inputs": {"text": NEGATIVE, "clip": ["4", 1]}},
        "8": {"class_type": "VAEDecode",
              "inputs": {"samples": ["3", 0], "vae": ["4", 2]}},
        "9": {"class_type": "SaveImage",
              "inputs": {"filename_prefix": "dsh_cover", "images": ["8", 0]}},
    }


def post(path: str, payload: dict) -> dict:
    req = urllib.request.Request(
        HOST + path, data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json"})
    return json.loads(urllib.request.urlopen(req, timeout=30).read())


def get(path: str) -> dict:
    return json.loads(urllib.request.urlopen(HOST + path, timeout=30).read())


def main() -> None:
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 3
    OUT.mkdir(parents=True, exist_ok=True)
    for i in range(n):
        seed = random.randint(1, 2 ** 31)
        pid = post("/prompt", {"prompt": workflow(seed)})["prompt_id"]
        print("  [%d/%d] 出图中 seed=%d …" % (i + 1, n, seed))
        t0 = time.time()
        while True:
            h = get("/history/%s" % pid)
            if pid in h:
                break
            if time.time() - t0 > 600:
                raise SystemExit("  超时")
            time.sleep(3)
        imgs = h[pid]["outputs"]["9"]["images"]
        src = Path(r"D:\ComfyUI\output") / imgs[0]["filename"]
        dst = OUT / ("cover_art_%02d.png" % (i + 1))
        dst.write_bytes(src.read_bytes())
        print("      -> %s  (%.0f 秒)" % (dst.name, time.time() - t0))
    print("  完成 %d 张，目录 %s" % (n, OUT))


if __name__ == "__main__":
    main()
