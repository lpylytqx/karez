#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""用本地 ComfyUI + SDXL 生成 6 张「灾难过场插画」，裁成事件卡的 150x200。

为什么是灾难插画，而不是地图贴图：
  地图贴图要的是 16px 网格精确、34 色板精确、形状可控 —— 这三件过程化生成完胜，
  试过 SDXL + 最近邻降采样，细节在贴图尺寸下会塌成一团颜色涂抹（见 make_reservoir.py）。
  但**过场插画反过来**：它不受像素网格约束、要的就是手绘感、显示尺寸也够大。
  这正是扩散模型擅长的位置。和事件卡插画（150x200）是同一个道理。

用法（需要 ComfyUI 在 127.0.0.1:8188 上跑着）：
    .venv\\Scripts\\python.exe scripts\\pipeline\\make_disaster_art.py
输出：assets/events/disaster_{sandstorm,drought,flood,cold,plague,locust}.png
      原始大图留档在 dsh-image-gen/disaster/（不降色 —— 插画刻意不走 34 色板）
"""
from __future__ import annotations

import json
import shutil
import time
import urllib.request
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
RAW = ROOT / "dsh-image-gen" / "disaster"
OUT = ROOT / "assets" / "events"
COMFY_OUT = Path(r"D:\ComfyUI\output")
HOST = "http://127.0.0.1:8188"

CARD_W, CARD_H = 150, 200       # 与事件卡一致；改这里要同步 hud.gd 的 EVENT_ART_W/H
GEN_W, GEN_H = 768, 1024        # 3:4，和卡片同比例，裁切时损失最小
TRIM_BOTTOM = 0.05              # 扩散模型爱在右下角留一个小标记，裁掉最省事

# 风格串统一：暖色、手绘、干燥的西域色调，和已有的 6 张事件插画同一路。
STYLE = ("painterly digital illustration, Central Asian / Xinjiang oasis village, "
         "warm ochre amber and dusty palette, cinematic light, textured brushwork, "
         "no text, no watermark, no signature")

SCENES = [
    ("sandstorm", "A towering wall of yellow-brown sandstorm rolling over a small mud-brick "
                  "desert village, poplar trees bending sideways, dust devils, distant figures "
                  "covering their faces with cloth, ominous sky"),
    ("drought", "Cracked parched earth, an almost empty stone irrigation pool, wilted grape "
                "vines, a lone old man staring into a dry underground canal well, harsh orange "
                "summer haze, heat shimmer"),
    ("flood", "Meltwater flood rushing through a desert oasis village, muddy brown water "
              "crossing an earthen irrigation channel, people carrying bundles on a raised path, "
              "overcast blue-grey light, snow-capped mountains behind"),
    # ⚠ key 必须与 numbers.json 里 disasters.list 的 **id** 一致 ——
    #   代码是按 `disaster_<id>` 取图的，叫 cold 就会取不到（id 是 cold_snap）。
    ("cold_snap", "A frozen winter night in a desert oasis village, thick ice on the irrigation "
                  "pool, snow on round felt tents and a watchtower, deep blue moonlight, sheep "
                  "huddled together in a pen"),
    ("plague", "A silent stricken village at dusk, doors shut, a small smoking bundle of herbs "
               "burning at a doorway, one lonely figure walking down the empty lane, muted green "
               "and grey palette, uneasy stillness"),
    ("locust", "A vast swarm of locusts darkening the sky above a millet field in a desert "
               "oasis, silhouetted farmers waving cloth, yellow-brown dust haze, sun blotted out"),
]


def workflow(ckpt: str, prompt: str, negative: str, seed: int) -> dict:
    return {
        "1": {"class_type": "CheckpointLoaderSimple", "inputs": {"ckpt_name": ckpt}},
        "2": {"class_type": "CLIPTextEncode",
              "inputs": {"text": prompt, "clip": ["1", 1]}},
        "3": {"class_type": "CLIPTextEncode",
              "inputs": {"text": negative, "clip": ["1", 1]}},
        "4": {"class_type": "EmptyLatentImage",
              "inputs": {"width": GEN_W, "height": GEN_H, "batch_size": 1}},
        "5": {"class_type": "KSampler",
              "inputs": {"seed": seed, "steps": 26, "cfg": 7.0,
                         "sampler_name": "dpmpp_2m", "scheduler": "karras",
                         "denoise": 1.0, "model": ["1", 0],
                         "positive": ["2", 0], "negative": ["3", 0],
                         "latent_image": ["4", 0]}},
        "6": {"class_type": "VAEDecode", "inputs": {"samples": ["5", 0], "vae": ["1", 2]}},
        "7": {"class_type": "SaveImage",
              "inputs": {"filename_prefix": "dsh_disaster", "images": ["6", 0]}},
    }


def post(path: str, payload: dict) -> dict:
    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(HOST + path, data=data,
                                headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.loads(r.read().decode("utf-8"))


def get(path: str) -> dict:
    with urllib.request.urlopen(HOST + path, timeout=30) as r:
        return json.loads(r.read().decode("utf-8"))


def wait_for(prompt_id: str, timeout_s: int = 300) -> Path | None:
    t0 = time.time()
    while time.time() - t0 < timeout_s:
        hist = get(f"/history/{prompt_id}")
        if prompt_id in hist:
            entry = hist[prompt_id]
            outs = entry.get("outputs", {})
            for node in outs.values():
                for im in node.get("images", []):
                    p = COMFY_OUT / im.get("subfolder", "") / im["filename"]
                    if p.exists():
                        return p
            return None
        time.sleep(2.0)
    return None


def crop_to_card(src: Path, dst: Path) -> None:
    im = Image.open(src).convert("RGB")
    w, h = im.size
    # 底部裁掉一点（去签名/水印）
    cut = int(h * TRIM_BOTTOM)
    im = im.crop((0, 0, w, h - cut))
    w, h = im.size
    target = CARD_W / CARD_H
    if w / h > target:                      # 太宽 → 左右裁
        nw = int(h * target)
        im = im.crop(((w - nw) // 2, 0, (w - nw) // 2 + nw, h))
    else:                                   # 太高 → 上下裁
        nh = int(w / target)
        im = im.crop((0, (h - nh) // 2, w, (h - nh) // 2 + nh))
    im = im.resize((CARD_W, CARD_H), Image.LANCZOS)
    im.save(dst)
    print(f"    -> {dst.name}  {CARD_W}x{CARD_H}")


def main() -> None:
    ckpts = get("/object_info/CheckpointLoaderSimple")
    names = ckpts["CheckpointLoaderSimple"]["input"]["required"]["ckpt_name"][0]
    ckpt = "sd_xl_base_1.0.safetensors" if "sd_xl_base_1.0.safetensors" in names else names[0]
    print(f"  用 checkpoint：{ckpt}")
    RAW.mkdir(parents=True, exist_ok=True)
    OUT.mkdir(parents=True, exist_ok=True)
    negative = ("text, letters, watermark, signature, logo, blurry, low quality, "
                "extra limbs, deformed faces, cartoon, anime")
    ok = 0
    for i, (key, scene) in enumerate(SCENES):
        prompt = f"{scene}, {STYLE}"
        print(f"  [{i+1}/{len(SCENES)}] {key} 生成中 …")
        res = post("/prompt", {"prompt": workflow(ckpt, prompt, negative, 20261006 + i * 37)})
        pid = res.get("prompt_id", "")
        src = wait_for(pid)
        if src is None:
            print(f"    [FAIL] {key} 没出图（prompt_id={pid}）")
            continue
        keep = RAW / f"{key}.png"
        shutil.copy2(src, keep)
        crop_to_card(keep, OUT / f"disaster_{key}.png")
        ok += 1
    print()
    print(f"  完成 {ok}/{len(SCENES)} 张")
    if ok == 0:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
