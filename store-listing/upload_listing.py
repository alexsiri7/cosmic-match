#!/usr/bin/env python3
"""Upload store listing text and screenshots for Cosmic Match to Google Play."""

import json, os, io, random
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
from google.oauth2 import service_account
from googleapiclient.discovery import build
from googleapiclient.http import MediaIoBaseUpload

PKG  = 'net.interstellarai.cosmicmatch'
LANG = 'en-US'
BASE = Path(__file__).parent

FONT_BOLD = "/usr/share/fonts/truetype/ubuntu/Ubuntu-B.ttf"
FONT_REG  = "/usr/share/fonts/truetype/ubuntu/Ubuntu-R.ttf"
FONT_MED  = "/usr/share/fonts/truetype/ubuntu/Ubuntu-M.ttf"

W, H   = 1080, 1920
FW, FH = 1024, 500

TOP    = (8, 5, 30)
BOTTOM = (20, 10, 55)
ACCENT = (180, 130, 255)
GOLD   = (255, 210, 80)
WHITE  = (245, 240, 255)
DIM    = (180, 160, 220)

TILE_COLORS = [
    (255, 90,  90),
    (80,  180, 255),
    (100, 230, 120),
    (255, 200, 60),
    (200, 100, 255),
    (255, 150, 60),
]


def fnt(path, size):
    return ImageFont.truetype(path, size)


def gradient(size, top, bottom):
    w, h = size
    img = Image.new('RGBA', (w, h))
    for y in range(h):
        t = y / h
        r = int(top[0] * (1-t) + bottom[0] * t)
        g = int(top[1] * (1-t) + bottom[1] * t)
        b = int(top[2] * (1-t) + bottom[2] * t)
        for x in range(w):
            img.putpixel((x, y), (r, g, b, 255))
    return img


def add_stars(draw, n=130, seed=42):
    rng = random.Random(seed)
    for _ in range(n):
        x, y = rng.randint(0, W), rng.randint(0, H)
        r = rng.choice([1, 1, 1, 2, 2, 3])
        draw.ellipse([x-r, y-r, x+r, y+r], fill=(255, 255, 255, rng.randint(130, 255)))


def wrap_text(draw, text, x, y, max_w, font, fill, spacing=1.5):
    words = text.split()
    lines, cur = [], []
    for word in words:
        test = ' '.join(cur + [word])
        bx = draw.textbbox((0, 0), test, font=font)
        if bx[2] - bx[0] > max_w and cur:
            lines.append(' '.join(cur))
            cur = [word]
        else:
            cur.append(word)
    if cur:
        lines.append(' '.join(cur))
    for line in lines:
        draw.text((x, y), line, font=font, fill=fill)
        bx = draw.textbbox((0, 0), line, font=font)
        y += int((bx[3] - bx[1]) * spacing)
    return y


def screenshot_1():
    img = gradient((W, H), TOP, BOTTOM)
    d = ImageDraw.Draw(img, 'RGBA')
    add_stars(d, seed=7)

    cell, gap = 128, 10
    cols, rows = 6, 5
    grid_x = (W - cols * (cell + gap) + gap) // 2
    grid_y = 185
    rng = random.Random(99)
    for row in range(rows):
        for col in range(cols):
            c = TILE_COLORS[rng.randint(0, len(TILE_COLORS)-1)]
            x0 = grid_x + col * (cell + gap)
            y0 = grid_y + row * (cell + gap)
            alpha = 185 if row < 3 else 90 if row == 3 else 25
            d.rounded_rectangle([x0, y0, x0+cell, y0+cell], radius=16,
                                 fill=(*c, alpha), outline=(255, 255, 255, 50), width=2)
            d.ellipse([x0+10, y0+10, x0+34, y0+34], fill=(255, 255, 255, 45))

    fade_start = grid_y + rows * (cell + gap) - 180
    fade_end   = grid_y + rows * (cell + gap) + gap
    for y in range(fade_start, fade_end):
        a = int(255 * (y - fade_start) / (fade_end - fade_start))
        d.line([(0, y), (W, y)], fill=(*TOP, a))

    d.text((W//2, 1090), "Cosmic Match", font=fnt(FONT_BOLD, 95), fill=WHITE, anchor='mm')
    d.text((W//2, 1200), "Space Puzzle Adventure", font=fnt(FONT_MED, 46), fill=ACCENT, anchor='mm')
    d.rectangle([W//2-155, 1258, W//2+155, 1261], fill=(*ACCENT, 90))
    wrap_text(d, "Match three or more gems to clear the board. Create cascades for stellar high scores.",
              80, 1305, W-160, fnt(FONT_REG, 38), DIM)
    return img.convert('RGB')


def screenshot_2():
    img = gradient((W, H), TOP, BOTTOM)
    d = ImageDraw.Draw(img, 'RGBA')
    add_stars(d, n=80, seed=42)
    d.text((W//2, 155), "How to play", font=fnt(FONT_BOLD, 70), fill=WHITE, anchor='mm')
    d.rectangle([160, 208, W-160, 211], fill=(*ACCENT, 80))

    features = [
        ("Swap gems",        "Tap two adjacent tiles to swap them"),
        ("Match 3 or more",  "Align same-color gems in a row or column"),
        ("Cascade combos",   "Chain matches for exponential score bonuses"),
        ("Gravity physics",  "Gems fall and fill gaps after each match"),
        ("Auto-saved",       "Progress saved automatically on your device"),
    ]
    icons = ["💎", "✨", "🌊", "🚀", "💾"]

    y = 295
    for (title, sub), icon in zip(features, icons):
        d.rounded_rectangle([60, y, W-60, y+185], radius=18, fill=(255, 255, 255, 10))
        d.text((108, y+46), icon, font=fnt(FONT_BOLD, 56), fill=ACCENT)
        d.text((210, y+32), title, font=fnt(FONT_BOLD, 44), fill=WHITE)
        d.text((210, y+92), sub,   font=fnt(FONT_REG,  34), fill=DIM)
        y += 210
    return img.convert('RGB')


def screenshot_3():
    img = gradient((W, H), TOP, BOTTOM)
    d = ImageDraw.Draw(img, 'RGBA')
    add_stars(d, n=100, seed=13)
    d.text((W//2, 155), "Features", font=fnt(FONT_BOLD, 70), fill=WHITE, anchor='mm')
    d.rectangle([160, 208, W-160, 211], fill=(*ACCENT, 80))

    items = [
        ("🎮", "Addictive gameplay",   "Easy to learn, hard to master"),
        ("🌌", "Space theme",          "Stars, gems, and cosmic visuals"),
        ("⚡", "Smooth animations",    "Fluid tile swaps and cascade effects"),
        ("📵", "Play offline",         "No internet needed to play"),
        ("🔒", "No account needed",    "No sign-in, no data collected"),
    ]
    y = 295
    for icon, title, sub in items:
        d.rounded_rectangle([60, y, W-60, y+185], radius=18, fill=(255, 255, 255, 10))
        d.text((108, y+46), icon, font=fnt(FONT_BOLD, 56), fill=ACCENT)
        d.text((210, y+32), title, font=fnt(FONT_BOLD, 44), fill=WHITE)
        d.text((210, y+92), sub,   font=fnt(FONT_REG,  34), fill=DIM)
        y += 210
    return img.convert('RGB')


def feature_graphic():
    img = gradient((FW, FH), TOP, BOTTOM)
    d = ImageDraw.Draw(img, 'RGBA')
    rng = random.Random(5)
    for _ in range(80):
        x, y = rng.randint(0, FW), rng.randint(0, FH)
        r = rng.choice([1, 1, 2, 2, 3])
        d.ellipse([x-r, y-r, x+r, y+r], fill=(255, 255, 255, rng.randint(80, 200)))
    # Gem strip
    for i, c in enumerate(TILE_COLORS):
        x0 = FW//2 - len(TILE_COLORS)*35 + i*70
        d.rounded_rectangle([x0, 42, x0+60, 102], radius=10, fill=(*c, 165))
    d.text((FW//2, 265), "Cosmic Match", font=fnt(FONT_BOLD, 90), fill=WHITE, anchor='mm')
    d.text((FW//2, 358), "Space Puzzle  •  Match 3  •  Cascade Combos", font=fnt(FONT_MED, 36), fill=ACCENT, anchor='mm')
    d.text((FW//2, 440), "Free to play · No ads · No account needed", font=fnt(FONT_REG, 30), fill=DIM, anchor='mm')
    return img.convert('RGB')


def upload_image(svc, eid, img_type, img):
    buf = io.BytesIO()
    img.save(buf, format='PNG')
    buf.seek(0)
    media = MediaIoBaseUpload(buf, mimetype='image/png')
    return svc.edits().images().upload(
        packageName=PKG, editId=eid, language=LANG,
        imageType=img_type, media_body=media
    ).execute()


def main():
    creds = service_account.Credentials.from_service_account_info(
        json.loads(os.environ['PLAY_SERVICE_ACCOUNT_JSON']),
        scopes=['https://www.googleapis.com/auth/androidpublisher']
    )
    svc = build('androidpublisher', 'v3', credentials=creds)

    edit = svc.edits().insert(packageName=PKG, body={}).execute()
    eid  = edit['id']
    print(f"Edit created: {eid}")

    listing = {
        'language':         LANG,
        'title':            (BASE / 'en-US/title.txt').read_text().strip(),
        'shortDescription': (BASE / 'en-US/short_description.txt').read_text().strip(),
        'fullDescription':  (BASE / 'en-US/full_description.txt').read_text().strip(),
    }
    svc.edits().listings().update(packageName=PKG, editId=eid, language=LANG, body=listing).execute()
    print("Listing text updated")

    for img_type in ('phoneScreenshots', 'featureGraphic'):
        try:
            svc.edits().images().deleteall(packageName=PKG, editId=eid, language=LANG, imageType=img_type).execute()
            print(f"Cleared existing {img_type}")
        except Exception as e:
            print(f"No existing {img_type} to clear ({e})")

    for i, img in enumerate([screenshot_1(), screenshot_2(), screenshot_3()], 1):
        upload_image(svc, eid, 'phoneScreenshots', img)
        print(f"Uploaded screenshot {i}")

    upload_image(svc, eid, 'featureGraphic', feature_graphic())
    print("Uploaded feature graphic")

    result = svc.edits().commit(packageName=PKG, editId=eid).execute()
    print(f"Edit committed: {result['id']}")


if __name__ == '__main__':
    main()
