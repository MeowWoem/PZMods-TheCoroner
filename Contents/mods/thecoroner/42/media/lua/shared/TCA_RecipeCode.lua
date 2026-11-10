TCA_RecipeCode = TCA_RecipeCode or {};

local R = TCA_RecipeCode;

R.LIVER_TAN_MAX_DECAY = 2;
R.CATGUT_MAX_DECAY = 1;
R.CATGUT_MAX_DAMAGE = 2;
R.CANTEEN_MAX_DECAY = 1;
R.CANTEEN_MAX_DAMAGE = 0;

function R.getDecay(item)
    return math.floor(tonumber(item:getModData()["TCA_Decay"]) or 0);
end

function R.getDamage(item)
    return math.floor(tonumber(item:getModData()["TCA_Damage"]) or 0);
end

function R.isInfected(item)
    return item:getModData()["TCA_Infected"] == true;
end

function R.testLiverTan(item, character)
    if not item or item:getFullType() ~= "TCA.Organ_liver" then
        return true;
    end
    return R.getDecay(item) <= R.LIVER_TAN_MAX_DECAY;
end

function R.testCatgut(item, character)
    if not item or item:getFullType() ~= "TCA.Organ_intestines" then
        return true;
    end
    if R.isInfected(item) then
        return false;
    end
    if R.getDecay(item) > R.CATGUT_MAX_DECAY then
        return false;
    end
    return R.getDamage(item) <= R.CATGUT_MAX_DAMAGE;
end

function R.testBladderCanteen(item, character)
    if not item or item:getFullType() ~= "TCA.Organ_bladder" then
        return true;
    end
    if R.isInfected(item) then
        return false;
    end
    if R.getDecay(item) > R.CANTEEN_MAX_DECAY then
        return false;
    end
    return R.getDamage(item) <= R.CANTEEN_MAX_DAMAGE;
end
