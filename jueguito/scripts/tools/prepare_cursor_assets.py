#!/usr/bin/env python3
"""Slice the transparent 4x3 cursor atlas into Godot-ready PNG files."""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image


CURSOR_NAMES = (
    "arrow",
    "wait",
    "pointing_hand",
    "grab",
    "grabbing",
    "pvp_enabled",
    "forbidden",
    "zoom_in",
    "zoom_out",
    "move",
    "chat",
    "help",
)


def _fit_icon(cell: Image.Image, size: int, padding: int) -> Image.Image:
    alpha_bounds = cell.getchannel("A").getbbox()
    if alpha_bounds is None:
        raise ValueError("The atlas contains an empty cursor cell")

    icon = cell.crop(alpha_bounds)
    available = size - padding * 2
    scale = min(available / icon.width, available / icon.height)
    resized = icon.resize(
        (max(1, round(icon.width * scale)), max(1, round(icon.height * scale))),
        Image.Resampling.LANCZOS,
    )
    output = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    output.alpha_composite(
        resized,
        ((size - resized.width) // 2, (size - resized.height) // 2),
    )
    return output


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("atlas", type=Path)
    parser.add_argument("output_dir", type=Path)
    parser.add_argument("--size", type=int, default=64)
    parser.add_argument("--padding", type=int, default=4)
    parser.add_argument(
        "--single-name",
        help="Process the whole input as one icon instead of slicing a 4x3 atlas.",
    )
    args = parser.parse_args()

    atlas = Image.open(args.atlas).convert("RGBA")
    args.output_dir.mkdir(parents=True, exist_ok=True)

    if args.single_name:
        cursor = _fit_icon(atlas, args.size, args.padding)
        cursor.save(
            args.output_dir / f"cursor_{args.single_name}.png",
            optimize=True,
        )
        return

    for index, name in enumerate(CURSOR_NAMES):
        column = index % 4
        row = index // 4
        cell = atlas.crop(
            (
                round(column * atlas.width / 4),
                round(row * atlas.height / 3),
                round((column + 1) * atlas.width / 4),
                round((row + 1) * atlas.height / 3),
            )
        )
        cursor = _fit_icon(cell, args.size, args.padding)
        cursor.save(args.output_dir / f"cursor_{name}.png", optimize=True)


if __name__ == "__main__":
    main()
