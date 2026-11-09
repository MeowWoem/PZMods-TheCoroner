import sys, os, math
from PIL import Image

SRC, MOD_TEX, LUA_OUT = sys.argv[1], sys.argv[2], sys.argv[3]

ORGANS = [
    ("heart", "organ_heart", 2, [(-1, 121), (7, 122)]),
    ("lung_l", "organ_lung_l", 3, [(9, 128)]),
    ("lung_r", "organ_lung_r", 4, [(-9, 128)]),
    ("liver", "organ_liver", 5, [(2, 152), (-8, 160)]),
    ("stomach", "organ_stomach", 6, [(5, 150), (-8, 174)]),
    ("intestines", "organs_intestines", 7, [(-18, 177), (8, 217)]),
    ("pancreas", "organs_pancreas", 8, [(-2, 175)]),
    ("kidney_r", "organ_kidney_r", 9, [(-10, 165)]),
    ("kidney_l", "organ_kidney_l", 10, [(10, 165)]),
    ("spleen", "organ_spleen", 11, [(22, 163)]),
    ("bladder", "organ_bladder", 12, [(1, 219)]),
]
PIECES = [
    ("PLASTRON", "plastron", "plastron"),
]
CANVAS_W, CANVAS_H, SCALE, ORIGIN_X, ORIGIN_Y = 520, 1020, 2, 130, 20
MASK_ALPHA = 128
CROP_ALPHA = 32
CROP_MARGIN = 2
ATTACH_HALF = 5

def num(v):
    return ("%.1f" % v).rstrip("0").rstrip(".")

def find_source(name):
    for candidate in (name, name.replace("organs_", "organ_"), name.replace("organ_", "organs_")):
        path = os.path.join(SRC, candidate + ".png")
        if os.path.exists(path):
            return path
    sys.exit("missing source: " + name)

out_dir = os.path.join(MOD_TEX, "organs")
os.makedirs(out_dir, exist_ok=True)

def load_piece(src_name, name):
    im = Image.open(find_source(src_name)).convert("RGBA")
    if im.size != (CANVAS_W, CANVAS_H):
        sys.exit("bad size: %s %s" % (src_name, im.size))
    core = im.split()[-1].point(lambda v: 255 if v >= CROP_ALPHA else 0).getbbox()
    bb = (max(core[0] - CROP_MARGIN, 0), max(core[1] - CROP_MARGIN, 0), min(core[2] + CROP_MARGIN, CANVAS_W), min(core[3] + CROP_MARGIN, CANVAS_H))
    bb = (bb[0] - bb[0] % SCALE, bb[1] - bb[1] % SCALE, bb[2] + (bb[2] % SCALE), bb[3] + (bb[3] % SCALE))
    crop = im.crop(bb)
    crop.save(os.path.join(out_dir, name + ".png"), optimize=True)
    x = bb[0] / SCALE - ORIGIN_X
    y = bb[1] / SCALE - ORIGIN_Y
    w = (bb[2] - bb[0]) / SCALE
    h = (bb[3] - bb[1]) / SCALE
    alpha = crop.split()[-1].load()
    cols = (crop.size[0] + SCALE - 1) // SCALE
    rows = (crop.size[1] + SCALE - 1) // SCALE
    mask = []
    for cy in range(rows):
        row = []
        for cx in range(cols):
            total, count = 0, 0
            for py in range(cy * SCALE, min((cy + 1) * SCALE, crop.size[1])):
                for px in range(cx * SCALE, min((cx + 1) * SCALE, crop.size[0])):
                    total += alpha[px, py]
                    count += 1
            row.append("1" if total / count >= MASK_ALPHA else "0")
        mask.append("".join(row))
    return crop, x, y, w, h, cols, rows, mask

def fill_holes(mask):
    rows = len(mask)
    cols = len(mask[0])
    outside = [[False] * cols for _ in range(rows)]
    stack = []
    for r in range(rows):
        for c in range(cols):
            if (r in (0, rows - 1) or c in (0, cols - 1)) and mask[r][c] == "0":
                outside[r][c] = True
                stack.append((r, c))
    while stack:
        r, c = stack.pop()
        for dr, dc in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nr, nc = r + dr, c + dc
            if 0 <= nr < rows and 0 <= nc < cols and not outside[nr][nc] and mask[nr][nc] == "0":
                outside[nr][nc] = True
                stack.append((nr, nc))
    return ["".join("0" if outside[r][c] else "1" for c in range(cols)) for r in range(rows)]

def mask_lines(mask, indent):
    out = [indent + "mask = {"]
    for row in mask:
        out.append(indent + "    \"%s\"," % row)
    out.append(indent + "},")
    return out

lines = ["require \"TCA_Shared\";", "", "TCA.Organs = TCA.Organs or {};", ""]
for key, src_name, name in PIECES:
    crop, x, y, w, h, cols, rows, mask = load_piece(src_name, name)
    mask = fill_holes(mask)
    lines.append("TCA.Organs.%s = {" % key)
    lines.append("    id = \"%s\", texture = \"media/textures/organs/%s.png\"," % (name, name))
    lines.append("    x = %s, y = %s, w = %s, h = %s," % (num(x), num(y), num(w), num(h)))
    lines += mask_lines(mask, "    ")
    lines.append("};")
    lines.append("")
    print("%-11s piece     crop %3dx%-3d  corps x %6s y %6s w %5s h %5s  masque %2dx%-2d (%d cases)" % (name, crop.size[0], crop.size[1], num(x), num(y), num(w), num(h), cols, rows, sum(r.count("1") for r in mask)))

lines.append("TCA.Organs.LIST = {")
for oid, src_name, step, attaches in ORGANS:
    name = "organ_" + oid
    crop, x, y, w, h, cols, rows, mask = load_piece(src_name, name)
    cells = [(x + cx + 0.5, y + cy + 0.5) for cy in range(rows) for cx in range(cols) if mask[cy][cx] == "1"]
    gx = sum(p[0] for p in cells) / len(cells)
    gy = sum(p[1] for p in cells) / len(cells)
    snapped = []
    for attach in attaches:
        ax, ay = attach[0], attach[1]
        best = None
        for px, py in cells:
            d = (px - ax) ** 2 + (py - ay) ** 2
            if best is None or d < best[0]:
                best = (d, px, py)
        if best[0] > 0.5:
            ax, ay = best[1], best[2]
        if len(attach) > 2:
            angle = math.radians(attach[2])
            tx, ty = math.cos(angle), math.sin(angle)
        else:
            rx, ry = ax - gx, ay - gy
            length = math.hypot(rx, ry) or 1
            tx, ty = -ry / length, rx / length
        if tx < -0.01 or (abs(tx) <= 0.01 and ty < 0):
            tx, ty = -tx, -ty
        snapped.append((ax, ay, ax - tx * ATTACH_HALF, ay - ty * ATTACH_HALF, ax + tx * ATTACH_HALF, ay + ty * ATTACH_HALF))
    attaches = snapped
    lines.append("    {")
    lines.append("        id = \"%s\", step = %d, texture = \"media/textures/organs/%s.png\"," % (oid, step, name))
    lines.append("        x = %s, y = %s, w = %s, h = %s," % (num(x), num(y), num(w), num(h)))
    lines.append("        attaches = {")
    for a in attaches:
        lines.append("            { x = %s, y = %s, ax = %s, ay = %s, bx = %s, by = %s }," % tuple(num(v) for v in a))
    lines.append("        },")
    lines += mask_lines(mask, "        ")
    lines.append("    },")
    print("%-11s step %2d  crop %3dx%-3d  corps x %6s y %6s w %5s h %5s  masque %2dx%-2d (%d cases)" % (oid, step, crop.size[0], crop.size[1], num(x), num(y), num(w), num(h), cols, rows, sum(r.count("1") for r in mask)))
lines += [
    "};",
    "",
    "function TCA.Organs.getById(id)",
    "    for _, organ in ipairs(TCA.Organs.LIST) do",
    "        if organ.id == id then",
    "            return organ;",
    "        end",
    "    end",
    "    return nil;",
    "end",
    "",
    "function TCA.Organs.getByStep(step)",
    "    for _, organ in ipairs(TCA.Organs.LIST) do",
    "        if organ.step == step then",
    "            return organ;",
    "        end",
    "    end",
    "    return nil;",
    "end",
    "",
    "function TCA.Organs.contains(organ, bx, by)",
    "    local col = math.floor(bx - organ.x) + 1;",
    "    local row = math.floor(by - organ.y) + 1;",
    "    local line = organ.mask[row];",
    "    if not line or col < 1 or col > string.len(line) then",
    "        return false;",
    "    end",
    "    return string.sub(line, col, col) == \"1\";",
    "end",
    "",
    "function TCA.Organs.isVisibleAt(organ, bx, by, removed)",
    "    if not TCA.Organs.contains(organ, bx, by) then",
    "        return false;",
    "    end",
    "    for i = removed + 1, #TCA.Organs.LIST do",
    "        local other = TCA.Organs.LIST[i];",
    "        if other == organ then",
    "            return true;",
    "        end",
    "        if TCA.Organs.contains(other, bx, by) then",
    "            return false;",
    "        end",
    "    end",
    "    return true;",
    "end",
    "",
    "function TCA.Organs.getFrontOrganAt(bx, by, removed)",
    "    for i = removed + 1, #TCA.Organs.LIST do",
    "        local organ = TCA.Organs.LIST[i];",
    "        if TCA.Organs.contains(organ, bx, by) then",
    "            return organ;",
    "        end",
    "    end",
    "    return nil;",
    "end",
    "",
    "function TCA.Organs.getPieceOutline(piece)",
    "    if piece.outline then",
    "        return piece.outline;",
    "    end",
    "    local outline = {};",
    "    for row = 1, #piece.mask do",
    "        local line = piece.mask[row];",
    "        for col = 1, string.len(line) do",
    "            local cx = piece.x + col - 0.5;",
    "            local cy = piece.y + row - 0.5;",
    "            if TCA.Organs.contains(piece, cx, cy) then",
    "                local edge = not TCA.Organs.contains(piece, cx - 1, cy) or not TCA.Organs.contains(piece, cx + 1, cy) or not TCA.Organs.contains(piece, cx, cy - 1) or not TCA.Organs.contains(piece, cx, cy + 1);",
    "                if edge then",
    "                    table.insert(outline, { x = piece.x + col - 1, y = piece.y + row - 1 });",
    "                end",
    "            end",
    "        end",
    "    end",
    "    piece.outline = outline;",
    "    return outline;",
    "end",
    ""
]
open(LUA_OUT, "w").write("\n".join(lines) + "\n")
