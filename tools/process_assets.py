import math
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter
import numpy as np

PROJECT = Path(__file__).resolve().parents[1]
RAW = PROJECT / "raw_assets"
DEST = PROJECT / "assets" / "images"
BRAIN = Path.home() / ".gemini" / "antigravity" / "brain" / "b6c935ea-a8e6-447e-8b0b-be8c9cf69df0"
FALLBACK_ASSETS = Path.home() / "Desktop" / "tactic_goal_assets" / "assets" / "images"

ASSET_SPECS = {
    "tiles": {
        "tile_grass_light.png": (256, 192),
        "tile_grass_dark.png": (256, 192),
        "tile_mud.png": (256, 192),
        "tile_ice.png": (256, 192),
        "tile_ramp_ne.png": (256, 192),
        "tile_ramp_nw.png": (256, 192),
        "tile_ramp_se.png": (256, 192),
        "tile_ramp_sw.png": (256, 192),
        "tile_target_zone.png": (256, 192),
    },
    "entities": {
        "ball.png": (256, 256),
        "player_teammate.png": (256, 256),
        "player_defender.png": (256, 256),
        "player_goalkeeper.png": (256, 256),
        "goal_front.png": (256, 256),
        "goal_side.png": (256, 256),
        "obstacle_cone.png": (256, 256),
        "obstacle_barrier.png": (256, 256),
    },
    "ui": {
        "card_shoot.png": (256, 360),
        "card_pass.png": (256, 360),
        "card_lob.png": (256, 360),
        "card_curve.png": (256, 360),
        "icon_undo.png": (128, 128),
        "icon_restart.png": (128, 128),
        "icon_settings.png": (128, 128),
        "icon_sound_on.png": (128, 128),
        "icon_sound_off.png": (128, 128),
        "icon_leagues.png": (128, 128),
        "arrow_guide.png": (128, 128),
        "indicator_valid.png": (128, 128),
        "indicator_invalid.png": (128, 128),
    },
}

def remove_white_background(img: Image.Image, threshold: int = 240, tolerance: int = 25) -> Image.Image:
    """Removes solid/off-white background using edge-connected flood fill & color thresholding."""
    rgba = img.convert("RGBA")
    arr = np.array(rgba, dtype=np.uint8)
    r, g, b, a = arr[:, :, 0], arr[:, :, 1], arr[:, :, 2], arr[:, :, 3]
    
    # Check brightness and low saturation (white/off-white)
    brightness = (r.astype(np.int32) + g.astype(np.int32) + b.astype(np.int32)) // 3
    color_diff = np.maximum.reduce([np.abs(r - g), np.abs(g - b), np.abs(b - r)])
    
    is_white = (brightness >= threshold) & (color_diff <= tolerance)
    
    # Calculate alpha mask: fully transparent where is_white, smooth transition near boundary
    alpha_channel = np.where(is_white, 0, 255).astype(np.uint8)
    
    # Smooth edges with feathering
    mask_img = Image.fromarray(alpha_channel, mode='L')
    mask_img = mask_img.filter(ImageFilter.GaussianBlur(radius=0.75))
    
    rgba.putalpha(mask_img)
    return rgba

def create_ball_shadow(size: tuple[int, int] = (256, 256)) -> Image.Image:
    """Creates a smooth soft black elliptical shadow for the ball."""
    img = Image.new("RGBA", size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    cx, cy = size[0] // 2, size[1] // 2 + 35
    rx, ry = 64, 28
    
    # Draw nested ellipses with increasing transparency
    for i in range(24, 0, -1):
        alpha = int(120 * (1 - i / 24))
        cur_rx = rx + i * 2
        cur_ry = ry + int(i * 1.2)
        draw.ellipse(
            [cx - cur_rx, cy - cur_ry, cx + cur_rx, cy + cur_ry],
            fill=(20, 30, 20, alpha)
        )
    return img.filter(ImageFilter.GaussianBlur(radius=6))

def locate_source_file(category: str, filename: str) -> Path | None:
    stem = Path(filename).stem
    candidates = [
        RAW / category / f"{stem}.jpg",
        RAW / category / f"{stem}.png",
        RAW / f"{stem}.jpg",
        RAW / f"{stem}.png",
    ]
    # Check brain directory for subagent-generated images
    for brain_file in sorted(BRAIN.glob(f"*{stem}*.jpg")):
        candidates.append(brain_file)
    for brain_file in sorted(BRAIN.glob(f"*{stem}*.png")):
        candidates.append(brain_file)
    # Check fallback directory
    candidates.append(FALLBACK_ASSETS / category / filename)
    candidates.append(FALLBACK_ASSETS.parent.parent / category / filename)
    
    for candidate in candidates:
        if candidate.exists() and candidate.is_file():
            return candidate
    return None

def process_single_asset(src: Path, dest: Path, target_size: tuple[int, int]) -> None:
    with Image.open(src) as opened:
        img = opened.convert("RGBA")
    
    # If source already has alpha and not fully opaque, keep it or trim white
    arr = np.array(img)
    min_alpha = arr[:, :, 3].min()
    
    if min_alpha > 240:
        # Source has solid background (white) -> remove white
        img = remove_white_background(img)
    
    # Trim empty / transparent margins
    bbox = img.getchannel("A").getbbox()
    if bbox is not None:
        img = img.crop(bbox)
    
    # Scale to target size with padding
    pad = 12
    max_w = max(1, target_size[0] - pad * 2)
    max_h = max(1, target_size[1] - pad * 2)
    img.thumbnail((max_w, max_h), Image.Resampling.LANCZOS)
    
    # Center on canvas
    canvas = Image.new("RGBA", target_size, (0, 0, 0, 0))
    offset = ((target_size[0] - img.width) // 2, (target_size[1] - img.height) // 2)
    canvas.alpha_composite(img, offset)
    
    dest.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(dest, "PNG", optimize=True)

def main():
    print("=== Processing Tactic Goal Game Assets ===")
    total = 0
    
    # 1. Process all tile, entity, ui assets
    for category, items in ASSET_SPECS.items():
        for filename, size in items.items():
            src = locate_source_file(category, filename)
            dest = DEST / category / filename
            if src and src.exists():
                process_single_asset(src, dest, size)
                print(f"[OK] {category}/{filename} <= {src.name} (size: {size})")
                total += 1
            else:
                print(f"[WARN] Source not found for {category}/{filename}")
    
    # 2. Generate smooth ball shadow
    shadow_dest = DEST / "entities" / "ball_shadow.png"
    shadow_img = create_ball_shadow((256, 256))
    shadow_img.save(shadow_dest, "PNG", optimize=True)
    print(f"[OK] entities/ball_shadow.png generated")
    total += 1
    
    print(f"=== Successfully processed {total} assets in {DEST} ===")

if __name__ == "__main__":
    main()
