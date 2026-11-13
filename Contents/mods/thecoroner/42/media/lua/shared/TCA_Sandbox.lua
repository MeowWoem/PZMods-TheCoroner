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

local function readRawOption(name)
    local options = getSandboxOptions();
    if options then
        local option = options:getOptionByName(S.PAGE .. "." .. name);
        if option then
            return option:getValue();
        end
    end
    if SandboxVars and SandboxVars[S.PAGE] then
        return SandboxVars[S.PAGE][name];
    end
    return nil;
end

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

function S.getBoolean(name, fallback)
    local value = readRawOption(name);
    if value == true or value == false then
        return value;
    end
    return fallback;
end

function S.areOrgansEdible()
    return S.getBoolean("OrgansEdible", true);
end

function S.areOrgansInfectious()
    return S.getBoolean("OrgansInfectious", true);
end

function S.getTimeOfDeathMaxRatio()
    return S.getNumber("TimeOfDeathMaxRatio", 6, 2, 30);
end

function S.getMorgueCorpseChance()
    return S.getNumber("MorgueCorpseChance", 10, 0, 100);
end

function S.getMorgueInfectedChance()
    return S.getNumber("MorgueCorpseInfectedChance", 50, 0, 100);
end

function S.getXpMultiplier()
    return S.getNumber("XpMultiplier", 1, 0, 10);
end

function S.getTremorMultiplier()
    return S.getNumber("TremorMultiplier", 1, 0, 3);
end

function S.getBetaBlockerReduction()
    return S.getNumber("BetaBlockerTremorReduction", 50, 0, 100);
end

function S.getBetaBlockerDuration()
    return S.getNumber("BetaBlockerDuration", 4, 0.5, 24);
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
