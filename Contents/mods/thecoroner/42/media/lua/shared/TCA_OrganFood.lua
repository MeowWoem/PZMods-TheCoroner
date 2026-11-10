TCA_OrganFood = TCA_OrganFood or {};

local F = TCA_OrganFood;

F.FRESH_RATIO = 0.5;
F.STALE_RATIO = 0.5;
F.ROTTEN_EXTRA_DAYS = 1;
F.STALE_POISON = 20;
F.ROTTEN_POISON = 40;
F.INFECTED_POISON = 100;
F.TRANSMISSION_NONE = 4;
F.MORTALITY_NEVER = 7;

function F.isFood(item)
    return item ~= nil and item.IsFood ~= nil and item:IsFood();
end

function F.getDecayLevel(item)
    if not item then
        return 0;
    end
    if not F.isFood(item) then
        return math.floor(tonumber(item:getModData()["TCA_Decay"]) or 0);
    end
    local age = item:getAge();
    local fresh = item:getOffAge();
    local rotten = item:getOffAgeMax();
    if age >= rotten then
        return 3;
    elseif age >= fresh then
        return 2;
    elseif age >= fresh * F.FRESH_RATIO then
        return 1;
    end
    return 0;
end

function F.getAgeForDecay(item, decay)
    local fresh = item:getOffAge();
    local rotten = item:getOffAgeMax();
    if decay >= 3 then
        return rotten + F.ROTTEN_EXTRA_DAYS;
    elseif decay == 2 then
        return fresh + (rotten - fresh) * F.STALE_RATIO;
    elseif decay == 1 then
        return fresh * F.FRESH_RATIO;
    end
    return 0;
end

function F.getPoisonForState(decay, infected)
    if infected then
        return F.INFECTED_POISON;
    elseif decay >= 3 then
        return F.ROTTEN_POISON;
    elseif decay == 2 then
        return F.STALE_POISON;
    end
    return 0;
end

function F.applyExtraction(item, decay, infected)
    if not F.isFood(item) then
        return;
    end
    decay = math.max(0, math.min(3, math.floor(tonumber(decay) or 0)));
    item:setAge(F.getAgeForDecay(item, decay));
    local poison = F.getPoisonForState(decay, infected == true);
    if poison > 0 then
        item:setPoisonPower(poison);
    end
end

function F.canInfect()
    local lore = SandboxVars and SandboxVars.ZombieLore;
    if not lore then
        return true;
    end
    if lore.Transmission == F.TRANSMISSION_NONE then
        return false;
    end
    return lore.Mortality ~= F.MORTALITY_NEVER;
end

function F.infect(character)
    if not character or not F.canInfect() then
        return;
    end
    local bodyDamage = character:getBodyDamage();
    if not bodyDamage then
        return;
    end
    local part = bodyDamage:getBodyPart(BodyPartType.Torso_Lower);
    if part and not part:IsInfected() then
        part:SetInfected(true);
    end
end

function F.onEat(food, character, percent)
    if not food or not character then
        return;
    end
    if food:getModData()["TCA_Infected"] == true then
        F.infect(character);
    end
end
