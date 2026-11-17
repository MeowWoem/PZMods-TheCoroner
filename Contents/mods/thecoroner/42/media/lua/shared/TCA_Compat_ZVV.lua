require "TCA_Wounds";
require "TCA_Sandbox";
require "TCA_Rot";

TCA = TCA or {};
TCA.Compat = TCA.Compat or {};
TCA.Compat.ZVV = TCA.Compat.ZVV or {};

local Z = TCA.Compat.ZVV;

Z.MOD_ID = "ZVirusVaccine42BETA";
Z.MASKS = { "Hat_SurgicalMask", "Hat_DustMask", "Hat_GasMask", "Hat_BuildersRespirator" };
Z.GLOVES = { "Gloves_Surgical", "Gloves_Dish", "Gloves_LeatherGloves", "Gloves_LeatherGlovesBlack" };
Z.SACKS = { "Garbagebag", "Bag_TrashBag" };
Z.PLASTICS = { "Plasticbag", "Plasticbag_Bags", "Plasticbag_Clothing" };
Z.INFECTED_BLOOD = "LabItems.MatInfectedBlood";
Z.TAINTED_BLOOD = "LabItems.MatTaintedBlood";
Z.SACK_REMAINS = "LabItems.LabGarbageBagWithRemains";
Z.PLASTIC_REMAINS = "LabItems.LabPlasticBagWithRemains";
Z.BRAIN = "RANDOM_BRAIN";
Z.BRAIN_HIGH = "LabItems.HumanBrainHigh";
Z.BRAIN_MID = "LabItems.HumanBrainMid";
Z.BRAIN_LOW = "LabItems.HumanBrainLow";
Z.PARTS = {
    { itemType = "RANDOM_BRAIN", text = "ContextMenu_LabCollectBrain", icon = "LabItems.HumanBrainHigh" },
    { itemType = "LabItems.LabHumanBoneLargeWP", text = "ContextMenu_LabCollectLargeBones", icon = "LabItems.LabHumanBoneLargeWP" },
    { itemType = "LabItems.LabHumanTeeth", text = "ContextMenu_LabCollectTeeth", icon = "LabItems.LabHumanTeeth" },
    { itemType = "LabItems.LabHumanSkullWithBrain", text = "ContextMenu_LabCollectSkull", icon = "LabItems.LabHumanSkullWithBrain" },
    { itemType = "LabItems.LabSmallRandomHumanBones", text = "ContextMenu_LabCollectSmallBones", icon = "LabItems.LabSmallRandomHumanBones" },
    { itemType = "LabItems.LabRegularHumanBoneWP", text = "ContextMenu_LabCollectRegularBones", icon = "LabItems.LabRegularHumanBoneWP" },
};
Z.PART_SET = {};
for _, part in ipairs(Z.PARTS) do
    Z.PART_SET[part.itemType] = true;
end
Z.BRAIN_XP = {};
Z.BRAIN_XP[Z.BRAIN_HIGH] = 1.5;
Z.BRAIN_XP[Z.BRAIN_MID] = 1.2;
Z.BRAIN_XP[Z.BRAIN_LOW] = 0.5;
Z.PART_DURATION = 220;
Z.PANIC = 25;
Z.KEY_AUTOPSY = "Autopsy";
Z.KEY_REWARDED = "AutopsyRewarded";

function Z.isActive()
    return TCA.Wounds.isModActivated(Z.MOD_ID) and SandboxVars.ZombieVirusVaccineBETA ~= nil;
end

function Z.isMenuBlocked()
    return TCA.Sandbox.isZVVAutopsyBlocked();
end

function Z.option(name, fallback)
    local vars = SandboxVars.ZombieVirusVaccineBETA;
    if not vars or vars[name] == nil then
        return fallback;
    end
    return vars[name];
end

function Z.isGroundAllowed()
    return Z.option("AllowAutopsyOnGround", true) == true;
end

function Z.getMaxHours()
    return tonumber(Z.option("AutopsyMaxHours", 12)) or 12;
end

function Z.getTableSpeedBonus()
    local value = tonumber(Z.option("TableSpeedBonus", 6)) or 6;
    return (value - 1) * 10;
end

function Z.isRLPActive()
    return _G.RLPTraitEffects ~= nil;
end

function Z.isIntern(character)
    if not Z.isRLPActive() or not RLP or not RLP.CharacterTrait or not RLP.CharacterTrait.AUTOPSY_SPECIALIST then
        return false;
    end
    return character:hasTrait(RLP.CharacterTrait.AUTOPSY_SPECIALIST);
end

function Z.isDoctor(character)
    return character:getDescriptor():getCharacterProfession() == CharacterProfession.DOCTOR;
end

function Z.getScience(character)
    if not Perks.Science then
        return 0;
    end
    return character:getPerkLevel(Perks.Science);
end

function Z.getCorpseAge(body)
    local md = body:getModData();
    local deathTime = md.DeathTime or md.deathTime or md.death_time;
    if not deathTime then
        deathTime = body:getDeathTime();
    end
    if not deathTime then
        return 0;
    end
    return math.max(0, getGameTime():getWorldAgeHours() - deathTime);
end

function Z.isFresh(body)
    return not body:isSkeleton() and Z.getCorpseAge(body) <= Z.getMaxHours();
end

function Z.isAutopsied(body)
    return body:getModData()[Z.KEY_AUTOPSY] == true;
end

function Z.isOnTable(body)
    return TCA.Rot.isOnTable(body);
end

function Z.notBroken(item)
    return item ~= nil and not item:isBroken();
end

function Z.isEmptyBag(item)
    if not item then
        return false;
    end
    if not instanceof(item, "InventoryContainer") then
        return true;
    end
    local inv = item:getInventory();
    return inv == nil or inv:isEmpty();
end

function Z.findFirst(inv, types, predicate)
    for _, itemType in ipairs(types) do
        local item = inv:getFirstTypeEvalRecurse(itemType, predicate);
        if item then
            return item;
        end
    end
    return nil;
end

function Z.collect(inv, types, limit, predicate)
    local found = {};
    for _, itemType in ipairs(types) do
        local list = inv:getAllTypeEvalRecurse(itemType, predicate);
        for i = 0, list:size() - 1 do
            table.insert(found, list:get(i));
            if #found >= limit then
                return found;
            end
        end
    end
    return nil;
end

function Z.findScalpel(inv)
    return inv:getFirstTypeEvalRecurse("Scalpel", Z.notBroken);
end

function Z.findTweezers(inv)
    return inv:getFirstTypeEvalRecurse("Tweezers", Z.notBroken);
end

function Z.findSaw(inv)
    return inv:getFirstTypeRecurse("Saw");
end

function Z.findSack(inv)
    return Z.findFirst(inv, Z.SACKS, Z.isEmptyBag);
end

function Z.findPlastics(inv)
    return Z.collect(inv, Z.PLASTICS, 2, Z.isEmptyBag);
end

function Z.getAutopsyDuration(character, onTable)
    local time = tonumber(Z.option("AutopsySpeed", 1200)) or 1200;
    local perk = character:getPerkLevel(Perks.Doctor);
    if perk > 1 then
        time = time - (perk - 1) * (tonumber(Z.option("TicksDecreasedByPerkLv", 30)) or 30);
    end
    if Z.isDoctor(character) then
        time = math.floor(time * 0.80);
    end
    if onTable then
        time = math.floor(time * (1.0 - Z.getTableSpeedBonus() / 100));
    end
    if character:hasTrait(CharacterTrait.HEMOPHOBIC) then
        time = math.floor(time * 1.20);
    end
    if Z.isRLPActive() then
        time = _G.RLPTraitEffects.ModifyAutopsyDuration(character, time);
    end
    local science = Z.getScience(character);
    if science > 0 then
        time = math.floor(time * (1.0 - science * 0.01));
    end
    return math.max(1, time);
end

function Z.addItem(inv, fullType)
    local item = inv:AddItem(fullType);
    if item and isServer() then
        sendAddItemToContainer(inv, item);
    end
    return item;
end

function Z.removeItem(item)
    local container = item and item:getContainer();
    if not container then
        return;
    end
    container:Remove(item);
    if isServer() then
        sendRemoveItemFromContainer(container, item);
    end
end

function Z.panic(character)
    if not character:hasTrait(CharacterTrait.HEMOPHOBIC) then
        return;
    end
    character:getStats():add(CharacterStat.PANIC, Z.PANIC);
    if isServer() then
        syncPlayerStats(character, SyncPlayerStatsPacket.getBitMaskForStat(CharacterStat.PANIC));
    end
end

function Z.splat(character, amount)
    local square = character:getCurrentSquare();
    if square then
        addBloodSplat(square, ZombRand(amount));
    end
end

function Z.sendFeedback(character, command, key, value)
    if isServer() then
        local args = {};
        args[key] = value;
        sendServerCommand(character, Z.MOD_ID, command, args);
        return;
    end
    if command == "AutopsyFeedback" and Events.OnLabAutopsyComplete then
        triggerEvent("OnLabAutopsyComplete", character, value);
    elseif command == "MorgueFeedback" and Events.OnLabMorgueAction then
        triggerEvent("OnLabMorgueAction", character, value);
    end
end

function Z.markAutopsied(body)
    local md = body:getModData();
    md[Z.KEY_AUTOPSY] = true;
    md[Z.KEY_REWARDED] = true;
    if isServer() then
        body:transmitModData();
    end
end

function Z.getXpMultiplier(character)
    local multiplier = 1.0;
    if Z.isRLPActive() then
        multiplier = _G.RLPTraitEffects.ModifyAutopsyXPMultiplier(character, multiplier);
    end
    if Z.isDoctor(character) then
        multiplier = multiplier * 1.10;
    end
    return multiplier;
end

function Z.tableSamples(character, inv, xp)
    local count = 3;
    if Z.isDoctor(character) then
        count = 4;
    end
    if Z.isRLPActive() then
        count = _G.RLPTraitEffects.ModifyAutopsySampleCount(character, count);
    end
    local science = Z.getScience(character);
    if science > 0 and ZombRand(100) < math.min(science * 3, 30) then
        count = count + 1;
    end
    local chance = 50 + character:getPerkLevel(Perks.Doctor);
    if Z.isDoctor(character) then
        chance = chance + 5;
    end
    if character:hasTrait(CharacterTrait.HEMOPHOBIC) then
        chance = chance - 15;
    end
    if Z.isRLPActive() then
        chance = _G.RLPTraitEffects.ModifyAutopsyInfectedBloodChance(character, chance);
    end
    local perSample = xp / count;
    local infected = false;
    local tainted = false;
    for i = 1, count do
        if ZombRand(100) < chance then
            Z.addItem(inv, Z.INFECTED_BLOOD);
            infected = true;
            addXp(character, Perks.Doctor, perSample * 1.3);
        else
            Z.addItem(inv, Z.TAINTED_BLOOD);
            tainted = true;
            addXp(character, Perks.Doctor, perSample * 0.8);
        end
    end
    if infected then
        return "Infected";
    elseif tainted then
        return "Tainted";
    end
    return "Nothing";
end

function Z.groundSamples(character, inv, xp)
    local baseInfected = 40;
    local baseTainted = 36;
    local baseNothing = 24;
    local science = Z.getScience(character);
    local skillReduction = 1.2 * character:getPerkLevel(Perks.Doctor);
    local totalReduction = skillReduction + science * 0.5;
    if Z.isRLPActive() then
        totalReduction = _G.RLPTraitEffects.ModifyGroundAutopsyNothingReduction(character, totalReduction);
    end
    if totalReduction > baseNothing then
        totalReduction = baseNothing;
    end
    local appliedSkill = math.min(skillReduction, totalReduction);
    local appliedScience = totalReduction - appliedSkill;
    local finalInfected = baseInfected + appliedSkill * 0.6 + appliedScience;
    local finalTainted = baseTainted + appliedSkill * 0.4;
    local rolls = 1;
    if science > 0 and ZombRand(100) < math.min(science * 3, 30) then
        rolls = 2;
    end
    local result = "Nothing";
    for i = 1, rolls do
        local roll = ZombRand(100);
        if roll < finalInfected then
            Z.addItem(inv, Z.INFECTED_BLOOD);
            result = "Infected";
        elseif roll < finalInfected + finalTainted then
            Z.addItem(inv, Z.TAINTED_BLOOD);
            if result ~= "Infected" then
                result = "Tainted";
            end
        end
    end
    if result == "Tainted" then
        xp = xp * 0.5;
    elseif result == "Nothing" then
        xp = xp * 0.2;
    end
    addXp(character, Perks.Doctor, xp);
    return result;
end

function Z.doAutopsy(character, body)
    if not character or not body then
        return nil;
    end
    if body:getModData()[Z.KEY_REWARDED] == true then
        Z.markAutopsied(body);
        Z.sendFeedback(character, "AutopsyFeedback", "result", "AlreadyAutopsied");
        Z.splat(character, 5);
        return "AlreadyAutopsied";
    end
    local onTable = Z.isOnTable(body);
    local inv = character:getInventory();
    local xp;
    if onTable then
        xp = tonumber(Z.option("AutopsyTableXP", 30)) or 30;
    else
        xp = tonumber(Z.option("AutopsyGroundXP", 15)) or 15;
    end
    xp = xp * Z.getXpMultiplier(character);
    local result;
    if onTable then
        result = Z.tableSamples(character, inv, xp);
    else
        result = Z.groundSamples(character, inv, xp);
    end
    Z.markAutopsied(body);
    Z.sendFeedback(character, "AutopsyFeedback", "result", result);
    Z.panic(character);
    Z.splat(character, 20);
    return result;
end

function Z.rollBrain(character)
    local skillScore = character:getPerkLevel(Perks.Butchering) * 2 + character:getPerkLevel(Perks.Doctor) * 2;
    local intern = Z.isIntern(character);
    local doctor = Z.isDoctor(character);
    local profBonus = 0;
    local maxScore = 40;
    local ceiling = 30;
    if intern then
        profBonus = 30;
        maxScore = 70;
        ceiling = 50;
    elseif doctor then
        profBonus = 18;
        maxScore = 58;
        ceiling = 40;
    end
    local debuff = 0;
    if character:hasTrait(CharacterTrait.HEMOPHOBIC) then
        debuff = tonumber(Z.option("HemophobicDebuff", 10)) or 10;
    end
    local score = math.max(0, skillScore + profBonus - debuff);
    local science = Z.getScience(character);
    if science > 0 then
        ceiling = ceiling + math.min(science * 0.5, 5);
    end
    local t = math.min(score / maxScore, 1.0);
    local offset = tonumber(Z.option("BrainHighOffset", 10)) or 10;
    local chanceHigh = offset + (t ^ 1.2) * (ceiling - offset);
    local remaining = 100 - chanceHigh;
    local midRatio = 0.33 + (t ^ 0.8) * (0.57 - 0.33);
    local chanceMid = remaining * midRatio;
    local roll = ZombRand(1000) / 10;
    if roll < chanceHigh then
        return Z.BRAIN_HIGH;
    elseif roll < chanceHigh + chanceMid then
        return Z.BRAIN_MID;
    end
    return Z.BRAIN_LOW;
end

function Z.wearTool(character, item)
    if not item then
        return;
    end
    item:setCondition(item:getCondition() - 1);
    if item:getCondition() <= 0 then
        Z.removeItem(item);
    elseif isServer() then
        syncItemFields(character, item);
    end
end

function Z.removeBody(body)
    local square = body:getSquare();
    if not square then
        return;
    end
    square:removeCorpse(body, false);
end

function Z.collectPart(character, body, itemType)
    if not character or not body or not Z.PART_SET[itemType] then
        return false;
    end
    local inv = character:getInventory();
    if not Z.findScalpel(inv) or not Z.findSaw(inv) then
        return false;
    end
    local sack = Z.findSack(inv);
    local plastics = nil;
    if not sack then
        plastics = Z.findPlastics(inv);
        if not plastics then
            return false;
        end
    end
    local finalType = itemType;
    if itemType == Z.BRAIN then
        finalType = Z.rollBrain(character);
    end
    if Z.option("AllowScalpelDegrade", false) == true then
        Z.wearTool(character, Z.findScalpel(inv));
    end
    if Z.option("AllowSawDegrade", true) == true then
        Z.wearTool(character, Z.findSaw(inv));
    end
    if sack then
        Z.removeItem(sack);
        Z.addItem(inv, Z.SACK_REMAINS);
    else
        for _, bag in ipairs(plastics) do
            Z.removeItem(bag);
        end
        Z.addItem(inv, Z.PLASTIC_REMAINS);
        Z.addItem(inv, Z.PLASTIC_REMAINS);
    end
    Z.addItem(inv, finalType);
    local xp = tonumber(Z.option("CollectPartXP", 15)) or 15;
    local brainXp = Z.BRAIN_XP[finalType];
    if brainXp then
        addXp(character, Perks.Butchering, xp * brainXp);
        addXp(character, Perks.Doctor, math.floor(xp * brainXp * 0.5));
    else
        addXp(character, Perks.Butchering, xp);
    end
    Z.splat(character, 15);
    Z.panic(character);
    Z.removeBody(body);
    Z.sendFeedback(character, "MorgueFeedback", "action", "BodyPartCollected");
    return true;
end
