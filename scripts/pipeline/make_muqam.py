"""按木卡姆的调式特征合成一段音乐。

为什么是「合成」而不是「找素材」：
  木卡姆是活态非遗，演出者具名、录音走商业发行。
  维基共享的 Category:Muqam 只有 5 个文件且全是照片；
  Freesound 用 CC0 过滤搜 muqam/dutar/rawap 是 0 条。
  **免费 CC 这条路是空的** —— 不是法律问题，是供给问题。
  所以改成自己造：合成出来的东西是原创作品，不存在侵权。

技术上抓的是什么：
  木卡姆最标志性的不是「音阶像中东」，而是**中立三度** ——
  一个比大三度低约 50 音分、比小三度高约 50 音分的音程（约 350 音分）。
  西方十二平均律里根本没有这个音，所以只要把它弹出来，
  听感立刻离开西方调式。二度、六度、七度同样用中立位置。
  （这是"调式特征"，不是"具体某首曲子"的复制 —— 见文件末尾的说明。）

音色：
  · 弹拨（都塔尔那种）：加法合成 + 各次谐波按序快速衰减，
    再加一点点拨弦噪声当"起振"，比纯正弦像弦。
  · 手鼓（达甫）：低音是正弦下滑，边圈的"叮"是带通噪声。
  两者都是纯计算出来的，没有采任何现成录音。

用法：
    .venv\\Scripts\\python.exe scripts\\pipeline\\make_muqam.py
输出：
    assets/audio/muqam_theme.wav   （可循环，末尾与开头接得上）
"""
import math
import struct
import wave
from pathlib import Path

import numpy as np

SR = 22050
OUT = Path(__file__).resolve().parents[2] / "assets" / "audio" / "muqam_theme.wav"

# ---------------------------------------------------------------------------
# 调式：以音分为单位，相对主音
# ---------------------------------------------------------------------------
# 中立二度 150 / 中立三度 350 / 纯四度 500 / 纯五度 700
# 中立六度 850 / 中立七度 1050 —— 三个中立音程是这段音乐的"口音"。
NEUTRAL = [0, 150, 350, 500, 700, 850, 1050, 1200]

TONIC_HZ = 196.0        # 都塔尔的常用音区，G3 附近


def cents_to_hz(cents: float, tonic: float = TONIC_HZ) -> float:
    return tonic * (2.0 ** (cents / 1200.0))


def pluck(freq: float, dur: float, amp: float = 0.5, bright: float = 1.0) -> np.ndarray:
    """拨弦音：加法合成，高次谐波衰减更快 —— 这是"弦"而不是"笛"的关键。"""
    n = int(SR * dur)
    if n <= 0:
        return np.zeros(0)
    t = np.arange(n) / SR
    out = np.zeros(n)
    # 音越高，高次谐波衰减越快（真实弦的物理行为）
    for k in range(1, 13):
        a = (1.0 / (k ** 1.35)) * math.exp(-k * 0.9 * bright)
        if a < 0.002:
            break
        # 轻微失谐：真实弦的各次谐波不是严格整数倍，这点"不准"反而像真的
        fk = freq * k * (1.0 + 0.0007 * k * k)
        if fk > SR * 0.45:
            break
        out += a * np.sin(2 * np.pi * fk * t)
    # 包络：极快的起振 + 较长的衰减
    env = np.exp(-3.2 * t)
    attack = np.minimum(1.0, t / 0.004)
    out *= env * attack
    # 起振噪声：拨片/指甲碰到弦那一下
    nz = int(SR * 0.012)
    if nz < n:
        out[:nz] += np.random.uniform(-1, 1, nz) * np.linspace(0.16, 0.0, nz)
    return out * amp


def dap(dur: float, kind: str = "dum") -> np.ndarray:
    """达甫（手鼓）。dum = 低音，tak = 边圈。"""
    n = int(SR * dur)
    t = np.arange(n) / SR
    if kind == "dum":
        # 低音：音高快速下滑，才有"闷"的一下
        f = 150.0 * np.exp(-14.0 * t) + 62.0
        out = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-9.0 * t)
        out += np.random.uniform(-1, 1, n) * np.exp(-40.0 * t) * 0.25
    else:
        # 边圈：带通感的噪声，短促
        nz = np.random.uniform(-1, 1, n)
        # 一阶差分当简易高通，再去掉低频
        out = np.diff(np.concatenate([[0.0], nz])) * np.exp(-38.0 * t)
        out *= 0.7
    return out * 0.85


def mix_at(dst: np.ndarray, src: np.ndarray, at: float, gain: float = 1.0) -> None:
    i = int(SR * at)
    if i >= len(dst) or len(src) == 0:
        return
    n = min(len(src), len(dst) - i)
    dst[i:i + n] += src[:n] * gain


def main() -> None:
    np.random.seed(20261005)          # 固定种子：每次跑出的曲子完全一样
    bpm = 76.0
    beat = 60.0 / bpm
    bars = 8
    total = bars * 4 * beat + 1.6     # 尾巴留出余韵，循环时接得顺
    out = np.zeros(int(SR * total))

    # ── 旋律 ──
    # 一段下行再上行的乐句，用中立音程当骨架。
    # 木卡姆的旋律重装饰：每个长音前后加邻音，听着才"绕"。
    # (起拍, 音级, 时值)  音级是 NEUTRAL 的下标，负数是低八度
    mel = [
        (0.0, 3, 1.0), (1.0, 4, 0.5), (1.5, 3, 0.5), (2.0, 2, 1.0),
        (3.0, 1, 0.5), (3.5, 2, 0.5),
        (4.0, 3, 1.5), (5.5, 4, 0.5), (6.0, 5, 1.0), (7.0, 4, 1.0),
        (8.0, 6, 1.0), (9.0, 5, 0.5), (9.5, 4, 0.5), (10.0, 3, 1.5),
        (11.5, 2, 0.5),
        (12.0, 1, 1.0), (13.0, 2, 0.5), (13.5, 3, 0.5), (14.0, 4, 1.5),
        (15.5, 3, 0.5),
        (16.0, 2, 1.0), (17.0, 1, 1.0), (18.0, 0, 2.0),
        (20.0, 3, 1.0), (21.0, 4, 1.0), (22.0, 5, 0.5), (22.5, 6, 0.5),
        (23.0, 7, 1.5),
        (24.0, 6, 0.5), (24.5, 7, 0.5), (25.0, 8 - 1, 2.0),   # 8-1 = 高八度主音(下标7+1oct)
    ]
    for start, deg, dur in mel:
        if deg < 0:
            hz = cents_to_hz(NEUTRAL[deg + len(NEUTRAL) - 1] - 1200)
        elif deg >= len(NEUTRAL):
            hz = cents_to_hz(NEUTRAL[deg - len(NEUTRAL)] + 1200)
        else:
            hz = cents_to_hz(NEUTRAL[deg])
        note = pluck(hz, dur * beat * 1.9 + 0.35, amp=0.42, bright=1.0)
        mix_at(out, note, start * beat)

    # 低音持续音（都塔尔的第二根弦常年空弦，是这种音乐的底色）
    for b in range(bars):
        mix_at(out, pluck(cents_to_hz(NEUTRAL[0]) * 0.5, 4 * beat + 0.4,
                          amp=0.20, bright=0.55), b * 4 * beat)

    # ── 手鼓 ──
    # 达甫的常见型：DUM - tak - DUM DUM - tak（4/4）
    pat = [("dum", 0.0), ("tak", 1.0), ("dum", 2.0), ("dum", 2.5),
           ("tak", 3.0), ("tak", 3.5)]
    for b in range(bars):
        for kind, off in pat:
            mix_at(out, dap(0.5 if kind == "dum" else 0.2, kind),
                   b * 4 * beat + off * beat, 0.9 if b % 2 == 0 else 0.7)

    # ── 收尾 ──
    peak = float(np.max(np.abs(out)))
    if peak > 0:
        out = out / peak * 0.89
    # 首尾各 30ms 淡入淡出，循环时不"啪"
    f = int(SR * 0.03)
    out[:f] *= np.linspace(0, 1, f)
    out[-f:] *= np.linspace(1, 0, f)

    OUT.parent.mkdir(parents=True, exist_ok=True)
    data = (out * 32767).astype(np.int16)
    with wave.open(str(OUT), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())
    print(f"  -> {OUT}")
    print(f"     时长 {len(out)/SR:.1f}s  采样率 {SR}  峰值 {np.max(np.abs(out)):.3f}")
    print(f"     调式音分 {NEUTRAL}")
    print(f"     中立三度 = {NEUTRAL[2]} 音分（西方小三度 300 / 大三度 400）")


if __name__ == "__main__":
    main()
