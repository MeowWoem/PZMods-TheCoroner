require "TCA_Shared";
require "TCA_Organs";
require "TCA_DeathTime";
require "TCA_Cold";

TCA.Autopsy = TCA.Autopsy or {};
local A = TCA.Autopsy;

A.XP_MIN = 10;
A.XP_MAX = 50;
A.INFECTION_CHANCE = 30;
A.MAX_PATH_LENGTH = 20000;
A.ORGAN_ITEM_PREFIX = "TCA.Organ_";
A.CHEST_PLATE_ITEM = "TCA.ChestPlate";

A.SYNC_FLAGS = 0xc00003808b;
A.SYNC_FLAGS_DEEP = 0xc00007818b;

A.XP_OPEN = 5;
A.XP_PER_RIB = 1.5;
A.XP_PER_ORGAN = 2;
A.XP_PLASTRON = 2;
A.GRADE_ACC_WEIGHT = 40;
A.GRADE_TEAR = 6;
A.GRADE_TEAR_MAX = 24;
A.GRADE_ORGAN = 4;
A.GRADE_ORGAN_MAX = 40;
A.GRADE_CUT = 5;
A.GRADE_CUT_MAX = 20;
A.GRADE_STEPS = { 90, 75, 60, 40 };

A.INCISION_Y = {
    { ax = -37.5, ay = 96, bx = 0, by = 107.5 },
    { ax = 37.5, ay = 96, bx = 0, by = 107.5 },
    { ax = 0, ay = 107.5, bx = 0, by = 225 },
};

A.STEP_CLOSED = 0;
A.STEP_OPENED = 1;
A.STEP_CHEST = 2;
A.OPEN_DONE = 0.99;
A.LAST_STEP = A.STEP_CHEST;

A.RIBS = {
    { x = -21, y = 114 },
    { x = -22, y = 123 },
    { x = -23.5, y = 132 },
    { x = -25, y = 141 },
    { x = -26.5, y = 150 },
    { x = -28, y = 159 },
    { x = 21, y = 114 },
    { x = 22, y = 123 },
    { x = 23.5, y = 132 },
    { x = 25, y = 141 },
    { x = 26.5, y = 150 },
    { x = 28, y = 159 },
};

A.FORCEPS_TYPES = { "SutureNeedleHolder", "Forceps_Forged", "Tweezers" };

A.OSCILLATING_SAW = "TCA.BoneSawOscillating";
A.BONE_SAW = "TCA.BoneSaw";

A.RIB_TOOLS = {
    { id = "oscillating", itemType = A.OSCILLATING_SAW, mode = "cutter", needsCharge = true, holdMs = 300, slipMul = 1.5, xpMul = 1.5 },
    { id = "bonesaw", itemType = A.BONE_SAW, mode = "saw", travelMul = 0.6, slipMul = 1.5, cutChance = 10, xpMul = 1.5 },
    { id = "cutter", tag = ItemTag.BOLT_CUTTERS, mode = "cutter" },
    { id = "saw", tag = ItemTag.SAW, mode = "saw" },
    { id = "saw", tag = ItemTag.SMALL_SAW, mode = "saw" },
    { id = "saw", tag = ItemTag.METAL_SAW, mode = "saw" },
    { id = "saw", tag = ItemTag.CRUDE_SAW, mode = "saw" },
};

A.BATTERY_TYPE = "Base.Battery";

local function segLength(seg)
    local dx = seg.bx - seg.ax;
    local dy = seg.by - seg.ay;
    return math.sqrt(dx * dx + dy * dy);
end

A.TOTAL_LENGTH = 0;
for _, seg in ipairs(A.INCISION_Y) do
    seg.length = segLength(seg);
    A.TOTAL_LENGTH = A.TOTAL_LENGTH + seg.length;
end

function A.getFraction(segIndex, segProgress)
    local count = #A.INCISION_Y;
    if segIndex > count then
        return 1;
    end
    local done = 0;
    for i, seg in ipairs(A.INCISION_Y) do
        if i < segIndex then
            done = done + seg.length;
        elseif i == segIndex then
            done = done + seg.length * segProgress;
        end
    end
    return done / A.TOTAL_LENGTH;
end

function A.getState(body)
    local md = body:getModData();
    local state = {};
    state.segIndex = tonumber(md["TCA_A_seg"]) or 1;
    state.segProgress = tonumber(md["TCA_A_prog"]) or 0;
    state.paths = md["TCA_A_paths"] or "";
    state.accuracy = tonumber(md["TCA_A_acc"]) or 0;
    state.accSamples = tonumber(md["TCA_A_accN"]) or 0;
    if md["TCA_Autopsied"] then
        state.segIndex = #A.INCISION_Y + 1;
        state.segProgress = 0;
    end
    return state;
end

function A.encodePaths(paths)
    local blocks = {};
    for i = 1, #A.INCISION_Y do
        local pts = {};
        local path = paths[i] or {};
        for _, pt in ipairs(path) do
            table.insert(pts, string.format("%.1f,%.1f", pt.x, pt.y));
        end
        table.insert(blocks, table.concat(pts, ";"));
    end
    return table.concat(blocks, "|");
end

function A.decodePaths(str)
    local paths = {};
    for i = 1, #A.INCISION_Y do
        paths[i] = {};
    end
    if not str or str == "" then
        return paths;
    end
    local index = 1;
    for block in string.gmatch(str .. "|", "([^|]*)|") do
        if index > #A.INCISION_Y then
            break
        end
        for xs, ys in string.gmatch(block, "([%-%d%.]+),([%-%d%.]+)") do
            table.insert(paths[index], { x = tonumber(xs), y = tonumber(ys) });
        end
        index = index + 1;
    end
    return paths;
end

function A.isIncisionDone(body)
    return body:getModData()["TCA_Autopsied"] and true or false;
end

function A.getStep(body)
    return tonumber(body:getModData()["TCA_A_step"]) or A.STEP_CLOSED;
end

function A.getOpenState(body)
    local md = body:getModData();
    local state = {};
    state.left = tonumber(md["TCA_A_openL"]) or 0;
    state.right = tonumber(md["TCA_A_openR"]) or 0;
    state.tears = tonumber(md["TCA_A_tears"]) or 0;
    return state;
end

function A.getOrganState(body)
    local md = body:getModData();
    local state = {};
    state.done = math.floor(tonumber(md["TCA_A_organs"]) or 0);
    state.damage = math.floor(tonumber(md["TCA_A_odmg"]) or 0);
    state.current = math.floor(tonumber(md["TCA_A_cdmg"]) or 0);
    state.attach = md["TCA_A_attach"] or "";
    return state;
end

function A.decodeAttach(str, count)
    local work = {};
    for i = 1, count do
        work[i] = 0;
    end
    local index = 1;
    for value in string.gmatch(tostring(str or ""), "[^,]+") do
        if index > count then
            break
        end
        local v = tonumber(value) or 0;
        if v < 0 then
            v = 0;
        elseif v > 1 then
            v = 1;
        end
        work[index] = v;
        index = index + 1;
    end
    return work;
end

function A.encodeAttach(work)
    local parts = {};
    local any = false;
    for i = 1, #work do
        local v = math.floor(work[i] * 1000 + 0.5) / 1000;
        if v > 0 then
            any = true;
        end
        parts[i] = tostring(v);
    end
    if not any then
        return "";
    end
    return table.concat(parts, ",");
end

function A.getOrganDecay(body)
    local hours = TCA.Cold.getEffectiveHours(body, TCA.Cold.DECAY_FACTOR);
    if TCA.isInfected(body) then
        if hours > 72 then
            return 3;
        end
        return 2;
    end
    if hours < 12 then
        return 0;
    elseif hours < 48 then
        return 1;
    elseif hours < 168 then
        return 2;
    end
    return 3;
end

function A.getStage(body)
    if not A.isIncisionDone(body) then
        return "incision";
    end
    local step = A.getStep(body);
    if step < A.STEP_OPENED then
        return "open";
    end
    if step < A.STEP_CHEST then
        if A.countRibs(A.getRibs(body)) >= #A.RIBS then
            return "plastron";
        end
        return "ribs";
    end
    if A.getOrganState(body).done < #TCA.Organs.LIST then
        return "organs";
    end
    return "done";
end

function A.decodeRibs(str)
    local ribs = {};
    str = str or "";
    for i = 1, #A.RIBS do
        ribs[i] = string.sub(str, i, i) == "1";
    end
    return ribs;
end

function A.encodeRibs(ribs)
    local chars = {};
    for i = 1, #A.RIBS do
        if ribs[i] then
            chars[i] = "1";
        else
            chars[i] = "0";
        end
    end
    return table.concat(chars);
end

function A.countRibs(ribs)
    local count = 0;
    for i = 1, #A.RIBS do
        if ribs[i] then
            count = count + 1;
        end
    end
    return count;
end

function A.getRibs(body)
    return A.decodeRibs(body:getModData()["TCA_A_ribs"]);
end

local function isNotBroken(item)
    return not item:isBroken();
end

function A.findScalpel(character)
    return character:getInventory():getFirstTypeRecurse("Scalpel");
end

A.BLADE_GROUPS = {
    Scalpel = "scalpel",
    StraightRazor = "fine",
    KnifeParing = "fine",
    KnifeFillet = "fine",
    SmallKnife = "fine",
    KnifePocket = "fine",
    SteakKnife = "fine",
    SwitchKnife = "fine",
    KnifeButterfly = "fine",
    KnifeSushi = "fine",
    Toothbrush_Shiv = "none",
};
A.NO_SHARPNESS_LEVEL = 0.5;

function A.registerIncisionBlade(itemType, group)
    A.BLADE_GROUPS[itemType] = group;
end

A.BUTCHER_MITIGATION = 0.5;
A.DULL_TREMOR = 0.3;
A.DULL_TOLERANCE = 0.15;
A.DULL_TEAR = 0.2;
A.EDGE_ROUGH = 0.8;
A.EDGE_VERY_ROUGH = 0.65;
A.PREDMG_MAX = 3;

A.NICK_SEGMENT = 3;
A.NICK_ZONES = {
    { y1 = 145, y2 = 175, organ = "stomach" },
    { y1 = 175, y2 = 212, organ = "intestines" },
    { y1 = 212, y2 = 235, organ = "bladder" },
};

function A.getBladeSharpness(item)
    if not item then
        return 1;
    end
    if not item:hasSharpness() then
        return A.NO_SHARPNESS_LEVEL;
    end
    local s = item:getSharpness();
    if s < 0 then
        return 0;
    end
    if s > 1 then
        return 1;
    end
    return s;
end

local function compareSharpness(a, b)
    return A.getBladeSharpness(a) - A.getBladeSharpness(b);
end

local function hasWeaponCategory(item, category)
    local script = item:getScriptItem();
    return script ~= nil and script:containsWeaponCategory(category);
end

local function isSlashBlade(item)
    if not instanceof(item, "HandWeapon") or not item:hasSharpness() then
        return false;
    end
    if item:getDamageCategory() ~= "Slash" then
        return false;
    end
    if item:hasTag(ItemTag.SCISSORS) or item:hasTag(ItemTag.AWL) then
        return false;
    end
    return hasWeaponCategory(item, WeaponCategory.SMALL_BLADE) or hasWeaponCategory(item, WeaponCategory.LONG_BLADE);
end

function A.getBladeGroup(item)
    if not item or item:isBroken() then
        return nil;
    end
    local group = A.BLADE_GROUPS[item:getFullType()] or A.BLADE_GROUPS[item:getType()];
    if group then
        if group == "none" then
            return nil;
        end
        return group;
    end
    local tagged = item:hasTag(ItemTag.SHARP_KNIFE);
    if not tagged and not isSlashBlade(item) then
        return nil;
    end
    if hasWeaponCategory(item, WeaponCategory.LONG_BLADE) then
        if not tagged then
            return nil;
        end
        return "large";
    end
    return "knife";
end

function A.isCrudeBlade(item)
    return item ~= nil and not item:hasSharpness();
end

local function isScalpelBlade(item)
    return A.getBladeGroup(item) == "scalpel";
end

local function isFineBlade(item)
    return A.getBladeGroup(item) == "fine";
end

local function isKnifeBlade(item)
    return A.getBladeGroup(item) == "knife";
end

local function isLargeBlade(item)
    return A.getBladeGroup(item) == "large";
end

A.INCISION_TOOLS = {
    { id = "scalpel", rank = 1, predicate = isScalpelBlade, tremorMul = 1, tolMul = 1, tearMul = 1, deepChance = 0, deepWoundChance = 0, xpMul = 1 },
    { id = "fine", rank = 2, predicate = isFineBlade, tremorMul = 1.1, tolMul = 0.95, tearMul = 0.85, deepChance = 0, deepWoundChance = 0, xpMul = 0.75, wearMul = 1.5 },
    { id = "knife", rank = 3, predicate = isKnifeBlade, tremorMul = 1.25, tolMul = 0.85, tearMul = 0.7, deepChance = 30, deepWoundChance = 15, xpMul = 0.5, wearMul = 1.5 },
    { id = "large", rank = 4, predicate = isLargeBlade, tremorMul = 1.4, tolMul = 0.75, tearMul = 0.55, deepChance = 50, deepWoundChance = 35, xpMul = 0.5, wearMul = 1.5 },
};

function A.getIncisionDef(rank)
    for _, def in ipairs(A.INCISION_TOOLS) do
        if def.rank == rank then
            return def;
        end
    end
    return nil;
end

function A.findIncisionTool(character)
    local inv = character:getInventory();
    for _, def in ipairs(A.INCISION_TOOLS) do
        local item = inv:getBestEvalRecurse(def.predicate, compareSharpness);
        if item then
            return item, def;
        end
    end
    return nil, nil;
end

function A.getButcheringMitigation(character, def)
    if not def or def.rank <= 1 then
        return 0;
    end
    local level = math.min(character:getPerkLevel(Perks.Butchering), 10);
    return level / 10 * A.BUTCHER_MITIGATION;
end

local function softenUp(mul, mit)
    return 1 + (mul - 1) * (1 - mit);
end

local function softenDown(mul, mit)
    return 1 - (1 - mul) * (1 - mit);
end

function A.getIncisionParams(character, item, def)
    local p = {};
    local dull = 1 - A.getBladeSharpness(item);
    local mit = A.getButcheringMitigation(character, def);
    p.rank = def.rank;
    p.dull = dull;
    p.tremorMul = softenUp(def.tremorMul, mit) * (1 + dull * A.DULL_TREMOR);
    p.tolMul = softenDown(def.tolMul, mit) * (1 - dull * A.DULL_TOLERANCE);
    p.tearMul = softenDown(def.tearMul, mit) * (1 - dull * A.DULL_TEAR);
    p.deepChance = def.deepChance * (1 - mit) * (1 + dull);
    p.deepWoundChance = def.deepWoundChance * (1 - mit) * (1 + dull);
    p.xpMul = def.xpMul;
    return p;
end

function A.isDullBlade(item)
    return item ~= nil and item:isDull();
end

function A.wearBlade(item, def)
    if not item or not def or not def.wearMul then
        return;
    end
    item:damageCheck(0, def.wearMul, true);
    item:syncItemFields();
end

function A.getNickOrgan(segIndex, bodyY)
    if segIndex ~= A.NICK_SEGMENT then
        return nil;
    end
    for _, zone in ipairs(A.NICK_ZONES) do
        if bodyY >= zone.y1 and bodyY < zone.y2 then
            return zone.organ;
        end
    end
    return nil;
end

function A.isNickOrgan(organId)
    for _, zone in ipairs(A.NICK_ZONES) do
        if zone.organ == organId then
            return true;
        end
    end
    return false;
end

function A.decodePreDamage(str)
    local map = {};
    for id, n in string.gmatch(tostring(str or ""), "(%a+):(%d+)") do
        if A.isNickOrgan(id) then
            map[id] = math.min(tonumber(n) or 0, A.PREDMG_MAX);
        end
    end
    return map;
end

function A.encodePreDamage(map)
    local parts = {};
    for _, zone in ipairs(A.NICK_ZONES) do
        local n = map[zone.organ] or 0;
        if n > 0 then
            table.insert(parts, zone.organ .. ":" .. tostring(n));
        end
    end
    return table.concat(parts, ",");
end

function A.countPreDamage(map)
    local total = 0;
    for _, zone in ipairs(A.NICK_ZONES) do
        total = total + (map[zone.organ] or 0);
    end
    return total;
end

function A.getPreDamage(body, organId)
    return A.decodePreDamage(body:getModData()["TCA_A_predmg"])[organId] or 0;
end

function A.getEdge(body)
    return tonumber(body:getModData()["TCA_A_edge"]) or 1;
end

function A.getBladeRank(body)
    return math.floor(tonumber(body:getModData()["TCA_A_blade"]) or 1);
end

function A.findForceps(character)
    local inv = character:getInventory();
    for _, itemType in ipairs(A.FORCEPS_TYPES) do
        local item = inv:getFirstTypeRecurse(itemType);
        if item and not item:isBroken() then
            return item;
        end
    end
    return nil;
end

function A.hasCharge(item)
    return item ~= nil and item:getCurrentUsesFloat() > 0;
end

function A.isUsableRibTool(item)
    return isNotBroken(item) and (not item:IsDrainable() or A.hasCharge(item));
end

function A.findRibToolItem(inv, def)
    if def.itemType then
        return inv:getFirstTypeEvalRecurse(def.itemType, A.isUsableRibTool);
    end
    if def.tag then
        return inv:getFirstTagEvalRecurse(def.tag, isNotBroken);
    end
    return nil;
end

function A.findRibTool(character)
    local inv = character:getInventory();
    for _, def in ipairs(A.RIB_TOOLS) do
        local item = A.findRibToolItem(inv, def);
        if item then
            return item, def.mode, def;
        end
    end
    return nil, nil, nil;
end

function A.useCharge(item, count)
    if not item or not item:IsDrainable() then
        return;
    end
    for i = 1, count do
        if item:getCurrentUsesFloat() <= 0 then
            return;
        end
        item:Use(false, false, isServer());
    end
end

function A.hasToolForStage(character, stage)
    if stage == "incision" then
        return A.findIncisionTool(character) ~= nil;
    elseif stage == "open" then
        return A.findForceps(character) ~= nil;
    elseif stage == "ribs" then
        return A.findRibTool(character) ~= nil;
    elseif stage == "organs" then
        return A.findScalpel(character) ~= nil;
    elseif stage == "plastron" then
        return true;
    end
    return false;
end

function A.getCutDeepChance(character, incision)
    if not incision then
        return 0;
    end
    local item, def = A.findIncisionTool(character);
    if not item then
        return 0;
    end
    return A.getIncisionParams(character, item, def).deepWoundChance;
end

function A.applyCut(character, deepChance)
    local partType = BodyPartType.Hand_L;
    if ZombRand(4) == 0 then
        partType = BodyPartType.Hand_R;
    end
    local bodyPart = character:getBodyDamage():getBodyPart(partType);
    local flags = A.SYNC_FLAGS;
    if deepChance and deepChance > 0 and ZombRand(100) < deepChance then
        bodyPart:generateDeepWound();
        flags = A.SYNC_FLAGS_DEEP;
    else
        bodyPart:setCut(true, true);
    end
    if not character:getClothingItem_Hands() and ZombRand(100) < A.INFECTION_CHANCE then
        bodyPart:setInfectedWound(true);
    end
    syncBodyPart(bodyPart, flags);
end

function A.giveXp(character, xp)
    if not character or not xp or xp <= 0 then
        return 0;
    end
    local before = character:getXp():getXP(Perks.Doctor);
    addXp(character, Perks.Doctor, xp);
    local gained = character:getXp():getXP(Perks.Doctor) - before;
    if gained < 0 then
        return 0;
    end
    return gained;
end

function A.showXpHalo(character, xp)
    local rounded = math.floor(xp * 10 + 0.5) / 10;
    if rounded <= 0 then
        return;
    end
    HaloTextHelper.addGoodText(character, getText("IGUI_TCA_XpGain", tostring(rounded), PerkFactory.getPerkName(Perks.Doctor)));
end

function A.getCutCount(body)
    return math.floor(tonumber(body:getModData()["TCA_A_cuts"]) or 0);
end

function A.computeScore(accuracy, tears, organDamage, cuts)
    local acc = math.max(0, math.min(1, tonumber(accuracy) or 0));
    local score = 100;
    score = score - (1 - acc) * A.GRADE_ACC_WEIGHT;
    score = score - math.min((tonumber(tears) or 0) * A.GRADE_TEAR, A.GRADE_TEAR_MAX);
    score = score - math.min((tonumber(organDamage) or 0) * A.GRADE_ORGAN, A.GRADE_ORGAN_MAX);
    score = score - math.min((tonumber(cuts) or 0) * A.GRADE_CUT, A.GRADE_CUT_MAX);
    return math.floor(math.max(0, math.min(100, score)) + 0.5);
end

function A.getGradeIndex(score)
    for i = 1, #A.GRADE_STEPS do
        if score >= A.GRADE_STEPS[i] then
            return i;
        end
    end
    return #A.GRADE_STEPS + 1;
end

function A.notifyXp(character, xp)
    if isServer() then
        local args = {};
        args.xp = xp;
        sendServerCommand(character, "TCA", "xp", args);
    else
        A.showXpHalo(character, xp);
    end
end

function A.resetBody(body)
    local md = body:getModData();
    md["TCA_A_seg"] = nil;
    md["TCA_A_prog"] = nil;
    md["TCA_A_paths"] = nil;
    md["TCA_A_acc"] = nil;
    md["TCA_A_accN"] = nil;
    md["TCA_Autopsied"] = nil;
    md["TCA_A_step"] = nil;
    md["TCA_A_openL"] = nil;
    md["TCA_A_openR"] = nil;
    md["TCA_A_tears"] = nil;
    md["TCA_A_organs"] = nil;
    md["TCA_A_odmg"] = nil;
    md["TCA_A_cdmg"] = nil;
    md["TCA_A_cuts"] = nil;
    md["TCA_A_attach"] = nil;
    md["TCA_A_ribs"] = nil;
    md["TCA_A_edge"] = nil;
    md["TCA_A_blade"] = nil;
    md["TCA_A_predmg"] = nil;
    body:transmitModData();
end

function A.getDebugLast()
    return 4 + #TCA.Organs.LIST;
end

function A.getDebugStraightPaths()
    local paths = {};
    for i, seg in ipairs(A.INCISION_Y) do
        paths[i] = { { x = seg.ax, y = seg.ay }, { x = seg.bx, y = seg.by } };
    end
    return paths;
end

function A.applyDebugPosition(body, pos)
    pos = math.max(0, math.min(math.floor(tonumber(pos) or 0), A.getDebugLast()));
    local md = body:getModData();
    md["TCA_A_seg"] = nil;
    md["TCA_A_prog"] = nil;
    md["TCA_A_paths"] = nil;
    md["TCA_A_acc"] = nil;
    md["TCA_A_accN"] = nil;
    md["TCA_Autopsied"] = nil;
    md["TCA_A_step"] = nil;
    md["TCA_A_openL"] = nil;
    md["TCA_A_openR"] = nil;
    md["TCA_A_tears"] = nil;
    md["TCA_A_organs"] = nil;
    md["TCA_A_odmg"] = nil;
    md["TCA_A_cdmg"] = nil;
    md["TCA_A_cuts"] = nil;
    md["TCA_A_attach"] = nil;
    md["TCA_A_ribs"] = nil;
    md["TCA_A_edge"] = nil;
    md["TCA_A_blade"] = nil;
    md["TCA_A_predmg"] = nil;
    if pos >= 1 then
        md["TCA_Autopsied"] = true;
        md["TCA_A_seg"] = #A.INCISION_Y + 1;
        md["TCA_A_prog"] = 0;
        md["TCA_A_paths"] = A.encodePaths(A.getDebugStraightPaths());
        md["TCA_A_acc"] = 1;
        md["TCA_A_accN"] = 1;
    end
    if pos >= 2 then
        md["TCA_A_step"] = A.STEP_OPENED;
        md["TCA_A_openL"] = 1;
        md["TCA_A_openR"] = 1;
    end
    if pos >= 3 then
        local ribs = {};
        for i = 1, #A.RIBS do
            ribs[i] = true;
        end
        md["TCA_A_ribs"] = A.encodeRibs(ribs);
    end
    if pos >= 4 then
        md["TCA_A_step"] = A.STEP_CHEST;
    end
    if pos >= 5 then
        md["TCA_A_organs"] = pos - 4;
    end
    body:transmitModData();
end

A.INCISION_PARTS = { "Torso_Upper", "Torso_Lower" };

function A.getBlockingClothing(body)
    local worn = body:getWornItems();
    if not worn then
        return nil;
    end
    for i = 0, worn:size() - 1 do
        local item = worn:getItemByIndex(i);
        if item and instanceof(item, "Clothing") then
            local parts = BloodClothingType.getCoveredParts(item:getBloodClothingType());
            if parts then
                for j = 0, parts:size() - 1 do
                    local partName = tostring(parts:get(j));
                    for _, wanted in ipairs(A.INCISION_PARTS) do
                        if partName == wanted then
                            return item;
                        end
                    end
                end
            end
        end
    end
    return nil;
end
