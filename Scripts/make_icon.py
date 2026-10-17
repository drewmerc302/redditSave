# Draws the app icon: white download arrow into a tray on an orange gradient.
# Usage: python3 Scripts/make_icon.py RedditSave/Assets.xcassets/AppIcon.appiconset/icon-1024.png
import sys
from PIL import Image, ImageDraw

S = 1024
out = sys.argv[1]

img = Image.new("RGB", (S, S))
top, bottom = (255, 120, 40), (235, 60, 20)
for y in range(S):
    t = y / (S - 1)
    c = tuple(round(a + (b - a) * t) for a, b in zip(top, bottom))
    for x in range(S):
        img.putpixel((x, y), c)

d = ImageDraw.Draw(img)
W = (255, 255, 255)
# Arrow shaft and head.
d.rounded_rectangle((452, 210, 572, 560), radius=40, fill=W)
d.polygon([(292, 500), (732, 500), (512, 720)], fill=W)
# Tray.
d.rounded_rectangle((232, 640, 312, 830), radius=40, fill=W)
d.rounded_rectangle((712, 640, 792, 830), radius=40, fill=W)
d.rounded_rectangle((232, 760, 792, 840), radius=40, fill=W)

img.save(out)
print("wrote", out)
