#!/usr/bin/env python3
"""Convert PNG/JPG artwork into a Paint by Numbers Luau ModuleScript.

The generated module uses one hexadecimal nibble per pixel. Color IDs are
1..16, so a 256x256 variant is about 64 KiB and does not require one Roblox
Instance per pixel.

Single resolution:
    python tools/image_to_luau.py art/sunset.png ArtLibrary/Sunset.lua \
        --size 64 --colors 12 --id sunset --name "Sunset"

All four selectable difficulties in one ModuleScript:
    python tools/image_to_luau.py art/sunset.png ArtLibrary/Sunset.lua \
        --all-sizes --colors 12 --id sunset --name "Sunset"

The output is source text. Copy it into a ModuleScript in
ReplicatedStorage/PaintByNumbers/ArtLibrary.
"""

from __future__ import annotations

import argparse
import re
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


def luau_string(value: str) -> str:
    escaped = value.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")
    return f'"{escaped}"'


def quantize_image(
    input_path: Path,
    *,
    size: int,
    colors: int,
    background: tuple[int, int, int],
) -> tuple[list[tuple[int, int, int]], str]:
    """Resize, composite, quantize, and return palette plus nibble pixels."""
    if Image is None or ImageOps is None:
        raise RuntimeError("Pillow is required. Install it with: python -m pip install Pillow")
    with Image.open(input_path) as source:
        image = ImageOps.exif_transpose(source).convert("RGBA")
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
    raw_palette = quantized.getpalette()
    source_indices = list(quantized.getdata())

    # Pillow palette indexes are not guaranteed to be dense or ordered by
    # first use. Re-number only used colors to stable IDs 1..N.
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
            rgb_colors.append(tuple(int(channel) for channel in raw_palette[offset : offset + 3]))
        encoded.append(f"{index_to_id[palette_index]:X}")

    return rgb_colors, "".join(encoded)


def palette_source(palette: list[tuple[int, int, int]], indent: str = "        ") -> str:
    return "\n".join(
        f"{indent}[{color_id}] = Color3.fromRGB({r}, {g}, {b}),"
        for color_id, (r, g, b) in enumerate(palette, start=1)
    )


def variant_source(
    *,
    difficulty: str,
    size: int,
    reward: int,
    palette: list[tuple[int, int, int]],
    pixels: str,
    indent: str = "        ",
) -> str:
    nested = indent + "    "
    return f'''{indent}[{luau_string(difficulty)}] = {{
{indent}    Difficulty = {luau_string(difficulty)},
{indent}    Width = {size},
{indent}    Height = {size},
{indent}    Reward = {reward},
{indent}    PaletteSize = {len(palette)},
{indent}    PixelEncoding = "hex-nibble-v1",
{indent}    Palette = {{
{palette_source(palette, nested + "    ")}
{indent}    }},
{indent}    Pixels = [[{pixels}]],
{indent}}},'''


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
    all_sizes: bool,
) -> None:
    if size not in SIZES:
        raise ValueError(f"size must be one of {SIZES}")
    if not 4 <= colors <= 16:
        raise ValueError("colors must be between 4 and 16")
    if Image is None or ImageOps is None:
        raise RuntimeError("Pillow is required. Install it with: python -m pip install Pillow")

    source_stem = input_path.stem
    safe_id = slug(art_id or source_stem)
    name = display_name or re.sub(r"[_-]+", " ", source_stem).strip().title()
    output_path.parent.mkdir(parents=True, exist_ok=True)

    if all_sizes:
        variant_lines: list[str] = []
        for variant_size in SIZES:
            palette, pixels = quantize_image(
                input_path,
                size=variant_size,
                colors=colors,
                background=background,
            )
            variant_reward = DEFAULT_REWARDS[variant_size] if reward is None else reward
            if variant_reward < 0:
                raise ValueError("reward must not be negative")
            variant_lines.append(
                variant_source(
                    difficulty=SIZE_TO_DIFFICULTY[variant_size],
                    size=variant_size,
                    reward=variant_reward,
                    palette=palette,
                    pixels=pixels,
                )
            )
        module = f'''-- Generated by tools/image_to_luau.py --all-sizes.
-- The builder creates a difficulty dropdown from Variants.
return {{
    Id = {luau_string(safe_id)},
    Name = {luau_string(name)},
    PixelEncoding = "hex-nibble-v1",
    Variants = {{
{chr(10).join(variant_lines)}
    }},
}}
'''
        output_path.write_text(module, encoding="utf-8", newline="\n")
        print(f"Wrote {output_path} (32/64/128/256 variants, {colors} color limit)")
        return

    palette, pixels = quantize_image(
        input_path,
        size=size,
        colors=colors,
        background=background,
    )
    final_reward = DEFAULT_REWARDS[size] if reward is None else reward
    if final_reward < 0:
        raise ValueError("reward must not be negative")
    module = f'''-- Generated by tools/image_to_luau.py. Do not edit Pixels by hand.
-- PixelEncoding is hex-nibble-v1: one character per pixel, IDs 1..16.
return {{
    Id = {luau_string(safe_id)},
    Name = {luau_string(name)},
    Difficulty = {luau_string(SIZE_TO_DIFFICULTY[size])},
    Width = {size},
    Height = {size},
    Reward = {final_reward},
    PaletteSize = {len(palette)},
    PixelEncoding = "hex-nibble-v1",
    Palette = {{
{palette_source(palette, "        ")}
    }},
    Pixels = [[{pixels}]],
}}
'''
    output_path.write_text(module, encoding="utf-8", newline="\n")
    print(f"Wrote {output_path} ({size}x{size}, {colors} color limit)")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input", type=Path, help="source PNG or JPG")
    parser.add_argument("output", type=Path, help="destination .lua/.luau file")
    parser.add_argument("--size", type=int, choices=SIZES, default=32)
    parser.add_argument("--all-sizes", action="store_true", help="write Easy/Medium/Hard/Extreme variants")
    parser.add_argument("--colors", type=int, choices=range(4, 17), default=12)
    parser.add_argument("--id", dest="art_id", help="stable ID used in saved progress")
    parser.add_argument("--name", dest="display_name", help="name shown in the gallery")
    parser.add_argument("--reward", type=int, help="gem reward; for --all-sizes it applies to every variant")
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
            all_sizes=args.all_sizes,
        )
    except (OSError, RuntimeError, ValueError) as exc:
        parser.error(str(exc))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
