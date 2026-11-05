"""Генератор текстур интерфейса в стиле острова (docs/ART_DIRECTION.md).

Запуск: python3 tools/ui_art/generate_ui_art.py  → assets/ui/*.png
Детерминирован (фиксированный seed), чтобы картинки можно было пересоздать один в один.
Рисуем в 2× и уменьшаем — сглаженные края без ручного антиалиасинга.
"""
import math
import random
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

OUT = Path(__file__).resolve().parents[2] / "assets" / "ui"
S = 2  # суперсэмплинг

# Палитра (docs/ART_DIRECTION.md)
WOOD_DARK = (74, 46, 28)
WOOD = (122, 80, 48)
WOOD_LIGHT = (164, 114, 70)
CARVE = (196, 150, 98)
PARCHMENT = (239, 224, 189)
PARCHMENT_DARK = (214, 192, 144)
INK = (59, 42, 26)
TEAL = (47, 138, 138)
GOLD = (232, 185, 74)


def rng(seed):
    return random.Random(seed)


def grain(img, box, base, seed, strength=18, horizontal=True):
    """Волокна дерева: полосы разной яркости вдоль доски."""
    d = ImageDraw.Draw(img)
    r = rng(seed)
    x0, y0, x1, y1 = box
    length = (x1 - x0) if horizontal else (y1 - y0)
    span = (y1 - y0) if horizontal else (x1 - x0)
    for i in range(span):
        shade = r.randint(-strength, strength)
        wobble = r.random() * 6
        color = tuple(max(0, min(255, c + shade)) for c in base)
        for t in range(0, length, 3):
            off = int(math.sin(t / (40 + wobble * 10) + i) * 1.5)
            if horizontal:
                d.point((x0 + t, y0 + i + off), fill=color)
            else:
                d.point((x0 + i + off, y0 + t), fill=color)
    # сучки
    for _ in range(max(1, length // 220)):
        cx = x0 + r.randint(20, max(21, (x1 - x0) - 20))
        cy = y0 + r.randint(6, max(7, (y1 - y0) - 6))
        rad = r.randint(3, 6) * S
        d.ellipse((cx - rad * 2, cy - rad, cx + rad * 2, cy + rad), outline=tuple(c - 25 for c in base), width=S)


def noise_fill(img, box, base, seed, amount=10):
    """Пергамент: мелкое зерно и волокна."""
    px = img.load()
    r = rng(seed)
    x0, y0, x1, y1 = box
    for y in range(y0, y1):
        for x in range(x0, x1):
            n = r.randint(-amount, amount)
            px[x, y] = tuple(max(0, min(255, c + n)) for c in base) + (255,)


def zigzag(d, x0, x1, y, h, step, color, width):
    pts = []
    x = x0
    up = True
    while x <= x1:
        pts.append((x, y - h if up else y + h))
        up = not up
        x += step
    d.line(pts, fill=color, width=width, joint="curve")


def waves(d, x0, x1, y, r, color, width):
    x = x0
    while x < x1:
        d.arc((x, y - r, x + 2 * r, y + r), 180, 360, fill=color, width=width)
        x += 2 * r


def save(img, name):
    small = img.resize((img.width // S, img.height // S), Image.LANCZOS)
    small.save(OUT / name)
    print("saved", name, small.size)


def panel():
    """Пергамент в деревянной раме с резным зигзагом и «узлами» в углах. 9-patch, поля 30."""
    w = h = 128 * S
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    radius = 18 * S
    mask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, w - 1, h - 1), radius, fill=255)
    frame = Image.new("RGBA", (w, h), WOOD + (255,))
    grain(frame, (0, 0, w, h), WOOD, 11, 14)
    img.paste(frame, (0, 0), mask)
    d = ImageDraw.Draw(img)
    d.rounded_rectangle((1, 1, w - 2, h - 2), radius, outline=WOOD_DARK, width=3 * S)
    # пергамент внутри
    inner = 12 * S
    par = Image.new("RGBA", (w, h), PARCHMENT + (255,))
    noise_fill(par, (0, 0, w, h), PARCHMENT, 12, 7)
    pmask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(pmask).rounded_rectangle((inner, inner, w - inner - 1, h - inner - 1), 8 * S, fill=255)
    # тень по краю пергамента
    edge = Image.new("L", (w, h), 0)
    ImageDraw.Draw(edge).rounded_rectangle((inner, inner, w - inner - 1, h - inner - 1), 8 * S, outline=255, width=6 * S)
    edge = edge.filter(ImageFilter.GaussianBlur(4 * S))
    par = Image.composite(Image.new("RGBA", (w, h), PARCHMENT_DARK + (255,)), par, edge)
    img.paste(par, (0, 0), pmask)
    d = ImageDraw.Draw(img)
    d.rounded_rectangle((inner, inner, w - inner - 1, h - inner - 1), 8 * S, outline=WOOD_DARK, width=2 * S)
    # резьба: зигзаг по раме
    mid = 6 * S
    zigzag(d, 26 * S, w - 26 * S, mid, 2 * S, 6 * S, CARVE, S)
    zigzag(d, 26 * S, w - 26 * S, h - mid, 2 * S, 6 * S, CARVE, S)
    for y in range(26 * S, h - 26 * S, 12 * S):
        d.line((mid - 2 * S, y, mid + 2 * S, y + 6 * S), fill=CARVE, width=S)
        d.line((w - mid - 2 * S, y, w - mid + 2 * S, y + 6 * S), fill=CARVE, width=S)
    # узлы-ракушки в углах
    for cx, cy in [(12 * S, 12 * S), (w - 12 * S, 12 * S), (12 * S, h - 12 * S), (w - 12 * S, h - 12 * S)]:
        d.ellipse((cx - 7 * S, cy - 7 * S, cx + 7 * S, cy + 7 * S), fill=GOLD, outline=WOOD_DARK, width=S)
        d.ellipse((cx - 3 * S, cy - 3 * S, cx + 3 * S, cy + 3 * S), fill=TEAL)
    save(img, "panel.png")


def plank(name, base, seed, highlight=0, pressed=False, w=96, h=40):
    """Деревянная табличка-кнопка; по краям — обмотка верёвкой. 9-patch, поля 18×12."""
    W, H = w * S, h * S
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    mask = Image.new("L", (W, H), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 2 * S, W - 1, H - 1), 9 * S, fill=255)
    col = tuple(min(255, c + highlight) for c in base)
    wood = Image.new("RGBA", (W, H), col + (255,))
    grain(wood, (0, 0, W, H), col, seed, 12)
    img.paste(wood, (0, 0), mask)
    d = ImageDraw.Draw(img)
    d.rounded_rectangle((1, 2 * S + 1, W - 2, H - 2), 9 * S, outline=WOOD_DARK, width=2 * S)
    if not pressed:
        d.line((10 * S, 5 * S, W - 10 * S, 5 * S), fill=tuple(min(255, c + 40) for c in col), width=S)
        d.line((10 * S, H - 4 * S, W - 10 * S, H - 4 * S), fill=WOOD_DARK, width=2 * S)
    for x in (9 * S, W - 13 * S):
        for i in range(4):
            yy = 7 * S + i * 7 * S
            d.line((x, yy, x + 4 * S, yy + 5 * S), fill=(210, 186, 140), width=2 * S)
    save(img, name)


def top_bar():
    """Доска верхней панели: волокна, волны по нижнему краю. Тайлится по горизонтали."""
    W, H = 256 * S, 52 * S
    img = Image.new("RGBA", (W, H), WOOD + (255,))
    grain(img, (0, 0, W, H), WOOD, 21, 16)
    d = ImageDraw.Draw(img)
    d.line((0, 2 * S, W, 2 * S), fill=WOOD_LIGHT, width=2 * S)
    d.rectangle((0, H - 10 * S, W, H), fill=WOOD_DARK)
    waves(d, 0, W, H - 10 * S, 8 * S, CARVE, 2 * S)
    for x in range(0, W, 16 * S):
        d.ellipse((x + 6 * S, H - 5 * S, x + 9 * S, H - 2 * S), fill=GOLD)
    save(img, "top_bar.png")


def bars():
    """Полоска: тёмный жёлоб и светлая заливка с бликом (цвет задаётся в игре через modulate)."""
    W, H = 48 * S, 16 * S
    bg = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(bg)
    d.rounded_rectangle((0, 0, W - 1, H - 1), 7 * S, fill=(58, 40, 26, 230), outline=WOOD_DARK, width=S)
    d.line((5 * S, 3 * S, W - 5 * S, 3 * S), fill=(30, 20, 12, 200), width=S)
    save(bg, "bar_bg.png")
    fill = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(fill)
    d.rounded_rectangle((1 * S, 1 * S, W - 1 * S - 1, H - 1 * S - 1), 6 * S, fill=(225, 225, 225, 255))
    d.rounded_rectangle((3 * S, 3 * S, W - 3 * S, 7 * S), 3 * S, fill=(255, 255, 255, 255))
    d.line((3 * S, H - 3 * S, W - 3 * S, H - 3 * S), fill=(170, 170, 170, 255), width=S)
    save(fill, "bar_fill.png")


def divider():
    """Разделитель: волна между двумя точками-ракушками. Тайлится по горизонтали."""
    W, H = 64 * S, 14 * S
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    waves(d, 0, W, H // 2 + 2 * S, 4 * S, (140, 100, 62, 255), S + 1)
    d.ellipse((W // 2 - 2 * S, 1 * S, W // 2 + 2 * S, 5 * S), fill=TEAL + (255,))
    save(img, "divider.png")


def field():
    """Поле ввода: вдавленный пергамент."""
    W, H = 64 * S, 36 * S
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle((0, 0, W - 1, H - 1), 7 * S, fill=PARCHMENT_DARK + (255,), outline=WOOD, width=2 * S)
    d.line((6 * S, 4 * S, W - 6 * S, 4 * S), fill=(180, 155, 110, 255), width=2 * S)
    save(img, "field.png")


def plaque():
    """Табличка для всплывающих сообщений: тёмное дерево, золотой кант."""
    W, H = 96 * S, 44 * S
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    mask = Image.new("L", (W, H), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, W - 1, H - 1), 12 * S, fill=255)
    wood = Image.new("RGBA", (W, H), WOOD_DARK + (240,))
    grain(wood, (0, 0, W, H), WOOD_DARK, 31, 10)
    img.paste(wood, (0, 0), mask)
    d = ImageDraw.Draw(img)
    d.rounded_rectangle((3 * S, 3 * S, W - 4 * S, H - 4 * S), 10 * S, outline=GOLD, width=S)
    save(img, "plaque.png")


def leaf():
    """Пальмовый лист для украшения заголовков."""
    W, H = 96 * S, 48 * S
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.line((4 * S, H - 8 * S, W - 6 * S, 10 * S), fill=(86, 112, 58, 255), width=2 * S)
    for i in range(10):
        t = i / 10
        x = 4 * S + (W - 10 * S) * t
        y = (H - 8 * S) - (H - 18 * S) * t
        ln = (14 - i) * S
        d.line((x, y, x - ln * 0.4, y - ln), fill=(104, 138, 70, 255), width=3 * S)
        d.line((x, y, x + ln, y + ln * 0.3), fill=(88, 120, 60, 255), width=3 * S)
    save(img, "leaf.png")


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    panel()
    plank("button.png", WOOD, 41)
    plank("button_hover.png", WOOD, 41, highlight=22)
    plank("button_pressed.png", WOOD_DARK, 43, pressed=True)
    plank("button_disabled.png", (110, 98, 86), 47)
    top_bar()
    bars()
    divider()
    field()
    plaque()
    leaf()
