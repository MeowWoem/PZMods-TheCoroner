import sys, os
from PIL import Image

SRC, MOD_TEX, LUA_OUT = sys.argv[1], sys.argv[2], sys.argv[3]

ORGANS = [
    ("heart", "organ_heart", 2),
    ("lung_l", "organ_lung_l", 3),
    ("lung_r", "organ_lung_r", 4),
    ("liver", "organ_liver", 5),
    ("stomach", "organ_stomach", 6),
    ("intestines", "organs_intestines", 7),
    ("pancreas", "organs_pancreas", 8),
    ("kidney_r", "organ_kidney_r", 9),
    ("kidney_l", "organ_kidney_l", 10),
    ("spleen", "organ_spleen", 11),
    ("bladder", "organ_bladder", 12),
]
CANVAS_W, CANVAS_H, SCALE, ORIGIN_X, ORIGIN_Y = 520, 1020, 2, 130, 20

def num(v):
    return ("%.1f" % v).rstrip("0").rstrip(".")

out_dir = os.path.join(MOD_TEX, "organs")
os.makedirs(out_dir, exist_ok=True)
lines = ["require \"TCA_Shared\";", "", "TCA.Organs = TCA.Organs or {};", "", "TCA.Organs.LIST = {"]
for oid, src_name, step in ORGANS:
    path = os.path.join(SRC, src_name + ".png")
    if not os.path.exists(path):
        path = os.path.join(SRC, src_name.replace("organs_", "organ_") + ".png")
    im = Image.open(path).convert("RGBA")
    if im.size != (CANVAS_W, CANVAS_H):
        sys.exit("bad size: %s %s" % (path, im.size))
    bb = im.split()[-1].getbbox()
    crop = im.crop(bb)
    name = "organ_" + oid
    crop.save(os.path.join(out_dir, name + ".png"), optimize=True)
    x = bb[0] / SCALE - ORIGIN_X
    y = bb[1] / SCALE - ORIGIN_Y
    w = (bb[2] - bb[0]) / SCALE
    h = (bb[3] - bb[1]) / SCALE
    lines.append("    { id = \"%s\", step = %d, texture = \"media/textures/organs/%s.png\", x = %s, y = %s, w = %s, h = %s }," % (oid, step, name, num(x), num(y), num(w), num(h)))
    print("%-11s step %2d  crop %3dx%-3d  corps x %6s y %6s w %5s h %5s" % (oid, step, crop.size[0], crop.size[1], num(x), num(y), num(w), num(h)))
lines += ["};", "", "function TCA.Organs.getById(id)", "    for _, organ in ipairs(TCA.Organs.LIST) do", "        if organ.id == id then", "            return organ;", "        end", "    end", "    return nil;", "end", "", "function TCA.Organs.getByStep(step)", "    for _, organ in ipairs(TCA.Organs.LIST) do", "        if organ.step == step then", "            return organ;", "        end", "    end", "    return nil;", "end"]
open(LUA_OUT, "w").write("\n".join(lines) + "\n")
