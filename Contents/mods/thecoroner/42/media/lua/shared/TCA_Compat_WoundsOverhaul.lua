require "TCA_Wounds";
require "TCA_Shared";
require "TCA_BloodType";

TCA = TCA or {};
TCA.Compat = TCA.Compat or {};
TCA.Compat.WoundsOverhaul = TCA.Compat.WoundsOverhaul or {};

local X = TCA.Compat.WoundsOverhaul;

X.MOD_ID = "WoundsOverhaul";
X.ROOT_KEY = "Wounds";
X.KEY_EXTRACTED = "TCA_WOExtracted";
X.COMMAND_MODULE = "TCA_WO";
X.TYPING_KIT = "Wounds.BloodTypingKit";
X.KEY_LODGED = "woundsBullets";
X.PART_ORDER = { "Torso_Upper", "Torso_Lower", "Groin" };

X.SEPSIS_SIGNS = 30;
X.SEPSIS_LETHAL = 55;
X.BLOOD_SIGNS = 50;
X.BLOOD_LETHAL = 75;
X.ACUTE_SIGNS = 55;
X.SUTURE_GOOD = 0.6;
X.PATHOLOGY_STEPS = { 15, 40, 70 };

X.TOURNIQUET_PARTS = { arm_L = "UpperArm_L", arm_R = "UpperArm_R", leg_L = "UpperLeg_L", leg_R = "UpperLeg_R" };

X.KINDS = { "openFracture", "burnDeep", "skinGraft", "sutured", "poorStitch", "tourniquet", "sepsis", "exsanguination", "overdoseSigns" };

X.REPLACES = { openFracture = "fracture", burnDeep = "burn" };

X.MIN_LEVEL = { poorStitch = 3, exsanguination = 3, sepsis = 6, overdoseSigns = 6 };

X.DETECT = {
    openFracture = 1, tourniquet = 1, burnDeep = 0.9, skinGraft = 0.8, sutured = 0.7, poorStitch = 0.5,
    exsanguination = 0.6, overdoseSigns = 0.4, sepsis = 0.35,
};

X.CONFUSE = { sutured = "poorStitch", skinGraft = "burnDeep" };

X.CAUSES = { "hemorrhage", "sepsis", "overdose" };

X.LETHAL_WOUNDS = {
    { kind = "exsanguination", cause = "hemorrhage" },
    { kind = "sepsis", cause = "sepsis" },
    { kind = "overdoseSigns", cause = "overdose" },
};

function X.isActive()
    if not TCA.Wounds.isModActivated(X.MOD_ID) then
        return false;
    end
    return Wounds ~= nil and type(Wounds) == "table" and type(Wounds.register) == "function";
end

function X.getRoot(character)
    local root = character:getModData()[X.ROOT_KEY];
    if type(root) ~= "table" then
        return nil;
    end
    return root;
end

function X.getCondition(root, id)
    if type(root.conditions) ~= "table" or type(root.conditions[id]) ~= "table" then
        return nil;
    end
    return root.conditions[id];
end

function X.number(value)
    return tonumber(value) or 0;
end

function X.partNames(player)
    local names = {};
    local bodyDamage = player:getBodyDamage();
    if not bodyDamage then
        return names;
    end
    local parts = bodyDamage:getBodyParts();
    for i = 0, parts:size() - 1 do
        names[tostring(i)] = BodyPartType.ToString(parts:get(i):getType());
    end
    return names;
end

function X.add(list, part, kind)
    if part then
        TCA.Wounds.addKind(list, part, kind);
    end
end

function X.snapshotFractures(root, names, list)
    local state = X.getCondition(root, "openfracture");
    if not state or type(state.parts) ~= "table" then
        return;
    end
    for key, _ in pairs(state.parts) do
        X.add(list, names[tostring(key)], "openFracture");
    end
end

function X.snapshotBurns(root, names, list)
    if type(root.burns) ~= "table" then
        return;
    end
    for key, record in pairs(root.burns) do
        if type(record) == "table" then
            local part = names[tostring(key)];
            if X.number(record.deg) >= 3 then
                X.add(list, part, "burnDeep");
            end
            if record.graft and not record.graftFailed then
                X.add(list, part, "skinGraft");
            end
        end
    end
end

function X.snapshotSutures(root, names, list)
    if type(root.sutures) ~= "table" then
        return;
    end
    for key, quality in pairs(root.sutures) do
        if X.number(quality) >= X.SUTURE_GOOD then
            X.add(list, names[tostring(key)], "sutured");
        else
            X.add(list, names[tostring(key)], "poorStitch");
        end
    end
end

function X.snapshotTourniquets(root, list)
    if type(root.tourniquets) ~= "table" then
        return;
    end
    for limb, _ in pairs(root.tourniquets) do
        X.add(list, X.TOURNIQUET_PARTS[limb], "tourniquet");
    end
end

function X.snapshotConditions(root, list)
    local sepsis = X.getCondition(root, "sepsis");
    if sepsis and X.number(sepsis.level) >= X.SEPSIS_SIGNS then
        X.add(list, "Torso_Upper", "sepsis");
    end
    local blood = X.getCondition(root, "bloodloss");
    if blood and X.number(blood.level) >= X.BLOOD_SIGNS then
        X.add(list, "Torso_Upper", "exsanguination");
    end
    local poisoning = X.getCondition(root, "poisoning");
    if poisoning and X.number(poisoning.acute) >= X.ACUTE_SIGNS then
        X.add(list, "Head", "overdoseSigns");
    end
end

function X.snapshot(player, list)
    local root = X.getRoot(player);
    if not root then
        return;
    end
    local names = X.partNames(player);
    X.snapshotFractures(root, names, list);
    X.snapshotBurns(root, names, list);
    X.snapshotSutures(root, names, list);
    X.snapshotTourniquets(root, list);
    X.snapshotConditions(root, list);
    TCA.BloodType.setTrue(player, root.bloodType);
end

function X.deathCause(character)
    local root = X.getRoot(character);
    if not root then
        return nil;
    end
    local poisoning = X.getCondition(root, "poisoning");
    if poisoning and X.number(poisoning.acute) >= X.ACUTE_SIGNS then
        return "overdose";
    end
    local sepsis = X.getCondition(root, "sepsis");
    if sepsis and X.number(sepsis.level) >= X.SEPSIS_LETHAL then
        return "sepsis";
    end
    local blood = X.getCondition(root, "bloodloss");
    if blood and X.number(blood.level) >= X.BLOOD_LETHAL then
        return "hemorrhage";
    end
    return nil;
end

function X.pathologyLevel(damage)
    local level = 0;
    for i = 1, #X.PATHOLOGY_STEPS do
        if damage >= X.PATHOLOGY_STEPS[i] then
            level = i;
        end
    end
    return level;
end

function X.organPathology(player)
    local root = X.getRoot(player);
    if not root then
        return nil;
    end
    local poisoning = X.getCondition(root, "poisoning");
    if not poisoning then
        return nil;
    end
    local result = {};
    local liver = X.pathologyLevel(X.number(poisoning.liver));
    if liver > 0 then
        result.liver = liver;
    end
    local kidney = X.pathologyLevel(X.number(poisoning.kidney));
    if kidney > 0 then
        result.kidney_l = kidney;
        result.kidney_r = kidney;
    end
    return result;
end

function X.removedBullets(body)
    local list = body:getModData()[X.KEY_EXTRACTED];
    if type(list) ~= "table" then
        return nil;
    end
    return list;
end

function X.applyExtraction(body, part)
    local W = TCA.Wounds;
    if not body or type(part) ~= "string" or not W.BULLET_ORGANS[part] then
        return;
    end
    local md = body:getModData();
    if type(md[X.KEY_EXTRACTED]) ~= "table" then
        md[X.KEY_EXTRACTED] = {};
    end
    table.insert(md[X.KEY_EXTRACTED], part);
    W.removeBulletFromPart(body, part);
    if isServer() then
        body:transmitModData();
    end
end

function X.partsForOrgan(organId)
    local W = TCA.Wounds;
    local parts = {};
    for i = 1, #X.PART_ORDER do
        local organs = W.BULLET_ORGANS[X.PART_ORDER[i]];
        if organs and W.listContains(organs, organId) then
            table.insert(parts, X.PART_ORDER[i]);
        end
    end
    return parts;
end

function X.removeLodged(body, part)
    local lodged = body:getModData()[X.KEY_LODGED];
    if type(lodged) ~= "table" then
        return false;
    end
    for i = 1, #lodged do
        if tostring(lodged[i]) == part then
            table.remove(lodged, i);
            return true;
        end
    end
    return false;
end

function X.bulletTaken(body, organId)
    local lodged = body:getModData()[X.KEY_LODGED];
    if type(lodged) ~= "table" then
        return;
    end
    local parts = X.partsForOrgan(organId);
    for p = 1, #parts do
        if X.removeLodged(body, parts[p]) then
            return;
        end
    end
end

function X.onClientCommand(module, command, player, args)
    if module ~= X.COMMAND_MODULE or command ~= "extracted" or not args then
        return;
    end
    local body = TCA.findBodyAt(args.x, args.y, args.z);
    if not body then
        return;
    end
    local dx = body:getX() - player:getX();
    local dy = body:getY() - player:getY();
    if dx * dx + dy * dy > 16 then
        return;
    end
    X.removeLodged(body, args.part);
    X.applyExtraction(body, args.part);
end

TCA.Wounds.registerProvider({
    id = X.MOD_ID,
    isActive = X.isActive,
    kinds = X.KINDS,
    minLevel = X.MIN_LEVEL,
    detect = X.DETECT,
    confuse = X.CONFUSE,
    replaces = X.REPLACES,
    causes = X.CAUSES,
    lethal = X.LETHAL_WOUNDS,
    snapshot = X.snapshot,
    deathCause = X.deathCause,
    organPathology = X.organPathology,
    removedBullets = X.removedBullets,
    bulletTaken = X.bulletTaken,
});

TCA.BloodType.registerKit({
    id = X.MOD_ID,
    isActive = X.isActive,
    fullType = X.TYPING_KIT,
});

if not X.commandRegistered then
    Events.OnClientCommand.Add(X.onClientCommand);
    X.commandRegistered = true;
end
