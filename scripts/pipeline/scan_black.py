from PIL import Image
from pathlib import Path
import numpy as np

A = Path(r'D:\坎儿井\assets\buildings')
rows = []
files = sorted(A.glob('*.png'))
for p in files:
    a = np.array(Image.open(p).convert('RGBA'))
    al = a[:, :, 3]
    blackish = ((a[:, :, 0] < 45) & (a[:, :, 1] < 45) & (a[:, :, 2] < 45) & (al > 200)).sum()
    frac = blackish / al.size
    if frac > 0.06:
        rows.append((frac, p.name, a.shape[1], a.shape[0], int(blackish), float((al == 0).mean())))

rows.sort(reverse=True)
print('  黑块占比大于 6% 的贴图（共 ' + str(len(rows)) + ' 张）:')
for frac, name, w, h, n, trans in rows:
    print('    {:5.1f}%  {:<26} {}x{}  黑{}px  透明{:.0f}%'.format(
        frac * 100, name, w, h, n, trans * 100))
if not rows:
    print('    （没有）')
print()
print('  buildings/ 共 ' + str(len(files)) + ' 张')
