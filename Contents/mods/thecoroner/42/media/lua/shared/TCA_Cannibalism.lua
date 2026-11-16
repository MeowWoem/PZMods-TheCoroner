require "TCA_Shared";
require "TCA_Sandbox";
require "TCA_Wounds";
require "TimedActions/ISEatFoodAction";

TCA = TCA or {};
TCA.Cannibal = TCA.Cannibal or {};

local C = TCA.Cannibal;

C.ORGAN_PREFIX = "TCA.Organ_";
C.EVOLVED_FACTOR = 0.3;
C.KEY = "TCA_Cannibal";

C.STRESS_HIT = 0.25;
C.UNHAPPY_HIT = 25;
C.FIRST_UNHAPPY = 15;
C.FIRST_SICKNESS = 25;
C.GUILT_HOURS = 12;
C.GUILT_FLOOR = 20;
C.HABIT_MIN = 0.25;
C.EXPOSURE_DECAY_PER_DAY = 1;
C.SENSITIVITY_MIN = 0.25;
C.SENSITIVITY_MAX = 2;

C.RELIEF_STRESS = 0.15;
C.RELIEF_UNHAPPY = 10;
C.RELIEF_BOREDOM = 10;
C.CRAVING_START_HOURS = 24;
C.CRAVING_FULL_HOURS = 72;
C.CRAVING_UNHAPPY = 40;
C.CRAVING_BOREDOM = 30;
C.CRAVING_STRESS = 0.3;
C.FLOOR_STEP_UNHAPPY = 2;
C.FLOOR_STEP_BOREDOM = 2;
C.FLOOR_STEP_STRESS = 0.02;

C.SUPPORTED_MODS = { "HarvestZCannibalism", "CZA" };

C.HARVESTZ_PRESETS = {
    SoundPresetOff = { 0, 0 },
    SoundPresetLow = { 1, 1 },
    SoundPresetMed = { 2, 1 },
    SoundPresetHigh = { 3, 2 },
};
C.HARVESTZ_PRESET_ORDER = { "SoundPresetOff", "SoundPresetLow", "SoundPresetMed", "SoundPresetHigh" };

C.CZA_RELIEF = 15;
C.CZA_MORALE = 0.10;
C.CZA_BOREDOM = 0.08;

function C.isHarvestZActive()
    return TCA.Wounds.isModActivated("HarvestZCannibalism") and SandboxVars ~= nil and SandboxVars.Cannibalism ~= nil;
end

function C.getCZATrait()
    if not TCA.Wounds.isModActivated("CZA") then
        return nil;
    end
    if CZA and CZA.CharacterTrait and CZA.CharacterTrait.Cannibal then
        return CZA.CharacterTrait.Cannibal;
    end
    return nil;
end

function C.findSupportedMod()
    if C.isHarvestZActive() then
        return "HarvestZCannibalism";
    end
    if C.getCZATrait() then
        return "CZA";
    end
    return "";
end

function C.getSupportedMod()
    if C.supported == nil then
        C.supported = C.findSupportedMod();
    end
    if C.supported == "" then
        return nil;
    end
    return C.supported;
end

function C.getTrait()
    if TCA.CharacterTrait and TCA.CharacterTrait.Cannibal then
        return TCA.CharacterTrait.Cannibal;
    end
    return nil;
end

function C.hasOwnTrait(character)
    local trait = C.getTrait();
    return trait ~= nil and character:hasTrait(trait);
end

function C.isHumanFoodType(fullType)
    return fullType ~= nil and string.sub(tostring(fullType), 1, string.len(C.ORGAN_PREFIX)) == C.ORGAN_PREFIX;
end

function C.isCooked(item)
    return item:isCooked() or item:isBurnt();
end

function C.now()
    return getGameTime():getWorldAgeHours();
end

function C.getData(character)
    local md = character:getModData();
    local data = md[C.KEY];
    if type(data) ~= "table" then
        data = {};
        data.meals = 0;
        data.exposure = 0;
        data.last = -1;
        data.guiltUntil = -1;
        data.guiltFloor = 0;
        md[C.KEY] = data;
    end
    return data;
end

function C.getSensitivity(character)
    local s = 1;
    if character:hasTrait(CharacterTrait.HEMOPHOBIC) then
        s = s * 1.5;
    end
    if character:hasTrait(CharacterTrait.COWARDLY) then
        s = s * 1.25;
    end
    if character:hasTrait(CharacterTrait.WEAK_STOMACH) then
        s = s * 1.25;
    end
    if character:hasTrait(CharacterTrait.BRAVE) then
        s = s * 0.75;
    end
    if character:hasTrait(CharacterTrait.IRON_GUT) then
        s = s * 0.75;
    end
    if character:hasTrait(CharacterTrait.DESENSITIZED) then
        s = s * 0.5;
    end
    local desc = character:getDescriptor();
    if desc and (desc:isCharacterProfession(CharacterProfession.DOCTOR) or desc:isCharacterProfession(CharacterProfession.NURSE)) then
        s = s * 0.75;
    end
    return math.max(C.SENSITIVITY_MIN, math.min(C.SENSITIVITY_MAX, s));
end

C.touched = {};

function C.addStat(character, stat, amount)
    local stats = character:getStats();
    if amount >= 0 then
        stats:add(stat, amount);
    else
        stats:remove(stat, -amount);
    end
    C.touched[stat] = true;
end

function C.raiseToFloor(character, stat, floor, step)
    local current = character:getStats():get(stat);
    if current < floor then
        C.addStat(character, stat, math.min(floor - current, step));
    end
end

function C.flushStats(character)
    if isServer() then
        for stat, _ in pairs(C.touched) do
            syncPlayerStats(character, SyncPlayerStatsPacket.getBitMaskForStat(stat));
        end
    end
    C.touched = {};
end

function C.notify(character, key)
    if isServer() then
        local args = {};
        args.key = key;
        sendServerCommand(character, "TCA", "cannibalHalo", args);
        return;
    end
    C.showHalo(character, key);
end

function C.showHalo(character, key)
    if character and HaloTextHelper then
        HaloTextHelper.addBadText(character, getText(key));
    end
end

function C.grantTrait(character, data)
    local trait = C.getTrait();
    if not trait or character:hasTrait(trait) then
        return;
    end
    character:getCharacterTraits():add(trait);
    data.guiltUntil = -1;
    data.guiltFloor = 0;
    if isServer() then
        sendSyncPlayerFields(character, 2);
    end
    C.notify(character, "IGUI_TCA_CannibalTraitGained");
end

function C.applyOwn(character, amount)
    local data = C.getData(character);
    local now = C.now();
    if C.hasOwnTrait(character) then
        C.addStat(character, CharacterStat.STRESS, -C.RELIEF_STRESS * amount);
        C.addStat(character, CharacterStat.UNHAPPINESS, -C.RELIEF_UNHAPPY * amount);
        C.addStat(character, CharacterStat.BOREDOM, -C.RELIEF_BOREDOM * amount);
        data.last = now;
        data.meals = data.meals + amount;
        return;
    end
    local strength = TCA.Sandbox.getCannibalismStrength();
    local threshold = TCA.Sandbox.getCannibalTraitMeals();
    local habit = math.max(C.HABIT_MIN, 1 - data.exposure / math.max(1, threshold));
    local f = C.getSensitivity(character) * strength * habit;
    local hit = math.min(amount, 1.5);
    local first = data.meals <= 0;
    C.addStat(character, CharacterStat.STRESS, C.STRESS_HIT * f * hit);
    local unhappy = C.UNHAPPY_HIT * f * hit;
    if first then
        unhappy = unhappy + C.FIRST_UNHAPPY * f;
        C.addStat(character, CharacterStat.FOOD_SICKNESS, C.FIRST_SICKNESS * f);
    end
    C.addStat(character, CharacterStat.UNHAPPINESS, unhappy);
    data.guiltUntil = math.max(data.guiltUntil, now + C.GUILT_HOURS * f);
    data.guiltFloor = math.max(data.guiltFloor, C.GUILT_FLOOR * f);
    data.exposure = data.exposure + amount;
    data.meals = data.meals + amount;
    data.last = now;
    if first then
        C.notify(character, "IGUI_TCA_CannibalFirst");
    end
    if TCA.Sandbox.isCannibalTraitEnabled() and data.meals >= threshold then
        C.grantTrait(character, data);
    end
end

function C.getHarvestZPoints(cooked)
    local vars = SandboxVars.Cannibalism;
    local index = 1;
    if cooked then
        index = 2;
    end
    for _, key in ipairs(C.HARVESTZ_PRESET_ORDER) do
        if vars[key] then
            return C.HARVESTZ_PRESETS[key][index];
        end
    end
    if cooked then
        return tonumber(vars.CookedHumanMeatInsanityPointsGain) or 0;
    end
    return tonumber(vars.RawHumanMeatInsanityPointsGain) or 0;
end

function C.applyHarvestZ(character, organs, extras, cooked)
    local points = C.getHarvestZPoints(cooked);
    local multiplier = tonumber(SandboxVars.Cannibalism.EvolvedRecipeInsanityPointsMultiplier) or 1;
    local change = points * organs + points * extras * multiplier;
    if change <= 0 then
        return;
    end
    local args = {};
    args.change = change;
    if isServer() then
        sendServerCommand(character, "Cannibalism", "insanity", args);
    else
        triggerEvent("OnServerCommand", "Cannibalism", "insanity", args);
    end
end

function C.applyCZA(character, amount, cooked)
    local trait = C.getCZATrait();
    if not trait or not cooked or not character:hasTrait(trait) then
        return;
    end
    local md = character:getModData();
    md.CZA_cravingHours = math.max(0, (md.CZA_cravingHours or 0) - C.CZA_RELIEF * amount);
    C.addStat(character, CharacterStat.MORALE, C.CZA_MORALE * amount);
    C.addStat(character, CharacterStat.BOREDOM, -C.CZA_BOREDOM * amount);
    C.addStat(character, CharacterStat.STRESS, -math.min(1, C.CZA_RELIEF / 55) * amount);
end

function C.measure(item)
    local result = {};
    result.organs = 0;
    result.extras = 0;
    result.cooked = false;
    if not item or not instanceof(item, "Food") then
        return result;
    end
    if C.isHumanFoodType(item:getFullType()) then
        result.organs = 1;
    end
    if item:haveExtraItems() then
        local extras = item:getExtraItems();
        for i = 0, extras:size() - 1 do
            if C.isHumanFoodType(extras:get(i)) then
                result.extras = result.extras + 1;
            end
        end
    end
    result.cooked = C.isCooked(item);
    return result;
end

function C.onEaten(character, measured, portion)
    if not character or (measured.organs <= 0 and measured.extras <= 0) then
        return;
    end
    local mod = C.getSupportedMod();
    if mod == "HarvestZCannibalism" then
        C.applyHarvestZ(character, measured.organs, measured.extras, measured.cooked);
        return;
    end
    local amount = (measured.organs + measured.extras * C.EVOLVED_FACTOR) * math.max(0, math.min(1, portion or 1));
    if amount <= 0 then
        return;
    end
    if mod == "CZA" then
        C.applyCZA(character, amount, measured.cooked);
    elseif TCA.Sandbox.areCannibalismEffectsEnabled() then
        C.applyOwn(character, amount);
    end
    C.flushStats(character);
end

function C.forEachPlayer(callback)
    if isClient() then
        return;
    end
    if isServer() then
        local players = getOnlinePlayers();
        if players then
            for i = 0, players:size() - 1 do
                callback(players:get(i));
            end
        end
        return;
    end
    for i = 0, getNumActivePlayers() - 1 do
        local p = getSpecificPlayer(i);
        if p then
            callback(p);
        end
    end
end

function C.tickPlayer(character)
    if not character or character:isDead() or C.getSupportedMod() then
        return;
    end
    if not TCA.Sandbox.areCannibalismEffectsEnabled() then
        return;
    end
    local data = character:getModData()[C.KEY];
    if type(data) ~= "table" then
        return;
    end
    local now = C.now();
    data.exposure = math.max(0, (data.exposure or 0) - C.EXPOSURE_DECAY_PER_DAY / 144);
    if C.hasOwnTrait(character) then
        local since = now - (data.last or now);
        if since > C.CRAVING_START_HOURS then
            local severity = math.min(1, (since - C.CRAVING_START_HOURS) / (C.CRAVING_FULL_HOURS - C.CRAVING_START_HOURS));
            local strength = TCA.Sandbox.getCannibalismStrength();
            C.raiseToFloor(character, CharacterStat.UNHAPPINESS, C.CRAVING_UNHAPPY * severity * strength, C.FLOOR_STEP_UNHAPPY);
            C.raiseToFloor(character, CharacterStat.BOREDOM, C.CRAVING_BOREDOM * severity * strength, C.FLOOR_STEP_BOREDOM);
            C.raiseToFloor(character, CharacterStat.STRESS, C.CRAVING_STRESS * severity * strength, C.FLOOR_STEP_STRESS);
        end
    elseif (data.guiltUntil or -1) > now then
        C.raiseToFloor(character, CharacterStat.UNHAPPINESS, data.guiltFloor or 0, C.FLOOR_STEP_UNHAPPY);
    end
    C.flushStats(character);
end

function C.everyTenMinutes()
    C.forEachPlayer(C.tickPlayer);
end

C.originalComplete = C.originalComplete or ISEatFoodAction.complete;
C.originalEat = C.originalEat or ISEatFoodAction.eat;

function C.complete(self)
    local measured = C.measure(self.item);
    local result = C.originalComplete(self);
    C.onEaten(self.character, measured, self.percentage or 1);
    return result;
end

function C.eat(self, food, percentage)
    local measured = C.measure(self.item);
    C.originalEat(self, food, percentage);
    local portion = tonumber(percentage) or 1;
    if portion > 0.95 then
        portion = 1;
    end
    C.onEaten(self.character, measured, (self.percentage or 1) * portion);
end

ISEatFoodAction.complete = C.complete;
ISEatFoodAction.eat = C.eat;

Events.EveryTenMinutes.Add(C.everyTenMinutes);
