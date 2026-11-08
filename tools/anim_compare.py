"""HTML 연출 스크린샷(tools/html_anim_capture.js)과 Godot 스모크 스크린샷(smoke_anim)을 시각별로 나란히 붙인다 (E32).

사용: python3 tools/anim_compare.py <장면> <html 폴더> <godot 스크린샷 폴더> <출력.png> [자를 영역 x,y,w,h] [Godot 쪽 세로 차이]
(두 화면의 판 위치가 다르면 Godot 쪽을 세로 차이만큼 옮겨 자른다.)
위 줄 = HTML, 아래 줄 = Godot, 열 = 같은 시각(ms). 둘 다 405×720 창.
"""
import glob
import os
import sys

from PIL import Image, ImageDraw


def main() -> None:
    scene, html_dir, godot_dir, out = sys.argv[1:5]
    crop = tuple(int(v) for v in sys.argv[5].split(",")) if len(sys.argv) > 5 else None
    dy = int(sys.argv[6]) if len(sys.argv) > 6 else 0
    html = sorted(glob.glob(os.path.join(html_dir, f"{scene}_*.png")))
    tiles = []
    for path in html:
        ms = os.path.basename(path).split("_")[-1].split(".")[0]
        godot = os.path.join(godot_dir, f"smoke_anim_{scene}_{ms}.png")
        if not os.path.exists(godot):
            continue
        pair = [Image.open(path).convert("RGB"), Image.open(godot).convert("RGB")]
        if crop:
            x, y, w, h = crop
            pair = [pair[0].crop((x, y, x + w, y + h)), pair[1].crop((x, y + dy, x + w, y + h + dy))]
        tiles.append((ms, pair))
    if not tiles:
        sys.exit("no matching frames")
    w, h = tiles[0][1][0].size
    label = 22
    sheet = Image.new("RGB", (w * len(tiles), (h + label) * 2), (0, 0, 0))
    draw = ImageDraw.Draw(sheet)
    for i, (ms, pair) in enumerate(tiles):
        for row, im in enumerate(pair):
            sheet.paste(im, (i * w, row * (h + label) + label))
            draw.text((i * w + 4, row * (h + label) + 4), f"{'HTML' if row == 0 else 'Godot'} {int(ms)}ms", fill=(255, 255, 0))
    sheet.save(out)
    print(f"{out}: {len(tiles)} frames")


if __name__ == "__main__":
    main()
