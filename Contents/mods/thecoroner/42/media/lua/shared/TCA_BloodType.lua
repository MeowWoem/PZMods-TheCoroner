require "TCA_Shared";
require "TCA_Exam";

TCA = TCA or {};
TCA.BloodType = TCA.BloodType or {};

local B = TCA.BloodType;

B.KEY_TRUE = "TCA_BloodType";
B.KEY_READ = "TCA_BloodRead";
B.KITS = B.KITS or {};
B.MISREAD_MAX = 0.15;
B.MISREAD_LEVEL = 8;
B.DURATION = 200;

B.GROUPS = {
    { group = "O+", weight = 374 },
    { group = "A+", weight = 357 },
    { group = "B+", weight = 85 },
    { group = "AB+", weight = 34 },
    { group = "O-", weight = 66 },
    { group = "A-", weight = 63 },
    { group = "B-", weight = 15 },
    { group = "AB-", weight = 6 },
};

function B.registerKit(def)
    if type(def) ~= "table" or type(def.id) ~= "string" or type(def.fullType) ~= "string" then
        return;
    end
    for i = 1, #B.KITS do
        if B.KITS[i].id == def.id then
            B.KITS[i] = def;
            return;
        end
    end
    table.insert(B.KITS, def);
end

function B.isKitActive(def)
    return type(def.isActive) ~= "function" or def.isActive() == true;
end

function B.isAvailable()
    for i = 1, #B.KITS do
        if B.isKitActive(B.KITS[i]) then
            return true;
        end
    end
    return false;
end

function B.isGroup(group)
    for i = 1, #B.GROUPS do
        if B.GROUPS[i].group == group then
            return true;
        end
    end
    return false;
end

function B.findKit(character)
    local inv = character:getInventory();
    for k = 1, #B.KITS do
        local def = B.KITS[k];
        if B.isKitActive(def) then
            local items = inv:getAllTypeRecurse(def.fullType);
            for i = 0, items:size() - 1 do
                local item = items:get(i);
                if item:getCurrentUsesFloat() > 0 then
                    return item;
                end
            end
        end
    end
    return nil;
end

function B.roll(exclude)
    local total = 0;
    for i = 1, #B.GROUPS do
        if B.GROUPS[i].group ~= exclude then
            total = total + B.GROUPS[i].weight;
        end
    end
    local pick = ZombRand(total);
    for i = 1, #B.GROUPS do
        local entry = B.GROUPS[i];
        if entry.group ~= exclude then
            if pick < entry.weight then
                return entry.group;
            end
            pick = pick - entry.weight;
        end
    end
    return "O+";
end

function B.ensureTrue(body)
    local md = body:getModData();
    if not B.isGroup(md[B.KEY_TRUE]) then
        md[B.KEY_TRUE] = B.roll(nil);
    end
    return md[B.KEY_TRUE];
end

function B.setTrue(character, group)
    if B.isGroup(group) then
        character:getModData()[B.KEY_TRUE] = group;
    end
end

function B.misreadChance(level)
    local capped = math.max(0, math.min(B.MISREAD_LEVEL, level or 0));
    return B.MISREAD_MAX * (1 - capped / B.MISREAD_LEVEL);
end

function B.getLastRead(body, character)
    local reads = body:getModData()[B.KEY_READ];
    if type(reads) ~= "table" then
        return nil;
    end
    return reads[TCA.Exam.getObserverKey(character)];
end

function B.typeBody(character, body)
    local truth = B.ensureTrue(body);
    local reading = truth;
    if ZombRand(1000) < B.misreadChance(character:getPerkLevel(Perks.Doctor)) * 1000 then
        reading = B.roll(truth);
    end
    local md = body:getModData();
    if type(md[B.KEY_READ]) ~= "table" then
        md[B.KEY_READ] = {};
    end
    md[B.KEY_READ][TCA.Exam.getObserverKey(character)] = reading;
    body:transmitModData();
    return reading;
end

function B.showResult(character, group)
    if character and group then
        HaloTextHelper.addText(character, getText("IGUI_TCA_BloodTypeResult", group));
    end
end

function B.notify(character, group)
    if isServer() then
        local args = {};
        args.group = group;
        sendServerCommand(character, "TCA", "bloodType", args);
    else
        B.showResult(character, group);
    end
end
