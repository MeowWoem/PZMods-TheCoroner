import sys, os
from PIL import Image

SRC, MOD_TEX, LUA_OUT = sys.argv[1], sys.argv[2], sys.argv[3]
STEPS_DIR = sys.argv[4] if len(sys.argv) > 4 else None

ORGANS = [
    ("heart", "organ_heart", 2, 2, [(-1, 121), (7, 122)]),
    ("lung_l", "organ_lung_l", 3, 3, [(9, 128)]),
    ("lung_r", "organ_lung_r", 4, 3, [(-9, 128)]),
    ("liver", "organ_liver", 5, 5, [(2, 152), (-8, 160)]),
    ("stomach", "organ_stomach", 6, 4, [(5, 150), (-8, 174)]),
    ("intestines", "organs_intestines", 7, 1, [(-18, 177), (8, 217)]),
    ("pancreas", "organs_pancreas", 8, 6, [(-2, 175)]),
    ("kidney_r", "organ_kidney_r", 9, 8, [(-10, 165)]),
    ("kidney_l", "organ_kidney_l", 10, 8, [(10, 165)]),
    ("spleen", "organ_spleen", 11, 7, [(22, 163)]),
    ("bladder", "organ_bladder", 12, 6, [(1, 219)]),
]
PIECES = [
    ("PLASTRON", "plastron", "plastron"),
]
CANVAS_W, CANVAS_H, SCALE, ORIGIN_X, ORIGIN_Y = 520, 1020, 2, 130, 20
MASK_ALPHA = 128
CROP_ALPHA = 32
CROP_MARGIN = 2
OVERLAP_ALPHA = 200
OVERLAP_MIN = 12
FRONT_MIN_SHARE = 0.6

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

def compute_in_front():
    images = {}
    for oid, src_name, step, depth, attaches in ORGANS:
        images[oid] = Image.open(find_source(src_name)).convert("RGBA").load()
    layers = {}
    in_front = {oid: [] for oid, _, _, _, _ in ORGANS}
    for i in range(len(ORGANS)):
        for j in range(i + 1, len(ORGANS)):
            a, _, step_a, depth_a, _ = ORGANS[i]
            b, _, step_b, depth_b, _ = ORGANS[j]
            front = a if depth_a < depth_b else b
            source = "profondeur"
            pa, pb = images[a], images[b]
            overlap = [(x, y) for y in range(0, CANVAS_H, SCALE) for x in range(0, CANVAS_W, SCALE) if pa[x, y][3] >= OVERLAP_ALPHA and pb[x, y][3] >= OVERLAP_ALPHA]
            if not overlap:
                continue
            if STEPS_DIR and len(overlap) >= OVERLAP_MIN:
                step = min(step_a, step_b)
                if step not in layers:
                    layers[step] = Image.open(os.path.join(STEPS_DIR, "torso_step%d.png" % step)).convert("RGBA").load()
                lay = layers[step]
                wins_a = 0
                for x, y in overlap:
                    ea = sum(abs(pa[x, y][c] - lay[x, y][c]) for c in range(3))
                    eb = sum(abs(pb[x, y][c] - lay[x, y][c]) for c in range(3))
                    if ea < eb:
                        wins_a += 1
                share_a = wins_a / len(overlap)
                if share_a >= FRONT_MIN_SHARE:
                    front, source = a, "calque %d%%" % round(share_a * 100)
                elif 1 - share_a >= FRONT_MIN_SHARE:
                    front, source = b, "calque %d%%" % round((1 - share_a) * 100)
            back = b if front == a else a
            in_front[back].append(front)
            print("  %-10s devant %-10s (%s, %d px)" % (front, back, source, len(overlap)))
    return in_front

IN_FRONT = compute_in_front()

lines.append("TCA.Organs.LIST = {")
for oid, src_name, step, depth, attaches in ORGANS:
    name = "organ_" + oid
    crop, x, y, w, h, cols, rows, mask = load_piece(src_name, name)
    snapped = []
    for ax, ay in attaches:
        best = None
        for cy in range(rows):
            for cx in range(cols):
                if mask[cy][cx] == "1":
                    px = x + cx + 0.5
                    py = y + cy + 0.5
                    d = (px - ax) ** 2 + (py - ay) ** 2
                    if best is None or d < best[0]:
                        best = (d, px, py)
        if best[0] <= 0.5:
            snapped.append((ax, ay))
        else:
            snapped.append((best[1], best[2]))
    attaches = snapped
    lines.append("    {")
    lines.append("        id = \"%s\", step = %d, depth = %d, texture = \"media/textures/organs/%s.png\"," % (oid, step, depth, name))
    lines.append("        x = %s, y = %s, w = %s, h = %s," % (num(x), num(y), num(w), num(h)))
    lines.append("        attaches = { %s }," % ", ".join("{ x = %s, y = %s }" % (num(ax), num(ay)) for ax, ay in attaches))
    lines.append("        inFront = { %s }," % ", ".join("\"%s\"" % other for other in IN_FRONT[oid]))
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
    "function TCA.Organs.isInFront(other, organ)",
    "    if not organ.inFrontSet then",
    "        organ.inFrontSet = {};",
    "        for _, id in ipairs(organ.inFront) do",
    "            organ.inFrontSet[id] = true;",
    "        end",
    "    end",
    "    return organ.inFrontSet[other.id] == true;",
    "end",
    "",
    "function TCA.Organs.isVisibleAt(organ, bx, by, removed)",
    "    if not TCA.Organs.contains(organ, bx, by) then",
    "        return false;",
    "    end",
    "    for i = removed + 1, #TCA.Organs.LIST do",
    "        local other = TCA.Organs.LIST[i];",
    "        if other ~= organ and TCA.Organs.isInFront(other, organ) and TCA.Organs.contains(other, bx, by) then",
    "            return false;",
    "        end",
    "    end",
    "    return true;",
    "end",
    "",
    "function TCA.Organs.getFrontOrganAt(bx, by, removed)",
    "    local fallback = nil;",
    "    for i = removed + 1, #TCA.Organs.LIST do",
    "        local organ = TCA.Organs.LIST[i];",
    "        if TCA.Organs.contains(organ, bx, by) then",
    "            if TCA.Organs.isVisibleAt(organ, bx, by, removed) then",
    "                return organ;",
    "            end",
    "            if not fallback or organ.depth < fallback.depth then",
    "                fallback = organ;",
    "            end",
    "        end",
    "    end",
    "    return fallback;",
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
    "",
    "function TCA.Organs.getOutline(organ, removed)",
    "    organ.outlines = organ.outlines or {};",
    "    if organ.outlines[removed] then",
    "        return organ.outlines[removed];",
    "    end",
    "    local outline = {};",
    "    for row = 1, #organ.mask do",
    "        local line = organ.mask[row];",
    "        for col = 1, string.len(line) do",
    "            local cx = organ.x + col - 0.5;",
    "            local cy = organ.y + row - 0.5;",
    "            if TCA.Organs.isVisibleAt(organ, cx, cy, removed) then",
    "                local edge = not TCA.Organs.isVisibleAt(organ, cx - 1, cy, removed) or not TCA.Organs.isVisibleAt(organ, cx + 1, cy, removed) or not TCA.Organs.isVisibleAt(organ, cx, cy - 1, removed) or not TCA.Organs.isVisibleAt(organ, cx, cy + 1, removed);",
    "                if edge then",
    "                    table.insert(outline, { x = organ.x + col - 1, y = organ.y + row - 1 });",
    "                end",
    "            end",
    "        end",
    "    end",
    "    organ.outlines[removed] = outline;",
    "    return outline;",
    "end",
]
open(LUA_OUT, "w").write("\n".join(lines) + "\n")
