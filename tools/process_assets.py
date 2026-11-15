from pathlib import Path
from PIL import Image


PROJECT = Path(__file__).resolve().parents[1]
BLENDER = Path.home() / "Desktop" / "tactic_goal_assets" / "assets" / "images"
OLD_PACK = Path.home() / "Desktop" / "tactic_goal_assets"
DEST = PROJECT / "assets" / "images"

ASSETS = {
    "tiles": {
        "tile_grass_light.png": BLENDER / "tiles" / "tile_grass_light.png",
        "tile_grass_dark.png": BLENDER / "tiles" / "tile_grass_dark.png",
        "tile_mud.png": BLENDER / "tiles" / "tile_mud.png",
        "tile_ice.png": BLENDER / "tiles" / "tile_ice.png",
        "tile_ramp_ne.png": BLENDER / "tiles" / "tile_ramp_ne.png",
        "tile_ramp_nw.png": BLENDER / "tiles" / "tile_ramp_nw.png",
        "tile_ramp_se.png": BLENDER / "tiles" / "tile_ramp_se.png",
        "tile_ramp_sw.png": BLENDER / "tiles" / "tile_ramp_sw.png",
        "tile_target_zone.png": BLENDER / "tiles" / "tile_target_zone.png",
    },
    "entities": {
        "ball.png": BLENDER / "entities" / "ball.png",
        "ball_shadow.png": OLD_PACK / "entities" / "ball_shadow.png",
        "player_teammate.png": BLENDER / "entities" / "player_teammate.png",
        "player_defender.png": BLENDER / "entities" / "player_defender.png",
        "player_goalkeeper.png": BLENDER / "entities" / "player_goalkeeper.png",
        "goal_front.png": BLENDER / "entities" / "goal_front.png",
        "goal_side.png": BLENDER / "entities" / "goal_side.png",
        "obstacle_cone.png": BLENDER / "entities" / "obstacle_cone.png",
        "obstacle_barrier.png": BLENDER / "entities" / "obstacle_barrier.png",
    },
    "ui": {
        "card_shoot.png": BLENDER / "ui" / "card_shoot.png",
        "card_pass.png": BLENDER / "ui" / "card_pass.png",
        "card_lob.png": BLENDER / "ui" / "card_lob.png",
        "card_curve.png": OLD_PACK / "ui" / "card_curve.png",
        "icon_undo.png": BLENDER / "ui" / "icon_undo.png",
        "icon_restart.png": BLENDER / "ui" / "icon_restart.png",
        "icon_settings.png": BLENDER / "ui" / "icon_settings.png",
        "icon_sound_on.png": OLD_PACK / "ui" / "icon_sound_on.png",
        "icon_sound_off.png": BLENDER / "ui" / "icon_sound_off.png",
        "icon_leagues.png": BLENDER / "ui" / "icon_leagues.png",
        "arrow_guide.png": BLENDER / "ui" / "arrow_guide.png",
        "indicator_valid.png": BLENDER / "ui" / "indicator_valid.png",
        "indicator_invalid.png": BLENDER / "ui" / "indicator_invalid.png",
    },
}


def target_size(category: str, filename: str) -> tuple[int, int]:
    if category == "tiles":
        return (256, 192)
    if category == "entities":
        return (256, 256)
    if filename.startswith("card_"):
        return (256, 360)
    return (128, 128)


def process(source: Path, destination: Path, size: tuple[int, int]) -> None:
    if not source.is_file():
        raise FileNotFoundError(f"Required source image is missing: {source}")
    with Image.open(source) as opened:
        image = opened.convert("RGBA")
    bounds = image.getchannel("A").getbbox()
    if bounds is not None:
        image = image.crop(bounds)
    inner = (max(1, size[0] - 12), max(1, size[1] - 12))
    image.thumbnail(inner, Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", size, (0, 0, 0, 0))
    canvas.alpha_composite(image, ((size[0] - image.width) // 2,
                                   (size[1] - image.height) // 2))
    destination.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(destination, "PNG", optimize=True)
    with Image.open(destination) as check:
        check.verify()


def main() -> None:
    count = 0
    for category, files in ASSETS.items():
        for filename, source in files.items():
            process(source, DEST / category / filename, target_size(category, filename))
            count += 1
            print(f"Processed {category}/{filename}")
    print(f"Prepared {count} transparent game assets at {DEST}")


if __name__ == "__main__":
    main()
