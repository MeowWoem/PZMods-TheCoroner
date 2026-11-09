require "TCA_Shared";
require "TCA_Organs";

TCA.Autopsy = TCA.Autopsy or {};
local A = TCA.Autopsy;

A.XP_MIN = 10;
A.XP_MAX = 50;
A.INFECTION_CHANCE = 30;
A.MAX_PATH_LENGTH = 20000;

A.SYNC_FLAGS = 0xc00003808b;

A.XP_OPEN = 5;
A.XP_PER_RIB = 1.5;
A.XP_PER_ORGAN = 2;

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

A.RIB_TOOLS = {
    { tag = ItemTag.BOLT_CUTTERS, mode = "cutter" },
    { tag = ItemTag.SAW, mode = "saw" },
    { tag = ItemTag.SMALL_SAW, mode = "saw" },
    { tag = ItemTag.METAL_SAW, mode = "saw" },
    { tag = ItemTag.CRUDE_SAW, mode = "saw" },
};

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
            break;
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
    return state;
end

function A.getOrganDecay(body)
    local hours = 0;
    local deathTime = body:getDeathTime();
    if deathTime and deathTime >= 0 then
        hours = getGameTime():getWorldAgeHours() - deathTime;
    end
    if body:isZombie() then
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

function A.findRibTool(character)
    local inv = character:getInventory();
    for _, def in ipairs(A.RIB_TOOLS) do
        if def.tag then
            local item = inv:getFirstTagEvalRecurse(def.tag, isNotBroken);
            if item then
                return item, def.mode;
            end
        end
    end
    return nil, nil;
end

function A.hasToolForStage(character, stage)
    if stage == "incision" then
        return A.findScalpel(character) ~= nil;
    elseif stage == "open" then
        return A.findForceps(character) ~= nil;
    elseif stage == "ribs" then
        return A.findRibTool(character) ~= nil;
    elseif stage == "organs" then
        return A.findScalpel(character) ~= nil;
    end
    return false;
end

function A.applyCut(character)
    local partType = BodyPartType.Hand_L;
    if ZombRand(4) == 0 then
        partType = BodyPartType.Hand_R;
    end
    local bodyPart = character:getBodyDamage():getBodyPart(partType);
    bodyPart:setCut(true, true);
    if not character:getClothingItem_Hands() and ZombRand(100) < A.INFECTION_CHANCE then
        bodyPart:setInfectedWound(true);
    end
    syncBodyPart(bodyPart, A.SYNC_FLAGS);
end

function A.showXpHalo(character, xp)
    local rounded = math.floor(xp * 10 + 0.5) / 10;
    if rounded <= 0 then
        return;
    end
    HaloTextHelper.addGoodText(character, getText("IGUI_TCA_XpGain", tostring(rounded), PerkFactory.getPerkName(Perks.Doctor)));
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
    md["TCA_A_ribs"] = nil;
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
