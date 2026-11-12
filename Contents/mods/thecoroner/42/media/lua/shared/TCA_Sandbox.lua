require "TCA_Shared";

TCA = TCA or {};
TCA.Sandbox = TCA.Sandbox or {};

local S = TCA.Sandbox;

S.PAGE = "TheCoroner";

S.XP_OPTIONS = {
    autopsy = "AutopsyXpMultiplier",
    timeOfDeath = "TimeOfDeathXpMultiplier",
    cause = "CauseOfDeathXpMultiplier",
};

local function readOption(name)
    local options = getSandboxOptions();
    if options then
        local option = options:getOptionByName(S.PAGE .. "." .. name);
        if option then
            local value = tonumber(option:getValue());
            if value ~= nil then
                return value;
            end
        end
    end
    if SandboxVars and SandboxVars[S.PAGE] then
        return tonumber(SandboxVars[S.PAGE][name]);
    end
    return nil;
end

function S.getNumber(name, fallback, minValue, maxValue)
    local value = readOption(name);
    if value == nil or value ~= value then
        return fallback;
    end
    if value < minValue then
        return minValue;
    end
    if value > maxValue then
        return maxValue;
    end
    return value;
end

function S.getXpMultiplier()
    return S.getNumber("XpMultiplier", 1, 0, 10);
end

function S.getTremorMultiplier()
    return S.getNumber("TremorMultiplier", 1, 0, 3);
end

function S.getKindXpMultiplier(kind)
    local name = S.XP_OPTIONS[kind];
    if not name then
        return 1;
    end
    return S.getNumber(name, 1, 0, 10);
end

function S.applyXp(xp, kind)
    return (tonumber(xp) or 0) * S.getXpMultiplier() * S.getKindXpMultiplier(kind);
end
