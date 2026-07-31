"""Crop transparent HUD masters and emit memory-conscious runtime textures."""

from pathlib import Path

from PIL import Image


PROJECT_ROOT = Path(__file__).resolve().parents[2]
HUD_ROOT = PROJECT_ROOT / "assets" / "ui" / "hud"
RUNTIME_ROOT = HUD_ROOT / "runtime"

ASSETS = {
    "portrait_frame_v1.png": ("portrait_frame.png", 512),
    "action_slot_frame_v1.png": ("action_slot_frame.png", 192),
    "minimap_frame_v1.png": ("minimap_frame_metal.png", 640),
    "minimap_frame_parchment_v2.png": ("minimap_frame_parchment.png", 640),
    "resource_bar_frame_v1.png": ("resource_bar_frame.png", 640),
    "pause_panel_v1.png": ("pause_panel.png", 640),
    "menu_button_v1.png": ("menu_button.png", 640),
    "map_screen_frame_v1.png": ("map_screen_frame.png", 1280),
    "map_viewport_frame_v1.png": ("map_viewport_frame.png", 1280),
    "map_menu_shell_v1.png": ("map_menu_shell.png", 1280),
    "world_atlas_shell_v1.png": ("world_atlas_shell.png", 1280),
}

FULL_CANVAS_ASSETS = {"map_menu_shell_v1.png", "world_atlas_shell_v1.png"}


def prepare(source_name: str, output_name: str, target_width: int) -> None:
    source_path = HUD_ROOT / source_name
    image = Image.open(source_path).convert("RGBA")
    alpha_bbox = image.getchannel("A").getbbox()
    if alpha_bbox is None:
        raise ValueError(f"{source_name} has no visible pixels")

    if source_name in FULL_CANVAS_ASSETS:
        cropped = image
    else:
        padding = max(8, round(max(image.size) * 0.012))
        left = max(alpha_bbox[0] - padding, 0)
        top = max(alpha_bbox[1] - padding, 0)
        right = min(alpha_bbox[2] + padding, image.width)
        bottom = min(alpha_bbox[3] + padding, image.height)
        cropped = image.crop((left, top, right, bottom))

    target_height = 720 if source_name in FULL_CANVAS_ASSETS else max(
        1, round(cropped.height * target_width / cropped.width)
    )
    runtime = cropped.resize((target_width, target_height), Image.Resampling.LANCZOS)
    output_path = RUNTIME_ROOT / output_name
    output_path.parent.mkdir(parents=True, exist_ok=True)
    runtime.save(output_path, optimize=True)

    if source_name not in FULL_CANVAS_ASSETS and runtime.getpixel((0, 0))[3] != 0:
        raise ValueError(f"{output_name} does not have a transparent corner")
    if source_name in FULL_CANVAS_ASSETS:
        center = runtime.getpixel((runtime.width // 2, runtime.height // 2))
        if center[3] != 0:
            raise ValueError(f"{output_name} does not have a transparent map opening")
    print(f"{source_name} -> {output_path.relative_to(PROJECT_ROOT)} {runtime.size}")


if __name__ == "__main__":
    for source, (output, width) in ASSETS.items():
        prepare(source, output, width)
