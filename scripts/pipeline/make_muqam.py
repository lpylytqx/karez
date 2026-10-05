"""按木卡姆的调式特征合成一段背景音乐。

为什么是「合成」而不是「找素材」：
  木卡姆是活态非遗，演出者具名、录音走商业发行。
  维基共享 Category:Muqam 只有 5 个文件且全是照片；
  Freesound 用 CC0 过滤搜 muqam/dutar/rawap 是 0 条。
  **免费 CC 这条路是空的** —— 不是法律问题，是供给问题。
  所以改成自己造：合成出来的东西是原创作品，不存在侵权。

【第二版：从"阴间"改成"热闹"】
第一版用户评价「有点阴间」。复盘下来是我把木卡姆写成了最哀伤的那一面：
  · 铺了 8 小节不断的低音持续音 —— **最低沉的长音天生压抑，这是最大元凶**
  · 76 BPM 太慢，慢即沉重
  · 调式以中立三度为主，明暗指向不明，听感悬着
  · 长衰减 + 13 次谐波 + 轻微失谐，接近钟铃，空灵发冷
但十二木卡姆里有一大部分叫**麦西热甫** —— 那是巴扎上又唱又跳的节庆音乐。
第二版整个换性格：
  · 速度 76 -> 104 BPM（舞曲速度）
  · 调式换成拉斯特式：**大三度 400 音分**（明亮），中立音只留在二度/六度上做"口音"
  · **删掉持续低音**，改成每拍拨一下的节奏性低音
  · 手鼓加密成真正的舞曲型
  · 音区整体上移一个八度附近
  · 衰减缩短，起振更亮 —— 离"钟"远一点，离"拨弦"近一点

技术上抓的是什么：
  木卡姆的"口音"是**中立音程** —— 比大音程低约 50 音分、比小音程高约 50 音分
  （如中立三度约 350 音分）。西方十二平均律里没有这些音，
  所以只要把它们放在二度、六度上，听感就离开西方调式，
  同时保留大三度的明亮，不至于阴郁。

音色：
  · 弹拨（都塔尔那种）：加法合成 + 各次谐波按序快速衰减 + 拨弦噪声起振。
  · 手鼓（达甫）：低音是正弦下滑，边圈是差分噪声。
  两者都是纯计算，没有采任何现成录音。

用法：
    <python> scripts\\pipeline\\make_muqam.py
输出：
    assets/audio/muqam_theme.wav
"""
import math
import wave
from pathlib import Path

import numpy as np

SR = 22050
OUT = Path(__file__).resolve().parents[2] / "assets" / "audio" / "muqam_theme.wav"

# ---------------------------------------------------------------------------
# 调式：以音分为单位，相对主音
# ---------------------------------------------------------------------------
# 拉斯特式（Rast）：明确的**大三度(400)** 打底 —— 这是"明亮"的来源；
# 中立音放在二度(150)和六度(850)上 —— 这是"木卡姆口音"的来源。
# 两者并存：既离开西方调式，又不阴郁。
SCALE = [0, 150, 400, 500, 700, 850, 1050, 1200]

TONIC_HZ = 261.63        # C4 —— 比第一版高一个八度附近，整体提亮


def hz(deg: int, oct_shift: int = 0) -> float:
    """取音级对应的频率。deg 可以超出范围，自动换八度。"""
    o, d = divmod(deg, len(SCALE) - 1)
    return TONIC_HZ * (2.0 ** ((SCALE[d] + 1200 * (o + oct_shift)) / 1200.0))


def pluck(freq: float, dur: float, amp: float = 0.5, bright: float = 1.0,
          decay: float = 5.5) -> np.ndarray:
    """拨弦音：加法合成，高次谐波衰减更快 —— 这是"弦"而不是"笛"的关键。"""
    n = int(SR * dur)
    if n <= 0:
        return np.zeros(0)
    t = np.arange(n) / SR
    out = np.zeros(n)
    for k in range(1, 14):
        a = (1.0 / (k ** 1.25)) * math.exp(-k * 0.55 * bright)
        if a < 0.003:
            break
        # 轻微失谐像真弦；但第一版失谐给多了，出来发冷，这里收到 1/3
        fk = freq * k * (1.0 + 0.00025 * k * k)
        if fk > SR * 0.45:
            break
        out += a * np.sin(2 * np.pi * fk * t)
    env = np.exp(-decay * t)          # 第一版 3.2，太长像钟；这里默认 5.5
    attack = np.minimum(1.0, t / 0.003)
    out *= env * attack
    nz = int(SR * 0.010)
    if nz < n:
        out[:nz] += np.random.uniform(-1, 1, nz) * np.linspace(0.20, 0.0, nz)
    return out * amp


def dap(dur: float, kind: str = "dum") -> np.ndarray:
    """达甫（手鼓）。dum = 低音，tak = 边圈。第二版整体收紧、提亮。"""
    n = int(SR * dur)
    t = np.arange(n) / SR
    if kind == "dum":
        f = 165.0 * np.exp(-16.0 * t) + 74.0
        out = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-11.0 * t)
        out += np.random.uniform(-1, 1, n) * np.exp(-50.0 * t) * 0.28
    else:
        nz = np.random.uniform(-1, 1, n)
        out = np.diff(np.concatenate([[0.0], nz])) * np.exp(-45.0 * t) * 0.8
    return out * 0.8


def mix_at(dst: np.ndarray, src: np.ndarray, at: float, gain: float = 1.0) -> None:
    i = int(SR * at)
    if i >= len(dst) or len(src) == 0:
        return
    n = min(len(src), len(dst) - i)
    dst[i:i + n] += src[:n] * gain


def main() -> None:
    np.random.seed(20261005)
    bpm = 104.0
    beat = 60.0 / bpm
    bars = 8
    total = bars * 4 * beat + 1.2
    out = np.zeros(int(SR * total))

    # ── 旋律 ──
    # 麦西热甫是舞曲：乐句短、多反复、落音明确，不像第一版那样一路下行。
    # (拍, 音级, 时值)  音级以 SCALE 下标计，可越界自动换八度
    mel = [
        (0.0, 2, 0.5), (0.5, 3, 0.5), (1.0, 4, 1.0), (2.0, 3, 0.5), (2.5, 2, 0.5),
        (3.0, 1, 1.0),
        (4.0, 2, 0.5), (4.5, 3, 0.5), (5.0, 4, 1.0), (6.0, 6, 1.0), (7.0, 5, 0.5),
        (7.5, 4, 0.5),
        (8.0, 4, 0.5), (8.5, 5, 0.5), (9.0, 6, 1.0), (10.0, 5, 0.5), (10.5, 4, 0.5),
        (11.0, 3, 1.0),
        (12.0, 2, 0.5), (12.5, 4, 0.5), (13.0, 3, 0.5), (13.5, 2, 0.5), (14.0, 1, 2.0),
        (16.0, 2, 0.5), (16.5, 3, 0.5), (17.0, 4, 1.0), (18.0, 3, 0.5), (18.5, 2, 0.5),
        (19.0, 1, 1.0),
        (20.0, 2, 0.5), (20.5, 3, 0.5), (21.0, 5, 1.0), (22.0, 4, 0.5), (22.5, 3, 0.5),
        (23.0, 2, 1.0),
        (24.0, 4, 0.5), (24.5, 5, 0.5), (25.0, 6, 1.0), (26.0, 5, 1.0),
        (27.0, 4, 1.0),
        (28.0, 3, 0.5), (28.5, 2, 0.5), (29.0, 1, 3.0),
    ]
    for start, deg, dur in mel:
        note = pluck(hz(deg), dur * beat * 1.6 + 0.28, amp=0.40)
        mix_at(out, note, start * beat)
        # 高八度轻叠一层：舞曲要"亮"，一根弦太单薄
        mix_at(out, pluck(hz(deg, 1), dur * beat * 1.2 + 0.16, amp=0.11), start * beat)

    # ── 低音：每拍拨一下，不用持续音 ──
    # 第一版是 8 小节不断的长低音，那是"阴间"的最大来源，这里彻底去掉。
    for b in range(bars):
        for k in range(4):
            deg = 0 if k % 2 == 0 else 4          # 主音 / 五度交替
            mix_at(out, pluck(hz(deg, -1), beat * 1.1, amp=0.26, decay=7.0),
                   b * 4 * beat + k * beat)

    # ── 手鼓：真正的舞曲型，密而稳 ──
    # 每拍有 dum，反拍补 tak —— 这是麦西热甫那种推着人走的感觉。
    for b in range(bars):
        base = b * 4 * beat
        for k in range(4):
            mix_at(out, dap(0.45, "dum"), base + k * beat, 0.95 if k in (0, 2) else 0.7)
            mix_at(out, dap(0.18, "tak"), base + (k + 0.5) * beat, 0.6)
        # 每两小节加一次花
        if b % 2 == 1:
            mix_at(out, dap(0.18, "tak"), base + 3.75 * beat, 0.55)

    # ── 收尾 ──
    peak = float(np.max(np.abs(out)))
    if peak > 0:
        out = out / peak * 0.89
    f = int(SR * 0.03)
    out[:f] *= np.linspace(0, 1, f)
    out[-f:] *= np.linspace(1, 0, f)

    OUT.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(OUT), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((out * 32767).astype(np.int16).tobytes())
    print(f"  -> {OUT}")
    print(f"     时长 {len(out)/SR:.1f}s  速度 {bpm:.0f} BPM  采样率 {SR}")
    print(f"     调式音分 {SCALE}   大三度 400（明亮）+ 中立二度 150 / 中立六度 850（口音）")
    print(f"     峰值 {np.max(np.abs(out)):.3f}  均方根 {np.sqrt(np.mean(out**2)):.4f}")


if __name__ == "__main__":
    main()
