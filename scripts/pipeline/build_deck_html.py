#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""从 PPTX 的逐页渲染图生成单文件 HTML 放映版。

为什么用渲染图而不是重新排一遍 HTML：
  重新排 = 第二份排版代码 = 迟早和 PPTX 不一致（本项目已经因为"两处各写一套"
  栽过 10 次）。用渲染图的话，HTML 与 PPTX **逐像素相同**，
  而且我在验收时看的就是它本身 —— 不存在"HTML 没核对过"这一说。

代价：HTML 里的字不是可选文本。可编辑版是 PPTX，HTML 只负责放映，
这个取舍是清楚的。

用法：.venv\\Scripts\\python.exe scripts\\pipeline\\build_deck_html.py <渲染目录>
"""
from __future__ import annotations

import sys as _sys
from pathlib import Path as _Path
_sys.path.insert(0, str(_Path(__file__).resolve().parent))
from _root import ROOT  # 路径唯一解析处，不再写死盘符
import base64
import io
import sys
from pathlib import Path

from PIL import Image

OUT = Path(str(ROOT / "deliverables/坎儿井_创新点答辩.html"))
MAXW = 1600

HTML = """<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="utf-8">
<title>《坎儿井》· 创新点答辩</title>
<style>
  :root{--bg:#2B2118;--gold:#E0A43C;--cream:#F0E4D0;--muted:#B5A48C;}
  *{box-sizing:border-box;margin:0;padding:0}
  html,body{height:100%;background:var(--bg);font-family:"Microsoft YaHei","微软雅黑",sans-serif;overflow:hidden}
  #stage{position:fixed;inset:0;display:flex;align-items:center;justify-content:center}
  .slide{display:none;width:100%;height:100%;align-items:center;justify-content:center}
  .slide.on{display:flex}
  .slide img{max-width:100%;max-height:100%;object-fit:contain;
    box-shadow:0 18px 60px rgba(0,0,0,.55)}
  #bar{position:fixed;left:0;top:0;height:3px;background:var(--gold);width:0;z-index:20;transition:width .25s}
  #hud{position:fixed;right:16px;bottom:12px;color:var(--muted);font-size:13px;z-index:20;
    background:rgba(20,15,11,.55);padding:4px 10px;border-radius:14px}
  #tip{position:fixed;left:16px;bottom:12px;color:var(--muted);font-size:12px;z-index:20;opacity:.75}
  #grid{position:fixed;inset:0;z-index:30;display:none;background:rgba(18,13,9,.96);
    padding:22px;overflow:auto}
  #grid.on{display:grid;grid-template-columns:repeat(4,1fr);gap:12px;align-content:start}
  #grid img{width:100%;border:1px solid rgba(224,164,60,.45);cursor:pointer}
  #grid img:hover{border-color:var(--gold)}
  @media print{
    html,body{background:#fff;overflow:visible}
    #stage{position:static;display:block}
    .slide{display:block !important;page-break-after:always;height:auto}
    .slide img{width:100%}
    #bar,#hud,#tip,#grid{display:none !important}
  }
</style>
</head>
<body>
<div id="bar"></div>
<div id="stage">__SLIDES__</div>
<div id="grid">__GRID__</div>
<div id="hud"><b id="no">1</b> / __N__</div>
<div id="tip">← → 翻页　·　F 全屏　·　G 总览　·　P 打印</div>
<script>
const slides=[...document.querySelectorAll('.slide')];
const grid=document.getElementById('grid');
let i=0;
function show(n){
  i=Math.max(0,Math.min(slides.length-1,n));
  slides.forEach((s,k)=>s.classList.toggle('on',k===i));
  document.getElementById('no').textContent=i+1;
  document.getElementById('bar').style.width=((i+1)/slides.length*100)+'%';
}
document.addEventListener('keydown',e=>{
  if(e.key==='ArrowRight'||e.key===' '||e.key==='PageDown'){show(i+1);e.preventDefault();}
  else if(e.key==='ArrowLeft'||e.key==='PageUp'){show(i-1);e.preventDefault();}
  else if(e.key==='Home'){show(0);}
  else if(e.key==='End'){show(slides.length-1);}
  else if(e.key==='f'||e.key==='F'){document.fullscreenElement?document.exitFullscreen():document.documentElement.requestFullscreen();}
  else if(e.key==='g'||e.key==='G'){grid.classList.toggle('on');}
  else if(e.key==='p'||e.key==='P'){window.print();}
});
grid.querySelectorAll('img').forEach((im,k)=>im.onclick=()=>{grid.classList.remove('on');show(k);});
let x0=null;
document.addEventListener('touchstart',e=>x0=e.touches[0].clientX);
document.addEventListener('touchend',e=>{
  if(x0===null)return;
  const dx=e.changedTouches[0].clientX-x0;
  if(Math.abs(dx)>50){show(dx<0?i+1:i-1);}
  x0=null;
});
show(0);
</script>
</body>
</html>
"""


def main() -> None:
    d = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(str(ROOT / "deliverables/renderZ2"))
    files = sorted(d.glob("*.png"))
    if not files:
        raise SystemExit("  渲染目录里没有 PNG：%s" % d)

    slides: list[str] = []
    thumbs: list[str] = []
    total = 0
    for f in files:
        with Image.open(f) as im:
            im = im.convert("RGB")
            if im.width > MAXW:
                im = im.resize((MAXW, int(im.height * MAXW / im.width)), Image.LANCZOS)
            buf = io.BytesIO()
            im.save(buf, "JPEG", quality=90, optimize=True)
        b64 = base64.b64encode(buf.getvalue()).decode("ascii")
        total += len(b64)
        uri = "data:image/jpeg;base64," + b64
        slides.append('<div class="slide"><img src="%s" alt="第 %d 页"></div>'
                      % (uri, len(slides) + 1))
        thumbs.append('<img src="%s" alt="第 %d 页">' % (uri, len(thumbs) + 1))

    html = (HTML.replace("__SLIDES__", "\n".join(slides))
                .replace("__GRID__", "\n".join(thumbs))
                .replace("__N__", str(len(files))))
    OUT.write_text(html, encoding="utf-8")
    print("  已生成：%s" % OUT)
    print("  页数 %d｜内嵌 %d 张｜base64 合计 %.1f MB｜文件 %.2f MB"
          % (len(files), len(files), total / 1024 / 1024, OUT.stat().st_size / 1024 / 1024))


if __name__ == "__main__":
    main()
