"""
Cut man/woman silhouettes from wo_man.jpg:
  - Top-left quadrant  = filled female symbol
  - Bottom-left quadrant = filled male symbol
Output: woman_sil.png, man_sil.png
  - transparent background
  - same canvas size (padded to largest bounding box, centred)
"""
from PIL import Image
import numpy as np

src = Image.open("wo_man.jpg").convert("RGBA")
w, h = src.size
mid_x, mid_y = w // 2, h // 2

# Crop the two filled quadrants
woman_q = src.crop((0,      0,      mid_x, mid_y))
man_q   = src.crop((0,      mid_y,  mid_x, h    ))

def make_transparent(img, threshold=200):
    """White-ish pixels become fully transparent."""
    data = np.array(img, dtype=np.uint8)
    r, g, b, a = data[...,0], data[...,1], data[...,2], data[...,3]
    white_mask = (r > threshold) & (g > threshold) & (b > threshold)
    data[..., 3] = np.where(white_mask, 0, 255)
    return Image.fromarray(data, "RGBA")

def tight_bbox(img):
    """Return bounding box of non-transparent pixels."""
    data = np.array(img)
    alpha = data[..., 3]
    rows = np.any(alpha > 0, axis=1)
    cols = np.any(alpha > 0, axis=0)
    rmin, rmax = np.where(rows)[0][[0, -1]]
    cmin, cmax = np.where(cols)[0][[0, -1]]
    return (int(cmin), int(rmin), int(cmax)+1, int(rmax)+1)

woman_t = make_transparent(woman_q)
man_t   = make_transparent(man_q)

wb = tight_bbox(woman_t)
mb = tight_bbox(man_t)

# Crop tight
woman_crop = woman_t.crop(wb)
man_crop   = man_t.crop(mb)

# Pad both to the same size (max of the two bounding boxes), centred
out_w = max(woman_crop.width,  man_crop.width)
out_h = max(woman_crop.height, man_crop.height)

def centre_on_canvas(img, cw, ch):
    canvas = Image.new("RGBA", (cw, ch), (0, 0, 0, 0))
    ox = (cw - img.width)  // 2
    oy = (ch - img.height) // 2
    canvas.paste(img, (ox, oy), img)
    return canvas

woman_out = centre_on_canvas(woman_crop, out_w, out_h)
man_out   = centre_on_canvas(man_crop,   out_w, out_h)

woman_out.save("woman_sil.png")
man_out.save("man_sil.png")
print(f"Saved: {out_w}x{out_h} px each")
print(f"  woman_sil.png  (cropped bbox {wb})")
print(f"  man_sil.png    (cropped bbox {mb})")
