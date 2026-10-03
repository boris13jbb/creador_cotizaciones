"""Genera el icono de CotiApp y lo despliega en Android, iOS, Web y Windows.

Uso:
  python tool/generate_app_icons.py
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
FOREST = (45, 106, 79, 255)  # #2D6A4F
FOREST_B = (64, 145, 108, 255)  # #40916C
WHITE = (255, 255, 255, 255)
MIST = (243, 246, 244, 255)


def lerp(a: tuple[int, ...], b: tuple[int, ...], t: float) -> tuple[int, ...]:
  return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(4))


def make_master(size: int = 1024, safe_inset: float = 0.0) -> Image.Image:
  img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
  draw = ImageDraw.Draw(img)

  for y in range(size):
    t = y / max(size - 1, 1)
    draw.line([(0, y), (size, y)], fill=lerp(FOREST_B, FOREST, t))

  inset = int(size * safe_inset)
  area = size - 2 * inset
  s = area / 1024

  def x(v: float) -> int:
    return inset + int(v * s)

  def y(v: float) -> int:
    return inset + int(v * s)

  def r(v: float) -> int:
    return max(1, int(v * s))

  doc = [x(280), y(190), x(744), y(820)]
  shadow = [doc[0] + r(18), doc[1] + r(22), doc[2] + r(18), doc[3] + r(22)]
  draw.rounded_rectangle(shadow, radius=r(48), fill=(0, 0, 0, 55))
  draw.rounded_rectangle(doc, radius=r(48), fill=WHITE)

  fold = [(x(560), y(190)), (x(744), y(190)), (x(744), y(374))]
  draw.polygon(fold, fill=MIST)
  draw.line(
    [(x(560), y(190)), (x(560), y(374)), (x(744), y(374))],
    fill=(220, 228, 222, 255),
    width=r(6),
  )

  line_left, line_right = x(340), x(640)
  for i, top in enumerate((430, 510, 590, 670)):
    right = line_right if i < 3 else x(520)
    draw.rounded_rectangle(
      [line_left, y(top), right, y(top + 36)],
      radius=r(12),
      fill=FOREST if i == 0 else (210, 222, 214, 255),
    )

  cx, cy, rad = x(700), y(700), r(90)
  draw.ellipse([cx - rad, cy - rad, cx + rad, cy + rad], fill=FOREST)
  draw.line(
    [(cx - r(34), cy), (cx - r(8), cy + r(30)), (cx + r(40), cy - r(28))],
    fill=WHITE,
    width=r(22),
  )
  return img


def resize_cover(src: Image.Image, size: int) -> Image.Image:
  return src.resize((size, size), Image.Resampling.LANCZOS)


def main() -> None:
  master = make_master(1024, safe_inset=0.0)
  master_safe = make_master(1024, safe_inset=0.12)

  branding = ROOT / 'assets' / 'branding'
  branding.mkdir(parents=True, exist_ok=True)
  master.save(branding / 'app_icon_1024.png')
  master_safe.save(branding / 'app_icon_maskable_1024.png')

  android_sizes = {
    'mipmap-mdpi': 48,
    'mipmap-hdpi': 72,
    'mipmap-xhdpi': 96,
    'mipmap-xxhdpi': 144,
    'mipmap-xxxhdpi': 192,
  }
  for folder, sz in android_sizes.items():
    out = ROOT / 'android' / 'app' / 'src' / 'main' / 'res' / folder / 'ic_launcher.png'
    resize_cover(master, sz).save(out, 'PNG')

  web = ROOT / 'web'
  resize_cover(master, 32).save(web / 'favicon.png', 'PNG')
  resize_cover(master, 192).save(web / 'icons' / 'Icon-192.png', 'PNG')
  resize_cover(master, 512).save(web / 'icons' / 'Icon-512.png', 'PNG')
  resize_cover(master_safe, 192).save(web / 'icons' / 'Icon-maskable-192.png', 'PNG')
  resize_cover(master_safe, 512).save(web / 'icons' / 'Icon-maskable-512.png', 'PNG')

  ico_sizes = [16, 24, 32, 48, 64, 128, 256]
  ico_images = [resize_cover(master, s) for s in ico_sizes]
  ico_path = ROOT / 'windows' / 'runner' / 'resources' / 'app_icon.ico'
  ico_images[-1].save(ico_path, format='ICO', sizes=[(s, s) for s in ico_sizes])

  ios_dir = ROOT / 'ios' / 'Runner' / 'Assets.xcassets' / 'AppIcon.appiconset'
  ios_files = {
    'Icon-App-20x20@1x.png': 20,
    'Icon-App-20x20@2x.png': 40,
    'Icon-App-20x20@3x.png': 60,
    'Icon-App-29x29@1x.png': 29,
    'Icon-App-29x29@2x.png': 58,
    'Icon-App-29x29@3x.png': 87,
    'Icon-App-40x40@1x.png': 40,
    'Icon-App-40x40@2x.png': 80,
    'Icon-App-40x40@3x.png': 120,
    'Icon-App-60x60@2x.png': 120,
    'Icon-App-60x60@3x.png': 180,
    'Icon-App-76x76@1x.png': 76,
    'Icon-App-76x76@2x.png': 152,
    'Icon-App-83.5x83.5@2x.png': 167,
    'Icon-App-1024x1024@1x.png': 1024,
  }
  for name, sz in ios_files.items():
    resize_cover(master, sz).save(ios_dir / name, 'PNG')

  print('Iconos CotiApp generados en Android, iOS, Web y Windows.')


if __name__ == '__main__':
  main()
