"""Remove a generated chroma-green field while preserving dark HUD materials."""

from argparse import ArgumentParser
from pathlib import Path

from PIL import Image


def remove_green_key(source: Path, output: Path) -> Image.Image:
    image = Image.open(source).convert("RGBA")
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
    output.parent.mkdir(parents=True, exist_ok=True)
    image.save(output, optimize=True)
    return image


def main() -> None:
    parser = ArgumentParser()
    parser.add_argument("source", type=Path)
    parser.add_argument("output", type=Path, nargs="?")
    parser.add_argument("--check-center", action="store_true")
    parser.add_argument(
        "--clear-rect",
        nargs=4,
        type=int,
        metavar=("LEFT", "TOP", "RIGHT", "BOTTOM"),
        help="Force the known chroma viewport interior to full transparency.",
    )
    args = parser.parse_args()
    output = args.output or args.source
    image = remove_green_key(args.source, output)
    if args.clear_rect:
        left, top, right, bottom = args.clear_rect
        pixels = image.load()
        for y in range(max(0, top), min(image.height, bottom)):
            for x in range(max(0, left), min(image.width, right)):
                red, green, blue, _alpha = pixels[x, y]
                pixels[x, y] = (red, green, blue, 0)
        image.save(output, optimize=True)
    if args.check_center and image.getpixel((image.width // 2, image.height // 2))[3] != 0:
        raise ValueError("The center of the keyed opening is not transparent")
    print(f"Removed green key: {output}")


if __name__ == "__main__":
    main()
