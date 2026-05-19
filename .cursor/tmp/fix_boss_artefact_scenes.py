import re
from pathlib import Path

root = Path(r"D:/Games/game/scene/pick_up/artefacts")
nested = root / "scene/pick_up/artefacts"
arts = [
    "small_cactus", "lime_juice", "ramen_bowl", "pill", "pill_can", "juice_box",
    "fairy_bottle", "flashlight", "top_hat", "snow_ball", "disco_ball", "bongo",
]
for name in arts:
    src = nested / f"{name}.tscn"
    dst = root / f"{name}.tscn"
    if not src.is_file():
        print("missing src", name)
        continue
    old_uid = None
    if dst.is_file():
        m = re.search(r'uid="(uid://[^"]+)"', dst.read_text(encoding="utf-8"))
        old_uid = m.group(1) if m else None
    content = src.read_text(encoding="utf-8")
    if old_uid:
        content = re.sub(r'uid="uid://[^"]+"', f'uid="{old_uid}"', content, count=1)
    dst.write_text(content, encoding="utf-8")
    print("updated", name, "uid kept:", old_uid)
