require "TCA_Sandbox";
require "TimedActions/ISTakePillAction";

TCA = TCA or {};
TCA.BetaBlocker = TCA.BetaBlocker or {};

local B = TCA.BetaBlocker;

B.ITEM = "Base.PillsBeta";
B.KEY = "TCA_BetaUntil";

function B.now()
    return getGameTime():getWorldAgeHours();
end

function B.getRemainingHours(character)
    if not character then
        return 0;
    end
    local untilTime = tonumber(character:getModData()[B.KEY]);
    if not untilTime then
        return 0;
    end
    local remaining = untilTime - B.now();
    if remaining <= 0 then
        character:getModData()[B.KEY] = nil;
        return 0;
    end
    return remaining;
end

function B.isActive(character)
    return B.getRemainingHours(character) > 0;
end

function B.getTremorFactor(character)
    if not B.isActive(character) then
        return 1;
    end
    return 1 - TCA.Sandbox.getBetaBlockerReduction() / 100;
end

function B.onTaken(character)
    if not character then
        return;
    end
    character:getModData()[B.KEY] = B.now() + TCA.Sandbox.getBetaBlockerDuration();
end

function B.isBetaItem(item)
    return item ~= nil and instanceof(item, "InventoryItem") and item:getFullType() == B.ITEM;
end

B.originalPerform = B.originalPerform or ISTakePillAction.perform;

function B.perform(self)
    local isBeta = B.isBetaItem(self.item);
    local character = self.character;
    B.originalPerform(self);
    if isBeta then
        B.onTaken(character);
    end
end

ISTakePillAction.perform = B.perform;
