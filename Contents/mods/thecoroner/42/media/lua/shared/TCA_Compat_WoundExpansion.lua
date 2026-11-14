require "TCA_Wounds";

TCA = TCA or {};
TCA.Compat = TCA.Compat or {};
TCA.Compat.WoundExpansion = TCA.Compat.WoundExpansion or {};

local X = TCA.Compat.WoundExpansion;

X.MOD_ID = "WoundExpansion";
X.ROOT_KEY = "WoundExp";
X.FROSTBITE = "Frostbite";

X.WOUND_KINDS = {
    Abrasion = "abrasion",
    Puncture = "puncture",
    Avulsion = "avulsion",
    Sprain = "sprain",
    Dislocation = "dislocation",
    Concussion = "concussion",
    JointDamage = "jointDamage",
    NerveDamage = "nerveDamage",
};

X.CONDITION_KINDS = {
    Bruised = "bruise",
    Swollen = "swollen",
    Inflamed = "inflamed",
    Necrotic = "necrotic",
    Maggots = "maggots",
    EmbeddedDebris = "debris",
    PoorlyStitched = "poorStitch",
    Reopened = "reopened",
    Tourniquet = "tourniquet",
    InternalBleeding = "internalBleeding",
    SepticFever = "sepsis",
};

X.SCAR_KINDS = { deep = "scarDeep", bite = "scarBite", burn = "scarBurn" };

X.KINDS = {
    "abrasion", "puncture", "avulsion", "frostbite1", "frostbite2", "frostbite3",
    "sprain", "dislocation", "concussion", "jointDamage", "nerveDamage",
    "bruise", "swollen", "inflamed", "necrotic", "maggots", "debris",
    "poorStitch", "reopened", "tourniquet", "internalBleeding", "sepsis",
    "scarDeep", "scarBite", "scarBurn",
};

X.REPLACES = { avulsion = "deep", frostbite2 = "burn", frostbite3 = "burn" };

X.MIN_LEVEL = {
    sprain = 3, dislocation = 3, swollen = 3, inflamed = 3, necrotic = 3, debris = 3, poorStitch = 3, reopened = 3,
    concussion = 6, jointDamage = 6, nerveDamage = 6, internalBleeding = 6, sepsis = 6,
};

X.DETECT = {
    tourniquet = 1, maggots = 0.9, avulsion = 0.9, frostbite3 = 0.9, frostbite2 = 0.8,
    bruise = 0.6, abrasion = 0.55, frostbite1 = 0.5, puncture = 0.45,
    scarDeep = 0.45, scarBite = 0.45, scarBurn = 0.5,
    sprain = 0.4, dislocation = 0.5, swollen = 0.4, inflamed = 0.4, necrotic = 0.6, debris = 0.4, poorStitch = 0.5, reopened = 0.5,
    concussion = 0.3, jointDamage = 0.3, nerveDamage = 0.25, internalBleeding = 0.4, sepsis = 0.35,
};

X.CONFUSE = {
    abrasion = "scratch", puncture = "spear", sprain = "dislocation", dislocation = "sprain",
    swollen = "inflamed", inflamed = "swollen", scarBite = "scarDeep", frostbite1 = "bruise",
};

X.CAUSES = { "hemorrhage", "sepsis" };

X.NATURAL_CAUSES = {
    { cause = "hemorrhage", weight = 8 },
    { cause = "sepsis", weight = 8 },
};

X.LETHAL_WOUNDS = {
    { kind = "internalBleeding", cause = "hemorrhage" },
    { kind = "sepsis", cause = "sepsis" },
    { kind = "necrotic", cause = "sepsis" },
};

X.DEATH_CONDITIONS = {
    { condition = "InternalBleeding", cause = "hemorrhage" },
    { condition = "SepticFever", cause = "sepsis" },
    { condition = "Necrotic", cause = "sepsis" },
};

X.PARTS_ALL = { "Head", "Neck", "Torso_Upper", "Torso_Lower", "Groin", "UpperArm_L", "ForeArm_L", "Hand_L", "UpperArm_R", "ForeArm_R", "Hand_R", "UpperLeg_L", "LowerLeg_L", "Foot_L", "UpperLeg_R", "LowerLeg_R", "Foot_R" };
X.PARTS_LIMBS = { "UpperArm_L", "ForeArm_L", "Hand_L", "UpperArm_R", "ForeArm_R", "Hand_R", "UpperLeg_L", "LowerLeg_L", "Foot_L", "UpperLeg_R", "LowerLeg_R", "Foot_R" };
X.PARTS_SKIN = { "Head", "ForeArm_L", "Hand_L", "ForeArm_R", "Hand_R", "LowerLeg_L", "LowerLeg_R", "UpperLeg_L", "UpperLeg_R" };
X.PARTS_EXTREMITIES = { "Hand_L", "Hand_R", "Foot_L", "Foot_R" };
X.PARTS_FEET = { "Foot_L", "Foot_R" };
X.PARTS_JOINTS = { "UpperArm_L", "UpperArm_R", "ForeArm_L", "ForeArm_R", "UpperLeg_L", "UpperLeg_R" };
X.PARTS_KNEES = { "LowerLeg_L", "LowerLeg_R", "ForeArm_L", "ForeArm_R" };
X.PARTS_STITCH = { "ForeArm_L", "ForeArm_R", "LowerLeg_L", "LowerLeg_R" };
X.PARTS_SEPSIS = { "ForeArm_L", "ForeArm_R", "Hand_L", "Hand_R", "LowerLeg_L", "LowerLeg_R", "Foot_L", "Foot_R", "UpperLeg_L", "UpperLeg_R" };
X.PARTS_TORSO = { "Torso_Upper", "Torso_Lower" };

X.OLD_INJURIES = {
    { kind = "abrasion", weight = 30, parts = X.PARTS_SKIN },
    { kind = "bruise", weight = 30, parts = X.PARTS_ALL },
    { kind = "scarDeep", weight = 12, parts = X.PARTS_LIMBS },
    { kind = "sprain", weight = 10, parts = X.PARTS_EXTREMITIES },
    { kind = "debris", weight = 8, parts = X.PARTS_EXTREMITIES },
    { kind = "poorStitch", weight = 5, parts = X.PARTS_STITCH },
    { kind = "jointDamage", weight = 5, parts = X.PARTS_KNEES },
};
X.OLD_INJURY_MAX = 2;

X.SEPSIS_ORIGINS = { "poorStitch", "reopened", "puncture", "avulsion" };
X.SKIN_PREFIX = "WoundExpansion.WE_Skin_";

function X.isActive()
    if not TCA.Wounds.isModActivated(X.MOD_ID) then
        return false;
    end
    return WoundExpansion ~= nil and type(WoundExpansion.WOUND) == "table";
end

function X.getRoot(character)
    local root = character:getModData()[X.ROOT_KEY];
    if type(root) ~= "table" or type(root.parts) ~= "table" then
        return nil;
    end
    return root;
end

function X.clampStage(data)
    local stage = 1;
    if type(data) == "table" and tonumber(data.stage) then
        stage = math.floor(tonumber(data.stage));
    end
    return math.max(1, math.min(3, stage));
end

function X.collectEntryKinds(entry)
    local found = {};
    if type(entry.wounds) == "table" then
        for id, data in pairs(entry.wounds) do
            if id == X.FROSTBITE then
                found["frostbite" .. X.clampStage(data)] = true;
            elseif X.WOUND_KINDS[id] then
                found[X.WOUND_KINDS[id]] = true;
            end
        end
    end
    if type(entry.conditions) == "table" then
        for id, _ in pairs(entry.conditions) do
            if X.CONDITION_KINDS[id] then
                found[X.CONDITION_KINDS[id]] = true;
            end
        end
    end
    if type(entry.scars) == "table" then
        for id, value in pairs(entry.scars) do
            if value and X.SCAR_KINDS[id] then
                found[X.SCAR_KINDS[id]] = true;
            end
        end
    end
    local kinds = {};
    for i = 1, #X.KINDS do
        if found[X.KINDS[i]] then
            table.insert(kinds, X.KINDS[i]);
        end
    end
    return kinds;
end

function X.snapshot(player, list)
    local root = X.getRoot(player);
    local bodyDamage = player:getBodyDamage();
    if not root or not bodyDamage then
        return;
    end
    local parts = bodyDamage:getBodyParts();
    for i = 0, parts:size() - 1 do
        local part = parts:get(i);
        local entry = root.parts[part:getIndex()];
        if type(entry) == "table" then
            local name = BodyPartType.ToString(part:getType());
            local kinds = X.collectEntryKinds(entry);
            for j = 1, #kinds do
                TCA.Wounds.addKind(list, name, kinds[j]);
            end
        end
    end
end

function X.deathCause(character)
    local root = X.getRoot(character);
    if not root then
        return nil;
    end
    for i = 1, #X.DEATH_CONDITIONS do
        local wanted = X.DEATH_CONDITIONS[i];
        for _, entry in pairs(root.parts) do
            if type(entry) == "table" and type(entry.conditions) == "table" and entry.conditions[wanted.condition] ~= nil then
                return wanted.cause;
            end
        end
    end
    return nil;
end

function X.keepWornItem(item)
    local fullType = item:getFullType();
    return type(fullType) == "string" and string.sub(fullType, 1, #X.SKIN_PREFIX) == X.SKIN_PREFIX;
end

function X.pick(list)
    return list[ZombRand(#list) + 1];
end

function X.chance(percent)
    return ZombRand(100) < percent;
end

function X.add(list, part, kind)
    TCA.Wounds.addKind(list, part, kind);
end

function X.findPart(list, kind)
    local W = TCA.Wounds;
    for i = 1, #list do
        local wound = W.decodeWound(list[i]);
        if wound and wound.kind == kind then
            return wound.part;
        end
    end
    return nil;
end

function X.inventOldInjuries(list)
    local count = ZombRand(X.OLD_INJURY_MAX + 1);
    for i = 1, count do
        local injury = TCA.Wounds.pickWeighted(X.OLD_INJURIES);
        X.add(list, X.pick(injury.parts), injury.kind);
    end
end

function X.inventInfected(list)
    local part = X.findPart(list, "bite");
    if not part then
        return;
    end
    if X.chance(50) then
        X.add(list, part, "inflamed");
    end
    if X.chance(25) then
        X.add(list, part, "necrotic");
        if X.chance(50) then
            X.add(list, part, "maggots");
        end
    end
end

function X.inventBlunt(list)
    X.add(list, "Head", "bruise");
    if X.chance(60) then
        X.add(list, "Head", "concussion");
    end
end

function X.inventFall(list)
    if X.chance(50) then
        X.add(list, "Head", "concussion");
    end
    if X.chance(70) then
        X.add(list, X.pick(X.PARTS_FEET), "sprain");
    end
    if X.chance(40) then
        X.add(list, X.pick(X.PARTS_JOINTS), "dislocation");
    end
    if X.chance(50) then
        X.add(list, X.pick(X.PARTS_SKIN), "abrasion");
    end
end

function X.inventFirearm(list)
    local part = X.findPart(list, "bullet");
    if part == "Torso_Upper" or part == "Torso_Lower" then
        if X.chance(40) then
            X.add(list, part, "internalBleeding");
        end
    end
end

function X.inventBlade(list)
    if X.chance(30) then
        X.add(list, "Torso_Upper", "internalBleeding");
    end
end

function X.inventHemorrhage(list)
    local part = X.pick(X.PARTS_TORSO);
    X.add(list, part, "internalBleeding");
    X.add(list, part, "bruise");
    if X.chance(50) then
        X.add(list, X.pick(X.PARTS_SKIN), "abrasion");
    end
    if X.chance(30) then
        X.add(list, X.pick(X.PARTS_JOINTS), "dislocation");
    end
    if X.chance(40) then
        X.add(list, "Head", "concussion");
    end
end

function X.inventSepsis(list)
    local part = X.pick(X.PARTS_SEPSIS);
    X.add(list, part, X.pick(X.SEPSIS_ORIGINS));
    X.add(list, part, "inflamed");
    if X.chance(50) then
        X.add(list, part, "swollen");
    end
    if X.chance(70) then
        X.add(list, part, "necrotic");
        if X.chance(50) then
            X.add(list, part, "maggots");
        end
    end
    X.add(list, part, "sepsis");
end

function X.inventExposure(list)
    local part = X.pick(X.PARTS_EXTREMITIES);
    X.add(list, part, "frostbite" .. (ZombRand(3) + 1));
end

function X.invent(list, cause)
    X.inventOldInjuries(list);
    if cause == "infection" then
        X.inventInfected(list);
    elseif cause == "blunt" then
        X.inventBlunt(list);
    elseif cause == "fall" then
        X.inventFall(list);
    elseif cause == "firearm" then
        X.inventFirearm(list);
    elseif cause == "blade" then
        X.inventBlade(list);
    elseif cause == "hemorrhage" then
        X.inventHemorrhage(list);
    elseif cause == "sepsis" then
        X.inventSepsis(list);
    elseif cause == "exposure" then
        X.inventExposure(list);
    end
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
    naturalCauses = X.NATURAL_CAUSES,
    lethal = X.LETHAL_WOUNDS,
    snapshot = X.snapshot,
    deathCause = X.deathCause,
    invent = X.invent,
    keepWornItem = X.keepWornItem,
});
