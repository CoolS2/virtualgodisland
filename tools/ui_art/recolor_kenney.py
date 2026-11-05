"""Перекраска палитр (colormap.png) паков Kenney под природную гамму острова (docs/ART_DIRECTION.md).

Источник — оригинальные архивы assets/kenney_*.zip (не меняются). Результат — assets/models/<пак>/Textures/colormap.png.
Мятно-бирюзовые зелёные (оттенок 75°–200°) сдвигаются к оливково-зелёному и приглушаются; остальное — как есть.
Запуск: python3 tools/ui_art/recolor_kenney.py
"""
import colorsys
import io
import zipfile
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
PACKS = {
    "survival": "kenney_survival-kit.zip",
    "pirate": "kenney_pirate-kit.zip",
    "town": "kenney_fantasy-town-kit_2.0.zip",
    "food": "kenney_food-kit.zip",
}
GREEN_FROM, GREEN_TO = 75 / 360, 200 / 360  # что считаем «зелёным»
TARGET_HUE = 92 / 360  # оливково-травяной
SATURATION = 0.72
VALUE = 0.86


def recolor(img: Image.Image) -> Image.Image:
    img = img.convert("RGBA")
    px = img.load()
    for y in range(img.height):
        for x in range(img.width):
            r, g, b, a = px[x, y]
            h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
            if s < 0.15 or not (GREEN_FROM <= h <= GREEN_TO):
                continue
            # Сохраняем относительные различия оттенков внутри группы, но сжимаем их к целевому.
            h = TARGET_HUE + (h - (GREEN_FROM + GREEN_TO) / 2) * 0.15
            nr, ng, nb = colorsys.hsv_to_rgb(h, s * SATURATION, v * VALUE)
            px[x, y] = (round(nr * 255), round(ng * 255), round(nb * 255), a)
    return img


def main() -> None:
    for pack, archive in PACKS.items():
        with zipfile.ZipFile(ROOT / "assets" / archive) as z:
            name = next(n for n in z.namelist() if n.endswith("GLB format/Textures/colormap.png"))
            img = Image.open(io.BytesIO(z.read(name)))
        out = ROOT / "assets" / "models" / pack / "Textures" / "colormap.png"
        recolor(img).save(out)
        print("recolored", out.relative_to(ROOT))


if __name__ == "__main__":
    main()
