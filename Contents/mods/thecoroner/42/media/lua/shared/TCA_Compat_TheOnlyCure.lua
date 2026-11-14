require "TCA_Wounds";

TCA = TCA or {};
TCA.Compat = TCA.Compat or {};
TCA.Compat.TheOnlyCure = TCA.Compat.TheOnlyCure or {};

local X = TCA.Compat.TheOnlyCure;

X.MOD_ID = "TheOnlyCure";
X.DATA_PREFIX = "TOC_";
X.SIDES = { "L", "R" };
X.CHAIN = { "Hand", "ForeArm", "UpperArm" };
X.ROOT = "Torso_Upper";
X.AMPUTATION_PREFIX = "TOC.Amputation_";
X.PROSTHESIS_PREFIX = "TOC.Prost_";
X.TOURNIQUET_PREFIX = "TOC.Surg_Arm_Tourniquet_";

X.KINDS = { "amputation", "amputationOpen", "amputationSealed", "amputationHealed", "prosthetic", "limbMissing", "tourniquet" };

X.MIN_LEVEL = {};

X.DETECT = {
    amputation = 1, amputationOpen = 1, amputationSealed = 1, amputationHealed = 1,
    prosthetic = 1, limbMissing = 1, tourniquet = 1,
};

X.CONFUSE = { amputationSealed = "amputationHealed", amputationHealed = "amputationSealed" };

X.CAUSES = { "hemorrhage" };

function X.isActive()
    if not TCA.Wounds.isModActivated(X.MOD_ID) then
        return false;
    end
    return TOC_DEBUG ~= nil and type(TOC_DEBUG) == "table";
end

function X.getData(player)
    if not ModData or not ModData.exists then
        return nil;
    end
    local username = player:getUsername();
    if not username then
        return nil;
    end
    local key = X.DATA_PREFIX .. username;
    if not ModData.exists(key) then
        return nil;
    end
    local data = ModData.get(key);
    if type(data) ~= "table" or type(data.limbs) ~= "table" then
        return nil;
    end
    return data;
end

function X.isCut(data, part)
    local entry = data.limbs[part];
    return type(entry) == "table" and entry.isCut == true;
end

function X.stumpKind(entry)
    if type(entry) ~= "table" then
        return "amputation";
    end
    if entry.isCicatrized then
        return "amputationHealed";
    end
    if entry.isCauterized then
        return "amputationSealed";
    end
    return "amputationOpen";
end

function X.hasProsthesis(data, side)
    if type(data.prostheses) ~= "table" then
        return false;
    end
    local group = data.prostheses["Top_" .. side];
    return type(group) == "table" and group.isProstEquipped == true;
end

function X.addSide(list, side, level, kind, prosthesis)
    if level <= 0 then
        return;
    end
    for i = 1, level do
        TCA.Wounds.addKind(list, X.CHAIN[i] .. "_" .. side, "limbMissing");
    end
    local stump = X.ROOT;
    if level < #X.CHAIN then
        stump = X.CHAIN[level + 1] .. "_" .. side;
    end
    TCA.Wounds.addKind(list, stump, kind);
    if prosthesis then
        TCA.Wounds.addKind(list, stump, "prosthetic");
    end
end

function X.snapshotFromData(data, list)
    for s = 1, #X.SIDES do
        local side = X.SIDES[s];
        local level = 0;
        for i = 1, #X.CHAIN do
            if X.isCut(data, X.CHAIN[i] .. "_" .. side) then
                level = i;
            end
        end
        if level > 0 then
            local entry = data.limbs[X.CHAIN[level] .. "_" .. side];
            X.addSide(list, side, level, X.stumpKind(entry), X.hasProsthesis(data, side));
        end
    end
end

function X.wornTypes(player)
    local types = {};
    local worn = player:getWornItems();
    if not worn then
        return types;
    end
    for i = 0, worn:size() - 1 do
        local item = worn:getItemByIndex(i);
        if item then
            local fullType = item:getFullType();
            if type(fullType) == "string" then
                table.insert(types, fullType);
            end
        end
    end
    return types;
end

function X.startsWith(text, prefix)
    return string.sub(text, 1, #prefix) == prefix;
end

function X.snapshotFromWorn(types, list)
    for s = 1, #X.SIDES do
        local side = X.SIDES[s];
        local level = 0;
        local prosthesis = false;
        for t = 1, #types do
            for i = 1, #X.CHAIN do
                if types[t] == X.AMPUTATION_PREFIX .. X.CHAIN[i] .. "_" .. side and i > level then
                    level = i;
                end
            end
            if X.startsWith(types[t], X.PROSTHESIS_PREFIX) and string.sub(types[t], -2) == "_" .. side then
                prosthesis = true;
            end
        end
        X.addSide(list, side, level, "amputation", prosthesis);
    end
end

function X.snapshotTourniquets(types, list)
    for t = 1, #types do
        if X.startsWith(types[t], X.TOURNIQUET_PREFIX) then
            local side = string.sub(types[t], -1);
            if side == "L" or side == "R" then
                TCA.Wounds.addKind(list, "UpperArm_" .. side, "tourniquet");
            end
        end
    end
end

function X.snapshot(player, list)
    local types = X.wornTypes(player);
    local data = X.getData(player);
    if data then
        X.snapshotFromData(data, list);
    else
        X.snapshotFromWorn(types, list);
    end
    X.snapshotTourniquets(types, list);
end

function X.deathCause(character)
    local data = X.getData(character);
    if not data then
        return nil;
    end
    for s = 1, #X.SIDES do
        local level = 0;
        for i = 1, #X.CHAIN do
            if X.isCut(data, X.CHAIN[i] .. "_" .. X.SIDES[s]) then
                level = i;
            end
        end
        if level > 0 then
            local entry = data.limbs[X.CHAIN[level] .. "_" .. X.SIDES[s]];
            if X.stumpKind(entry) == "amputationOpen" then
                return "hemorrhage";
            end
        end
    end
    return nil;
end

function X.keepWornItem(item)
    local fullType = item:getFullType();
    if type(fullType) ~= "string" then
        return false;
    end
    return X.startsWith(fullType, X.AMPUTATION_PREFIX) or X.startsWith(fullType, X.PROSTHESIS_PREFIX);
end

TCA.Wounds.registerProvider({
    id = X.MOD_ID,
    isActive = X.isActive,
    kinds = X.KINDS,
    minLevel = X.MIN_LEVEL,
    detect = X.DETECT,
    confuse = X.CONFUSE,
    causes = X.CAUSES,
    snapshot = X.snapshot,
    deathCause = X.deathCause,
    keepWornItem = X.keepWornItem,
});
