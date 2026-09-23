# -*- coding: utf-8 -*-
"""生成 CosyAgent 应用图标：蓝紫渐变圆角方块 + 白色智能体循环气泡。"""
import os
from PIL import Image, ImageDraw

BASE = 1024
OUT = os.path.join(os.path.dirname(__file__), 'icon_out')
os.makedirs(OUT, exist_ok=True)

# ---------- 主图绘制 ----------
img = Image.new('RGBA', (BASE, BASE), (0, 0, 0, 0))
d = ImageDraw.Draw(img)

# 1) 圆角方块背景（半径 180），垂直渐变 #6E8CFF -> #2A3DB8
radius = 180
top, bottom = (110, 140, 255), (42, 61, 184)
mask = Image.new('L', (BASE, BASE), 0)
md = ImageDraw.Draw(mask)
md.rounded_rectangle([0, 0, BASE - 1, BASE - 1], radius=radius, fill=255)
for y in range(BASE):
    t = y / (BASE - 1)
    c = tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3))
    line = Image.new('RGBA', (BASE, 1), c + (255,))
    img.paste(line, (0, y), mask.crop((0, y, BASE, y + 1)))
img.putalpha(mask)

# 2) 中央白色圆角气泡（宽 480 高 420，居中，圆角 110）
bx0, by0, bx1, by1 = 272, 302, 752, 722
bubble = Image.new('RGBA', (BASE, BASE), (0, 0, 0, 0))
bd = ImageDraw.Draw(bubble)
bd.rounded_rectangle([bx0, by0, bx1, by1], radius=110, fill=(255, 255, 255, 255))
# 气泡小尾巴（左下）
bd.polygon([(620, 722), (700, 722), (585, 800)], fill=(255, 255, 255, 255))
img.alpha_composite(bubble)

# 3) 气泡内 ReAct 三点回路（深蓝圆点 + 连线，代表 Thought-Action-Observation 循环）
dot_r = 34
nodes = [(512, 392), (388, 546), (636, 546)]  # 顶 / 左下 / 右下
edge_color = (58, 84, 200, 255)
for i in range(3):
    a, b = nodes[i], nodes[(i + 1) % 3]
    d.line([a, b], fill=edge_color, width=26)
for (x, y) in nodes:
    d.ellipse([x - dot_r, y - dot_r, x + dot_r, y + dot_r], fill=(64, 90, 214, 255))

img.save(os.path.join(OUT, 'app_icon_1024.png'))

# ---------- 导出多尺寸 PNG ----------
sizes = [16, 32, 48, 64, 128, 192, 256, 512, 1024]
for s in sizes:
    img.resize((s, s), Image.LANCZOS).save(
        os.path.join(OUT, f'app_icon_{s}.png'))

# ---------- 生成 .ico（多尺寸嵌入） ----------
ico_sizes = [(256, 256), (128, 128), (64, 64), (48, 48), (32, 32), (24, 24), (16, 16)]
img.resize((256, 256), Image.LANCZOS).save(
    os.path.join(OUT, 'app_icon.ico'),
    format='ICO',
    sizes=ico_sizes,
)

print('generated:', sorted(os.listdir(OUT)))
