#!/usr/bin/env python3
"""Convert a PNG/JPG into a Paint by Numbers ModuleScript.

The generated module uses one hexadecimal nibble per pixel.  Color IDs are
1..16, so a 256x256 art is only about 64 KiB of pixel data and can be loaded
without creating one Roblox Instance per pixel.

Example:
    python tools/image_to_luau.py art/sunset.png \
        ReplicatedStorage/PaintByNumbers/ArtLibrary/Sunset.lua \
        --size 64 --colors 12 --name "Sunset" --id sunset

The output is source text.  Copy it into a ModuleScript in Roblox Studio (or
use the import instructions in README.md).
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path
from typing import Iterable

try:
    from PIL import Image, ImageOps
except ImportError:  # Keep --help usable before Pillow is installed.
    Image = None  # type: ignore[assignment]
    ImageOps = None  # type: ignore[assignment]


SIZES = (32, 64, 128, 256)
SIZE_TO_DIFFICULTY = {
    32: "Easy",
    64: "Medium",
    128: "Hard",
    256: "Extreme / Unreal",
}
DEFAULT_REWARDS = {32: 75, 64: 150, 128: 300, 256: 600}


def slug(value: str) -> str:
    """Return a safe, stable identifier for a Roblox art module."""
    value = re.sub(r"[^A-Za-z0-9_]+", "_", value.strip())
    value = re.sub(r"_+", "_", value).strip("_")
    if not value:
        value = "art"
    if value[0].isdigit():
        value = "art_" + value
    return value.lower()


def parse_rgb(value: str) -> tuple[int, int, int]:
    value = value.strip().lstrip("#")
    if len(value) != 6 or not re.fullmatch(r"[0-9a-fA-F]{6}", value):
        raise argparse.ArgumentTypeError("background must be RRGGBB or #RRGGBB")
    return int(value[0:2], 16), int(value[2:4], 16), int(value[4:6], 16)


def wrap_string(value: str, width: int = 120) -> str:
    """Return pixel data without whitespace inside the long string.

    It is tempting to wrap a 256x256 value over several lines, but a newline
    would become an actual byte in the Luau string and shift every following
    pixel. A single 65 KiB source line is valid for a ModuleScript and keeps
    the runtime decoder O(1) per pixel.
    """
    return value


def convert(
    input_path: Path,
    output_path: Path,
    *,
    size: int,
    colors: int,
    art_id: str | None,
    display_name: str | None,
    reward: int | None,
    background: tuple[int, int, int],
) -> None:
    if Image is None or ImageOps is None:
        raise RuntimeError("Pillow is required. Install it with: python -m pip install Pillow")
    if size not in SIZES:
        raise ValueError(f"size must be one of {SIZES}")
    if not 4 <= colors <= 16:
        raise ValueError("colors must be between 4 and 16")

    with Image.open(input_path) as source:
        image = ImageOps.exif_transpose(source).convert("RGBA")
        # Transparent art needs a deterministic color behind it.  Compositing
        # before quantization also avoids a transparent black color entering
        # the palette unexpectedly.
        background_image = Image.new("RGBA", image.size, (*background, 255))
        background_image.alpha_composite(image)
        rgb = background_image.convert("RGB").resize(
            (size, size), Image.Resampling.LANCZOS
        )

    quantized = rgb.quantize(
        colors=colors,
        method=Image.Quantize.MEDIANCUT,
        dither=Image.Dither.NONE,
    )
    palette = quantized.getpalette()
    source_indices = list(quantized.getdata())

    # Pillow's palette indexes are not guaranteed to be dense or ordered by
    # first use.  Re-number only colors that actually occur, preserving the
    # visual first-use order and producing IDs 1..N for the Luau runtime.
    index_to_id: dict[int, int] = {}
    rgb_colors: list[tuple[int, int, int]] = []
    encoded: list[str] = []
    for palette_index in source_indices:
        if palette_index not in index_to_id:
            color_id = len(rgb_colors) + 1
            if color_id > 16:
                raise ValueError("internal error: more than 16 colors")
            index_to_id[palette_index] = color_id
            offset = palette_index * 3
            rgb_colors.append(tuple(int(channel) for channel in palette[offset : offset + 3]))
        encoded.append(f"{index_to_id[palette_index]:X}")

    source_stem = input_path.stem
    safe_id = slug(art_id or source_stem)
    name = display_name or re.sub(r"[_-]+", " ", source_stem).strip().title()
    final_reward = DEFAULT_REWARDS[size] if reward is None else reward
    if final_reward < 0:
        raise ValueError("reward must not be negative")

    def luau_string(value: str) -> str:
        # Keep metadata valid even when a display name contains quotes or a
        # backslash. Pixel data is emitted as a long string below.
        escaped = value.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")
        return f'"{escaped}"'

    palette_lines = [
        f"    [{color_id}] = Color3.fromRGB({r}, {g}, {b}),"
        for color_id, (r, g, b) in enumerate(rgb_colors, start=1)
    ]
    pixel_data = "".join(encoded)
    module = f'''-- Generated by tools/image_to_luau.py. Do not edit Pixels by hand.
-- PixelEncoding is hex-nibble-v1: one character per pixel, IDs 1..16.
return {{
    Id = {luau_string(safe_id)},
    Name = {luau_string(name)},
    Difficulty = {luau_string(SIZE_TO_DIFFICULTY[size])},
    Width = {size},
    Height = {size},
    Reward = {final_reward},
    PaletteSize = {len(rgb_colors)},
    PixelEncoding = "hex-nibble-v1",
    Palette = {{
{chr(10).join(palette_lines)}
    }},
    Pixels = [[{wrap_string(pixel_data)}]],
}}
'''
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(module, encoding="utf-8", newline="\n")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input", type=Path, help="source PNG or JPG")
    parser.add_argument("output", type=Path, help="destination .lua/.luau file")
    parser.add_argument("--size", type=int, choices=SIZES, default=32)
    parser.add_argument("--colors", type=int, choices=range(4, 17), default=12)
    parser.add_argument("--id", dest="art_id", help="stable ID used in saved progress")
    parser.add_argument("--name", dest="display_name", help="name shown in the gallery")
    parser.add_argument("--reward", type=int, help="gem reward for completing the art")
    parser.add_argument(
        "--background",
        type=parse_rgb,
        default=(255, 255, 255),
        metavar="RRGGBB",
        help="background used for transparent pixels (default: FFFFFF)",
    )
    return parser


def main(argv: Iterable[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    try:
        convert(
            args.input,
            args.output,
            size=args.size,
            colors=args.colors,
            art_id=args.art_id,
            display_name=args.display_name,
            reward=args.reward,
            background=args.background,
        )
    except (OSError, RuntimeError, ValueError) as exc:
        parser.error(str(exc))
    print(f"Wrote {args.output} ({args.size}x{args.size}, {args.colors} color limit)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
