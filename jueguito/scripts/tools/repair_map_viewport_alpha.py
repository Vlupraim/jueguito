"""Remove the green inner key left in the generated map viewport frame."""

from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
TARGET = ROOT / "assets" / "ui" / "hud" / "map_viewport_frame_v1.png"


def main() -> None:
    image = Image.open(TARGET).convert("RGBA")
    pixels = image.load()
    for y in range(image.height):
        for x in range(image.width):
            red, green, blue, alpha = pixels[x, y]
            dominance = green - max(red, blue)
            if green > 90 and dominance > 35:
                matte = max(0.0, min(1.0, (115.0 - dominance) / 80.0))
                next_alpha = min(alpha, round(255.0 * matte))
                neutral_green = min(green, round(max(red, blue) * 1.12))
                pixels[x, y] = (red, neutral_green, blue, next_alpha)
    image.save(TARGET, optimize=True)

    if image.getpixel((image.width // 2, image.height // 2))[3] != 0:
        raise ValueError("The inner map opening is not transparent")
    if image.getpixel((0, 0))[3] != 0:
        raise ValueError("The outer corner is not transparent")
    print(f"Repaired alpha: {TARGET.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
